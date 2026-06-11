import Foundation
import Testing
@testable import ReLaunchpad

@Suite struct LayoutReconcileTests {
    let slotsPerPage = 4

    @Test func freshInstallFillsPagesInOrder() {
        let layout = Layout.reconciled(
            Layout(pages: [[]]),
            installed: ["a", "b", "c", "d", "e"],
            slotsPerPage: slotsPerPage
        )
        #expect(layout.pages.count == 2)
        #expect(layout.pages[0] == [.app(bundleID: "a"), .app(bundleID: "b"), .app(bundleID: "c"), .app(bundleID: "d")])
        #expect(layout.pages[1] == [.app(bundleID: "e")])
    }

    @Test func uninstalledAppsCompactWithinPage() {
        let layout = Layout(pages: [[.app(bundleID: "a"), .app(bundleID: "b"), .app(bundleID: "c")]])
        let result = Layout.reconciled(layout, installed: ["a", "c"], slotsPerPage: slotsPerPage)
        #expect(result.pages == [[.app(bundleID: "a"), .app(bundleID: "c")]])
    }

    @Test func newAppsAppendToLastPage() {
        let layout = Layout(pages: [[.app(bundleID: "a")]])
        let result = Layout.reconciled(layout, installed: ["a", "b"], slotsPerPage: slotsPerPage)
        #expect(result.pages == [[.app(bundleID: "a"), .app(bundleID: "b")]])
    }

    @Test func existingOrderIsPreserved() {
        let layout = Layout(pages: [[.app(bundleID: "z"), .app(bundleID: "a")]])
        let result = Layout.reconciled(layout, installed: ["a", "z"], slotsPerPage: slotsPerPage)
        #expect(result.pages == [[.app(bundleID: "z"), .app(bundleID: "a")]])
    }

    @Test func folderItemsFollowInstallState() {
        let folder = FolderSlot(id: .init(), name: "Tools", items: ["a", "b"])
        let layout = Layout(pages: [[.folder(folder)]])

        let kept = Layout.reconciled(layout, installed: ["a"], slotsPerPage: slotsPerPage)
        guard case .folder(let f) = kept.pages[0][0] else {
            Issue.record("folder should survive while non-empty")
            return
        }
        #expect(f.items == ["a"])

        let dissolved = Layout.reconciled(layout, installed: [], slotsPerPage: slotsPerPage)
        #expect(dissolved.pages == [[]])
    }

    @Test func emptyTrailingPagesAreTrimmed() {
        let layout = Layout(pages: [[.app(bundleID: "a")], [.app(bundleID: "b")]])
        let result = Layout.reconciled(layout, installed: ["a"], slotsPerPage: slotsPerPage)
        #expect(result.pages == [[.app(bundleID: "a")]])
    }

    @Test func folderAppsAreNotReAdded() {
        let folder = FolderSlot(id: .init(), name: "Tools", items: ["a"])
        let layout = Layout(pages: [[.folder(folder)]])
        let result = Layout.reconciled(layout, installed: ["a"], slotsPerPage: slotsPerPage)
        #expect(result.pages.count == 1)
        #expect(result.pages[0].count == 1)
    }
}

@Suite struct SearchRankerTests {
    let apps = [
        AppItem(id: "1", name: "Safari", url: URL(fileURLWithPath: "/a")),
        AppItem(id: "2", name: "App Store", url: URL(fileURLWithPath: "/b")),
        AppItem(id: "3", name: "Final Cut Pro", url: URL(fileURLWithPath: "/c")),
        AppItem(id: "4", name: "Visual Studio Code", url: URL(fileURLWithPath: "/d")),
    ]

    @Test func prefixBeatsWordPrefixBeatsSubstring() {
        let results = SearchRanker.filter(apps, query: "s")
        #expect(results.map(\.name) == ["Safari", "App Store", "Visual Studio Code"])
    }

    @Test func caseInsensitive() {
        #expect(SearchRanker.filter(apps, query: "SAFARI").map(\.name) == ["Safari"])
    }

    @Test func emptyQueryReturnsNothing() {
        #expect(SearchRanker.filter(apps, query: "  ").isEmpty)
    }

    @Test func chunkingSplitsIntoPages() {
        let slots: [Slot] = (0..<5).map { .app(bundleID: "\($0)") }
        let pages = SearchRanker.chunked(slots, size: 2)
        #expect(pages.count == 3)
        #expect(pages[2] == [.app(bundleID: "4")])
    }
}
