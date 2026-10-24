#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""短信验证码登录(忘记密码时用)。

流程:滑块验证 -> 发送短信验证码 -> 手动输入验证码 -> login/sms -> 存 token
用法:BMW_USERNAME='8613...' python3 -m bimmer.login_sms
"""
import hashlib
import json
import os
import sys

import httpx

from bimmer import login


def send_sms_code(verify_id: str):
    device_id = hashlib.md5(login.MOBILE.encode()).hexdigest()
    r = httpx.post(
        f"{login.SERVER}/eadrax-coas/v1/cop/message",
        json={"mobile": login.MOBILE, "deviceId": device_id, "verifyId": verify_id},
        headers={**login.BASE_HEADERS, **login.x_headers()},
        timeout=20,
    )
    print(f"[sms   ] http={r.status_code} body={r.text[:400]}")
    return r


def login_sms(otp_id: str, code: str):
    device_id = hashlib.md5(login.MOBILE.encode()).hexdigest()
    headers = {
        **login.BASE_HEADERS,
        **login.x_headers(),
        "x-login-nonce": login.generate_cn_nonce(login.MOBILE),
    }
    body = {
        "mobile": login.MOBILE,
        "otpId": otp_id,
        "otpMsg": code,
        "deviceId": device_id,
    }
    r = httpx.post(
        f"{login.SERVER}/eadrax-coas/v2/login/sms",
        json=body,
        headers=headers,
        timeout=20,
    )
    print(f"[login ] http={r.status_code}")
    print(f"         body={r.text[:600]}")
    return r


def save_token(data: dict) -> bool:
    refresh = data.get("refresh_token")
    if not refresh:
        return False
    out = {
        "mobile": login.MOBILE,
        "gcid": data.get("gcid"),
        "refresh_token": refresh,
        "access_token": data.get("access_token"),
    }
    p = os.path.expanduser("~/bimmer/tokens.json")
    with open(p, "w") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    os.chmod(p, 0o600)
    print(f"[PASS] 登录成功! token 已保存到 {p}")
    print(f"       gcid={out['gcid']}")
    return True


def solve_captcha() -> str:
    """滑块验证,成功返回 verifyId。"""
    for attempt in range(1, 6):
        print(f"[*] 第 {attempt} 次尝试解滑块...")
        cap = login.create_captcha()
        if not cap:
            continue
        verify_id = cap.get("verifyId")
        pos = login.solve_position(cap.get("backGroundImg"), cap.get("cutImg"))
        print(f"[*] position={pos:.5f}")
        rv = login.verify_captcha(verify_id, pos)
        if rv.status_code >= 300:
            rv = login.verify_captcha(verify_id, round(pos, 2))
        try:
            vcode = rv.json().get("code")
        except Exception:
            vcode = None
        if vcode in (200, "200"):
            print("[PASS] 滑块验证通过。")
            return verify_id
        print(f"[retry] code={vcode}")
    return ""


def main() -> int:
    if not login.MOBILE:
        print("[!] 需要 BMW_USERNAME 环境变量。")
        return 2

    verify_id = solve_captcha()
    if not verify_id:
        print("[FAIL] 滑块验证未通过。")
        return 1

    r = send_sms_code(verify_id)
    otp_id = None
    try:
        d = r.json()
        if d.get("code") not in (200, "200"):
            print("[FAIL] 发送短信失败。")
            return 1
        data = d.get("data") or {}
        otp_id = data.get("otpID") or data.get("otpId")
    except Exception:
        pass
    if not otp_id:
        print("[FAIL] 响应里没有 otpID,请把上面的 body 贴给我。")
        return 1
    print("[*] 验证码已发送,请查收短信(通常 1 分钟内到达)。")

    code = input("请输入短信验证码: ").strip()
    if not code:
        print("[FAIL] 未输入验证码。")
        return 1

    r = login_sms(otp_id, code)
    try:
        data = r.json().get("data") or {}
    except Exception:
        data = {}
    if r.status_code >= 300 or not data.get("refresh_token"):
        print("[FAIL] 短信登录失败,把上面的 body 贴给我。")
        return 1
    save_token(data)
    return 0


if __name__ == "__main__":
    sys.exit(main())
