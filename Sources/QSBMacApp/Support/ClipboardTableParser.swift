import Foundation

struct ClipboardTable: Equatable, Sendable {
    let rows: [[String]]

    var columnCount: Int { rows.first?.count ?? 0 }

    init(text: String) throws {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if lines.last?.isEmpty == true { lines.removeLast() }
        guard !lines.isEmpty else { throw ClipboardTableError.emptyClipboard }

        let parsed = lines.map { line in
            line.split(separator: "\t", omittingEmptySubsequences: false).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
        }
        guard let firstCount = parsed.first?.count, firstCount == 1 || firstCount == 2 else {
            throw ClipboardTableError.tooManyColumns
        }
        guard parsed.allSatisfy({ $0.count == firstCount }) else {
            throw ClipboardTableError.inconsistentColumns
        }
        guard !parsed.flatMap({ $0 }).contains(where: \.isEmpty) else {
            throw ClipboardTableError.emptyCell
        }
        rows = parsed
    }
}

enum ClipboardTableError: Error, Equatable, CustomStringConvertible {
    case emptyClipboard
    case tooManyColumns
    case inconsistentColumns
    case emptyCell

    var description: String {
        switch self {
        case .emptyClipboard: "The clipboard is empty."
        case .tooManyColumns: "Paste one numeric column or two tab-separated columns (period and value)."
        case .inconsistentColumns: "Every pasted row must have the same number of columns."
        case .emptyCell: "The paste contains an empty cell."
        }
    }
}
