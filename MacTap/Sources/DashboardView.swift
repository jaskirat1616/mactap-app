import SwiftUI
import AppKit

struct DashboardView: View {
    @ObservedObject private var localization = Localization.shared
    @ObservedObject var engine: GestureEngine
    @ObservedObject var permissions: PermissionsManager
    @ObservedObject private var configStore = ConfigStore.shared
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 10) {
            header
            if engine.sensor.source == .unavailable && !engine.sensor.isArrowSimulationEnabled {
                unsupportedBanner
            }
            hero
            statusCapsules
            if !permissions.allGranted {
                CoastCapsuleButton(title: L("Allow Accessibility"), icon: "lock.shield", prominent: true, fillOnly: true) {
                    permissions.requestAccessibility()
                }
            }
            footer
        }
        .padding(12)
        .frame(width: 292)
    }

    private var header: some View {
        CoastRow(fillOnly: true) {
            HStack(spacing: 8) {
                PulseDot(isOn: engine.isRunning)
                VStack(alignment: .leading, spacing: 1) {
                    Text(statusTitle)
                        .font(.headline)
                    Text(L(statusSubtitle))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } trailing: {
            Toggle(L("Detection"), isOn: Binding(
                get: { engine.isRunning },
                set: { on in
                    if on { engine.start() } else { engine.stop() }
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .disabled(!engine.sensor.isAvailable)
            .accessibilityLabel(L("Detection"))
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            ChassisSilhouette(
                leftHot: glow(.left),
                rightHot: glow(.right),
                unified: configStore.config.layout == .knock
            )
            .frame(height: 54)

            WaveformView(
                history: engine.sensor.waveformHistory,
                color: lastAccent
            )
            .frame(height: 36)
            .opacity(engine.isRunning ? 1 : 0.35)

            HStack {
                Text(L(heroCaption))
                    .font(.caption.weight(.medium))
                Spacer()
                Text(L(sensorCaption))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .coastCard(fillOnly: true)
    }

    private var unsupportedBanner: some View {
        CoastRow(fillOnly: true) {
            Label(L("This Mac’s motion sensor isn’t accessible"), systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } trailing: {
            EmptyView()
        }
    }

    private var statusCapsules: some View {
        VStack(spacing: 6) {
            CoastRow(fillOnly: true) {
                Label(L("Last tap"), systemImage: "hand.tap")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } trailing: {
                if let g = engine.lastGesture {
                    Text(L(lastActionCaption(g)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MacTapTheme.accent(for: g.side))
                        .lineLimit(1)
                } else {
                    Text(L("Waiting"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            CoastRow(fillOnly: true) {
                Label(L("Preset"), systemImage: "square.grid.2x2")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } trailing: {
                Menu {
                    ForEach(GesturePreset.allCases) { preset in
                        Button {
                            configStore.applyPreset(preset)
                        } label: {
                            Label(L(preset.title), systemImage: preset.icon)
                        }
                    }
                } label: {
                    Text(L(configStore.currentPreset?.title ?? L("Custom")))
                        .font(.caption.weight(.semibold))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            CoastToggleRow(
                title: L("On-screen overlay"),
                icon: "rectangle.inset.filled",
                isOn: $configStore.config.showHUD,
                fillOnly: true
            ) { _ in
                configStore.save()
            }

            if configStore.config.stats.todayCount > 0 {
                CoastRow(fillOnly: true) {
                    Label(L("Today"), systemImage: "chart.bar")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } trailing: {
                    Text("\(configStore.config.stats.todayCount)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            CoastCapsuleButton(title: L("Settings"), icon: "gearshape", fillOnly: true) {
                NSApp.activate(ignoringOtherApps: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    openSettings()
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            }
            CoastCapsuleButton(title: L("Quit"), fillOnly: true) {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private var lastAccent: Color {
        engine.lastGesture.map { MacTapTheme.accent(for: $0.side) } ?? .accentColor
    }

    private func glow(_ side: TapSide) -> Double {
        guard engine.lastGesture != nil else { return 0.12 }
        if configStore.config.layout == .knock { return 0.9 }
        guard engine.lastGesture?.side == side else { return 0.12 }
        return 1
    }

    private var heroCaption: String {
        if let g = engine.lastGesture {
            if let slot = engine.lastExecutedSlot, slot.actionType != .none {
                return L(slot.actionType.displayName)
            }
            return configStore.config.layout == .knock
                ? tapWord(g.tapCount)
                : "\(L(g.side.displayName)) · \(tapWord(g.tapCount))"
        }
        return engine.isRunning
            ? (configStore.config.layout == .knock ? L("Knock the chassis or desk") : L("Tap a chassis edge"))
            : (engine.sensor.isAvailable ? L("Detection is off") : L("No motion sensor"))
    }

    private func lastActionCaption(_ g: DetectedGesture) -> String {
        let layout = configStore.config.layout
        let pattern = layout == .knock ? tapWord(g.tapCount) : "\(L(g.side.displayName)) · \(tapWord(g.tapCount))"
        if let slot = engine.lastExecutedSlot, slot.actionType != ActionType.none {
            return "\(pattern) · \(L(slot.actionType.displayName))"
        }
        return pattern
    }

    private func tapWord(_ count: Int) -> String {
        switch count {
        case 1: return L("Single")
        case 2: return L("Double")
        default: return L("Triple")
        }
    }

    private var statusTitle: String { "MacTap" }

    private var statusSubtitle: String {
        if !engine.sensor.isAvailable { return L("Unavailable") }
        return engine.isRunning ? L("Listening") : L("Paused")
    }

    private var sensorCaption: String {
        if engine.sensor.source == .spu {
            if engine.sensor.gyroAvailable {
                return engine.sensor.isStreaming ? L("IMU + gyro") : L("Ready")
            }
            return engine.sensor.isStreaming ? L("Built-in IMU") : L("Ready")
        }
        if engine.sensor.isArrowSimulationEnabled {
            return L("Debug arrows")
        }
        return L("No IMU")
    }
}
