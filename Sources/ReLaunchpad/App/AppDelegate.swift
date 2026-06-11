import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement only takes effect when running from a bundle; force the
        // accessory policy so `swift run` behaves the same during development.
        NSApp.setActivationPolicy(.accessory)
        AppLibrary.shared.start()

        // Debug helpers for automated verification:
        //   --show          opens the overlay shortly after launch
        //   --search <text> additionally types into the search field
        let args = CommandLine.arguments
        if args.contains("--show") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                OverlayWindowController.shared.show()
                if let flag = args.firstIndex(of: "--search"), args.indices.contains(flag + 1) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        LaunchpadViewModel.shared.searchText = args[flag + 1]
                    }
                }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        OverlayWindowController.shared.toggle()
        return false
    }
}
