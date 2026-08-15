import Foundation
func mostNegativeColumn(in row: ArraySlice<Double>, forbiddenColumns: Set<Int> = []) -> Int? {
    var selected: Int?
    var selectedValue = -1e-9
    for (index, value) in row.enumerated() where value < selectedValue {
        guard !forbiddenColumns.contains(index) else {
            continue
        }
        selected = index
        selectedValue = value
    }
    return selected
}

func pivot(_ tableau: inout [[Double]], row: Int, column: Int) {
    let pivotValue = tableau[row][column]
    for index in tableau[row].indices {
        tableau[row][index] /= pivotValue
    }

    for targetRow in tableau.indices where targetRow != row {
        let factor = tableau[targetRow][column]
        guard abs(factor) > 1e-12 else { continue }
        for index in tableau[targetRow].indices {
            tableau[targetRow][index] -= factor * tableau[row][index]
        }
    }
}
