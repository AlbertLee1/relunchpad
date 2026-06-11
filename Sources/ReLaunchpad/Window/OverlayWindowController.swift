import AppKit
import SwiftUI

/// Drives presentation state so SwiftUI can animate open/close like the
/// original Launchpad (zoom + fade); the window itself orders in/out instantly.
@MainActor
final class OverlayState: ObservableObject {
    @Published var isPresented = false
}

@MainActor
final class OverlayWindowController: NSObject, NSWindowDelegate {
    static let shared = OverlayWindowController()

    let state = OverlayState()
    private var window: OverlayWindow?
    private var hideWorkItem: DispatchWorkItem?
    private var scrollMonitor: Any?

    static let animationDuration: TimeInterval = 0.18

    var isVisible: Bool { window?.isVisible ?? false }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    func show() {
        NSLog("ReLaunchpad: show()")
        hideWorkItem?.cancel()
        hideWorkItem = nil

        let window = ensureWindow()
        let screen = screenUnderMouse()
        window.setFrame(screen.frame, display: true)

        state.isPresented = false
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        if scrollMonitor == nil {
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                if event.window === self.window {
                    LaunchpadViewModel.shared.handleScroll(event)
                }
                return event
            }
        }

        // Flip on the next runloop tick so SwiftUI animates from the closed state.
        DispatchQueue.main.async { [self] in
            withAnimation(.easeOut(duration: Self.animationDuration)) {
                state.isPresented = true
            }
        }
    }

    func hide() {
        guard let window, window.isVisible, hideWorkItem == nil else { return }
        withAnimation(.easeIn(duration: Self.animationDuration)) {
            state.isPresented = false
        }
        if let scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
            self.scrollMonitor = nil
        }
        let item = DispatchWorkItem { [weak self] in
            self?.window?.orderOut(nil)
            self?.hideWorkItem = nil
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.animationDuration, execute: item)
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        NSLog("ReLaunchpad: windowDidResignKey -> hide")
        hide()
    }

    // MARK: - Private

    private func ensureWindow() -> OverlayWindow {
        if let window { return window }

        let window = OverlayWindow(
            contentRect: screenUnderMouse().frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.delegate = self
        window.onEscape = { [weak self] in self?.hide() }
        window.keyHandler = { LaunchpadViewModel.shared.handleKey($0) }

        let root = LaunchpadRootView(
            state: state,
            onDismiss: { [weak self] in self?.hide() }
        )
        let hosting = NSHostingView(rootView: root)
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting

        self.window = window
        return window
    }

    private func screenUnderMouse() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}
