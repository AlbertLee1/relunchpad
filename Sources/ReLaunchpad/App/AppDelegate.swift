import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement only takes effect when running from a bundle; force the
        // accessory policy so `swift run` behaves the same during development.
        NSApp.setActivationPolicy(.accessory)
        AppLibrary.shared.start()

        // Debug helpers for automated verification:
        //   --show          opens the overlay shortly after launch
        //   --search <text> additionally types into the search field
        //   --demo-drag     drives DragController through reorder + folder drop
        let args = CommandLine.arguments
        if args.contains("--show") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                OverlayWindowController.shared.show()
                if let flag = args.firstIndex(of: "--search"), args.indices.contains(flag + 1) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        LaunchpadViewModel.shared.searchText = args[flag + 1]
                    }
                }
                if args.contains("--demo-drag") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { Self.runDragDemo() }
                }
            }
        }
    }

    /// Exercises the drag state machine without synthetic mouse events:
    /// 1. drags slot 0 to the boundary after slot 3 (reorder)
    /// 2. drags the (new) slot 0 onto the icon at slot 2 (folder creation)
    @MainActor
    private static func runDragDemo() {
        let library = AppLibrary.shared
        let drag = DragController.shared
        let grid = library.grid
        let frame = drag.gridFrame
        guard frame.width > 0, let first = library.layout.pages.first, first.count >= 5 else {
            NSLog("ReLaunchpad demo: grid not ready")
            return
        }

        func center(_ index: Int) -> CGPoint {
            GridMath.slotCenter(index: index, in: frame, grid: grid)
        }
        func boundary(after index: Int) -> CGPoint {
            var p = center(index)
            p.x += GridMath.cellSize(in: frame, grid: grid).width * 0.48
            return p
        }

        NSLog("ReLaunchpad demo: before = %@", String(describing: library.layout.pages[0].prefix(5)))

        // Scenario 1: reorder slot 0 → after slot 3.
        drag.begin(item: first[0], origin: .page(pageIndex: 0, slotIndex: 0), location: center(0))
        drag.update(location: center(1))
        drag.update(location: boundary(after: 3))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { MainActor.assumeIsolated {
            drag.update(location: boundary(after: 3))
            drag.end()
            NSLog("ReLaunchpad demo: after reorder = %@", String(describing: library.layout.pages[0].prefix(5)))

            // Scenario 2: drag slot 0 onto slot 2 → folder.
            let slots = library.layout.pages[0]
            drag.begin(item: slots[0], origin: .page(pageIndex: 0, slotIndex: 0), location: center(0))
            drag.update(location: center(2))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { MainActor.assumeIsolated {
                drag.update(location: center(2))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { MainActor.assumeIsolated {
                    drag.end()
                    NSLog("ReLaunchpad demo: after folder drop = %@", String(describing: library.layout.pages[0].prefix(5)))
                } }
            } }
        } }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        OverlayWindowController.shared.toggle()
        return false
    }
}
