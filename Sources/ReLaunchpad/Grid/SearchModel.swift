import Foundation

enum SearchRanker {
    /// Case/diacritic-insensitive match, ranked: name prefix, then any word
    /// prefix, then substring, then pinyin (full, initials, substring) for
    /// Chinese names. Ties resolve alphabetically.
    static func filter(_ apps: [AppItem], query: String) -> [AppItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let lowered = trimmed.lowercased()
        let isLatinQuery = lowered.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }

        func rank(_ name: String) -> Int? {
            let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
            if let range = name.range(of: trimmed, options: options) {
                if range.lowerBound == name.startIndex { return 0 }
                if name[name.index(before: range.lowerBound)] == " " { return 1 }
                return 2
            }
            guard isLatinQuery, let pinyin = Pinyin.keys(for: name) else { return nil }
            if pinyin.full.hasPrefix(lowered) { return 3 }
            if pinyin.initials.hasPrefix(lowered) { return 4 }
            if pinyin.full.contains(lowered) { return 5 }
            return nil
        }

        return apps
            .compactMap { app in rank(app.name).map { (app, $0) } }
            .sorted {
                if $0.1 != $1.1 { return $0.1 < $1.1 }
                return $0.0.name.localizedStandardCompare($1.0.name) == .orderedAscending
            }
            .map(\.0)
    }

    static func chunked(_ slots: [Slot], size: Int) -> [[Slot]] {
        guard size > 0, !slots.isEmpty else { return [[]] }
        return stride(from: 0, to: slots.count, by: size).map {
            Array(slots[$0..<min($0 + size, slots.count)])
        }
    }
}
