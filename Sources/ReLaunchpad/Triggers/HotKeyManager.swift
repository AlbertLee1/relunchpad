import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Carbon-backed global hot key: no TCC permission needed, consumes the event.
    static let toggleLaunchpad = Self("toggleLaunchpad", default: .init(.space, modifiers: [.option]))
}

@MainActor
enum HotKeyManager {
    static func start() {
        KeyboardShortcuts.onKeyUp(for: .toggleLaunchpad) {
            TriggerCoordinator.shared.toggle(source: "hotkey")
        }
    }
}
