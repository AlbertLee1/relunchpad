import AppKit

/// Central model: installed apps + persisted layout, kept in sync.
@MainActor
final class AppLibrary: ObservableObject {
    static let shared = AppLibrary()

    @Published private(set) var appsByID: [String: AppItem] = [:]
    @Published private(set) var layout = Layout(pages: [[]])
    @Published var grid = GridConfig.default

    private let scanner = AppScanner()
    private let store = LayoutStore()

    func start() {
        if let saved = store.load() { layout = saved }
        scanner.onUpdate = { [weak self] apps in self?.apply(apps) }
        scanner.start()
    }

    func app(for id: String) -> AppItem? { appsByID[id] }

    func launch(_ id: String) {
        guard let app = appsByID[id] else { return }
        NSWorkspace.shared.openApplication(at: app.url, configuration: .init())
        OverlayWindowController.shared.hide()
    }

    func updateLayout(_ newLayout: Layout) {
        layout = newLayout
        store.save(newLayout)
    }

    private func apply(_ apps: [AppItem]) {
        appsByID = Dictionary(apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let sortedIDs = apps
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map(\.id)
        let reconciled = Layout.reconciled(layout, installed: sortedIDs, slotsPerPage: grid.slotsPerPage)
        if reconciled != layout {
            updateLayout(reconciled)
        }
        IconCache.shared.prewarm(apps.map(\.url))
    }
}
