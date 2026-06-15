import Foundation

/// Canned data so the app's full UI can be explored without a backend — used
/// for the "Explore demo" entry point and for App Store review.
enum DemoData {
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "demoMode") }
        set { UserDefaults.standard.set(newValue, forKey: "demoMode") }
    }

    static let user = SessionUser(id: "demo", name: "Demo User",
                                  email: "demo@iotflow.app", role: "ADMIN")

    static func summary() -> DashboardSummary {
        let now = Date()
        return DashboardSummary(
            counts: Counts(total: 4, online: 3, offline: 1, activeAlerts: 1),
            latestTelemetry: [
                row("t1", "Living Room Sensor", "lr-sensor", "temperature", 22.4, now.addingTimeInterval(-30)),
                row("t2", "Living Room Sensor", "lr-sensor", "humidity", 48, now.addingTimeInterval(-30)),
                row("t3", "Warehouse Gateway", "wh-gw", "power_kw", 3.7, now.addingTimeInterval(-95)),
                row("t4", "Rooftop Weather", "roof-wx", "wind_ms", 5.1, now.addingTimeInterval(-160)),
            ],
            recentAlerts: [
                alert("a1", "Cold Storage", "Temperature above 8°C threshold", "ACTIVE", now.addingTimeInterval(-600)),
                alert("a2", "Warehouse Gateway", "Device back online", "RESOLVED", now.addingTimeInterval(-5400)),
            ],
            devices: devices().map {
                DeviceLite(id: $0.id, name: $0.name, deviceId: $0.deviceId,
                           status: $0.status, lastSeen: $0.lastSeen)
            })
    }

    static func devices() -> [Device] {
        let now = Date()
        return [
            device("d1", "Living Room Sensor", "Temperature", "lr-sensor", "HTTP", "ONLINE", "Home", 842, now.addingTimeInterval(-30)),
            device("d2", "Warehouse Gateway", "Gateway", "wh-gw", "MQTT", "ONLINE", "Depot A", 15203, now.addingTimeInterval(-95)),
            device("d3", "Rooftop Weather", "Weather", "roof-wx", "MQTT", "ONLINE", "Building 3", 6410, now.addingTimeInterval(-160)),
            device("d4", "Cold Storage", "Temperature", "cold-1", "HTTP", "OFFLINE", "Depot A", 320, now.addingTimeInterval(-7200)),
        ]
    }

    static func createdDevice(name: String, type: String, proto: DeviceProtocol, location: String?) -> CreateDeviceResponse {
        let id = name.lowercased().replacingOccurrences(of: " ", with: "-")
        let d = device(UUID().uuidString, name, type.isEmpty ? "Generic" : type, id, proto.rawValue, "OFFLINE", location, 0, nil)
        return CreateDeviceResponse(device: d, token: "demo_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())
    }

    // MARK: builders (decode from JSON so the immutable models stay simple)

    private static func device(_ id: String, _ name: String, _ type: String, _ deviceId: String,
                               _ proto: String, _ status: String, _ location: String?,
                               _ count: Int, _ lastSeen: Date?) -> Device {
        let json: [String: Any?] = [
            "id": id, "name": name, "type": type, "deviceId": deviceId,
            "location": location, "protocol": proto, "status": status,
            "lastSeen": lastSeen.map { iso.string(from: $0) },
            "createdAt": iso.string(from: Date(timeIntervalSinceNow: -86400 * 12)),
            "_count": ["telemetry": count],
        ]
        return decode(Device.self, json)
    }

    private static func row(_ id: String, _ devName: String, _ devId: String,
                            _ metric: String, _ value: Double, _ ts: Date) -> TelemetryRow {
        decode(TelemetryRow.self, [
            "id": id, "metric": metric, "value": value, "ts": iso.string(from: ts),
            "device": ["name": devName, "deviceId": devId],
        ])
    }

    private static func alert(_ id: String, _ devName: String, _ message: String,
                              _ status: String, _ at: Date) -> AlertRow {
        decode(AlertRow.self, [
            "id": id, "message": message, "value": nil, "status": status,
            "triggeredAt": iso.string(from: at), "device": ["name": devName],
        ])
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func decode<T: Decodable>(_ type: T.Type, _ dict: [String: Any?]) -> T {
        let clean = dict.compactMapValues { $0 }
        let data = try! JSONSerialization.data(withJSONObject: clean)
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let raw = try dec.singleValueContainer().decode(String.self)
            return iso.date(from: raw) ?? Date()
        }
        return try! d.decode(T.self, from: data)
    }
}
