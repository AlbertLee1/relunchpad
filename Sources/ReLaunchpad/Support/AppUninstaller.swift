import AppKit

@MainActor
enum AppUninstaller {
    /// System apps can't be removed; everything the user can delete shows
    /// the ✕ badge in jiggle mode (broader than the original's
    /// App-Store-only rule, matching what users expect today).
    static func canTrash(_ app: AppItem) -> Bool {
        !app.url.path.hasPrefix("/System")
            && FileManager.default.isDeletableFile(atPath: app.url.path)
    }

    static func trash(_ app: AppItem) {
        NSWorkspace.shared.recycle([app.url]) { _, error in
            Task { @MainActor in
                if let error {
                    NSLog("ReLaunchpad: trash failed for \(app.id): \(error)")
                    NSSound.beep()
                    return
                }
                AppLibrary.shared.removeEverywhere(bundleID: app.id)
            }
        }
    }
}
