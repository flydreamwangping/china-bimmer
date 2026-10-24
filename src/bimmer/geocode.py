#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""逆地理编码:把经纬度转成中文地址(用于菜单栏展示)。

优先级:高德 / 百度 / Apple 原生 / Nominatim(免 key 兜底)。
配置:项目 config/config.json 里写 {"geo_provider": "amap", "geo_key": "xxx"},
或环境变量 BMW_GEO_PROVIDER / BMW_GEO_KEY。不配置则用 Apple 原生兜底(免 key)。
"""
import asyncio
import math
import os
import re

import httpx

from bimmer.config import load_config

# ---- 坐标转换(宝马返回 WGS84,高德要 GCJ-02,百度要 BD-09) ----
_PI = math.pi
_A = 6378245.0
_EE = 0.00669342162296594323


def _out_of_china(lng, lat):
    return not (72.004 <= lng <= 137.8347 and 0.8293 <= lat <= 55.8271)


def _tlat(x, y):
    r = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * math.sqrt(abs(x))
    r += (20.0 * math.sin(6.0 * x * _PI) + 20.0 * math.sin(2.0 * x * _PI)) * 2.0 / 3.0
    r += (20.0 * math.sin(y * _PI) + 40.0 * math.sin(y / 3.0 * _PI)) * 2.0 / 3.0
    r += (160.0 * math.sin(y / 12.0 * _PI) + 320.0 * math.sin(y * _PI / 30.0)) * 2.0 / 3.0
    return r


def _tlng(x, y):
    r = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * math.sqrt(abs(x))
    r += (20.0 * math.sin(6.0 * x * _PI) + 20.0 * math.sin(2.0 * x * _PI)) * 2.0 / 3.0
    r += (20.0 * math.sin(x * _PI) + 40.0 * math.sin(x / 3.0 * _PI)) * 2.0 / 3.0
    r += (150.0 * math.sin(x / 12.0 * _PI) + 300.0 * math.sin(x / 30.0 * _PI)) * 2.0 / 3.0
    return r


def wgs84_to_gcj02(lng, lat):
    if _out_of_china(lng, lat):
        return lng, lat
    dlat = _tlat(lng - 105.0, lat - 35.0)
    dlng = _tlng(lng - 105.0, lat - 35.0)
    rad = lat / 180.0 * _PI
    magic = math.sin(rad)
    magic = 1 - _EE * magic * magic
    sm = math.sqrt(magic)
    dlat = (dlat * 180.0) / ((_A * (1 - _EE)) / (magic * sm) * _PI)
    dlng = (dlng * 180.0) / (_A / sm * math.cos(rad) * _PI)
    return lng + dlng, lat + dlat


def gcj02_to_bd09(lng, lat):
    x, y = lng, lat
    z = math.sqrt(x * x + y * y) + 0.00002 * math.sin(y * _PI * 3000.0 / 180.0)
    theta = math.atan2(y, x) + 0.000003 * math.cos(x * _PI * 3000.0 / 180.0)
    return z * math.cos(theta) + 0.0065, z * math.sin(theta) + 0.006


# ---- 配置 ----
def _cfg():
    cfg = load_config()
    provider = (cfg.get("geo_provider") or os.environ.get("BMW_GEO_PROVIDER") or "nominatim").lower()
    key = cfg.get("geo_key") or os.environ.get("BMW_GEO_KEY") or ""
    return provider, key


# ---- 地址格式化 ----
def _nominatim_addr(data):
    a = data.get("address") or {}
    out = []
    if a.get("city"):
        out.append(a["city"])
    elif a.get("town"):
        out.append(a["town"])
    for k in ("district", "county"):
        if a.get(k):
            out.append(a[k])
            break
    for k in ("road", "suburb", "neighbourhood", "village"):
        if a.get(k):
            out.append(a[k])
            break
    s = "".join(out)
    return s or data.get("display_name", "")


def _door_number(addr):
    """从地址里提取门牌号,如 '505弄155号' / '10号' / '88号院'。"""
    m = re.search(r"\d+(?:[弄巷]?\d+)*(?:号|院|栋|幢|号楼|单元|室)", addr)
    return m.group(0) if m else ""


def _baidu_addr(res):
    """百度逆地理编码 -> 尽量精确到门牌号的地址。"""
    ac = res.get("addressComponent") or {}
    base = res.get("formatted_address") or ""
    street = ac.get("street") or ""

    # 来源一:addressComponent.street_number
    sn = (ac.get("street_number") or "").strip()
    if sn and sn not in base:
        base = base.rstrip() + sn

    # 来源二:最近 POI 的详细地址(住宅/商户常带门牌号)
    door = ""
    poi_name = ""
    for p in res.get("pois") or []:
        addr = p.get("addr") or ""
        if street and street in addr:
            tail = addr.split(street, 1)[1].strip()
            if tail:
                door, poi_name = tail, (p.get("name") or "")
                break
        if _door_number(addr):
            door, poi_name = _door_number(addr), (p.get("name") or "")
            break

    if door and door not in base:
        base = base.rstrip() + door
    if poi_name and poi_name not in base:
        base = f"{base}（{poi_name}）"
    return base


def _format_placemark(pm):
    """把 CLPlacemark 拼成中文地址:省/市/区/街道,直辖市不重复省份。"""
    admin = pm.administrativeArea() or ""
    city = pm.locality() or ""
    district = pm.subLocality() or ""
    street = pm.thoroughfare() or ""
    name = pm.name() or ""

    parts = []
    if admin and admin != city:  # 直辖市(上海等)的 administrativeArea 为 None 或与市同名
        parts.append(admin)
    if city:
        parts.append(city)
    if district:
        parts.append(district)
    if street:
        parts.append(street)
    elif name:  # 没有街道信息时退回 POI 名称
        parts.append(name)
    return "".join(parts)


async def _apple_reverse(lat, lng, timeout=10.0):
    """Apple 原生逆地理编码(系统自带、免 key),失败/超时返回 ""。

    CLGeocoder 的 completion handler 只在主线程的 run loop 里回调(rumps 的
    AppKit 主循环保证它在跑),这里用 call_soon_threadsafe 把结果送回 asyncio
    loop 线程。CLLocation 用 WGS-84,与宝马返回的坐标系一致。
    """
    try:
        from CoreLocation import CLGeocoder, CLLocation
    except Exception:
        return ""
    loop = asyncio.get_running_loop()
    fut = loop.create_future()
    try:
        geocoder = CLGeocoder.alloc().init()
        loc = CLLocation.alloc().initWithLatitude_longitude_(lat, lng)

        def _done(placemarks, error):
            def _set():
                if fut.done():
                    return
                try:
                    if error or not placemarks or len(placemarks) == 0:
                        fut.set_result("")
                        return
                    fut.set_result(_format_placemark(placemarks[0]))
                except Exception:
                    if not fut.done():
                        fut.set_result("")

            loop.call_soon_threadsafe(_set)

        geocoder.reverseGeocodeLocation_completionHandler_(loc, _done)
    except Exception:
        return ""
    try:
        return await asyncio.wait_for(fut, timeout)
    except Exception:
        return ""


async def reverse_geocode(lat, lng, timeout=8.0):
    provider, key = _cfg()
    async with httpx.AsyncClient(timeout=timeout) as client:
        # 高德
        if provider == "amap" and key:
            glng, glat = wgs84_to_gcj02(lng, lat)
            r = await client.get(
                "https://restapi.amap.com/v3/geocode/regeo",
                params={"key": key, "location": f"{glng:.6f},{glat:.6f}",
                        "extensions": "base", "radius": "1000"},
            )
            data = r.json()
            if data.get("status") == "1":
                return (data.get("regeocode") or {}).get("formatted_address", "")

        # 百度
        if provider == "baidu" and key:
            glng, glat = wgs84_to_gcj02(lng, lat)
            blng, blat = gcj02_to_bd09(glng, glat)
            r = await client.get(
                "https://api.map.baidu.com/reverse_geocoding/v3/",
                params={"ak": key, "output": "json", "coordtype": "bd09ll",
                        "location": f"{blat:.6f},{blng:.6f}",
                        "pois": "1", "extensions_poi": "1"},
            )
            data = r.json()
            if data.get("status") == 0:
                return _baidu_addr(data.get("result") or {})

        # Apple 原生(免 key,无需任何配置,Mac 上最省事)
        addr = await _apple_reverse(lat, lng, timeout=timeout)
        if addr:
            return addr

        # Nominatim 兜底(免 key,WGS84 直用;国内常被墙,仅作最后手段)
        try:
            r = await client.get(
                "https://nominatim.openstreetmap.org/reverse",
                params={"lat": lat, "lon": lng, "format": "jsonv2",
                        "accept-language": "zh-CN", "zoom": 16},
                headers={"User-Agent": "BimmerMenuBar/1.0 (personal use)"},
            )
            return _nominatim_addr(r.json())
        except Exception:
            return ""
