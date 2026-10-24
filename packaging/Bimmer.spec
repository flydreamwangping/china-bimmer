# -*- mode: python ; coding: utf-8 -*-
# PyInstaller 打包配置:自包含 Bimmer.app(菜单栏宝马互联驾驶)
import os

# 项目根目录 = packaging/ 的上一级(而非 ~/bimmer 运行时数据目录)
ROOT = os.path.dirname(os.path.abspath(SPECPATH))
SRC = os.path.join(ROOT, "src")

block_cipher = None

a = Analysis(
    [os.path.join(SRC, "bimmer", "app.py")],
    pathex=[SRC],
    binaries=[],
    datas=[],
    hiddenimports=[
        # 本地模块(函数内 import 也能被静态分析抓到,这里显式声明更稳)
        "bimmer.app",
        "bimmer.login",
        "bimmer.login_sms",
        "bimmer.geocode",
        # bimmer_connected 中国区用 importlib.import_module("PIL.Image") 动态导入
        "PIL",
        "PIL.Image",
        # pycryptodome(bimmer_connected 与 bimmer.login 均用)
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
    runtime_hooks=[os.path.join(ROOT, "packaging", "rth_metadata.py")],
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
    icon=os.path.join(ROOT, "packaging", "Bimmer.icns"),
    bundle_identifier="com.wangping.bimmer",
    info_plist={
        "CFBundleName": "Bimmer",
        "CFBundleDisplayName": "Bimmer",
        "CFBundleShortVersionString": "1.0.1",
        "CFBundleVersion": "1.0.1",
        "LSUIElement": True,
        "NSHighResolutionCapable": True,
        "LSMinimumSystemVersion": "12.0",
    },
)
