import SwiftUI

struct OnboardingView: View {
    @ObservedObject var engine: GestureEngine
    @ObservedObject var configStore: ConfigStore
    @ObservedObject var permissions: PermissionsManager
    @State private var step = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: stepIcon)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 64, height: 64)
                .coastCard()

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.largeTitle.weight(.semibold))
                Text(bodyCopy)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Group {
                switch step {
                case 0:
                    ChassisSilhouette(leftHot: 0.45, rightHot: 0.45)
                        .frame(height: 96)
                case 1:
                    if permissions.allGranted {
                        Label("Accessibility is on", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Open Accessibility Settings") {
                            permissions.requestAccessibility()
                        }
                        .modifier(OnboardGlassProminent())
                    }
                default:
                    EmptyView()
                }
            }

            Spacer()

            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }
                        .modifier(OnboardGlass())
                }
                Spacer()
                Button(step == 2 ? "Get Started" : "Continue") {
                    if step == 2 {
                        configStore.config.hasCompletedOnboarding = true
                        configStore.save()
                        if permissions.allGranted && !engine.isRunning {
                            engine.start()
                        }
                    } else {
                        step += 1
                    }
                }
                .modifier(OnboardGlassProminent())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var stepIcon: String {
        ["laptopcomputer", "lock.shield", "hand.tap"][min(step, 2)]
    }

    private var title: String {
        ["Tap the chassis", "Allow Accessibility", "Choose your actions"][min(step, 2)]
    }

    private var bodyCopy: String {
        [
            "MacTap uses the MacBook motion sensors. Knock the left or right edge once, twice, or three times to run a shortcut.",
            "Accessibility is required so MacTap can send keyboard shortcuts and media keys. Knocks are ignored while you type.",
            "Map each gesture in Gestures. Use Calibration if left and right feel swapped. Sound effects and the tap HUD are optional."
        ][min(step, 2)]
    }
}

struct CalibrationView: View {
    @ObservedObject var engine: GestureEngine
    @ObservedObject var configStore: ConfigStore
    @State private var leftPeaks: [Double] = []
    @State private var rightPeaks: [Double] = []
    @State private var message = "Tap the left edge four times, pausing at least half a second between knocks."
    @State private var collectingRight = false
    @State private var saved = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Side Calibration")
                .font(.title2.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                calColumn(title: "Left", count: leftPeaks.count)
                calColumn(title: "Right", count: rightPeaks.count)
            }

            if leftPeaks.count == 4 && !collectingRight {
                Button("Continue with right edge") {
                    engine.resetCalibrationSamples()
                    collectingRight = true
                    message = "Now tap the right edge four times, pausing between knocks."
                }
                .modifier(OnboardGlassProminent())
            }

            if leftPeaks.count >= 4 && rightPeaks.count >= 4 && !saved {
                Button("Save Calibration") { commit() }
                    .modifier(OnboardGlassProminent())
            }

            Button("Reset Samples") {
                leftPeaks.removeAll()
                rightPeaks.removeAll()
                collectingRight = false
                saved = false
                engine.resetCalibrationSamples()
                message = "Tap the left edge four times, pausing between knocks."
            }
            .modifier(OnboardGlass())

            Button(saved ? "Done" : "Cancel") { dismiss() }
                .modifier(OnboardGlass())

            Spacer()
        }
        .padding(24)
        .onAppear {
            engine.beginCalibration()
        }
        .onDisappear { engine.endCalibration() }
        .onReceive(engine.calibrationGestures) { gesture in
            ingest(gesture)
        }
    }

    private func calColumn(title: String, count: Int) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(count)/4")
                .font(.title.monospacedDigit().weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .coastCard()
    }

    private func ingest(_ g: DetectedGesture) {
        guard !saved else { return }
        guard g.tapCount == 1, !g.isSimulated, abs(g.peakX) >= 0.0024 else {
            message = "Sample skipped. Use one clear side knock, then pause at least half a second."
            return
        }
        if !collectingRight && leftPeaks.count < 4 {
            leftPeaks.append(g.peakX)
            message = leftPeaks.count >= 4 ? "Left samples ready. Click Continue before tapping the right edge." : "Left \(leftPeaks.count) of 4"
        } else if collectingRight && rightPeaks.count < 4 {
            rightPeaks.append(g.peakX)
            message = rightPeaks.count >= 4 ? "Ready to save." : "Right \(rightPeaks.count) of 4"
        }
    }

    private func commit() {
        let leftMean = leftPeaks.reduce(0, +) / Double(leftPeaks.count)
        let rightMean = rightPeaks.reduce(0, +) / Double(rightPeaks.count)
        guard abs(leftMean - rightMean) >= 0.0048 else {
            message = "The two edges look too similar. Reset samples and try clear side knocks."
            return
        }
        configStore.config.invertSides = leftMean > rightMean
        configStore.config.sideBias = -(leftMean + rightMean) / 2
        configStore.save()
        saved = true
        message = configStore.config.invertSides
            ? "Saved. Left and right were swapped for this Mac."
            : "Saved. Side detection kept as-is."
    }
}

private struct OnboardGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

private struct OnboardGlassProminent: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}
