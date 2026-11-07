import Foundation
import Combine
import AppKit

final class GestureEngine: ObservableObject {

    @Published var isRunning = false
    @Published var lastGesture: DetectedGesture?
    @Published var lastExecutedSlot: GestureSlot?
    @Published var flashToken: Int = 0
    @Published var hudGesture: DetectedGesture?
    @Published private(set) var isCalibrating = false
    let calibrationGestures = PassthroughSubject<DetectedGesture, Never>()
    private var wasRunningBeforeCalibration = false

    let sensor = SensorManager()
    private(set) lazy var detector = TapDetector(sensor: sensor)

    private var cancellables = Set<AnyCancellable>()
    private var lastActionAt: Double = 0

    init() {
        detector.onGesture = { [weak self] gesture in
            self?.handle(gesture)
        }

        ConfigStore.shared.$config
            .sink { [weak self] config in
                self?.apply(config)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .macTapAutoStart)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, !self.isRunning else { return }
                guard ConfigStore.shared.config.enabled else { return }
                self.start()
            }
            .store(in: &cancellables)

        apply(ConfigStore.shared.config)
        SoundManager.shared.sync(from: ConfigStore.shared.config)
    }

    private func apply(_ config: AppConfig) {
        detector.sensitivity = config.sensitivity
        detector.groupingWindow = config.tapGroupingWindow
        detector.invertSides = isCalibrating ? false : config.invertSides
        detector.sideBias = isCalibrating ? 0 : config.sideBias
        detector.ignoreWhileTyping = config.ignoreWhileTyping
        detector.classifySides = isCalibrating || config.layout == .sides
    }

    func beginCalibration() {
        guard !isCalibrating else { return }
        wasRunningBeforeCalibration = isRunning
        isCalibrating = true
        detector.resetSession()
        apply(ConfigStore.shared.config)
        if !isRunning { start() }
    }

    func resetCalibrationSamples() {
        detector.resetSession()
    }

    func endCalibration() {
        guard isCalibrating else { return }
        detector.resetSession()
        isCalibrating = false
        apply(ConfigStore.shared.config)
        if !wasRunningBeforeCalibration { stop() }
    }

    func start() {
        apply(ConfigStore.shared.config)
        guard sensor.start() else {
            isRunning = false
            NSLog("MacTap: engine not started — this Mac does not expose the motion sensor")
            return
        }
        isRunning = true
        NSLog("MacTap: engine started")
    }

    func stop() {
        sensor.stop()
        isRunning = false
        NSLog("MacTap: engine stopped")
    }

    func toggle() {
        if isRunning { stop() } else { start() }
    }

    func handle(_ gesture: DetectedGesture) {
        if isCalibrating {
            calibrationGestures.send(gesture)
            return
        }
        let config = ConfigStore.shared.config
        lastGesture = gesture
        flashToken &+= 1
        hudGesture = gesture

        ConfigStore.shared.config.stats.record(tapCount: gesture.tapCount)
        ConfigStore.shared.save()

        let frontID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let slot = ConfigStore.shared.resolvedSlot(
            side: gesture.side,
            tapCount: gesture.tapCount,
            bundleID: frontID
        )
        if config.showHUD {
            HUDController.shared.flash(gesture, slot: slot)
        }

        if config.soundEnabled || SoundManager.shared.isEnabled {
            SoundManager.shared.playTapSound(side: gesture.side, tapCount: gesture.tapCount)
        }

        guard config.enabled else { return }

        let now = Date().timeIntervalSince1970
        if now - lastActionAt < config.actionCooldown { return }
        lastActionAt = now

        guard let slot, slot.actionType != .none else { return }
        if gesture.isSimulated {
            NSLog("MacTap: simulated tap ignored by ActionExecutor")
            return
        }

        lastExecutedSlot = slot
        let frontApp = NSWorkspace.shared.frontmostApplication
        DispatchQueue.main.async {
            ActionExecutor.shared.execute(slot, targeting: frontApp)
        }
    }
}
