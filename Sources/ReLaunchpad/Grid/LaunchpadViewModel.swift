import AppKit
import SwiftUI

/// Presentation state for the overlay: paging, search, selection, and
/// key/scroll routing.
@MainActor
final class LaunchpadViewModel: ObservableObject {
    static let shared = LaunchpadViewModel()

    @Published var currentPage = 0
    @Published var searchText = "" {
        didSet {
            guard searchText != oldValue else { return }
            selectedIndex = searchText.isEmpty ? nil : 0
            currentPage = 0
        }
    }
    /// Keyboard selection within search results (global index across pages).
    @Published var selectedIndex: Int?
    /// Folder currently expanded over the grid.
    @Published var openFolder: UUID?
    /// Where the open folder's icon sits, as a fraction of the root bounds —
    /// the expand animation grows the panel out of this point.
    @Published var openFolderAnchor: UnitPoint = .center
    /// Jiggle (edit) mode: icons wobble and removable apps show a ✕ badge.
    @Published var isJiggling = false

    var isSearching: Bool { !searchText.isEmpty }

    private var scrollAccumulator: CGFloat = 0
    private var scrollLocked = false
    private var wheelCooldown = false

    /// Pages currently shown by the pager: the persisted layout, or search
    /// results re-chunked into pages while searching.
    var displayPages: [[Slot]] {
        let library = AppLibrary.shared
        guard isSearching else { return library.layout.pages }
        let results = SearchRanker.filter(Array(library.appsByID.values), query: searchText)
        return SearchRanker.chunked(results.map { .app(bundleID: $0.id) }, size: library.grid.slotsPerPage)
    }

    var pageCount: Int { displayPages.count }

    func reset() {
        currentPage = 0
        searchText = ""
        selectedIndex = nil
        openFolder = nil
        isJiggling = false
        scrollAccumulator = 0
        scrollLocked = false
    }

    func goToPage(_ page: Int) {
        let clamped = max(0, min(pageCount - 1, page))
        guard clamped != currentPage else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            currentPage = clamped
        }
    }

    /// Returns true when the event was consumed.
    func handleKey(_ event: NSEvent) -> Bool {
        if event.keyCode == 53 { // Esc: drag > folder > jiggle > search > dismiss
            if DragController.shared.isDragging {
                DragController.shared.cancel()
                return true
            }
            if openFolder != nil {
                withAnimation(.easeOut(duration: 0.18)) { openFolder = nil }
                return true
            }
            if isJiggling {
                isJiggling = false
                return true
            }
            if isSearching {
                searchText = ""
                return true
            }
            OverlayWindowController.shared.hide()
            return true
        }

        if isSearching {
            return handleSearchNavigation(event)
        }

        switch event.keyCode {
        case 123: goToPage(currentPage - 1); return true // ←
        case 124: goToPage(currentPage + 1); return true // →
        default: return false
        }
    }

    private func handleSearchNavigation(_ event: NSEvent) -> Bool {
        let pages = displayPages
        let resultCount = pages.reduce(0) { $0 + $1.count }
        guard resultCount > 0 else { return false }
        let columns = AppLibrary.shared.grid.columns
        let current = selectedIndex ?? 0

        func select(_ index: Int) {
            let clamped = max(0, min(resultCount - 1, index))
            selectedIndex = clamped
            goToPage(clamped / AppLibrary.shared.grid.slotsPerPage)
        }

        switch event.keyCode {
        case 123: select(current - 1); return true        // ←
        case 124: select(current + 1); return true        // →
        case 126: select(current - columns); return true  // ↑
        case 125: select(current + columns); return true  // ↓
        case 36, 76: // Return / keypad Enter
            let flat = pages.flatMap(\.self)
            if case .app(let id) = flat[max(0, min(resultCount - 1, current))] {
                AppLibrary.shared.launch(id)
            }
            return true
        default:
            return false
        }
    }

    func handleScroll(_ event: NSEvent) {
        let deltaX = event.scrollingDeltaX
        let deltaY = event.scrollingDeltaY
        let delta = abs(deltaX) > abs(deltaY) ? deltaX : deltaY

        if event.hasPreciseScrollingDeltas {
            // Trackpad: accumulate within one swipe, flip once, re-arm on end.
            if event.phase == .began { scrollAccumulator = 0; scrollLocked = false }
            if event.phase == .ended || event.momentumPhase == .ended {
                if event.momentumPhase == .ended || event.momentumPhase == [] {
                    scrollAccumulator = 0
                    scrollLocked = false
                }
                return
            }
            guard !scrollLocked else { return }
            scrollAccumulator += delta
            if scrollAccumulator <= -40 {
                scrollLocked = true
                goToPage(currentPage + 1)
            } else if scrollAccumulator >= 40 {
                scrollLocked = true
                goToPage(currentPage - 1)
            }
        } else {
            // Mouse wheel: one notch per page with a short cooldown.
            guard !wheelCooldown, abs(delta) > 0.2 else { return }
            wheelCooldown = true
            goToPage(delta < 0 ? currentPage + 1 : currentPage - 1)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.wheelCooldown = false
            }
        }
    }
}
