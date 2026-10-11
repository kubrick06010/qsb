import Foundation

enum SpreadsheetTransferError: Error, Equatable, CustomStringConvertible {
    case emptyClipboard
    case inconsistentRows(expected: Int, actual: Int)
    case inconsistentColumns(expected: Int, actual: Int, row: Int)
    case invalidValue(String, column: String, row: Int)

    var description: String {
        switch self {
        case .emptyClipboard:
            "The copied range is empty."
        case .inconsistentRows(let expected, let actual):
            "The copied range has \(actual) rows; expected \(expected)."
        case .inconsistentColumns(let expected, let actual, let row):
            "Row \(row) has \(actual) columns; expected \(expected)."
        case .invalidValue(let value, let column, let row):
            "“\(value)” is not valid for \(column) in row \(row)."
        }
    }
}

struct SpreadsheetTable: Equatable, Sendable {
    let rows: [[String]]

    init(text: String) throws {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard !lines.isEmpty else { throw SpreadsheetTransferError.emptyClipboard }
        let delimiter: Character = normalized.contains("\t") ? "\t" : (normalized.contains(";") ? ";" : ",")
        let parsed = lines.map { line in
            line.split(separator: delimiter, omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        let expected = parsed[0].count
        for (index, row) in parsed.enumerated() where row.count != expected {
            throw SpreadsheetTransferError.inconsistentColumns(
                expected: expected,
                actual: row.count,
                row: index + 1
            )
        }
        rows = parsed
    }

    static func requireFinite(_ value: String, column: String, row: Int) throws {
        guard let number = Double(value), number.isFinite else {
            throw SpreadsheetTransferError.invalidValue(value, column: column, row: row)
        }
    }
}
