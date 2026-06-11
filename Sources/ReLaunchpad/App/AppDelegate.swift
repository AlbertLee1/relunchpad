import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement only takes effect when running from a bundle; force the
        // accessory policy so `swift run` behaves the same during development.
        NSApp.setActivationPolicy(.accessory)
        AppLibrary.shared.start()

        if CommandLine.arguments.contains("--show") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                OverlayWindowController.shared.show()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        OverlayWindowController.shared.toggle()
        return false
    }
}
