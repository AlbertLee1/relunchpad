import SwiftUI

/// Lays one page of slots out on a fixed columns×rows geometry. Icons are
/// placed with .position so M3 can freely animate them between slots.
struct PageGridView: View {
    let slots: [Slot]
    let grid: GridConfig
    var selectedIndex: Int? = nil

    @ObservedObject private var library = AppLibrary.shared

    var body: some View {
        GeometryReader { geo in
            let cellWidth = geo.size.width / CGFloat(grid.columns)
            let cellHeight = geo.size.height / CGFloat(grid.rows)
            let iconSide = min(cellWidth * 0.55, cellHeight * 0.62)

            ZStack {
                ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                    slotView(slot, iconSide: iconSide, isSelected: index == selectedIndex)
                        .frame(width: cellWidth, height: cellHeight)
                        .position(
                            x: (CGFloat(index % grid.columns) + 0.5) * cellWidth,
                            y: (CGFloat(index / grid.columns) + 0.5) * cellHeight
                        )
                }
            }
        }
    }

    @ViewBuilder
    private func slotView(_ slot: Slot, iconSide: CGFloat, isSelected: Bool) -> some View {
        switch slot {
        case .app(let bundleID):
            if let app = library.app(for: bundleID) {
                AppIconView(app: app, iconSide: iconSide, isSelected: isSelected)
            }
        case .folder:
            // Folders arrive in M3.
            EmptyView()
        }
    }
}
