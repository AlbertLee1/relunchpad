import AppKit
import OpenMultitouchSupport

enum PinchStatus: Equatable {
    case off
    case waitingForData // listening but nothing arrived yet
    case active
    case noPermission
}

/// Five-finger pinch via the private MultitouchSupport framework (wrapped by
/// OpenMultitouchSupport). All private-API contact is isolated here so a
/// future macOS breaking the framework degrades to "gesture unavailable"
/// while every other trigger keeps working.
@MainActor
final class PinchGestureMonitor: ObservableObject {
    @Published private(set) var status: PinchStatus = .off {
        didSet { NSLog("ReLaunchpad pinch status: \(status)") }
    }

    private var task: Task<Void, Never>?
    private var sawData = false

    func start(fingers: Int) {
        stop()
        status = .waitingForData
        sawData = false

        guard OMSManager.shared.startListening() else {
            status = .noPermission
            return
        }

        task = Task { [weak self] in
            var tracker = PinchTracker(requiredFingers: fingers)
            for await touches in OMSManager.shared.touchDataStream {
                guard let self else { return }
                if Task.isCancelled { return }

                let points = touches
                    .filter { $0.state == .touching || $0.state == .making || $0.state == .starting }
                    .map { (x: Double($0.position.x), y: Double($0.position.y)) }
                let phase = tracker.process(points: points, at: ProcessInfo.processInfo.systemUptime)

                await MainActor.run {
                    if !self.sawData {
                        self.sawData = true
                        self.status = .active
                    }
                    let controller = OverlayWindowController.shared
                    switch phase {
                    case .active(.pinch, let progress):
                        controller.interactiveOpenUpdate(progress: progress)
                    case .ended(.pinch, let progress):
                        controller.interactiveOpenEnd(commit: progress > 0.5)
                    case .active(.spread, let progress):
                        controller.interactiveCloseUpdate(progress: progress)
                    case .ended(.spread, let progress):
                        controller.interactiveCloseEnd(commit: progress > 0.5)
                    case .idle:
                        break
                    }
                }
            }
        }

        // No frames after a grace period → almost certainly a TCC denial.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.status == .waitingForData, !self.sawData else { return }
            self.status = .noPermission
            PermissionChecker.requestInputMonitoring()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        OMSManager.shared.stopListening()
        status = .off
    }
}
