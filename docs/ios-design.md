# Bimmer iOS 前端设计文档

> 原生 SwiftUI 版车况主页 + 远程控制面板,对应 macOS 菜单栏版 [Bimmer](../README.md) 的功能与数据模型。
> 本文是 [frontend-design](../../.agents/skills/frontend-design/SKILL.md) 方法论的两段式产出:先定设计基座与 token,再逐个界面设计,最后自审。

## 一、设计基座

- **题材**:一台**插电混动 BMW**(同时有纯电续航 + 燃油续航)的远程控制 App,替代「Bimmer 控制器」,对接宝马中国区互联驾驶。默认电池容量 9.7 kWh,对应 530Le / X1 PHEV 一类车型。
- **受众**:车主本人,打开就想「一眼看清车况 + 安全下达远程指令」。
- **首要任务**:**信任与清晰**,不是炫技。远程指令(解锁、开空调)会真实作用到车辆,UI 必须把「当前状态」表达零歧义,并把有风险的指令做成「刻意确认」。
- **方向**:车控界面最容易掉进「深色底 + 单一青色/荧光绿点缀」的 AI 模板脸。本设计用 **BMW 经典仪表盘琥珀色背光做身份色**(E30/E36/E46 时代那抹橙色仪表灯),近黑但非纯黑、暖色底 + 暖白文字 —— 这个信号几乎没人用,天然「像车、不像普通 App」。

## 二、设计 Token

### 颜色(暖石墨底 + 琥珀身份色 + 语义色)

| Token | 值 | 用途 |
|---|---|---|
| `bg` | `#0D0C0A` | App 背景(暖黑,非中性 `#0B0B0B`) |
| `surface` | `#16140F` | 卡片/面板 |
| `surface-2` | `#1E1B15` | 可点按的 tile |
| `stroke` | `#2C2820` | 1pt 发丝分隔线(代替阴影) |
| `ink` | `#F4EFE6` | 主文字(暖白,非纯白) |
| `ink-dim` | `#9A9184` | 次要文字 |
| `ink-faint` | `#6B6459` | 三级文字/眉标 |
| `amber` | `#F2A33C` | **身份色**:总续航环形表、激活态控件、主按钮 |
| `amber-bright` | `#FFC164` | 强调:充电发光、选中高亮 |
| `electric` | `#5BA6D6` | **电语义**:纯电续航、充电中、充电枪(BMW i 蓝) |
| `ok-green` | `#5DB886` | **安全**:已锁定、状态正常 |
| `alert-red` | `#E0524B` | **需注意**:已解锁、车窗/门盖开启、错误 |

### 字体

- **读数(续航、电量、百分比)**:SF Mono(`.monospaced`,代码里封装为 `Font.instrument(size:weight:)`),重量 `.medium/.semibold`,等效 DIN 1451 的器械精确感,零打包成本。
- **标签/正文**:SF Pro 系统字体,句首大写,**不用全大写标签**。hero 里的「总里程 / 总续航 / 剩余电量」用 `.caption2` 二级色做标签,不做小字号 + 拉开字距的眉标。

### 布局

- 卡片圆角 **12**(tile 用 10),比流行的 16/24 更「仪表盘」。
- 页面边距 **20pt**;卡片间用 **1pt 发丝线**分隔,**不用每张卡叠一层同样的柔灰阴影**。
- **一个 hero(总续航)独占视觉重心**,其余全部安静。

## 三、状态语义(颜色规则)

> 统一规则:**正常 = `ok-green`,需注意 = `alert-red`**,不再用 `ink-dim` 表达「安全」,避免「灰 = 正常」的歧义。唯一例外是充电枪:插着枪是「该拔了」的提醒,所以用红。

| 状态 | 值 | 颜色 |
|---|---|---|
| 车锁 `SECURED` | 已锁定 | `ok-green` |
| 车锁 `UNLOCKED` / `SELECTIVE` / `SECURED_EXTERNAL` | 已解锁 / 部分锁定 / 外部已锁定 | `alert-red` |
| 车窗关闭 | 车窗已关 | `ok-green` |
| 车窗开启 | 车窗开启 | `alert-red` |
| 门/盖关闭 | 门盖已关 | `ok-green` |
| 门/盖开启 | 门/盖开启 | `alert-red` |
| 充电 `CHARGING` | 充电中 | `electric` |
| 充电 `FINISHED_FULLY_CHARGED` / `CHARGING_COMPLETED` | 已充满 / 充电完成 | `ok-green` |
| 充电枪连接 | 已连接(提醒拔枪) | `alert-red` |
| 充电枪未连接 | 未连接 | `ok-green` |
| 环形电量表 | 正常 / 充电中 | `amber` / `electric` |

## 四、界面设计

### 1. 车辆状态主页(Home)

```
┌─────────────────────────────────┐
│         [车辆渲染图]            │ ← 后端下发 base64 PNG,失败回退剪影
│                                 │
│   ┌───────────────────────────┐ │
│   │ 总里程 18,560 km  [环形 82%]│ │ ← 左:总里程 / 总续航 纵向堆叠
│   │ 总续航 628 km      剩余电量 │ │    右:剩余电量 amber 环形
│   │ ─────────────────────────  │ │
│   │ 电量  油量  纯电  燃油      │ │ ← electric / dim / electric / dim
│   └───────────────────────────┘ │
│   ┌───────────────────────────┐ │
│   │ 🕐 更新时间 xx:xx     ⟳    │ │ ← 状态条头:更新时间 + 刷新按钮
│   │ ─────────────────────────  │ │
│   │ 🔒已锁 车窗已关 已连接 ⚡ 门盖│ │ ← 锁/车窗/充电枪/充电/门盖 一行五项
│   └───────────────────────────┘ │
│   ┌───────────────────────────┐ │
│   │ 📍 上海市浦东新区…       → │ │ ← 位置卡,点开 Apple 地图
│   └───────────────────────────┘ │
│   ┌───────────────────────────┐ │
│   │ 本月数据                    │ │ ← 里程/充电量/充电次数/行程次数 四项
│   └───────────────────────────┘ │
│   ┌───────────────────────────┐ │
│   │ 🗺 行程记录             → │ │ ← 记录入口(不再是 tab)
│   │ ⚡ 充电记录             → │ │
│   └───────────────────────────┘ │
└─────────────────────────────────┘
   [状态]                 [控制]
```

- **数据映射**:`vehicle_image`(base64)/ `name` / `mileage` / `range_total` / `remaining_battery_percent` / `battery_energy_kwh` / `remaining_fuel` / `range_elec` / `range_fuel` / `last_refresh` / `lock` / `windows_open` / `charger_connected` / `charging` / `lids_open` / `address` / `month_km` / `charge_kwh` / `charge_sessions` / `month_trips`。
- **结构**:TabView 两个 tab(「状态」「控制」)。首页依次为车辆图 → hero → 状态条 → 位置卡 → 本月数据 → 记录入口;「行程 / 充电」改由首页底部的记录卡片 `NavigationLink` 进入,不再占用 tab。

### 2. 控制面板(Control)

```
┌─────────────────────────────────┐
│ 远程控制                         │
│   ┌──────────┐  ┌──────────┐   │
│   │ 🔒 锁车  │  │ 🔓 解锁  │   │ ← 解锁/开空调/开始充电 = amber 描边
│   └──────────┘  └──────────┘   │
│   ┌──────────┐  ┌──────────┐   │
│   │ ❄ 开启空调│  │ ♨ 关闭空调│   │
│   └──────────┘  └──────────┘   │
│   ┌──────────┐  ┌──────────┐   │
│   │ 📣 喇叭  │  │ 💡 灯光闪烁│   │
│   └──────────┘  └──────────┘   │
│   ┌──────────┐  ┌──────────┐   │
│   │ 🔌 开始充电│  │ ⏹ 停止充电│   │
│   └──────────┘  └──────────┘   │
│   ┌──────────┐                  │
│   │ 📍 寻车  │                  │ ← 9 项,末行单独一个 tile
│   └──────────┘                  │
└─────────────────────────────────┘
```

### 3. 远程解锁(Unlock —— 交互流程)

1. 点「🔓 解锁」→ 底部弹出**确认 Sheet**:主文案用 `amber`,风险提示用 `alert-red`。
2. 确认后进入**进行中态** → 结果回填顶部通知(成功绿 / 失败红)。
3. 可选增强(未默认实现):长按 1 秒解锁(进度环 + `amber` 填充),更防误触。

### 4. 空调(Climate)

- 关闭态:灰 tile「关闭空调」;开启态:tile 切换 `amber` 高亮。
- 开启走**二次确认**(真实启动耗电);关闭直接执行。

### 5. 灯光(Lights)

- 单 tile「💡 灯光闪烁」,轻确认后调用闪灯(无破坏性),执行中短暂亮起 `amber-bright`,完成后熄灭。

## 五、数据与指令映射

### 远程指令(对应 [app.py:748](../src/bimmer/app.py#L748) `_trigger` 的 method)

| 指令 | 后端 method | 风险 | 交互 |
|---|---|---|---|
| 锁车 | `trigger_remote_door_lock` | 低 | 直接执行 |
| 解锁 | `trigger_remote_door_unlock` | **中** | 二次确认 |
| 开启空调 | `trigger_remote_air_conditioning` | **中** | 二次确认 |
| 关闭空调 | `trigger_remote_air_conditioning_stop` | 低 | 直接执行 |
| 喇叭 | `trigger_remote_horn` | 低 | 直接执行 |
| 灯光闪烁 | `trigger_remote_light_flash` | 低 | 直接执行 |
| 开始充电 | `trigger_charge_start` | **中** | 二次确认 |
| 停止充电 | `trigger_charge_stop` | 低 | 直接执行 |
| 寻车 | `trigger_remote_vehicle_finder` | 低 | 直接执行 |

### 车况字段(对应 [app.py:692](../src/bimmer/app.py#L692) `_fetch` 里的 d 字典)

| 前端字段 | 后端来源 |
|---|---|
| `vehicleImageBase64` | `_fetch` 里 bimmer_connected 车辆渲染图(PNG → base64) |
| `batteryPercent` / `batteryEnergyKwh` | `fuel_and_battery.remaining_battery_percent`(能量值 = 百分比 × `batteryCapacityKwh`) |
| `fuelLiters` | `fuel_and_battery.remaining_fuel` |
| `rangeElectric` / `rangeFuel` / `rangeTotal` | `remaining_range_electric` / `..._fuel` / `..._total` |
| `mileage` / `monthKm` | `v.mileage` / 本地月度统计 `_record_mileage` |
| `charging` | `charging_status` → `CHARGING_STATE` |
| `lock` | `door_lock_state` → `LOCK_STATE` |
| `windowsOpen` / `lidsOpen` | `all_windows_closed` / `all_lids_closed` 取反 |
| `address` / 坐标 | `vehicle_location` + 逆地理编码 |
| `chargeKwh` / `chargeSessions` / `monthTrips` | `/eadrax-chs/v2/charging-statistics` / 行程统计 |
| `lastRefresh` | `_fetch` 拉取时间(状态条「更新时间」) |

## 六、自审(拒绝掉的默认项)

- ❌ 拒绝「近黑 + 荧光绿/朱红单点缀」→ 暖石墨 + **琥珀仪表背光**(来自 BMW 真实仪表灯,非通用审美)。
- ❌ 拒绝「内容切成一堆同圆角卡片 + 每张卡同一柔灰阴影」→ 发丝线分隔、只保留一个 hero。
- ❌ 拒绝「到处 ALL-CAPS 眉标 + A·B·C 圆点分隔」→ 全句首大写,只留一处器械感眉标。
- ❌ 拒绝「解锁做成普通按钮」→ `alert-red`/`amber` 描边 + 二次确认。
- ✅ 保留「电 vs 油」的 PHEV 核心二元:用 `electric` 专属电、`ink-dim` 表油。

## 七、实现范围

SwiftUI 骨架代码在 [ios/](../ios/):设计 token、车况模型、远程指令枚举、首页 + 控制面板 + 二次确认 Sheet,以及行程 / 充电两个记录占位页(首页底部记录卡片进入)。含 `Assets.xcassets` 应用图标(石墨底 + 琥珀圆环 + 琥珀→电蓝闪电)、Mock 数据与预览。当前为纯 UI,网络层留 `TODO` 接入。
