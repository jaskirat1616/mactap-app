import SwiftUI
import AppKit

/// Floating confirmation HUD. Optional — gated by `AppConfig.showHUD`.
final class HUDController {
    static let shared = HUDController()

    private var panel: NSPanel?
    private var host: NSHostingView<HUDView>?
    private var hideWork: DispatchWorkItem?
    private let model = HUDModel()
    private var permissionObserver: NSObjectProtocol?

    private init() {
        permissionObserver = NotificationCenter.default.addObserver(
            forName: .macTapNeedsAccessibility,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.flashNeedsAccessibility()
        }
    }

    func flash(_ gesture: DetectedGesture, slot: GestureSlot?) {
        DispatchQueue.main.async { self.show(gesture, slot: slot) }
    }

    func preview() {
        let layout = ConfigStore.shared.config.layout
        let side: TapSide = layout == .knock ? .left : .right
        let tapCount = 2
        let slot = ConfigStore.shared.resolvedSlot(side: side, tapCount: tapCount, bundleID: nil)
            ?? GestureSlot(side: side, tapCount: tapCount, actionType: .copy, parameter: "")
        let gesture = DetectedGesture(
            side: side,
            tapCount: tapCount,
            timestamp: 0,
            peakMagnitude: 0.04,
            peakX: 0.02
        )
        flash(gesture, slot: slot)
    }

    func flashNeedsAccessibility() {
        DispatchQueue.main.async {
            let gesture = DetectedGesture(
                side: .left,
                tapCount: 1,
                timestamp: 0,
                peakMagnitude: 0,
                peakX: 0
            )
            self.model.permissionPrompt = true
            self.show(gesture, slot: nil)
        }
    }

    private func show(_ gesture: DetectedGesture, slot: GestureSlot?) {
        ensurePanel()
        place(side: gesture.side)

        model.gesture = gesture
        model.slot = slot
        if slot != nil { model.permissionPrompt = false }
        model.bounceToken &+= 1

        panel?.orderFrontRegardless()

        hideWork?.cancel()
        withAnimation(HUDMotion.appear) {
            model.visible = true
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            withAnimation(HUDMotion.dismiss) {
                self.model.visible = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + HUDMotion.dismissDuration) {
                if !self.model.visible {
                    self.panel?.orderOut(nil)
                }
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + HUDMotion.hold, execute: work)
    }

    private func ensurePanel() {
        guard panel == nil else { return }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: HUDLayout.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        let host = NSHostingView(rootView: HUDView(model: model))
        host.wantsLayer = true
        host.layer?.isOpaque = false
        host.layer?.backgroundColor = NSColor.clear.cgColor
        host.frame = NSRect(origin: .zero, size: HUDLayout.size)
        panel.contentView = host

        self.host = host
        self.panel = panel
    }

    private func place(side: TapSide) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let knock = ConfigStore.shared.config.layout == .knock
        let bias: CGFloat = knock ? 0 : (side == .left ? -HUDLayout.sideBias : HUDLayout.sideBias)
        let origin = NSPoint(
            x: visible.midX - HUDLayout.size.width / 2 + bias,
            y: visible.midY - HUDLayout.size.height / 2 + HUDLayout.verticalLift
        )
        panel?.setFrame(NSRect(origin: origin, size: HUDLayout.size), display: true)
    }
}

private enum HUDLayout {
    static let size = NSSize(width: 248, height: 236)
    static let sideBias: CGFloat = 108
    static let verticalLift: CGFloat = 18
}

private enum HUDMotion {
    static let hold: TimeInterval = 1.28
    static let dismissDuration: TimeInterval = 0.28
    static let appear: Animation = .spring(response: 0.38, dampingFraction: 0.78)
    static let dismiss: Animation = .easeIn(duration: dismissDuration)
}

final class HUDModel: ObservableObject {
    @Published var gesture: DetectedGesture?
    @Published var slot: GestureSlot?
    @Published var visible = false
    @Published var bounceToken = 0
    @Published var permissionPrompt = false
}

struct HUDView: View {
    @ObservedObject private var localization = Localization.shared
    @ObservedObject var model: HUDModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            Color.clear
            if let gesture = model.gesture {
                card(for: gesture)
                    .opacity(model.visible ? 1 : 0)
                    .scaleEffect(scale)
                    .offset(y: model.visible ? 0 : 10)
                    .blur(radius: model.visible || reduceMotion ? 0 : 6)
            }
        }
        .frame(width: HUDLayout.size.width, height: HUDLayout.size.height)
        .allowsHitTesting(false)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : HUDMotion.appear, value: model.visible)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : HUDMotion.appear, value: model.bounceToken)
    }

    private var scale: CGFloat {
        if reduceMotion { return 1 }
        return model.visible ? 1 : 0.88
    }

    private func card(for gesture: DetectedGesture) -> some View {
        let layout = ConfigStore.shared.config.layout
        let accent = model.permissionPrompt
            ? Color.orange
            : (layout == .knock ? Color.orange : MacTapTheme.accent(for: gesture.side))
        let action = resolvedAction
        let title: String
        let subtitle: String
        let icon: String
        if model.permissionPrompt {
            title = L("Allow Accessibility")
            subtitle = L("Then knocks can send shortcuts")
            icon = "lock.shield"
        } else {
            title = action == .none ? tapCaption(gesture.tapCount) : L(action.displayName)
            subtitle = action == .none
                ? (layout == .knock ? L("Anywhere") : L(gesture.side.displayName))
                : (layout == .knock ? tapCaption(gesture.tapCount) : "\(L(gesture.side.displayName)) · \(tapCaption(gesture.tapCount))")
            icon = action == .none ? "hand.tap.fill" : action.icon
        }

        return VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 42, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accent)
                .symbolEffect(.bounce, value: model.bounceToken)
                .frame(width: 72, height: 56)

            VStack(spacing: 3) {
                Text(L(title))
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(L(subtitle))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            tapTicks(count: gesture.tapCount, accent: accent)

            if layout == .sides {
            HUDChassisMark(side: gesture.side)
                .frame(height: 26)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .frame(width: 200)
        .background {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.regularMaterial)
            } else {
                HUDGlassView(cornerRadius: 22)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(accent.opacity(0.22), lineWidth: 0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(layout == .knock
                            ? "\(tapCaption(gesture.tapCount)), \(title)"
                            : "\(L(gesture.side.displayName)), \(tapCaption(gesture.tapCount)), \(title)")
    }

    private var resolvedAction: ActionType {
        guard let slot = model.slot else { return .none }
        return slot.actionType
    }

    private func tapTicks(count: Int, accent: Color) -> some View {
        HStack(spacing: 6) {
            ForEach(1...3, id: \.self) { index in
                let on = index <= count
                Capsule(style: .continuous)
                    .fill(on ? accent : Color.primary.opacity(0.16))
                    .frame(width: on ? 16 : 7, height: 7)
            }
        }
        .accessibilityHidden(true)
    }

    private func tapCaption(_ count: Int) -> String {
        switch count {
        case 1: return L("Single")
        case 2: return L("Double")
        default: return L("Triple")
        }
    }
}

private struct HUDChassisMark: View {
    let side: TapSide

    var body: some View {
        HStack(spacing: 5) {
            Capsule(style: .continuous)
                .fill(side == .left ? Color.orange : Color.orange.opacity(0.18))
                .frame(width: 3, height: 20)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(.tertiary, lineWidth: 1.15)
                .frame(width: 38, height: 22)
                .overlay {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(.quaternary)
                        .frame(width: 16, height: 2.5)
                        .offset(y: 6)
                }
            Capsule(style: .continuous)
                .fill(side == .right ? Color.blue : Color.blue.opacity(0.18))
                .frame(width: 3, height: 20)
        }
        .accessibilityHidden(true)
    }
}

