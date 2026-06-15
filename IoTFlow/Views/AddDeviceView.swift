import SwiftUI

struct AddDeviceView: View {
    var onAdded: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type = ""
    @State private var location = ""
    @State private var proto: DeviceProtocol = .HTTP
    @State private var busy = false
    @State private var error: String?
    @State private var created: CreateDeviceResponse?

    var body: some View {
        NavigationStack {
            Form {
                if let created {
                    successSection(created)
                } else {
                    Section("Device") {
                        TextField("Name (e.g. Living Room Sensor)", text: $name)
                            .textInputAutocapitalization(.words)
                        TextField("Type (e.g. Temperature)", text: $type)
                        TextField("Location (optional)", text: $location)
                    }
                    Section("Connection") {
                        Picker("Protocol", selection: $proto) {
                            ForEach(DeviceProtocol.allCases) { p in
                                Text(p.label).tag(p)
                            }
                        }
                    }
                    if let error {
                        Section { Text(error).foregroundStyle(.red).font(.footnote) }
                    }
                }
            }
            .navigationTitle(created == nil ? "Add Device" : "Device Added")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(created == nil ? "Cancel" : "Done") {
                        if created != nil { onAdded() }
                        dismiss()
                    }
                }
                if created == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") { add() }
                            .disabled(name.isEmpty || busy)
                    }
                }
            }
            .overlay {
                if busy { ProgressView().controlSize(.large) }
            }
        }
    }

    @ViewBuilder
    private func successSection(_ c: CreateDeviceResponse) -> some View {
        Section {
            HStack {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("\(c.device.name) is ready to connect.")
            }
        }
        Section("Device ID") {
            Text(c.device.deviceId).font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
        Section {
            Text(c.token)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
            Button {
                UIPasteboard.general.string = c.token
            } label: {
                Label("Copy token", systemImage: "doc.on.doc")
            }
        } header: {
            Text("Device Token")
        } footer: {
            Text("Save this token now — it is shown only once. Devices send telemetry to /api/telemetry using this token.")
        }
    }

    private func add() {
        busy = true
        error = nil
        Task {
            do {
                created = try await APIClient.shared.createDevice(
                    name: name, type: type,
                    location: location.isEmpty ? nil : location, proto: proto)
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            busy = false
        }
    }
}
