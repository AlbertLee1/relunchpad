import Foundation

enum PinchEvent {
    case pinch  // fingers contracted → open Launchpad
    case spread // fingers expanded → close Launchpad
}

/// Pure pinch/spread recognition over raw multitouch frames.
///
/// Contracting fingers physically merge/drop trackpad contacts (the thumb
/// especially), so the finger count routinely dips below the required count
/// mid-gesture. Detection therefore anchors on the earliest frame in the
/// window that had the full finger count and tolerates the count falling to
/// three afterwards — only a hand leaving the pad resets the window.
struct PinchDetector {
    var requiredFingers: Int = 5
    var threshold: Double = 0.35
    var window: TimeInterval = 0.40
    var cooldown: TimeInterval = 0.8

    private var samples: [(time: TimeInterval, spread: Double, count: Int)] = []
    private var lastTrigger: TimeInterval = -.infinity

    init(requiredFingers: Int = 5) {
        self.requiredFingers = requiredFingers
    }

    mutating func process(points: [(x: Double, y: Double)], at time: TimeInterval) -> PinchEvent? {
        guard points.count >= 3 else {
            samples.removeAll(keepingCapacity: true)
            return nil
        }

        let cx = points.reduce(0) { $0 + $1.x } / Double(points.count)
        let cy = points.reduce(0) { $0 + $1.y } / Double(points.count)
        let spread = points.reduce(0) { $0 + ((($1.x - cx) * ($1.x - cx) + ($1.y - cy) * ($1.y - cy)).squareRoot()) }
            / Double(points.count)

        samples.append((time, spread, points.count))
        samples.removeAll { time - $0.time > window }

        guard time - lastTrigger > cooldown else { return nil }

        // Pinch: started with all fingers down, contracted since.
        if let anchor = samples.first(where: { $0.count >= requiredFingers }),
           anchor.spread > 0.01,
           spread / anchor.spread < 1 - threshold {
            lastTrigger = time
            samples.removeAll(keepingCapacity: true)
            return .pinch
        }

        // Spread: ends with all fingers down, expanded since.
        if points.count >= requiredFingers,
           let anchor = samples.first,
           anchor.spread > 0.01,
           spread / anchor.spread > 1 + threshold {
            lastTrigger = time
            samples.removeAll(keepingCapacity: true)
            return .spread
        }

        return nil
    }
}
