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

@Suite struct PinchTrackerTests {
    /// Fingers arranged symmetrically on a circle: mean spread == radius.
    func ring(_ radius: Double, count: Int = 5) -> [(x: Double, y: Double)] {
        (0..<count).map { i in
            let a = Double(i) / Double(count) * 2 * .pi
            return (x: 0.5 + radius * cos(a), y: 0.5 + radius * sin(a))
        }
    }

    func progress(_ phase: PinchPhase) -> Double? {
        switch phase {
        case .active(_, let p), .ended(_, let p): p
        case .idle: nil
        }
    }

    @Test func progressTracksContraction() {
        var tracker = PinchTracker(requiredFingers: 5)
        #expect(tracker.process(points: ring(0.30), at: 0.00) == .idle) // anchor frame
        let early = tracker.process(points: ring(0.27), at: 0.05)
        guard case .active(.pinch, let p1) = early else { Issue.record("expected active"); return }
        #expect(abs(p1 - 0.125) < 0.02)
        let late = tracker.process(points: ring(0.18), at: 0.10)
        guard case .active(.pinch, let p2) = late else { Issue.record("expected active"); return }
        #expect(p2 > p1)
        #expect(tracker.process(points: ring(0.12), at: 0.15) == .active(direction: .pinch, progress: 1.0))
        #expect(tracker.process(points: [], at: 0.20) == .ended(direction: .pinch, progress: 1.0))
    }

    @Test func retreatReducesProgress() {
        var tracker = PinchTracker(requiredFingers: 5)
        _ = tracker.process(points: ring(0.30), at: 0.00)
        let far = progress(tracker.process(points: ring(0.20), at: 0.05)) ?? 0
        let back = progress(tracker.process(points: ring(0.27), at: 0.10)) ?? 1
        #expect(back < far)
        let ended = tracker.process(points: [], at: 0.15)
        guard case .ended(.pinch, let final) = ended else { Issue.record("expected ended"); return }
        #expect(final < 0.5) // release after retreating → caller cancels
    }

    @Test func contactLossKeepsTracking() {
        var tracker = PinchTracker(requiredFingers: 5)
        #expect(tracker.process(points: ring(0.30), at: 0.00) == .idle)
        guard case .active(.pinch, _) = tracker.process(points: ring(0.22, count: 4), at: 0.05) else {
            Issue.record("tracking should survive a lost contact"); return
        }
        #expect(tracker.process(points: ring(0.12, count: 3), at: 0.10) == .active(direction: .pinch, progress: 1.0))
        #expect(tracker.process(points: [], at: 0.15) == .ended(direction: .pinch, progress: 1.0))
    }

    @Test func fourFingerStartStaysIdle() {
        var tracker = PinchTracker(requiredFingers: 5)
        #expect(tracker.process(points: ring(0.30, count: 4), at: 0.00) == .idle)
        #expect(tracker.process(points: ring(0.12, count: 4), at: 0.10) == .idle)
        #expect(tracker.process(points: [], at: 0.20) == .idle)
    }

    @Test func spreadTracksExpansion() {
        var tracker = PinchTracker(requiredFingers: 5)
        #expect(tracker.process(points: ring(0.15), at: 0.00) == .idle)
        #expect(tracker.process(points: ring(0.25), at: 0.08) == .active(direction: .spread, progress: 1.0))
        #expect(tracker.process(points: [], at: 0.15) == .ended(direction: .spread, progress: 1.0))
    }

    @Test func cooldownAfterGestureEnd() {
        var tracker = PinchTracker(requiredFingers: 5)
        _ = tracker.process(points: ring(0.30), at: 0.00)
        _ = tracker.process(points: ring(0.15), at: 0.10)
        _ = tracker.process(points: [], at: 0.20) // ended
        #expect(tracker.process(points: ring(0.30), at: 0.30) == .idle) // cooling down
        #expect(tracker.process(points: ring(0.15), at: 0.40) == .idle)
        _ = tracker.process(points: [], at: 0.45)
        #expect(tracker.process(points: ring(0.30), at: 0.80) == .idle) // re-anchors
        guard case .active(.pinch, _) = tracker.process(points: ring(0.18), at: 0.90) else {
            Issue.record("expected re-armed tracking"); return
        }
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

