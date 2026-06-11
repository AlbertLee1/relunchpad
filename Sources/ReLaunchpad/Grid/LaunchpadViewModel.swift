import AppKit
import SwiftUI

/// Presentation state for the overlay: current page plus key/scroll routing.
@MainActor
final class LaunchpadViewModel: ObservableObject {
    static let shared = LaunchpadViewModel()

    @Published var currentPage = 0

    var pageCount: Int { AppLibrary.shared.layout.pages.count }

    private var scrollAccumulator: CGFloat = 0
    private var scrollLocked = false
    private var wheelCooldown = false

    func reset() {
        currentPage = 0
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
        switch event.keyCode {
        case 123: goToPage(currentPage - 1); return true // ←
        case 124: goToPage(currentPage + 1); return true // →
        default: return false
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
