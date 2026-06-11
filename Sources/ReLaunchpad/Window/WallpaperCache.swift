import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Pre-blurred desktop wallpaper per screen — the original Launchpad blurs the
/// wallpaper itself, not whatever windows happen to be open underneath.
@MainActor
final class WallpaperCache {
    static let shared = WallpaperCache()

    private var cache: [String: NSImage] = [:]
    private let context = CIContext()

    func blurredWallpaper(for screen: NSScreen) -> NSImage? {
        guard let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return nil }
        let modified = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date)
            .map { "\($0.timeIntervalSince1970)" } ?? ""
        let key = url.path + "|" + modified
        if let cached = cache[key] { return cached }

        guard let source = CIImage(contentsOf: url) else { return nil }
        // Downscale first: blurring a 6K original is wasted work.
        let scale = min(1, 1600 / max(source.extent.width, 1))
        let scaled = source.transformed(by: .init(scaleX: scale, y: scale))
        let blurred = scaled
            .clampedToExtent()
            .applyingGaussianBlur(sigma: 28)
            .cropped(to: scaled.extent)

        guard let cgImage = context.createCGImage(blurred, from: blurred.extent) else { return nil }
        let image = NSImage(cgImage: cgImage, size: blurred.extent.size)
        cache = [key: image] // wallpaper changes are rare; keep just the latest
        return image
    }
}
