import Foundation

/// 远程指令(移植 bimmer_connected/vehicle/remote_services.py 的 Services)。
enum RemoteCommand: String, CaseIterable, Identifiable {
    case lock
    case unlock
    case climateOn
    case climateOff
    case horn
    case light
    case chargeStart
    case chargeStop
    case finder

    var id: String { rawValue }

    var serviceType: String {
        switch self {
        case .lock: return "door-lock"
        case .unlock: return "door-unlock"
        case .climateOn, .climateOff: return "climate-now"
        case .horn: return "horn-blow"
        case .light: return "light-flash"
        case .chargeStart: return "start-charging"
        case .chargeStop: return "stop-charging"
        case .finder: return "vehicle-finder"
        }
    }

    /// 空调 on/off 的 action 参数,其余为 nil。
    var action: String? {
        switch self {
        case .climateOn: return "START"
        case .climateOff: return "STOP"
        default: return nil
        }
    }

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

    var icon: String {
        switch self {
        case .lock: return "lock.fill"
        case .unlock: return "lock.open.fill"
        case .climateOn: return "snowflake"
        case .climateOff: return "sun.max"
        case .horn: return "speaker.wave.2.fill"
        case .light: return "lightbulb.fill"
        case .chargeStart: return "bolt.fill"
        case .chargeStop: return "bolt.slash.fill"
        case .finder: return "mappin.circle.fill"
        }
    }

    /// 是否弹确认框(与 app.py 一致:锁车/解锁/开启空调需要确认)。
    var needsConfirm: Bool {
        switch self {
        case .lock, .unlock, .climateOn: return true
        default: return false
        }
    }

    /// 是否会改变车辆状态(库内对应 refresh=True:执行后需等车辆状态落库再刷新)。
    var refreshesState: Bool {
        switch self {
        case .lock, .unlock, .climateOn, .climateOff, .chargeStart, .chargeStop: return true
        case .horn, .light, .finder: return false
        }
    }

    var confirmDetail: String {
        switch self {
        case .lock: return "将远程锁车。"
        case .unlock: return "将远程解锁车辆,请注意安全。"
        case .climateOn: return "将远程开启空调。"
        default: return ""
        }
    }
}
