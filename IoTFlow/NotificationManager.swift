import Foundation
import UserNotifications

/// Local alert notifications — polls the platform's dashboard summary while the
/// app is running and posts a local notification when a new ACTIVE alert
/// appears (e.g. a threshold automation fired). No push infrastructure needed.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private var pollTask: Task<Void, Never>?
    /// Alert ids already notified, so re-polls don't repeat notifications.
    private var seen: Set<String> = []
    private var primed = false

    private init() {}

    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    /// Start polling for new active alerts (idempotent).
    func startPolling() async {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkForNewAlerts()
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
        seen.removeAll()
        primed = false
    }

    private func checkForNewAlerts() async {
        guard let summary = try? await APIClient.shared.dashboardSummary() else { return }
        let active = summary.recentAlerts.filter { $0.status == "ACTIVE" }
        // First poll only records what's already active — notify on changes.
        if !primed {
            seen.formUnion(active.map(\.id))
            primed = true
            return
        }
        for alert in active where !seen.contains(alert.id) {
            seen.insert(alert.id)
            await notify(alert)
        }
    }

    private func notify(_ alert: AlertRow) async {
        let content = UNMutableNotificationContent()
        content.title = alert.device?.name ?? "IoTFlow alert"
        content.body = alert.message
        content.sound = .default
        let request = UNNotificationRequest(identifier: "alert-\(alert.id)",
                                            content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
