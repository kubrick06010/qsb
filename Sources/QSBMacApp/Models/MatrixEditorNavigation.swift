import Foundation

struct MatrixEditorNavigation: Equatable {
    static let columnsPerGroup = 12
    var rowID: UUID?
    var columnGroup = 0

    func rowIndex(in rows: [UUID]) -> Int? {
        guard !rows.isEmpty else { return nil }
        return rowID.flatMap { rows.firstIndex(of: $0) } ?? 0
    }
    func groupCount(columnCount: Int) -> Int {
        columnCount > 0 ? (columnCount - 1) / Self.columnsPerGroup + 1 : 0
    }
    func columns(columnCount: Int) -> Range<Int> {
        guard columnCount > 0 else { return 0..<0 }
        let group = min(max(0, columnGroup), groupCount(columnCount: columnCount) - 1)
        let start = group * Self.columnsPerGroup
        return start..<min(start + min(Self.columnsPerGroup, columnCount - start), columnCount)
    }
    mutating func reconcile(previousRows: [UUID], rows: [UUID], columnCount: Int) {
        if rowID == nil || !rows.contains(where: { $0 == rowID }) {
            let previousIndex = rowID.flatMap { previousRows.firstIndex(of: $0) } ?? 0
            rowID = rows.isEmpty ? nil : rows[min(previousIndex, rows.count - 1)]
        }
        columnGroup = min(max(0, columnGroup), max(0, groupCount(columnCount: columnCount) - 1))
    }
}
