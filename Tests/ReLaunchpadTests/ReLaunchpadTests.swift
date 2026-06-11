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

@Suite struct GridMathTests {
    let grid = GridConfig(columns: 4, rows: 2)
    let frame = CGRect(x: 100, y: 100, width: 400, height: 200)

    @Test func centerOfSlotZero() {
        let c = GridMath.slotCenter(index: 0, in: frame, grid: grid)
        #expect(c == CGPoint(x: 150, y: 150))
    }

    @Test func pointOnIconCenterIsFolderTarget() {
        let target = GridMath.dropTarget(at: CGPoint(x: 150, y: 150), in: frame, grid: grid, count: 8)
        #expect(target == .onIcon(0))
    }

    @Test func pointBetweenCellsInserts() {
        // Right edge of cell 0 → insert at 1.
        let target = GridMath.dropTarget(at: CGPoint(x: 195, y: 150), in: frame, grid: grid, count: 8)
        #expect(target == .insert(1))
    }

    @Test func leftHalfInsertsBefore() {
        let target = GridMath.dropTarget(at: CGPoint(x: 210, y: 150), in: frame, grid: grid, count: 8)
        #expect(target == .insert(1))
    }

    @Test func emptyCellInsertsAtCount() {
        // Cell 5 unoccupied when count == 3 → clamp to insert(3).
        let target = GridMath.dropTarget(at: CGPoint(x: 250, y: 250), in: frame, grid: grid, count: 3)
        #expect(target == .insert(3))
    }

    @Test func outsideFrameIsNil() {
        #expect(GridMath.dropTarget(at: CGPoint(x: 50, y: 50), in: frame, grid: grid, count: 8) == nil)
    }
}

@Suite struct LayoutNormalizeTests {
    @Test func overflowCascadesToNextPage() {
        let pages: [[Slot]] = [
            [.app(bundleID: "a"), .app(bundleID: "b"), .app(bundleID: "c")],
            [.app(bundleID: "d")],
        ]
        let result = Layout.normalized(pages, slotsPerPage: 2)
        #expect(result == [
            [.app(bundleID: "a"), .app(bundleID: "b")],
            [.app(bundleID: "c"), .app(bundleID: "d")],
        ])
    }

    @Test func deepOverflowCreatesPages() {
        let pages: [[Slot]] = [(0..<5).map { .app(bundleID: "\($0)") }]
        let result = Layout.normalized(pages, slotsPerPage: 2)
        #expect(result.count == 3)
        #expect(result[2] == [.app(bundleID: "4")])
    }

    @Test func trailingEmptyPagesTrimmed() {
        let result = Layout.normalized([[.app(bundleID: "a")], [], []], slotsPerPage: 4)
        #expect(result == [[.app(bundleID: "a")]])
    }
}

@Suite struct PinchDetectorTests {
    /// Five fingers arranged on a circle of the given radius.
    func ring(_ radius: Double) -> [(x: Double, y: Double)] {
        (0..<5).map { i in
            let a = Double(i) / 5 * 2 * .pi
            return (x: 0.5 + radius * cos(a), y: 0.5 + radius * sin(a))
        }
    }

    @Test func contractionFiresPinch() {
        var detector = PinchDetector(requiredFingers: 5)
        #expect(detector.process(points: ring(0.30), at: 0.00) == nil)
        #expect(detector.process(points: ring(0.25), at: 0.08) == nil)
        #expect(detector.process(points: ring(0.15), at: 0.16) == .pinch)
    }

    @Test func expansionFiresSpread() {
        var detector = PinchDetector(requiredFingers: 5)
        #expect(detector.process(points: ring(0.15), at: 0.00) == nil)
        #expect(detector.process(points: ring(0.25), at: 0.12) == .spread)
    }

    @Test func slowContractionOutsideWindowDoesNotFire() {
        var detector = PinchDetector(requiredFingers: 5)
        #expect(detector.process(points: ring(0.30), at: 0.0) == nil)
        #expect(detector.process(points: ring(0.27), at: 0.4) == nil)
        #expect(detector.process(points: ring(0.24), at: 0.8) == nil)
        #expect(detector.process(points: ring(0.21), at: 1.2) == nil)
    }

    @Test func fourFingersDoNotTriggerFiveFingerDetector() {
        var detector = PinchDetector(requiredFingers: 5)
        let four = Array(ring(0.3).prefix(4))
        #expect(detector.process(points: four, at: 0.0) == nil)
        #expect(detector.process(points: Array(ring(0.1).prefix(4)), at: 0.1) == nil)
    }

    @Test func cooldownSuppressesImmediateRetrigger() {
        var detector = PinchDetector(requiredFingers: 5)
        _ = detector.process(points: ring(0.30), at: 0.0)
        #expect(detector.process(points: ring(0.15), at: 0.1) == .pinch)
        _ = detector.process(points: ring(0.30), at: 0.2)
        #expect(detector.process(points: ring(0.15), at: 0.3) == nil) // within cooldown
        _ = detector.process(points: ring(0.30), at: 1.2)
        #expect(detector.process(points: ring(0.15), at: 1.3) == .pinch) // re-armed
    }
}

@Suite struct PinyinSearchTests {
    let apps = [
        AppItem(id: "1", name: "微信", url: URL(fileURLWithPath: "/a")),
        AppItem(id: "2", name: "网易云音乐", url: URL(fileURLWithPath: "/b")),
        AppItem(id: "3", name: "Safari", url: URL(fileURLWithPath: "/c")),
        AppItem(id: "4", name: "微博", url: URL(fileURLWithPath: "/d")),
    ]

    @Test func fullPinyinMatches() {
        #expect(SearchRanker.filter(apps, query: "weixin").map(\.name) == ["微信"])
    }

    @Test func pinyinInitialsMatch() {
        let names = SearchRanker.filter(apps, query: "wx").map(\.name)
        #expect(names.contains("微信"))
    }

    @Test func pinyinPrefixMatchesMultiple() {
        let names = SearchRanker.filter(apps, query: "wei").map(\.name)
        #expect(Set(names) == ["微信", "微博"])
    }

    @Test func chineseQueryStillMatchesDirectly() {
        #expect(SearchRanker.filter(apps, query: "网易").map(\.name) == ["网易云音乐"])
    }

    @Test func latinNamesUnaffected() {
        #expect(SearchRanker.filter(apps, query: "saf").map(\.name) == ["Safari"])
    }
}

@Suite struct DissolveFolderTests {
    @Test func folderSpillsInPlace() {
        let id = UUID()
        let layout = Layout(pages: [[
            .app(bundleID: "a"),
            .folder(FolderSlot(id: id, name: "F", items: ["x", "y"])),
            .app(bundleID: "b"),
        ]])
        let result = layout.dissolvingFolder(id)
        #expect(result.pages == [[
            .app(bundleID: "a"),
            .app(bundleID: "x"),
            .app(bundleID: "y"),
            .app(bundleID: "b"),
        ]])
    }

    @Test func unknownFolderIsNoOp() {
        let layout = Layout(pages: [[.app(bundleID: "a")]])
        #expect(layout.dissolvingFolder(UUID()) == layout)
    }
}
