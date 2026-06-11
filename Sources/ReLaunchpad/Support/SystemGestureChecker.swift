import AppKit

/// Detects whether macOS's own pinch gesture (which opens the system Apps
/// view) is still enabled — it would fire together with ReLaunchpad's pinch.
/// Backed by the trackpad preference domains the Trackpad settings pane writes.
@MainActor
enum SystemGestureChecker {
    private static let domains = [
        "com.apple.AppleMultitouchTrackpad",                 // built-in trackpad
        "com.apple.driver.AppleBluetoothMultitouch.trackpad" // external trackpads
    ]
    private static let keys = [
        "TrackpadFourFingerPinchGesture",
        "TrackpadFiveFingerPinchGesture",
    ]

    /// True when any pinch-to-Apps gesture is still active system-wide
    /// (0 = off; 2 = opens Launchpad/Apps view).
    static var systemPinchEnabled: Bool {
        for domain in domains {
            for key in keys {
                if let value = CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? Int,
                   value != 0 {
                    return true
                }
            }
        }
        return false
    }

    /// Turns the system gesture off (both finger counts, both trackpad
    /// domains) and restarts the Dock, which owns gesture handling.
    static func disableSystemPinch() {
        for domain in domains {
            for key in keys {
                CFPreferencesSetAppValue(key as CFString, 0 as CFNumber, domain as CFString)
            }
            CFPreferencesAppSynchronize(domain as CFString)
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["Dock"]
        try? task.run()
    }

    static func openTrackpadSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
