#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""复刻 Yixi/Y-BMW(MIT)的宝马中国区密码登录流程,产出 refresh_token / access_token。

流程:create-captcha -> 解滑块 -> verify-captcha -> publickey -> login/pwd
用法:BMW_USERNAME='8613...' BMW_PASSWORD='...' python3 -m bimmer.login
"""
import base64
import datetime
import hashlib
import io
import json
import logging
import os
import sys
import uuid

import httpx
from PIL import Image
from Crypto.Cipher import AES, PKCS1_v1_5
from Crypto.Hash import SHA256
from Crypto.PublicKey import RSA
from Crypto.Random import get_random_bytes
from Crypto.Util.Padding import pad

SERVER = "https://myprofile.bmw.com.cn"
MOBILE = os.environ.get("BMW_USERNAME", "").strip()
PASSWORD = os.environ.get("BMW_PASSWORD", "")

BASE_HEADERS = {
    "Content-Type": "application/json; charset=utf-8",
    "x-user-agent": "android(29);bmw;5.14.0(58417);cn",
    "Accept-Language": "zh-CN",
    "User-Agent": "Dart/3.3 (dart:io)",
}

# 打包成菜单栏 app(console=False)后 stdout 不可见,这里同时写到 ~/bimmer/app.log,
# 便于在真机上排查登录/滑块/网络问题。
_logger = logging.getLogger("bimmer.login")
if not _logger.handlers:
    try:
        _log_path = os.path.expanduser("~/bimmer/app.log")
        os.makedirs(os.path.dirname(_log_path), exist_ok=True)
        _fh = logging.FileHandler(_log_path, encoding="utf-8")
        _fh.setFormatter(logging.Formatter("%(asctime)s %(message)s"))
        _logger.addHandler(_fh)
        _logger.setLevel(logging.INFO)
    except Exception:
        pass


def log(msg: str) -> None:
    """同时输出到 stdout 与 ~/bimmer/app.log。"""
    print(msg)
    try:
        _logger.info(msg)
    except Exception:
        pass


def normalize_mobile(mobile: str) -> str:
    """规整中国手机号:去除非数字字符,并补全 86 区号前缀。

    宝马中国区接口要求 "86"+11 位手机号(如 8613812345678)。用户常直接输入
    11 位(13812345678),此时 create-captcha 会返回 422,导致滑块/短信全程失败。
    """
    m = (mobile or "").strip()
    digits = "".join(ch for ch in m if ch.isdigit())
    if digits.startswith("86") and len(digits) == 13:
        return digits
    if len(digits) == 11 and digits.startswith("1"):
        return "86" + digits
    return m


def x_headers():
    """x / correlation-id:客户端随机生成的设备指纹(非密钥)。"""
    u = str(uuid.uuid4())
    x = (
        uuid.uuid4().hex[0]
        + hashlib.md5(str(uuid.uuid4()).encode()).hexdigest()
        + hashlib.md5(str(uuid.uuid4()).encode()).hexdigest()
    )[:64]
    return {"x-correlation-id": u, "bmw-correlation-id": u, "x": x}


def _random_hex(size: int) -> str:
    """与 bimmer_connected fork 一致:随机 size 个十六进制字符。"""
    return get_random_bytes(size).hex()[:size]


def generate_cn_nonce(username: str) -> str:
    """生成 x-login-nonce(登录用 mobile,刷新用 gcid)。

    算法复刻自 bimmer_connected 中国区 fork 的 generate_cn_nonce:
    key/iv 随机 -> SHA256 摘要 -> AES-CBC 加密 "mobile&GMT时间&随机串"。
    """
    key = _random_hex(16)
    iv = _random_hex(16)

    k1, k2 = key[:8], key[8:]
    i1, i2 = iv[:8], iv[8:]

    if username is None:
        username = ""

    sha256_hex = SHA256.new(
        (k2 + i1 + "u3.6.1" + username[-4:] + k1 + i2).encode()
    ).hexdigest()
    sha256_a, sha256_b = sha256_hex[:32], sha256_hex[32:]

    random_str = k1
    time_str = datetime.datetime.now(tz=datetime.timezone.utc).strftime(
        "%a, %d %b %Y %H:%M:%S GMT"
    )
    phone_text = f"{username}&{time_str}&{random_str}"

    chars = list("01234abcdefghijklmnopqrstuvwxyz56789")
    k1r = chars[36 - chars.index(k1[4]) - 1]
    k2r = chars[36 - chars.index(k2[4]) - 1]
    aes_key = key[:4] + k1r + key[5:12] + k2r + key[13:]

    cipher_aes = AES.new(aes_key.encode(), AES.MODE_CBC, iv.encode())
    aes_hex = cipher_aes.encrypt(pad(phone_text.encode(), AES.block_size)).hex()

    return k2 + i1 + sha256_a + aes_hex + k1 + i2 + sha256_b


def create_captcha():
    r = httpx.post(
        f"{SERVER}/eadrax-coas/v2/cop/create-captcha",
        json={"mobile": MOBILE, "brand": "BMW"},
        headers={**BASE_HEADERS, **x_headers()},
        timeout=20,
    )
    log(f"[captcha] http={r.status_code}")
    if r.status_code >= 300:
        return None
    d = r.json()
    if d.get("code") not in (200, "200"):
        log(f"[captcha] 失败 body={r.text[:300]}")
        return None
    return d.get("data")


def solve_position(bg_b64: str, cut_b64: str) -> float:
    """缺口定位:缺口是阴影(颜色对不上),但拼图块轮廓的边缘与缺口边界重合。

    做法:取拼图块 alpha 轮廓,在背景水平梯度图上滑动,累加轮廓处的梯度,
    最大处即缺口左边界。返回 position=x/width。
    """
    bg = Image.open(io.BytesIO(base64.b64decode(bg_b64))).convert("L")
    cut = Image.open(io.BytesIO(base64.b64decode(cut_b64))).convert("RGBA")
    W, H = bg.size

    # 拼图块轮廓(相对 bbox 左上角的 (dx,dy) 列表)
    a = cut.getchannel("A")
    x0, y0, x1, y1 = a.getbbox()
    w, h = x1 - x0, y1 - y0
    ap = a.load()

    def opaque(x, y):
        return 0 <= x < cut.width and 0 <= y < cut.height and ap[x, y] > 128

    edge = [
        (dx, dy)
        for dy in range(h)
        for dx in range(w)
        if opaque(x0 + dx, y0 + dy)
        and not all(opaque(x0 + dx + ox, y0 + dy + oy)
                    for ox in (-1, 0, 1) for oy in (-1, 0, 1))
    ]

    # 背景水平梯度幅值
    gp = bg.load()
    gx = [[abs(gp[x + 1, y] - gp[x - 1, y]) if 0 < x < W - 1 else 0
           for x in range(W)] for y in range(H)]

    best_x, best_score = 0, -1
    for cx in range(0, W - w + 1):
        s = 0
        for dx, dy in edge:
            s += gx[y0 + dy][cx + dx]
        if s > best_score:
            best_score, best_x = s, cx
    return best_x / W


def verify_captcha(verify_id: str, position: float):
    r = httpx.post(
        f"{SERVER}/eadrax-coas/v2/cop/verify-captcha",
        json={"position": position, "verifyId": verify_id, "mobile": MOBILE},
        headers={**BASE_HEADERS, **x_headers()},
        timeout=20,
    )
    log(f"[verify] http={r.status_code} body={r.text[:300]}")
    return r


def get_public_key():
    r = httpx.get(
        f"{SERVER}/eadrax-coas/v1/cop/publickey",
        headers={**BASE_HEADERS, **x_headers()},
        timeout=20,
    )
    log(f"[pubkey] http={r.status_code}")
    if r.status_code >= 300:
        return None
    d = r.json()
    # 结构: {"data": {"value": "-----BEGIN PUBLIC KEY-----..."}}
    try:
        return d["data"]["value"]
    except (KeyError, TypeError):
        return d.get("value")


def login(verify_id: str, enc_pwd: str):
    device_id = hashlib.md5(MOBILE.encode()).hexdigest()
    body = {
        "mobile": MOBILE,
        "password": enc_pwd,
        "verifyId": verify_id,
        "deviceId": device_id,
    }
    headers = {
        **BASE_HEADERS,
        **x_headers(),
        "x-login-nonce": generate_cn_nonce(MOBILE),
    }
    r = httpx.post(
        f"{SERVER}/eadrax-coas/v2/login/pwd",
        json=body,
        headers=headers,
        timeout=20,
    )
    log(f"[login ] http={r.status_code}")
    log(f"         body={r.text[:600]}")
    return r


def main() -> int:
    global MOBILE
    MOBILE = normalize_mobile(MOBILE)
    if not MOBILE or not PASSWORD:
        log("[!] 需要 BMW_USERNAME / BMW_PASSWORD 环境变量。")
        return 2

    verify_id = None
    for attempt in range(1, 6):
        log(f"[*] 第 {attempt} 次尝试解滑块...")
        cap = create_captcha()
        if not cap:
            log("[FAIL] create-captcha 失败。")
            return 1
        verify_id = cap.get("verifyId")
        bg_b64 = cap.get("backGroundImg")
        cut_b64 = cap.get("cutImg")

        position = solve_position(bg_b64, cut_b64)
        log(f"[*] 滑块 position={position:.5f} (≈{round(position, 2)})")

        rv = verify_captcha(verify_id, position)
        if rv.status_code >= 300:
            log(f"     被拒,重试 2 位小数 {round(position, 2)}")
            rv = verify_captcha(verify_id, round(position, 2))
        try:
            vcode = rv.json().get("code")
        except Exception:
            vcode = None
        if vcode in (200, "200"):
            log("[PASS] 滑块验证通过。")
            break
        log(f"[retry] 本次未通过 (code={vcode}),重新获取验证码。")
    else:
        log("[FAIL] 5 次都未通过滑块验证。")
        return 1

    pem = get_public_key()
    if not pem:
        log("[FAIL] 拿不到公钥。")
        return 1
    key = RSA.import_key(pem)
    cipher = PKCS1_v1_5.new(key)
    enc_pwd = base64.b64encode(cipher.encrypt(PASSWORD.encode("utf-8"))).decode()
    log(f"[*] 密码已 RSA 加密 (len={len(enc_pwd)})")

    r = login(verify_id, enc_pwd)
    if r.status_code >= 300:
        log("[FAIL] 登录失败。")
        return 1
    try:
        data = r.json().get("data") or {}
        refresh = data.get("refresh_token")
        access = data.get("access_token")
        gcid = data.get("gcid")
    except Exception:
        refresh = access = gcid = None
    if refresh:
        out = {
            "mobile": MOBILE,
            "gcid": gcid,
            "refresh_token": refresh,
            "access_token": access,
        }
        p = os.path.expanduser("~/bimmer/tokens.json")
        with open(p, "w") as f:
            json.dump(out, f, ensure_ascii=False, indent=2)
        os.chmod(p, 0o600)
        log(f"[PASS] 登录成功! token 已保存到 {p}")
        log(f"       gcid={gcid}")
        log(f"       refresh_token={refresh[:20]}...")
        return 0
    log("[FAIL] 响应里没有 refresh_token。")
    return 1


if __name__ == "__main__":
    sys.exit(main())
