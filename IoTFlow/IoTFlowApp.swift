import SwiftUI

@main
struct IoTFlowApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .tint(.accentColor)
        }
    }
}
