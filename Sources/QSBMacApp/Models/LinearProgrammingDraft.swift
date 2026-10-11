import Foundation
import QSBCore

enum LPDraftBound: Equatable, Sendable {
    case unbounded
    case value(String)
}

struct LPDraftVariable: Equatable, Sendable {
    var name: String
    var type: VariableType
    var lowerBound: String
    var upperBound: LPDraftBound
    var unrestricted: Bool
}

struct LPDraftConstraint: Equatable, Sendable {
    var name: String
    var coefficients: [String]
    var relation: ConstraintRelation
    var rhs: String
}

enum LPDraftError: Error, Equatable, CustomStringConvertible {
    case emptyTitle
    case emptyVariableName(index: Int)
    case emptyConstraintName(index: Int)
    case invalidNumber(path: String, value: String)
    case missingUpperBound(index: Int)
    case dimension(path: String)

    var path: String {
        switch self {
        case .emptyTitle: "title"
        case .emptyVariableName(let index): "variables.\(index).name"
        case .emptyConstraintName(let index): "constraints.\(index).name"
        case .invalidNumber(let path, _), .dimension(let path): path
        case .missingUpperBound(let index): "variables.\(index).upperBound"
        }
    }

    var message: String {
        switch self {
        case .emptyTitle: "Enter a model title."
        case .emptyVariableName(let index): "Variable \(index + 1) needs a name."
        case .emptyConstraintName(let index): "Constraint \(index + 1) needs a name."
        case .invalidNumber(let path, let value): "Enter a finite number for \(path) (received '\(value)')."
        case .missingUpperBound(let index): "Enter an upper bound or mark variable \(index + 1) as unbounded."
        case .dimension(let path): "The editor data is dimensionally inconsistent at \(path)."
        }
    }

    var description: String { message }
}

enum LPDraftTabularError: Error, Equatable, CustomStringConvertible {
    case emptyClipboard
    case inconsistentColumns(expected: Int, actual: Int, row: Int)
    case invalidValue(String, column: String, row: Int)

    var description: String {
        switch self {
        case .emptyClipboard:
            "The copied range is empty."
        case .inconsistentColumns(let expected, let actual, let row):
            "Row \(row) has \(actual) columns; expected \(expected)."
        case .invalidValue(let value, let column, let row):
            "“\(value)” is not valid for \(column) in row \(row)."
        }
    }
}

struct LinearProgrammingDraft: Equatable, Sendable {
    var title: String
    var sense: ObjectiveSense
    var variables: [LPDraftVariable]
    var objectiveCoefficients: [String]
    var constraints: [LPDraftConstraint]

    init(
        title: String,
        sense: ObjectiveSense,
        variables: [LPDraftVariable],
        objectiveCoefficients: [String],
        constraints: [LPDraftConstraint]
    ) {
        self.title = title
        self.sense = sense
        self.variables = variables
        self.objectiveCoefficients = objectiveCoefficients
        self.constraints = constraints
    }

    static func blank() -> Self {
        Self(
            title: "New Linear Program",
            sense: .maximize,
            variables: [LPDraftVariable(
                name: "x1",
                type: .continuous,
                lowerBound: "0",
                upperBound: .unbounded,
                unrestricted: false
            )],
            objectiveCoefficients: ["0"],
            constraints: []
        )
    }

    init(program: LinearProgram) {
        title = program.title
        sense = program.sense
        variables = program.variableNames.indices.map { index in
            LPDraftVariable(
                name: program.variableNames[index],
                type: program.variableTypes[safe: index] ?? .continuous,
                lowerBound: Self.format(program.lowerBounds[safe: index] ?? 0),
                upperBound: (program.upperBounds[safe: index] ?? nil).map { .value(Self.format($0)) } ?? .unbounded,
                unrestricted: program.unrestrictedVariables[safe: index] ?? false
            )
        }
        objectiveCoefficients = program.objectiveCoefficients.map(Self.format)
        constraints = program.constraints.map { constraint in
            LPDraftConstraint(
                name: constraint.name,
                coefficients: constraint.coefficients.map(Self.format),
                relation: constraint.relation,
                rhs: Self.format(constraint.rhs)
            )
        }
    }

    func makeLinearProgram() throws -> LinearProgram {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { throw LPDraftError.emptyTitle }
        guard objectiveCoefficients.count == variables.count else {
            throw LPDraftError.dimension(path: "objectiveCoefficients")
        }

        var names: [String] = []
        var lowerBounds: [Double] = []
        var upperBounds: [Double?] = []
        var variableTypes: [VariableType] = []
        var unrestricted: [Bool] = []

        for (index, variable) in variables.enumerated() {
            let name = variable.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { throw LPDraftError.emptyVariableName(index: index) }
            names.append(name)
            variableTypes.append(variable.type)
            unrestricted.append(variable.unrestricted)

            let lower = try Self.number(variable.lowerBound, path: "variables.\(index).lowerBound")
            lowerBounds.append(lower)
            switch variable.upperBound {
            case .unbounded:
                upperBounds.append(nil)
            case .value(let value):
                upperBounds.append(try Self.number(value, path: "variables.\(index).upperBound"))
            }
        }

        let objective = try objectiveCoefficients.enumerated().map { index, value in
            try Self.number(value, path: "objectiveCoefficients.\(index)")
        }

        let normalizedConstraints = try constraints.enumerated().map { index, constraint in
            let name = constraint.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { throw LPDraftError.emptyConstraintName(index: index) }
            guard constraint.coefficients.count == variables.count else {
                throw LPDraftError.dimension(path: "constraints.\(index).coefficients")
            }
            let coefficients = try constraint.coefficients.enumerated().map { column, value in
                try Self.number(value, path: "constraints.\(index).coefficients.\(column)")
            }
            return LinearConstraint(
                name: name,
                coefficients: coefficients,
                relation: constraint.relation,
                rhs: try Self.number(constraint.rhs, path: "constraints.\(index).rhs")
            )
        }

        return LinearProgram(
            title: trimmedTitle,
            sense: sense,
            variableNames: names,
            objectiveCoefficients: objective,
            constraints: normalizedConstraints,
            lowerBounds: lowerBounds,
            upperBounds: upperBounds,
            variableTypes: variableTypes,
            unrestrictedVariables: unrestricted
        )
    }

    func draftDiagnostics() -> [ValidationDiagnostic] {
        do {
            let program = try makeLinearProgram()
            return LinearProgramValidator.diagnostics(for: program)
        } catch let error as LPDraftError {
            return [ValidationDiagnostic(
                severity: .error,
                code: "lp.draft.\(error.path.replacingOccurrences(of: ".", with: "_"))",
                message: error.message,
                path: error.path
            )]
        } catch {
            return [ValidationDiagnostic(
                severity: .error,
                code: "lp.draft.invalid",
                message: error.localizedDescription,
                path: nil
            )]
        }
    }

    mutating func addVariable() {
        let index = variables.count + 1
        variables.append(LPDraftVariable(
            name: "x\(index)",
            type: .continuous,
            lowerBound: "0",
            upperBound: .unbounded,
            unrestricted: false
        ))
        objectiveCoefficients.append("0")
        for index in constraints.indices {
            constraints[index].coefficients.append("0")
        }
    }

    mutating func removeVariable(at index: Int) {
        guard variables.indices.contains(index), variables.count > 1 else { return }
        variables.remove(at: index)
        if objectiveCoefficients.indices.contains(index) {
            objectiveCoefficients.remove(at: index)
        }
        for constraintIndex in constraints.indices where constraints[constraintIndex].coefficients.indices.contains(index) {
            constraints[constraintIndex].coefficients.remove(at: index)
        }
    }

    mutating func addConstraint() {
        constraints.append(LPDraftConstraint(
            name: "C\(constraints.count + 1)",
            coefficients: Array(repeating: "0", count: variables.count),
            relation: .lessThanOrEqual,
            rhs: "0"
        ))
    }

    mutating func removeConstraint(at index: Int) {
        guard constraints.indices.contains(index) else { return }
        constraints.remove(at: index)
    }

    func variablesTabularText() -> String {
        let header = ["Name", "Objective", "Type", "Lower", "Upper", "Unrestricted"].joined(separator: "\t")
        let rows = variables.indices.map { index in
            let variable = variables[index]
            let upper = switch variable.upperBound {
            case .unbounded: ""
            case .value(let value): value
            }
            return [
                variable.name,
                objectiveCoefficients[index],
                variable.type.rawValue,
                variable.lowerBound,
                upper,
                variable.unrestricted ? "true" : "false"
            ].joined(separator: "\t")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    mutating func replaceVariables(withTabularText text: String) throws {
        var rows = try Self.tabularRows(from: text)
        let columns = ["Name", "Objective", "Type", "Lower", "Upper", "Unrestricted"]
        if Self.isHeader(rows[0], matching: columns) { rows.removeFirst() }
        guard !rows.isEmpty else { throw LPDraftTabularError.emptyClipboard }

        var pastedVariables: [LPDraftVariable] = []
        var pastedObjectives: [String] = []
        for (index, row) in rows.enumerated() {
            try Self.requireColumnCount(row, expected: columns.count, row: index + 1)
            let rowNumber = index + 1
            let name = row[0].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                throw LPDraftTabularError.invalidValue(row[0], column: "Name", row: rowNumber)
            }
            try Self.requireNumber(row[1], column: "Objective", row: rowNumber)
            guard let type = VariableType(rawValue: row[2].lowercased()) else {
                throw LPDraftTabularError.invalidValue(row[2], column: "Type", row: rowNumber)
            }
            try Self.requireNumber(row[3], column: "Lower", row: rowNumber)
            if !row[4].isEmpty { try Self.requireNumber(row[4], column: "Upper", row: rowNumber) }
            let unrestricted = try Self.boolean(row[5], column: "Unrestricted", row: rowNumber)

            pastedVariables.append(LPDraftVariable(
                name: name,
                type: type,
                lowerBound: row[3],
                upperBound: row[4].isEmpty ? .unbounded : .value(row[4]),
                unrestricted: unrestricted
            ))
            pastedObjectives.append(row[1])
        }

        let newCount = pastedVariables.count
        let resizedConstraints = constraints.map { constraint in
            var coefficients = Array(constraint.coefficients.prefix(newCount))
            coefficients.append(contentsOf: repeatElement("0", count: max(0, newCount - coefficients.count)))
            return LPDraftConstraint(
                name: constraint.name,
                coefficients: coefficients,
                relation: constraint.relation,
                rhs: constraint.rhs
            )
        }
        variables = pastedVariables
        objectiveCoefficients = pastedObjectives
        constraints = resizedConstraints
    }

    func constraintsTabularText() -> String {
        let header = ["Name"] + variables.map(\.name) + ["Relation", "RHS"]
        let rows = constraints.map { constraint in
            [constraint.name] + constraint.coefficients + [constraint.relation.rawValue, constraint.rhs]
        }
        return ([header] + rows).map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }

    mutating func replaceConstraints(withTabularText text: String) throws {
        var rows = try Self.tabularRows(from: text)
        let columns = ["Name"] + variables.map(\.name) + ["Relation", "RHS"]
        if Self.isHeader(rows[0], matching: columns) { rows.removeFirst() }
        guard !rows.isEmpty else { throw LPDraftTabularError.emptyClipboard }

        let pasted = try rows.enumerated().map { index, row in
            try Self.requireColumnCount(row, expected: columns.count, row: index + 1)
            let rowNumber = index + 1
            let name = row[0].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                throw LPDraftTabularError.invalidValue(row[0], column: "Name", row: rowNumber)
            }
            let coefficients = Array(row[1..<(1 + variables.count)])
            for (column, value) in coefficients.enumerated() {
                try Self.requireNumber(value, column: variables[column].name, row: rowNumber)
            }
            let relationIndex = 1 + variables.count
            let relationText = row[relationIndex]
                .replacingOccurrences(of: "≤", with: "<=")
                .replacingOccurrences(of: "≥", with: ">=")
            guard let relation = ConstraintRelation(rawValue: relationText) else {
                throw LPDraftTabularError.invalidValue(row[relationIndex], column: "Relation", row: rowNumber)
            }
            try Self.requireNumber(row[relationIndex + 1], column: "RHS", row: rowNumber)
            return LPDraftConstraint(
                name: name,
                coefficients: coefficients,
                relation: relation,
                rhs: row[relationIndex + 1]
            )
        }
        constraints = pasted
    }

    private static func tabularRows(from text: String) throws -> [[String]] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard !lines.isEmpty else { throw LPDraftTabularError.emptyClipboard }
        let delimiter: Character = normalized.contains("\t") ? "\t" : (normalized.contains(";") ? ";" : ",")
        return lines.map { line in
            line.split(separator: delimiter, omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        }
    }

    private static func requireColumnCount(_ rowValues: [String], expected: Int, row: Int) throws {
        guard rowValues.count == expected else {
            throw LPDraftTabularError.inconsistentColumns(expected: expected, actual: rowValues.count, row: row)
        }
    }

    private static func requireNumber(_ value: String, column: String, row: Int) throws {
        guard let number = Double(value), number.isFinite else {
            throw LPDraftTabularError.invalidValue(value, column: column, row: row)
        }
    }

    private static func boolean(_ value: String, column: String, row: Int) throws -> Bool {
        switch value.lowercased() {
        case "true", "yes", "1": true
        case "false", "no", "0": false
        default: throw LPDraftTabularError.invalidValue(value, column: column, row: row)
        }
    }

    private static func isHeader(_ values: [String], matching columns: [String]) -> Bool {
        guard values.count == columns.count else { return false }
        let normalizedValues = values.map { $0.lowercased().filter(\.isLetter) }
        let normalizedColumns = columns.map { $0.lowercased().filter(\.isLetter) }
        let matches = zip(normalizedValues, normalizedColumns).filter(==).count
        return matches * 2 >= columns.count
    }

    private static func number(_ text: String, path: String) throws -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value.isFinite else {
            throw LPDraftError.invalidNumber(path: path, value: text)
        }
        return value
    }

    private static func format(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 1e-10 { return String(Int(rounded)) }
        return String(format: "%.6g", value)
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
