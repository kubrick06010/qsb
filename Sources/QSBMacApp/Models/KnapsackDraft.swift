import Foundation
import QSBCore

enum KnapsackDraftError: Error, Equatable, CustomStringConvertible {
    case emptyField(path: String, label: String)
    case invalidNumber(path: String, label: String, value: String)
    case invalidInteger(path: String, label: String, value: String)

    var path: String {
        switch self {
        case .emptyField(let path, _), .invalidNumber(let path, _, _), .invalidInteger(let path, _, _): path
        }
    }

    var description: String {
        switch self {
        case .emptyField(_, let label): "Enter \(label)."
        case .invalidNumber(_, let label, let value): "Enter a finite number for \(label) (received ‘\(value)’)."
        case .invalidInteger(_, let label, let value): "Enter a whole number for \(label) (received ‘\(value)’)."
        }
    }
}

struct KnapsackItemDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var available: String
    var capacityRequired: String
    var returnPerUnit: String

    init(id: UUID = UUID(), name: String, available: String = "1", capacityRequired: String = "1", returnPerUnit: String = "0") {
        self.id = id; self.name = name; self.available = available
        self.capacityRequired = capacityRequired; self.returnPerUnit = returnPerUnit
    }
}

struct KnapsackDraft: Equatable, Sendable {
    var title: String
    var capacity: String
    var items: [KnapsackItemDraft]

    static let headers = ["Item", "Available", "Capacity Required", "Return Per Unit"]

    private init(title: String, capacity: String, items: [KnapsackItemDraft]) {
        self.title = title; self.capacity = capacity; self.items = items
    }

    static func blank() -> Self {
        Self(title: "New Bounded Knapsack", capacity: "10", items: [KnapsackItemDraft(name: "Item 1", available: "1", capacityRequired: "1", returnPerUnit: "1")])
    }

    init(_ problem: KnapsackProblem) {
        title = problem.title
        capacity = String(problem.capacity)
        items = problem.items.map {
            KnapsackItemDraft(name: $0.name, available: String($0.available), capacityRequired: String($0.capacityRequired), returnPerUnit: String($0.returnPerUnit))
        }
    }

    func makeProblem() throws -> KnapsackProblem {
        try required(title, path: "model.title", label: "a model title")
        let parsedItems = try items.enumerated().map { index, item in
            let base = "model.items.\(index)"
            try required(item.name, path: "\(base).name", label: "an item name")
            return KnapsackItem(
                name: item.name,
                available: try integer(item.available, path: "\(base).available", label: "available quantity"),
                capacityRequired: try integer(item.capacityRequired, path: "\(base).capacityRequired", label: "capacity required"),
                returnPerUnit: try number(item.returnPerUnit, path: "\(base).returnPerUnit", label: "return per unit")
            )
        }
        return KnapsackProblem(
            title: title,
            capacity: try integer(capacity, path: "model.capacity", label: "knapsack capacity"),
            items: parsedItems
        )
    }

    func draftDiagnostics() -> [ValidationDiagnostic] {
        do {
            return KnapsackValidator.diagnostics(for: try makeProblem())
        } catch let error as KnapsackDraftError {
            return [ValidationDiagnostic(
                severity: .error, code: "knapsack.draft.\(error.path.replacingOccurrences(of: ".", with: "_"))",
                message: error.description, path: error.path
            )]
        } catch {
            return [ValidationDiagnostic(severity: .error, code: "knapsack.draft.invalid", message: error.localizedDescription)]
        }
    }

    @discardableResult
    mutating func addItem() -> UUID {
        var suffix = items.count + 1
        var name = "Item \(suffix)"
        while items.contains(where: { $0.name == name }) { suffix += 1; name = "Item \(suffix)" }
        let item = KnapsackItemDraft(name: name)
        items.append(item)
        return item.id
    }

    mutating func removeItem(id: UUID) {
        guard items.count > 1 else { return }
        items.removeAll { $0.id == id }
    }

    func tabularText() -> String {
        ([Self.headers] + items.map { [$0.name, $0.available, $0.capacityRequired, $0.returnPerUnit] })
            .map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }

    mutating func replaceItems(withTabularText text: String) throws {
        var rows = try SpreadsheetTable(text: text).rows
        if rows.first?.map({ $0.lowercased() }) == Self.headers.map({ $0.lowercased() }) { rows.removeFirst() }
        guard !rows.isEmpty else { throw SpreadsheetTransferError.emptyClipboard }
        let existing = Dictionary(grouping: items, by: \.name)
        let incoming = Dictionary(grouping: rows, by: { $0.first ?? "" })
        var replacement: [KnapsackItemDraft] = []
        for (index, row) in rows.enumerated() {
            let displayRow = index + 1
            guard row.count == Self.headers.count else {
                throw SpreadsheetTransferError.inconsistentColumns(expected: Self.headers.count, actual: row.count, row: displayRow)
            }
            guard !row[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SpreadsheetTransferError.invalidValue(row[0], column: "Item", row: displayRow) }
            guard Int(row[1]) != nil else { throw SpreadsheetTransferError.invalidValue(row[1], column: "Available", row: displayRow) }
            guard Int(row[2]) != nil else { throw SpreadsheetTransferError.invalidValue(row[2], column: "Capacity Required", row: displayRow) }
            try SpreadsheetTable.requireFinite(row[3], column: "Return Per Unit", row: displayRow)
            // A unique name preserves the existing row across spreadsheet reorder.
            let id = existing[row[0]]?.count == 1 && incoming[row[0]]?.count == 1 ? existing[row[0]]?.first?.id : nil
            replacement.append(KnapsackItemDraft(id: id ?? UUID(), name: row[0], available: row[1], capacityRequired: row[2], returnPerUnit: row[3]))
        }
        items = replacement
    }

    private func required(_ value: String, path: String, label: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw KnapsackDraftError.emptyField(path: path, label: label)
        }
    }

    private func integer(_ value: String, path: String, label: String) throws -> Int {
        guard let integer = Int(value) else { throw KnapsackDraftError.invalidInteger(path: path, label: label, value: value) }
        return integer
    }

    private func number(_ value: String, path: String, label: String) throws -> Double {
        guard let number = Double(value), number.isFinite else { throw KnapsackDraftError.invalidNumber(path: path, label: label, value: value) }
        return number
    }
}
