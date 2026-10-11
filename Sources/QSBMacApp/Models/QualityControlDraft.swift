import Foundation
import QSBCore

enum QualityControlDraftError: Error, Equatable, CustomStringConvertible {
    case emptyField(path: String, label: String)
    case invalidNumber(path: String, label: String, value: String)
    case invalidInteger(path: String, label: String, value: String)
    case dimension(path: String)

    var path: String {
        switch self {
        case .emptyField(let path, _), .invalidNumber(let path, _, _), .invalidInteger(let path, _, _), .dimension(let path): path
        }
    }

    var description: String {
        switch self {
        case .emptyField(_, let label): "Enter \(label)."
        case .invalidNumber(_, let label, let value): "Enter a finite number for \(label) (received ‘\(value)’)."
        case .invalidInteger(_, let label, let value): "Enter a whole number for \(label) (received ‘\(value)’)."
        case .dimension: "The table dimensions are inconsistent."
        }
    }
}

struct QualityControlColumnDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    init(id: UUID = UUID(), name: String) { self.id = id; self.name = name }
}

struct QualityControlRowDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var values: [String]
    init(id: UUID = UUID(), values: [String]) { self.id = id; self.values = values }
}

private struct QualityControlVariantDraft: Equatable, Sendable {
    var characteristic: String
    var columns: [QualityControlColumnDraft]
    var rows: [QualityControlRowDraft]
}

struct QualityControlDraft: Equatable, Sendable {
    var kind: QualityControlProblemKind
    var title: String
    var characteristic: String
    var columns: [QualityControlColumnDraft]
    var rows: [QualityControlRowDraft]

    // Switching analysis changes the active table, not the user's unfinished work.
    // Keep text and identities so returning to a variant also preserves invalid input.
    private var variants: [String: QualityControlVariantDraft] = [:]

    private init(
        kind: QualityControlProblemKind,
        title: String,
        characteristic: String,
        columns: [QualityControlColumnDraft],
        rows: [QualityControlRowDraft]
    ) {
        self.kind = kind
        self.title = title
        self.characteristic = characteristic
        self.columns = columns
        self.rows = rows
    }

    static func blank(_ kind: QualityControlProblemKind = .cChart) -> Self {
        let shape = defaultShape(kind)
        return Self(kind: kind, title: "New Quality Control Analysis", characteristic: "Characteristic", columns: shape.columns, rows: shape.rows)
    }

    init(_ model: QualityControlModelEnvelope) {
        switch model {
        case .cChart(let value):
            self.init(kind: .cChart, title: value.title, characteristic: value.characteristic,
                      columns: [QualityControlColumnDraft(name: "Count")], rows: value.counts.map { QualityControlRowDraft(values: [Self.format($0)]) })
        case .pChart(let value):
            self.init(kind: .pChart, title: value.title, characteristic: value.characteristic,
                      columns: [QualityControlColumnDraft(name: "Sample Size"), QualityControlColumnDraft(name: "Proportion")],
                      rows: (0..<max(value.sampleSizes.count, value.proportions.count)).map { index in
                          QualityControlRowDraft(values: [
                              value.sampleSizes.indices.contains(index) ? String(value.sampleSizes[index]) : "",
                              value.proportions.indices.contains(index) ? Self.format(value.proportions[index]) : ""
                          ])
                      })
        case .xbarRChart(let value):
            let count = value.subgroups.map(\.count).max() ?? 2
            self.init(kind: .xbarRChart, title: value.title, characteristic: value.characteristic,
                      columns: (0..<count).map { QualityControlColumnDraft(name: "Measurement \($0 + 1)") },
                      rows: value.subgroups.map { QualityControlRowDraft(values: Self.padded($0, count: count)) })
        case .pareto(let value):
            let count = max(value.categoryNames.count, value.subgroupCounts.map(\.count).max() ?? 0)
            self.init(kind: .pareto, title: value.title, characteristic: "",
                      columns: (0..<count).map { QualityControlColumnDraft(name: value.categoryNames.indices.contains($0) ? value.categoryNames[$0] : "") },
                      rows: value.subgroupCounts.map { QualityControlRowDraft(values: Self.padded($0, count: count)) })
        case .normalProbabilityPlot(let value):
            self.init(kind: .normalProbabilityPlot, title: value.title, characteristic: value.characteristic,
                      columns: [QualityControlColumnDraft(name: "Value")], rows: value.values.map { QualityControlRowDraft(values: [Self.format($0)]) })
        }
    }

    func makeModel() throws -> QualityControlModelEnvelope {
        try required(title, path: "model.title", label: "a model title")
        guard !rows.isEmpty, !columns.isEmpty, rows.allSatisfy({ $0.values.count == columns.count }) else {
            throw QualityControlDraftError.dimension(path: "model")
        }
        switch kind {
        case .cChart:
            try required(characteristic, path: "model.characteristic", label: "a characteristic")
            return .cChart(CChartModel(title: title, characteristic: characteristic, counts: try oneColumnNumbers()))
        case .pChart:
            try required(characteristic, path: "model.characteristic", label: "a characteristic")
            guard columns.count == 2 else { throw QualityControlDraftError.dimension(path: "model") }
            return .pChart(PChartModel(
                title: title, characteristic: characteristic,
                sampleSizes: try rows.enumerated().map { try integer($0.element.values[0], path: "model.sampleSizes.\($0.offset)", label: "sample size") },
                proportions: try rows.enumerated().map { try number($0.element.values[1], path: "model.proportions.\($0.offset)", label: "proportion") }
            ))
        case .xbarRChart:
            try required(characteristic, path: "model.characteristic", label: "a characteristic")
            return .xbarRChart(XbarRChartModel(title: title, characteristic: characteristic, subgroups: try matrixNumbers(path: "model.subgroups", label: "measurement")))
        case .pareto:
            for (index, column) in columns.enumerated() {
                try required(column.name, path: "model.categoryNames.\(index)", label: "a category name")
            }
            return .pareto(ParetoModel(title: title, categoryNames: columns.map(\.name), subgroupCounts: try matrixNumbers(path: "model.subgroupCounts", label: "count")))
        case .normalProbabilityPlot:
            try required(characteristic, path: "model.characteristic", label: "a characteristic")
            return .normalProbabilityPlot(NormalProbabilityPlotModel(title: title, characteristic: characteristic, values: try oneColumnNumbers()))
        }
    }

    func draftDiagnostics() -> [ValidationDiagnostic] {
        do { return QualityControlValidator.diagnostics(for: try makeModel()) }
        catch let error as QualityControlDraftError {
            return [ValidationDiagnostic(severity: .error, code: "qualityControl.draft.\(error.path.replacingOccurrences(of: ".", with: "_"))", message: error.description, path: error.path)]
        } catch {
            return [ValidationDiagnostic(severity: .error, code: "qualityControl.draft.invalid", message: error.localizedDescription)]
        }
    }

    mutating func switchKind(to newKind: QualityControlProblemKind) {
        guard newKind != kind else { return }
        variants[kind.rawValue] = QualityControlVariantDraft(characteristic: characteristic, columns: columns, rows: rows)
        let replacement = variants[newKind.rawValue]
        let shape = Self.defaultShape(newKind)
        kind = newKind
        characteristic = replacement?.characteristic ?? characteristic
        columns = replacement?.columns ?? shape.columns
        rows = replacement?.rows ?? shape.rows
    }

    @discardableResult mutating func addRow() -> UUID {
        let row = QualityControlRowDraft(values: kind == .pChart ? ["100", "0.1"] : Array(repeating: "0", count: columns.count))
        rows.append(row)
        return row.id
    }

    mutating func removeRow(id: UUID) {
        let minimum = kind == .normalProbabilityPlot ? 3 : 1
        guard rows.count > minimum else { return }
        rows.removeAll { $0.id == id }
    }

    mutating func addColumn() {
        guard kind == .xbarRChart || kind == .pareto else { return }
        let name = kind == .pareto ? "Category \(columns.count + 1)" : "Measurement \(columns.count + 1)"
        columns.append(QualityControlColumnDraft(name: name))
        for index in rows.indices { rows[index].values.append("0") }
    }

    mutating func removeColumn(id: UUID) {
        guard let index = columns.firstIndex(where: { $0.id == id }) else { return }
        let minimum = kind == .xbarRChart ? 2 : 1
        guard columns.count > minimum else { return }
        columns.remove(at: index)
        for rowIndex in rows.indices where rows[rowIndex].values.indices.contains(index) { rows[rowIndex].values.remove(at: index) }
    }

    func tabularText() -> String {
        let lead = kind == .pareto || kind == .xbarRChart ? "Subgroup" : "Observation"
        var tableRows: [[String]] = [[lead] + columns.map(\.name)]
        for (index, row) in rows.enumerated() {
            tableRows.append([String(index + 1)] + row.values)
        }
        return tableRows.map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }

    mutating func replaceTable(withTabularText text: String) throws {
        var tableRows = try SpreadsheetTable(text: text).rows
        let hasHeader = ["subgroup", "observation"].contains(tableRows.first?.first?.lowercased() ?? "")
        let pastedColumns: [String]
        if hasHeader {
            pastedColumns = Array(tableRows.removeFirst().dropFirst())
        } else {
            pastedColumns = columns.map(\.name)
        }
        guard !tableRows.isEmpty, !pastedColumns.isEmpty else { throw SpreadsheetTransferError.emptyClipboard }
        switch kind {
        case .cChart, .normalProbabilityPlot:
            guard pastedColumns.count == 1 else { throw QualityControlDraftError.dimension(path: "model") }
        case .pChart:
            guard pastedColumns.count == 2 else { throw QualityControlDraftError.dimension(path: "model") }
        case .pareto:
            for (index, name) in pastedColumns.enumerated() {
                try required(name, path: "model.categoryNames.\(index)", label: "a category name")
            }
        case .xbarRChart: break
        }
        let existingColumns = Dictionary(grouping: columns, by: \.name)
        let incomingColumns = Dictionary(grouping: pastedColumns, by: { $0 })
        let incomingOrdinals = Dictionary(grouping: tableRows, by: { Int($0.first ?? "") })
        let expected = pastedColumns.count + 1
        var replacement: [QualityControlRowDraft] = []
        for (index, row) in tableRows.enumerated() {
            guard row.count == expected else { throw SpreadsheetTransferError.inconsistentColumns(expected: expected, actual: row.count, row: index + 1) }
            let values = Array(row.dropFirst())
            for (column, value) in values.enumerated() {
                if kind == .pChart && column == 0 {
                    guard Int(value) != nil else { throw SpreadsheetTransferError.invalidValue(value, column: pastedColumns[column], row: index + 1) }
                } else {
                    try SpreadsheetTable.requireFinite(value, column: pastedColumns[column], row: index + 1)
                }
            }
            // Exported ordinals identify existing observations even after spreadsheet reorder.
            let ordinal = Int(row[0])
            let id: UUID?
            if let ordinal, ordinal > 0, rows.indices.contains(ordinal - 1), incomingOrdinals[ordinal]?.count == 1 {
                id = rows[ordinal - 1].id
            } else { id = nil }
            replacement.append(QualityControlRowDraft(id: id ?? UUID(), values: values))
        }
        var candidate = self
        candidate.columns = pastedColumns.map { name in
            let id = existingColumns[name]?.count == 1 && incomingColumns[name]?.count == 1
                ? existingColumns[name]?.first?.id : nil
            return QualityControlColumnDraft(id: id ?? UUID(), name: name)
        }
        candidate.rows = replacement
        self = candidate
    }

    private static func defaultShape(_ kind: QualityControlProblemKind) -> (columns: [QualityControlColumnDraft], rows: [QualityControlRowDraft]) {
        let names: [String]
        let rowCount: Int
        switch kind {
        case .cChart: names = ["Count"]; rowCount = 5
        case .pChart: names = ["Sample Size", "Proportion"]; rowCount = 5
        case .xbarRChart: names = ["Measurement 1", "Measurement 2", "Measurement 3"]; rowCount = 4
        case .pareto: names = ["Category 1", "Category 2", "Category 3"]; rowCount = 3
        case .normalProbabilityPlot: names = ["Value"]; rowCount = 5
        }
        let columns = names.map { QualityControlColumnDraft(name: $0) }
        let rows = (0..<rowCount).map { _ in QualityControlRowDraft(values: Array(repeating: kind == .pChart ? "0.1" : "0", count: names.count)) }
        if kind == .pChart {
            return (columns, rows.map { _ in QualityControlRowDraft(values: ["100", "0.1"]) })
        }
        return (columns, rows)
    }

    private func oneColumnNumbers() throws -> [Double] {
        guard columns.count == 1 else { throw QualityControlDraftError.dimension(path: "model") }
        return try rows.enumerated().map { try number($0.element.values[0], path: "model.values.\($0.offset)", label: columns[0].name.lowercased()) }
    }

    private func matrixNumbers(path: String, label: String) throws -> [[Double]] {
        try rows.enumerated().map { row in
            try row.element.values.enumerated().map { column in
                try number(column.element, path: "\(path).\(row.offset).\(column.offset)", label: label)
            }
        }
    }

    private func required(_ value: String, path: String, label: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw QualityControlDraftError.emptyField(path: path, label: label) }
    }
    private func integer(_ value: String, path: String, label: String) throws -> Int {
        guard let result = Int(value) else { throw QualityControlDraftError.invalidInteger(path: path, label: label, value: value) }
        return result
    }
    private func number(_ value: String, path: String, label: String) throws -> Double {
        guard let result = Double(value), result.isFinite else { throw QualityControlDraftError.invalidNumber(path: path, label: label, value: value) }
        return result
    }
    private static func padded(_ values: [Double], count: Int) -> [String] {
        // Missing imported measurements remain empty and invalid until the user repairs them.
        values.map(format) + Array(repeating: "", count: max(0, count - values.count))
    }
    private static func format(_ value: Double) -> String { String(value) }
}
