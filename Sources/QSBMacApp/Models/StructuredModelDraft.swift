import CoreFoundation
import Foundation
import Observation

enum StructuredModelTabularError: Error, CustomStringConvertible {
    case emptyClipboard
    case unsupportedShape
    case inconsistentColumns(expected: Int, actual: Int, row: Int)
    case tooManyColumns(maximum: Int, actual: Int, row: Int)
    case invalidValue(String, column: String, row: Int)

    var description: String {
        switch self {
        case .emptyClipboard:
            "The copied range is empty."
        case .unsupportedShape:
            "This section needs a family-specific table editor before it can accept a spreadsheet range."
        case .inconsistentColumns(let expected, let actual, let row):
            "Row \(row) has \(actual) columns; expected \(expected)."
        case .tooManyColumns(let maximum, let actual, let row):
            "Row \(row) has \(actual) columns; this table has \(maximum)."
        case .invalidValue(let value, let column, let row):
            "“\(value)” is not valid for \(column) in row \(row)."
        }
    }
}

@Observable
final class StructuredModelNode: Identifiable {
    enum ValueKind: String {
        case object
        case array
        case string
        case number
        case boolean
        case null
    }

    struct Field: Identifiable {
        let id: UUID
        let key: String
        var value: StructuredModelNode

        init(id: UUID = UUID(), key: String, value: StructuredModelNode) {
            self.id = id
            self.key = key
            self.value = value
        }
    }

    let id: UUID
    var kind: ValueKind
    var fields: [Field]
    var elements: [StructuredModelNode]
    var text: String
    var booleanValue: Bool

    init(
        id: UUID = UUID(),
        kind: ValueKind,
        fields: [Field] = [],
        elements: [StructuredModelNode] = [],
        text: String = "",
        booleanValue: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.fields = fields
        self.elements = elements
        self.text = text
        self.booleanValue = booleanValue
    }

    static func parse(_ json: String) throws -> StructuredModelNode {
        let data = Data(json.utf8)
        let value = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return try StructuredModelNode(jsonObject: value)
    }

    func encodedJSON() throws -> String {
        let object = try jsonObject()
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed]
        )
        return String(decoding: data, as: UTF8.self)
    }

    func child(named key: String) -> StructuredModelNode? {
        fields.first { $0.key == key }?.value
    }

    func clone() -> StructuredModelNode {
        StructuredModelNode(
            kind: kind,
            fields: fields.map { Field(key: $0.key, value: $0.value.clone()) },
            elements: elements.map { $0.clone() },
            text: text,
            booleanValue: booleanValue
        )
    }

    func appendArrayElement() {
        elements.append(elements.last?.clone() ?? StructuredModelNode(kind: .string))
    }

    func appendArrayElement(kind: ValueKind) {
        elements.append(StructuredModelNode(kind: kind))
    }

    func replaceNull(with replacement: ValueKind) {
        guard kind == .null else { return }
        kind = replacement
        text = ""
        booleanValue = false
        fields = []
        elements = []
    }

    func setToNull() {
        kind = .null
        fields = []
        elements = []
        text = ""
        booleanValue = false
    }

    func firstIssue(path: String = "Model") -> String? {
        switch kind {
        case .number:
            guard Self.decimalNumber(from: text) != nil else {
                return "\(path) must be a finite number."
            }
        case .object:
            for field in fields {
                if let issue = field.value.firstIssue(path: "\(path) › \(Self.displayName(for: field.key))") {
                    return issue
                }
            }
        case .array:
            for (index, element) in elements.enumerated() {
                if let issue = element.firstIssue(path: "\(path) › \(index + 1)") {
                    return issue
                }
            }
        case .string, .boolean, .null:
            break
        }
        return nil
    }

    var isScalar: Bool {
        switch kind {
        case .string, .number, .boolean, .null: true
        case .object, .array: false
        }
    }

    var isScalarMatrix: Bool {
        guard kind == .array, !elements.isEmpty else { return false }
        return elements.allSatisfy { row in
            row.kind == .array && row.elements.allSatisfy(\.isScalar)
        }
    }

    var itemSummary: String? {
        guard kind == .object else { return nil }
        for key in ["name", "title", "id", "period", "label"] {
            if let child = child(named: key), child.kind == .string, !child.text.isEmpty {
                return child.text
            }
        }
        return nil
    }

    var supportsTabularTransfer: Bool {
        guard kind == .array, !elements.isEmpty else { return false }
        if elements.allSatisfy(\.isScalar) || isScalarMatrix { return true }
        guard let first = elements.first, first.kind == .object else { return false }
        let signature = first.tabularShapeSignature
        return !first.tabularColumns().isEmpty && elements.allSatisfy { $0.tabularShapeSignature == signature }
    }

    func replaceArrayContents(withTabularText text: String) throws {
        guard kind == .array else { throw StructuredModelTabularError.unsupportedShape }
        var rows = try Self.tabularRows(from: text)

        if elements.allSatisfy(\.isScalar), let template = elements.first {
            let cells = rows.flatMap { $0 }
            elements = try cells.enumerated().map { index, value in
                try Self.node(byApplying: value, to: template, column: "value \(index + 1)", row: 1)
            }
            return
        }

        if isScalarMatrix,
           let rowTemplate = elements.first,
           let cellTemplate = rowTemplate.elements.first {
            let expected = rows.first?.count ?? 0
            for (index, row) in rows.enumerated() where row.count != expected {
                throw StructuredModelTabularError.inconsistentColumns(
                    expected: expected,
                    actual: row.count,
                    row: index + 1
                )
            }
            elements = try rows.enumerated().map { rowIndex, row in
                StructuredModelNode(
                    kind: .array,
                    elements: try row.enumerated().map { columnIndex, value in
                        try Self.node(
                            byApplying: value,
                            to: cellTemplate,
                            column: "column \(columnIndex + 1)",
                            row: rowIndex + 1
                        )
                    }
                )
            }
            return
        }

        guard let template = elements.first, template.kind == .object else {
            throw StructuredModelTabularError.unsupportedShape
        }
        let templateColumns = template.tabularColumns()
        guard !templateColumns.isEmpty else { throw StructuredModelTabularError.unsupportedShape }

        if let first = rows.first, Self.looksLikeHeader(first, columns: templateColumns) {
            rows.removeFirst()
        }
        guard !rows.isEmpty else { throw StructuredModelTabularError.emptyClipboard }

        elements = try rows.enumerated().map { rowIndex, values in
            guard values.count <= templateColumns.count else {
                throw StructuredModelTabularError.tooManyColumns(
                    maximum: templateColumns.count,
                    actual: values.count,
                    row: rowIndex + 1
                )
            }
            let item = template.clone()
            let columns = item.tabularColumns()
            for (columnIndex, value) in values.enumerated() {
                try Self.apply(
                    value,
                    to: columns[columnIndex].node,
                    column: columns[columnIndex].label,
                    row: rowIndex + 1
                )
            }
            return item
        }
    }

    func tabularText() throws -> String {
        guard kind == .array else { throw StructuredModelTabularError.unsupportedShape }
        if elements.allSatisfy(\.isScalar) {
            return elements.map(\.spreadsheetValue).joined(separator: "\t")
        }
        if isScalarMatrix {
            return elements.map { row in
                row.elements.map(\.spreadsheetValue).joined(separator: "\t")
            }.joined(separator: "\n")
        }
        guard supportsTabularTransfer else { throw StructuredModelTabularError.unsupportedShape }
        let columns = elements[0].tabularColumns()
        let header = columns.map(\.label).joined(separator: "\t")
        let body = elements.map { item in
            item.tabularColumns().map { $0.node.spreadsheetValue }.joined(separator: "\t")
        }.joined(separator: "\n")
        return body.isEmpty ? header : header + "\n" + body
    }

    static func displayName(for key: String) -> String {
        let common: [String: String] = [
            "aql": "AQL",
            "bom": "BOM",
            "id": "ID",
            "ids": "IDs",
            "rql": "RQL",
            "rhs": "Right-hand side",
            "url": "URL"
        ]
        if let known = common[key.lowercased()] {
            return known
        }

        let expanded = key
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(
                of: "([a-z0-9])([A-Z])",
                with: "$1 $2",
                options: .regularExpression
            )
        let words = expanded.split(separator: " ").map(String.init)
        return words.enumerated().map { index, word in
            if let known = common[word.lowercased()] { return known }
            return index == 0 ? word.prefix(1).uppercased() + word.dropFirst() : word.lowercased()
        }.joined(separator: " ")
    }

    private convenience init(jsonObject value: Any) throws {
        if value is NSNull {
            self.init(kind: .null)
        } else if let dictionary = value as? [String: Any] {
            let fields = try dictionary
                .map { Field(key: $0.key, value: try StructuredModelNode(jsonObject: $0.value)) }
                .sorted { Self.fieldOrder($0.key) < Self.fieldOrder($1.key) }
            self.init(kind: .object, fields: fields)
        } else if let array = value as? [Any] {
            self.init(kind: .array, elements: try array.map(StructuredModelNode.init(jsonObject:)))
        } else if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self.init(kind: .boolean, booleanValue: number.boolValue)
            } else {
                self.init(kind: .number, text: number.stringValue)
            }
        } else if let string = value as? String {
            self.init(kind: .string, text: string)
        } else {
            throw CocoaError(
                .fileReadCorruptFile,
                userInfo: [NSLocalizedDescriptionKey: "The model contains an unsupported JSON value."]
            )
        }
    }

    private struct TabularColumn {
        let label: String
        let node: StructuredModelNode
    }

    private var tabularShapeSignature: String {
        switch kind {
        case .object:
            return "object:" + fields.map { "\($0.key)=\($0.value.tabularShapeSignature)" }.joined(separator: ",")
        case .array:
            if elements.allSatisfy(\.isScalar) {
                return "array:" + elements.map { $0.kind.rawValue }.joined(separator: ",")
            }
            return "complex-array"
        case .string, .number, .boolean, .null:
            return kind.rawValue
        }
    }

    private func tabularColumns(prefix: String = "") -> [TabularColumn] {
        switch kind {
        case .object:
            return fields.flatMap { field in
                let name = Self.displayName(for: field.key)
                let fieldPrefix = prefix.isEmpty ? name : "\(prefix) \(name)"
                return field.value.tabularColumns(prefix: fieldPrefix)
            }
        case .array:
            guard elements.allSatisfy(\.isScalar) else { return [] }
            return elements.enumerated().map { index, element in
                TabularColumn(label: "\(prefix) \(index + 1)", node: element)
            }
        case .string, .number, .boolean, .null:
            return [TabularColumn(label: prefix, node: self)]
        }
    }

    private var spreadsheetValue: String {
        let value: String
        switch kind {
        case .string, .number:
            value = text
        case .boolean:
            value = booleanValue ? "true" : "false"
        case .null:
            value = ""
        case .object, .array:
            value = ""
        }
        return value.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ")
    }

    private static func tabularRows(from text: String) throws -> [[String]] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let nonemptyLines = normalized.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard !nonemptyLines.isEmpty else { throw StructuredModelTabularError.emptyClipboard }
        let delimiter: Character = normalized.contains("\t") ? "\t" : (normalized.contains(";") ? ";" : ",")
        return nonemptyLines.map { line in
            line.split(separator: delimiter, omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        }
    }

    private static func looksLikeHeader(_ values: [String], columns: [TabularColumn]) -> Bool {
        guard !values.isEmpty else { return false }
        let matches = zip(values, columns).filter { normalizeHeader($0.0) == normalizeHeader($0.1.label) }.count
        return matches > 0 && matches * 2 >= min(values.count, columns.count)
    }

    private static func normalizeHeader(_ value: String) -> String {
        value.lowercased().filter(\.isLetter)
    }

    private static func node(
        byApplying value: String,
        to template: StructuredModelNode,
        column: String,
        row: Int
    ) throws -> StructuredModelNode {
        let node = template.clone()
        try apply(value, to: node, column: column, row: row)
        return node
    }

    private static func apply(
        _ value: String,
        to node: StructuredModelNode,
        column: String,
        row: Int
    ) throws {
        switch node.kind {
        case .string:
            node.text = value
        case .number:
            guard decimalNumber(from: value) != nil else {
                throw StructuredModelTabularError.invalidValue(value, column: column, row: row)
            }
            node.text = value
        case .boolean:
            switch value.lowercased() {
            case "true", "yes", "1": node.booleanValue = true
            case "false", "no", "0": node.booleanValue = false
            default: throw StructuredModelTabularError.invalidValue(value, column: column, row: row)
            }
        case .null:
            if value.isEmpty {
                node.setToNull()
            } else if decimalNumber(from: value) != nil {
                node.replaceNull(with: .number)
                node.text = value
            } else {
                node.replaceNull(with: .string)
                node.text = value
            }
        case .object, .array:
            throw StructuredModelTabularError.invalidValue(value, column: column, row: row)
        }
    }

    private func jsonObject() throws -> Any {
        switch kind {
        case .object:
            return try fields.reduce(into: [String: Any]()) { result, field in
                result[field.key] = try field.value.jsonObject()
            }
        case .array:
            return try elements.map { try $0.jsonObject() }
        case .string:
            return text
        case .number:
            guard let number = Self.decimalNumber(from: text) else {
                throw CocoaError(
                    .formatting,
                    userInfo: [NSLocalizedDescriptionKey: "\(text) is not a finite number."]
                )
            }
            return number
        case .boolean:
            return booleanValue
        case .null:
            return NSNull()
        }
    }

    private static func decimalNumber(from text: String) -> NSDecimalNumber? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let number = NSDecimalNumber(string: trimmed, locale: Locale(identifier: "en_US_POSIX"))
        guard number != .notANumber else { return nil }
        return number
    }

    private static func fieldOrder(_ key: String) -> String {
        let priority: [String: Int] = [
            "title": 0,
            "name": 1,
            "kind": 2,
            "representation": 3,
            "model": 4,
            "request": 5
        ]
        return String(format: "%03d-%@", priority[key] ?? 100, key.localizedLowercase)
    }
}
