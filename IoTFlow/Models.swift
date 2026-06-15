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
