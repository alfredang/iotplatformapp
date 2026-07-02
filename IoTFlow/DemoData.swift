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

    // MARK: - Dashboard widgets + control (demo)

    /// In-memory virtual-pin state so demo control widgets feel live.
    private static var pinStore: [String: Double] = [
        "d1|V1": 1,      // Living Room LED on
        "d1|brightness": 60,
        "d2|relay": 0,   // Warehouse fan off
    ]

    static func widgets() -> [DashWidget] {
        [
            widget("w1", "NUMBER", "Living Room Temp", devId: "d1", devName: "Living Room Sensor", metric: "temperature"),
            widget("w2", "GAUGE", "Humidity", devId: "d1", devName: "Living Room Sensor", metric: "humidity", min: 0, max: 100),
            widget("w3", "SWITCH", "Living Room Light", devId: "d1", devName: "Living Room Sensor", pin: "V1"),
            widget("w4", "SLIDER", "Brightness", devId: "d1", devName: "Living Room Sensor", pin: "brightness", min: 0, max: 100),
            widget("w5", "SWITCH", "Warehouse Fan", devId: "d2", devName: "Warehouse Gateway", pin: "relay"),
            widget("w6", "BUTTON", "Ring Buzzer", devId: "d2", devName: "Warehouse Gateway", pin: "buzzer"),
            widget("w7", "STATUS", "Rooftop Weather", devId: "d3", devName: "Rooftop Weather"),
            widget("w8", "LED", "Pump Running", devId: "d2", devName: "Warehouse Gateway", metric: "power_kw"),
        ]
    }

    static func latest(_ deviceId: String, _ metric: String) -> Double? {
        switch metric {
        case "temperature": return 22.4
        case "humidity": return 48
        case "power_kw": return 3.7
        case "wind_ms": return 5.1
        default: return 12.3
        }
    }

    static func pins(_ deviceId: String) -> [String: Double] {
        pinStore.filter { $0.key.hasPrefix(deviceId + "|") }
            .reduce(into: [:]) { acc, kv in
                acc[String(kv.key.dropFirst(deviceId.count + 1))] = kv.value
            }
    }

    static func setPin(_ deviceId: String, _ pin: String, _ value: Double?) {
        pinStore["\(deviceId)|\(pin)"] = value ?? 0
    }

    static func automations() -> [Automation] {
        let now = Date()
        return [
            automation("au1", "ESP32 LED Blinker → n8n", "COMMAND", nil, now.addingTimeInterval(-120), "ok"),
            automation("au2", "DHT22 Climate → n8n", "TELEMETRY", "temperature", now.addingTimeInterval(-45), "ok"),
            automation("au3", "Arduino Soil Moisture → n8n", "TELEMETRY", "soil", now.addingTimeInterval(-600), "ok"),
            automation("au4", "Room Monitor CO₂ alert → n8n", "ALERT", nil, nil, nil),
            automation("au5", "Smart Plug power → n8n", "TELEMETRY", "power", now.addingTimeInterval(-30), "ok"),
        ]
    }

    private static func automation(_ id: String, _ name: String, _ event: String,
                                   _ metric: String?, _ fired: Date?, _ status: String?) -> Automation {
        decode(Automation.self, [
            "id": id, "name": name, "event": event, "metric": metric,
            "n8nWebhookUrl": "https://n8n.tertiarytraining.com/webhook/iot-demo-\(id)",
            "enabled": true,
            "lastFiredAt": fired.map { iso.string(from: $0) },
            "lastStatus": status,
        ])
    }

    private static func widget(_ id: String, _ type: String, _ title: String,
                               devId: String, devName: String, metric: String? = nil,
                               pin: String? = nil, min: Double? = nil, max: Double? = nil) -> DashWidget {
        var config: [String: Any?] = [:]
        if let pin { config["pin"] = pin }
        if let min { config["min"] = min }
        if let max { config["max"] = max }
        var json: [String: Any?] = [
            "id": id, "type": type, "title": title, "metric": metric,
            "device": ["id": devId, "name": devName, "deviceId": devName.lowercased().replacingOccurrences(of: " ", with: "-"), "status": "ONLINE"],
        ]
        if !config.isEmpty { json["config"] = config.compactMapValues { $0 } }
        return decode(DashWidget.self, json)
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
