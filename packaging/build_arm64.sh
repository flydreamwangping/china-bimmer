#!/bin/bash
# 在 Apple Silicon (arm64) 机器上构建 Bimmer 原生包
# 产出:dist/Bimmer.app(ad-hoc 签名) + Bimmer-arm64.dmg
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> [1/6] 架构自检"
if [ "$(uname -m)" != "arm64" ]; then
  echo "✗ 本机是 $(uname -m),不是 arm64。PyInstaller 无法交叉编译,请在 Apple Silicon 机器上运行本脚本。" >&2
  exit 1
fi
# 确认 Python 本身也是 arm64(避免 homebrew 装了 x86_64 版 Python 跑在 Rosetta 下)
PY=""
for cand in python3.13 python3.12 python3.11 python3; do
  if command -v "$cand" >/dev/null 2>&1; then
    arch="$("$cand" -c 'import platform; print(platform.machine())' 2>/dev/null || true)"
    if [ "$arch" = "arm64" ]; then
      PY="$cand"
      break
    fi
  fi
done
if [ -z "$PY" ]; then
  echo "✗ 没找到 arm64 的 python3(3.11+)。请先安装:" >&2
  echo "   brew install python@3.13   # 安装到 /opt/homebrew(arm64)" >&2
  exit 1
fi
echo "    使用 $PY ($("$PY" --version 2>&1))"

echo "==> [2/6] 源码文件自检"
for f in src/bimmer/app.py src/bimmer/login.py src/bimmer/login_sms.py src/bimmer/geocode.py src/bimmer/config.py packaging/Bimmer.spec packaging/Bimmer.icns packaging/rth_metadata.py requirements.txt pyproject.toml; do
  [ -f "$f" ] || { echo "✗ 缺少 $f" >&2; exit 1; }
done

echo "==> [3/6] 创建独立 venv(arm64)"
rm -rf venv-arm64
"$PY" -m venv venv-arm64
# shellcheck disable=SC1091
source venv-arm64/bin/activate
python -m pip install -q --upgrade pip
python -m pip install -q -r requirements.txt
echo "    关键包架构:"
python -c "import platform; print('      python:', platform.machine())"
# pycryptodome 的原生库(_raw_aes 等)是经 ctypes 加载的 raw lib,不是可 import 的
# Python 模块,直接 import 会报 "does not define module export function"。这里改用
# file 直接查看 .so 的实际架构,确保是 arm64(而不是 Rosetta 下装的 x86_64 版)。
RAW_AES="$(python -c "import Crypto, os; print(os.path.join(os.path.dirname(Crypto.__file__), 'Cipher', '_raw_aes.abi3.so'))")"
if file "$RAW_AES" | grep -q arm64; then
  echo "      Crypto 原生库: arm64 ✓"
else
  echo "✗ pycryptodome 原生库不是 arm64: $(file -b "$RAW_AES")" >&2
  exit 1
fi
python -c "import objc; print('      PyObjC ok')"

echo "==> [4/6] PyInstaller 打包(复用 Bimmer.spec)"
pyinstaller --clean --noconfirm packaging/Bimmer.spec

echo "==> [5/6] 校验产物架构 + ad-hoc 签名"
BIN="dist/Bimmer.app/Contents/MacOS/Bimmer"
arch="$(file -b "$BIN" | grep -o 'arm64' || true)"
if [ "$arch" != "arm64" ]; then
  echo "✗ 产物不是 arm64:$(file -b "$BIN")" >&2
  exit 1
fi
echo "    产物架构: arm64 ✓"
codesign --force --deep --sign - dist/Bimmer.app
codesign --verify --deep --strict dist/Bimmer.app && echo "    签名校验 ✓"

echo "==> [6/6] 生成 dmg"
rm -rf dmg_staging Bimmer-arm64.dmg
mkdir -p dmg_staging
cp -R dist/Bimmer.app dmg_staging/
ln -s /Applications dmg_staging/Applications
hdiutil create -volname "Bimmer" -srcfolder dmg_staging -ov -format UDZO Bimmer-arm64.dmg >/dev/null
rm -rf dmg_staging
ls -lh Bimmer-arm64.dmg

echo ""
echo "✅ 完成。交付物:"
echo "   $ROOT/dist/Bimmer.app   (arm64,ad-hoc 签名)"
echo "   $ROOT/Bimmer-arm64.dmg  (拖拽安装)"
echo "提示:目标机 ~/bimmer/ 仍需手动放 config.json + tokens.json(凭据不打包);config.json 可从 config/config.example.json 复制后填写。"
