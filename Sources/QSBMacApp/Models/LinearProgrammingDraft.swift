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
