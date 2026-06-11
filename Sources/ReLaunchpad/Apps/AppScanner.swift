import AppKit

/// Enumerates installed applications via Spotlight (NSMetadataQuery) with a
/// plain directory scan as fallback when Spotlight returns nothing.
/// Spotlight gives us free install/uninstall notifications via
/// NSMetadataQueryDidUpdate.
@MainActor
final class AppScanner: NSObject {
    var onUpdate: (([AppItem]) -> Void)?

    private let query = NSMetadataQuery()
    private var observers: [NSObjectProtocol] = []

    nonisolated static let searchRoots = [
        "/Applications",
        NSHomeDirectory() + "/Applications",
        "/System/Applications",
        "/System/Cryptexes/App/System/Applications", // Safari lives here
    ]

    /// Built-in apps living outside Spotlight-indexed roots.
    nonisolated static let extraRoots = [
        "/System/Library/CoreServices/Applications", // Screen Sharing, Directory Utility…
    ]
    nonisolated static let extraApps = [
        "/System/Library/CoreServices/Finder.app",
    ]

    /// Finder and friends — merged into every scan since NSMetadataQuery
    /// cannot see them.
    nonisolated static func wellKnownApps() -> [AppItem] {
        let fm = FileManager.default
        var paths = extraApps
        for root in extraRoots {
            let children = (try? fm.contentsOfDirectory(atPath: root)) ?? []
            paths += children.filter { $0.hasSuffix(".app") }.map { root + "/" + $0 }
        }
        return paths.compactMap { path in
            guard let bundle = Bundle(path: path), let id = bundle.bundleIdentifier else { return nil }
            return AppItem(
                id: id,
                name: fm.displayName(atPath: path),
                url: URL(fileURLWithPath: path)
            )
        }
    }

    func start() {
        query.predicate = NSPredicate(
            format: "kMDItemContentTypeTree == %@", "com.apple.application-bundle"
        )
        query.searchScopes = Self.searchRoots
        query.operationQueue = .main

        let center = NotificationCenter.default
        for name in [NSNotification.Name.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate] {
            observers.append(center.addObserver(forName: name, object: query, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.collectFromQuery() }
            })
        }
        query.start()

        // Spotlight disabled or empty index → fall back to a directory walk.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.query.resultCount == 0 else { return }
            self.onUpdate?(Self.scanDirectories())
        }
    }

    private func collectFromQuery() {
        query.disableUpdates()
        defer { query.enableUpdates() }

        var items: [AppItem] = []
        for index in 0..<query.resultCount {
            guard let result = query.result(at: index) as? NSMetadataItem,
                  let path = result.value(forAttribute: NSMetadataItemPathKey) as? String,
                  let bundleID = result.value(forAttribute: "kMDItemCFBundleIdentifier") as? String
            else { continue }
            let name = (result.value(forAttribute: "kMDItemDisplayName") as? String)
                .map { $0.hasSuffix(".app") ? String($0.dropLast(4)) : $0 }
                ?? FileManager.default.displayName(atPath: path)
            items.append(AppItem(id: bundleID, name: name, url: URL(fileURLWithPath: path)))
        }
        if !items.isEmpty {
            onUpdate?(Self.deduplicated(items + Self.wellKnownApps()))
        }
    }

    nonisolated static func scanDirectories() -> [AppItem] {
        let fm = FileManager.default
        var items: [AppItem] = []
        var directories = searchRoots
        var seen = Set<String>()
        while let dir = directories.popLast() {
            guard let children = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for child in children {
                let path = dir + "/" + child
                if child.hasSuffix(".app") {
                    guard let bundle = Bundle(path: path), let id = bundle.bundleIdentifier else { continue }
                    items.append(AppItem(
                        id: id,
                        name: fm.displayName(atPath: path),
                        url: URL(fileURLWithPath: path)
                    ))
                } else if !seen.contains(path), (try? fm.attributesOfItem(atPath: path))?[.type] as? FileAttributeType == .typeDirectory {
                    seen.insert(path)
                    directories.append(path) // e.g. /System/Applications/Utilities
                }
            }
        }
        return deduplicated(items + wellKnownApps())
    }

    /// Keeps the first occurrence per bundle ID, preferring earlier search roots.
    nonisolated static func deduplicated(_ items: [AppItem]) -> [AppItem] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }
}
