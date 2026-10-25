import Foundation

/// 车况展示模型(镜像 app.py _fetch 的 d 字典,已格式化为展示文案)。
struct VehicleState {
    var name = "BMW"
    var battery = "—"        // "73%"
    var fuel = "—"           // "30.5 L"
    var rangeElec = "—"      // "42 km"
    var rangeFuel = "—"
    var rangeTotal = "—"
    var mileage = "—"        // 总里程
    var monthKm: Double? = nil
    var charging = "—"       // 中文充电状态
    var chargerConnected = false
    var lock = "—"           // 中文锁状态
    var windowsOpen = false
    var lidsOpen = false
    var lat: Double? = nil
    var lng: Double? = nil
    var address: String? = nil
    var chargeKwh: Double? = nil
    var chargeSessions: Int? = nil
    var chargeSessionsLocal: [ChargeSession] = []
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
    static func km(_ v: Double?) -> String {
        guard let v else { return "—" }
        return "\(Int(v.rounded())) km"
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
