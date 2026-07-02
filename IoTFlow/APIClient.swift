import Foundation

/// Networking layer for the IoTFlow platform.
///
/// The backend uses Auth.js (NextAuth v5) with a JWT session cookie. We log in
/// by replicating the browser credentials flow:
///   1. GET  /api/auth/csrf                 -> csrfToken (+ csrf cookie)
///   2. POST /api/auth/callback/credentials -> sets the session cookie
/// `URLSession`'s shared cookie storage then carries the session cookie on
/// every subsequent JSON API request, exactly like a browser would.
actor APIClient {
    static let shared = APIClient()

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    private var baseURL: URL {
        let stored = UserDefaults.standard.string(forKey: "serverURL")
        return URL(string: stored ?? AppConfig.defaultServer)!
    }

    private lazy var decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = APIClient.iso.date(from: raw) ?? APIClient.isoPlain.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container,
                debugDescription: "Unrecognised date: \(raw)")
        }
        return d
    }()

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - Auth

    func login(email: String, password: String) async throws {
        let token = try await fetchCSRF()
        var req = URLRequest(url: url("/api/auth/callback/credentials"))
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("1", forHTTPHeaderField: "X-Auth-Return-Redirect")
        req.httpBody = formBody([
            "csrfToken": token,
            "email": email,
            "password": password,
            "callbackUrl": "/dashboard",
            "json": "true",
        ])
        let (data, _) = try await send(req)
        let cb = try? decoder.decode(CallbackResponse.self, from: data)
        if let u = cb?.url, u.contains("error") {
            throw APIError.invalidCredentials
        }
        // Confirm the session actually exists.
        guard try await currentUser() != nil else {
            throw APIError.invalidCredentials
        }
    }

    func register(name: String, email: String, password: String) async throws {
        var req = URLRequest(url: url("/api/auth/register"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "name": name, "email": email, "password": password,
        ])
        let (data, resp) = try await send(req)
        guard (200...299).contains(resp.statusCode) else {
            let msg = (try? decoder.decode(APIErrorResponse.self, from: data))?.error
            throw APIError.server(msg ?? "Registration failed (\(resp.statusCode)).")
        }
    }

    /// Permanently delete the signed-in user's account on the backend
    /// (Guideline 5.1.1(v)). In demo mode there is no real account, so this is
    /// a no-op and the caller simply exits the session.
    func deleteAccount() async throws {
        if DemoData.isEnabled { return }
        var req = URLRequest(url: url("/api/account"))
        req.httpMethod = "DELETE"
        let (data, resp) = try await send(req)
        guard (200...299).contains(resp.statusCode) else {
            let msg = (try? decoder.decode(APIErrorResponse.self, from: data))?.error
            throw APIError.server(msg ?? "Could not delete account (\(resp.statusCode)).")
        }
    }

    func currentUser() async throws -> SessionUser? {
        let req = URLRequest(url: url("/api/auth/session"))
        let (data, _) = try await send(req)
        let session = try? decoder.decode(SessionResponse.self, from: data)
        return session?.user
    }

    func logout() async {
        // Clear cookies for the server so the session ends locally.
        if let cookies = HTTPCookieStorage.shared.cookies {
            for c in cookies where baseURL.host?.contains(c.domain.replacingOccurrences(of: ".", with: "")) ?? true {
                HTTPCookieStorage.shared.deleteCookie(c)
            }
        }
        HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
    }

    private func fetchCSRF() async throws -> String {
        let req = URLRequest(url: url("/api/auth/csrf"))
        let (data, _) = try await send(req)
        guard let csrf = try? decoder.decode(CSRFResponse.self, from: data) else {
            throw APIError.decoding
        }
        return csrf.csrfToken
    }

    // MARK: - Data

    func dashboardSummary() async throws -> DashboardSummary {
        if DemoData.isEnabled { return DemoData.summary() }
        return try await getJSON("/api/dashboard/summary")
    }

    func devices() async throws -> [Device] {
        if DemoData.isEnabled { return DemoData.devices() }
        let resp: DevicesResponse = try await getJSON("/api/devices")
        return resp.devices
    }

    func createDevice(name: String, type: String, location: String?,
                      proto: DeviceProtocol) async throws -> CreateDeviceResponse {
        if DemoData.isEnabled {
            return DemoData.createdDevice(name: name, type: type, proto: proto, location: location)
        }
        var body: [String: Any] = ["name": name, "protocol": proto.rawValue]
        if !type.isEmpty { body["type"] = type }
        if let location, !location.isEmpty { body["location"] = location }
        var req = URLRequest(url: url("/api/devices"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await send(req)
        guard (200...299).contains(resp.statusCode) else {
            let msg = (try? decoder.decode(APIErrorResponse.self, from: data))?.error
            throw APIError.server(msg ?? "Could not add device (\(resp.statusCode)).")
        }
        return try decoder.decode(CreateDeviceResponse.self, from: data)
    }

    func deleteDevice(id: String) async throws {
        if DemoData.isEnabled { return }
        var req = URLRequest(url: url("/api/devices/\(id)"))
        req.httpMethod = "DELETE"
        let (_, resp) = try await send(req)
        guard (200...299).contains(resp.statusCode) else {
            throw APIError.server("Could not delete device (\(resp.statusCode)).")
        }
    }

    // MARK: - Dashboard widgets + device control

    /// The current project's dashboard widgets (display + control), matching web.
    func dashboardWidgets() async throws -> [DashWidget] {
        if DemoData.isEnabled { return DemoData.widgets() }
        let resp: WidgetsResponse = try await getJSON("/api/dashboard/widgets")
        return resp.widgets
    }

    /// Latest value for a device metric (for number / gauge / LED widgets).
    func latestValue(deviceId: String, metric: String) async throws -> Double? {
        if DemoData.isEnabled { return DemoData.latest(deviceId, metric) }
        let m = metric.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? metric
        let resp: TelemetryLatestResponse = try await getJSON("/api/devices/\(deviceId)/telemetry?metric=\(m)&limit=1")
        return resp.telemetry.first?.value
    }

    /// Current virtual-pin states for a device (control widgets reflect these).
    func pinStates(deviceId: String) async throws -> [String: Double] {
        if DemoData.isEnabled { return DemoData.pins(deviceId) }
        let resp: PinStateResponse = try await getJSON("/api/devices/\(deviceId)/command")
        return resp.state.compactMapValues { $0.double }
    }

    /// Set a virtual-pin value (downlink control) — the platform persists it and
    /// publishes to MQTT `devices/<id>/down`.
    func setCommand(deviceId: String, pin: String, value: Double?, strValue: String? = nil) async throws {
        if DemoData.isEnabled { DemoData.setPin(deviceId, pin, value); return }
        var body: [String: Any] = ["pin": pin]
        if let value { body["value"] = value }
        if let strValue { body["strValue"] = strValue }
        var req = URLRequest(url: url("/api/devices/\(deviceId)/command"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await send(req)
        guard (200...299).contains(resp.statusCode) else {
            let msg = (try? decoder.decode(APIErrorResponse.self, from: data))?.error
            throw APIError.server(msg ?? "Could not send command (\(resp.statusCode)).")
        }
    }

    // MARK: - Automations (n8n low-code flows)

    /// List the current project's automations (event → n8n webhook links).
    func automations() async throws -> [Automation] {
        if DemoData.isEnabled { return DemoData.automations() }
        let resp: AutomationsResponse = try await getJSON("/api/automations")
        return resp.automations
    }

    /// Trigger an automation — sends a sample event to its n8n flow (the same
    /// "Test" action as the web Automations page). Returns the delivery status.
    func triggerAutomation(id: String) async throws -> String {
        if DemoData.isEnabled { return "ok" }
        var req = URLRequest(url: url("/api/automations/\(id)"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, resp) = try await send(req)
        guard (200...299).contains(resp.statusCode) else {
            let msg = (try? decoder.decode(APIErrorResponse.self, from: data))?.error
            throw APIError.server(msg ?? "Could not trigger flow (\(resp.statusCode)).")
        }
        return (try? decoder.decode(AutomationActionResponse.self, from: data))?.status ?? "ok"
    }

    /// Enable/disable an automation.
    func setAutomationEnabled(id: String, enabled: Bool) async throws {
        if DemoData.isEnabled { return }
        var req = URLRequest(url: url("/api/automations/\(id)"))
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["enabled": enabled])
        _ = try await send(req)
    }

    // MARK: - Helpers

    private func getJSON<T: Decodable>(_ path: String) async throws -> T {
        let req = URLRequest(url: url(path))
        let (data, resp) = try await send(req)
        guard (200...299).contains(resp.statusCode) else {
            let msg = (try? decoder.decode(APIErrorResponse.self, from: data))?.error
            throw APIError.server(msg ?? "Request failed (\(resp.statusCode)).")
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private func send(_ req: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.network("No response from server.")
            }
            return (data, http)
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    private func url(_ path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }

    private func formBody(_ params: [String: String]) -> Data {
        params.map { key, value in
            let v = value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
            return "\(key)=\(v)"
        }.joined(separator: "&").data(using: .utf8) ?? Data()
    }
}

enum AppConfig {
    static let defaultServer = "https://iot.tertiaryinfotech.com"
}
