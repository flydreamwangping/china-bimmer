import SwiftUI

// MARK: - 车锁状态(对应后端 LOCK_STATE)
enum LockState: String {
    case secured = "SECURED"
    case unlocked = "UNLOCKED"
    case selective = "SELECTIVE"
    case securedExternal = "SECURED_EXTERNAL"

    var label: String {
        switch self {
        case .secured: return "已锁定"
        case .unlocked: return "已解锁"
        case .selective: return "部分锁定"
        case .securedExternal: return "外部已锁定"
        }
    }

    /// 需注意的状态(非锁定)标红
    var isAttention: Bool { self != .secured }
}

// MARK: - 充电状态(对应后端 CHARGING_STATE)
enum ChargingState: String {
    case charging = "CHARGING"
    case fullyCharged = "FINISHED_FULLY_CHARGED"
    case completed = "CHARGING_COMPLETED"
    case notCharging = "NOT_CHARGING"
    case error = "ERROR"
    case unknown = "UNKNOWN"

    var label: String {
        switch self {
        case .charging: return "充电中"
        case .fullyCharged: return "已充满"
        case .completed: return "充电完成"
        case .notCharging: return "未充电"
        case .error: return "异常"
        case .unknown: return "未知"
        }
    }

    var color: Color {
        switch self {
        case .error, .unknown: return .alertRed
        default: return .okGreen
        }
    }
}

// MARK: - 车辆状态(对应 app.py `_fetch` 里的 d 字典)
struct VehicleStatus {
    var name = "BMW"
    var vehicleImageBase64: String?     // 车辆图片(后端下发 base64 PNG,解码失败回退剪影)
    var batteryPercent: Int?            // remaining_battery_percent
    var batteryCapacityKwh: Double = 9.7 // 电池可用容量(kWh),用于把百分比换算成能量值
    var fuelLiters: Double?             // remaining_fuel (L)
    var rangeElectric: Double?          // 纯电续航 (km)
    var rangeFuel: Double?              // 燃油续航 (km)
    var rangeTotal: Double?             // 总续航 (km)
    var mileage: Double?                // 总里程 (km)
    var monthKm: Double?                // 本月里程 (km)
    var charging: ChargingState = .unknown
    var chargerConnected = false
    var lock: LockState = .secured
    var windowsOpen = false
    var lidsOpen = false
    var latitude: Double?               // 车辆坐标(WGS-84)
    var longitude: Double?
    var address: String?                // 逆地理编码地址
    var chargeKwh: Double?              // 本月充电量 (kWh)
    var chargeSessions: Int?            // 本月充电次数
    var monthTrips: Int?                // 本月行程次数
    var lastRefresh = Date()

    /// 剩余电量(具体能量值 kWh)= 百分比 × 电池容量
    var batteryEnergyKwh: Double? {
        guard let p = batteryPercent else { return nil }
        return Double(p) / 100.0 * batteryCapacityKwh
    }
}

// MARK: - 远程指令(对应 app.py 的 remote 菜单)
enum RemoteCommand: String, CaseIterable, Identifiable {
    case lock, unlock, climateOn, climateOff, horn, light, chargeStart, chargeStop, finder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lock: return "锁车"
        case .unlock: return "解锁"
        case .climateOn: return "开启空调"
        case .climateOff: return "关闭空调"
        case .horn: return "喇叭"
        case .light: return "灯光闪烁"
        case .chargeStart: return "开始充电"
        case .chargeStop: return "停止充电"
        case .finder: return "寻车"
        }
    }

    var symbol: String {
        switch self {
        case .lock: return "lock.fill"
        case .unlock: return "lock.open.fill"
        case .climateOn: return "snowflake"
        case .climateOff: return "thermometer"
        case .horn: return "speaker.wave.2.fill"
        case .light: return "lightbulb.fill"
        case .chargeStart: return "bolt.fill"
        case .chargeStop: return "bolt.slash.fill"
        case .finder: return "location.fill"
        }
    }

    /// 风险分级:medium = 二次确认,其余直接执行
    var risk: RiskLevel {
        switch self {
        case .unlock, .climateOn, .chargeStart: return .medium
        default: return .low
        }
    }
}

enum RiskLevel {
    case low, medium
}
