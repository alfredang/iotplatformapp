import SwiftUI

/// "My widgets" section on the Dashboard — mirrors the web dashboard: renders
/// display widgets (number, gauge, LED, status, chart-latest) and interactive
/// control widgets (switch, slider, button, terminal) that trigger device
/// actions via the platform command API.
struct DashboardWidgetsSection: View {
    @State private var widgets: [DashWidget] = []
    @State private var loaded = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("My Widgets").font(.headline)
            if widgets.isEmpty && loaded {
                Text("No widgets yet. Add them on the web dashboard.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 16))
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(widgets) { w in
                        WidgetCard(widget: w)
                            .gridCellColumns(isWide(w) ? 2 : 1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .task { await load() }
    }

    private func isWide(_ w: DashWidget) -> Bool {
        ["LINE", "BAR", "ALERTS", "MAP", "TERMINAL"].contains(w.type)
    }

    private func load() async {
        widgets = (try? await APIClient.shared.dashboardWidgets()) ?? []
        loaded = true
    }
}

// MARK: - Widget card

private struct WidgetCard: View {
    let widget: DashWidget

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(widget.title.isEmpty ? (widget.device?.name ?? widget.type) : widget.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            content
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var content: some View {
        switch widget.type {
        case "NUMBER":
            if let d = widget.device, let m = widget.metric {
                LatestNumber(deviceId: d.id, metric: m)
            }
        case "GAUGE":
            if let d = widget.device, let m = widget.metric {
                GaugeWidget(deviceId: d.id, metric: m,
                            min: widget.config?.min ?? 0, max: widget.config?.max ?? 100)
            }
        case "LED":
            if let d = widget.device, let m = widget.metric {
                LedWidget(deviceId: d.id, metric: m)
            }
        case "STATUS":
            if let d = widget.device {
                StatusPill(online: d.statusEnum == .ONLINE)
            }
        case "LINE", "BAR":
            if let d = widget.device, let m = widget.metric {
                LatestNumber(deviceId: d.id, metric: m, caption: "History on web")
            }
        case "SWITCH":
            if let d = widget.device { SwitchWidget(deviceId: d.id, pin: widget.pin) }
        case "SLIDER":
            if let d = widget.device {
                SliderWidget(deviceId: d.id, pin: widget.pin,
                             min: widget.config?.min ?? 0, max: widget.config?.max ?? 100)
            }
        case "BUTTON":
            if let d = widget.device { ButtonWidget(deviceId: d.id, pin: widget.pin) }
        case "TERMINAL":
            if let d = widget.device { TerminalWidget(deviceId: d.id, pin: widget.pin) }
        default:
            Text(widget.type).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Display widgets

private func fmt(_ v: Double?) -> String {
    guard let v else { return "—" }
    return v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
}

private struct LatestNumber: View {
    let deviceId: String
    let metric: String
    var caption: String? = nil
    @State private var value: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(fmt(value)).font(.system(size: 30, weight: .bold, design: .rounded))
            Text(caption ?? metric).font(.caption).foregroundStyle(.secondary)
        }
        .task { await poll() }
    }

    private func poll() async {
        while !Task.isCancelled {
            value = try? await APIClient.shared.latestValue(deviceId: deviceId, metric: metric)
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }
}

private struct GaugeWidget: View {
    let deviceId: String
    let metric: String
    let min: Double
    let max: Double
    @State private var value: Double?

    private var fraction: Double {
        guard let value, max > min else { return 0 }
        return Swift.min(1, Swift.max(0, (value - min) / (max - min)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(fmt(value)).font(.system(size: 26, weight: .bold, design: .rounded))
            ProgressView(value: fraction).tint(.blue)
            HStack {
                Text(fmt(min)); Spacer(); Text(fmt(max))
            }.font(.caption2).foregroundStyle(.secondary)
        }
        .task { await poll() }
    }

    private func poll() async {
        while !Task.isCancelled {
            value = try? await APIClient.shared.latestValue(deviceId: deviceId, metric: metric)
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }
}

private struct LedWidget: View {
    let deviceId: String
    let metric: String
    @State private var on = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(on ? Color.green : Color(.systemGray4))
                .frame(width: 30, height: 30)
                .shadow(color: on ? .green.opacity(0.7) : .clear, radius: 8)
            Text(on ? "ON" : "OFF").font(.headline)
        }
        .task { await poll() }
    }

    private func poll() async {
        while !Task.isCancelled {
            let v = try? await APIClient.shared.latestValue(deviceId: deviceId, metric: metric)
            on = (v ?? 0) > 0
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }
}

// MARK: - Control widgets (trigger actions)

private struct SwitchWidget: View {
    let deviceId: String
    let pin: String
    @State private var isOn = false
    @State private var busy = false

    var body: some View {
        Toggle(isOn: Binding(
            get: { isOn },
            set: { newValue in
                isOn = newValue
                Task { await send(newValue) }
            }
        )) {
            Text("Pin \(pin)").font(.caption).foregroundStyle(.secondary)
        }
        .disabled(busy)
        .task { await refresh() }
    }

    private func refresh() async {
        let pins = (try? await APIClient.shared.pinStates(deviceId: deviceId)) ?? [:]
        isOn = (pins[pin] ?? 0) == 1
    }

    private func send(_ value: Bool) async {
        busy = true
        try? await APIClient.shared.setCommand(deviceId: deviceId, pin: pin, value: value ? 1 : 0)
        busy = false
    }
}

private struct SliderWidget: View {
    let deviceId: String
    let pin: String
    let min: Double
    let max: Double
    @State private var value: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Pin \(pin)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(fmt(value)).font(.headline.monospacedDigit())
            }
            Slider(value: $value, in: min...max) { editing in
                if !editing {
                    Task { try? await APIClient.shared.setCommand(deviceId: deviceId, pin: pin, value: value) }
                }
            }
        }
        .task { await refresh() }
    }

    private func refresh() async {
        let pins = (try? await APIClient.shared.pinStates(deviceId: deviceId)) ?? [:]
        value = Swift.min(max, Swift.max(min, pins[pin] ?? min))
    }
}

private struct ButtonWidget: View {
    let deviceId: String
    let pin: String
    @State private var busy = false

    var body: some View {
        Button {
            Task {
                busy = true
                try? await APIClient.shared.setCommand(deviceId: deviceId, pin: pin, value: 1)
                try? await Task.sleep(nanoseconds: 400_000_000)
                try? await APIClient.shared.setCommand(deviceId: deviceId, pin: pin, value: 0)
                busy = false
            }
        } label: {
            Text(busy ? "Sending…" : "Press")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(busy)
    }
}

private struct TerminalWidget: View {
    let deviceId: String
    let pin: String
    @State private var text = ""
    @State private var sent: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Send to \(pin)…", text: $text)
                    .textFieldStyle(.roundedBorder)
                Button("Send") { Task { await send() } }
                    .disabled(text.isEmpty)
            }
            if !sent.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(sent.enumerated()), id: \.offset) { _, s in
                        Text("→ \(s)").font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func send() async {
        let msg = text
        try? await APIClient.shared.setCommand(deviceId: deviceId, pin: pin, value: nil, strValue: msg)
        sent.insert(msg, at: 0)
        sent = Array(sent.prefix(4))
        text = ""
    }
}
