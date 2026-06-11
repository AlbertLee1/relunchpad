import SwiftUI

/// Closed folder: rounded tile with a mini-grid of the first nine app icons.
struct FolderIconView: View {
    let folder: FolderSlot
    let iconSide: CGFloat
    var isHovered = false

    @ObservedObject private var library = AppLibrary.shared

    var body: some View {
        VStack(spacing: 6) {
            miniGrid
                .frame(width: iconSide, height: iconSide)
                .background(
                    RoundedRectangle(cornerRadius: iconSide * 0.22)
                        .fill(.white.opacity(0.25))
                        .background(
                            RoundedRectangle(cornerRadius: iconSide * 0.22)
                                .fill(.ultraThinMaterial)
                        )
                )
                .scaleEffect(isHovered ? 1.12 : 1.0)
            Text(folder.name)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                .lineLimit(1)
        }
    }

    private var miniGrid: some View {
        let inset = iconSide * 0.12
        let cell = (iconSide - inset * 2) / 3
        return ZStack {
            ForEach(Array(folder.items.prefix(9).enumerated()), id: \.offset) { index, id in
                if let app = library.app(for: id) {
                    Image(nsImage: IconCache.shared.icon(forAppAt: app.url))
                        .resizable()
                        .frame(width: cell * 0.82, height: cell * 0.82)
                        .position(
                            x: inset + (CGFloat(index % 3) + 0.5) * cell,
                            y: inset + (CGFloat(index / 3) + 0.5) * cell
                        )
                }
            }
        }
    }
}

/// Expanded folder panel: rename field + slot grid with reorder/drag-out.
struct FolderOpenView: View {
    let folder: FolderSlot

    @ObservedObject private var library = AppLibrary.shared
    @ObservedObject private var drag = DragController.shared
    @ObservedObject private var viewModel = LaunchpadViewModel.shared
    @FocusState private var nameFocused: Bool
    @State private var editedName = ""

    var body: some View {
        VStack(spacing: 18) {
            TextField("文件夹名称", text: $editedName)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .focused($nameFocused)
                .frame(width: 280)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(nameFocused ? 0.14 : 0))
                )
                .onSubmit { commitName() }

            folderGrid
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.white.opacity(0.12))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        )
        .onAppear { editedName = folder.name }
        .onDisappear { commitName() }
    }

    private func commitName() {
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, trimmed != folder.name {
            library.renameFolder(folder.id, to: trimmed)
        }
        nameFocused = false
    }

    private var folderGrid: some View {
        let grid = drag.folderGrid(forCount: folder.items.count)
        let cell: CGFloat = 130
        let width = CGFloat(grid.columns) * cell
        let height = CGFloat(grid.rows) * cell

        return ZStack {
            let draggedIndex = draggedItemIndex
            ForEach(Array(folder.items.enumerated()), id: \.element) { index, bundleID in
                if let app = library.app(for: bundleID) {
                    let isDragged = index == draggedIndex
                    let cellIndex = displayCell(for: index, draggedIndex: draggedIndex)
                    AppIconView(app: app, iconSide: 72, isJiggling: viewModel.isJiggling)
                        .slotDrag(.app(bundleID: bundleID)) {
                            .folder(id: folder.id, itemIndex: indexOf(bundleID) ?? index)
                        }
                        .frame(width: cell, height: cell)
                        .position(position(for: cellIndex, grid: grid, cell: cell))
                        .opacity(isDragged ? 0 : 1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: cellIndex)
                }
            }
        }
        .frame(width: width, height: height)
        .background(
            GeometryReader { geo in
                Color.clear.onChange(of: geo.frame(in: .named("launchpad")), initial: true) { _, frame in
                    drag.folderGridFrame = frame
                }
            }
        )
    }

    private var draggedItemIndex: Int? {
        guard let session = drag.session,
              case .folder(let id, let itemIndex) = session.origin,
              id == folder.id else { return nil }
        return itemIndex
    }

    private func indexOf(_ bundleID: String) -> Int? {
        folder.items.firstIndex(of: bundleID)
    }

    private func displayCell(for index: Int, draggedIndex: Int?) -> Int {
        var ordinal = index
        if let draggedIndex, index > draggedIndex { ordinal -= 1 }
        if let gap = drag.folderInsertion, draggedIndex != nil, ordinal >= gap { ordinal += 1 }
        return ordinal
    }

    private func position(for cellIndex: Int, grid: GridConfig, cell: CGFloat) -> CGPoint {
        CGPoint(
            x: (CGFloat(cellIndex % grid.columns) + 0.5) * cell,
            y: (CGFloat(cellIndex / grid.columns) + 0.5) * cell
        )
    }
}
