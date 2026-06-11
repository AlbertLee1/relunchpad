import AppKit

@MainActor
final class IconCache {
    static let shared = IconCache()

    private let cache = NSCache<NSString, NSImage>()

    func icon(forAppAt url: URL) -> NSImage {
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 256, height: 256)
        cache.setObject(icon, forKey: key)
        return icon
    }

    /// Warms the cache in small batches so the first page flip doesn't stutter.
    func prewarm(_ urls: [URL]) {
        var remaining = urls[...]
        func warmNextBatch() {
            let batch = remaining.prefix(10)
            remaining = remaining.dropFirst(10)
            guard !batch.isEmpty else { return }
            for url in batch { _ = icon(forAppAt: url) }
            DispatchQueue.main.async { warmNextBatch() }
        }
        warmNextBatch()
    }
}
