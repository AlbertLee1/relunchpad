import SwiftUI

/// Lays one page of slots out on a fixed columns×rows geometry. Icons are
/// placed with .position so drags can animate them between slots.
///
/// During a drag the model is untouched; this view applies the display
/// transformation: the drag source keeps its view (gesture owner, invisible),
/// the remaining items flow around the make-way gap reported by DragController.
struct PageGridView: View {
    let pageIndex: Int
    let slots: [Slot]
    let grid: GridConfig
    var selectedIndex: Int? = nil
    var isInteractive = true

    @ObservedObject private var library = AppLibrary.shared
    @ObservedObject private var drag = DragController.shared
    @ObservedObject private var viewModel = LaunchpadViewModel.shared

    var body: some View {
        GeometryReader { geo in
            let cellWidth = geo.size.width / CGFloat(grid.columns)
            let cellHeight = geo.size.height / CGFloat(grid.rows)
            let iconSide = min(cellWidth * 0.55, cellHeight * 0.62)
            let source = drag.pageSource

            ZStack {
                ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                    let isSource = source?.page == pageIndex && source?.slot == index
                    let cell = displayCell(forModelIndex: index, source: source)
                    let hovered = isHovered(modelIndex: index, source: source)

                    slotView(slot, iconSide: iconSide, isSelected: index == selectedIndex, hovered: hovered)
                        .frame(width: cellWidth, height: cellHeight)
                        .position(
                            x: (CGFloat(cell % grid.columns) + 0.5) * cellWidth,
                            y: (CGFloat(cell / grid.columns) + 0.5) * cellHeight
                        )
                        .opacity(isSource ? 0 : 1)
                        .animation(
                            isSource ? nil : .spring(response: 0.3, dampingFraction: 0.8),
                            value: cell
                        )
                }
            }
            .onChange(of: geo.frame(in: .named("launchpad")), initial: true) { _, frame in
                if pageIndex == viewModel.currentPage {
                    drag.gridFrame = frame
                }
            }
            .onChange(of: viewModel.currentPage, initial: true) { _, current in
                if pageIndex == current {
                    drag.gridFrame = geo.frame(in: .named("launchpad"))
                }
            }
        }
    }

    /// Position cell for a model slot, accounting for the drag source removal
    /// and the make-way gap.
    private func displayCell(forModelIndex index: Int, source: (page: Int, slot: Int)?) -> Int {
        guard drag.isDragging else { return index }
        var ordinal = index
        if let source, source.page == pageIndex {
            if index == source.slot { return index } // invisible gesture owner
            if index > source.slot { ordinal -= 1 }
        }
        return drag.displayCell(forOrdinal: ordinal, onPage: pageIndex)
    }

    private func isHovered(modelIndex index: Int, source: (page: Int, slot: Int)?) -> Bool {
        guard pageIndex == viewModel.currentPage, let hover = drag.hoverOrdinal else { return false }
        var ordinal = index
        if let source, source.page == pageIndex {
            if index == source.slot { return false }
            if index > source.slot { ordinal -= 1 }
        }
        return ordinal == hover
    }

    @ViewBuilder
    private func slotView(_ slot: Slot, iconSide: CGFloat, isSelected: Bool, hovered: Bool) -> some View {
        switch slot {
        case .app(let bundleID):
            if let app = library.app(for: bundleID) {
                let icon = AppIconView(
                    app: app,
                    iconSide: iconSide,
                    isSelected: isSelected,
                    isHovered: hovered,
                    isJiggling: viewModel.isJiggling && isInteractive
                )
                if isInteractive {
                    icon.slotDrag(slot) { currentOrigin(of: slot) }
                } else {
                    icon
                }
            }
        case .folder(let folder):
            let view = FolderIconView(folder: folder, iconSide: iconSide, isHovered: hovered)
                .jiggle(viewModel.isJiggling && isInteractive, seed: folder.id.uuidString)
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.18)) {
                        LaunchpadViewModel.shared.openFolder = folder.id
                    }
                }
            if isInteractive {
                view.slotDrag(slot) { currentOrigin(of: slot) }
            } else {
                view
            }
        }
    }

    /// Indices may have shifted since render; resolve at drag-start time.
    private func currentOrigin(of slot: Slot) -> DragOrigin {
        let pages = library.layout.pages
        if pages.indices.contains(pageIndex), let idx = pages[pageIndex].firstIndex(of: slot) {
            return .page(pageIndex: pageIndex, slotIndex: idx)
        }
        for (p, page) in pages.enumerated() {
            if let idx = page.firstIndex(of: slot) {
                return .page(pageIndex: p, slotIndex: idx)
            }
        }
        return .page(pageIndex: pageIndex, slotIndex: 0)
    }
}
