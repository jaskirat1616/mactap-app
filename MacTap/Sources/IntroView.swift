import SwiftUI
import AppKit
import Combine

enum IntroStore {
    static let revision = 4
    static let key = "app.mactap.introRevision"

    static var needsIntro: Bool {
        UserDefaults.standard.integer(forKey: key) < revision
            || !ConfigStore.shared.config.hasCompletedOnboarding
    }

    static func markComplete() {
        UserDefaults.standard.set(revision, forKey: key)
        ConfigStore.shared.config.hasCompletedOnboarding = true
        ConfigStore.shared.save()
    }
}

final class IntroWindowController: NSObject, NSWindowDelegate {
    static let shared = IntroWindowController()

    private var window: NSWindow?
    private var host: NSHostingView<IntroRoot>?

    private override init() {
        super.init()
    }

    private var escapeMonitor: Any?

    func show(engine: GestureEngine) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        if window == nil {
            let win = NSWindow(
                contentRect: frame,
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            win.title = "MacTap"
            win.backgroundColor = .black
            win.isOpaque = true
            win.hasShadow = false
            win.isReleasedWhenClosed = false
            win.isMovable = false
            win.hidesOnDeactivate = false
            win.animationBehavior = .none
            // Above normal apps, below system permission sheets.
            win.level = .floating
            win.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .stationary,
                .ignoresCycle
            ]
            win.delegate = self
            window = win
        }

        window?.setFrame(frame, display: true)
        window?.level = .floating

        let root = IntroRoot(engine: engine) { [weak self] in
            self?.close()
        }
        let host = NSHostingView(rootView: root)
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.black.cgColor
        window?.contentView = host
        self.host = host

        installEscapeMonitor()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        window?.setFrame(frame, display: true)
    }

    /// Let System Settings sit in front while the user flips Accessibility.
    func yieldToSystemSettings() {
        window?.level = .normal
        window?.orderBack(nil)
    }

    func bringToFront() {
        guard window?.isVisible == true else { return }
        window?.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func installEscapeMonitor() {
        if escapeMonitor != nil { return }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.close()
                return nil
            }
            return event
        }
    }

    func close() {
        IntroStore.markComplete()
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    func windowWillClose(_ notification: Notification) {
        IntroStore.markComplete()
    }
}

struct IntroRoot: View {
    @ObservedObject private var localization = Localization.shared
    @ObservedObject var engine: GestureEngine
    @ObservedObject var permissions = PermissionsManager.shared
    @ObservedObject var configStore = ConfigStore.shared
    var onFinish: () -> Void

    @State private var step: IntroStep = .splash

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if step != .splash {
                HorizonMist()
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if step != .splash {
                        Button(L("Skip")) { finish() }
                            .buttonStyle(.plain)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.45))
                            .padding(.trailing, 28)
                            .padding(.top, 18)
                    }
                }
                .frame(height: 48)

                ZStack {
                    stepView
                        .id(step)
                        .transition(ripple)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if step != .splash {
                    IntroDots(current: step.index, total: IntroStep.interactiveCount)
                        .padding(.bottom, 28)
                } else {
                    Color.clear.frame(height: 28)
                }
            }
        }
        .preferredColorScheme(.dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
            permissions.checkAll()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                guard step == .splash else { return }
                advance()
            }
        }
        .onChange(of: permissions.allGranted) { _, granted in
            if granted {
                IntroWindowController.shared.bringToFront()
            }
        }
        .onExitCommand { finish() }
    }

    @ViewBuilder
    private var stepView: some View {
        switch step {
        case .splash:
            CinematicSplash()
                .onTapGesture { advance() }
        case .welcome:
            WelcomeStep(onContinue: advance)
        case .features:
            FeaturesStep(onContinue: advance)
        case .permission:
            PermissionStep(permissions: permissions, onContinue: advance)
        case .tryTap:
            TryTapStep(engine: engine, onContinue: advance)
        case .finale:
            FinaleStep(onDone: finish)
        }
    }

    private var ripple: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.985)),
            removal: .opacity
        )
    }

    private func advance() {
        withAnimation(.smooth(duration: 0.55)) {
            if let next = IntroStep(rawValue: step.rawValue + 1) {
                step = next
            } else {
                finish()
            }
        }
    }

    private func finish() {
        if engine.sensor.isAvailable && permissions.allGranted && !engine.isRunning {
            engine.start()
        }
        onFinish()
    }
}

private enum IntroStep: Int, CaseIterable {
    case splash, welcome, features, permission, tryTap, finale

    var index: Int { max(0, rawValue - 1) }
    static var interactiveCount: Int { 5 }
}

// MARK: - Background (Coast intro horizon)

private struct HorizonMist: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let breathe = 0.5 + 0.5 * sin(t * 0.55)
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))

                let sun = CGPoint(x: size.width * 0.5, y: size.height * 1.08)
                let radius = size.width * (0.42 + 0.03 * breathe)
                context.drawLayer { ctx in
                    ctx.addFilter(.blur(radius: 48))
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: sun.x - radius, y: sun.y - radius, width: radius * 2, height: radius * 1.15)),
                        with: .radialGradient(
                            Gradient(colors: [
                                Color.white.opacity(0.55),
                                Color(red: 0.55, green: 0.72, blue: 1.0).opacity(0.22),
                                Color.orange.opacity(0.06),
                                .clear
                            ]),
                            center: sun,
                            startRadius: 10,
                            endRadius: radius
                        )
                    )
                }

                var arc = Path()
                arc.addArc(
                    center: CGPoint(x: size.width / 2, y: -size.height * 0.15),
                    radius: size.width * 0.62,
                    startAngle: .degrees(20),
                    endAngle: .degrees(160),
                    clockwise: false
                )
                context.stroke(
                    arc,
                    with: .color(Color(red: 0.62, green: 0.74, blue: 1.0).opacity(0.18 + 0.08 * breathe)),
                    lineWidth: 1.2
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Wordmark

private struct MacTapMark: View {
    var size: CGFloat = 28

    var body: some View {
        VStack(spacing: size * 0.16) {
            Capsule().frame(width: size * 0.42, height: size * 0.18)
            Capsule().frame(width: size * 0.68, height: size * 0.18)
            Capsule().frame(width: size, height: size * 0.18)
        }
        .foregroundStyle(.white.opacity(0.88))
        .accessibilityHidden(true)
    }
}

private struct Wordmark: View {
    var large = false

    var body: some View {
        HStack(spacing: large ? 22 : 12) {
            MacTapMark(size: large ? 48 : 20)
            Text("mactap")
                .font(.system(size: large ? 72 : 24, weight: .regular, design: .default))
                .tracking(-1.2)
                .foregroundStyle(.white.opacity(0.94))
        }
    }
}

// MARK: - Shared chrome

private struct IntroPill: View {
    @ObservedObject private var localization = Localization.shared
    let title: String
    var prominent: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(L(title))
                .font(.headline)
                .padding(.horizontal, 28)
                .frame(height: 42)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(prominent ? Color.black : Color.white.opacity(0.9))
        .background(
            Capsule(style: .continuous)
                .fill(prominent ? Color.white : Color.white.opacity(0.12))
        )
        .shadow(color: .white.opacity(prominent ? 0.18 : 0), radius: 16, y: 4)
    }
}

private struct IntroDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(Color.white.opacity(i == current ? 0.9 : 0.22))
                    .frame(width: i == current ? 18 : 6, height: 6)
                    .animation(.smooth(duration: 0.35), value: current)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct IntroCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(22)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white.opacity(0.07))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 0.8)
                    }
            }
    }
}

// MARK: - Steps

private struct CinematicSplash: View {
    @ObservedObject private var localization = Localization.shared
    var body: some View {
        ZStack {
            Color.black
            HorizonMist()

            VStack(spacing: 16) {
                Wordmark(large: true)
                Text(L("Knock an edge. Run a shortcut."))
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.42))
            }

            VStack {
                Spacer()
                Text(L("Click to continue · Esc to skip"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.28))
                    .padding(.bottom, 36)
            }
        }
    }
}

private struct WelcomeStep: View {
    @ObservedObject private var localization = Localization.shared
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Wordmark()
            VStack(spacing: 10) {
                Text(L("Six knocks.\nYour whole Mac."))
                    .font(.system(size: 56, weight: .semibold, design: .default))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                Text(L("Left and right edges. One, two, or three taps.\nCopy, paste, play, screenshot, Accept — without the keyboard."))
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            IntroPill(title: L("Continue"), action: onContinue)
                .padding(.top, 8)
        }
        .padding(.horizontal, 48)
    }
}

private struct FeaturesStep: View {
    @ObservedObject private var localization = Localization.shared
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Text(L("Built for real work."))
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)

            HStack(alignment: .top, spacing: 16) {
                feature(L("Presets"), icon: "square.grid.2x2", color: .orange, copy: L("Daily, Coding, Capture, Media, Focus — one click."))
                feature(L("Per-app"), icon: "app.badge", color: .blue, copy: L("Cursor gets Accept. Safari gets tabs. Overrides only there."))
                feature("1 · 2 · 3", icon: "hand.tap.fill", color: .white, copy: L("Six slots. Left and right stay different."))
            }
            .padding(.horizontal, 36)

            ChassisSilhouette(leftHot: 0.9, rightHot: 0.9)
                .frame(width: 180, height: 56)
                .padding(.top, 4)

            IntroPill(title: L("Continue"), action: onContinue)
        }
    }

    private func feature(_ title: String, icon: String, color: Color, copy: String) -> some View {
        IntroCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(L(title))
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(L(copy))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: 240)
    }
}

private struct PermissionStep: View {
    @ObservedObject private var localization = Localization.shared
    @ObservedObject var permissions: PermissionsManager
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Text(L("Enable Accessibility"))
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
            Text(L("Needed so a tap can send Search, copy, paste, and media keys. Detection itself does not need it."))
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.55))
                .frame(maxWidth: 520)

            IntroCard {
                HStack(spacing: 14) {
                    Image(systemName: permissions.allGranted ? "checkmark.circle.fill" : "lock.shield")
                        .font(.title)
                        .foregroundStyle(permissions.allGranted ? Color.green : Color.white.opacity(0.85))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Accessibility"))
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(permissions.allGranted ? L("Allowed. Actions can run.") : L("Required for actions"))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    if !permissions.allGranted {
                        IntroPill(title: L("Allow"), prominent: true) {
                            IntroWindowController.shared.yieldToSystemSettings()
                            permissions.requestAccessibility()
                        }
                    }
                }
            }
            .frame(maxWidth: 520)

            if permissions.allGranted {
                IntroPill(title: L("Continue"), action: onContinue)
            } else {
                Text(L("System Settings will open. Turn on MacTap, then this screen continues."))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                Button(L("Continue without actions")) { onContinue() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 40)
        .onAppear { permissions.checkAll() }
    }
}

private struct TryTapStep: View {
    @ObservedObject private var localization = Localization.shared
    @ObservedObject var engine: GestureEngine
    var onContinue: () -> Void
    @State private var heard = false

    var body: some View {
        VStack(spacing: 22) {
            if !engine.sensor.isAvailable {
                unsupported
            } else {
                listening
            }
        }
        .onAppear {
            if engine.sensor.isAvailable, !engine.isRunning { engine.start() }
        }
        .onChange(of: engine.flashToken) { _, _ in
            withAnimation(.smooth) { heard = engine.lastGesture != nil }
        }
    }

    private var unsupported: some View {
        VStack(spacing: 22) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(.orange)
            Text(L("This Mac can’t knock."))
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(L("MacTap needs the chassis motion sensor. Original M1 Air and some other models don’t expose it. Detection stays off so arrow keys keep working."))
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.55))
                .frame(maxWidth: 480)
            IntroPill(title: L("Continue"), action: onContinue)
        }
    }

    private var listening: some View {
        VStack(spacing: 22) {
            Text(heard ? L("Got it.") : L("Knock the left edge."))
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
            Text(heard
                 ? L("That’s a chassis tap. Left and right are different.")
                 : L("A light knock on the left side of the MacBook. We’ll listen."))
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.55))
                .frame(maxWidth: 480)

            ChassisSilhouette(
                leftHot: heard && engine.lastGesture?.side == .left ? 1 : (heard ? 0.2 : 0.85),
                rightHot: heard && engine.lastGesture?.side == .right ? 1 : 0.2
            )
            .frame(width: 220, height: 72)

            if heard, let g = engine.lastGesture {
                Text("\(L(g.side.displayName)) · \(L(g.tapCount == 1 ? "single" : g.tapCount == 2 ? "double" : "triple"))")
                    .font(.headline)
                    .foregroundStyle(MacTapTheme.accent(for: g.side))
                IntroPill(title: L("Continue"), action: onContinue)
            } else {
                Text(L("Waiting for a tap…"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.35))
                Button(L("Skip for now")) { onContinue() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}

private struct FinaleStep: View {
    @ObservedObject private var localization = Localization.shared
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "arrow.up.to.line")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(.white.opacity(0.85))
            Text(L("It’s in the menu bar."))
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.white)
            Text(L("Switch presets from there. Overlay and sounds stay optional."))
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.55))
                .frame(maxWidth: 460)
            IntroPill(title: L("Get Started"), action: onDone)
                .padding(.top, 10)
        }
    }
}
