import Foundation

/// Display geometry only: model coordinates and solution values remain unchanged.
struct FacilityLayoutCanvasMetrics {
    let rows: Int
    let columns: Int
    let zoom: Double
    var maximumExtent: Double = 1_200

    var cellSize: Double {
        min(50, maximumExtent / Double(max(1, max(rows, columns)))) * zoom
    }
    var width: Double { Double(max(0, columns)) * cellSize }
    var height: Double { Double(max(0, rows)) * cellSize }
    var rowGridLines: [Int] { Self.gridLines(for: rows) }
    var columnGridLines: [Int] { Self.gridLines(for: columns) }
    var rowStep: Int { Self.gridStep(for: rows) }
    var columnStep: Int { Self.gridStep(for: columns) }

    private static func gridStep(for dimension: Int) -> Int {
        max(1, dimension / 120 + (dimension % 120 > 0 ? 1 : 0))
    }
    private static func gridLines(for dimension: Int) -> [Int] {
        guard dimension > 0 else { return [0] }
        let step = gridStep(for: dimension)
        var lines = [0]
        var position = 0
        // Bound rendering by visible detail, including grids whose final edge is Int.max.
        while true {
            let next = position.addingReportingOverflow(step)
            guard !next.overflow, next.partialValue < dimension else { break }
            position = next.partialValue
            lines.append(position)
        }
        lines.append(dimension)
        return lines
    }
}
