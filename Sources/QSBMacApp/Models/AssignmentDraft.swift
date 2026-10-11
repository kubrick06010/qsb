import Foundation
import QSBCore

struct AssignmentRowDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

struct AssignmentColumnDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

enum AssignmentDraftIssue: Equatable, Sendable {
    case emptyTitle
    case emptyRowName(UUID)
    case emptyColumnName(UUID)
    case invalidCost(UUID, UUID)
    case inconsistentDimensions

    var message: String {
        switch self {
        case .emptyTitle: "Model title must not be empty."
        case .emptyRowName: "Worker names must not be empty."
        case .emptyColumnName: "Task names must not be empty."
        case .invalidCost: "Enter a finite numeric assignment cost."
        case .inconsistentDimensions: "The assignment cost matrix dimensions are inconsistent."
        }
    }
}

enum AssignmentDraftError: Error, Equatable, CustomStringConvertible {
    case issues([AssignmentDraftIssue])

    var issues: [AssignmentDraftIssue] {
        if case .issues(let value) = self { return value }
        return []
    }

    var description: String {
        switch self {
        case .issues(let issues): issues.map(\.message).joined(separator: " ")
        }
    }
}

struct AssignmentDraft: Equatable, Sendable {
    var title: String
    var rows: [AssignmentRowDraft]
    var columns: [AssignmentColumnDraft]
    var costs: [[String]]

    init(
        title: String = "New Assignment",
        rows: [AssignmentRowDraft],
        columns: [AssignmentColumnDraft],
        costs: [[String]]
    ) {
        self.title = title
        self.rows = rows
        self.columns = columns
        self.costs = costs
    }

    static func blank() -> Self {
        Self(
            rows: [AssignmentRowDraft(name: "Worker 1"), AssignmentRowDraft(name: "Worker 2"), AssignmentRowDraft(name: "Worker 3")],
            columns: [AssignmentColumnDraft(name: "Task 1"), AssignmentColumnDraft(name: "Task 2"), AssignmentColumnDraft(name: "Task 3")],
            costs: Array(repeating: Array(repeating: "0", count: 3), count: 3)
        )
    }

    init(model: AssignmentProblem) {
        title = model.title
        rows = model.workers.map { AssignmentRowDraft(name: $0) }
        columns = model.tasks.map { AssignmentColumnDraft(name: $0) }
        costs = model.costs.map { $0.map { String($0) } }
    }

    init?(envelope: NetworkModelEnvelope) {
        guard case .assignment(let model) = envelope else { return nil }
        self.init(model: model)
    }

    func draftIssues() -> [AssignmentDraftIssue] {
        var issues: [AssignmentDraftIssue] = []
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append(.emptyTitle) }
        for row in rows where row.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append(.emptyRowName(row.id)) }
        for column in columns where column.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append(.emptyColumnName(column.id)) }
        guard costs.count == rows.count, costs.allSatisfy({ $0.count == columns.count }) else {
            issues.append(.inconsistentDimensions)
            return issues
        }
        for (rowIndex, row) in rows.enumerated() {
            for (columnIndex, column) in columns.enumerated() where parseFinite(costs[rowIndex][columnIndex]) == nil {
                issues.append(.invalidCost(row.id, column.id))
            }
        }
        return issues
    }

    func makeModel() throws -> AssignmentProblem {
        let issues = draftIssues()
        guard issues.isEmpty else { throw AssignmentDraftError.issues(issues) }
        return AssignmentProblem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            workers: rows.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) },
            tasks: columns.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) },
            costs: costs.map { row in row.compactMap(parseFinite) }
        )
    }

    @discardableResult
    mutating func addRow(name: String? = nil) -> UUID {
        let row = AssignmentRowDraft(name: name ?? "Worker \(rows.count + 1)")
        rows.append(row)
        costs.append(Array(repeating: "0", count: columns.count))
        return row.id
    }

    mutating func removeRow(at index: Int) {
        guard rows.indices.contains(index) else { return }
        rows.remove(at: index)
        if costs.indices.contains(index) { costs.remove(at: index) }
    }

    @discardableResult
    mutating func addColumn(name: String? = nil) -> UUID {
        let column = AssignmentColumnDraft(name: name ?? "Task \(columns.count + 1)")
        columns.append(column)
        for index in costs.indices { costs[index].append("0") }
        return column.id
    }

    mutating func removeColumn(at index: Int) {
        guard columns.indices.contains(index) else { return }
        columns.remove(at: index)
        for row in costs.indices where costs[row].indices.contains(index) { costs[row].remove(at: index) }
    }

    func tabularText() -> String {
        let header = ["Worker / Task"] + columns.map(\.name)
        let body = rows.indices.map { index in [rows[index].name] + costs[index] }
        return ([header] + body).map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }

    mutating func replaceTable(withTabularText text: String) throws {
        let table = try SpreadsheetTable(text: text)
        let first = table.rows[0][0].lowercased().filter(\.isLetter)
        let hasHeaders = ["workertask", "worker", "name"].contains(first)

        if hasHeaders {
            guard table.rows[0].count >= 2 else {
                throw SpreadsheetTransferError.inconsistentColumns(expected: 2, actual: table.rows[0].count, row: 1)
            }
            let columnNames = Array(table.rows[0].dropFirst())
            guard !columnNames.contains(where: \.isEmpty) else {
                throw SpreadsheetTransferError.invalidValue("", column: "Task", row: 1)
            }
            let dataRows = Array(table.rows.dropFirst())
            guard !dataRows.isEmpty else { throw SpreadsheetTransferError.emptyClipboard }
            var newRows: [AssignmentRowDraft] = []
            var newCosts: [[String]] = []
            for (index, values) in dataRows.enumerated() {
                let rowNumber = index + 2
                guard !values[0].isEmpty else {
                    throw SpreadsheetTransferError.invalidValue("", column: "Worker", row: rowNumber)
                }
                for (column, value) in values.dropFirst().enumerated() {
                    try SpreadsheetTable.requireFinite(value, column: columnNames[column], row: rowNumber)
                }
                newRows.append(AssignmentRowDraft(name: values[0]))
                newCosts.append(Array(values.dropFirst()))
            }
            rows = newRows
            columns = columnNames.map { AssignmentColumnDraft(name: $0) }
            costs = newCosts
            return
        }

        guard table.rows.count == rows.count else {
            throw SpreadsheetTransferError.inconsistentRows(expected: rows.count, actual: table.rows.count)
        }
        for (rowIndex, values) in table.rows.enumerated() {
            guard values.count == columns.count else {
                throw SpreadsheetTransferError.inconsistentColumns(expected: columns.count, actual: values.count, row: rowIndex + 1)
            }
            for (columnIndex, value) in values.enumerated() {
                try SpreadsheetTable.requireFinite(value, column: columns[columnIndex].name, row: rowIndex + 1)
            }
        }
        costs = table.rows
    }

    private func parseFinite(_ text: String) -> Double? {
        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)), value.isFinite else { return nil }
        return value
    }
}
