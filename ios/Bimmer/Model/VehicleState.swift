import Foundation

/// 车况展示模型(镜像 app.py _fetch 的 d 字典)。
/// 同时保留「已格式化文案」与「原始数值」(供 hero 环形 / 大字 / 语义色使用)。
struct VehicleState {
    var name = "BMW"

    // 已格式化文案
    var battery = "—"        // "73%"
    var fuel = "—"           // "30.5 L"
    var rangeElec = "—"      // "42 km"
    var rangeFuel = "—"
    var rangeTotal = "—"
    var mileage = "—"

    // 原始数值
    var batteryPercent: Int? = nil
    var batteryEnergyKwh: Double? = nil
    var fuelLitersValue: Double? = nil
    var rangeElecValue: Double? = nil
    var rangeFuelValue: Double? = nil
    var rangeTotalValue: Double? = nil
    var mileageValue: Double? = nil

    var monthKm: Double? = nil
    var charging = "—"       // 中文充电状态
    var chargerConnected = false
    var lock = "—"           // 中文锁状态
    var lockRaw: String? = nil
    var chargingRaw: String? = nil
    var windowsOpen = false
    var lidsOpen = false
    var lat: Double? = nil
    var lng: Double? = nil
    var address: String? = nil
    var chargeKwh: Double? = nil
    var chargeSessions: Int? = nil
    var chargeSessionsLocal: [ChargeSession] = []
    var lastRefresh: Date? = nil
    var vehicleImageBase64: String? = nil
}

/// 状态语义色(见 docs/ios-design.md「状态语义」)。
extension VehicleState {
    var lockTone: StatusTone {
        switch lockRaw {
        case "SECURED", "LOCKED": return .ok
        case "UNLOCKED", "SELECTIVE", "SECURED_EXTERNAL": return .alert
        default: return .neutral
        }
    }
    var windowsTone: StatusTone { windowsOpen ? .alert : .ok }
    var lidsTone: StatusTone { lidsOpen ? .alert : .ok }
    // 充电枪:插着枪是「该拔了」的提醒,故用红(设计文档唯一例外)。
    var chargerTone: StatusTone { chargerConnected ? .alert : .ok }
    var chargingTone: StatusTone {
        switch chargingRaw {
        case "CHARGING": return .electric
        case "FINISHED_FULLY_CHARGED", "FULLY_CHARGED", "CHARGING_COMPLETED", "COMPLETE": return .ok
        default: return .neutral
        }
    }
}

/// 本地充电会话记录(app.py _track_charging)。
struct ChargeSession: Codable, Identifiable {
    var start: String
    var end: String
    var startSoc: Double?
    var endSoc: Double?
    var kwh: Double?

    var id: String { "\(start)-\(end)-\(String(describing: kwh))" }
}

enum VehicleFormat {
    /// 默认电池容量 kWh(设计文档:530Le / X1 PHEV 一类插电混动)。
    static let batteryCapacityKwh = 9.7

    static func km(_ v: Double?) -> String {
        guard let v else { return "—" }
        return "\(Int(v.rounded())) km"
    }

    static func kmGrouped(_ v: Double?) -> String {
        guard let v else { return "—" }
        let n = Int(v.rounded())
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return "\(f.string(from: NSNumber(value: n)) ?? "\(n)") km"
    }

    static func liters(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%.1f L", v)
    }

    // 移植 app.py LOCK_STATE / CHARGING_STATE(补了几个库里的枚举值)。
    static let lockStates: [String: String] = [
        "SECURED": "已锁定",
        "LOCKED": "已锁定",
        "UNLOCKED": "已解锁",
        "SELECTIVE": "部分锁定",
        "SELECTIVE_LOCKED": "部分锁定",
        "PARTIALLY_LOCKED": "部分锁定",
        "SECURED_EXTERNAL": "外部已锁定",
    ]

    static let chargingStates: [String: String] = [
        "CHARGING": "充电中",
        "FINISHED_FULLY_CHARGED": "已充满",
        "FULLY_CHARGED": "已充满",
        "CHARGING_COMPLETED": "充电完成",
        "COMPLETE": "充电完成",
        "NOT_CHARGING": "未充电",
        "INVALID": "未充电",
        "PLUGGED_IN": "已插枪",
        "WAITING_FOR_CHARGING": "等待充电",
        "TARGET_REACHED": "已达到目标",
        "ERROR": "异常",
    ]
}
