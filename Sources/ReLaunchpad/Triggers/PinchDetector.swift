import Foundation

enum PinchDirection: Equatable {
    case pinch  // contracting → opening Launchpad
    case spread // expanding → closing Launchpad
}

enum PinchPhase: Equatable {
    case idle
    /// Fingers are moving; progress runs 0...1 and may retreat mid-gesture.
    case active(direction: PinchDirection, progress: Double)
    /// Fingers lifted; the caller commits or cancels based on final progress.
    case ended(direction: PinchDirection, progress: Double)
}

/// Continuous pinch tracking over raw multitouch frames, driving the
/// original Launchpad's interactive transition (UI fades in with the pinch).
///
/// Contracting fingers merge/drop trackpad contacts, so tracking anchors on
/// the first full-count frame and then tolerates the count falling to three;
/// only the hand leaving the pad ends the gesture.
struct PinchTracker {
    var requiredFingers = 5
    /// Contraction fraction that maps to progress 1.0.
    var pinchRange = 0.40
    /// Expansion fraction that maps to progress 1.0.
    var spreadRange = 0.45
    /// Ignore spread changes smaller than this (touch noise).
    var deadband = 0.05
    var cooldown: TimeInterval = 0.5

    private var anchorSpread: Double?
    private var direction: PinchDirection?
    private var lastProgress: Double = 0
    private var lastEnd: TimeInterval = -.infinity

    init(requiredFingers: Int = 5) {
        self.requiredFingers = requiredFingers
    }

    mutating func process(points: [(x: Double, y: Double)], at time: TimeInterval) -> PinchPhase {
        guard points.count >= 3 else {
            let endedDirection = direction
            let endedProgress = lastProgress
            anchorSpread = nil
            direction = nil
            lastProgress = 0
            if let endedDirection {
                lastEnd = time
                return .ended(direction: endedDirection, progress: endedProgress)
            }
            return .idle
        }

        guard time - lastEnd > cooldown else { return .idle }

        let cx = points.reduce(0) { $0 + $1.x } / Double(points.count)
        let cy = points.reduce(0) { $0 + $1.y } / Double(points.count)
        let spread = points.reduce(0) { $0 + ((($1.x - cx) * ($1.x - cx) + ($1.y - cy) * ($1.y - cy)).squareRoot()) }
            / Double(points.count)

        // The gesture must start with every finger on the pad.
        if anchorSpread == nil {
            if points.count >= requiredFingers { anchorSpread = spread }
            return .idle
        }
        guard let anchor = anchorSpread, anchor > 0.01 else { return .idle }
        let ratio = spread / anchor

        if direction == nil {
            if ratio < 1 - deadband {
                direction = .pinch
            } else if ratio > 1 + deadband, points.count >= requiredFingers {
                direction = .spread
            } else {
                return .idle
            }
        }

        switch direction! {
        case .pinch:
            lastProgress = min(1, max(0, (1 - ratio - deadband) / pinchRange))
        case .spread:
            lastProgress = min(1, max(0, (ratio - 1 - deadband) / spreadRange))
        }
        return .active(direction: direction!, progress: lastProgress)
    }
}
