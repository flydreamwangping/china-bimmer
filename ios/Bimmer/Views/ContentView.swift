import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TabView {
            HomeView(model: model)
                .tabItem { Label("状态", systemImage: "gauge") }
            RemoteCommandsView(model: model)
                .tabItem { Label("控制", systemImage: "slider.horizontal.3") }
        }
        .tint(Theme.amber)
        .preferredColorScheme(.dark)
    }
}
