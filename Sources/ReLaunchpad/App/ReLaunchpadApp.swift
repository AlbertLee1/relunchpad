import SwiftUI

@main
struct ReLaunchpadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("ReLaunchpad", systemImage: "square.grid.3x3") {
            Button("打开 Launchpad") {
                OverlayWindowController.shared.toggle()
            }
            Divider()
            Button("退出 ReLaunchpad") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
