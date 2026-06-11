import Foundation

enum HotCorner: String, CaseIterable, Identifiable {
    case off, topLeft, topRight, bottomLeft, bottomRight
    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: "关闭"
        case .topLeft: "左上角"
        case .topRight: "右上角"
        case .bottomLeft: "左下角"
        case .bottomRight: "右下角"
        }
    }
}

/// UserDefaults-backed preferences shared by triggers, grid, and settings UI.
enum Preferences {
    private static var defaults: UserDefaults { .standard }

    static var hotCorner: HotCorner {
        get { HotCorner(rawValue: defaults.string(forKey: "hotCorner") ?? "") ?? .off }
        set { defaults.set(newValue.rawValue, forKey: "hotCorner") }
    }

    static var pinchEnabled: Bool {
        get { defaults.object(forKey: "pinchEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "pinchEnabled") }
    }

    /// 4 or 5 — five by default so the system's four-finger Apps gesture stays distinct.
    static var pinchFingers: Int {
        get { max(4, min(5, defaults.object(forKey: "pinchFingers") as? Int ?? 5)) }
        set { defaults.set(max(4, min(5, newValue)), forKey: "pinchFingers") }
    }

    /// Capture the hardware Launchpad key (F4). Needs Accessibility.
    static var captureLaunchpadKey: Bool {
        get { defaults.object(forKey: "captureLaunchpadKey") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "captureLaunchpadKey") }
    }

    static var showDockIcon: Bool {
        get { defaults.object(forKey: "showDockIcon") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showDockIcon") }
    }

    static var hasSeenWelcome: Bool {
        get { defaults.bool(forKey: "hasSeenWelcome") }
        set { defaults.set(newValue, forKey: "hasSeenWelcome") }
    }

    static var gridColumns: Int {
        get { max(4, min(12, defaults.object(forKey: "gridColumns") as? Int ?? 7)) }
        set { defaults.set(max(4, min(12, newValue)), forKey: "gridColumns") }
    }

    static var gridRows: Int {
        get { max(3, min(10, defaults.object(forKey: "gridRows") as? Int ?? 5)) }
        set { defaults.set(max(3, min(10, newValue)), forKey: "gridRows") }
    }
}
