import Foundation
import Combine
import QuartzCore
import CoreGraphics

struct DetectedGesture: Sendable, Equatable {
    let side: TapSide
    let tapCount: Int
    let timestamp: Double
    let peakMagnitude: Double
    let peakX: Double
    var isSimulated: Bool = false

    var tapWord: String {
        switch tapCount {
        case 1: return "Single"
        case 2: return "Double"
        default: return "Triple"
        }
    }
}

/// Chassis-tap classifier on the undocumented SPU IMU (~800 Hz accel + gyro).
///
/// Onset uses a fast two-stage high-pass signal to separate fresh contacts
/// from the chassis' long low-frequency resonance. Side follows Knocker, but
/// at native 800 Hz we can do better: only the attack (~30 ms) counts, the
/// pre-tap X baseline is subtracted so gravity leak cannot pin every tap to
/// one edge, and bounce after ~35 ms is ignored.
final class TapDetector: ObservableObject {

    @Published private(set) var lastDetectedGesture: DetectedGesture?
    @Published private(set) var rawTapPulse: Double = 0
    @Published private(set) var pendingTapCount: Int = 0
    @Published private(set) var currentMagnitude: Double = 0
    @Published private(set) var noiseFloor: Double = 0.02
    @Published private(set) var lastRejectReason: String = ""

    var sensitivity: Double = 0.7
    var groupingWindow: Double = 0.32
    var invertSides = false
    var sideBias: Double = 0
    var ignoreWhileTyping = true
    var classifySides = false
    var splitOnSideChange = true

    private var cancellables = Set<AnyCancellable>()
    private weak var sensor: SensorManager?
    private let queue = DispatchQueue(label: "app.mactap.detector", qos: .userInteractive)

    private let refractoryPeriod: Double = 0.14
    // Chassis resonance can last seconds. Rearm on the short impact signal,
    // rather than waiting for the entire low-frequency vibration to stop.
    private let settlingPeriod: Double = 0.025
    private var fastX = 0.0, fastY = 0.0, fastZ = 0.0
    private var transientX = 0.0, transientY = 0.0, transientZ = 0.0
    private var readyForNextTap = true
    private var quietSince: Double?
    private var deliveryEpoch = 0
    private let minCaptureTime: Double = 0.032
    private let attackWindow: Double = 0.034
    private let attackTau: Double = 0.011
    private let typingBurstWindow: Double = 0.50
    private let typingLockout: Double = 0.40
    /// Pause knocks after a key press. Short enough for a follow-up knock, long enough for hunt-and-peck.
    private let keySuppressWindow: Double = 0.45

    private var adaptiveNoise: Double = 0.006
    private var emaMag: Double = 0
    private var lastTapTime: Double = -1
    private var currentTapCount: Int = 0
    private var currentSide: TapSide = .left
    private var groupDeadline: Double = 0
    private var groupPeakMag: Double = 0
    private var groupPeakX: Double = 0

    private var capturing = false
    private var captureStart: Double = 0
    private var capturePeakMag: Double = 0
    private var captureSamples: Int = 0
    private var baselineX: Double = 0
    private var weightedX: Double = 0
    private var weightSum: Double = 0
    private var attackPeakX: Double = 0
    private var attackAbsX: Double = 0
    private var attackSumZ: Double = 0
    private var captureSimulated = false
    private var groupSimulated = false

    private var histX: [Double] = []
    private var histT: [Double] = []
    private let histMax = 96

    private var impulseTimes: [Double] = []
    private var typingUntil: Double = -1
    private var lastUIPublish: Double = 0
    private var lastKeyTime: Double = -10
    private var lastTypingCheck: Double = 0
    private var cachedTyping = false

    private var tapThreshold: Double {
        let minT = 0.012
        let maxT = 0.050
        return maxT - sensitivity * (maxT - minT)
    }

    private var snrMultiplier: Double {
        3.0 - sensitivity * 1.2
    }

    init(sensor: SensorManager) {
        self.sensor = sensor
        histX.reserveCapacity(histMax)
        histT.reserveCapacity(histMax)
        bind()
    }

    private func bind() {
        sensor?.sampleStream
            .receive(on: queue)
            .sink { [weak self] sample in
                self?.process(sample)
            }
            .store(in: &cancellables)

        sensor?.typingActivity
            .receive(on: queue)
            .sink { [weak self] in
                self?.lastKeyTime = CACurrentMediaTime()
            }
            .store(in: &cancellables)
    }

    func notifyTyping() {
        queue.async { [weak self] in
            self?.lastKeyTime = CACurrentMediaTime()
        }
    }

    /// Called on the main thread when entering/leaving calibration. Also
    /// invalidate results already waiting on the main queue.
    func resetSession() {
        queue.sync {
            deliveryEpoch &+= 1
            capturing = false
            resetCapture()
            currentTapCount = 0
            groupPeakMag = 0
            groupPeakX = 0
            groupSimulated = false
            groupDeadline = 0
            lastTapTime = -1
            readyForNextTap = false
            quietSince = nil
            impulseTimes.removeAll()
            typingUntil = -1
        }
        pendingTapCount = 0
        lastDetectedGesture = nil
    }

    private func process(_ sample: SensorSample) {
        let mag = sample.magnitude
        let now = sample.timestamp

        pushHistory(x: sample.x, t: now)

        emaMag = 0.02 * mag + 0.98 * emaMag
        let delta = mag - emaMag

        // Two high-pass stages at the native ~800 Hz rate reject the smooth
        // chassis oscillation while retaining a new contact's sharp attack.
        let alpha = 0.35
        fastX += alpha * (sample.x - fastX)
        fastY += alpha * (sample.y - fastY)
        fastZ += alpha * (sample.z - fastZ)
        let hx = sample.x - fastX, hy = sample.y - fastY, hz = sample.z - fastZ
        transientX += alpha * (hx - transientX)
        transientY += alpha * (hy - transientY)
        transientZ += alpha * (hz - transientZ)
        let tx = hx - transientX, ty = hy - transientY, tz = hz - transientZ
        let impact = sqrt(tx * tx + ty * ty + tz * tz)
        let impactThreshold = max(0.009, tapThreshold * 0.25)

        if mag < tapThreshold * 0.9 {
            adaptiveNoise = 0.02 * mag + 0.98 * adaptiveNoise
        }
        adaptiveNoise = min(max(adaptiveNoise, 0.0035), 0.030)

        let threshold = max(tapThreshold * 0.88, adaptiveNoise * snrMultiplier)
        let keyedRecently = ignoreWhileTyping && isActivelyTyping()
        let inTypingLockout = now < typingUntil || keyedRecently
        let inRefractory = (now - lastTapTime) < refractoryPeriod
        let onset = (mag > threshold || delta > threshold)
            && impact > impactThreshold

        if !readyForNextTap && !capturing {
            if impact < impactThreshold * 0.6 {
                if quietSince == nil { quietSince = now }
                if now - (quietSince ?? now) >= settlingPeriod {
                    readyForNextTap = true
                }
            } else {
                quietSince = nil
            }
        }

        if capturing {
            absorb(sample)
            let elapsed = now - captureStart
            let quiet = mag < capturePeakMag * 0.35 && elapsed >= (classifySides ? minCaptureTime : 0.006)
            if quiet || elapsed >= attackWindow || captureSamples > 100 {
                finalizeCapture(now: now, inTypingLockout: inTypingLockout, keyedRecently: keyedRecently)
            }
        } else if readyForNextTap && !inRefractory && onset {
            if keyedRecently {
                publishReject("typing")
            } else {
                startCapture(sample)
            }
        }

        if currentTapCount > 0 && now >= groupDeadline && !capturing {
            emitGesture(now: now)
        }

        if now - lastUIPublish > 0.05 {
            lastUIPublish = now
            let noise = adaptiveNoise
            let pending = currentTapCount
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.currentMagnitude = mag
                self.rawTapPulse = mag
                self.noiseFloor = noise
                self.pendingTapCount = pending
            }
        }
    }

    /// Session/HID last-key time does not need Input Monitoring. The global
    /// NSEvent monitor is a backup when that permission is granted.
    private func isActivelyTyping() -> Bool {
        let wall = CACurrentMediaTime()
        if wall - lastKeyTime < keySuppressWindow {
            return true
        }
        if wall - lastTypingCheck < 0.02 {
            return cachedTyping
        }
        lastTypingCheck = wall
        let session = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let hid = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .keyDown)
        cachedTyping = min(session, hid) < keySuppressWindow
        return cachedTyping
    }

    private func pushHistory(x: Double, t: Double) {
        histX.append(x)
        histT.append(t)
        let overflow = histX.count - histMax
        if overflow > 0 {
            histX.removeFirst(overflow)
            histT.removeFirst(overflow)
        }
    }

    /// Mean X from 15–90 ms before onset. Residual gravity on HP X is a DC
    /// offset; integrating it makes every tap look like the same side.
    private func preTapBaseline(at now: Double) -> Double {
        var sum = 0.0
        var n = 0
        for i in histX.indices {
            let age = now - histT[i]
            if age > 0.012 && age < 0.10 {
                sum += histX[i]
                n += 1
            }
        }
        guard n >= 4 else { return 0 }
        return sum / Double(n)
    }

    private func startCapture(_ sample: SensorSample) {
        capturing = true
        readyForNextTap = false
        quietSince = nil
        captureStart = sample.timestamp
        capturePeakMag = sample.magnitude
        captureSamples = 1
        baselineX = preTapBaseline(at: sample.timestamp)
        weightedX = 0
        weightSum = 0
        attackPeakX = 0
        attackAbsX = 0
        attackSumZ = 0
        captureSimulated = sample.isSimulated
        accumulateAttack(sample)
    }

    private func absorb(_ sample: SensorSample) {
        captureSamples += 1
        if sample.magnitude > capturePeakMag {
            capturePeakMag = sample.magnitude
        }
        if sample.isSimulated { captureSimulated = true }
        accumulateAttack(sample)
    }

    private func accumulateAttack(_ sample: SensorSample) {
        let t = sample.timestamp - captureStart
        guard t <= attackWindow else { return }
        let w = exp(-t / attackTau)
        let dx = sample.x - baselineX
        weightedX += dx * w
        weightSum += w
        attackSumZ += sample.z * w
        if abs(dx) > attackAbsX {
            attackAbsX = abs(dx)
            attackPeakX = dx
        }
    }

    private func finalizeCapture(now: Double, inTypingLockout: Bool, keyedRecently: Bool) {
        capturing = false
        let peak = capturePeakMag
        let width = now - captureStart
        let snr = adaptiveNoise > 0 ? peak / adaptiveNoise : 99
        let meanAttackX = weightSum > 1e-9 ? weightedX / weightSum : attackPeakX
        let meanAttackZ = weightSum > 1e-9 ? attackSumZ / weightSum : 0

        defer { resetCapture() }

        if width > 0.16 {
            publishReject("slow pulse")
            return
        }
        if snr < 1.6 {
            publishReject("low SNR")
            return
        }
        if keyedRecently && abs(meanAttackZ) > abs(meanAttackX) * 2.2 && attackAbsX < 0.010 {
            publishReject("vertical (typing)")
            return
        }
        if inTypingLockout {
            publishReject("typing lockout")
            return
        }

        impulseTimes.append(now)
        impulseTimes = impulseTimes.filter { now - $0 < typingBurstWindow }
        if impulseTimes.count >= 4 {
            typingUntil = now + typingLockout
            impulseTimes.removeAll()
            publishReject("burst lockout")
            return
        }

        let side = classifySides
            ? classifySide(meanX: meanAttackX, peakX: attackPeakX)
            : .left
        let reportX = meanAttackX

        lastTapTime = captureStart
        // Close the previous group BEFORE adding this knock. Otherwise a
        // side-changing knock belongs to both the old and new groups.
        if splitOnSideChange && currentTapCount > 0 && side != currentSide && abs(reportX) > 0.008 {
            emitGesture(now: now)
        }
        currentTapCount += 1
        groupPeakMag = max(groupPeakMag, peak)
        groupPeakX = abs(reportX) > abs(groupPeakX) ? reportX : groupPeakX
        groupSimulated = groupSimulated || captureSimulated

        if currentTapCount == 1 {
            currentSide = side
            groupSimulated = captureSimulated
        }
        // The window is the allowed gap to the NEXT knock, not the total
        // duration of a three-knock sequence.
        groupDeadline = now + groupingWindow

        if currentTapCount >= 3 {
            emitGesture(now: now)
        }
    }

    /// Two votes from the attack only: energy-weighted mean X, and X at max |X|.
    /// Knocker default: +X = right. Bounce after ~35 ms is never consulted.
    private func classifySide(meanX: Double, peakX: Double) -> TapSide {
        var a = meanX + sideBias
        var p = peakX + sideBias
        if invertSides {
            a = -a
            p = -p
        }

        var right = 0
        var left = 0
        func vote(_ v: Double, floor: Double) {
            guard abs(v) >= floor else { return }
            if v > 0 { right += 1 } else { left += 1 }
        }
        vote(a, floor: 0.0024)
        vote(p, floor: 0.0040)

        if right > left { return .right }
        if left > right { return .left }
        // Tie or both weak: trust the weighted mean (less bounce).
        return a >= 0 ? .right : .left
    }

    private func resetCapture() {
        capturePeakMag = 0
        captureSamples = 0
        baselineX = 0
        weightedX = 0
        weightSum = 0
        attackPeakX = 0
        attackAbsX = 0
        attackSumZ = 0
        captureSimulated = false
    }

    private func emitGesture(now: Double) {
        guard currentTapCount > 0 else { return }

        let gesture = DetectedGesture(
            side: currentSide,
            tapCount: currentTapCount,
            timestamp: now,
            peakMagnitude: groupPeakMag,
            peakX: groupPeakX,
            isSimulated: groupSimulated
        )

        currentTapCount = 0
        groupPeakMag = 0
        groupPeakX = 0
        groupSimulated = false
        // A group can time out while the next knock is being captured.
        // Emitting the previous group must not discard that capture.
        let epoch = deliveryEpoch

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.queue.sync(execute: { self.deliveryEpoch == epoch }) else { return }
            self.lastDetectedGesture = gesture
            self.pendingTapCount = 0
            self.onGesture?(gesture)
        }
    }

    private func publishReject(_ reason: String) {
        DispatchQueue.main.async { [weak self] in
            self?.lastRejectReason = reason
        }
    }

    var onGesture: ((DetectedGesture) -> Void)?

    static var sideHeuristicDescription: String {
        "Left/right uses the first ~30 ms of lateral X after subtracting the pre-tap baseline — the same impulse idea as Knocker, but bounce and gravity leak are ignored. Invert if your chassis is mirrored."
    }
}
