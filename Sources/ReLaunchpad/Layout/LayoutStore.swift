import Foundation

/// Atomic JSON persistence for the icon layout. A few hundred entries at most,
/// so JSON beats SQLite here: readable, diffable, no schema migrations.
final class LayoutStore: Sendable {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ReLaunchpad/layout.json")
    }

    func load() -> Layout? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Layout.self, from: data)
    }

    func save(_ layout: Layout) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(layout).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("ReLaunchpad: failed to save layout: \(error)")
        }
    }
}
