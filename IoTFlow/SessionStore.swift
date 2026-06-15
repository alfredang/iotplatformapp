import SwiftUI

/// App-wide authentication state.
@MainActor
final class SessionStore: ObservableObject {
    enum State {
        case loading
        case signedOut
        case signedIn(SessionUser)
    }

    @Published var state: State = .loading

    var user: SessionUser? {
        if case .signedIn(let u) = state { return u }
        return nil
    }

    func enterDemo() {
        DemoData.isEnabled = true
        state = .signedIn(DemoData.user)
    }

    func restore() async {
        if DemoData.isEnabled {
            state = .signedIn(DemoData.user)
            return
        }
        do {
            if let user = try await APIClient.shared.currentUser() {
                state = .signedIn(user)
                return
            }
        } catch { /* fall through to signed out */ }
        state = .signedOut
    }

    func login(email: String, password: String) async throws {
        try await APIClient.shared.login(email: email, password: password)
        let user = try await APIClient.shared.currentUser()
        state = .signedIn(user ?? SessionUser(id: nil, name: nil, email: email, role: nil))
    }

    func register(name: String, email: String, password: String) async throws {
        try await APIClient.shared.register(name: name, email: email, password: password)
        try await login(email: email, password: password)
    }

    func logout() async {
        DemoData.isEnabled = false
        await APIClient.shared.logout()
        state = .signedOut
    }
}
