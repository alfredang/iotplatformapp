import SwiftUI

struct DevicesView: View {
    @State private var devices: [Device] = []
    @State private var loading = false
    @State private var error: String?
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if devices.isEmpty && loading {
                    ProgressView()
                } else if devices.isEmpty, let error {
                    ErrorBanner(message: error) { Task { await load() } }
                } else if devices.isEmpty {
                    ContentUnavailableView {
                        Label("No Devices", systemImage: "cpu")
                    } description: {
                        Text("Add your first device to start streaming telemetry.")
                    } actions: {
                        Button("Add Device") { showAdd = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(devices) { device in
                            NavigationLink {
                                DeviceDetailView(device: device)
                            } label: {
                                DeviceRow(device: device)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Devices")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable { await load() }
            .task { await load() }
            .sheet(isPresented: $showAdd) {
                AddDeviceView { Task { await load() } }
            }
            .onAppear {
                if ProcessInfo.processInfo.arguments.contains("-showAddDevice") {
                    showAdd = true
                }
            }
        }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            devices = try await APIClient.shared.devices()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        loading = false
    }

    private func delete(at offsets: IndexSet) {
        let targets = offsets.map { devices[$0] }
        devices.remove(atOffsets: offsets)
        Task {
            for d in targets {
                try? await APIClient.shared.deleteDevice(id: d.id)
            }
        }
    }
}

struct DeviceRow: View {
    let device: Device

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(device.statusEnum == .ONLINE ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: "cpu.fill")
                    .foregroundStyle(device.statusEnum == .ONLINE ? .green : .gray)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(device.name).font(.headline)
                HStack(spacing: 6) {
                    Text(device.proto ?? "HTTP")
                    Text("·")
                    Text(device.deviceId).lineLimit(1)
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            StatusPill(online: device.statusEnum == .ONLINE)
        }
        .padding(.vertical, 4)
    }
}

struct StatusPill: View {
    let online: Bool
    var body: some View {
        Text(online ? "Online" : "Offline")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background((online ? Color.green : Color.gray).opacity(0.18),
                        in: Capsule())
            .foregroundStyle(online ? .green : .gray)
    }
}
