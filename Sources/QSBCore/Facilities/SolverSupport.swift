import Foundation

struct FacilityLayoutGeometry {
    let cellCount: Int
    let centroidRow: Double
    let centroidColumn: Double
}

/// Summarizes the union of valid positive rectangles without allocating one item per cell.
/// Callers must validate that the containing grid's area fits in Int first.
func layoutGeometry(in rectangles: [FacilityLayoutRect]) -> FacilityLayoutGeometry {
    // Half-open unsigned edges can represent Int.max + 1, avoiding overflow at
    // the last inclusive cell. Bands merge column intervals to count overlaps once.
    let edges = Set(rectangles.flatMap { [UInt64($0.startRow), UInt64($0.endRow) + 1] }).sorted()
    var count: UInt64 = 0
    var rowMoment = 0.0
    var columnMoment = 0.0
    for (lower, upper) in zip(edges, edges.dropFirst()) {
        let intervals = rectangles.filter { UInt64($0.startRow) <= lower && UInt64($0.endRow) >= lower }
            .map { (start: UInt64($0.startColumn), end: UInt64($0.endColumn) + 1) }
            .sorted { $0.start < $1.start }
        var merged: [(start: UInt64, end: UInt64)] = []
        for interval in intervals {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1].end = max(last.end, interval.end)
            } else {
                merged.append(interval)
            }
        }
        for interval in merged {
            let area = (upper - lower) * (interval.end - interval.start)
            count += area
            // Averaging endpoints in Double avoids overflowing integer sums.
            rowMoment += Double(area) * (Double(lower) / 2 + Double(upper - 1) / 2)
            columnMoment += Double(area) * (Double(interval.start) / 2 + Double(interval.end - 1) / 2)
        }
    }
    return FacilityLayoutGeometry(
        cellCount: Int(count),
        centroidRow: count == 0 ? 0 : rowMoment / Double(count),
        centroidColumn: count == 0 ? 0 : columnMoment / Double(count))
}
