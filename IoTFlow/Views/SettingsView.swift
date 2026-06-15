import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if let user = session.user {
                        LabeledContent("Name", value: user.name ?? "—")
                        LabeledContent("Email", value: user.email ?? "—")
                        if let role = user.role {
                            LabeledContent("Role", value: role.capitalized)
                        }
                    }
                }
                Section("Connection") {
                    NavigationLink {
                        ServerSettingsView()
                    } label: {
                        Label("Server", systemImage: "server.rack")
                    }
                }
                Section {
                    Button(role: .destructive) {
                        Task { await session.logout() }
                    } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
                Section {
                    LabeledContent("Version", value: appVersion)
                } footer: {
                    Text("IoTFlow — manage devices and monitor telemetry on the go.")
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

struct ServerSettingsView: View {
    @AppStorage("serverURL") private var serverURL = AppConfig.defaultServer
    @State private var draft = ""

    var body: some View {
        Form {
            Section {
                TextField("https://iot.example.com", text: $draft)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Server URL")
            } footer: {
                Text("Point the app at your self-hosted IoTFlow instance. Defaults to the public platform.")
            }
            Section {
                Button("Save") {
                    var v = draft.trimmingCharacters(in: .whitespaces)
                    if v.hasSuffix("/") { v.removeLast() }
                    if !v.isEmpty { serverURL = v }
                }
                Button("Reset to default") {
                    serverURL = AppConfig.defaultServer
                    draft = serverURL
                }
            }
        }
        .navigationTitle("Server")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { draft = serverURL }
    }
}
