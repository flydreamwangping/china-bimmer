#!/usr/bin/env bash
# 构建 Bimmer iOS App 并导出 .ipa(免费 Apple ID 签名,7 天有效期)
# 用法:
#   ./build.sh <你的TeamID>
#   TEAM_ID=XXXXXXXXXX ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

TEAM_ID="${TEAM_ID:-${1:-}}"
if [ -z "$TEAM_ID" ]; then
  echo "用法: ./build.sh <TeamID>"
  echo "TeamID 查看: Xcode → Settings → Accounts → 你的 Apple ID → Personal Team 括号里那串 10 位字符。"
  exit 1
fi

BUNDLE_ID="org.china.bimmer.app"
SCHEME="Bimmer"
CONFIG="Release"
DERIVED="build"
ARCHIVE="$DERIVED/Bimmer.xcarchive"
EXPORT_DIR="$DERIVED/export"
IPA="$EXPORT_DIR/Bimmer.ipa"

command -v xcodegen >/dev/null 2>&1 || { echo "缺少 xcodegen,请先安装: brew install xcodegen"; exit 1; }
command -v xcodebuild >/dev/null 2>&1 || { echo "缺少 xcodebuild,请先安装 Xcode 并执行: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"; exit 1; }

echo "==> 生成 Xcode 工程"
xcodegen generate

echo "==> 归档 (TeamID: $TEAM_ID)"
xcodebuild archive \
  -project Bimmer.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -archivePath "$ARCHIVE" \
  -destination "generic/platform=iOS" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  -allowProvisioningUpdates

echo "==> 写入导出配置 (TeamID)"
/usr/libexec/PlistBuddy -c "Set :teamID $TEAM_ID" ExportOptions.plist

echo "==> 导出 .ipa"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates

echo ""
echo "✅ 完成: $IPA"
echo "下一步: ./install.sh   (iPhone 已数据线连接并信任后执行)"
