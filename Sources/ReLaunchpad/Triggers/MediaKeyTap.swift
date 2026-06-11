import AppKit

/// Captures the hardware Launchpad key (F4, NX_KEYTYPE_LAUNCHPAD) via a
/// CGEventTap and consumes it so the system's Apps view doesn't also open.
/// Requires Accessibility permission; degrades to off without it.
@MainActor
final class MediaKeyTap: ObservableObject {
    @Published private(set) var isActive = false

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private nonisolated static let launchpadKeyCode = 131 // NX_KEYTYPE_LAUNCHPAD

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        guard PermissionChecker.accessibilityGranted else {
            isActive = false
            return false
        }

        let mask = CGEventMask(1 << 14) // NSEvent.EventType.systemDefined
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, cgEvent, _ in
                MediaKeyTap.handle(type: type, event: cgEvent)
            },
            userInfo: nil
        ) else {
            isActive = false
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isActive = true
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        isActive = false
    }

    /// Runs on the main run loop (the tap source is scheduled there).
    private nonisolated static func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Re-enable; the system disables slow taps.
            DispatchQueue.main.async { MainActor.assumeIsolated {
                if let tap = TriggerCoordinator.shared.mediaKey.tapForReenable {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            } }
            return Unmanaged.passUnretained(event)
        }

        guard let nsEvent = NSEvent(cgEvent: event), nsEvent.subtype.rawValue == 8 else {
            return Unmanaged.passUnretained(event)
        }
        let data1 = nsEvent.data1
        let keyCode = (data1 & 0xFFFF_0000) >> 16
        let isKeyDown = (data1 & 0xFF00) >> 8 == 0xA
        guard keyCode == launchpadKeyCode else {
            return Unmanaged.passUnretained(event)
        }
        if isKeyDown {
            DispatchQueue.main.async { MainActor.assumeIsolated {
                TriggerCoordinator.shared.toggle(source: "f4")
            } }
        }
        return nil // consume both down and up so the system Apps view stays shut
    }

    fileprivate var tapForReenable: CFMachPort? { tap }
}
