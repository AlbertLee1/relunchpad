import Foundation

struct GridConfig: Equatable, Sendable {
    var columns: Int
    var rows: Int
    var slotsPerPage: Int { columns * rows }

    static let `default` = GridConfig(columns: 7, rows: 5)
}

struct FolderSlot: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var items: [String] // bundle IDs
}

enum Slot: Codable, Equatable, Sendable {
    case app(bundleID: String)
    case folder(FolderSlot)
}

struct Layout: Codable, Equatable, Sendable {
    var pages: [[Slot]]

    /// Every bundle ID referenced anywhere in the layout.
    var referencedIDs: Set<String> {
        var ids = Set<String>()
        for slot in pages.joined() {
            switch slot {
            case .app(let id): ids.insert(id)
            case .folder(let folder): ids.formUnion(folder.items)
            }
        }
        return ids
    }

    /// Brings a stored layout in sync with the installed apps:
    /// - drops apps that are no longer installed (compacting within each page,
    ///   matching original Launchpad behavior),
    /// - dissolves folders that become empty,
    /// - appends newly installed apps to the last page, creating pages as needed.
    static func reconciled(_ layout: Layout, installed: [String], slotsPerPage: Int) -> Layout {
        let installedSet = Set(installed)
        var pages: [[Slot]] = layout.pages.map { page in
            page.compactMap { slot in
                switch slot {
                case .app(let id):
                    return installedSet.contains(id) ? slot : nil
                case .folder(var folder):
                    folder.items.removeAll { !installedSet.contains($0) }
                    return folder.items.isEmpty ? nil : .folder(folder)
                }
            }
        }

        let known = Layout(pages: pages).referencedIDs
        let newIDs = installed.filter { !known.contains($0) }

        for id in newIDs {
            if let last = pages.indices.last, pages[last].count < slotsPerPage {
                pages[last].append(.app(bundleID: id))
            } else {
                pages.append([.app(bundleID: id)])
            }
        }

        while pages.count > 1, pages.last?.isEmpty == true {
            pages.removeLast()
        }
        if pages.isEmpty { pages = [[]] }
        return Layout(pages: pages)
    }

    /// Replaces a folder slot with its member apps, in place.
    func dissolvingFolder(_ id: UUID) -> Layout {
        var pages = self.pages
        for pageIndex in pages.indices {
            for slotIndex in pages[pageIndex].indices {
                guard case .folder(let folder) = pages[pageIndex][slotIndex], folder.id == id else { continue }
                pages[pageIndex].replaceSubrange(
                    slotIndex...slotIndex,
                    with: folder.items.map { Slot.app(bundleID: $0) }
                )
                return Layout(pages: pages)
            }
        }
        return self
    }

    /// Restores the page-size invariant after a drag edit: pages overflowing
    /// `slotsPerPage` cascade their tail into the next page (original
    /// Launchpad behavior), empty trailing pages are trimmed.
    static func normalized(_ pages: [[Slot]], slotsPerPage: Int) -> [[Slot]] {
        var result: [[Slot]] = []
        var carry: [Slot] = []
        for page in pages {
            var merged = carry + page
            carry = []
            if merged.count > slotsPerPage {
                carry = Array(merged[slotsPerPage...])
                merged = Array(merged[..<slotsPerPage])
            }
            result.append(merged)
        }
        while !carry.isEmpty {
            let chunk = Array(carry.prefix(slotsPerPage))
            carry.removeFirst(chunk.count)
            result.append(chunk)
        }
        while result.count > 1, result.last?.isEmpty == true {
            result.removeLast()
        }
        return result.isEmpty ? [[]] : result
    }
}
