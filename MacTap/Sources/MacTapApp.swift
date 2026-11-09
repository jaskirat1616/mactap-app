import SwiftUI
import AppKit

@main
struct MacTapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            DashboardView(
                engine: appDelegate.engine,
                permissions: PermissionsManager.shared
            )
        } label: {
            MenuBarLabel(engine: appDelegate.engine)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(engine: appDelegate.engine)
        }
    }
}

struct MenuBarLabel: View {
    @ObservedObject private var localization = Localization.shared
    @ObservedObject var engine: GestureEngine

    var body: some View {
        Image(systemName: menuSymbol)
            .symbolRenderingMode(.hierarchical)
            .accessibilityLabel(L(menuAccessibilityLabel))
    }

    private var menuSymbol: String {
        if !engine.sensor.isAvailable { return "exclamationmark.triangle" }
        return engine.isRunning ? "hand.tap.fill" : "hand.tap"
    }

    private var menuAccessibilityLabel: String {
        if !engine.sensor.isAvailable { return L("MacTap, motion sensor unavailable") }
        return engine.isRunning ? L("MacTap, detection on") : L("MacTap, detection off")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = GestureEngine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        PermissionsManager.shared.checkOnLaunch()
        _ = HUDController.shared

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if IntroStore.needsIntro {
                IntroWindowController.shared.show(engine: self.engine)
            } else if ConfigStore.shared.config.enabled {
                NotificationCenter.default.post(name: .macTapAutoStart, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let macTapAutoStart = Notification.Name("macTapAutoStart")
}
