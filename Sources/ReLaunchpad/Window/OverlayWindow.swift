import AppKit

/// Borderless full-screen window that can become key (the search field needs
/// keyboard focus) and routes Esc to a dismiss handler.
final class OverlayWindow: NSWindow {
    var onEscape: (() -> Void)?
    /// Returns true when the event was consumed (paging, search navigation).
    var keyHandler: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onEscape?()
            return
        }
        if keyHandler?(event) == true { return }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}
