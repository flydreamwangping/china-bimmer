import Foundation

/// 本地月度里程 + 充电会话累计(移植 app.py _record_mileage / _track_charging)。
/// 数据存 UserDefaults(JSON)。
enum StatsStore {
    static let batteryCapacityKwh = 9.7  // 与 macOS config.json 默认一致

    private static let defaults = UserDefaults.standard
    private static let mileageKey = "monthly_mileage"
    private static let chargeKey = "charge_stats"

    private struct MonthlyStats: Codable {
        var startKm: Double = 0
        var lastKm: Double = 0
    }

    private struct ChargeArchive: Codable {
        var sessions: [ChargeSession] = []
        var active: ActiveCharge? = nil
    }

    private struct ActiveCharge: Codable {
        var start: String
        var startSoc: Double?
    }

    private static func monthKey() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM"
        return f.string(from: Date())
    }

    private static func nowIso() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: Date())
    }

    /// 记录总里程,返回本月累计(km);数据无效返回 nil。
    static func recordMileage(_ km: Double) -> Double? {
        var all: [String: MonthlyStats] = [:]
        if let data = defaults.data(forKey: mileageKey),
           let decoded = try? JSONDecoder().decode([String: MonthlyStats].self, from: data) {
            all = decoded
        }
        let key = monthKey()
        var m = all[key] ?? MonthlyStats(startKm: km)
        m.lastKm = km
        all[key] = m
        if let data = try? JSONEncoder().encode(all) {
            defaults.set(data, forKey: mileageKey)
        }
        return ((km - m.startKm) * 10).rounded() / 10
    }

    /// 检测充电会话起止,返回最近会话列表(最近 30 条)。
    static func trackCharging(status: String, soc: Double?) -> [ChargeSession] {
        var archive = ChargeArchive()
        if let data = defaults.data(forKey: chargeKey),
           let decoded = try? JSONDecoder().decode(ChargeArchive.self, from: data) {
            archive = decoded
        }
        let now = nowIso()

        if status == "CHARGING" {
            if archive.active == nil {
                archive.active = ActiveCharge(start: now, startSoc: soc)
            }
        } else if let active = archive.active {
            var kwh: Double? = nil
            if let startSoc = active.startSoc, let soc {
                let delta = max(0, soc - startSoc)
                kwh = (delta / 100.0 * batteryCapacityKwh * 100).rounded() / 100
            }
            archive.sessions.append(ChargeSession(
                start: active.start, end: now,
                startSoc: active.startSoc, endSoc: soc, kwh: kwh
            ))
            if archive.sessions.count > 30 {
                archive.sessions = Array(archive.sessions.suffix(30))
            }
            archive.active = nil
        }

        if let data = try? JSONEncoder().encode(archive) {
            defaults.set(data, forKey: chargeKey)
        }
        return archive.sessions
    }
}
