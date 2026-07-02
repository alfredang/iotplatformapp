import Foundation

// MARK: - Auth

struct CSRFResponse: Decodable {
    let csrfToken: String
}

struct CallbackResponse: Decodable {
    let url: String?
}

struct SessionResponse: Decodable {
    let user: SessionUser?
}

struct SessionUser: Decodable {
    let id: String?
    let name: String?
    let email: String?
    let role: String?
}

// MARK: - Devices

enum DeviceProtocol: String, Codable, CaseIterable, Identifiable {
    case HTTP, MQTT, WEBSOCKET
    var id: String { rawValue }
    var label: String {
        switch self {
        case .HTTP: return "HTTP REST"
        case .MQTT: return "MQTT"
        case .WEBSOCKET: return "WebSocket"
        }
    }
}

enum DeviceStatus: String, Codable {
    case ONLINE, OFFLINE
}

struct Device: Decodable, Identifiable {
    let id: String
    let name: String
    let type: String?
    let deviceId: String
    let location: String?
    let latitude: Double?
    let longitude: Double?
    let proto: String?
    let status: String
    let lastSeen: Date?
    let createdAt: Date?
    let _count: DeviceCount?

    var statusEnum: DeviceStatus { DeviceStatus(rawValue: status) ?? .OFFLINE }
    var telemetryCount: Int { _count?.telemetry ?? 0 }

    enum CodingKeys: String, CodingKey {
        case id, name, type, deviceId, location, latitude, longitude
        case proto = "protocol"
        case status, lastSeen, createdAt, _count
    }
}

struct DeviceCount: Decodable {
    let telemetry: Int?
}

struct DevicesResponse: Decodable {
    let devices: [Device]
    let projectId: String?
}

struct CreateDeviceResponse: Decodable {
    let device: Device
    let token: String
}

// MARK: - Dashboard

struct DashboardSummary: Decodable {
    let counts: Counts
    let latestTelemetry: [TelemetryRow]
    let recentAlerts: [AlertRow]
    let devices: [DeviceLite]
}

struct Counts: Decodable {
    let total: Int
    let online: Int
    let offline: Int
    let activeAlerts: Int
}

struct DeviceLite: Decodable, Identifiable {
    let id: String
    let name: String
    let deviceId: String
    let status: String
    let lastSeen: Date?

    var statusEnum: DeviceStatus { DeviceStatus(rawValue: status) ?? .OFFLINE }
}

struct TelemetryRow: Decodable, Identifiable {
    let id: String
    let ts: Date?
    let metric: String
    let value: Double?
    let device: TelemetryDevice?

    struct TelemetryDevice: Decodable {
        let name: String?
        let deviceId: String?
    }
}

struct AlertRow: Decodable, Identifiable {
    let id: String
    let message: String
    let value: Double?
    let status: String
    let triggeredAt: Date?
    let device: AlertDevice?

    struct AlertDevice: Decodable {
        let name: String?
    }
}

// MARK: - Dashboard widgets + device control (virtual pins)

/// A single value in a device's pin-state map, which may be a number, a string
/// (terminal text) or null. Control widgets use the numeric form.
enum PinValue: Decodable {
    case number(Double)
    case text(String)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .text(s) }
        else { self = .null }
    }

    var double: Double? { if case .number(let n) = self { return n } else { return nil } }
}

struct WidgetsResponse: Decodable {
    let widgets: [DashWidget]
}

struct DashWidget: Decodable, Identifiable {
    let id: String
    let type: String
    let title: String
    let metric: String?
    let config: WidgetConfig?
    let device: WidgetDevice?

    /// The virtual pin a control widget writes to (config.pin, default "V1").
    var pin: String { config?.pin ?? "V1" }
    var isControl: Bool { ["BUTTON", "SWITCH", "SLIDER", "TERMINAL"].contains(type) }
}

struct WidgetConfig: Decodable {
    let min: Double?
    let max: Double?
    let pin: String?
}

struct WidgetDevice: Decodable {
    let id: String
    let name: String
    let deviceId: String
    let status: String

    var statusEnum: DeviceStatus { DeviceStatus(rawValue: status) ?? .OFFLINE }
}

struct TelemetryLatestResponse: Decodable {
    let telemetry: [TelemetryValue]
    struct TelemetryValue: Decodable { let value: Double? }
}

struct PinStateResponse: Decodable {
    let state: [String: PinValue]
}

struct CommandResponse: Decodable {
    let ok: Bool?
}

// MARK: - Automations (n8n low-code flows)

struct AutomationsResponse: Decodable {
    let automations: [Automation]
}

struct Automation: Decodable, Identifiable {
    let id: String
    let name: String
    let event: String
    let metric: String?
    let n8nWebhookUrl: String
    let enabled: Bool
    let lastFiredAt: Date?
    let lastStatus: String?

    var eventLabel: String {
        switch event {
        case "TELEMETRY": return "Telemetry"
        case "ALERT": return "Alert"
        case "DEVICE_ONLINE": return "Device online"
        case "DEVICE_OFFLINE": return "Device offline"
        case "COMMAND": return "Command"
        default: return event
        }
    }
    var lastOk: Bool { !(lastStatus?.hasPrefix("error") ?? false) }
}

struct AutomationActionResponse: Decodable {
    let ok: Bool?
    let status: String?
}

// MARK: - API errors

struct APIErrorResponse: Decodable {
    let error: String?
}

enum APIError: LocalizedError {
    case invalidCredentials
    case server(String)
    case decoding
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Invalid email or password."
        case .server(let m): return m
        case .decoding: return "Couldn't read the server response."
        case .network(let m): return m
        }
    }
}
