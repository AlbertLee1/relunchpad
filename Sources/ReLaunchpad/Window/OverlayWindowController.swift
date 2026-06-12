import AppKit
import SwiftUI

/// Drives presentation so SwiftUI can animate open/close like the original
/// Launchpad. `progress` (0...1) is the single source of truth for the
/// zoom+fade — button-style triggers animate it, while the trackpad pinch
/// scrubs it directly so the UI tracks the fingers.
@MainActor
final class OverlayState: ObservableObject {
    /// 0 = fully hidden, 1 = fully presented; the grid fades/zooms along it.
    @Published var progress: Double = 0
    /// Committed-open semantic state (focus, monitors active).
    @Published var isPresented = false
    /// Pre-blurred wallpaper of the screen the overlay is showing on.
    @Published var wallpaper: NSImage?
    /// Height of the Dock at the bottom of the current screen — content keeps
    /// clear of it since the Dock floats above the overlay.
    @Published var bottomInset: CGFloat = 0
}

@MainActor
final class OverlayWindowController: NSObject, NSWindowDelegate {
    static let shared = OverlayWindowController()

    private enum InteractiveMode { case opening, closing }

    let state = OverlayState()
    private var window: OverlayWindow?
    private var hideWorkItem: DispatchWorkItem?
    private var scrollMonitor: Any?
    private var keyMonitor: Any?
    private var flagsMonitor: Any?
    private var interactive: InteractiveMode?

    static let animationDuration: TimeInterval = 0.18

    var isVisible: Bool { window?.isVisible ?? false }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    func show() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        interactive = nil

        prepareWindowFront()
        LaunchpadViewModel.shared.reset()
        commitOpen()

        // Flip on the next runloop tick so SwiftUI animates from the closed state.
        DispatchQueue.main.async { [self] in
            withAnimation(.easeOut(duration: Self.animationDuration)) {
                state.progress = 1
            }
        }
    }

    func hide() {
        guard let window, window.isVisible, hideWorkItem == nil else { return }
        interactive = nil
        NSApp.presentationOptions = []
        state.isPresented = false
        withAnimation(.easeIn(duration: Self.animationDuration)) {
            state.progress = 0
        }
        removeMonitors()
        let item = DispatchWorkItem { [weak self] in
            self?.window?.orderOut(nil)
            self?.hideWorkItem = nil
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.animationDuration, execute: item)
    }

    // MARK: - Interactive (pinch-driven) presentation

    /// The pinch scrubs the open transition: the window is on screen but not
    /// key, and `progress` follows the fingers (虚→实).
    func interactiveOpenUpdate(progress: Double) {
        switch interactive {
        case .closing:
            return
        case nil:
            guard !state.isPresented, hideWorkItem == nil else { return }
            guard !isVisible else { return }
            interactive = .opening
            prepareWindowFront()
            LaunchpadViewModel.shared.reset()
        case .opening:
            break
        }
        state.progress = progress
    }

    func interactiveOpenEnd(commit: Bool) {
        guard interactive == .opening else { return }
        interactive = nil
        if commit {
            commitOpen()
            withAnimation(.easeOut(duration: 0.15)) {
                state.progress = 1
            }
        } else {
            withAnimation(.easeIn(duration: 0.15)) {
                state.progress = 0
            }
            let item = DispatchWorkItem { [weak self] in
                self?.window?.orderOut(nil)
                self?.hideWorkItem = nil
            }
            hideWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
        }
    }

    /// Spreading the fingers scrubs the close transition from the open state.
    func interactiveCloseUpdate(progress: Double) {
        guard state.isPresented || interactive == .closing else { return }
        interactive = .closing
        state.progress = 1 - progress
    }

    func interactiveCloseEnd(commit: Bool) {
        guard interactive == .closing else { return }
        interactive = nil
        if commit {
            hide()
        } else {
            withAnimation(.easeOut(duration: 0.15)) {
                state.progress = 1
            }
        }
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    // MARK: - Private

    /// Positions the window on the mouse screen and orders it front without
    /// activating the app (interactive opens must not steal focus).
    private func prepareWindowFront() {
        let window = ensureWindow()
        let screen = screenUnderMouse()
        window.setFrame(screen.frame, display: true)
        state.wallpaper = WallpaperCache.shared.blurredWallpaper(for: screen)
        state.bottomInset = max(0, screen.visibleFrame.minY - screen.frame.minY)
        state.progress = 0
        window.orderFrontRegardless()
    }

    /// Takes key/focus and installs event monitors — the overlay is now
    /// semantically open.
    private func commitOpen() {
        guard let window else { return }
        hideWorkItem?.cancel()
        hideWorkItem = nil
        NSApp.presentationOptions = [.autoHideMenuBar]
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        state.isPresented = true
        installMonitors()
    }

    private func installMonitors() {
        if scrollMonitor == nil {
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                if event.window === self.window {
                    LaunchpadViewModel.shared.handleScroll(event)
                }
                return event
            }
        }
        // A local monitor sees keys before the focused search field does,
        // letting arrows/Enter/Esc drive navigation while typing stays in the field.
        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard event.window === self.window else { return event }
                return LaunchpadViewModel.shared.handleKey(event) ? nil : event
            }
        }
        // Holding ⌥ enters jiggle mode, releasing it leaves — like the original.
        if flagsMonitor == nil {
            flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                guard event.window === self.window else { return event }
                LaunchpadViewModel.shared.isJiggling = event.modifierFlags.contains(.option)
                return event
            }
        }
    }

    private func removeMonitors() {
        if let scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
            self.scrollMonitor = nil
        }
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
            self.flagsMonitor = nil
        }
    }

    private func ensureWindow() -> OverlayWindow {
        if let window { return window }

        let window = OverlayWindow(
            contentRect: screenUnderMouse().frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        // Just below the Dock: the original Launchpad keeps the Dock visible
        // and clickable on top of the grid (the menu bar is hidden via
        // presentationOptions while the overlay is up).
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) - 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.delegate = self
        window.onEscape = { [weak self] in self?.hide() }

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
