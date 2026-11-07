import Foundation
import Combine

// Sensor-free seam: use the production detector and its real Combine queue.
enum TapSide: Sendable { case left, right }
struct SensorSample: Sendable {
    let timestamp: Double
    let x: Double
    let y: Double
    let z: Double
    let magnitude: Double
    let rawMagnitude: Double
    var isSimulated = false
}
final class SensorManager {
    let sampleStream = PassthroughSubject<SensorSample, Never>()
    let typingActivity = PassthroughSubject<Void, Never>()
}

@main
struct DetectorRegression {
    static func replay(_ pulses: [(Double, Double)], sensitivity: Double = 0,
                       resetBeforeDelivery: Bool = false, ringing: Bool = false,
                       splitOnSideChange: Bool = true, verticalAmplitude: Double = 0.15) -> [DetectedGesture] {
        let sensor = SensorManager()
        let detector = TapDetector(sensor: sensor)
        detector.sensitivity = sensitivity
        detector.classifySides = true
        detector.splitOnSideChange = splitOnSideChange
        detector.ignoreWhileTyping = false
        detector.groupingWindow = 0.40
        var events: [DetectedGesture] = []
        detector.onGesture = { events.append($0) }
        for i in 0...1120 {
            let t = Double(i) / 800
            var x = 0.0, z = 0.0
            for p in pulses where t >= p.0 {
                let age = t - p.0
                if age < 0.008 { x += p.1; z += verticalAmplitude }
                if ringing {
                    let wave = exp(-age / 0.35) * sin(2 * .pi * 13 * age)
                    x += p.1 * 0.3 * wave
                    z += 0.10 * wave
                }
            }
            sensor.sampleStream.send(SensorSample(timestamp: t, x: x, y: 0, z: z,
                magnitude: (x*x + z*z).squareRoot(),
                rawMagnitude: (x*x + (1+z)*(1+z)).squareRoot()))
        }
        if resetBeforeDelivery { detector.resetSession() }
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        withExtendedLifetime(detector) {}
        return events
    }

    static func check(_ name: String, _ pulses: [(Double, Double)],
                      _ expected: [(TapSide, Int)], sensitivity: Double = 0, ringing: Bool = false) {
        let events = replay(pulses, sensitivity: sensitivity, ringing: ringing)
        let valid = events.count == expected.count && zip(events, expected).allSatisfy {
            $0.side == $1.0 && $0.tapCount == $1.1
        }
        precondition(valid, "FAIL \(name): \(events.map { "\($0.side)x\($0.tapCount)" })")
        print("PASS \(name)")
    }

    static func main() {
        check("isolated knock", [(0.2,-0.06)], [(.left,1)])
        for sensitivity in [0.0, 0.7, 1.0] {
            check("single knock with long chassis resonance, sensitivity \(sensitivity)",
                  [(0.2,-0.06)], [(.left,1)], sensitivity: sensitivity, ringing: true)
            check("triple over continuing chassis resonance, sensitivity \(sensitivity)",
                  [(0.2,-0.06),(0.45,-0.06),(0.70,-0.06)], [(.left,3)], sensitivity: sensitivity, ringing: true)
        }
        check("deliberate double", [(0.2,-0.06),(0.39,-0.06)], [(.left,2)])
        check("deliberate triple", [(0.2,-0.06),(0.39,-0.06),(0.58,-0.06)], [(.left,3)])
        check("triple with 250ms gaps", [(0.2,-0.06),(0.45,-0.06),(0.70,-0.06)], [(.left,3)])
        check("triple with 300ms gaps", [(0.2,-0.06),(0.50,-0.06),(0.80,-0.06)], [(.left,3)])
        check("triple with 160ms gaps", [(0.2,-0.06),(0.36,-0.06),(0.52,-0.06)], [(.left,3)])
        check("side change counts each knock once", [(0.2,-0.06),(0.4,0.06)], [(.left,1),(.right,1)])
        let merged = replay([(0.2,-0.06),(0.4,0.06),(0.6,-0.06)], splitOnSideChange: false)
        precondition(merged.count == 1 && merged[0].tapCount == 3)
        print("PASS equivalent side actions preserve triple despite side noise")
        let lateral = replay([(0.2,-0.20)], verticalAmplitude: 0)
        precondition(lateral.count == 1 && lateral[0].tapCount == 1)
        print("PASS lateral impulse does not require a gravity-magnitude change")
        check("capture starting inside window stays in group", [(0.2,-0.06),(0.62,-0.06)], [(.left,2)])
        check("capture starting outside window starts new group", [(0.2,-0.06),(0.66,-0.06)], [(.left,1),(.left,1)])
        check("separate groups", [(0.2,-0.06),(0.8,-0.06)], [(.left,1),(.left,1)])
        precondition(replay([(0.2,-0.06)], resetBeforeDelivery: true).isEmpty,
                     "reset must invalidate queued deliveries")
        print("PASS reset invalidates queued deliveries")
    }
}
