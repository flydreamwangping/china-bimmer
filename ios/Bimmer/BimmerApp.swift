import SwiftUI

@main
struct BimmerApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if model.isLoggedIn {
                    ContentView(model: model)
                } else {
                    LoginView(model: model)
                }
            }
            .onAppear { model.start() }
        }
    }
}
