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
        grid = GridConfig(columns: Preferences.gridColumns, rows: Preferences.gridRows)
        if let saved = store.load() { layout = saved }
        scanner.onUpdate = { [weak self] apps in self?.apply(apps) }
        scanner.start()
    }

    /// Re-chunks the layout when the grid dimensions change in settings.
    func applyGridPreferences() {
        let newGrid = GridConfig(columns: Preferences.gridColumns, rows: Preferences.gridRows)
        guard newGrid != grid else { return }
        grid = newGrid
        updateLayout(Layout(pages: Layout.normalized(layout.pages, slotsPerPage: newGrid.slotsPerPage)))
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

    /// Removes a (just-trashed) app from the model and layout immediately,
    /// without waiting for the Spotlight update.
    func removeEverywhere(bundleID: String) {
        appsByID[bundleID] = nil
        let installed = layout.referencedIDs.subtracting([bundleID])
        updateLayout(Layout.reconciled(layout, installed: Array(installed), slotsPerPage: grid.slotsPerPage))
    }

    // MARK: - Folder mutations

    func folder(_ id: UUID) -> FolderSlot? {
        for slot in layout.pages.joined() {
            if case .folder(let folder) = slot, folder.id == id { return folder }
        }
        return nil
    }

    /// Applies `transform` to the folder, dissolving it when it shrinks to a
    /// single item (original Launchpad behavior) and dropping it when empty.
    func mutateFolder(_ id: UUID, transform: (inout FolderSlot) -> Void) {
        var pages = layout.pages
        for pageIndex in pages.indices {
            for slotIndex in pages[pageIndex].indices {
                guard case .folder(var folder) = pages[pageIndex][slotIndex], folder.id == id else { continue }
                transform(&folder)
                if folder.items.isEmpty {
                    pages[pageIndex].remove(at: slotIndex)
                } else if folder.items.count == 1 {
                    pages[pageIndex][slotIndex] = .app(bundleID: folder.items[0])
                    LaunchpadViewModel.shared.openFolder = nil
                } else {
                    pages[pageIndex][slotIndex] = .folder(folder)
                }
                updateLayout(Layout(pages: Layout.normalized(pages, slotsPerPage: grid.slotsPerPage)))
                return
            }
        }
    }

    func renameFolder(_ id: UUID, to name: String) {
        mutateFolder(id) { $0.name = name }
    }

    func removeFromFolder(_ id: UUID, bundleID: String) {
        mutateFolder(id) { $0.items.removeAll { $0 == bundleID } }
    }

    func moveInFolder(_ id: UUID, from: Int, to: Int) {
        mutateFolder(id) { folder in
            guard folder.items.indices.contains(from) else { return }
            let item = folder.items.remove(at: from)
            folder.items.insert(item, at: min(to, folder.items.count))
        }
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
