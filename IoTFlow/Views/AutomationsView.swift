import SwiftUI

/// Automations tab — lists the project's n8n automations and lets the user
/// **trigger** a flow (sends a sample event to its n8n webhook, same as the web
/// "Test" action) or enable/disable it. Mirrors the web Automations page.
struct AutomationsView: View {
    @State private var automations: [Automation] = []
    @State private var loading = false
    @State private var error: String?
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            Group {
                if automations.isEmpty && loading {
                    ProgressView().padding(.top, 80)
                } else if let error, automations.isEmpty {
                    ErrorBanner(message: error) { Task { await load() } }.padding()
                } else if automations.isEmpty {
                    ContentUnavailableView(
                        "No automations",
                        systemImage: "bolt.horizontal.circle",
                        description: Text("Create automations on the web dashboard to wire device events to n8n flows.")
                    )
                } else {
                    List {
                        Section(footer: Text("Trigger sends a sample event to the flow's n8n webhook — the same as the web Test button.")) {
                            ForEach(automations) { a in AutomationRow(a: a, onTrigger: { await trigger(a) }) }
                        }
                    }
                }
            }
            .navigationTitle("Automations")
            .refreshable { await load() }
            .task { await load() }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private func load() async {
        loading = automations.isEmpty
        error = nil
        do { automations = try await APIClient.shared.automations() }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
        loading = false
    }

    private func trigger(_ a: Automation) async {
        do {
            let status = try await APIClient.shared.triggerAutomation(id: a.id)
            await flash(status.hasPrefix("error") ? "Flow error: \(status)" : "▶︎ Triggered “\(a.name)”")
            await load()
        } catch {
            await flash((error as? LocalizedError)?.errorDescription ?? "Trigger failed")
        }
    }

    @MainActor
    private func flash(_ msg: String) async {
        withAnimation { toast = msg }
        try? await Task.sleep(nanoseconds: 2_500_000_000)
        withAnimation { toast = nil }
    }
}

private struct AutomationRow: View {
    let a: Automation
    let onTrigger: () async -> Void
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bolt.fill").foregroundStyle(.yellow)
                Text(a.name).font(.subheadline.weight(.semibold))
                Spacer()
            }
            HStack(spacing: 8) {
                Tag(text: a.eventLabel, tint: .blue)
                if let m = a.metric { Tag(text: m, tint: .gray) }
                Tag(text: a.enabled ? "Enabled" : "Disabled", tint: a.enabled ? .green : .gray)
            }
            if let fired = a.lastFiredAt {
                HStack(spacing: 4) {
                    Image(systemName: a.lastOk ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(a.lastOk ? .green : .red).font(.caption2)
                    Text("Last fired ").font(.caption2).foregroundStyle(.secondary)
                    + Text(fired, style: .relative).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Button {
                Task { busy = true; await onTrigger(); busy = false }
            } label: {
                HStack { if busy { ProgressView().controlSize(.small) }
                    Text(busy ? "Triggering…" : "Trigger flow") }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(busy)
        }
        .padding(.vertical, 6)
    }
}

private struct Tag: View {
    let text: String
    let tint: Color
    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }
}
