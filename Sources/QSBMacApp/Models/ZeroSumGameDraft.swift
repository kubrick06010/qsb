import Foundation
import QSBCore

struct ZeroSumGameDraft: Equatable, Sendable {
    var title: String
    var rowStrategies: [String]
    var columnStrategies: [String]
    var payoffs: [[String]]

    static func blank() -> Self {
        Self(
            title: "New Zero-Sum Game",
            rowStrategies: ["Row 1", "Row 2"],
            columnStrategies: ["Column 1", "Column 2"],
            payoffs: [["1", "-1"], ["-1", "1"]]
        )
    }

    init(title: String, rowStrategies: [String], columnStrategies: [String], payoffs: [[String]]) {
        self.title = title
        self.rowStrategies = rowStrategies
        self.columnStrategies = columnStrategies
        self.payoffs = payoffs
    }

    init?(_ envelope: DecisionAnalysisModelEnvelope) {
        guard case .zeroSumGame(let game) = envelope,
              game.payoffs.count == game.rowStrategies.count,
              game.payoffs.allSatisfy({ $0.count == game.columnStrategies.count }) else { return nil }
        self.init(
            title: game.title,
            rowStrategies: game.rowStrategies,
            columnStrategies: game.columnStrategies,
            payoffs: game.payoffs.map { $0.map { String($0) } }
        )
    }

    func makeModel() throws -> DecisionAnalysisModelEnvelope {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecisionAnalysisDraftError.emptyTitle
        }
        let values = try payoffs.enumerated().map { row, entries in
            try entries.enumerated().map { column, text in
                guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)), value.isFinite else {
                    throw DecisionAnalysisDraftError.invalidNumber(path: "model.payoffs.\(row).\(column)", value: text)
                }
                return value
            }
        }
        return .zeroSumGame(ZeroSumGame(
            title: title, rowStrategies: rowStrategies,
            columnStrategies: columnStrategies, payoffs: values
        ))
    }

    func draftDiagnostics() -> [ValidationDiagnostic] {
        do {
            return DecisionAnalysisValidator.diagnostics(for: try makeModel())
        } catch let error as DecisionAnalysisDraftError {
            return [ValidationDiagnostic(
                severity: .error,
                code: "decisionAnalysis.draft.\(error.path.replacingOccurrences(of: ".", with: "_"))",
                message: error.description,
                path: error.path
            )]
        } catch {
            return [ValidationDiagnostic(severity: .error, code: "decisionAnalysis.draft.invalid", message: error.localizedDescription)]
        }
    }

    mutating func addRowStrategy() {
        rowStrategies.append(Self.uniqueName(prefix: "Row", existing: rowStrategies))
        payoffs.append(Array(repeating: "0", count: columnStrategies.count))
    }

    mutating func removeRowStrategy(at index: Int) {
        guard rowStrategies.count > 1, rowStrategies.indices.contains(index) else { return }
        rowStrategies.remove(at: index)
        payoffs.remove(at: index)
    }

    mutating func addColumnStrategy() {
        columnStrategies.append(Self.uniqueName(prefix: "Column", existing: columnStrategies))
        for row in payoffs.indices { payoffs[row].append("0") }
    }

    mutating func removeColumnStrategy(at index: Int) {
        guard columnStrategies.count > 1, columnStrategies.indices.contains(index) else { return }
        columnStrategies.remove(at: index)
        for row in payoffs.indices { payoffs[row].remove(at: index) }
    }

    func tabularText() -> String {
        let header = ["Player 1 / Player 2"] + columnStrategies
        let rows = rowStrategies.indices.map { [rowStrategies[$0]] + payoffs[$0] }
        return ([header] + rows).map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }

    mutating func replaceTable(withTabularText text: String) throws {
        let table = try SpreadsheetTable(text: text)
        let first = table.rows[0][0].lowercased().filter(\.isLetter)
        let hasHeader = ["playerplayer", "player", "strategy"].contains(first)

        if hasHeader {
            let columns = Array(table.rows[0].dropFirst())
            guard !columns.isEmpty, !columns.contains(where: \.isEmpty) else {
                throw SpreadsheetTransferError.invalidValue("", column: "Player 2 Strategy", row: 1)
            }
            let rows = Array(table.rows.dropFirst())
            guard !rows.isEmpty else { throw SpreadsheetTransferError.emptyClipboard }
            let parsed = try Self.parseRows(rows, columnNames: columns, firstRowNumber: 2)
            rowStrategies = parsed.names
            columnStrategies = columns
            payoffs = parsed.values
            return
        }

        guard table.rows.count == rowStrategies.count else {
            throw SpreadsheetTransferError.inconsistentRows(expected: rowStrategies.count, actual: table.rows.count)
        }
        for (index, row) in table.rows.enumerated() where row.count != columnStrategies.count {
            throw SpreadsheetTransferError.inconsistentColumns(expected: columnStrategies.count, actual: row.count, row: index + 1)
        }
        var parsed: [[String]] = []
        for (row, values) in table.rows.enumerated() {
            for (column, value) in values.enumerated() {
                try SpreadsheetTable.requireFinite(value, column: columnStrategies[column], row: row + 1)
            }
            parsed.append(values)
        }
        payoffs = parsed
    }

    private static func parseRows(
        _ rows: [[String]],
        columnNames: [String],
        firstRowNumber: Int
    ) throws -> (names: [String], values: [[String]]) {
        var names: [String] = []
        var matrix: [[String]] = []
        for (index, row) in rows.enumerated() {
            let rowNumber = firstRowNumber + index
            let expected = columnNames.count + 1
            guard row.count == expected else {
                throw SpreadsheetTransferError.inconsistentColumns(expected: expected, actual: row.count, row: rowNumber)
            }
            guard !row[0].isEmpty else {
                throw SpreadsheetTransferError.invalidValue(row[0], column: "Player 1 Strategy", row: rowNumber)
            }
            let values = Array(row.dropFirst())
            for (column, value) in values.enumerated() {
                try SpreadsheetTable.requireFinite(value, column: columnNames[column], row: rowNumber)
            }
            names.append(row[0])
            matrix.append(values)
        }
        return (names, matrix)
    }

    private static func uniqueName(prefix: String, existing: [String]) -> String {
        var index = 1
        while existing.contains("\(prefix) \(index)") { index += 1 }
        return "\(prefix) \(index)"
    }
}
