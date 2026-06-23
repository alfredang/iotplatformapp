import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: SessionStore
    @State private var confirmingDelete = false
    @State private var deleting = false
    @State private var deleteError: String?

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
                    if !confirmingDelete {
                        Button(role: .destructive) {
                            withAnimation { confirmingDelete = true }
                        } label: {
                            Label("Delete Account", systemImage: "trash")
                        }
                        .disabled(deleting)
                    } else {
                        Button(role: .destructive) {
                            performDelete()
                        } label: {
                            HStack {
                                Label("Permanently Delete Account", systemImage: "trash.fill")
                                if deleting { Spacer(); ProgressView() }
                            }
                        }
                        .disabled(deleting)
                        Button("Cancel") {
                            withAnimation { confirmingDelete = false }
                        }
                        .disabled(deleting)
                    }
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text(confirmingDelete
                         ? "This permanently deletes your account and all associated data, and signs you out. This action cannot be undone."
                         : "Permanently deletes your IoTFlow account and signs you out. This cannot be undone.")
                }
                Section {
                    LabeledContent("Version", value: appVersion)
                } footer: {
                    Text("IoTFlow — manage devices and monitor telemetry on the go.")
                }
            }
            .navigationTitle("Settings")
            .alert("Couldn't delete account", isPresented: .constant(deleteError != nil)) {
                Button("OK") { deleteError = nil }
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    private func performDelete() {
        deleting = true
        Task {
            do {
                try await session.deleteAccount()
            } catch {
                deleteError = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            }
            deleting = false
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
