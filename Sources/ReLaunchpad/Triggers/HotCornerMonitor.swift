import AppKit

/// Hot-corner trigger. Global mouse-moved monitoring needs no TCC permission
/// (unlike keyboard monitoring). Dwell briefly in the chosen corner of any
/// screen to toggle; the pointer must leave the corner before re-arming.
@MainActor
final class HotCornerMonitor {
    var corner: HotCorner = .off {
        didSet { corner == .off ? stop() : start() }
    }

    private var monitor: Any?
    private var dwellWorkItem: DispatchWorkItem?
    private var armed = true

    private let hitRadius: CGFloat = 14
    private let rearmRadius: CGFloat = 100
    private let dwell: TimeInterval = 0.25

    private func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleMove() }
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        dwellWorkItem?.cancel()
        dwellWorkItem = nil
        armed = true
    }

    private func handleMove() {
        guard corner != .off else { return }
        let mouse = NSEvent.mouseLocation
        guard let distance = distanceToCorner(from: mouse) else { return }

        if distance > rearmRadius {
            armed = true
            dwellWorkItem?.cancel()
            dwellWorkItem = nil
            return
        }

        guard armed, distance <= hitRadius, dwellWorkItem == nil else { return }
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.dwellWorkItem = nil
            guard let d = self.distanceToCorner(from: NSEvent.mouseLocation), d <= self.hitRadius else { return }
            self.armed = false
            TriggerCoordinator.shared.toggle(source: "hotcorner")
        }
        dwellWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + dwell, execute: item)
    }

    private func distanceToCorner(from point: CGPoint) -> CGFloat? {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) else {
            return nil
        }
        let f = screen.frame
        guard corner != .off else { return nil }
        let target: CGPoint = switch corner {
        case .topLeft: CGPoint(x: f.minX, y: f.maxY)
        case .topRight: CGPoint(x: f.maxX, y: f.maxY)
        case .bottomLeft: CGPoint(x: f.minX, y: f.minY)
        case .bottomRight: CGPoint(x: f.maxX, y: f.minY)
        case .off: .zero
        }
        return hypot(point.x - target.x, point.y - target.y)
    }
}
