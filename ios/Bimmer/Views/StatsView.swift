import SwiftUI

struct StatsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本月统计").font(.headline)

            if let s = model.state {
                StatRow(label: "⚡ 本月充电", value: kwhText(s))
                StatRow(label: "🔌 充电次数", value: sessionsText(s))

                let local = Array(s.chargeSessionsLocal.suffix(8)).reversed()
                if !local.isEmpty {
                    Text("本地充电记录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    ForEach(local) { session in
                        Text(sessionText(session))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("暂无数据").foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func kwhText(_ s: VehicleState) -> String {
        guard let kwh = s.chargeKwh else { return "—" }
        return String(format: "%.1f kWh", kwh)
    }

    private func sessionsText(_ s: VehicleState) -> String {
        guard let n = s.chargeSessions else { return "—" }
        return "\(n) 次"
    }

    private func sessionText(_ s: ChargeSession) -> String {
        var parts = ["\(short(s.start)) → \(short(s.end))"]
        if let startSoc = s.startSoc, let endSoc = s.endSoc {
            parts.append("\(Int(startSoc))%→\(Int(endSoc))%")
        }
        if let kwh = s.kwh {
            parts.append("≈\(kwh) kWh")
        }
        return parts.joined(separator: "  ")
    }

    private func short(_ iso: String) -> String {
        let inFmt = ISO8601DateFormatter()
        inFmt.formatOptions = [.withInternetDateTime]
        guard let date = inFmt.date(from: iso) else { return iso }
        let outFmt = DateFormatter()
        outFmt.locale = Locale(identifier: "en_US_POSIX")
        outFmt.dateFormat = "MM-dd HH:mm"
        return outFmt.string(from: date)
    }
}
