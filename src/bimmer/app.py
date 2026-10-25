#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""宝马菜单栏 App:车况读取 + 远程控制(中国区互联驾驶)。

依赖 bimmer_connected(数据/远程指令) + rumps(菜单栏)。
token 存于 ~/bimmer/tokens.json,由 login_sms.py / login.py 生成。
"""
import asyncio
import base64
import datetime
import json
import os
import plistlib
import queue
import sys
import threading
import urllib.parse
import webbrowser

import rumps

from bimmer_connected.account import MyBMWAccount
from bimmer_connected.api.client import MyBMWClient
from bimmer_connected.const import CarBrands, Regions
from bimmer_connected.models import MyBMWAuthError, MyBMWCaptchaMissingError

from bimmer import geocode
from bimmer.config import load_config

TOKENS_PATH = os.path.expanduser("~/bimmer/tokens.json")
STATS_PATH = os.path.expanduser("~/bimmer/stats.json")
CHARGE_STATS_PATH = os.path.expanduser("~/bimmer/charge_stats.json")

LAUNCH_AGENT_LABEL = "com.wangping.bimmer"
LAUNCH_AGENT_PATH = os.path.expanduser(f"~/Library/LaunchAgents/{LAUNCH_AGENT_LABEL}.plist")

# 打包分发到新机器时数据目录可能不存在,启动前确保存在
os.makedirs(os.path.expanduser("~/bimmer"), exist_ok=True)

LOCK_STATE = {
    "SECURED": "已锁定",
    "LOCKED": "已锁定",
    "UNLOCKED": "已解锁",
    "SELECTIVE": "部分锁定",
    "SELECTIVE_LOCKED": "部分锁定",
    "PARTIALLY_LOCKED": "部分锁定",
    "SECURED_EXTERNAL": "外部已锁定",
}

CHARGING_STATE = {
    "CHARGING": "充电中",
    "FINISHED_FULLY_CHARGED": "已充满",
    "CHARGING_COMPLETED": "充电完成",
    "NOT_CHARGING": "未充电",
    "ERROR": "异常",
}


def _km(v):
    return f"{v.value} km" if v is not None and v.value is not None else "—"


from Foundation import NSObject


class _LoginPanelController(NSObject):
    """登录面板按钮的 target:把点击转发给 BimmerApp(主线程)。"""

    def sendTapped_(self, _sender):
        self._owner._login_send()

    def loginTapped_(self, _sender):
        self._owner._login_submit()

    def cancelTapped_(self, _sender):
        self._owner._login_cancel()


class BimmerApp(rumps.App):
    def __init__(self):
        super().__init__("Bimmer", title="🚗")

        # 后台 asyncio 事件循环(独立线程)
        self._loop = asyncio.new_event_loop()
        threading.Thread(target=self._loop.run_forever, daemon=True).start()

        self._account = None
        self._mobile = ""
        self._data = {}
        self._version = 0
        self._last_shown = -1
        self._op_lock = None
        self._address = None
        self._last_geo = None
        self._logging_in = False
        self._login_auto_attempted = False
        self._login_lock = threading.Lock()
        # 常驻登录面板状态(主线程操作)
        self._login_show_requested = False
        self._login_events = queue.Queue()
        self._login_panel = None
        self._login_ctrl = None
        self._login_status = None
        self._login_phone_field = None
        self._login_code_field = None
        self._login_send_btn = None
        self._login_login_btn = None
        self._login_otp_id = None

        # 动态菜单项
        self._mi_title = rumps.MenuItem("加载中…")
        self._mi_battery = rumps.MenuItem("")
        self._mi_range = rumps.MenuItem("")
        self._mi_mileage = rumps.MenuItem("")
        self._mi_charging = rumps.MenuItem("")
        self._mi_charge_stats = rumps.MenuItem("")
        self._mi_trend = rumps.MenuItem("📊 充电趋势")
        self._mi_trend.add(rumps.MenuItem("加载中…"))
        self._mi_autostart = rumps.MenuItem("🚀 开机自动启动", callback=self._cb_autostart)
        self._mi_autostart.state = 1 if self._autostart_enabled() else 0
        self._mi_lock = rumps.MenuItem("")
        self._mi_location = rumps.MenuItem("", callback=self._open_map)
        self._mi_notice = rumps.MenuItem("")

        remote = rumps.MenuItem("远程控制")
        remote.add(rumps.MenuItem("🔒 锁车", callback=self._cb_lock))
        remote.add(rumps.MenuItem("🔓 解锁", callback=self._cb_unlock))
        remote.add(rumps.MenuItem("❄️ 开启空调", callback=self._cb_climate_on))
        remote.add(rumps.MenuItem("♨️ 关闭空调", callback=self._cb_climate_off))
        remote.add(rumps.MenuItem("📣 喇叭", callback=self._cb_horn))
        remote.add(rumps.MenuItem("💡 灯光闪烁", callback=self._cb_light))
        remote.add(rumps.MenuItem("🔌 开始充电", callback=self._cb_charge_start))
        remote.add(rumps.MenuItem("⏹ 停止充电", callback=self._cb_charge_stop))
        remote.add(rumps.MenuItem("📍 寻车", callback=self._cb_finder))

        self.menu = [
            self._mi_title,
            None,
            self._mi_battery,
            self._mi_range,
            self._mi_mileage,
            self._mi_charging,
            self._mi_charge_stats,
            self._mi_trend,
            self._mi_lock,
            self._mi_location,
            self._mi_notice,
            None,
            remote,
            None,
            rumps.MenuItem("🔐 重新登录", callback=self._cb_login),
            rumps.MenuItem("🔄 刷新", callback=self._cb_refresh),
            self._mi_autostart,
            None,
            rumps.MenuItem("退出", callback=lambda _: rumps.quit_application()),
        ]

        # 定时器:主线程轮询 UI(1s) + 后台定时拉取(60s)
        rumps.Timer(self._on_timer, 1).start()
        asyncio.run_coroutine_threadsafe(self._periodic(), self._loop)
        self._run_async(self._fetch())

    # ---------- token ----------
    def _load_tokens(self) -> dict:
        try:
            with open(TOKENS_PATH) as f:
                return json.load(f)
        except Exception:
            return {}

    def _save_tokens(self):
        a = self._account
        if not a:
            return
        cur = self._load_tokens()
        try:
            access = a.config.authentication.access_token
        except Exception:
            access = cur.get("access_token", "")
        new = {
            "mobile": self._mobile or cur.get("mobile", ""),
            "gcid": a.gcid or cur.get("gcid", ""),
            "refresh_token": a.refresh_token or cur.get("refresh_token", ""),
            "access_token": access or cur.get("access_token", ""),
        }
        if new != cur:
            with open(TOKENS_PATH, "w") as f:
                json.dump(new, f, ensure_ascii=False, indent=2)
            os.chmod(TOKENS_PATH, 0o600)

    # ---------- 里程统计(本地累计) ----------
    def _load_stats(self) -> dict:
        try:
            with open(STATS_PATH) as f:
                return json.load(f)
        except Exception:
            return {}

    def _save_stats(self, stats: dict):
        with open(STATS_PATH, "w") as f:
            json.dump(stats, f, ensure_ascii=False, indent=2)
        os.chmod(STATS_PATH, 0o600)

    def _record_mileage(self, km: float) -> float:
        """记录总里程,返回本月累计里程(km)。"""
        month = datetime.date.today().strftime("%Y-%m")
        stats = self._load_stats()
        m = stats.get(month)
        if not m:
            m = {"start_km": km}
            stats[month] = m
        m["last_km"] = km
        self._save_stats(stats)
        return round(km - m["start_km"], 1)

    # ---------- 充电会话本地记录(趋势) ----------
    def _load_charge_stats(self) -> dict:
        try:
            with open(CHARGE_STATS_PATH) as f:
                return json.load(f)
        except Exception:
            return {"sessions": []}

    def _save_charge_stats(self, stats: dict):
        with open(CHARGE_STATS_PATH, "w") as f:
            json.dump(stats, f, ensure_ascii=False, indent=2)
        os.chmod(CHARGE_STATS_PATH, 0o600)

    def _battery_capacity(self) -> float:
        try:
            return float(load_config().get("battery_capacity_kwh", 9.7))
        except Exception:
            return 9.7

    def _track_charging(self, status, soc):
        """检测充电会话起止,返回最近会话列表。"""
        stats = self._load_charge_stats()
        active = stats.get("active")
        sessions = stats.get("sessions", [])
        now = datetime.datetime.now().isoformat(timespec="seconds")

        if status == "CHARGING":
            if not active:
                stats["active"] = {"start": now, "start_soc": soc}
        elif active:
            start_soc = active.get("start_soc")
            kwh = None
            if start_soc is not None and soc is not None:
                delta = max(0.0, soc - start_soc)
                kwh = round(delta / 100.0 * self._battery_capacity(), 2)
            sessions.append({
                "start": active.get("start"), "end": now,
                "start_soc": start_soc, "end_soc": soc, "kwh": kwh,
            })
            sessions = sessions[-30:]
            stats["sessions"] = sessions
            stats.pop("active", None)

        self._save_charge_stats(stats)
        return sessions

    @staticmethod
    def _fmt_time(iso):
        try:
            return datetime.datetime.fromisoformat(iso).strftime("%m-%d %H:%M")
        except Exception:
            return iso

    def _format_session(self, s):
        parts = [f"{self._fmt_time(s.get('start',''))}→{self._fmt_time(s.get('end',''))}"]
        if s.get("start_soc") is not None and s.get("end_soc") is not None:
            parts.append(f"{s['start_soc']}%→{s['end_soc']}%")
        if s.get("kwh") is not None:
            parts.append(f"≈{s['kwh']}kWh")
        return "  ".join(parts)

    # ---------- async 核心 ----------
    def _lock(self) -> asyncio.Lock:
        if self._op_lock is None:
            self._op_lock = asyncio.Lock()
        return self._op_lock

    def _run_async(self, coro):
        """从主线程调度协程到后台循环。"""
        fut = asyncio.run_coroutine_threadsafe(coro, self._loop)
        fut.add_done_callback(self._after_async)
        return fut

    def _after_async(self, fut):
        try:
            result = fut.result()
            if isinstance(result, str) and result:
                self._set_data({"notice": result})
        except Exception as ex:
            self._set_data({"notice": f"操作失败: {ex}"})

    # ---------- 短信验证码登录 ----------
    def _cb_login(self, sender):
        self._start_login()

    def _start_login(self, auto: bool = False) -> bool:
        """发起短信登录:在主线程弹出常驻登录面板。auto=True 表示由定时拉取自动触发。"""
        with self._login_lock:
            if self._logging_in:
                return False
            if auto and self._login_auto_attempted:
                return False
            if auto:
                self._login_auto_attempted = True
            self._logging_in = True
            self._login_otp_id = None
        # 面板必须在主线程创建/显示,这里置位后由主线程定时器 _pump_prompt 处理。
        self._login_show_requested = True
        return True

    @staticmethod
    def _needs_login(ex) -> bool:
        if isinstance(ex, (MyBMWAuthError, MyBMWCaptchaMissingError)):
            return True
        return "未登录" in str(ex)

    # ---------- 登录面板(常驻,主线程) ----------
    def _pump_prompt(self):
        """主线程:弹出待显示的登录面板,并把后台线程结果回填到面板上。"""
        self._drain_login_events()
        if self._login_show_requested:
            self._login_show_requested = False
            self._show_login_panel()

    def _drain_login_events(self):
        while True:
            try:
                ev = self._login_events.get_nowait()
            except queue.Empty:
                return
            tag = ev[0]
            if tag == "send_done":
                _, otp_id, err = ev
                self._login_set_busy(False)
                if otp_id:
                    self._login_otp_id = otp_id
                    self._login_set_status("验证码已发送,请输入短信验证码后点「登录」")
                else:
                    self._login_set_status(err or "验证码发送失败,请重试")
            elif tag == "login_done":
                _, ok, err = ev
                if ok:
                    self._login_finish(ok=True)
                else:
                    self._login_set_busy(False)
                    self._login_set_status(err or "登录失败,请重试")

    def _login_set_status(self, text):
        if self._login_status is not None:
            self._login_status.setStringValue_(text or "")

    def _login_set_busy(self, busy):
        if self._login_send_btn is not None:
            self._login_send_btn.setEnabled_(not busy)
        if self._login_login_btn is not None:
            self._login_login_btn.setEnabled_(not busy)

    def _show_login_panel(self):
        from AppKit import (NSPanel, NSTextField, NSButton, NSMakeRect,
                            NSBackingStoreBuffered, NSWindowStyleMaskTitled,
                            NSBezelStyleRounded)

        if self._login_panel is None:
            panel = NSPanel.alloc().initWithContentRect_styleMask_backing_defer_(
                NSMakeRect(0, 0, 340, 200),
                NSWindowStyleMaskTitled,
                NSBackingStoreBuffered,
                False,
            )
            panel.setTitle_("登录 BMW 互联驾驶")
            panel.setReleasedWhenClosed_(False)
            panel.setFloatingPanel_(True)
            panel.setLevel_(3)  # 浮于普通窗口之上
            panel.setHidesOnDeactivate_(False)

            content = panel.contentView()

            status = NSTextField.alloc().initWithFrame_(NSMakeRect(16, 164, 308, 20))
            status.setEditable_(False)
            status.setBezeled_(False)
            status.setDrawsBackground_(False)

            phone_label = NSTextField.labelWithString_("手机号")
            phone_label.setFrame_(NSMakeRect(16, 128, 56, 22))
            phone_field = NSTextField.alloc().initWithFrame_(NSMakeRect(76, 122, 248, 26))
            phone_field.setPlaceholderString_("8613812345678")

            code_label = NSTextField.labelWithString_("验证码")
            code_label.setFrame_(NSMakeRect(16, 88, 56, 22))
            code_field = NSTextField.alloc().initWithFrame_(NSMakeRect(76, 82, 248, 26))
            code_field.setPlaceholderString_("短信验证码")

            ctrl = _LoginPanelController.alloc().init()
            ctrl._owner = self

            send_btn = NSButton.buttonWithTitle_target_action_("发送验证码", ctrl, "sendTapped:")
            send_btn.setFrame_(NSMakeRect(16, 24, 100, 32))
            send_btn.setBezelStyle_(NSBezelStyleRounded)

            login_btn = NSButton.buttonWithTitle_target_action_("登录", ctrl, "loginTapped:")
            login_btn.setFrame_(NSMakeRect(120, 24, 100, 32))
            login_btn.setBezelStyle_(NSBezelStyleRounded)
            login_btn.setKeyEquivalent_("\r")

            cancel_btn = NSButton.buttonWithTitle_target_action_("取消", ctrl, "cancelTapped:")
            cancel_btn.setFrame_(NSMakeRect(224, 24, 100, 32))
            cancel_btn.setBezelStyle_(NSBezelStyleRounded)
            cancel_btn.setKeyEquivalent_("\x1b")

            for v in (status, phone_label, phone_field, code_label, code_field,
                      send_btn, login_btn, cancel_btn):
                content.addSubview_(v)

            self._login_panel = panel
            self._login_ctrl = ctrl
            self._login_status = status
            self._login_phone_field = phone_field
            self._login_code_field = code_field
            self._login_send_btn = send_btn
            self._login_login_btn = login_btn

        # 每次显示前重置到初始状态
        self._login_phone_field.setStringValue_(self._mobile or "")
        self._login_code_field.setStringValue_("")
        self._login_otp_id = None
        self._login_set_status("请输入手机号和短信验证码")
        self._login_set_busy(False)
        self._login_panel.center()
        self._login_panel.makeKeyAndOrderFront_(None)
        self._login_panel.orderFrontRegardless()

    def _login_send(self):
        from bimmer import login
        phone = login.normalize_mobile(self._login_phone_field.stringValue())
        if not phone:
            self._login_set_status("请输入手机号")
            return
        self._mobile = phone
        self._login_phone_field.setStringValue_(phone)
        self._login_otp_id = None
        self._login_set_busy(True)
        self._login_set_status("正在发送验证码…")
        threading.Thread(target=self._login_send_worker, args=(phone,), daemon=True).start()

    def _login_send_worker(self, phone):
        try:
            otp_id, err = self._send_sms_sync(phone)
        except Exception as ex:
            otp_id, err = None, f"发送验证码异常: {ex}"
        self._login_events.put(("send_done", otp_id, err))

    def _login_submit(self):
        code = self._login_code_field.stringValue().strip()
        if not self._login_otp_id:
            self._login_set_status("请先点「发送验证码」获取验证码")
            return
        if not code:
            self._login_set_status("请输入短信验证码")
            return
        self._login_set_busy(True)
        self._login_set_status("正在登录…")
        threading.Thread(target=self._login_submit_worker,
                         args=(self._login_otp_id, code), daemon=True).start()

    def _login_submit_worker(self, otp_id, code):
        from bimmer import login
        from bimmer import login_sms
        try:
            r = login_sms.login_sms(otp_id, code)
            try:
                data = r.json().get("data") or {}
            except Exception:
                data = {}
            if r.status_code >= 300 or not data.get("refresh_token"):
                self._login_events.put(("login_done", False, "验证码错误或已过期,请重新点「发送验证码」"))
                return
            login_sms.save_token(data)
            self._mobile = login.MOBILE
            self._login_events.put(("login_done", True, ""))
        except Exception as ex:
            self._login_events.put(("login_done", False, f"登录异常: {ex}"))

    def _login_cancel(self):
        self._login_finish(ok=False)

    def _login_finish(self, ok):
        if self._login_panel is not None:
            self._login_panel.orderOut_(None)
        with self._login_lock:
            self._logging_in = False
        if ok:
            self._account = None
            self._set_data({"notice": "登录成功 ✓"})
            self._run_async(self._fetch_after_login())
        else:
            self._set_data({"notice": "登录未完成,可点菜单「🔐 重新登录」重试"})

    def _send_sms_sync(self, phone):
        """滑块验证 + 发送短信,成功返回 (otp_id, ""),失败返回 (None, 提示语)。"""
        from bimmer import login
        from bimmer import login_sms

        login.MOBILE = login.normalize_mobile(phone)
        try:
            verify_id = login_sms.solve_captcha()
        except Exception as ex:
            msg = f"滑块验证请求异常: {ex}"
            self._set_data({"notice": msg})
            return None, msg
        if not verify_id:
            msg = "滑块验证未通过,请重试"
            self._set_data({"notice": msg})
            return None, msg
        try:
            r = login_sms.send_sms_code(verify_id)
        except Exception as ex:
            msg = f"发送短信请求异常: {ex}"
            self._set_data({"notice": msg})
            return None, msg
        otp_id = None
        try:
            d = r.json()
            if d.get("code") not in (200, "200"):
                msg = d.get("message") or d.get("msg") or d.get("code")
                self._set_data({"notice": f"发送短信失败: {msg}"})
                return None, f"发送短信失败: {msg}"
            data = d.get("data") or {}
            otp_id = data.get("otpID") or data.get("otpId")
        except Exception:
            otp_id = None
        if not otp_id:
            msg = "未取到验证码 ID,请重试"
            self._set_data({"notice": msg})
            return None, msg
        return otp_id, ""

    @staticmethod
    def _access_expires_at(token: str):
        """从 access_token JWT 读 exp(UTC),失败返回 None。"""
        try:
            payload = token.split(".")[1]
            payload += "=" * (-len(payload) % 4)
            d = json.loads(base64.urlsafe_b64decode(payload))
            return datetime.datetime.fromtimestamp(d["exp"], tz=datetime.timezone.utc)
        except Exception:
            return None

    async def _refresh_token_known_good(self, account) -> bool:
        """用 login 的已知可用方式刷新 token。

        库内 China 刷新(_refresh_token_china)缺 x-correlation-id 等 header 会 401,
        这里复刻 refresh_token.py 的请求。成功会轮换 refresh_token 并立即落盘。
        """
        import httpx
        from bimmer import login

        old_refresh = account.refresh_token or ""
        old_gcid = account.gcid or ""
        if not old_refresh:
            return False
        headers = {
            **login.BASE_HEADERS,
            **login.x_headers(),
            "x-login-nonce": login.generate_cn_nonce(old_gcid),
        }
        async with httpx.AsyncClient(timeout=20) as client:
            r = await client.post(
                f"{login.SERVER}/eadrax-coas/v2/oauth/token",
                data={"refresh_token": old_refresh, "grant_type": "refresh_token"},
                headers=headers,
            )
        if r.status_code >= 300:
            return False
        d = r.json()
        new_access = d.get("access_token")
        if not new_access:
            return False
        account.set_refresh_token(
            d.get("refresh_token") or old_refresh,
            d.get("gcid") or old_gcid,
            new_access,
        )
        self._save_tokens()  # 轮换后的 refresh_token 立即落盘,避免丢失
        return True

    async def _refresh_if_needed(self, account) -> None:
        """access_token 缺失或临近过期时,用已知可用方式主动刷新。"""
        try:
            access = account.config.authentication.access_token
        except Exception:
            access = ""
        exp = self._access_expires_at(access) if access else None
        if exp is not None and datetime.datetime.now(tz=datetime.timezone.utc) < exp - datetime.timedelta(seconds=300):
            return
        try:
            await self._refresh_token_known_good(account)
        except Exception:
            pass

    async def _ensure_account(self) -> MyBMWAccount:
        if self._account is None:
            t = self._load_tokens()
            self._mobile = t.get("mobile", "")
            if not t.get("refresh_token"):
                raise RuntimeError("未登录")
            account = MyBMWAccount(self._mobile, "", region=Regions.CHINA)
            account.set_refresh_token(
                t.get("refresh_token"), t.get("gcid"), t.get("access_token")
            )
            self._account = account
        await self._refresh_if_needed(self._account)
        return self._account

    async def _periodic(self):
        while True:
            await asyncio.sleep(60)
            await self._fetch()

    async def _maybe_geocode(self, lat, lng):
        """逆地理编码,位置基本没变时直接用缓存,避免频繁请求。"""
        if self._address is not None and self._last_geo is not None:
            pl, pn = self._last_geo
            # ~150m 内视为未移动
            if abs(lat - pl) < 0.0015 and abs(lng - pn) < 0.0015:
                return self._address
        try:
            addr = await geocode.reverse_geocode(lat, lng)
        except Exception:
            addr = ""
        if addr:
            self._address = addr
            self._last_geo = (lat, lng)
        return addr

    async def _fetch_charging_stats(self, account, vin):
        """本月充电统计(充电量 kWh + 充电次数)。"""
        date_str = datetime.date.today().isoformat()
        async with MyBMWClient(account.config) as client:
            headers = client.generate_default_header(CarBrands.BMW)
            r = await client.get(
                "/eadrax-chs/v2/charging-statistics",
                params={"currentDate": date_str},
                headers=dict(headers, **{"bmw-vin": vin}),
            )
            if r.status_code != 200:
                return None
            st = (r.json().get("statistics") or {})
            kwh = st.get("totalEnergyCharged")
            sessions = st.get("numberOfChargingSessions")
            if kwh is None and sessions is None:
                return None
            return {"kwh": kwh, "sessions": sessions}

    async def _fetch(self):
        async with self._lock():
            try:
                account = await self._ensure_account()
                await account.get_vehicles()
                self._save_tokens()
            except Exception as ex:
                if self._needs_login(ex):
                    if self._start_login(auto=True):
                        self._set_data({"notice": "需要登录,正在弹出验证窗口…"})
                    elif self._logging_in:
                        self._set_data({"notice": "登录进行中…"})
                    else:
                        self._set_data({"error": "未登录: 请点菜单「🔐 重新登录」"})
                else:
                    self._set_data({"error": str(ex)})
                return

            if not account.vehicles:
                self._set_data({"error": "账号下没有车辆"})
                return

            v = account.vehicles[0]
            fb = v.fuel_and_battery
            dw = v.doors_and_windows
            loc = v.vehicle_location

            d = {
                "name": v.name or "BMW",
                "battery": (f"{fb.remaining_battery_percent}%"
                            if fb.remaining_battery_percent is not None else "—"),
                "fuel": (f"{fb.remaining_fuel.value} L"
                         if fb.remaining_fuel is not None and fb.remaining_fuel.value is not None
                         else "—"),
                "range_elec": fb.remaining_range_electric,
                "range_fuel": fb.remaining_range_fuel,
                "range_total": fb.remaining_range_total,
                "mileage": v.mileage,
                "charging": CHARGING_STATE.get(
                    fb.charging_status.value if fb.charging_status else "",
                    "未知",
                ),
                "charger_connected": fb.is_charger_connected,
                "lock": LOCK_STATE.get(
                    dw.door_lock_state.value if dw.door_lock_state else "",
                    "未知",
                ),
                "windows_open": not dw.all_windows_closed,
                "lids_open": not dw.all_lids_closed,
                "lat": loc.location.latitude if loc and loc.location else None,
                "lng": loc.location.longitude if loc and loc.location else None,
                "heading": loc.heading if loc else None,
            }
            if d["lat"] is not None and d["lng"] is not None:
                addr = await self._maybe_geocode(d["lat"], d["lng"])
                if addr:
                    d["address"] = addr
            if v.mileage is not None and v.mileage.value is not None:
                d["month_km"] = self._record_mileage(v.mileage.value)
            cs_status = fb.charging_status.value if fb.charging_status else None
            cs_soc = fb.remaining_battery_percent
            d["charge_sessions_local"] = self._track_charging(cs_status, cs_soc)
            try:
                cs = await self._fetch_charging_stats(account, v.vin)
                if cs:
                    d["charge_kwh"] = cs.get("kwh")
                    d["charge_sessions"] = cs.get("sessions")
                    self._save_tokens()  # 充电接口也可能触发 token 轮换
            except Exception:
                pass
            # 成功拉到数据:清掉可能残留的 error,并重武装自动登录
            self._data.pop("error", None)
            self._login_auto_attempted = False
            self._set_data(d)

    async def _fetch_after_login(self):
        """登录成功后带重试的拉取,应对短信 token 首次使用时的瞬时失败。"""
        for _ in range(3):
            await self._fetch()
            if not self._data.get("error"):
                return
            await asyncio.sleep(2)

    async def _trigger(self, method_name: str, label: str):
        async with self._lock():
            account = await self._ensure_account()
            await account.get_vehicles()
            self._save_tokens()
            if not account.vehicles:
                raise RuntimeError("无车辆")
            v = account.vehicles[0]
            status = await getattr(v.remote_services, method_name)()
            self._save_tokens()
            await account.get_vehicles()  # 刷新状态
            return f"{label}: {status.state.value}"

    # ---------- 状态 ----------
    def _set_data(self, patch: dict):
        self._data = {**self._data, **patch}
        self._version += 1

    # ---------- UI ----------
    def _on_timer(self, timer):
        self._pump_prompt()
        if self._version != self._last_shown:
            self._last_shown = self._version
            self._update_menu()

    def _update_menu(self):
        d = self._data
        if d.get("error"):
            self.title = "🚗 ⚠️"
            self._mi_title.title = "⚠️ 出错了"
            self._mi_notice.title = d["error"]
            for mi in (self._mi_battery, self._mi_range, self._mi_mileage,
                       self._mi_charging, self._mi_charge_stats,
                       self._mi_lock, self._mi_location):
                mi.title = ""
            return

        name = d.get("name", "BMW")
        total = d.get("range_total")
        self.title = f"🚗 {_km(total)}" if total else "🚗"

        self._mi_title.title = f"{name}"
        self._mi_battery.title = f"🔋 电量 {d.get('battery','—')} · 油量 {d.get('fuel','—')}"
        self._mi_range.title = (f"🛣 纯电 {_km(d.get('range_elec'))} · "
                                f"燃油 {_km(d.get('range_fuel'))} · 总 {_km(d.get('range_total'))}")
        self._mi_mileage.title = f"📏 总里程 {_km(d.get('mileage'))}"
        if d.get("month_km") is not None:
            self._mi_mileage.title += f" · 本月 +{d['month_km']:.0f} km"
        charger = "充电枪已连接" if d.get("charger_connected") else "充电枪未连接"
        self._mi_charging.title = f"🔌 {d.get('charging','—')} ({charger})"

        if d.get("charge_kwh") is not None or d.get("charge_sessions") is not None:
            kwh = f"{d['charge_kwh']} kWh" if d.get("charge_kwh") is not None else "—"
            ses = f"{d['charge_sessions']} 次" if d.get("charge_sessions") is not None else "—"
            self._mi_charge_stats.title = f"⚡ 本月充电 {kwh} · {ses}"
        else:
            self._mi_charge_stats.title = "⚡ 本月充电 —"

        # 充电趋势子菜单
        self._mi_trend.clear()
        self._mi_trend.add(rumps.MenuItem(
            f"本月官方: {d.get('charge_kwh', '—') if d.get('charge_kwh') is not None else '—'} kWh · "
            f"{d.get('charge_sessions', '—') if d.get('charge_sessions') is not None else '—'} 次"))
        self._mi_trend.add(None)
        sessions = d.get("charge_sessions_local") or []
        if sessions:
            shown = sessions[-8:]
            self._mi_trend.add(rumps.MenuItem(f"本地记录(最近 {len(shown)} 条):"))
            for s in reversed(shown):
                self._mi_trend.add(rumps.MenuItem(self._format_session(s)))
        else:
            self._mi_trend.add(rumps.MenuItem("本地暂无记录(检测到充电后自动生成)"))

        lock = f"🔒 {d.get('lock','—')}"
        if d.get("windows_open"):
            lock += " · 有车窗开启"
        if d.get("lids_open"):
            lock += " · 有门/盖开启"
        self._mi_lock.title = lock

        if d.get("lat") is not None:
            addr = d.get("address")
            if not addr:
                # 逆地理编码未成功时,退而显示坐标,而不是误导性的"查询中…"
                addr = f"{d['lat']:.5f}, {d['lng']:.5f}"
            elif len(addr) > 40:
                addr = addr[:39] + "…"
            self._mi_location.title = f"📍 {addr} (点击打开地图)"
        else:
            self._mi_location.title = "📍 无位置信息"

        self._mi_notice.title = d.get("notice", "")

    def _open_map(self, sender):
        lat, lng = self._data.get("lat"), self._data.get("lng")
        if lat is None or lng is None:
            rumps.alert("无位置信息")
            return
        q = urllib.parse.quote("我的车")
        webbrowser.open(f"https://maps.apple.com/?ll={lat},{lng}&q={q}")

    # ---------- 开机自动启动(LaunchAgent) ----------
    @staticmethod
    def _app_bundle_path() -> str:
        """当前 App 的 .app 目录(打包后 sys.executable 位于 .app/Contents/MacOS/ 下)。"""
        if getattr(sys, "frozen", False):
            return os.path.dirname(os.path.dirname(os.path.dirname(sys.executable)))
        return ""

    def _autostart_enabled(self) -> bool:
        return os.path.exists(LAUNCH_AGENT_PATH)

    def _set_autostart(self, enable: bool) -> bool:
        if enable:
            bundle = self._app_bundle_path()
            if not bundle:
                rumps.alert("仅在打包后的 App 中可用")
                return False
            os.makedirs(os.path.dirname(LAUNCH_AGENT_PATH), exist_ok=True)
            plist = {
                "Label": LAUNCH_AGENT_LABEL,
                "ProgramArguments": ["/usr/bin/open", bundle],
                "RunAtLoad": True,
                "KeepAlive": False,
            }
            with open(LAUNCH_AGENT_PATH, "wb") as f:
                plistlib.dump(plist, f)
        else:
            try:
                os.remove(LAUNCH_AGENT_PATH)
            except FileNotFoundError:
                pass
        return True

    def _cb_autostart(self, sender):
        enable = not self._autostart_enabled()
        if self._set_autostart(enable):
            self._mi_autostart.state = 1 if enable else 0
            rumps.alert("已开启开机自动启动" if enable else "已关闭开机自动启动")

    # ---------- 远程指令回调 ----------
    def _confirm(self, label: str, detail: str) -> bool:
        return rumps.alert(f"确认{label}?", detail, ok=label, cancel="取消") == 1

    def _cb_lock(self, sender):
        if self._confirm("锁车", "将远程锁车。"):
            self._run_async(self._trigger("trigger_remote_door_lock", "锁车"))

    def _cb_unlock(self, sender):
        if self._confirm("解锁", "将远程解锁车辆,请注意安全。"):
            self._run_async(self._trigger("trigger_remote_door_unlock", "解锁"))

    def _cb_climate_on(self, sender):
        if self._confirm("开启空调", "将远程开启空调。"):
            self._run_async(self._trigger("trigger_remote_air_conditioning", "开启空调"))

    def _cb_climate_off(self, sender):
        self._run_async(self._trigger("trigger_remote_air_conditioning_stop", "关闭空调"))

    def _cb_horn(self, sender):
        self._run_async(self._trigger("trigger_remote_horn", "喇叭"))

    def _cb_light(self, sender):
        self._run_async(self._trigger("trigger_remote_light_flash", "灯光闪烁"))

    def _cb_charge_start(self, sender):
        self._run_async(self._trigger("trigger_charge_start", "开始充电"))

    def _cb_charge_stop(self, sender):
        self._run_async(self._trigger("trigger_charge_stop", "停止充电"))

    def _cb_finder(self, sender):
        self._run_async(self._trigger("trigger_remote_vehicle_finder", "寻车"))

    def _cb_refresh(self, sender):
        self._run_async(self._fetch())


def main() -> None:
    BimmerApp().run()


if __name__ == "__main__":
    main()
