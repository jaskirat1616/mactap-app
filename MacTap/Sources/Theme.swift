import SwiftUI
import AppKit

enum MacTapTheme {
    static func accent(for side: TapSide) -> Color {
        side == .left ? Color.orange : Color.blue
    }

    static let rowHeight: CGFloat = 36
    static let capsuleRadius: CGFloat = 13
    static let cardRadius: CGFloat = 18
    static let rowFill = Color.primary.opacity(0.06)
    static let rowFillInteractive = Color.primary.opacity(0.10)
}

/// AppKit HUD material that samples the desktop behind the window — Coast's HUDGlass.
struct HUDGlassView: NSViewRepresentable {
    var cornerRadius: CGFloat = MacTapTheme.capsuleRadius
    var material: NSVisualEffectView.Material = .hudWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.layer?.cornerRadius = cornerRadius
    }
}

extension View {
    @ViewBuilder
    func macGlass(in shape: some Shape = RoundedRectangle(cornerRadius: 16, style: .continuous)) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    @ViewBuilder
    func macGlassInteractive(in shape: some Shape = RoundedRectangle(cornerRadius: 16, style: .continuous)) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    /// Capsule glass used on every Coast-style row.
    @ViewBuilder
    func coastCapsule(interactive: Bool = false, fillOnly: Bool = false) -> some View {
        let shape = Capsule(style: .continuous)
        if fillOnly {
            self.background(interactive ? MacTapTheme.rowFillInteractive : MacTapTheme.rowFill, in: shape)
        } else if #available(macOS 26.0, *) {
            if interactive {
                self.glassEffect(.regular.tint(.white.opacity(0.12)).interactive(), in: shape)
            } else {
                self.glassEffect(.regular, in: shape)
            }
        } else {
            self.background {
                HUDGlassView(cornerRadius: MacTapTheme.capsuleRadius)
                    .clipShape(shape)
            }
        }
    }

    @ViewBuilder
    func coastCard(fillOnly: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: MacTapTheme.cardRadius, style: .continuous)
        if fillOnly {
            self.background(MacTapTheme.rowFill, in: shape)
        } else if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background {
                HUDGlassView(cornerRadius: MacTapTheme.cardRadius, material: .sidebar)
                    .clipShape(shape)
            }
        }
    }
}

struct CoastGlassStack<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                VStack(spacing: spacing) { content }
            }
        } else {
            VStack(spacing: spacing) { content }
        }
    }
}

struct CoastSectionHeader: View {
    @ObservedObject private var localization = Localization.shared
    let title: String

    var body: some View {
        Text(L(title))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.4)
            .padding(.horizontal, 6)
            .padding(.top, 10)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CoastCardGroup<Content: View>: View {
    @ObservedObject private var localization = Localization.shared
    var title: String?
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                CoastSectionHeader(title: title)
            }
            if #available(macOS 26.0, *) {
                GlassEffectContainer(spacing: 6) {
                    VStack(spacing: 6) { content }
                }
            } else {
                VStack(spacing: 6) { content }
            }
            if let footer {
                Text(L(footer))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct CoastRow<Leading: View, Trailing: View>: View {
    var fillOnly: Bool = false
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            leading
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 12)
        .frame(minHeight: MacTapTheme.rowHeight)
        .contentShape(Capsule())
        .coastCapsule(fillOnly: fillOnly)
    }
}

struct CoastToggleRow: View {
    @ObservedObject private var localization = Localization.shared
    let title: String
    var icon: String? = nil
    @Binding var isOn: Bool
    var fillOnly: Bool = false
    var onChange: ((Bool) -> Void)? = nil

    var body: some View {
        CoastRow(fillOnly: fillOnly) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                }
                Text(L(title))
            }
        } trailing: {
            Toggle(L(title), isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .onChange(of: isOn) { _, v in onChange?(v) }
        }
    }
}

struct CoastButtonRow: View {
    @ObservedObject private var localization = Localization.shared
    let title: String
    var icon: String? = nil
    var role: ButtonRole? = nil
    var fillOnly: Bool = false
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .frame(width: 16)
                }
                Text(L(title))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: MacTapTheme.rowHeight)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .coastCapsule(interactive: true, fillOnly: fillOnly)
    }
}

struct CoastCapsuleButton: View {
    @ObservedObject private var localization = Localization.shared
    let title: String
    var icon: String? = nil
    var prominent: Bool = false
    var fillOnly: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(L(title))
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .frame(maxWidth: .infinity)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(prominent ? Color.primary : Color.secondary)
        .coastCapsule(interactive: true, fillOnly: fillOnly)
    }
}

struct KnockTicks: View {
    var count: Int
    var color: Color = .orange

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...3, id: \.self) { i in
                Capsule(style: .continuous)
                    .fill(i <= count ? color : Color.primary.opacity(0.14))
                    .frame(width: i <= count ? 9 : 6, height: 6)
            }
        }
        .frame(width: 36, alignment: .leading)
        .accessibilityHidden(true)
    }
}

struct ChassisSilhouette: View {
    var leftHot: Double = 0
    var rightHot: Double = 0
    var unified: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            if !unified {
                Capsule()
                    .fill(Color.orange.opacity(0.18 + leftHot * 0.72))
                    .frame(width: 5)
            }
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary.opacity(0.45))
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(.tertiary, lineWidth: 1)
                        .frame(width: 54, height: 18)
                        .offset(y: 10)
                }
                .overlay {
                    if unified {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.orange.opacity(0.18 + max(leftHot, rightHot) * 0.55), lineWidth: 1.2)
                    }
                }
            if !unified {
                Capsule()
                    .fill(Color.blue.opacity(0.18 + rightHot * 0.72))
                    .frame(width: 5)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

struct WaveformView: View {
    let history: [Double]
    var threshold: Double = 0.04
    var maxDisplay: Double = 0.12
    var color: Color = .accentColor

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let threshY = h - CGFloat(min(threshold / maxDisplay, 1)) * (h - 8) - 4

            var thresh = Path()
            thresh.move(to: CGPoint(x: 0, y: threshY))
            thresh.addLine(to: CGPoint(x: w, y: threshY))
            context.stroke(thresh, with: .color(.secondary.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

            guard history.count > 1 else { return }
            let step = w / CGFloat(history.count - 1)
            var path = Path()
            for (i, value) in history.enumerated() {
                let x = CGFloat(i) * step
                let n = min(value / maxDisplay, 1.0)
                let y = h - CGFloat(n) * (h - 8) - 4
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            var fill = path
            fill.addLine(to: CGPoint(x: w, y: h))
            fill.addLine(to: CGPoint(x: 0, y: h))
            fill.closeSubpath()
            context.fill(fill, with: .linearGradient(
                Gradient(colors: [color.opacity(0.28), color.opacity(0.02)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: h)
            ))
            context.stroke(path, with: .color(color), lineWidth: 1.5)
        }
    }
}

struct PulseDot: View {
    var isOn: Bool
    var color: Color = .green

    var body: some View {
        ZStack {
            if isOn {
                Circle()
                    .fill(color.opacity(0.28))
                    .frame(width: 10, height: 10)
            }
            Circle()
                .fill(isOn ? color : Color.secondary.opacity(0.35))
                .frame(width: 6, height: 6)
        }
        .accessibilityHidden(true)
    }
}
