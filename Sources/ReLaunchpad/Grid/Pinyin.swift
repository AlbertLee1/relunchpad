import Foundation

/// Latinization of Chinese app names so "weixin" or "wx" finds 微信.
/// Backed by CFStringTransform; results are memoized per name.
enum Pinyin {
    struct Keys {
        /// e.g. "weixin"
        let full: String
        /// e.g. "wx"
        let initials: String
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [String: Keys?] = [:]

    static func keys(for name: String) -> Keys? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[name] { return cached }

        let result: Keys?
        if name.unicodeScalars.contains(where: { $0.properties.isIdeographic }) {
            let mutable = NSMutableString(string: name)
            CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false)
            CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
            let syllables = (mutable as String)
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
            result = syllables.isEmpty ? nil : Keys(
                full: syllables.joined(),
                initials: syllables.compactMap(\.first).map(String.init).joined()
            )
        } else {
            result = nil
        }
        cache[name] = result
        return result
    }
}
