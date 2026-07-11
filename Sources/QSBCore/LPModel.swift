import Foundation

public enum ObjectiveSense: String, Codable, Sendable {
    case maximize
    case minimize
}

public enum ConstraintRelation: String, Codable, Sendable {
    case lessThanOrEqual = "<="
    case greaterThanOrEqual = ">="
    case equal = "="
}

public enum VariableType: String, Codable, Sendable {
    case continuous
    case integer
    case binary
}

public struct LinearConstraint: Codable, Equatable, Sendable {
    public let name: String
    public let coefficients: [Double]
    public let relation: ConstraintRelation
    public let rhs: Double
}

public struct LinearProgram: Codable, Equatable, Sendable {
    public let title: String
    public let sense: ObjectiveSense
    public let variableNames: [String]
    public let objectiveCoefficients: [Double]
    public let constraints: [LinearConstraint]
    public let lowerBounds: [Double]
    public let upperBounds: [Double?]
    public let variableTypes: [VariableType]

    public init(
        title: String,
        sense: ObjectiveSense,
        variableNames: [String],
        objectiveCoefficients: [Double],
        constraints: [LinearConstraint],
        lowerBounds: [Double]? = nil,
        upperBounds: [Double?]? = nil,
        variableTypes: [VariableType]? = nil
    ) {
        self.title = title
        self.sense = sense
        self.variableNames = variableNames
        self.objectiveCoefficients = objectiveCoefficients
        self.constraints = constraints
        self.lowerBounds = lowerBounds ?? Array(repeating: 0, count: variableNames.count)
        self.upperBounds = upperBounds ?? Array(repeating: nil, count: variableNames.count)
        self.variableTypes = variableTypes ?? Array(repeating: .continuous, count: variableNames.count)
    }
}

public struct LinearProgramSolution: Codable, Equatable, Sendable {
    public let objectiveValue: Double
    public let variableValues: [String: Double]
}

public enum LinearProgramSolveMode: String, Codable, Sendable {
    case continuous
    case integer
}

public protocol LinearProgrammingBackend: Sendable {
    var capabilities: SolverCapabilities { get }

    func validationReport(for program: LinearProgram) -> ValidationReport
    func solve(
        _ program: LinearProgram,
        mode: LinearProgramSolveMode,
        options: SolverOptions
    ) throws -> LinearProgramSolution
}

public extension LinearProgrammingBackend {
    func validationReport(for program: LinearProgram) -> ValidationReport {
        ValidationReport(
            backend: capabilities.backendKind,
            diagnostics: LinearProgramValidator.diagnostics(for: program)
        )
    }

    func solve(
        _ program: LinearProgram,
        mode: LinearProgramSolveMode
    ) throws -> LinearProgramSolution {
        try solve(program, mode: mode, options: SolverOptions())
    }
}

public struct NativeEducationalLinearProgrammingBackend: LinearProgrammingBackend {
    public init() {}

    public var capabilities: SolverCapabilities {
        SolverCapabilities(
            backendKind: .nativeEducational,
            solves: true,
            validates: true,
            exportsStructuredSolution: true,
            notes: [
                "Uses the bundled two-phase simplex solver for continuous LP models.",
                "Uses fixture-scale branch-and-bound for integer and binary variables."
            ]
        )
    }

    public func solve(
        _ program: LinearProgram,
        mode: LinearProgramSolveMode,
        options: SolverOptions = SolverOptions()
    ) throws -> LinearProgramSolution {
        try LinearProgramValidator.validate(program)
        switch mode {
        case .continuous:
            return try SimplexSolver.solve(program)
        case .integer:
            return try IntegerLinearProgramSolver.solve(
                program,
                maxNodes: options.nodeLimit ?? 10_000
            )
        }
    }
}

public struct ValidateOnlyLinearProgrammingBackend: LinearProgrammingBackend {
    public init() {}

    public var capabilities: SolverCapabilities {
        SolverCapabilities(
            backendKind: .validateOnly,
            solves: false,
            validates: true,
            exportsStructuredSolution: false,
            notes: [
                "Runs structural and semantic validation without solving the model."
            ]
        )
    }

    public func solve(
        _ program: LinearProgram,
        mode: LinearProgramSolveMode,
        options: SolverOptions = SolverOptions()
    ) throws -> LinearProgramSolution {
        throw LinearProgramError.unsupportedModel(
            "validateOnly backend does not solve \(mode.rawValue) LP models"
        )
    }
}

public enum LinearProgrammingBackends {
    public static func backend(for kind: SolverBackendKind) -> (any LinearProgrammingBackend)? {
        switch kind {
        case .nativeEducational:
            NativeEducationalLinearProgrammingBackend()
        case .validateOnly:
            ValidateOnlyLinearProgrammingBackend()
        case .externalHighPerformance:
            nil
        }
    }
}

public enum LinearProgramValidator {
    public static func diagnostics(for program: LinearProgram) -> [ValidationDiagnostic] {
        var diagnostics: [ValidationDiagnostic] = []
        let variableCount = program.variableNames.count

        if variableCount == 0 {
            diagnostics.append(error("lp.variableNames.empty", "variableNames must contain at least one variable", path: "variableNames"))
            return diagnostics
        }

        let trimmedVariableNames = program.variableNames.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if trimmedVariableNames.contains(where: \.isEmpty) {
            diagnostics.append(error("lp.variableNames.emptyName", "variableNames must not contain empty names", path: "variableNames"))
        }
        if Set(program.variableNames).count != variableCount {
            diagnostics.append(error("lp.variableNames.duplicate", "variableNames must be unique", path: "variableNames"))
        }
        if program.objectiveCoefficients.count != variableCount {
            diagnostics.append(error("lp.objectiveCoefficients.dimension", "objectiveCoefficients must contain one value per variable", path: "objectiveCoefficients"))
        }
        if program.lowerBounds.count != variableCount {
            diagnostics.append(error("lp.lowerBounds.dimension", "lowerBounds must contain one value per variable", path: "lowerBounds"))
        }
        if program.upperBounds.count != variableCount {
            diagnostics.append(error("lp.upperBounds.dimension", "upperBounds must contain one value or null per variable", path: "upperBounds"))
        }
        if program.variableTypes.count != variableCount {
            diagnostics.append(error("lp.variableTypes.dimension", "variableTypes must contain one value per variable", path: "variableTypes"))
        }
        if !program.objectiveCoefficients.allSatisfy(\.isFinite) {
            diagnostics.append(error("lp.objectiveCoefficients.finite", "objectiveCoefficients must be finite", path: "objectiveCoefficients"))
        }

        guard program.lowerBounds.count == variableCount,
              program.upperBounds.count == variableCount,
              program.variableTypes.count == variableCount
        else {
            return diagnostics
        }

        for index in 0..<variableCount {
            let name = program.variableNames[index]
            let lower = program.lowerBounds[index]
            let variablePath = "variables.\(name)"
            if !lower.isFinite {
                diagnostics.append(error("lp.lowerBounds.finite", "lower bound for '\(name)' must be finite", path: "\(variablePath).lowerBound"))
            }
            if lower < 0 {
                diagnostics.append(error("lp.lowerBounds.nonnegative", "lower bound for '\(name)' must be nonnegative", path: "\(variablePath).lowerBound"))
            }
            if let upper = program.upperBounds[index] {
                if !upper.isFinite {
                    diagnostics.append(error("lp.upperBounds.finite", "upper bound for '\(name)' must be finite", path: "\(variablePath).upperBound"))
                }
                if upper < lower {
                    diagnostics.append(error("lp.upperBounds.order", "upper bound for '\(name)' must be greater than or equal to its lower bound", path: "\(variablePath).upperBound"))
                }
            }
            if program.variableTypes[index] == .binary {
                if lower < 0 || lower > 1 {
                    diagnostics.append(error("lp.binary.lowerBound", "binary variable '\(name)' lower bound must be between 0 and 1", path: "\(variablePath).lowerBound"))
                }
                if let upper = program.upperBounds[index], upper < 0 || upper > 1 {
                    diagnostics.append(error("lp.binary.upperBound", "binary variable '\(name)' upper bound must be between 0 and 1", path: "\(variablePath).upperBound"))
                }
            }
        }

        for constraint in program.constraints where constraint.coefficients.count != variableCount {
            diagnostics.append(error("lp.constraintCoefficients.dimension", "constraint '\(constraint.name)' must contain one coefficient per variable", path: "constraints.\(constraint.name).coefficients"))
        }
        for constraint in program.constraints {
            if !constraint.rhs.isFinite {
                diagnostics.append(error("lp.constraintRHS.finite", "constraint '\(constraint.name)' rhs must be finite", path: "constraints.\(constraint.name).rhs"))
            }
            if !constraint.coefficients.allSatisfy(\.isFinite) {
                diagnostics.append(error("lp.constraintCoefficients.finite", "constraint '\(constraint.name)' coefficients must be finite", path: "constraints.\(constraint.name).coefficients"))
            }
        }

        if diagnostics.isEmpty {
            diagnostics.append(ValidationDiagnostic(
                severity: .info,
                code: "lp.valid",
                message: "Linear program is valid",
                path: nil
            ))
        }
        return diagnostics
    }

    public static func validate(_ program: LinearProgram) throws {
        if let diagnostic = diagnostics(for: program).first(where: { $0.severity == .error }) {
            throw LinearProgramError.invalidModel(diagnostic.message)
        }
    }

    private static func error(_ code: String, _ message: String, path: String?) -> ValidationDiagnostic {
        ValidationDiagnostic(severity: .error, code: code, message: message, path: path)
    }
}

public enum LinearProgramJSON {
    public static func decodeProgram(from data: Data) throws -> LinearProgram {
        let program = try decoder.decode(LinearProgram.self, from: data)
        try validate(program)
        return program
    }

    public static func encodeProgram(_ program: LinearProgram) throws -> Data {
        try encoder.encode(program)
    }

    public static func encodeSolution(_ solution: LinearProgramSolution) throws -> Data {
        try encoder.encode(solution)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        JSONDecoder()
    }

    private static func validate(_ program: LinearProgram) throws {
        try LinearProgramValidator.validate(program)
    }
}

public enum LinearProgramError: Error, CustomStringConvertible {
    case unsupportedMatrixFormat
    case invalidNumericValue(String)
    case unsupportedRelation(String)
    case unsupportedVariableType(String)
    case invalidModel(String)
    case unsupportedModel(String)
    case infeasible
    case unbounded

    public var description: String {
        switch self {
        case .unsupportedMatrixFormat:
            "Unsupported LP matrix format"
        case .invalidNumericValue(let value):
            "Invalid numeric value: \(value)"
        case .unsupportedRelation(let relation):
            "Unsupported constraint relation: \(relation)"
        case .unsupportedVariableType(let type):
            "Unsupported variable type: \(type)"
        case .invalidModel(let detail):
            "Invalid LP model: \(detail)"
        case .unsupportedModel(let detail):
            "Unsupported LP model: \(detail)"
        case .infeasible:
            "Linear program is infeasible"
        case .unbounded:
            "Linear program is unbounded"
        }
    }
}

public enum WinQSBMatrixParser {
    public static func parseLP(from data: Data) throws -> LinearProgram {
        guard let text = String(data: data, encoding: .isoLatin1) else {
            throw LinearProgramError.unsupportedMatrixFormat
        }

        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(clean) }

        guard let metadata = lines.first, metadata.count >= 2, metadata[0] == "LP" else {
            throw LinearProgramError.unsupportedMatrixFormat
        }

        switch metadata[1] {
        case "MatrixFormat":
            return try parseMatrixFormat(lines)
        case "NormalModel":
            return try parseNormalModel(lines)
        default:
            throw LinearProgramError.unsupportedMatrixFormat
        }
    }

    private static func parseMatrixFormat(_ lines: [[String]]) throws -> LinearProgram {
        guard
            let metadata = lines.first,
            metadata.count >= 5,
            metadata[0] == "LP",
            metadata[1] == "MatrixFormat",
            let variableCount = Int(metadata[3]),
            let constraintCount = Int(metadata[4]),
            lines.count >= constraintCount + 3
        else {
            throw LinearProgramError.unsupportedMatrixFormat
        }

        let title = metadata[2]
        let header = lines[1]
        guard header.count >= variableCount + 1 else {
            throw LinearProgramError.unsupportedMatrixFormat
        }

        let variableNames = Array(header[1...(variableCount)])
        let objectiveRow = lines[2]
        guard objectiveRow.count >= variableCount + 1 else {
            throw LinearProgramError.unsupportedMatrixFormat
        }

        let sense: ObjectiveSense
        switch objectiveRow[0].lowercased() {
        case "maximize":
            sense = .maximize
        case "minimize":
            sense = .minimize
        default:
            throw LinearProgramError.unsupportedMatrixFormat
        }

        let objective = try objectiveRow[1...variableCount].map(parseDouble)
        let constraints = try lines[3..<(3 + constraintCount)].map { row in
            guard row.count >= variableCount + 3 else {
                throw LinearProgramError.unsupportedMatrixFormat
            }

            let relationText = row[variableCount + 1]
            let relation: ConstraintRelation
            switch relationText {
            case "<=":
                relation = .lessThanOrEqual
            case ">=":
                relation = .greaterThanOrEqual
            case "=":
                relation = .equal
            default:
                throw LinearProgramError.unsupportedRelation(relationText)
            }

            return LinearConstraint(
                name: row[0],
                coefficients: try row[1...variableCount].map(parseDouble),
                relation: relation,
                rhs: try parseDouble(row[variableCount + 2])
            )
        }

        var lowerBounds = Array(repeating: 0.0, count: variableCount)
        var upperBounds = Array<Double?>(repeating: nil, count: variableCount)
        var variableTypes = Array(repeating: VariableType.continuous, count: variableCount)

        for row in lines.dropFirst(3 + constraintCount) {
            guard let label = row.first else { continue }
            switch label.lowercased() {
            case "lowerbound":
                for index in 0..<variableCount where index + 1 < row.count {
                    lowerBounds[index] = try parseBound(row[index + 1]) ?? 0
                }
            case "upperbound":
                for index in 0..<variableCount where index + 1 < row.count {
                    upperBounds[index] = try parseBound(row[index + 1])
                }
            case "variabletype":
                for index in 0..<variableCount where index + 1 < row.count {
                    variableTypes[index] = try parseVariableType(row[index + 1])
                }
            default:
                continue
            }
        }

        return LinearProgram(
            title: title,
            sense: sense,
            variableNames: variableNames,
            objectiveCoefficients: objective,
            constraints: constraints,
            lowerBounds: lowerBounds,
            upperBounds: upperBounds,
            variableTypes: variableTypes
        )
    }

    private static func parseNormalModel(_ lines: [[String]]) throws -> LinearProgram {
        guard
            let metadata = lines.first,
            metadata.count >= 5,
            metadata[0] == "LP",
            metadata[1] == "NormalModel",
            let variableCount = Int(metadata[3]),
            let constraintCount = Int(metadata[4]),
            lines.count >= constraintCount + 3
        else {
            throw LinearProgramError.unsupportedMatrixFormat
        }

        let title = metadata[2]
        let objectiveRow = lines[2]
        guard objectiveRow.count >= 2 else {
            throw LinearProgramError.unsupportedMatrixFormat
        }

        let sense: ObjectiveSense
        switch objectiveRow[0].lowercased() {
        case "maximize":
            sense = .maximize
        case "minimize":
            sense = .minimize
        default:
            throw LinearProgramError.unsupportedMatrixFormat
        }

        let variableNames = try normalModelVariableNames(lines: lines, variableCount: variableCount, constraintCount: constraintCount)
        let objective = try coefficients(for: parseLinearExpression(objectiveRow[1]), variableNames: variableNames)
        let constraints = try lines[3..<(3 + constraintCount)].map { row in
            guard row.count >= 2 else {
                throw LinearProgramError.unsupportedMatrixFormat
            }
            let parsed = try parseConstraintExpression(row[1])
            return LinearConstraint(
                name: row[0],
                coefficients: try coefficients(for: parsed.coefficients, variableNames: variableNames),
                relation: parsed.relation,
                rhs: parsed.rhs
            )
        }

        var lowerBounds = Array(repeating: 0.0, count: variableCount)
        var upperBounds = Array<Double?>(repeating: nil, count: variableCount)
        var variableTypes = Array(repeating: VariableType.continuous, count: variableCount)
        let variableIndexByName = Dictionary(uniqueKeysWithValues: variableNames.enumerated().map { ($1, $0) })

        for row in lines.dropFirst(3 + constraintCount) {
            guard let label = row.first, !label.isEmpty else { continue }
            let normalizedLabel = label.lowercased()
            if normalizedLabel == "integer:" || normalizedLabel == "binary:" || normalizedLabel == "unrestricted:" {
                let type: VariableType? = normalizedLabel == "integer:" ? .integer : normalizedLabel == "binary:" ? .binary : nil
                guard let type else { continue }
                for name in variableList(from: Array(row.dropFirst())) {
                    if let index = variableIndexByName[name] {
                        variableTypes[index] = type
                    }
                }
            } else if let index = variableIndexByName[label], row.count >= 2 {
                let bounds = try parseNormalBounds(row[1])
                lowerBounds[index] = bounds.lower
                upperBounds[index] = bounds.upper
            }
        }

        for index in 0..<variableCount where variableTypes[index] == .binary {
            upperBounds[index] = min(upperBounds[index] ?? 1, 1)
        }

        return LinearProgram(
            title: title,
            sense: sense,
            variableNames: variableNames,
            objectiveCoefficients: objective,
            constraints: constraints,
            lowerBounds: lowerBounds,
            upperBounds: upperBounds,
            variableTypes: variableTypes
        )
    }

    private static func clean(_ value: Substring) -> String {
        String(value).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseDouble(_ value: String) throws -> Double {
        guard let double = Double(value) else {
            throw LinearProgramError.invalidNumericValue(value)
        }
        return double
    }

    private static func parseBound(_ value: String) throws -> Double? {
        if value.lowercased() == "m" {
            return nil
        }
        return try parseDouble(value)
    }

    private static func parseVariableType(_ value: String) throws -> VariableType {
        switch value.lowercased() {
        case "continuous":
            .continuous
        case "integer":
            .integer
        case "binary":
            .binary
        default:
            throw LinearProgramError.unsupportedVariableType(value)
        }
    }

    private static func normalModelVariableNames(
        lines: [[String]],
        variableCount: Int,
        constraintCount: Int
    ) throws -> [String] {
        var names: [String] = []
        var seen: Set<String> = []

        func append(_ name: String) {
            guard !name.isEmpty, !seen.contains(name) else { return }
            seen.insert(name)
            names.append(name)
        }

        for row in lines.dropFirst(3 + constraintCount) {
            guard let label = row.first, !label.isEmpty else { continue }
            switch label.lowercased() {
            case "integer:", "binary:", "unrestricted:":
                for name in variableList(from: Array(row.dropFirst())) {
                    append(name)
                }
            default:
                if row.count >= 2, row[1].contains(">") || row[1].contains("<") || row[1].contains("=") {
                    append(label)
                }
            }
        }

        if lines.count > 2, lines[2].count >= 2 {
            for name in try parseLinearExpression(lines[2][1]).keys {
                append(name)
            }
        }

        for row in lines[3..<(3 + constraintCount)] where row.count >= 2 {
            for name in try parseConstraintExpression(row[1]).coefficients.keys {
                append(name)
            }
        }

        guard names.count == variableCount else {
            throw LinearProgramError.unsupportedModel("NormalModel variable count mismatch")
        }
        return names
    }

    private static func parseConstraintExpression(_ expression: String) throws -> (
        coefficients: [String: Double],
        relation: ConstraintRelation,
        rhs: Double
    ) {
        let relationText: String
        if expression.contains("<=") {
            relationText = "<="
        } else if expression.contains(">=") {
            relationText = ">="
        } else if expression.contains("=") {
            relationText = "="
        } else {
            throw LinearProgramError.unsupportedMatrixFormat
        }

        let parts = expression.components(separatedBy: relationText)
        guard parts.count == 2 else {
            throw LinearProgramError.unsupportedMatrixFormat
        }

        let relation: ConstraintRelation
        switch relationText {
        case "<=":
            relation = .lessThanOrEqual
        case ">=":
            relation = .greaterThanOrEqual
        case "=":
            relation = .equal
        default:
            throw LinearProgramError.unsupportedRelation(relationText)
        }

        return (
            coefficients: try parseLinearExpression(parts[0]),
            relation: relation,
            rhs: try parseDouble(parts[1].trimmingCharacters(in: .whitespacesAndNewlines))
        )
    }

    private static func parseLinearExpression(_ expression: String) throws -> [String: Double] {
        let compact = expression
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "+-")
        let terms = compact.split(separator: "+").map(String.init).filter { !$0.isEmpty }
        var coefficients: [String: Double] = [:]

        for term in terms {
            let split = term.firstIndex { $0.isLetter || $0 == "_" }
            guard let split else {
                throw LinearProgramError.unsupportedMatrixFormat
            }

            let coefficientText = String(term[..<split])
            let variableName = String(term[split...])
            let coefficient: Double
            switch coefficientText {
            case "", "+":
                coefficient = 1
            case "-":
                coefficient = -1
            default:
                coefficient = try parseDouble(coefficientText)
            }
            coefficients[variableName, default: 0] += coefficient
        }

        return coefficients
    }

    private static func coefficients(for values: [String: Double], variableNames: [String]) throws -> [Double] {
        let knownNames = Set(variableNames)
        let unknownNames = Set(values.keys).subtracting(knownNames)
        guard unknownNames.isEmpty else {
            throw LinearProgramError.unsupportedModel("Unknown variables: \(unknownNames.sorted().joined(separator: ", "))")
        }
        return variableNames.map { values[$0] ?? 0 }
    }

    private static func parseNormalBounds(_ text: String) throws -> (lower: Double, upper: Double?) {
        var lower = 0.0
        var upper: Double?
        let parts = text.split(separator: ",").map { clean($0) }
        for part in parts {
            if part.hasPrefix(">=") {
                lower = try parseBound(String(part.dropFirst(2))) ?? 0
            } else if part.hasPrefix("<=") {
                upper = try parseBound(String(part.dropFirst(2)))
            }
        }
        return (lower, upper)
    }

    private static func variableList(from values: [String]) -> [String] {
        values
            .flatMap { $0.split { $0 == "," || $0 == " " || $0 == "\t" } }
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

public enum SimplexSolver {
    public static func solve(_ program: LinearProgram) throws -> LinearProgramSolution {
        let variableCount = program.variableNames.count
        guard program.lowerBounds.count == variableCount,
              program.upperBounds.count == variableCount,
              program.variableTypes.count == variableCount
        else {
            throw LinearProgramError.unsupportedModel("Variable metadata does not match variable count")
        }

        var constraints = program.constraints
        for index in 0..<variableCount {
            let name = program.variableNames[index]
            let lower = program.lowerBounds[index]
            if lower < -1e-9 {
                throw LinearProgramError.unsupportedModel("Negative lower bounds require variable substitution")
            }
            if lower > 1e-9 {
                constraints.append(boundConstraint(name: "\(name)_lower", variableCount: variableCount, index: index, relation: .greaterThanOrEqual, rhs: lower))
            }
            if let upper = program.upperBounds[index] {
                constraints.append(boundConstraint(name: "\(name)_upper", variableCount: variableCount, index: index, relation: .lessThanOrEqual, rhs: upper))
            }
            if program.variableTypes[index] == .binary {
                constraints.append(boundConstraint(name: "\(name)_binary_upper", variableCount: variableCount, index: index, relation: .lessThanOrEqual, rhs: 1))
            }
        }

        let canonicalObjective = program.sense == .maximize
            ? program.objectiveCoefficients
            : program.objectiveCoefficients.map { -$0 }

        let result = try solveCanonicalMaximization(
            variableCount: variableCount,
            objectiveCoefficients: canonicalObjective,
            constraints: constraints
        )

        let objectiveValue = program.sense == .maximize ? result.objectiveValue : -result.objectiveValue
        let values = Dictionary(uniqueKeysWithValues: program.variableNames.enumerated().map { index, name in
            (name, result.variableValues[index])
        })

        return LinearProgramSolution(objectiveValue: objectiveValue, variableValues: values)
    }

    private struct CanonicalSolution {
        let objectiveValue: Double
        let variableValues: [Double]
    }

    private enum TableauColumn {
        case decision(Int)
        case slack
        case artificial
    }

    private static func boundConstraint(
        name: String,
        variableCount: Int,
        index: Int,
        relation: ConstraintRelation,
        rhs: Double
    ) -> LinearConstraint {
        var coefficients = Array(repeating: 0.0, count: variableCount)
        coefficients[index] = 1
        return LinearConstraint(name: name, coefficients: coefficients, relation: relation, rhs: rhs)
    }

    private static func solveCanonicalMaximization(
        variableCount: Int,
        objectiveCoefficients: [Double],
        constraints: [LinearConstraint]
    ) throws -> CanonicalSolution {
        var normalizedConstraints: [LinearConstraint] = []
        for constraint in constraints {
            guard constraint.coefficients.count == variableCount else {
                throw LinearProgramError.unsupportedModel("Constraint coefficient count does not match variable count")
            }
            normalizedConstraints.append(normalized(constraint))
        }

        let constraintCount = normalizedConstraints.count
        var columns: [TableauColumn] = (0..<variableCount).map(TableauColumn.decision)
        var basis = Array(repeating: -1, count: constraintCount)
        var artificialColumns: [Int] = []
        var rowAuxiliaryColumns = Array(repeating: [(column: Int, coefficient: Double)](), count: constraintCount)

        for (row, constraint) in normalizedConstraints.enumerated() {
            switch constraint.relation {
            case .lessThanOrEqual:
                columns.append(.slack)
                basis[row] = columns.count - 1
                rowAuxiliaryColumns[row].append((columns.count - 1, 1))
            case .greaterThanOrEqual:
                columns.append(.slack)
                rowAuxiliaryColumns[row].append((columns.count - 1, -1))
                columns.append(.artificial)
                basis[row] = columns.count - 1
                artificialColumns.append(columns.count - 1)
                rowAuxiliaryColumns[row].append((columns.count - 1, 1))
            case .equal:
                columns.append(.artificial)
                basis[row] = columns.count - 1
                artificialColumns.append(columns.count - 1)
                rowAuxiliaryColumns[row].append((columns.count - 1, 1))
            }
        }

        let width = columns.count + 1
        let rhsColumn = width - 1
        var tableau = Array(
            repeating: Array(repeating: 0.0, count: width),
            count: constraintCount + 1
        )

        for (rowIndex, constraint) in normalizedConstraints.enumerated() {
            for column in 0..<variableCount {
                tableau[rowIndex][column] = constraint.coefficients[column]
            }
            for entry in rowAuxiliaryColumns[rowIndex] {
                tableau[rowIndex][entry.column] = entry.coefficient
            }
            tableau[rowIndex][rhsColumn] = constraint.rhs
        }

        let objectiveRow = constraintCount
        if !artificialColumns.isEmpty {
            setObjectiveRow(&tableau, objective: phaseOneObjective(width: width, artificialColumns: artificialColumns), basis: basis)
            debugTableau(tableau, label: "phase-1-start", basis: basis)
            try optimize(&tableau, basis: &basis, constraintCount: constraintCount, rhsColumn: rhsColumn)
            debugTableau(tableau, label: "phase-1-end", basis: basis)
            if tableau[objectiveRow][rhsColumn] < -1e-8 {
                throw LinearProgramError.infeasible
            }
        }

        var objective = Array(repeating: 0.0, count: width)
        for column in 0..<variableCount {
            objective[column] = objectiveCoefficients[column]
        }
        setObjectiveRow(&tableau, objective: objective, basis: basis)
        debugTableau(tableau, label: "phase-2-start", basis: basis)
        try optimize(
            &tableau,
            basis: &basis,
            constraintCount: constraintCount,
            rhsColumn: rhsColumn,
            forbiddenEnteringColumns: Set(artificialColumns)
        )
        debugTableau(tableau, label: "phase-2-end", basis: basis)

        var values = Array(repeating: 0.0, count: variableCount)
        for column in 0..<variableCount {
            if let row = basicVariableRow(in: tableau, column: column, constraintCount: constraintCount) {
                values[column] = tableau[row][rhsColumn]
            }
        }

        return CanonicalSolution(objectiveValue: tableau[objectiveRow][rhsColumn], variableValues: values)
    }

    private static func normalized(_ constraint: LinearConstraint) -> LinearConstraint {
        guard constraint.rhs < -1e-9 else {
            return constraint
        }

        let relation: ConstraintRelation
        switch constraint.relation {
        case .lessThanOrEqual:
            relation = .greaterThanOrEqual
        case .greaterThanOrEqual:
            relation = .lessThanOrEqual
        case .equal:
            relation = .equal
        }

        return LinearConstraint(
            name: constraint.name,
            coefficients: constraint.coefficients.map { -$0 },
            relation: relation,
            rhs: -constraint.rhs
        )
    }

    private static func phaseOneObjective(width: Int, artificialColumns: [Int]) -> [Double] {
        var objective = Array(repeating: 0.0, count: width)
        for column in artificialColumns {
            objective[column] = -1
        }
        return objective
    }

    private static func setObjectiveRow(_ tableau: inout [[Double]], objective: [Double], basis: [Int]) {
        let objectiveRow = tableau.count - 1
        for column in tableau[objectiveRow].indices {
            tableau[objectiveRow][column] = column < objective.count ? -objective[column] : 0
        }

        for row in 0..<basis.count {
            let basisColumn = basis[row]
            let coefficient = basisColumn < objective.count ? objective[basisColumn] : 0
            guard abs(coefficient) > 1e-12 else { continue }
            for column in tableau[objectiveRow].indices {
                tableau[objectiveRow][column] += coefficient * tableau[row][column]
            }
        }
    }

    private static func optimize(
        _ tableau: inout [[Double]],
        basis: inout [Int],
        constraintCount: Int,
        rhsColumn: Int,
        forbiddenEnteringColumns: Set<Int> = []
    ) throws {
        while let enteringColumn = mostNegativeColumn(
            in: tableau[constraintCount].dropLast(),
            forbiddenColumns: forbiddenEnteringColumns
        ) {
            var leavingRow: Int?
            var bestRatio = Double.infinity

            for row in 0..<constraintCount {
                let coefficient = tableau[row][enteringColumn]
                guard coefficient > 1e-9 else { continue }
                let ratio = tableau[row][rhsColumn] / coefficient
                if ratio < bestRatio - 1e-12 {
                    bestRatio = ratio
                    leavingRow = row
                }
            }

            guard let pivotRow = leavingRow else {
                throw LinearProgramError.unbounded
            }

            pivot(&tableau, row: pivotRow, column: enteringColumn)
            basis[pivotRow] = enteringColumn
        }
    }

    private static func debugTableau(_ tableau: [[Double]], label: String, basis: [Int]) {
        guard ProcessInfo.processInfo.environment["QSB_DEBUG_TABLEAU"] == "1" else {
            return
        }
        fputs("\n\(label) basis=\(basis)\n", stderr)
        for row in tableau {
            fputs(row.map { String(format: "%9.3f", $0) }.joined(separator: " ") + "\n", stderr)
        }
    }
}

public enum IntegerLinearProgramSolver {
    public static func solve(_ program: LinearProgram, maxNodes: Int = 10_000) throws -> LinearProgramSolution {
        let integerIndexes = program.variableTypes.enumerated().compactMap { index, type in
            type == .integer || type == .binary ? index : nil
        }
        guard !integerIndexes.isEmpty else {
            return try SimplexSolver.solve(program)
        }

        var best: LinearProgramSolution?
        var nodesVisited = 0

        func search(_ current: LinearProgram) throws {
            nodesVisited += 1
            guard nodesVisited <= maxNodes else {
                throw LinearProgramError.unsupportedModel("Branch-and-bound node limit exceeded")
            }

            let relaxation: LinearProgramSolution
            do {
                relaxation = try SimplexSolver.solve(current)
            } catch LinearProgramError.infeasible {
                return
            }

            if let incumbent = best {
                switch program.sense {
                case .maximize where relaxation.objectiveValue <= incumbent.objectiveValue + 1e-8:
                    return
                case .minimize where relaxation.objectiveValue >= incumbent.objectiveValue - 1e-8:
                    return
                default:
                    break
                }
            }

            if let heuristic = roundedFeasibleSolution(from: relaxation, program: program, integerIndexes: integerIndexes) {
                best = better(heuristic, than: best, sense: program.sense)
            }

            guard let branchIndex = firstFractionalVariable(in: relaxation, program: program, integerIndexes: integerIndexes) else {
                best = better(relaxation, than: best, sense: program.sense)
                return
            }

            let variableName = program.variableNames[branchIndex]
            let value = relaxation.variableValues[variableName] ?? 0
            let floorValue = floor(value)
            let ceilValue = ceil(value)

            let lowerBranch = addingBranchConstraint(
                to: current,
                variableIndex: branchIndex,
                relation: .lessThanOrEqual,
                rhs: floorValue
            )

            let upperBranch = addingBranchConstraint(
                to: current,
                variableIndex: branchIndex,
                relation: .greaterThanOrEqual,
                rhs: ceilValue
            )

            switch program.sense {
            case .maximize:
                try search(lowerBranch)
                try search(upperBranch)
            case .minimize:
                try search(upperBranch)
                try search(lowerBranch)
            }
        }

        try search(program)

        guard let best else {
            throw LinearProgramError.infeasible
        }
        return best
    }

    private static func firstFractionalVariable(
        in solution: LinearProgramSolution,
        program: LinearProgram,
        integerIndexes: [Int]
    ) -> Int? {
        for index in integerIndexes {
            let value = solution.variableValues[program.variableNames[index]] ?? 0
            if abs(value - value.rounded()) > 1e-8 {
                return index
            }
        }
        return nil
    }

    private static func better(
        _ candidate: LinearProgramSolution,
        than incumbent: LinearProgramSolution?,
        sense: ObjectiveSense
    ) -> LinearProgramSolution {
        guard let incumbent else {
            return candidate
        }

        switch sense {
        case .maximize:
            return candidate.objectiveValue > incumbent.objectiveValue ? candidate : incumbent
        case .minimize:
            return candidate.objectiveValue < incumbent.objectiveValue ? candidate : incumbent
        }
    }

    private static func roundedFeasibleSolution(
        from relaxation: LinearProgramSolution,
        program: LinearProgram,
        integerIndexes: [Int]
    ) -> LinearProgramSolution? {
        var values = relaxation.variableValues

        for index in integerIndexes {
            let name = program.variableNames[index]
            let value = values[name] ?? 0
            switch program.variableTypes[index] {
            case .binary:
                values[name] = min(1, max(0, value.rounded()))
            case .integer:
                values[name] = program.sense == .maximize ? floor(value) : ceil(value)
            case .continuous:
                break
            }
        }

        guard isFeasible(values: values, program: program, integerIndexes: integerIndexes) else {
            return nil
        }

        let objective = program.variableNames.enumerated().reduce(0.0) { partial, element in
            partial + program.objectiveCoefficients[element.offset] * (values[element.element] ?? 0)
        }
        return LinearProgramSolution(objectiveValue: objective, variableValues: values)
    }

    private static func isFeasible(
        values: [String: Double],
        program: LinearProgram,
        integerIndexes: [Int]
    ) -> Bool {
        for (index, name) in program.variableNames.enumerated() {
            let value = values[name] ?? 0
            if value < program.lowerBounds[index] - 1e-8 {
                return false
            }
            if let upper = program.upperBounds[index], value > upper + 1e-8 {
                return false
            }
        }

        for index in integerIndexes {
            let value = values[program.variableNames[index]] ?? 0
            if abs(value - value.rounded()) > 1e-8 {
                return false
            }
            if program.variableTypes[index] == .binary && (value < -1e-8 || value > 1 + 1e-8) {
                return false
            }
        }

        for constraint in program.constraints {
            let lhs = program.variableNames.enumerated().reduce(0.0) { partial, element in
                partial + constraint.coefficients[element.offset] * (values[element.element] ?? 0)
            }
            switch constraint.relation {
            case .lessThanOrEqual where lhs > constraint.rhs + 1e-8:
                return false
            case .greaterThanOrEqual where lhs < constraint.rhs - 1e-8:
                return false
            case .equal where abs(lhs - constraint.rhs) > 1e-8:
                return false
            default:
                break
            }
        }

        return true
    }

    private static func addingBranchConstraint(
        to program: LinearProgram,
        variableIndex: Int,
        relation: ConstraintRelation,
        rhs: Double
    ) -> LinearProgram {
        var coefficients = Array(repeating: 0.0, count: program.variableNames.count)
        coefficients[variableIndex] = 1
        let constraint = LinearConstraint(
            name: "\(program.variableNames[variableIndex])_branch_\(program.constraints.count)",
            coefficients: coefficients,
            relation: relation,
            rhs: rhs
        )
        return LinearProgram(
            title: program.title,
            sense: program.sense,
            variableNames: program.variableNames,
            objectiveCoefficients: program.objectiveCoefficients,
            constraints: program.constraints + [constraint],
            lowerBounds: program.lowerBounds,
            upperBounds: program.upperBounds,
            variableTypes: program.variableTypes
        )
    }
}

private func mostNegativeColumn(in row: ArraySlice<Double>, forbiddenColumns: Set<Int> = []) -> Int? {
    var selected: Int?
    var selectedValue = -1e-9
    for (index, value) in row.enumerated() where value < selectedValue {
        guard !forbiddenColumns.contains(index) else {
            continue
        }
        selected = index
        selectedValue = value
    }
    return selected
}

private func pivot(_ tableau: inout [[Double]], row: Int, column: Int) {
    let pivotValue = tableau[row][column]
    for index in tableau[row].indices {
        tableau[row][index] /= pivotValue
    }

    for targetRow in tableau.indices where targetRow != row {
        let factor = tableau[targetRow][column]
        guard abs(factor) > 1e-12 else { continue }
        for index in tableau[targetRow].indices {
            tableau[targetRow][index] -= factor * tableau[row][index]
        }
    }
}

private func basicVariableRow(
    in tableau: [[Double]],
    column: Int,
    constraintCount: Int
) -> Int? {
    var oneRow: Int?
    for row in 0..<constraintCount {
        let value = tableau[row][column]
        if abs(value - 1) < 1e-8 {
            if oneRow != nil {
                return nil
            }
            oneRow = row
        } else if abs(value) > 1e-8 {
            return nil
        }
    }
    return oneRow
}
