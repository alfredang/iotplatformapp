import SwiftUI

struct DeviceDetailView: View {
    let device: Device

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    StatusPill(online: device.statusEnum == .ONLINE)
                }
                row("Device ID", device.deviceId, mono: true)
                row("Protocol", device.proto ?? "HTTP")
                if let type = device.type { row("Type", type) }
                if let loc = device.location, !loc.isEmpty { row("Location", loc) }
                row("Telemetry points", "\(device.telemetryCount)")
                if let last = device.lastSeen {
                    HStack {
                        Text("Last seen"); Spacer()
                        Text(last, style: .relative).foregroundStyle(.secondary)
                    }
                }
                if let created = device.createdAt {
                    HStack {
                        Text("Added"); Spacer()
                        Text(created, style: .date).foregroundStyle(.secondary)
                    }
                }
            }

            if device.latitude != nil, device.longitude != nil {
                Section("Location") {
                    row("Latitude", String(format: "%.5f", device.latitude ?? 0))
                    row("Longitude", String(format: "%.5f", device.longitude ?? 0))
                }
            }
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(mono ? .system(.body, design: .monospaced) : .body)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}
