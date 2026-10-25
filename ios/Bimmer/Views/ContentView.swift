import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if let notice = model.notice {
                        Text(notice)
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    statusCard
                    locationCard
                    RemoteCommandsView(model: model)
                    StatsView(model: model)
                }
                .padding()
            }
            .navigationTitle(model.state?.name ?? "Bimmer")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("退出") { model.logout() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await model.fetch() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable { await model.fetch() }
        }
    }

    private var statusCard: some View {
        VStack(spacing: 10) {
            StatRow(label: "🔋 电量", value: model.state?.battery ?? "—")
            StatRow(label: "⛽ 油量", value: model.state?.fuel ?? "—")
            StatRow(label: "🛣 纯电续航", value: model.state?.rangeElec ?? "—")
            StatRow(label: "🛣 燃油续航", value: model.state?.rangeFuel ?? "—")
            StatRow(label: "🛣 总续航", value: model.state?.rangeTotal ?? "—")
            StatRow(label: "📏 总里程", value: mileageText)
            StatRow(label: "🔌 充电", value: chargingText)
            StatRow(label: "🔒 车门", value: lockText)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var locationCard: some View {
        Button {
            if let lat = model.state?.lat, let lng = model.state?.lng {
                GeocodeService.openMaps(lat: lat, lng: lng)
            }
        } label: {
            HStack {
                Image(systemName: "location.fill")
                Text(locationText)
                    .font(.footnote)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private var mileageText: String {
        guard let s = model.state else { return "—" }
        var text = s.mileage
        if let monthKm = s.monthKm {
            text += " · 本月 +\(Int(monthKm.rounded())) km"
        }
        return text
    }

    private var chargingText: String {
        guard let s = model.state else { return "—" }
        let plug = s.chargerConnected ? "充电枪已连接" : "充电枪未连接"
        return "\(s.charging) (\(plug))"
    }

    private var lockText: String {
        guard let s = model.state else { return "—" }
        var text = s.lock
        if s.windowsOpen { text += " · 有车窗开启" }
        if s.lidsOpen { text += " · 有门/盖开启" }
        return text
    }

    private var locationText: String {
        guard let s = model.state else { return "无位置信息" }
        if let addr = s.address, !addr.isEmpty { return addr }
        if let lat = s.lat, let lng = s.lng {
            return String(format: "%.5f, %.5f", lat, lng)
        }
        return "无位置信息"
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).bold()
        }
    }
}
