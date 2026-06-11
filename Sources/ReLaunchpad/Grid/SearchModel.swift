import Foundation

enum SearchRanker {
    /// Case/diacritic-insensitive match, ranked: name prefix, then any word
    /// prefix, then substring. Ties resolve alphabetically.
    static func filter(_ apps: [AppItem], query: String) -> [AppItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        func rank(_ name: String) -> Int? {
            let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
            guard let range = name.range(of: trimmed, options: options) else { return nil }
            if range.lowerBound == name.startIndex { return 0 }
            if name[name.index(before: range.lowerBound)] == " " { return 1 }
            return 2
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
