import AppKit

/// Single entry point for every trigger (Dock, hot key, hot corner, pinch)
/// with debouncing so two triggers firing together don't open-then-close.
@MainActor
final class TriggerCoordinator: ObservableObject {
    static let shared = TriggerCoordinator()

    let pinch = PinchGestureMonitor()
    let hotCorner = HotCornerMonitor()
    let mediaKey = MediaKeyTap()

    private var lastAction = Date.distantPast
    private let debounce: TimeInterval = 0.35

    func start() {
        HotKeyManager.start()
        applyPreferences()
    }

    func applyPreferences() {
        hotCorner.corner = Preferences.hotCorner
        if Preferences.pinchEnabled {
            pinch.start(fingers: Preferences.pinchFingers)
        } else {
            pinch.stop()
        }
        if Preferences.captureLaunchpadKey {
            mediaKey.start()
        } else {
            mediaKey.stop()
        }
        NSApp.setActivationPolicy(Preferences.showDockIcon ? .regular : .accessory)
    }

    func toggle(source: String) {
        guard debounced() else { return }
        OverlayWindowController.shared.toggle()
    }

    func requestShow(source: String) {
        guard !OverlayWindowController.shared.isVisible, debounced() else { return }
        OverlayWindowController.shared.show()
    }

    func requestHide(source: String) {
        guard OverlayWindowController.shared.isVisible, debounced() else { return }
        OverlayWindowController.shared.hide()
    }

    private func debounced() -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastAction) > debounce else { return false }
        lastAction = now
        return true
    }
}
