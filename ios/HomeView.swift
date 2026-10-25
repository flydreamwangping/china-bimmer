import SwiftUI
import UIKit

/// 车辆状态主页:一眼看清车况,hero 是总续航。
struct HomeView: View {
    let status: VehicleStatus
    var onRefresh: () -> Void = {}

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    vehicleImage
                    heroCard
                    statusStrip
                    locationCard
                    statsCard
                    recordsMenu
                }
                .padding(.horizontal, Layout.gutter)
                .padding(.vertical, 8)
            }
            .background(Color.bg)
            .navigationTitle(status.name)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - 车辆图片(后端下发 base64 PNG,解码失败回退剪影)
    private var vehicleImage: some View {
        VehicleImage(base64: status.vehicleImageBase64)
    }

    // MARK: - 总览 hero(左:总里程 / 总续航,右:剩余电量)
    private var heroCard: some View {
        SectionCard {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    metricColumn("总里程", status.mileage.map { "\(fmt($0)) km" } ?? "—")
                        .padding([.top, .leading, .trailing], 10.0)
                    metricColumn("总续航", status.rangeTotal.map { "\(fmt($0)) km" } ?? "—")
                        .padding([.leading, .bottom, .trailing], 10.0)
                }

                Spacer()

                VStack(spacing: 6) {
                    Text("剩余电量")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .padding(10.0)
                        .frame(height: nil)
                        .foregroundStyle(Color.inkDim)
                    RingGauge(percent: status.batteryPercent ?? 0,
                              color: status.charging == .charging ? .electric : .amber,
                              diameter: 80)
                }
            }

            Divider().overlay(Color.stroke)

            HStack {
                valueColumn("电量", status.batteryEnergyKwh.map { "\(fmt($0, digits: 1)) kWh" } ?? "—",
                            status.charging == .charging ? .electric : .amber)
                Spacer()
                valueColumn("油量", status.fuelLiters.map { "\(fmt($0, digits: 1)) L" } ?? "—", .inkDim)
                Spacer()
                valueColumn("纯电", status.rangeElectric.map { "\(fmt($0)) km" } ?? "—", .electric)
                Spacer()
                valueColumn("燃油", status.rangeFuel.map { "\(fmt($0)) km" } ?? "—", .inkDim)
            }
        }
    }

    private func metricColumn(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.inkDim)
            Text(value)
                .font(.instrument(24, weight: .semibold))
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func valueColumn(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.inkDim)
            Text(value)
                .font(.instrument(16, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    // MARK: - 状态条(更新时间 + 刷新 + 锁 / 车窗 / 充电枪 / 充电 / 门盖)
    private var statusStrip: some View {
        SectionCard {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundStyle(Color.inkFaint)
                Text("车辆更新时间 \(fmtDate(status.lastRefresh))")
                    .font(.caption)
                    .foregroundStyle(Color.inkDim)
                Spacer()
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.inkDim)
                }
                .buttonStyle(.plain)
            }

            Divider().overlay(Color.stroke)

            HStack(spacing: 8) {
                StatusItem(symbol: status.lock == .secured ? "lock.fill" : "lock.open.fill",
                           label: status.lock.label,
                           color: status.lock.isAttention ? .alertRed : .okGreen)
                StatusItem(symbol: status.windowsOpen ? "rectangle.dashed" : "rectangle.on.rectangle",
                           label: status.windowsOpen ? "车窗开启" : "车窗已关",
                           color: status.windowsOpen ? .alertRed : .okGreen)
                StatusItem(symbol: status.chargerConnected ? "bolt.circle.fill" : "bolt.circle",
                           label: status.chargerConnected ? "已连接" : "未连接",
                           color: status.chargerConnected ? .alertRed : .okGreen)
                StatusItem(symbol: "bolt.fill",
                           label: status.charging.label,
                           color: status.charging.color)
                StatusItem(symbol: "car.fill",
                           label: status.lidsOpen ? "门盖开启" : "门盖已关",
                           color: status.lidsOpen ? .alertRed : .okGreen)
            }
        }
    }

    // MARK: - 位置卡(点开 Apple 地图)
    private var locationCard: some View {
        Button { openInMaps() } label: {
            SectionCard {
                HStack(spacing: 10) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(Color.amber)
                    Text(status.address ?? "无位置信息")
                        .font(.subheadline)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(Color.inkFaint)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 本月数据(里程 / 充电量 / 充电次数 / 行程次数)
    private var statsCard: some View {
        SectionCard {
            Text("本月数据")
                .font(.caption2.weight(.semibold))
                .multilineTextAlignment(.leading)
                .foregroundStyle(Color.inkFaint)

            HStack(spacing: 8) {
                stat("里程", status.monthKm.map { "\(fmt($0)) km" } ?? "—")
                stat("充电量", status.chargeKwh.map { "\(fmt($0)) kWh" } ?? "—")
                stat("充电次数", status.chargeSessions.map { "\($0) 次" } ?? "—")
                stat("行程次数", status.monthTrips.map { "\($0) 次" } ?? "—")
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.inkDim)
            Text(value)
                .font(.instrument(14, weight: .semibold))
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 记录入口(行程 / 充电,点击进入)
    private var recordsMenu: some View {
        SectionCard {
            NavigationLink { TripRecordsView() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "map")
                        .foregroundStyle(Color.amber)
                    Text("行程记录")
                        .font(.subheadline)
                        .foregroundStyle(Color.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(Color.inkFaint)
                }
            }
            .buttonStyle(.plain)

            Divider().overlay(Color.stroke)

            NavigationLink { ChargingRecordsView() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(Color.amber)
                    Text("充电记录")
                        .font(.subheadline)
                        .foregroundStyle(Color.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(Color.inkFaint)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func openInMaps() {
        guard let lat = status.latitude, let lng = status.longitude else { return }
        if let url = URL(string: "https://maps.apple.com/?ll=\(lat),\(lng)&q=我的车") {
            UIApplication.shared.open(url)
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HomeView(status: .sample)
                .previewDisplayName("正常")
            HomeView(status: .chargingSample)
                .previewDisplayName("需注意态")
        }
    }
}
