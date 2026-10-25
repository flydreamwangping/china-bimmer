import SwiftUI

@main
struct BimmerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark) // 本设计是固定暗色体系
                .tint(.amber)
        }
    }
}

/// 两个 tab:「状态」与「控制」。
struct RootView: View {
    @State private var status = VehicleStatus.sample

    var body: some View {
        TabView {
            HomeView(status: status) { refresh() }
                .tabItem { Label("状态", systemImage: "car.fill") }

            ControlPanelView()
                .tabItem { Label("控制", systemImage: "switch.2") }
        }
    }

    private func refresh() {
        // TODO: 接入后端,拉取最新车况(对应 macOS 版 app.py 的 `_fetch`)。
    }
}

/// 行程记录(占位:接入后端后展示行程列表)
struct TripRecordsView: View {
    var body: some View {
        ScrollView {
            RecordsEmptyState(text: "暂无行程记录")
                .padding(Layout.gutter)
        }
        .background(Color.bg)
        .navigationTitle("行程记录")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 充电记录(占位:接入后端后展示充电列表)
struct ChargingRecordsView: View {
    var body: some View {
        ScrollView {
            RecordsEmptyState(text: "暂无充电记录")
                .padding(Layout.gutter)
        }
        .background(Color.bg)
        .navigationTitle("充电记录")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 记录页空态
struct RecordsEmptyState: View {
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color.inkFaint)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.inkDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
}
