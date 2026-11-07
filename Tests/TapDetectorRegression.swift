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
                       resetBeforeDelivery: Bool = false) -> [DetectedGesture] {
        let sensor = SensorManager()
        let detector = TapDetector(sensor: sensor)
        detector.sensitivity = sensitivity
        detector.classifySides = true
        detector.ignoreWhileTyping = false
        detector.groupingWindow = 0.40
        var events: [DetectedGesture] = []
        detector.onGesture = { events.append($0) }
        for i in 0...1120 {
            let t = Double(i) / 800
            let p = pulses.first { t >= $0.0 && t < $0.0 + 0.008 }
            let x = p?.1 ?? 0
            let z = p == nil ? 0.0 : 0.15
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
                      _ expected: [(TapSide, Int)], sensitivity: Double = 0) {
        let events = replay(pulses, sensitivity: sensitivity)
        let valid = events.count == expected.count && zip(events, expected).allSatisfy {
            $0.side == $1.0 && $0.tapCount == $1.1
        }
        precondition(valid, "FAIL \(name): \(events.map { "\($0.side)x\($0.tapCount)" })")
        print("PASS \(name)")
    }

    static func main() {
        check("isolated knock", [(0.2,-0.06)], [(.left,1)])
        for sensitivity in [0.0, 0.7, 1.0] {
            check("same-side ringing, sensitivity \(sensitivity)",
                  [(0.2,-0.06),(0.32,-0.05),(0.44,-0.04)], [(.left,1)], sensitivity: sensitivity)
            check("alternating ringing, sensitivity \(sensitivity)",
                  [(0.2,-0.06),(0.32,0.05),(0.44,-0.04)], [(.left,1)], sensitivity: sensitivity)
        }
        check("deliberate double", [(0.2,-0.06),(0.39,-0.06)], [(.left,2)])
        check("deliberate triple", [(0.2,-0.06),(0.39,-0.06),(0.58,-0.06)], [(.left,3)])
        check("side change counts each knock once", [(0.2,-0.06),(0.4,0.06)], [(.left,1),(.right,1)])
        check("timeout preserves in-flight capture", [(0.2,-0.06),(0.62,-0.06)], [(.left,1),(.left,1)])
        check("separate groups", [(0.2,-0.06),(0.8,-0.06)], [(.left,1),(.left,1)])
        precondition(replay([(0.2,-0.06)], resetBeforeDelivery: true).isEmpty,
                     "reset must invalidate queued deliveries")
        print("PASS reset invalidates queued deliveries")
    }
}
