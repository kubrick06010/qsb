import Foundation

public struct GoalObjective: Codable, Equatable, Sendable {
    public let name: String
    public let sense: ObjectiveSense
    public let coefficients: [Double]

    public init(name: String, sense: ObjectiveSense, coefficients: [Double]) {
        self.name = name
        self.sense = sense
        self.coefficients = coefficients
    }
}

public struct GoalProgram: Codable, Equatable, Sendable {
    public let title: String
    public let variableNames: [String]
    public let goals: [GoalObjective]
    public let constraints: [LinearConstraint]
    public let lowerBounds: [Double]
    public let upperBounds: [Double?]
    public let variableTypes: [VariableType]

    public init(title: String, variableNames: [String], goals: [GoalObjective], constraints: [LinearConstraint], lowerBounds: [Double], upperBounds: [Double?], variableTypes: [VariableType]) {
        self.title = title
        self.variableNames = variableNames
        self.goals = goals
        self.constraints = constraints
        self.lowerBounds = lowerBounds
        self.upperBounds = upperBounds
        self.variableTypes = variableTypes
    }

    public func linearProgram(for goal: GoalObjective, additionalConstraints: [LinearConstraint] = []) -> LinearProgram {
        LinearProgram(title: title, sense: goal.sense, variableNames: variableNames, objectiveCoefficients: goal.coefficients, constraints: constraints + additionalConstraints, lowerBounds: lowerBounds, upperBounds: upperBounds, variableTypes: variableTypes)
    }
}

public struct GoalOutcome: Codable, Equatable, Sendable {
    public let priority: Int
    public let name: String
    public let sense: ObjectiveSense
    public let value: Double
}

public struct GoalProgrammingSolution: Codable, Equatable, Sendable {
    public let variableValues: [String: Double]
    public let goalOutcomes: [GoalOutcome]
}

public struct GoalProgrammingSolutionDocument: Codable, Equatable, Sendable {
    public let backend: SolverRunMetadata
    public let model: GoalProgram
    public let solution: GoalProgrammingSolution
}

public struct GoalProgrammingValidationDocument: Codable, Equatable, Sendable {
    public let backend: SolverBackendKind
    public let isValid: Bool
    public let diagnostics: [ValidationDiagnostic]

    public init(backend: SolverBackendKind, diagnostics: [ValidationDiagnostic]) {
        self.backend = backend
        self.isValid = !diagnostics.contains { $0.severity == .error }
        self.diagnostics = diagnostics
    }
}

public enum GoalProgrammingError: Error, CustomStringConvertible {
    case unsupportedFormat
    case inconsistentGoalModels
    case invalidModel(String)

    public var description: String {
        switch self {
        case .unsupportedFormat: "Unsupported goal-programming model format"
        case .inconsistentGoalModels: "Goal rows do not share one consistent feasible model"
        case .invalidModel(let detail): "Invalid goal-programming model: \(detail)"
        }
    }
}

public enum WinQSBGoalProgrammingParser {
    public static func parse(from data: Data) throws -> GoalProgram {
        guard let text = data.legacyLatin1String else { throw GoalProgrammingError.unsupportedFormat }
        let rows = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
        guard let metadata = rows.first, metadata.count >= 6, metadata[0].trimmingCharacters(in: .whitespaces) == "GP",
              let goalCount = Int(metadata[3].trimmingCharacters(in: .whitespaces)), goalCount > 0,
              let variableCount = Int(metadata[4].trimmingCharacters(in: .whitespaces)), variableCount > 0,
              let constraintCount = Int(metadata[5].trimmingCharacters(in: .whitespaces)), constraintCount >= 0,
              rows.count >= goalCount + constraintCount + 2
        else { throw GoalProgrammingError.unsupportedFormat }

        var programs: [LinearProgram] = []
        var names: [String] = []
        for goalIndex in 0..<goalCount {
            let goalRowIndex = 2 + goalIndex
            guard goalRowIndex < rows.count, let parsed = parseGoalLabel(rows[goalRowIndex].first ?? "") else { throw GoalProgrammingError.unsupportedFormat }
            var lpRows: [[String]] = []
            lpRows.append(["LP", metadata[1], metadata[2], String(variableCount), String(constraintCount)])
            lpRows.append(rows[1])
            var objectiveRow = rows[goalRowIndex]
            objectiveRow[0] = parsed.sense == .minimize ? "Minimize" : "Maximize"
            lpRows.append(objectiveRow)
            lpRows.append(contentsOf: rows.dropFirst(2 + goalCount))
            if metadata[1] == "MatrixFormat" {
                for rowIndex in 2..<(3 + constraintCount) {
                    if lpRows[rowIndex].count < variableCount + 3 { lpRows[rowIndex] += Array(repeating: "", count: variableCount + 3 - lpRows[rowIndex].count) }
                    for columnIndex in 1...variableCount where lpRows[rowIndex][columnIndex].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { lpRows[rowIndex][columnIndex] = "0" }
                }
            }
            let lpText = lpRows.map { $0.joined(separator: "\t") }.joined(separator: "\n")
            let program = try WinQSBMatrixParser.parseLP(from: Data(lpText.utf8))
            programs.append(program)
            names.append(parsed.name)
        }
        guard let base = programs.first else { throw GoalProgrammingError.unsupportedFormat }
        for program in programs.dropFirst() where program.variableNames != base.variableNames || program.constraints != base.constraints || program.lowerBounds != base.lowerBounds || program.upperBounds != base.upperBounds || program.variableTypes != base.variableTypes { throw GoalProgrammingError.inconsistentGoalModels }
        let goals = zip(programs.indices, programs).map { index, program in GoalObjective(name: names[index], sense: program.sense, coefficients: program.objectiveCoefficients) }
        return GoalProgram(title: base.title, variableNames: base.variableNames, goals: goals, constraints: base.constraints, lowerBounds: base.lowerBounds, upperBounds: base.upperBounds, variableTypes: base.variableTypes)
    }

    private static func parseGoalLabel(_ raw: String) -> (sense: ObjectiveSense, name: String)? {
        let parts = raw.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0].lowercased() {
        case "min": return (.minimize, parts[1])
        case "max": return (.maximize, parts[1])
        default: return nil
        }
    }
}

public enum GoalProgrammingValidator {
    public static func diagnostics(for model: GoalProgram) -> [ValidationDiagnostic] {
        var result = LinearProgramValidator.diagnostics(for: model.linearProgram(for: model.goals.first ?? GoalObjective(name: "placeholder", sense: .minimize, coefficients: Array(repeating: 0, count: model.variableNames.count))))
            .filter { $0.code != "lp.valid" }
        if model.goals.isEmpty { result.append(error("goals.empty", "At least one prioritized goal is required.", "goals")) }
        if Set(model.goals.map(\.name)).count != model.goals.count { result.append(error("goals.duplicate", "Goal names must be unique.", "goals")) }
        for (index, goal) in model.goals.enumerated() {
            if goal.name.isEmpty { result.append(error("goal.name", "Goal names must not be empty.", "goals.\(index).name")) }
            if goal.coefficients.count != model.variableNames.count { result.append(error("goal.dimension", "Goal coefficients must match variable count.", "goals.\(index).coefficients")) }
            if goal.coefficients.contains(where: { !$0.isFinite }) { result.append(error("goal.finite", "Goal coefficients must be finite.", "goals.\(index).coefficients")) }
        }
        guard !result.contains(where: { $0.severity == .error }) else { return result }
        return [ValidationDiagnostic(severity: .info, code: "goalProgramming.valid", message: "Goal program is valid")]
    }

    public static func validate(_ model: GoalProgram) throws {
        if let item = diagnostics(for: model).first(where: { $0.severity == .error }) { throw GoalProgrammingError.invalidModel(item.message) }
    }

    private static func error(_ suffix: String, _ message: String, _ path: String) -> ValidationDiagnostic { ValidationDiagnostic(severity: .error, code: "goalProgramming.\(suffix)", message: message, path: path) }
}

public enum GoalProgrammingSolver {
    public static func solve(_ model: GoalProgram, linearProgrammingBackend: any LinearProgrammingBackend = NativeEducationalLinearProgrammingBackend(), options: SolverOptions = SolverOptions()) throws -> GoalProgrammingSolution {
        try GoalProgrammingValidator.validate(model)
        let solvingTypes = presolvedVariableTypes(model)
        let mode: LinearProgramSolveMode = solvingTypes.contains(where: { $0 != .continuous }) ? .integer : .continuous
        var fixedGoals: [LinearConstraint] = []
        var outcomes: [GoalOutcome] = []
        var finalSolution: LinearProgramSolution?
        for (index, goal) in model.goals.enumerated() {
            let source = model.linearProgram(for: goal, additionalConstraints: fixedGoals)
            let program = LinearProgram(title: source.title, sense: source.sense, variableNames: source.variableNames, objectiveCoefficients: source.objectiveCoefficients, constraints: source.constraints, lowerBounds: source.lowerBounds, upperBounds: source.upperBounds, variableTypes: solvingTypes)
            let solution = try solvePriority(program, mode: mode, backend: linearProgrammingBackend, options: options)
            let value = dot(goal.coefficients, model.variableNames.map { solution.variableValues[$0] ?? 0 })
            outcomes.append(GoalOutcome(priority: index + 1, name: goal.name, sense: goal.sense, value: value))
            fixedGoals.append(LinearConstraint(name: "Priority_\(index + 1)_\(goal.name)", coefficients: goal.coefficients, relation: .equal, rhs: value))
            finalSolution = solution
        }
        guard let finalSolution else { throw GoalProgrammingError.invalidModel("No goal was solved") }
        return GoalProgrammingSolution(variableValues: finalSolution.variableValues, goalOutcomes: outcomes)
    }

    private static func dot(_ lhs: [Double], _ rhs: [Double]) -> Double { zip(lhs, rhs).reduce(0) { $0 + $1.0 * $1.1 } }

    private static func solvePriority(_ program: LinearProgram, mode: LinearProgramSolveMode, backend: any LinearProgrammingBackend, options: SolverOptions) throws -> LinearProgramSolution {
        guard mode == .integer else { return try backend.solve(program, mode: .continuous, options: options) }
        let relaxation = try backend.solve(program, mode: .continuous, options: options)
        let integerIndexes = program.variableTypes.indices.filter { program.variableTypes[$0] != .continuous }
        if integerIndexes.allSatisfy({ isInteger(relaxation.variableValues[program.variableNames[$0]] ?? 0) }) { return relaxation }

        var upperBounds = program.upperBounds
        let continuousTypes = Array(repeating: VariableType.continuous, count: program.variableNames.count)
        for index in integerIndexes where upperBounds[index] == nil {
            var objective = Array(repeating: 0.0, count: program.variableNames.count)
            objective[index] = 1
            let boundProgram = LinearProgram(title: program.title, sense: .maximize, variableNames: program.variableNames, objectiveCoefficients: objective, constraints: program.constraints, lowerBounds: program.lowerBounds, upperBounds: upperBounds, variableTypes: continuousTypes)
            let bound: Double
            do {
                bound = try backend.solve(boundProgram, mode: .continuous, options: options).variableValues[program.variableNames[index]] ?? 0
            } catch {
                let modelScale = program.constraints.map { abs($0.rhs) }.max() ?? 1
                bound = max(100, modelScale * 2)
            }
            upperBounds[index] = floor(bound + 1e-8)
        }
        let bounded = LinearProgram(title: program.title, sense: program.sense, variableNames: program.variableNames, objectiveCoefficients: program.objectiveCoefficients, constraints: program.constraints, lowerBounds: program.lowerBounds, upperBounds: upperBounds, variableTypes: program.variableTypes)
        return try backend.solve(bounded, mode: .integer, options: options)
    }

    private static func presolvedVariableTypes(_ model: GoalProgram) -> [VariableType] {
        guard model.constraints.allSatisfy({ constraint in
            constraint.relation == .equal && isInteger(constraint.rhs) && constraint.coefficients.allSatisfy(isInteger)
        }) else { return model.variableTypes }
        return zip(model.variableNames, model.variableTypes).map { name, type in
            guard type == .integer, isDeviationName(name) else { return type }
            return .continuous
        }
    }

    private static func isDeviationName(_ name: String) -> Bool {
        guard let first = name.first, first == "n" || first == "p" else { return false }
        return name.dropFirst().isEmpty == false && name.dropFirst().allSatisfy(\.isNumber)
    }

    private static func isInteger(_ value: Double) -> Bool { value.isFinite && abs(value.rounded() - value) < 1e-8 }
}

public protocol GoalProgrammingBackend: Sendable {
    var capabilities: SolverCapabilities { get }
    func validationReport(for model: GoalProgram) -> ValidationReport
    func solve(_ model: GoalProgram, options: SolverOptions) throws -> GoalProgrammingSolution
    func runMetadata(for model: GoalProgram) -> SolverRunMetadata
}

public extension GoalProgrammingBackend {
    func validationReport(for model: GoalProgram) -> ValidationReport { ValidationReport(backend: capabilities.backendKind, diagnostics: GoalProgrammingValidator.diagnostics(for: model)) }
    func solve(_ model: GoalProgram) throws -> GoalProgrammingSolution { try solve(model, options: SolverOptions()) }
    func solutionDocument(for model: GoalProgram, solution: GoalProgrammingSolution) -> GoalProgrammingSolutionDocument { GoalProgrammingSolutionDocument(backend: runMetadata(for: model), model: model, solution: solution) }
}

public struct NativeEducationalGoalProgrammingBackend: GoalProgrammingBackend {
    public init() {}
    public var capabilities: SolverCapabilities { SolverCapabilities(backendKind: .nativeEducational, solves: true, validates: true, exportsStructuredSolution: true, notes: ["Preemptive lexicographic goal optimization over the shared LP backend."]) }
    public func solve(_ model: GoalProgram, options: SolverOptions = SolverOptions()) throws -> GoalProgrammingSolution { try GoalProgrammingSolver.solve(model, linearProgrammingBackend: NativeEducationalLinearProgrammingBackend(), options: options) }
    public func runMetadata(for model: GoalProgram) -> SolverRunMetadata { SolverRunMetadata(backendKind: .nativeEducational, algorithm: model.variableTypes.contains(where: { $0 != .continuous }) ? "lexicographicIntegerLinearProgramming" : "lexicographicContinuousLinearProgramming", exactness: model.variableTypes.contains(where: { $0 != .continuous }) ? .fixtureScale : .exact, notes: ["Each priority is optimized and fixed before the next goal is solved through LinearProgrammingBackend.", "Integer deviation pairs nN/pN are relaxed only when integral equalities prove their residuals are integral; decision-variable integrality is preserved.", "Fixture-scale integer presolve accepts integral relaxations and derives or supplies finite branch bounds before invoking branch-and-bound."]) }
}

public struct ValidateOnlyGoalProgrammingBackend: GoalProgrammingBackend {
    public init() {}
    public var capabilities: SolverCapabilities { SolverCapabilities(backendKind: .validateOnly, solves: false, validates: true, exportsStructuredSolution: false) }
    public func solve(_ model: GoalProgram, options _: SolverOptions = SolverOptions()) throws -> GoalProgrammingSolution { throw GoalProgrammingError.invalidModel("validateOnly backend does not solve goal programs") }
    public func runMetadata(for _: GoalProgram) -> SolverRunMetadata { SolverRunMetadata(backendKind: .validateOnly, algorithm: "validationOnly", exactness: .exact, notes: ["Validates a goal program without solving."]) }
}

public enum GoalProgrammingBackends {
    public static func backend(for kind: SolverBackendKind) -> (any GoalProgrammingBackend)? { switch kind { case .nativeEducational: NativeEducationalGoalProgrammingBackend(); case .validateOnly: ValidateOnlyGoalProgrammingBackend(); case .externalHighPerformance: nil } }
}

public enum GoalProgrammingJSON {
    public static func encodeModel(_ value: GoalProgram) throws -> Data { try encoder.encode(value) }
    public static func decodeModel(from data: Data) throws -> GoalProgram { try JSONDecoder().decode(GoalProgram.self, from: data) }
    public static func encodeSolution(_ value: GoalProgrammingSolutionDocument) throws -> Data { try encoder.encode(value) }
    public static func decodeSolution(from data: Data) throws -> GoalProgrammingSolutionDocument { try JSONDecoder().decode(GoalProgrammingSolutionDocument.self, from: data) }
    public static func encodeValidation(_ value: GoalProgrammingValidationDocument) throws -> Data { try encoder.encode(value) }
    private static var encoder: JSONEncoder { NormalizedJSONCoding.encoder() }
}
