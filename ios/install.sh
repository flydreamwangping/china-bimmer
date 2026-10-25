#!/usr/bin/env bash
# 把 Bimmer.ipa 安装到已连接的 iPhone(兼容 iOS 15/16/17)
# 前置: iPhone 数据线连 Mac、信任本机、开启开发者模式(设置 → 隐私与安全 → 开发者模式)
set -euo pipefail
cd "$(dirname "$0")"

IPA="${1:-build/export/Bimmer.ipa}"
if [ ! -f "$IPA" ]; then
  echo "未找到 $IPA,请先运行: ./build.sh <TeamID>"
  exit 1
fi

echo "==> 尝试安装 $IPA"

# 1) devicectl(Xcode 15+;仅支持 iOS 17+ 设备)
if command -v xcrun >/dev/null 2>&1 && xcrun devicectl help >/dev/null 2>&1; then
  if xcrun devicectl device install app "$IPA" 2>/dev/null; then
    echo "✅ 已安装(devicectl),到 iPhone 上打开 Bimmer。"
    exit 0
  fi
  echo "devicectl 安装失败(设备可能是 iOS 15/16,devicectl 仅支持 iOS 17+)。"
fi

# 2) ios-deploy(兼容 iOS 15/16/17;brew install ios-deploy)
if command -v ios-deploy >/dev/null 2>&1; then
  if ios-deploy --bundle "$IPA"; then
    echo "✅ 已安装(ios-deploy),到 iPhone 上打开 Bimmer。"
    exit 0
  fi
  echo "ios-deploy 安装失败。"
fi

# 3) Xcode 图形界面兜底(最稳,任意 iOS 版本)
cat <<'EOF'

自动安装失败,用 Xcode 图形界面手动安装(最稳):

1. 打开 Xcode → 菜单 Window → Devices and Simulators(快捷键 ⌘⇧2)
2. 左侧选中你已连接的 iPhone(若提示解锁/信任,在手机上确认)
3. 右侧 "Installed Apps" 区域点 "+",选择本目录下的:
   build/export/Bimmer.ipa
4. 装完后 iPhone 桌面出现 Bimmer。

首次打开若提示「未受信任的开发者」:
   设置 → 通用 → VPN与设备管理 → 开发者 App → 信任 flydreamwangping@gmail.com

也可以装 ios-deploy 后重试: brew install ios-deploy && ./install.sh
EOF
exit 1
