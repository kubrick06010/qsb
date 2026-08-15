import Foundation

struct FacilityLayoutCell: Comparable, Hashable {
    let row: Int
    let column: Int

    static func < (left: FacilityLayoutCell, right: FacilityLayoutCell) -> Bool {
        if left.row != right.row {
            return left.row < right.row
        }
        return left.column < right.column
    }
}

func layoutCells(in rects: [FacilityLayoutRect]) -> Set<FacilityLayoutCell> {
    var cells: Set<FacilityLayoutCell> = []
    for rect in rects {
        guard rect.startRow <= rect.endRow, rect.startColumn <= rect.endColumn else {
            continue
        }
        for row in rect.startRow...rect.endRow {
            for column in rect.startColumn...rect.endColumn {
                cells.insert(FacilityLayoutCell(row: row, column: column))
            }
        }
    }
    return cells
}
