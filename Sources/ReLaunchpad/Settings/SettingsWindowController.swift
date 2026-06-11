import AppKit
import SwiftUI

/// Self-managed settings window — SwiftUI's Settings scene has no reliable
/// programmatic-open path across macOS versions.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show() {
        let window = ensureWindow()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.center()
    }

    private func ensureWindow() -> NSWindow {
        if let window { return window }
        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "ReLaunchpad 设置"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(hosting.view.fittingSize)
        self.window = window
        return window
    }
}
