# Bimmer iOS 版(原生 SwiftUI)

宝马中国区互联驾驶 App 的 iOS 移植版:短信验证码登录(自动解滑块)+ 车况查看 + 8 项远程控制 + 定位/地图 + 里程/充电统计。

> 最低部署目标 iOS 15.0,可装到 iPhone 11(iOS 15.6.1)。

## 构建与安装

工程用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 生成(`project.yml` → `Bimmer.xcodeproj`),免费 Apple ID 签名(7 天重签一次)。

```bash
# 1. 生成工程
xcodegen generate

# 2. 构建并导出 .ipa(默认 org.china.bimmer.app,DEVELOPMENT_TEAM 在 build.sh 里填)
./build.sh

# 3. 安装到已连接的真机(iOS 17+ 用 devicectl,15/16 用 ios-deploy 或 Xcode 拖拽)
./install.sh
```

## 目录结构

| 路径 | 说明 |
| --- | --- |
| `project.yml` | XcodeGen 配置(部署目标 / bundle id / AppIcon / 签名) |
| `Bimmer/AppModel.swift` | 登录态、车况、远程指令编排(60s 轮询 + token 自动刷新) |
| `Bimmer/BimmerApp.swift` | `@main` 入口 |
| `Bimmer/Model/` | Token、车况模型、远程指令枚举 |
| `Bimmer/Net/` | 请求头生成、nonce、滑块求解、URLSession 客户端 |
| `Bimmer/Service/` | 登录/车况/远程指令编排、GCJ-02→WGS-84、逆地理、本地统计 |
| `Bimmer/Views/` | 车况主页 / 登录 / 远程控制 / 统计 |
| `Assets.xcassets` | 应用图标(石墨底 + 琥珀圆环 + 闪电) |

设计文档见 [docs/ios-design.md](../docs/ios-design.md)。
