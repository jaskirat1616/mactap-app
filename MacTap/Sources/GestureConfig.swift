import Foundation
import SwiftUI

// MARK: - Action Types

enum ActionType: String, CaseIterable, Codable, Identifiable {
    case none
    case copy
    case paste
    case cut
    case undo
    case redo
    case save
    case selectAll
    case aiAccept
    case aiReject
    case newTab
    case closeTab
    case screenshot
    case screenshotSelection
    case mediaPlayPause
    case mediaNext
    case mediaPrevious
    case mute
    case volumeUp
    case volumeDown
    case lockScreen
    case sleepDisplay
    case missionControl
    case spotlight
    case showDesktop
    case hideFrontApp
    case hideOthers
    case switchDesktopLeft
    case switchDesktopRight
    case tileLeft
    case tileRight
    case notificationCenter
    case startScreensaver
    case toggleDarkMode
    case dictation
    case openApp
    case openURL
    case runShortcut
    case keyboardShortcut
    case shellCommand
    case appleScript
    case soundFX

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:                 return "No Action"
        case .copy:                 return "Copy"
        case .paste:                return "Paste"
        case .cut:                  return "Cut"
        case .undo:                 return "Undo"
        case .redo:                 return "Redo"
        case .save:                 return "Save"
        case .selectAll:            return "Select All"
        case .aiAccept:             return "AI Accept"
        case .aiReject:             return "AI Reject"
        case .newTab:               return "New Tab"
        case .closeTab:             return "Close Tab"
        case .screenshot:           return "Screenshot"
        case .screenshotSelection:  return "Screenshot Selection"
        case .mediaPlayPause:       return "Play / Pause"
        case .mediaNext:            return "Next Track"
        case .mediaPrevious:        return "Previous Track"
        case .mute:                 return "Toggle Mute"
        case .volumeUp:             return "Volume Up"
        case .volumeDown:           return "Volume Down"
        case .lockScreen:           return "Lock Screen"
        case .sleepDisplay:         return "Sleep Display"
        case .missionControl:       return "Mission Control"
        case .spotlight:            return "Spotlight"
        case .showDesktop:          return "Show Desktop"
        case .hideFrontApp:         return "Hide Front App"
        case .hideOthers:           return "Hide Others"
        case .switchDesktopLeft:    return "Desktop ←"
        case .switchDesktopRight:   return "Desktop →"
        case .tileLeft:             return "Tile Window Left"
        case .tileRight:            return "Tile Window Right"
        case .notificationCenter:   return "Notification Center"
        case .startScreensaver:     return "Screensaver"
        case .toggleDarkMode:       return "Toggle Dark Mode"
        case .dictation:            return "Dictation"
        case .openApp:              return "Open App"
        case .openURL:              return "Open URL"
        case .runShortcut:          return "Run Shortcut"
        case .keyboardShortcut:     return "Keyboard Shortcut"
        case .shellCommand:         return "Shell Command"
        case .appleScript:          return "AppleScript"
        case .soundFX:              return "Sound FX Only"
        }
    }

    var icon: String {
        switch self {
        case .none:                 return "circle.dashed"
        case .copy:                 return "doc.on.doc"
        case .paste:                return "doc.on.clipboard"
        case .cut:                  return "scissors"
        case .undo:                 return "arrow.uturn.backward"
        case .redo:                 return "arrow.uturn.forward"
        case .save:                 return "square.and.arrow.down"
        case .selectAll:            return "selection.pin.in.out"
        case .aiAccept:             return "checkmark.circle"
        case .aiReject:             return "xmark.circle"
        case .newTab:               return "plus.square.on.square"
        case .closeTab:             return "xmark.square"
        case .screenshot:           return "camera.viewfinder"
        case .screenshotSelection:  return "camera.metering.center.weighted"
        case .mediaPlayPause:       return "playpause"
        case .mediaNext:            return "forward.fill"
        case .mediaPrevious:        return "backward.fill"
        case .mute:                 return "speaker.slash"
        case .volumeUp:             return "speaker.plus"
        case .volumeDown:           return "speaker.minus"
        case .lockScreen:           return "lock.fill"
        case .sleepDisplay:         return "moon.zzz.fill"
        case .missionControl:       return "squares.below.rectangle"
        case .spotlight:            return "magnifyingglass"
        case .showDesktop:          return "menubar.dock.rectangle"
        case .hideFrontApp:         return "eye.slash"
        case .hideOthers:           return "eye.slash.fill"
        case .switchDesktopLeft:    return "arrow.left.to.line"
        case .switchDesktopRight:   return "arrow.right.to.line"
        case .tileLeft:             return "rectangle.lefthalf.filled"
        case .tileRight:            return "rectangle.righthalf.filled"
        case .notificationCenter:   return "bell.badge"
        case .startScreensaver:     return "sparkles.tv"
        case .toggleDarkMode:       return "circle.lefthalf.filled"
        case .dictation:            return "mic.fill"
        case .openApp:              return "app.badge"
        case .openURL:              return "safari"
        case .runShortcut:          return "arrow.triangle.branch"
        case .keyboardShortcut:     return "keyboard"
        case .shellCommand:         return "terminal"
        case .appleScript:          return "applescript"
        case .soundFX:              return "speaker.wave.2.fill"
        }
    }

    var needsAccessibility: Bool {
        switch self {
        case .none, .soundFX, .openApp, .openURL, .runShortcut, .shellCommand:
            return false
        case .appleScript, .toggleDarkMode, .notificationCenter, .startScreensaver, .sleepDisplay:
            return false
        default:
            return true
        }
    }

    var category: ActionCategory {
        switch self {
        case .none, .soundFX:
            return .none
        case .copy, .paste, .cut, .undo, .redo, .save, .selectAll, .aiAccept, .aiReject, .newTab, .closeTab:
            return .editing
        case .screenshot, .screenshotSelection, .dictation:
            return .capture
        case .mediaPlayPause, .mediaNext, .mediaPrevious, .mute, .volumeUp, .volumeDown:
            return .media
        case .lockScreen, .sleepDisplay, .missionControl, .spotlight, .showDesktop, .hideFrontApp, .hideOthers, .notificationCenter, .startScreensaver, .toggleDarkMode:
            return .system
        case .switchDesktopLeft, .switchDesktopRight, .tileLeft, .tileRight:
            return .windows
        case .openApp, .openURL, .runShortcut, .keyboardShortcut, .shellCommand, .appleScript:
            return .custom
        }
    }

    var needsParameter: Bool {
        switch self {
        case .shellCommand, .appleScript, .openURL, .keyboardShortcut, .openApp, .runShortcut:
            return true
        default:
            return false
        }
    }

    var parameterLabel: String {
        switch self {
        case .shellCommand:     return "Shell command"
        case .appleScript:      return "AppleScript"
        case .openURL:          return "URL"
        case .keyboardShortcut: return "Shortcut"
        case .openApp:          return "App name or bundle ID"
        case .runShortcut:      return "Shortcuts name"
        default:                return ""
        }
    }

    var parameterPlaceholder: String {
        switch self {
        case .shellCommand:     return "screencapture -i ~/Desktop/shot.png"
        case .appleScript:      return "tell application \"Safari\" to activate"
        case .openURL:          return "https://example.com"
        case .keyboardShortcut: return "cmd+shift+3"
        case .openApp:          return "Cursor  or  com.todesktop.230313mzl4w4u92"
        case .runShortcut:      return "Do Not Disturb"
        default:                return ""
        }
    }
}

enum ActionCategory: String, CaseIterable, Identifiable {
    case none, editing, capture, media, system, windows, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .editing: return "Editing"
        case .capture: return "Capture"
        case .media: return "Media"
        case .system: return "System"
        case .windows: return "Windows"
        case .custom: return "Custom"
        }
    }

    var types: [ActionType] {
        ActionType.allCases.filter { $0.category == self }
    }
}

enum TapSide: String, Codable, CaseIterable {
    case left
    case right

    var displayName: String { rawValue.capitalized }

    var opposite: TapSide { self == .left ? .right : .left }
}

struct GestureSlot: Codable, Identifiable, Hashable {
    var id: String { "\(side.rawValue)_\(tapCount)" }
    var side: TapSide
    var tapCount: Int
    var actionType: ActionType
    var parameter: String

    var displayName: String {
        "\(side.displayName) × \(tapCount)"
    }

    var summary: String {
        if actionType == .none { return "Off" }
        if actionType.needsParameter, !parameter.isEmpty {
            return "\(actionType.displayName) · \(parameter)"
        }
        return actionType.displayName
    }

    func label(layout: GestureLayout) -> String {
        switch layout {
        case .knock:
            return L(tapWord)
        case .sides:
            return "\(L(side.displayName)) · \(L(tapWord))"
        }
    }

    var tapWord: String {
        switch tapCount {
        case 1: return "Single"
        case 2: return "Double"
        default: return "Triple"
        }
    }
}

struct AppRule: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var bundleID: String
    var appName: String
    var enabled: Bool
    /// Present slots override the global map. Missing slots inherit.
    var slots: [GestureSlot]

    init(
        id: UUID = UUID(),
        bundleID: String,
        appName: String,
        enabled: Bool = true,
        slots: [GestureSlot] = []
    ) {
        self.id = id
        self.bundleID = bundleID
        self.appName = appName
        self.enabled = enabled
        self.slots = slots
    }

    func override(side: TapSide, tapCount: Int) -> GestureSlot? {
        slots.first { $0.side == side && $0.tapCount == tapCount }
    }
}

enum GesturePreset: String, CaseIterable, Identifiable, Codable {
    case daily
    case coding
    case capture
    case media
    case focus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: return "Daily"
        case .coding: return "Coding"
        case .capture: return "Capture"
        case .media: return "Media"
        case .focus: return "Focus"
        }
    }

    var knockLine: String {
        let left = slots.filter { $0.side == .left }.sorted { $0.tapCount < $1.tapCount }
        return left.map { L($0.actionType.displayName) }.joined(separator: " · ")
    }

    var subtitle: String {
        switch self {
        case .daily: return "Copy, paste, play, screenshot, lock"
        case .coding: return "Accept, reject, save — built for Cursor and Claude"
        case .capture: return "Full and partial screenshots"
        case .media: return "Play, skip, volume"
        case .focus: return "Hide, tile, lock, sleep"
        }
    }

    var icon: String {
        switch self {
        case .daily: return "star.fill"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .capture: return "camera.viewfinder"
        case .media: return "playpause"
        case .focus: return "moon.fill"
        }
    }

    var slots: [GestureSlot] {
        switch self {
        case .daily:
            return [
                GestureSlot(side: .left,  tapCount: 1, actionType: .copy, parameter: ""),
                GestureSlot(side: .left,  tapCount: 2, actionType: .paste, parameter: ""),
                GestureSlot(side: .left,  tapCount: 3, actionType: .undo, parameter: ""),
                GestureSlot(side: .right, tapCount: 1, actionType: .mediaPlayPause, parameter: ""),
                GestureSlot(side: .right, tapCount: 2, actionType: .screenshot, parameter: ""),
                GestureSlot(side: .right, tapCount: 3, actionType: .lockScreen, parameter: ""),
            ]
        case .coding:
            return [
                GestureSlot(side: .left,  tapCount: 1, actionType: .aiAccept, parameter: ""),
                GestureSlot(side: .left,  tapCount: 2, actionType: .aiReject, parameter: ""),
                GestureSlot(side: .left,  tapCount: 3, actionType: .save, parameter: ""),
                GestureSlot(side: .right, tapCount: 1, actionType: .copy, parameter: ""),
                GestureSlot(side: .right, tapCount: 2, actionType: .paste, parameter: ""),
                GestureSlot(side: .right, tapCount: 3, actionType: .undo, parameter: ""),
            ]
        case .capture:
            return [
                GestureSlot(side: .left,  tapCount: 1, actionType: .screenshot, parameter: ""),
                GestureSlot(side: .left,  tapCount: 2, actionType: .screenshotSelection, parameter: ""),
                GestureSlot(side: .left,  tapCount: 3, actionType: .lockScreen, parameter: ""),
                GestureSlot(side: .right, tapCount: 1, actionType: .mediaPlayPause, parameter: ""),
                GestureSlot(side: .right, tapCount: 2, actionType: .mediaNext, parameter: ""),
                GestureSlot(side: .right, tapCount: 3, actionType: .mute, parameter: ""),
            ]
        case .media:
            return [
                GestureSlot(side: .left,  tapCount: 1, actionType: .mediaPrevious, parameter: ""),
                GestureSlot(side: .left,  tapCount: 2, actionType: .volumeDown, parameter: ""),
                GestureSlot(side: .left,  tapCount: 3, actionType: .mute, parameter: ""),
                GestureSlot(side: .right, tapCount: 1, actionType: .mediaPlayPause, parameter: ""),
                GestureSlot(side: .right, tapCount: 2, actionType: .mediaNext, parameter: ""),
                GestureSlot(side: .right, tapCount: 3, actionType: .volumeUp, parameter: ""),
            ]
        case .focus:
            return [
                GestureSlot(side: .left,  tapCount: 1, actionType: .hideFrontApp, parameter: ""),
                GestureSlot(side: .left,  tapCount: 2, actionType: .tileLeft, parameter: ""),
                GestureSlot(side: .left,  tapCount: 3, actionType: .lockScreen, parameter: ""),
                GestureSlot(side: .right, tapCount: 1, actionType: .missionControl, parameter: ""),
                GestureSlot(side: .right, tapCount: 2, actionType: .tileRight, parameter: ""),
                GestureSlot(side: .right, tapCount: 3, actionType: .sleepDisplay, parameter: ""),
            ]
        }
    }

    static func matching(_ slots: [GestureSlot]) -> GesturePreset? {
        allCases.first { signature($0.slots) == signature(slots) }
    }

    private static func signature(_ slots: [GestureSlot]) -> String {
        slots
            .sorted { ($0.side.rawValue, $0.tapCount) < ($1.side.rawValue, $1.tapCount) }
            .map { "\($0.side.rawValue).\($0.tapCount).\($0.actionType.rawValue).\($0.parameter)" }
            .joined(separator: "|")
    }
}

struct GestureStats: Codable, Equatable {
    var gesturesFired: Int = 0
    var tapsDetected: Int = 0
    var lastDayStamp: String = ""
    var todayCount: Int = 0

    mutating func record(tapCount: Int) {
        let stamp = Self.dayStamp()
        if stamp != lastDayStamp {
            lastDayStamp = stamp
            todayCount = 0
        }
        gesturesFired += 1
        tapsDetected += tapCount
        todayCount += 1
    }

    static func dayStamp() -> String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

enum GestureLayout: String, Codable, CaseIterable, Identifiable {
    case knock
    case sides

    var id: String { rawValue }

    var title: String {
        switch self {
        case .knock: return "Anywhere"
        case .sides: return "Left & Right"
        }
    }

    var subtitle: String {
        switch self {
        case .knock: return "Like Knock — one, two, or three taps on the chassis or desk"
        case .sides: return "Separate actions for each edge"
        }
    }
}

struct AppConfig: Codable {
    /// Side noise must not split a sequence when both sides resolve to the
    /// same actions. Include per-app overrides when deciding equivalence.
    func hasDistinctSideActions(bundleID: String?) -> Bool {
        guard layout == .sides else { return false }
        let overrides = appRules.first { $0.enabled && $0.bundleID == bundleID }?.slots ?? []
        func resolved(_ side: TapSide, _ count: Int) -> GestureSlot? {
            overrides.first { $0.side == side && $0.tapCount == count }
                ?? slots.first { $0.side == side && $0.tapCount == count }
        }
        return (1...3).contains { count in
            let left = resolved(.left, count), right = resolved(.right, count)
            return (left?.actionType ?? .none) != (right?.actionType ?? .none)
                || (left?.parameter ?? "") != (right?.parameter ?? "")
        }
    }

    var slots: [GestureSlot]
    var sensitivity: Double
    var tapGroupingWindow: Double
    var enabled: Bool
    var configVersion: Int
    var invertSides: Bool
    var ignoreWhileTyping: Bool
    var showHUD: Bool
    var actionCooldown: Double
    var sideBias: Double
    var soundEnabled: Bool
    var soundPack: String
    var soundVolume: Float
    var hasCompletedOnboarding: Bool
    var stats: GestureStats
    var appRules: [AppRule]
    var activePreset: String
    var layout: GestureLayout

    static let `default` = AppConfig(
        slots: GesturePreset.daily.slots,
        sensitivity: 0.70,
        tapGroupingWindow: 0.40,
        enabled: true,
        configVersion: 5,
        invertSides: false,
        ignoreWhileTyping: true,
        showHUD: true,
        actionCooldown: 0.18,
        sideBias: 0,
        soundEnabled: false,
        soundPack: SoundPack.drumKit.rawValue,
        soundVolume: 0.7,
        hasCompletedOnboarding: false,
        stats: GestureStats(),
        appRules: [
            AppRule(
                bundleID: "com.todesktop.230313mzl4w4u92",
                appName: "Cursor",
                slots: [
                    GestureSlot(side: .left, tapCount: 1, actionType: .aiAccept, parameter: ""),
                    GestureSlot(side: .left, tapCount: 2, actionType: .aiReject, parameter: ""),
                    GestureSlot(side: .left, tapCount: 3, actionType: .save, parameter: ""),
                ]
            ),
            AppRule(
                bundleID: "com.anthropic.claudefordesktop",
                appName: "Claude",
                slots: [
                    GestureSlot(side: .left, tapCount: 1, actionType: .aiAccept, parameter: ""),
                    GestureSlot(side: .left, tapCount: 2, actionType: .aiReject, parameter: ""),
                ]
            ),
        ],
        activePreset: GesturePreset.daily.rawValue,
        layout: .knock
    )

    init(
        slots: [GestureSlot],
        sensitivity: Double,
        tapGroupingWindow: Double,
        enabled: Bool,
        configVersion: Int,
        invertSides: Bool,
        ignoreWhileTyping: Bool,
        showHUD: Bool,
        actionCooldown: Double,
        sideBias: Double,
        soundEnabled: Bool,
        soundPack: String,
        soundVolume: Float,
        hasCompletedOnboarding: Bool,
        stats: GestureStats,
        appRules: [AppRule],
        activePreset: String,
        layout: GestureLayout
    ) {
        self.slots = slots
        self.sensitivity = sensitivity
        self.tapGroupingWindow = tapGroupingWindow
        self.enabled = enabled
        self.configVersion = configVersion
        self.invertSides = invertSides
        self.ignoreWhileTyping = ignoreWhileTyping
        self.showHUD = showHUD
        self.actionCooldown = actionCooldown
        self.sideBias = sideBias
        self.soundEnabled = soundEnabled
        self.soundPack = soundPack
        self.soundVolume = soundVolume
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.stats = stats
        self.appRules = appRules
        self.activePreset = activePreset
        self.layout = layout
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        slots = try c.decodeIfPresent([GestureSlot].self, forKey: .slots) ?? AppConfig.default.slots
        sensitivity = try c.decodeIfPresent(Double.self, forKey: .sensitivity) ?? 0.70
        if abs(sensitivity - 0.84) < 0.002 || abs(sensitivity - 0.62) < 0.002 {
            sensitivity = 0.70
        }
        tapGroupingWindow = try c.decodeIfPresent(Double.self, forKey: .tapGroupingWindow) ?? 0.40
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        configVersion = try c.decodeIfPresent(Int.self, forKey: .configVersion) ?? 5
        invertSides = try c.decodeIfPresent(Bool.self, forKey: .invertSides) ?? false
        ignoreWhileTyping = try c.decodeIfPresent(Bool.self, forKey: .ignoreWhileTyping) ?? true
        showHUD = try c.decodeIfPresent(Bool.self, forKey: .showHUD) ?? true
        actionCooldown = try c.decodeIfPresent(Double.self, forKey: .actionCooldown) ?? 0.18
        sideBias = try c.decodeIfPresent(Double.self, forKey: .sideBias) ?? 0
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? false
        soundPack = try c.decodeIfPresent(String.self, forKey: .soundPack) ?? SoundPack.drumKit.rawValue
        soundVolume = try c.decodeIfPresent(Float.self, forKey: .soundVolume) ?? 0.7
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        stats = try c.decodeIfPresent(GestureStats.self, forKey: .stats) ?? GestureStats()
        appRules = try c.decodeIfPresent([AppRule].self, forKey: .appRules) ?? AppConfig.default.appRules
        activePreset = try c.decodeIfPresent(String.self, forKey: .activePreset) ?? "custom"
        layout = try c.decodeIfPresent(GestureLayout.self, forKey: .layout) ?? .knock
        if slots.count < 6 {
            slots = AppConfig.default.slots
        }
        if let match = GesturePreset.matching(slots) {
            activePreset = match.rawValue
        }
    }
}

final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()

    @Published var config: AppConfig

    private let key = "app.mactap.config.v3"
    private let legacyKeys = ["app.mactap.config.v2", "app.mactap.config.v1"]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) {
            self.config = decoded
        } else if let migrated = Self.migrate(from: defaults) {
            self.config = migrated
            self.save()
        } else {
            self.config = .default
            self.save()
        }
        for k in legacyKeys { defaults.removeObject(forKey: k) }
    }

    private static func migrate(from defaults: UserDefaults) -> AppConfig? {
        for k in ["app.mactap.config.v2", "app.mactap.config.v1"] {
            if let data = defaults.data(forKey: k),
               let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) {
                var c = decoded
                c.configVersion = 3
                return c
            }
        }
        return nil
    }

    func save() {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: key)
        }
    }

    func reset() {
        let onboarded = config.hasCompletedOnboarding
        let stats = config.stats
        config = .default
        config.hasCompletedOnboarding = onboarded
        config.stats = stats
        save()
    }

    func applyPreset(_ preset: GesturePreset) {
        config.slots = preset.slots
        config.activePreset = preset.rawValue
        save()
    }

    func markSlotsCustom() {
        if GesturePreset.matching(config.slots) == nil {
            config.activePreset = "custom"
        } else if let match = GesturePreset.matching(config.slots) {
            config.activePreset = match.rawValue
        }
        save()
    }

    func slot(for side: TapSide, tapCount: Int) -> GestureSlot? {
        config.slots.first { $0.side == side && $0.tapCount == tapCount }
    }

    func resolvedSlot(side: TapSide, tapCount: Int, bundleID: String?) -> GestureSlot? {
        if config.layout == .knock {
            if let bundleID,
               let rule = config.appRules.first(where: { $0.enabled && $0.bundleID == bundleID }) {
                if let override = rule.slots.first(where: { $0.tapCount == tapCount }) {
                    return override
                }
            }
            return slot(for: .left, tapCount: tapCount)
        }
        if let bundleID,
           let rule = config.appRules.first(where: { $0.enabled && $0.bundleID == bundleID }),
           let override = rule.override(side: side, tapCount: tapCount) {
            return override
        }
        return slot(for: side, tapCount: tapCount)
    }

    var currentPreset: GesturePreset? {
        GesturePreset(rawValue: config.activePreset) ?? GesturePreset.matching(config.slots)
    }
}
