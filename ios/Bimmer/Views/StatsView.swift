import SwiftUI

/// 充电记录页(首页「充电记录」入口进入):本月官方统计 + 本地充电会话。
struct StatsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let s = model.state {
                    VStack(spacing: 12) {
                        StatRow(label: "本月充电", value: kwhText(s), color: Theme.electric)
                        StatRow(label: "充电次数", value: sessionsText(s), color: Theme.ink)
                    }
                    .cardStyle()

                    let local = Array(s.chargeSessionsLocal.suffix(10)).reversed()
                    if !local.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("本地充电记录")
                                .font(.subheadline)
                                .foregroundColor(Theme.inkFaint)
                            ForEach(local) { session in
                                Text(sessionText(session))
                                    .font(.footnote)
                                    .foregroundColor(Theme.inkDim)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                    }
                } else {
                    Text("暂无数据")
                        .foregroundColor(Theme.inkDim)
                }
            }
            .padding(Theme.pageMargin)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("充电记录")
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
