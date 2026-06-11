import Foundation

enum DropTarget: Equatable {
    /// Cursor rests on an occupied slot's center — folder creation / insertion.
    case onIcon(Int)
    /// Cursor is between slots — reorder, inserting at this index (0...count).
    case insert(Int)
}

/// Pure geometry for the slot grid; kept free of UI so it can be unit-tested.
enum GridMath {
    static func cellSize(in frame: CGRect, grid: GridConfig) -> CGSize {
        CGSize(
            width: frame.width / CGFloat(grid.columns),
            height: frame.height / CGFloat(grid.rows)
        )
    }

    static func slotCenter(index: Int, in frame: CGRect, grid: GridConfig) -> CGPoint {
        let cell = cellSize(in: frame, grid: grid)
        return CGPoint(
            x: frame.minX + (CGFloat(index % grid.columns) + 0.5) * cell.width,
            y: frame.minY + (CGFloat(index / grid.columns) + 0.5) * cell.height
        )
    }

    /// Classifies a cursor position against a page holding `count` slots.
    /// Returns nil when the point is outside the grid frame entirely.
    static func dropTarget(
        at point: CGPoint,
        in frame: CGRect,
        grid: GridConfig,
        count: Int
    ) -> DropTarget? {
        guard frame.contains(point), grid.columns > 0, grid.rows > 0 else { return nil }
        let cell = cellSize(in: frame, grid: grid)
        let column = min(grid.columns - 1, max(0, Int((point.x - frame.minX) / cell.width)))
        let row = min(grid.rows - 1, max(0, Int((point.y - frame.minY) / cell.height)))
        let index = row * grid.columns + column

        if index < count {
            let center = slotCenter(index: index, in: frame, grid: grid)
            let radius = min(cell.width, cell.height) * 0.28
            if hypot(point.x - center.x, point.y - center.y) < radius {
                return .onIcon(index)
            }
        }

        // Between slots: left half inserts before this cell, right half after.
        let fractionInCell = (point.x - frame.minX) / cell.width - CGFloat(column)
        let insertIndex = index + (fractionInCell >= 0.5 ? 1 : 0)
        return .insert(min(count, max(0, insertIndex)))
    }
}
