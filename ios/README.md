# Bimmer iOS 前端(SwiftUI)

原生 SwiftUI 版车况主页 + 远程控制面板,对应 macOS 菜单栏版的功能与数据模型。
设计文档见 [docs/ios-design.md](../docs/ios-design.md)。

## 运行

1. 直接双击打开 `Bimmer.xcodeproj`(或命令行 `open ios/Bimmer.xcodeproj`)。
2. 选一个 iPhone 模拟器,直接 Run;或在 Xcode 预览里查看 `HomeView` / `ControlPanelView`。

> 最低 iOS 15.6,可装到 iPhone 11(iOS 15.6.1)。真机运行需在 Signing & Capabilities 里选你的 Team。

## 文件

| 文件 | 说明 |
| --- | --- |
| `BimmerApp.swift` | `@main` 入口 + TabView(状态 / 控制)+ 行程 / 充电记录占位页 |
| `Theme.swift` | 设计 token:颜色 / 字体 / 间距(见 docs/ios-design.md) |
| `Models.swift` | 车况模型 + 远程指令枚举(对应 app.py 的数据与 remote 菜单) |
| `MockData.swift` | 预览样例数据(含「需注意」态) |
| `Components.swift` | 环形电量表 / 状态条 / 指令 tile / 卡片容器 |
| `HomeView.swift` | 车辆状态主页(hero / 状态条 / 位置 / 本月数据 / 记录入口) |
| `ControlPanelView.swift` | 远程控制面板(中风险二次确认) |
| `Assets.xcassets` | 应用图标(石墨底 + 琥珀圆环 + 闪电) |

## 接入后端

当前为纯 UI 骨架,车况用 `MockData` 占位。接入真实后端时:

- 车况:把 `RootView.status` 换成网络拉取结果,对应 macOS 版 [app.py:665](../src/bimmer/app.py#L665) 的 `_fetch`。
- 车辆图片:后端 `_fetch` 拉取 bimmer_connected 车辆渲染图(PNG),以 base64 存进 `vehicle_image`,前端 `VehicleStatus.vehicleImageBase64` 解码显示(解码失败显示剪影)。
- 远程指令:把 `ControlPanelView.run(_:)` 换成真实调用,对应 [app.py:748](../src/bimmer/app.py#L748) 的 `_trigger`。
