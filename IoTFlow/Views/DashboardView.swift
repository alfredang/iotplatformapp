import SwiftUI

struct DashboardView: View {
    @State private var summary: DashboardSummary?
    @State private var error: String?
    @State private var loading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let summary {
                    content(summary)
                } else if loading {
                    ProgressView().padding(.top, 80)
                } else if let error {
                    ErrorBanner(message: error) { Task { await load() } }
                        .padding()
                }
            }
            .navigationTitle("Dashboard")
            .refreshable { await load() }
            .task { await load() }
        }
    }

    @ViewBuilder
    private func content(_ s: DashboardSummary) -> some View {
        VStack(spacing: 20) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                StatCard(title: "Total Devices", value: "\(s.counts.total)",
                         icon: "cpu.fill", color: .blue)
                StatCard(title: "Online", value: "\(s.counts.online)",
                         icon: "wifi", color: .green)
                StatCard(title: "Offline", value: "\(s.counts.offline)",
                         icon: "wifi.slash", color: .gray)
                StatCard(title: "Active Alerts", value: "\(s.counts.activeAlerts)",
                         icon: "bell.badge.fill", color: .orange)
            }
            .padding(.horizontal)

            section("Latest Telemetry") {
                if s.latestTelemetry.isEmpty {
                    EmptyRow(text: "No telemetry yet.")
                } else {
                    ForEach(s.latestTelemetry) { t in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.device?.name ?? t.device?.deviceId ?? "Device")
                                    .font(.subheadline.weight(.medium))
                                Text(t.metric).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(t.value.map { format($0) } ?? "—")
                                    .font(.subheadline.monospacedDigit())
                                if let ts = t.ts {
                                    Text(ts, style: .relative).font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        Divider()
                    }
                }
            }

            section("Recent Alerts") {
                if s.recentAlerts.isEmpty {
                    EmptyRow(text: "No alerts. All good!")
                } else {
                    ForEach(s.recentAlerts) { a in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: a.status == "ACTIVE" ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(a.status == "ACTIVE" ? .orange : .green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(a.device?.name ?? "Device").font(.subheadline.weight(.medium))
                                Text(a.message).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let t = a.triggeredAt {
                                Text(t, style: .relative).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                        Divider()
                    }
                }
            }
        }
        .padding(.vertical)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder _ body: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            VStack(spacing: 0) { body() }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 16))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    private func format(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v)
    }

    private func load() async {
        loading = summary == nil
        error = nil
        do {
            summary = try await APIClient.shared.dashboardSummary()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        loading = false
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value).font(.system(size: 30, weight: .bold, design: .rounded))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
    }
}

struct EmptyRow: View {
    let text: String
    var body: some View {
        Text(text).font(.subheadline).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ErrorBanner: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.icloud")
                .font(.largeTitle).foregroundStyle(.secondary)
            Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Try again", action: retry).buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}
