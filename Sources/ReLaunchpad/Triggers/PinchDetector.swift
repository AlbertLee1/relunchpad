import Foundation

enum PinchEvent {
    case pinch  // fingers contracted → open Launchpad
    case spread // fingers expanded → close Launchpad
}

/// Pure pinch/spread recognition over raw multitouch frames. Feed every frame;
/// it fires when the mean finger-to-centroid distance contracts (or expands)
/// past the threshold within the time window. UI-free and unit-testable.
struct PinchDetector {
    var requiredFingers: Int = 5
    var threshold: Double = 0.35
    var window: TimeInterval = 0.30
    var cooldown: TimeInterval = 0.8

    private var samples: [(time: TimeInterval, spread: Double)] = []
    private var lastTrigger: TimeInterval = -.infinity

    init(requiredFingers: Int = 5) {
        self.requiredFingers = requiredFingers
    }

    mutating func process(points: [(x: Double, y: Double)], at time: TimeInterval) -> PinchEvent? {
        guard points.count >= requiredFingers else {
            samples.removeAll(keepingCapacity: true)
            return nil
        }

        let cx = points.reduce(0) { $0 + $1.x } / Double(points.count)
        let cy = points.reduce(0) { $0 + $1.y } / Double(points.count)
        let spread = points.reduce(0) { $0 + ((($1.x - cx) * ($1.x - cx) + ($1.y - cy) * ($1.y - cy)).squareRoot()) }
            / Double(points.count)

        samples.append((time, spread))
        samples.removeAll { time - $0.time > window }

        guard time - lastTrigger > cooldown,
              let earliest = samples.first, earliest.spread > 0.01 else { return nil }

        let ratio = spread / earliest.spread
        if ratio < 1 - threshold {
            lastTrigger = time
            samples.removeAll(keepingCapacity: true)
            return .pinch
        }
        if ratio > 1 + threshold {
            lastTrigger = time
            samples.removeAll(keepingCapacity: true)
            return .spread
        }
        return nil
    }
}
