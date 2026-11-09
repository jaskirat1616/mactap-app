import SwiftUI
import AppKit

private enum SettingsPane: String, CaseIterable, Identifiable {
    case general, gestures, sensor, sound, privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return L("General")
        case .gestures: return L("Gestures")
        case .sensor: return L("Sensor")
        case .sound: return L("Sound")
        case .privacy: return L("Privacy")
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .gestures: return "hand.tap"
        case .sensor: return "waveform"
        case .sound: return "speaker.wave.2"
        case .privacy: return "lock.shield"
        }
    }
}

struct SettingsView: View {
    @ObservedObject private var localization = Localization.shared
    @ObservedObject var engine: GestureEngine
    @ObservedObject var configStore = ConfigStore.shared
    @ObservedObject var permissions = PermissionsManager.shared
    @State private var pane: SettingsPane = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 188)
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
            paneContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 720, height: 520)
        .onAppear { permissions.checkAll() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                PulseDot(isOn: engine.isRunning)
                VStack(alignment: .leading, spacing: 1) {
                    Text("MacTap")
                        .font(.headline)
                    Text(engine.isRunning ? L("Listening") : L("Paused"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)

            ForEach(SettingsPane.allCases) { item in
                Button {
                    pane = item
                } label: {
                    Label(L(item.title), systemImage: item.icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(pane == item ? Color.primary : Color.secondary)
                .coastCapsule(interactive: pane == item, fillOnly: pane != item)
            }

            Spacer()
            Text("MacTap \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0")")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 8)
        }
        .padding(14)
    }

    @ViewBuilder
    private var paneContent: some View {
        switch pane {
        case .general:
            GeneralSettingsView(engine: engine, configStore: configStore)
        case .gestures:
            GesturesSettingsView(engine: engine, configStore: configStore)
        case .sensor:
            SensorMonitorView(engine: engine)
        case .sound:
            SoundFXSettingsView()
        case .privacy:
            PermissionsSettingsView(permissions: permissions)
        }
    }
}

struct SetupPane: View {
    @ObservedObject private var localization = Localization.shared
    @ObservedObject var engine: GestureEngine
    @ObservedObject var configStore: ConfigStore
    @ObservedObject var permissions: PermissionsManager
    @State private var mode = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker(L("Mode"), selection: $mode) {
                Text(L("Welcome")).tag(0)
                Text(L("Calibration")).tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if mode == 0 {
                OnboardingView(engine: engine, configStore: configStore, permissions: permissions)
            } else {
                CalibrationView(engine: engine, configStore: configStore)
            }
        }
        .navigationTitle(L("Welcome"))
    }
}

private struct SettingsScroll<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                content
            }
            .padding(22)
        }
    }
}

struct GeneralSettingsView: View {
    @ObservedObject private var localization = Localization.shared
    @ObservedObject var engine: GestureEngine
    @ObservedObject var configStore: ConfigStore
    @State private var launchLogin = LaunchAtLogin.isEnabled
    @State private var showCalibration = false

    var body: some View {
        SettingsScroll {
            CoastCardGroup(title: L("Language"), footer: L("Changes take effect immediately.")) {
                CoastRow {
                    Text(L("Interface language"))
                } trailing: {
                    Picker(L("Language"), selection: $localization.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(verbatim: language.nativeName).tag(language)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityLabel(L("Interface language"))
                }
            }
            CoastCardGroup(title: L("Detection"), footer: detectionFooter) {
                CoastRow {
                    HStack(spacing: 8) {
                        PulseDot(isOn: engine.isRunning)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(engine.isRunning ? L("Detection On") : L("Detection Off"))
                                .font(.headline)
                            Text(L(engine.sensor.source.rawValue))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } trailing: {
                    Button(engine.isRunning ? L("Stop") : L("Start")) { engine.toggle() }
                        .controlSize(.small)
                        .disabled(!engine.sensor.isAvailable && !engine.isRunning)
                }

                #if DEBUG
                CoastToggleRow(
                    title: L("Simulate knocks with arrow keys"),
                    icon: "arrow.left.arrow.right",
                    isOn: Binding(
                        get: { engine.sensor.isArrowSimulationEnabled },
                        set: { engine.sensor.isArrowSimulationEnabled = $0 }
                    )
                ) { on in
                    if engine.isRunning {
                        engine.stop()
                        if on { engine.start() }
                    }
                }
                #endif

                CoastToggleRow(title: L("Enable gesture actions"), icon: "bolt.fill", isOn: $configStore.config.enabled) { _ in
                    configStore.save()
                }
                CoastToggleRow(title: L("Open at login"), icon: "power.circle", isOn: $launchLogin) { v in
                    _ = LaunchAtLogin.setEnabled(v)
                }
            }

            CoastCardGroup(title: L("Sensitivity"), footer: L("A firm knuckle on the side edge should fire. If the trackpad or typing also fires, turn this down.")) {
                sliderRow(L("Sensitivity"), value: $configStore.config.sensitivity, range: 0...1) { v in
                    engine.detector.sensitivity = v
                }
                CoastRow {
                    Text(L("Threshold"))
                } trailing: {
                    Text(String(format: "%.3f g · %@", currentThreshold, sensitivityLabel))
                        .foregroundStyle(.secondary)
                        .font(.caption.monospacedDigit())
                }
            }

            CoastCardGroup(title: L("Timing")) {
                sliderRow(L("Multi-tap window"), value: $configStore.config.tapGroupingWindow, range: 0.15...0.55) { v in
                    engine.detector.groupingWindow = v
                }
                CoastRow {
                    Text(L("Window"))
                } trailing: {
                    Text(String(format: L("%.2f s"), configStore.config.tapGroupingWindow))
                        .foregroundStyle(.secondary)
                        .font(.caption.monospacedDigit())
                }
                sliderRow(L("Action cooldown"), value: $configStore.config.actionCooldown, range: 0.05...0.6)
                CoastRow {
                    Text(L("Cooldown"))
                } trailing: {
                    Text(String(format: L("%.2f s"), configStore.config.actionCooldown))
                        .foregroundStyle(.secondary)
                        .font(.caption.monospacedDigit())
                }
            }

            CoastCardGroup(title: L("Overlay"), footer: L("A short confirmation appears when a gesture is recognized. Optional.")) {
                CoastToggleRow(title: L("Show on-screen overlay"), icon: "rectangle.inset.filled", isOn: $configStore.config.showHUD) { _ in
                    configStore.save()
                }
                if configStore.config.showHUD {
                    CoastButtonRow(title: L("Preview Overlay"), icon: "sparkles") {
                        HUDController.shared.preview()
                    }
                }
            }

            CoastCardGroup(title: L("Accuracy"), footer: configStore.config.layout == .knock
                           ? L("Knock ignores left vs right. Knocks are ignored for a moment after any key so typing does not fire actions.")
                           : TapDetector.sideHeuristicDescription) {
                if configStore.config.layout == .sides {
                CoastToggleRow(title: L("Invert left and right"), icon: "arrow.left.arrow.right", isOn: $configStore.config.invertSides) { v in
                    engine.detector.invertSides = v
                    configStore.save()
                }
                }
                CoastToggleRow(title: L("Ignore taps while typing"), icon: "keyboard", isOn: $configStore.config.ignoreWhileTyping) { v in
                    engine.detector.ignoreWhileTyping = v
                    configStore.save()
                }
                if configStore.config.layout == .sides {
                CoastButtonRow(title: L("Calibrate Left / Right"), icon: "ruler") {
                    showCalibration = true
                }
                }
                CoastButtonRow(title: L("Replay intro"), icon: "sparkles") {
                    IntroWindowController.shared.show(engine: engine)
                }
            }

            CoastCardGroup {
                CoastButtonRow(title: L("Reset Settings"), icon: "arrow.counterclockwise", role: .destructive) {
                    configStore.reset()
                    engine.detector.sensitivity = configStore.config.sensitivity
                    SoundManager.shared.sync(from: configStore.config)
                }
            }
        }
        .sheet(isPresented: $showCalibration) {
            CalibrationView(engine: engine, configStore: configStore)
                .frame(width: 420, height: 360)
        }
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, onChange: ((Double) -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L(title))
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: value, in: range, step: 0.01)
                .onChange(of: value.wrappedValue) { _, v in
                    configStore.save()
                    onChange?(v)
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .coastCapsule()
    }

    private var detectionFooter: String? {
        if !engine.sensor.isAvailable {
            return L("This Mac’s motion sensor isn’t accessible. Detection stays off so the keyboard is untouched.")
        }
        if engine.sensor.source == .keyboardSim {
            return L("Debug only: Left/Right arrows inject fake taps. They never send shortcuts.")
        }
        if engine.sensor.isStreaming {
            return L("Receiving %d Hz from the built-in motion sensor.", Int(engine.sensor.sampleRateHz))
        }
        return nil
    }

    private var currentThreshold: Double {
        0.050 - configStore.config.sensitivity * (0.050 - 0.012)
    }

    private var sensitivityLabel: String {
        if configStore.config.sensitivity < 0.35 { return L("Firm taps") }
        if configStore.config.sensitivity < 0.7 { return L("Balanced") }
        return L("Light taps")
    }
}

struct GesturesSettingsView: View {
    @ObservedObject private var localization = Localization.shared
    @ObservedObject var engine: GestureEngine
    @ObservedObject var configStore: ConfigStore
    @State private var expandedRuleID: UUID?

    var body: some View {
        SettingsScroll {
            VStack(alignment: .leading, spacing: 8) {
                CoastSectionHeader(title: L("Layout"))
                Picker(L("Layout"), selection: layoutBinding) {
                    Text(L("Anywhere")).tag(GestureLayout.knock)
                    Text(L("Left & Right")).tag(GestureLayout.sides)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(configStore.config.layout == .knock
                     ? L("Knock the chassis or the desk. One, two, or three taps.")
                     : L("Left and right edges are different actions."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
            }

            CoastCardGroup(footer: presetFooter) {
                CoastRow {
                    Text(L("Preset"))
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
                        HStack(spacing: 4) {
                            Text(L(configStore.currentPreset?.title ?? L("Custom")))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }

            if configStore.config.layout == .knock {
                CoastCardGroup(title: L("Actions")) {
                    ForEach(leftSlots) { slot in
                        GestureSlotRow(slot: binding(for: slot), layout: .knock)
                    }
                }
            } else {
                CoastCardGroup(title: L("Left")) {
                    ForEach(leftSlots) { slot in
                        GestureSlotRow(slot: binding(for: slot), layout: .sides)
                    }
                }
                CoastCardGroup(title: L("Right")) {
                    ForEach(rightSlots) { slot in
                        GestureSlotRow(slot: binding(for: slot), layout: .sides)
                    }
                }
            }

            CoastCardGroup(
                title: L("Per app"),
                footer: configStore.config.layout == .knock
                    ? L("When that app is frontmost, these three knocks replace the ones above.")
                    : L("When that app is frontmost, listed taps replace the global ones.")
            ) {
                Menu {
                    Button(L("Frontmost app")) { addRuleForFrontmost() }
                    Divider()
                    ForEach(runningApps, id: \.processIdentifier) { app in
                        Button(app.localizedName ?? app.bundleIdentifier ?? L("App")) {
                            addRule(for: app)
                        }
                    }
                } label: {
                    Label(L("Add app"), systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .menuStyle(.borderlessButton)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .coastCapsule(interactive: true)

                ForEach($configStore.config.appRules) { $rule in
                    AppRuleCard(
                        rule: $rule,
                        layout: configStore.config.layout,
                        isExpanded: expandedRuleID == rule.id
                    ) {
                        withAnimation(.snappy(duration: 0.2)) {
                            expandedRuleID = expandedRuleID == rule.id ? nil : rule.id
                        }
                    } onDelete: {
                        configStore.config.appRules.removeAll { $0.id == rule.id }
                        configStore.save()
                    }
                }
            }
        }
    }

    private var presetFooter: String? {
        if let preset = configStore.currentPreset {
            return configStore.config.layout == .knock ? preset.knockLine : preset.subtitle
        }
        return L("Custom mix of actions.")
    }

    private var layoutBinding: Binding<GestureLayout> {
        Binding(
            get: { configStore.config.layout },
            set: { newValue in
                configStore.config.layout = newValue
                configStore.save()
            }
        )
    }

    private var leftSlots: [GestureSlot] {
        configStore.config.slots.filter { $0.side == .left }.sorted { $0.tapCount < $1.tapCount }
    }

    private var rightSlots: [GestureSlot] {
        configStore.config.slots.filter { $0.side == .right }.sorted { $0.tapCount < $1.tapCount }
    }

    private func binding(for slot: GestureSlot) -> Binding<GestureSlot> {
        Binding(
            get: { configStore.config.slots.first { $0.id == slot.id } ?? slot },
            set: { newValue in
                if let idx = configStore.config.slots.firstIndex(where: { $0.id == slot.id }) {
                    configStore.config.slots[idx] = newValue
                    configStore.markSlotsCustom()
                }
            }
        )
    }

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { app in
                app.activationPolicy == .regular
                    && app.bundleIdentifier != "app.mactap.MacTap"
                    && app.bundleIdentifier != nil
            }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func addRuleForFrontmost() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        addRule(for: app)
    }

    private func addRule(for app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier, bundleID != "app.mactap.MacTap" else { return }
        if configStore.config.appRules.contains(where: { $0.bundleID == bundleID }) {
            expandedRuleID = configStore.config.appRules.first { $0.bundleID == bundleID }?.id
            return
        }
        let name = app.localizedName ?? bundleID
        let rule = AppRule(bundleID: bundleID, appName: name)
        configStore.config.appRules.append(rule)
        configStore.save()
        expandedRuleID = rule.id
    }
}

private struct AppRuleCard: View {
    @ObservedObject private var localization = Localization.shared
    @Binding var rule: AppRule
    var layout: GestureLayout
    var isExpanded: Bool
    var onToggle: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "app.dashed")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(rule.appName)
                    Text(rule.enabled ? (rule.slots.isEmpty ? L("Uses global actions") : L("%d custom", rule.slots.count)) : L("Off"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $rule.enabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                    .onChange(of: rule.enabled) { _, _ in
                        ConfigStore.shared.save()
                    }
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggle)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(visibleCounts, id: \.self) { count in
                        overrideRow(side: .left, tapCount: count)
                    }
                    if layout == .sides {
                        ForEach(1...3, id: \.self) { count in
                            overrideRow(side: .right, tapCount: count)
                        }
                    }
                    Button(L("Remove"), role: .destructive, action: onDelete)
                        .controlSize(.small)
                }
                .padding(.top, 12)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .coastCapsule()
    }

    private var visibleCounts: [Int] { [1, 2, 3] }

    private func overrideRow(side: TapSide, tapCount: Int) -> some View {
        let label = GestureSlot(side: side, tapCount: tapCount, actionType: .none, parameter: "")
            .label(layout: layout)
        return HStack(spacing: 8) {
            KnockTicks(
                count: tapCount,
                color: layout == .knock ? .orange : MacTapTheme.accent(for: side)
            )
            Text(L(label))
                .font(.caption)
                .frame(width: layout == .knock ? 52 : 88, alignment: .leading)
            Picker(L("Action"), selection: overrideBinding(side: side, tapCount: tapCount)) {
                Text(L("Inherit")).tag(Optional<ActionType>.none)
                ForEach(ActionCategory.allCases) { cat in
                    Section(L(cat.title)) {
                        ForEach(cat.types) { type in
                            Text(L(type.displayName)).tag(Optional(type))
                        }
                    }
                }
            }
            .labelsHidden()
        }
    }

    private func overrideBinding(side: TapSide, tapCount: Int) -> Binding<ActionType?> {
        Binding(
            get: { rule.override(side: side, tapCount: tapCount)?.actionType },
            set: { newValue in
                rule.slots.removeAll { $0.side == side && $0.tapCount == tapCount }
                if let newValue {
                    rule.slots.append(GestureSlot(side: side, tapCount: tapCount, actionType: newValue, parameter: ""))
                }
                ConfigStore.shared.save()
            }
        )
    }
}

struct GestureSlotRow: View {
    @ObservedObject private var localization = Localization.shared
    @Binding var slot: GestureSlot
    var layout: GestureLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                KnockTicks(
                    count: slot.tapCount,
                    color: layout == .knock ? .orange : MacTapTheme.accent(for: slot.side)
                )
                Text(L(slot.label(layout: layout)))
                    .font(.body.weight(.medium))
                    .frame(minWidth: 56, alignment: .leading)
                Spacer(minLength: 8)
                Picker(L("Action"), selection: $slot.actionType) {
                    ForEach(ActionCategory.allCases) { cat in
                        Section(L(cat.title)) {
                            ForEach(cat.types) { type in
                                Text(L(type.displayName)).tag(type)
                            }
                        }
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                Button {
                    ActionExecutor.shared.execute(slot)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(L("Test this action"))
                .accessibilityLabel(L("Test %@", slot.label(layout: layout)))
            }
            if slot.actionType.needsParameter {
                TextField(slot.actionType.parameterPlaceholder, text: $slot.parameter, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .coastCapsule()
    }
}



struct SensorMonitorView: View {
    @ObservedObject private var localization = Localization.shared
    @ObservedObject var engine: GestureEngine
    @ObservedObject private var configStore = ConfigStore.shared

    var body: some View {
        SettingsScroll {
            CoastCardGroup(title: L("Live")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(L("Magnitude"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(engine.sensor.sampleRateHz)) Hz")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    WaveformView(history: engine.sensor.waveformHistory)
                        .frame(height: 120)
                    ChassisSilhouette(
                        leftHot: engine.lastGesture == nil ? 0.15 : (configStore.config.layout == .knock ? 0.9 : (engine.lastGesture?.side == .left ? 1 : 0.15)),
                        rightHot: engine.lastGesture == nil ? 0.15 : (configStore.config.layout == .knock ? 0.9 : (engine.lastGesture?.side == .right ? 1 : 0.15)),
                        unified: configStore.config.layout == .knock
                    )
                    .frame(height: 44)
                }
                .padding(14)
                .coastCard()
            }

            CoastCardGroup(title: L("Status")) {
                if !engine.sensor.isAvailable {
                    Text(L("This Mac’s motion sensor isn’t accessible. Knock detection is off."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .coastCapsule()
                }
                labeled(L("Status"), engine.sensor.isStreaming ? L("Streaming") : L("Idle"))
                labeled(L("Source"), engine.sensor.source.rawValue)
                labeled(L("Rate"), "\(Int(engine.sensor.sampleRateHz)) Hz")
                labeled(L("Samples"), "\(engine.sensor.sampleCount)")
            }

            CoastCardGroup(title: L("Axes")) {
                WaveformView(history: engine.sensor.axisHistoryX.map(abs), color: .orange)
                    .frame(height: 44)
                    .padding(10)
                    .coastCapsule()
                WaveformView(history: engine.sensor.axisHistoryY.map(abs), color: .green)
                    .frame(height: 44)
                    .padding(10)
                    .coastCapsule()
                WaveformView(history: engine.sensor.axisHistoryZ.map(abs), color: .yellow)
                    .frame(height: 44)
                    .padding(10)
                    .coastCapsule()
            }

            CoastCardGroup(title: L("Values")) {
                if let sample = engine.sensor.lastSample {
                    AxisValueRow(label: L("X · lateral"), value: sample.x, color: .orange)
                    AxisValueRow(label: L("Y · long"), value: sample.y, color: .green)
                    AxisValueRow(label: L("Z · vertical"), value: sample.z, color: .yellow)
                    AxisValueRow(label: L("Magnitude"), value: sample.magnitude, color: .blue, bold: true)
                    AxisValueRow(label: L("Noise floor"), value: engine.detector.noiseFloor, color: .secondary)
                } else {
                    Text(L("Start detection to see sensor data."))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .frame(minHeight: MacTapTheme.rowHeight)
                        .coastCapsule()
                }
            }

            CoastCardGroup(title: L("Classifier")) {
                labeled(L("Pending taps"), "\(engine.detector.pendingTapCount)")
                if let g = engine.detector.lastDetectedGesture {
                    labeled(L("Last gesture"), configStore.config.layout == .knock
                            ? L(g.tapWord)
                            : "\(L(g.side.displayName)) · \(L(g.tapWord))")
                }
                if !engine.detector.lastRejectReason.isEmpty {
                    labeled(L("Last reject"), engine.detector.lastRejectReason)
                }
            }
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        CoastRow {
            Text(L(title))
        } trailing: {
            Text(L(value))
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }
}

struct AxisValueRow: View {
    @ObservedObject private var localization = Localization.shared
    let label: String
    let value: Double
    let color: Color
    var bold: Bool = false

    var body: some View {
        CoastRow {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(L(label)).fontWeight(bold ? .semibold : .regular)
            }
        } trailing: {
            Text(String(format: "%+.4f g", value))
                .monospacedDigit()
                .foregroundStyle(bold ? .primary : .secondary)
        }
    }
}

struct PermissionsSettingsView: View {
    @ObservedObject private var localization = Localization.shared
    @ObservedObject var permissions: PermissionsManager

    var body: some View {
        SettingsScroll {
            CoastCardGroup {
                if permissions.allGranted {
                    CoastRow {
                        Label(L("Accessibility is allowed. Actions can run."), systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } trailing: {
                        EmptyView()
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L("MacTap needs Accessibility to send shortcuts and media keys. Other permissions are optional."))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            permissions.requestAccessibility()
                        } label: {
                            Label(L("Allow Accessibility…"), systemImage: "key.fill")
                        }
                    }
                    .padding(14)
                    .coastCapsule()
                }
            }

            PermissionStepRow(
                stepNumber: 1,
                title: L("Accessibility"),
                description: L("Required to send Search, copy, paste, and other shortcuts. macOS lists keystroke posting here."),
                state: permissions.canPostEvents ? .granted : permissions.accessibility,
                isCurrentStep: permissions.currentStep == 1,
                isRequired: true,
                onRequest: { permissions.requestAccessibility() },
                onOpenSettings: { permissions.openAccessibilitySettings() }
            )
            PermissionStepRow(
                stepNumber: 2,
                title: L("Input Monitoring"),
                description: L("Optional. Accessibility already pauses knocks while you type; this is a fallback."),
                state: permissions.inputMonitoring,
                isCurrentStep: permissions.currentStep == 2,
                isRequired: false,
                onRequest: { permissions.requestInputMonitoring() },
                onOpenSettings: { permissions.openInputMonitoringSettings() }
            )
            PermissionStepRow(
                stepNumber: 3,
                title: L("Automation"),
                description: L("Needed so MacTap can ask System Events to type shortcuts (copy, paste, Spotlight)."),
                state: permissions.appleEvents,
                isCurrentStep: permissions.currentStep == 3,
                isRequired: true,
                onRequest: { permissions.requestAppleEvents() },
                onOpenSettings: { permissions.openAutomationSettings() }
            )

            CoastCardGroup {
                CoastButtonRow(title: L("Recheck Permissions"), icon: "arrow.clockwise") {
                    permissions.checkAll()
                }
            }
        }
    }
}

struct PermissionStepRow: View {
    @ObservedObject private var localization = Localization.shared
    let stepNumber: Int
    let title: String
    let description: String
    let state: PermissionState
    let isCurrentStep: Bool
    var isRequired: Bool = true
    let onRequest: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        CoastCardGroup(title: L("Step %d", stepNumber)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: state == .granted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(state == .granted ? .green : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(L(title)).font(.headline)
                            Text(isRequired ? L("Required") : L("Optional"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(isRequired ? .orange : .secondary)
                        }
                        Text(L(description))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                if state != .granted {
                    HStack {
                        Button(L("Allow"), action: onRequest)
                        Button(L("System Settings"), action: onOpenSettings)
                    }
                    .controlSize(.small)
                }
            }
            .padding(14)
            .coastCapsule()
        }
    }
}

struct SoundFXSettingsView: View {
    @ObservedObject private var localization = Localization.shared
    @ObservedObject var soundManager = SoundManager.shared
    @State private var previewingSound: String?

    var body: some View {
        SettingsScroll {
            CoastCardGroup(title: L("Playback"), footer: L("Left taps pan left and right taps pan right. Sounds are synthesized in-app.")) {
                CoastToggleRow(title: L("Play a sound on every gesture"), icon: "speaker.wave.2", isOn: $soundManager.isEnabled)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Volume"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: Binding(
                        get: { Double(soundManager.volume) },
                        set: { soundManager.volume = Float($0) }
                    ), in: 0...1)
                    Text("\(Int(soundManager.volume * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .coastCapsule()
            }

            CoastCardGroup(title: L("Pack")) {
                CoastRow {
                    Text(L("Sound Pack"))
                } trailing: {
                    Picker(L("Sound Pack"), selection: $soundManager.selectedPack) {
                        ForEach(SoundPack.allCases) { pack in
                            Text(L(pack.rawValue)).tag(pack)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }
                Text(L(soundManager.selectedPack.description))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .coastCapsule()
            }

            CoastCardGroup(title: L("Preview")) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(soundManager.selectedPack.sounds, id: \.self) { name in
                        Button {
                            previewingSound = name
                            soundManager.playSound(name)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                if previewingSound == name { previewingSound = nil }
                            }
                        } label: {
                            Text(L(name.capitalized))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .coastCapsule(interactive: true)
                    }
                }
            }
        }
        .onAppear { soundManager.preloadPack() }
    }
}

struct AboutView: View {
    @ObservedObject private var localization = Localization.shared
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
                .frame(width: 88, height: 88)
                .macGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            Text("MacTap")
                .font(.largeTitle.weight(.semibold))
            Text(L("Version %@", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"))
                .foregroundStyle(.secondary)

            Text(L("Tap the MacBook chassis to run shortcuts, control media, and more."))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)

            Spacer()
            Text("SwiftUI · IOKit · Core Audio")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(L("About"))
    }
}
