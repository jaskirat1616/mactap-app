import Foundation
import Combine

extension Notification.Name {
    static let macTapAutoStart = Notification.Name("macTapAutoStart")
}

@main
struct CalibrationRegression {
    static func main() {
        // The unbundled test executable has its own defaults domain.
        let store = ConfigStore.shared
        store.config = .default
        store.config.invertSides = true
        store.config.sideBias = 0.007
        let engine = GestureEngine()
        // Exercise lifecycle without opening a real sensor or firing actions.
        engine.isRunning = true
        let beforeStats = try! JSONEncoder().encode(store.config.stats)
        engine.beginCalibration()
        precondition(engine.isCalibrating)
        precondition(store.config.invertSides && store.config.sideBias == 0.007)
        precondition(!engine.detector.invertSides && engine.detector.sideBias == 0)
        var received = 0
        let subscription = engine.calibrationGestures.sink { _ in received += 1 }
        let gesture = DetectedGesture(side: .left, tapCount: 1, timestamp: 1,
                                      peakMagnitude: 0.2, peakX: -0.04)
        engine.handle(gesture)
        precondition(received == 1 && engine.lastGesture == nil && engine.lastExecutedSlot == nil)
        let afterStats = try! JSONEncoder().encode(store.config.stats)
        // JSON key ordering need not be stable.
        precondition(NSDictionary(dictionary: try! JSONSerialization.jsonObject(with: beforeStats) as! [String: Any]) ==
                     NSDictionary(dictionary: try! JSONSerialization.jsonObject(with: afterStats) as! [String: Any]))
        store.config.sensitivity = 0.2
        precondition(!engine.detector.invertSides && engine.detector.sideBias == 0)
        engine.endCalibration()
        precondition(!engine.isCalibrating && engine.isRunning)
        precondition(engine.detector.invertSides && engine.detector.sideBias == 0.007)
        precondition(store.config.invertSides && store.config.sideBias == 0.007)
        withExtendedLifetime(subscription) {}
        print("PASS calibration routes samples without actions, HUD, or stats")
        print("PASS opening/cancelling preserves saved calibration")
        print("PASS config changes keep calibration coordinates neutral")
        print("PASS ending calibration restores detector and prior running state")
    }
}
