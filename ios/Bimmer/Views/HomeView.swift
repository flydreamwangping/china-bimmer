import SwiftUI

/// 车辆状态主页(见 docs/ios-design.md「车辆状态主页」)。
struct HomeView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    vehicleImageView

                    if let notice = model.notice {
                        NoticeBanner(text: notice)
                    }

                    heroCard
                    statusCard
                    locationCard
                    monthCard
                    recordsCard
                }
                .padding(Theme.pageMargin)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle(model.state?.name ?? "Bimmer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("退出") { model.logout() }
                        .foregroundColor(Theme.inkDim)
                }
            }
            .refreshable { await model.fetch() }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - 车辆渲染图

    private var vehicleImageView: some View {
        ZStack {
            if let ui = vehicleUIImage {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "car.fill")
                    .font(.system(size: 64))
                    .foregroundColor(Theme.inkFaint)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
    }

    private var vehicleUIImage: UIImage? {
        guard let b = model.state?.vehicleImageBase64,
              let d = Data(base64Encoded: b) else { return nil }
        return UIImage(data: d)
    }

    // MARK: - hero(总续航独占视觉重心)

    private var heroCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HeroStat(label: "总里程", value: VehicleFormat.kmGrouped(model.state?.mileageValue))
                    HeroStat(label: "总续航", value: VehicleFormat.kmGrouped(model.state?.rangeTotalValue))
                }
                Spacer()
                BatteryRing(percent: batteryPercent, isCharging: isCharging)
            }

            HairlineDivider().padding(.vertical, 14)

            HStack(spacing: 8) {
                MiniStat(label: "电量", value: energyText, color: Theme.electric)
                MiniStat(label: "油量", value: model.state?.fuel ?? "—", color: Theme.inkDim)
                MiniStat(label: "纯电", value: model.state?.rangeElec ?? "—", color: Theme.electric)
                MiniStat(label: "燃油", value: model.state?.rangeFuel ?? "—", color: Theme.inkDim)
            }
        }
        .cardStyle()
    }

    private var batteryPercent: Double {
        Double(model.state?.batteryPercent ?? 0)
    }

    private var isCharging: Bool {
        model.state?.chargingRaw == "CHARGING"
    }

    private var energyText: String {
        if let kwh = model.state?.batteryEnergyKwh {
            return String(format: "%.1f kWh", kwh)
        }
        return model.state?.battery ?? "—"
    }

    // MARK: - 状态条

    private var statusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Label("更新时间 \(refreshText)", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(Theme.inkFaint)
                Spacer()
                Button {
                    Task { await model.fetch() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(Theme.amber)
                }
            }

            HairlineDivider()

            if let s = model.state {
                HStack(spacing: 8) {
                    StatusChip(icon: s.lockTone == .ok ? "lock.fill" : "lock.open.fill",
                               label: s.lock, tone: s.lockTone)
                    StatusChip(icon: "rectangle.split.2x2",
                               label: s.windowsOpen ? "车窗开启" : "车窗已关", tone: s.windowsTone)
                    StatusChip(icon: "powerplug",
                               label: s.chargerConnected ? "已插枪" : "充电枪未连接", tone: s.chargerTone)
                    StatusChip(icon: "bolt.fill", label: s.charging, tone: s.chargingTone)
                    StatusChip(icon: "car.fill",
                               label: s.lidsOpen ? "门盖开启" : "门盖已关", tone: s.lidsTone)
                }
            }
        }
        .cardStyle()
    }

    private var refreshText: String {
        guard let d = model.state?.lastRefresh else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    // MARK: - 位置卡

    private var locationCard: some View {
        Button {
            if let lat = model.state?.lat, let lng = model.state?.lng {
                GeocodeService.openMaps(lat: lat, lng: lng)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "location.fill").foregroundColor(Theme.amber)
                Text(locationText)
                    .font(.footnote)
                    .foregroundColor(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.inkFaint)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var locationText: String {
        guard let s = model.state else { return "无位置信息" }
        if let addr = s.address, !addr.isEmpty { return addr }
        if let lat = s.lat, let lng = s.lng {
            return String(format: "%.5f, %.5f", lat, lng)
        }
        return "无位置信息"
    }

    // MARK: - 本月数据

    private var monthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本月数据")
                .font(.subheadline)
                .foregroundColor(Theme.inkFaint)
            HStack(spacing: 8) {
                MiniStat(label: "本月里程", value: VehicleFormat.kmGrouped(model.state?.monthKm), color: Theme.ink)
                MiniStat(label: "本月充电", value: kwhText, color: Theme.electric)
                MiniStat(label: "充电次数", value: sessionsText, color: Theme.ink)
            }
        }
        .cardStyle()
    }

    private var kwhText: String {
        guard let kwh = model.state?.chargeKwh else { return "—" }
        return String(format: "%.1f kWh", kwh)
    }

    private var sessionsText: String {
        guard let n = model.state?.chargeSessions else { return "—" }
        return "\(n) 次"
    }

    // MARK: - 记录入口

    private var recordsCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                StatsView(model: model)
            } label: {
                recordRow(icon: "bolt.fill", title: "充电记录", color: Theme.electric)
            }
            .buttonStyle(.plain)

            HairlineDivider()

            NavigationLink {
                TripsPlaceholderView()
            } label: {
                recordRow(icon: "map.fill", title: "行程记录", color: Theme.amber)
            }
            .buttonStyle(.plain)
        }
        .background(Theme.surface)
        .cornerRadius(Theme.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

    private func recordRow(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(color).frame(width: 24)
            Text(title).foregroundColor(Theme.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Theme.inkFaint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

/// 行程记录占位页(现有后端无行程统计,见设计文档「接入后端」说明)。
struct TripsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "map")
                .font(.largeTitle)
                .foregroundColor(Theme.inkFaint)
            Text("暂无行程记录")
                .foregroundColor(Theme.inkDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("行程记录")
    }
}
