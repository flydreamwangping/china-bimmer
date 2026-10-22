# -*- mode: python ; coding: utf-8 -*-
# PyInstaller 打包配置:自包含 Bimmer.app(菜单栏宝马互联驾驶)
import os

ROOT = os.path.expanduser("~/bimmer")

block_cipher = None

a = Analysis(
    [os.path.join(ROOT, "bimmer_app.py")],
    pathex=[ROOT],
    binaries=[],
    datas=[],
    hiddenimports=[
        # 本地模块(函数内 import 也能被静态分析抓到,这里显式声明更稳)
        "cn_login",
        "cn_login_sms",
        "geocode",
        # bimmer_connected 中国区用 importlib.import_module("PIL.Image") 动态导入
        "PIL",
        "PIL.Image",
        # pycryptodome(bimmer_connected 与 cn_login 均用)
        "Crypto",
        "Crypto.Cipher",
        "Crypto.Cipher.AES",
        "Crypto.Cipher.PKCS1_v1_5",
        "Crypto.PublicKey",
        "Crypto.PublicKey.RSA",
        "Crypto.Hash",
        "Crypto.Hash.SHA256",
        "Crypto.Random",
        "Crypto.Util.Padding",
        # 其它
        "jwt",
        "httpx",
        "rumps",
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[os.path.join(ROOT, "rth_metadata.py")],
    excludes=[
        "tkinter",
        "unittest",
        "pydoc",
        "doctest",
        "test",
        "PyQt5",
        "PyQt6",
        "PySide2",
        "PySide6",
    ],
    noarchive=False,
    optimize=0,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="Bimmer",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,  # 菜单栏 app,无控制台窗口
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name="Bimmer",
)

app = BUNDLE(
    coll,
    name="Bimmer.app",
    icon=os.path.join(ROOT, "Bimmer.icns"),
    bundle_identifier="com.wangping.bimmer",
    info_plist={
        "CFBundleName": "Bimmer",
        "CFBundleDisplayName": "Bimmer",
        "CFBundleShortVersionString": "1.0.0",
        "CFBundleVersion": "1.0.0",
        "LSUIElement": True,
        "NSHighResolutionCapable": True,
        "LSMinimumSystemVersion": "12.0",
    },
)
