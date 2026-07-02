import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        Group {
            switch session.state {
            case .loading:
                ProgressView("Loading…")
                    .controlSize(.large)
            case .signedOut:
                LoginView()
            case .signedIn:
                MainTabView()
            }
        }
        .animation(.default, value: isSignedIn)
        .task {
            if case .loading = session.state {
                await session.restore()
            }
        }
    }

    private var isSignedIn: Bool {
        if case .signedIn = session.state { return true }
        return false
    }
}

struct MainTabView: View {
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2.fill") }
                .tag(0)
            DevicesView()
                .tabItem { Label("Devices", systemImage: "cpu.fill") }
                .tag(1)
            AutomationsView()
                .tabItem { Label("Automations", systemImage: "bolt.horizontal.fill") }
                .tag(2)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(3)
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-showAddDevice") {
                tab = 1
            }
        }
        // Ask for notification permission and start polling for new alerts.
        .task {
            await NotificationManager.shared.requestAuthorization()
            await NotificationManager.shared.startPolling()
        }
    }
}
