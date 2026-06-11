import AppKit
import SwiftUI

enum DragOrigin: Equatable {
    case page(pageIndex: Int, slotIndex: Int)
    case folder(id: UUID, itemIndex: Int)
}

struct DragSession {
    var item: Slot
    var origin: DragOrigin
    var location: CGPoint // in the "launchpad" coordinate space
}

struct Insertion: Equatable {
    var page: Int
    /// Gap position in display-cell terms (0...displayCount).
    var index: Int
}

/// State machine for icon dragging.
///
/// The layout model is NOT mutated while a drag is in flight — the gesture
/// lives on the dragged icon's view, and removing that view from the
/// hierarchy would cancel the gesture. Instead the grid applies a pure
/// display transformation (source hidden from flow, make-way gap at the
/// insertion cell) and the model mutates once, on drop.
@MainActor
final class DragController: ObservableObject {
    static let shared = DragController()

    @Published private(set) var session: DragSession?
    /// Make-way gap on a page, in display-cell terms.
    @Published private(set) var insertion: Insertion?
    /// Display ordinal (per current page, source excluded) of the icon
    /// highlighted as a folder-drop target.
    @Published private(set) var hoverOrdinal: Int?
    /// Make-way gap inside the open folder, in display-cell terms.
    @Published private(set) var folderInsertion: Int?

    /// Frame of the visible page's grid in launchpad space (set by the view).
    var gridFrame: CGRect = .zero
    /// Frame of the open folder's grid in launchpad space.
    var folderGridFrame: CGRect = .zero
    /// Full root bounds, for edge-flip zones.
    var rootBounds: CGRect = .zero

    private var flipWorkItem: DispatchWorkItem?
    private var flipArmed = true
    private var hoverWorkItem: DispatchWorkItem?
    private var pendingHover: Int?

    var isDragging: Bool { session != nil }

    // MARK: - Display transformation (pure, used by the grid views)

    /// The source slot position when dragging from a page.
    var pageSource: (page: Int, slot: Int)? {
        guard let session, case .page(let p, let s) = session.origin else { return nil }
        return (p, s)
    }

    /// Display cell for the k-th non-source item of a page.
    func displayCell(forOrdinal k: Int, onPage page: Int) -> Int {
        guard let insertion, insertion.page == page else { return k }
        return k >= insertion.index ? k + 1 : k
    }

    // MARK: - Session lifecycle

    func begin(item: Slot, origin: DragOrigin, location: CGPoint) {
        guard session == nil, !LaunchpadViewModel.shared.isSearching else { return }
        session = DragSession(item: item, origin: origin, location: location)
        switch origin {
        case .page(let pageIndex, let slotIndex):
            insertion = Insertion(page: pageIndex, index: slotIndex)
        case .folder(_, let itemIndex):
            folderInsertion = itemIndex
        }
    }

    func update(location: CGPoint) {
        guard var session else { return }
        session.location = location
        self.session = session

        if case .folder = session.origin {
            updateFolderDrag(location: location)
        } else {
            updatePageDrag(location: location)
        }
    }

    func end() {
        guard let session else { return }
        defer { cleanup() }

        switch session.origin {
        case .page(let sourcePage, let sourceSlot):
            endPageDrag(session: session, sourcePage: sourcePage, sourceSlot: sourceSlot)
        case .folder(let folderID, let itemIndex):
            endFolderDrag(session: session, folderID: folderID, itemIndex: itemIndex)
        }
    }

    func cancel() {
        cleanup()
    }

    // MARK: - Page drag tracking

    private func updatePageDrag(location: CGPoint) {
        let viewModel = LaunchpadViewModel.shared
        let page = viewModel.currentPage
        let library = AppLibrary.shared

        handleEdgeFlip(location: location, viewModel: viewModel)

        let pages = library.layout.pages
        let modelCount = pages.indices.contains(page) ? pages[page].count : 0
        let sourceOnThisPage = pageSource.map { $0.page == page } ?? false
        let displayCount = modelCount - (sourceOnThisPage ? 1 : 0)
        let gapPresent = insertion?.page == page
        let occupiedCells = displayCount + (gapPresent ? 1 : 0)

        switch GridMath.dropTarget(at: location, in: gridFrame, grid: library.grid, count: occupiedCells) {
        case .onIcon(let cell):
            guard let ordinal = ordinalForCell(cell, onPage: page, displayCount: displayCount),
                  canDropOnIcon(atOrdinal: ordinal, page: page, dragged: session?.item)
            else {
                setHover(nil)
                return
            }
            setHover(ordinal)
        case .insert(let cell):
            setHover(nil)
            var index = cell
            if let gap = insertion, gap.page == page, cell > gap.index { index = cell - 1 }
            let clamped = min(displayCount, max(0, index))
            if insertion != Insertion(page: page, index: clamped) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    insertion = Insertion(page: page, index: clamped)
                }
            }
        case nil:
            setHover(nil)
        }
    }

    /// Maps an occupied display cell back to the item ordinal, skipping the gap.
    private func ordinalForCell(_ cell: Int, onPage page: Int, displayCount: Int) -> Int? {
        var ordinal = cell
        if let gap = insertion, gap.page == page {
            if cell == gap.index { return nil } // the gap itself
            if cell > gap.index { ordinal = cell - 1 }
        }
        return ordinal < displayCount ? ordinal : nil
    }

    private func canDropOnIcon(atOrdinal ordinal: Int, page: Int, dragged: Slot?) -> Bool {
        guard case .app = dragged else { return false } // folders never nest
        guard case .some = slotForOrdinal(ordinal, onPage: page) else { return false }
        return true
    }

    private func slotForOrdinal(_ ordinal: Int, onPage page: Int) -> Slot? {
        let pages = AppLibrary.shared.layout.pages
        guard pages.indices.contains(page) else { return nil }
        var modelIndex = ordinal
        if let source = pageSource, source.page == page, ordinal >= source.slot {
            modelIndex = ordinal + 1
        }
        guard pages[page].indices.contains(modelIndex) else { return nil }
        return pages[page][modelIndex]
    }

    private func setHover(_ ordinal: Int?) {
        guard pendingHover != ordinal else { return }
        pendingHover = ordinal
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        guard let ordinal else {
            hoverOrdinal = nil
            return
        }
        // Brief dwell so flying across icons doesn't flash folder targets.
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.pendingHover == ordinal else { return }
            withAnimation(.easeOut(duration: 0.12)) { self.hoverOrdinal = ordinal }
        }
        hoverWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: item)
    }

    private func handleEdgeFlip(location: CGPoint, viewModel: LaunchpadViewModel) {
        let zone: CGFloat = 60
        let inLeft = location.x < rootBounds.minX + zone
        let inRight = location.x > rootBounds.maxX - zone
        guard inLeft || inRight else {
            flipWorkItem?.cancel()
            flipWorkItem = nil
            flipArmed = true
            return
        }
        guard flipArmed, flipWorkItem == nil else { return }
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.isDragging else { return }
            let target = viewModel.currentPage + (inRight ? 1 : -1)
            if inRight && target >= viewModel.pageCount {
                // Dragging past the last page creates a fresh one on drop.
                if AppLibrary.shared.layout.pages.last?.isEmpty == false {
                    self.insertion = Insertion(page: target, index: 0)
                }
            }
            viewModel.goToPage(target)
            self.flipWorkItem = nil
            self.flipArmed = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { self.flipArmed = true }
        }
        flipWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: item)
    }

    // MARK: - Folder drag tracking

    private func updateFolderDrag(location: CGPoint) {
        guard LaunchpadViewModel.shared.openFolder != nil else { return }
        if !folderGridFrame.insetBy(dx: -50, dy: -70).contains(location) {
            // Outside the panel: releasing here will move the app onto the page.
            withAnimation(.easeOut(duration: 0.15)) { folderInsertion = nil }
            return
        }
        guard case .folder(let folderID, let itemIndex) = session?.origin,
              let folder = AppLibrary.shared.folder(folderID) else { return }
        let displayCount = folder.items.count - 1
        let gapPresent = folderInsertion != nil
        let grid = folderGrid(forCount: folder.items.count)
        let occupied = displayCount + (gapPresent ? 1 : 0)
        _ = itemIndex
        switch GridMath.dropTarget(at: location, in: folderGridFrame, grid: grid, count: occupied) {
        case .insert(let cell), .onIcon(let cell):
            var index = cell
            if let gap = folderInsertion, cell > gap { index = cell - 1 }
            let clamped = min(displayCount, max(0, index))
            if folderInsertion != clamped {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    folderInsertion = clamped
                }
            }
        case nil:
            break
        }
    }

    // MARK: - Drop

    private func endPageDrag(session: DragSession, sourcePage: Int, sourceSlot: Int) {
        let library = AppLibrary.shared
        var pages = library.layout.pages
        guard pages.indices.contains(sourcePage), pages[sourcePage].indices.contains(sourceSlot) else { return }
        let item = pages[sourcePage].remove(at: sourceSlot)
        let page = LaunchpadViewModel.shared.currentPage

        if let hoverOrdinal, pages.indices.contains(page), pages[page].indices.contains(hoverOrdinal),
           case .app(let draggedID) = item {
            switch pages[page][hoverOrdinal] {
            case .app(let targetID):
                pages[page][hoverOrdinal] = .folder(
                    FolderSlot(id: UUID(), name: defaultFolderName, items: [targetID, draggedID])
                )
            case .folder(var folder):
                folder.items.append(draggedID)
                pages[page][hoverOrdinal] = .folder(folder)
            }
        } else if let insertion {
            while pages.count <= insertion.page { pages.append([]) }
            let index = min(insertion.index, pages[insertion.page].count)
            pages[insertion.page].insert(item, at: index)
        } else {
            pages[sourcePage].insert(item, at: min(sourceSlot, pages[sourcePage].count))
        }

        library.updateLayout(Layout(pages: Layout.normalized(pages, slotsPerPage: library.grid.slotsPerPage)))
    }

    private func endFolderDrag(session: DragSession, folderID: UUID, itemIndex: Int) {
        guard case .app(let bundleID) = session.item else { return }
        let library = AppLibrary.shared
        let insidePanel = folderGridFrame.insetBy(dx: -50, dy: -70).contains(session.location)

        if insidePanel {
            if let target = folderInsertion {
                library.moveInFolder(folderID, from: itemIndex, to: target)
            }
            return
        }

        // Released outside the panel: move out of the folder onto the page.
        library.removeFromFolder(folderID, bundleID: bundleID)
        withAnimation(.easeOut(duration: 0.18)) { LaunchpadViewModel.shared.openFolder = nil }

        var pages = library.layout.pages
        let page = min(LaunchpadViewModel.shared.currentPage, pages.count - 1)
        let library2 = library
        let grid = library2.grid
        var index = pages[page].count
        if case .insert(let cell)? = GridMath.dropTarget(
            at: session.location, in: gridFrame, grid: grid, count: pages[page].count
        ) {
            index = min(cell, pages[page].count)
        }
        pages[page].insert(.app(bundleID: bundleID), at: index)
        library.updateLayout(Layout(pages: Layout.normalized(pages, slotsPerPage: grid.slotsPerPage)))
    }

    // MARK: - Helpers

    private var defaultFolderName: String { "未命名文件夹" }

    func folderGrid(forCount count: Int) -> GridConfig {
        let columns = min(5, max(2, Int(ceil(sqrt(Double(max(count, 1)))))))
        let rows = max(1, Int(ceil(Double(count) / Double(columns))))
        return GridConfig(columns: columns, rows: rows)
    }

    private func cleanup() {
        session = nil
        insertion = nil
        hoverOrdinal = nil
        folderInsertion = nil
        pendingHover = nil
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        flipWorkItem?.cancel()
        flipWorkItem = nil
        flipArmed = true
    }
}
