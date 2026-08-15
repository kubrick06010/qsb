import Foundation

public enum DecisionAnalysisProblemKind: String, Codable, CaseIterable, Sendable {
    case payoff
    case bayesian
    case decisionTree
    case zeroSumGame
}

public enum DecisionAnalysisModelEnvelope: Codable, Equatable, Sendable {
    case payoff(DecisionPayoffProblem)
    case bayesian(BayesianAnalysisProblem)
    case decisionTree(DecisionTree)
    case zeroSumGame(ZeroSumGame)

    private enum Keys: String, CodingKey { case kind, model }

    public var kind: DecisionAnalysisProblemKind {
        switch self {
        case .payoff: .payoff
        case .bayesian: .bayesian
        case .decisionTree: .decisionTree
        case .zeroSumGame: .zeroSumGame
        }
    }

    public var title: String {
        switch self {
        case .payoff(let value): value.title
        case .bayesian(let value): value.title
        case .decisionTree(let value): value.title
        case .zeroSumGame(let value): value.title
        }
    }

    public init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: Keys.self)
        switch try box.decode(DecisionAnalysisProblemKind.self, forKey: .kind) {
        case .payoff: self = .payoff(try box.decode(DecisionPayoffProblem.self, forKey: .model))
        case .bayesian: self = .bayesian(try box.decode(BayesianAnalysisProblem.self, forKey: .model))
        case .decisionTree: self = .decisionTree(try box.decode(DecisionTree.self, forKey: .model))
        case .zeroSumGame: self = .zeroSumGame(try box.decode(ZeroSumGame.self, forKey: .model))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var box = encoder.container(keyedBy: Keys.self)
        try box.encode(kind, forKey: .kind)
        switch self {
        case .payoff(let value): try box.encode(value, forKey: .model)
        case .bayesian(let value): try box.encode(value, forKey: .model)
        case .decisionTree(let value): try box.encode(value, forKey: .model)
        case .zeroSumGame(let value): try box.encode(value, forKey: .model)
        }
    }
}

public enum DecisionAnalysisSolutionEnvelope: Codable, Equatable, Sendable {
    case payoff(DecisionPayoffSolution)
    case bayesian(BayesianAnalysisSolution)
    case decisionTree(DecisionTreeSolution)
    case zeroSumGame(ZeroSumGameSolution)

    private enum Keys: String, CodingKey { case kind, solution }

    public var kind: DecisionAnalysisProblemKind {
        switch self {
        case .payoff: .payoff
        case .bayesian: .bayesian
        case .decisionTree: .decisionTree
        case .zeroSumGame: .zeroSumGame
        }
    }

    public init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: Keys.self)
        switch try box.decode(DecisionAnalysisProblemKind.self, forKey: .kind) {
        case .payoff: self = .payoff(try box.decode(DecisionPayoffSolution.self, forKey: .solution))
        case .bayesian: self = .bayesian(try box.decode(BayesianAnalysisSolution.self, forKey: .solution))
        case .decisionTree: self = .decisionTree(try box.decode(DecisionTreeSolution.self, forKey: .solution))
        case .zeroSumGame: self = .zeroSumGame(try box.decode(ZeroSumGameSolution.self, forKey: .solution))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var box = encoder.container(keyedBy: Keys.self)
        try box.encode(kind, forKey: .kind)
        switch self {
        case .payoff(let value): try box.encode(value, forKey: .solution)
        case .bayesian(let value): try box.encode(value, forKey: .solution)
        case .decisionTree(let value): try box.encode(value, forKey: .solution)
        case .zeroSumGame(let value): try box.encode(value, forKey: .solution)
        }
    }
}

public struct DecisionAnalysisSolutionDocument: Codable, Equatable, Sendable {
    public let backend: SolverRunMetadata
    public let model: DecisionAnalysisModelEnvelope
    public let solution: DecisionAnalysisSolutionEnvelope
}

public struct DecisionAnalysisValidationDocument: Codable, Equatable, Sendable {
    public let kind: DecisionAnalysisProblemKind
    public let backend: SolverBackendKind
    public let isValid: Bool
    public let diagnostics: [ValidationDiagnostic]

    public init(kind: DecisionAnalysisProblemKind, backend: SolverBackendKind, diagnostics: [ValidationDiagnostic]) {
        self.kind = kind
        self.backend = backend
        self.isValid = !diagnostics.contains { $0.severity == .error }
        self.diagnostics = diagnostics
    }
}

public enum DecisionAnalysisValidator {
    public static func diagnostics(for envelope: DecisionAnalysisModelEnvelope) -> [ValidationDiagnostic] {
        switch envelope {
        case .payoff(let value): payoffDiagnostics(value)
        case .bayesian(let value): bayesianDiagnostics(value)
        case .decisionTree(let value): decisionTreeDiagnostics(value)
        case .zeroSumGame(let value): ZeroSumGameValidator.diagnostics(for: value)
        }
    }

    public static func validate(_ envelope: DecisionAnalysisModelEnvelope) throws {
        if let item = diagnostics(for: envelope).first(where: { $0.severity == .error }) {
            throw DecisionAnalysisModelError.invalidModel(item.message)
        }
    }

    private static func payoffDiagnostics(_ value: DecisionPayoffProblem) -> [ValidationDiagnostic] {
        var result = commonProbabilityDiagnostics(states: value.states, priors: value.priorProbabilities)
        if value.decisions.isEmpty || Set(value.decisions).count != value.decisions.count { result.append(error("decisionAnalysis.payoff.decisions.invalid", "Decision names must be nonempty and unique.", "model.decisions")) }
        if value.indicators.isEmpty || Set(value.indicators).count != value.indicators.count { result.append(error("decisionAnalysis.payoff.indicators.invalid", "Indicator names must be nonempty and unique.", "model.indicators")) }
        validateMatrix(value.payoffs, rows: value.decisions.count, columns: value.states.count, code: "decisionAnalysis.payoff.payoffs", path: "model.payoffs", result: &result)
        validateLikelihoods(value.indicatorLikelihoods, rows: value.indicators.count, states: value.states.count, code: "decisionAnalysis.payoff.likelihoods", path: "model.indicatorLikelihoods", result: &result)
        return completed(result, kind: "payoff")
    }

    private static func bayesianDiagnostics(_ value: BayesianAnalysisProblem) -> [ValidationDiagnostic] {
        var result = commonProbabilityDiagnostics(states: value.states, priors: value.priorProbabilities)
        if value.outcomes.isEmpty || Set(value.outcomes).count != value.outcomes.count { result.append(error("decisionAnalysis.bayesian.outcomes.invalid", "Outcome names must be nonempty and unique.", "model.outcomes")) }
        validateLikelihoods(value.likelihoods, rows: value.outcomes.count, states: value.states.count, code: "decisionAnalysis.bayesian.likelihoods", path: "model.likelihoods", result: &result)
        return completed(result, kind: "bayesian")
    }

    private static func decisionTreeDiagnostics(_ tree: DecisionTree) -> [ValidationDiagnostic] {
        var result: [ValidationDiagnostic] = []
        let ids = tree.nodes.map(\.id)
        if tree.nodes.isEmpty { result.append(error("decisionAnalysis.decisionTree.nodes.empty", "Decision tree must contain nodes.", "model.nodes")) }
        if Set(ids).count != ids.count { result.append(error("decisionAnalysis.decisionTree.nodes.duplicate", "Decision tree node IDs must be unique.", "model.nodes")) }
        let idSet = Set(ids)
        if !idSet.contains(tree.rootID) { result.append(error("decisionAnalysis.decisionTree.root.missing", "Root node must exist.", "model.rootID")) }
        for node in tree.nodes {
            if node.childIDs.contains(where: { !idSet.contains($0) }) { result.append(error("decisionAnalysis.decisionTree.child.missing", "Every child ID must reference a node.", "model.nodes.\(node.id).childIDs")) }
            switch node.kind {
            case .terminal where !node.childIDs.isEmpty || node.payoff == nil:
                result.append(error("decisionAnalysis.decisionTree.terminal.invalid", "Terminal nodes require a payoff and no children.", "model.nodes.\(node.id)"))
            case .decision where node.childIDs.isEmpty:
                result.append(error("decisionAnalysis.decisionTree.decision.children", "Decision nodes require children.", "model.nodes.\(node.id).childIDs"))
            case .chance where node.childIDs.isEmpty:
                result.append(error("decisionAnalysis.decisionTree.chance.children", "Chance nodes require children.", "model.nodes.\(node.id).childIDs"))
            default: break
            }
            if let probability = node.probability, (!probability.isFinite || probability < 0 || probability > 1) { result.append(error("decisionAnalysis.decisionTree.probability.invalid", "Node probability must be in [0, 1].", "model.nodes.\(node.id).probability")) }
        }
        for node in tree.nodes where node.kind == .chance {
            let probabilities = node.childIDs.compactMap { id in tree.nodes.first(where: { $0.id == id })?.probability }
            let total = probabilities.reduce(0, +)
            if probabilities.count != node.childIDs.count || total <= 1e-12 {
                result.append(error("decisionAnalysis.decisionTree.probabilities.invalid", "Chance child probabilities must be present and sum to a positive value.", "model.nodes.\(node.id).childIDs"))
            } else if abs(total - 1) > 1e-8 {
                result.append(ValidationDiagnostic(severity: .warning, code: "decisionAnalysis.decisionTree.probabilities.normalized", message: "Chance child probabilities sum to \(total) and will be normalized.", path: "model.nodes.\(node.id).childIDs"))
            }
        }
        return completed(result, kind: "decisionTree")
    }

    private static func commonProbabilityDiagnostics(states: [String], priors: [Double]) -> [ValidationDiagnostic] {
        var result: [ValidationDiagnostic] = []
        if states.isEmpty || Set(states).count != states.count { result.append(error("decisionAnalysis.states.invalid", "State names must be nonempty and unique.", "model.states")) }
        if priors.count != states.count || priors.contains(where: { !$0.isFinite || $0 < 0 || $0 > 1 }) { result.append(error("decisionAnalysis.priors.invalid", "Prior probabilities must match states and be in [0, 1].", "model.priorProbabilities")) }
        if !priors.isEmpty, abs(priors.reduce(0, +) - 1) > 1e-8 { result.append(error("decisionAnalysis.priors.sum", "Prior probabilities must sum to one.", "model.priorProbabilities")) }
        return result
    }

    private static func validateLikelihoods(_ matrix: [[Double]], rows: Int, states: Int, code: String, path: String, result: inout [ValidationDiagnostic]) {
        validateMatrix(matrix, rows: rows, columns: states, code: code, path: path, result: &result)
        if matrix.flatMap({ $0 }).contains(where: { $0 < 0 || $0 > 1 }) { result.append(error("\(code).range", "Likelihoods must be in [0, 1].", path)) }
        if matrix.count == rows, matrix.allSatisfy({ $0.count == states }) {
            for state in 0..<states where abs(matrix.reduce(0) { $0 + $1[state] } - 1) > 1e-8 { result.append(error("\(code).sum", "Likelihoods for each state must sum to one.", "\(path).state.\(state)")) }
        }
    }

    private static func validateMatrix(_ matrix: [[Double]], rows: Int, columns: Int, code: String, path: String, result: inout [ValidationDiagnostic]) {
        if matrix.count != rows || matrix.contains(where: { $0.count != columns }) { result.append(error("\(code).dimensions", "Matrix dimensions do not match model labels.", path)) }
        if matrix.flatMap({ $0 }).contains(where: { !$0.isFinite }) { result.append(error("\(code).finite", "Matrix values must be finite.", path)) }
    }

    private static func completed(_ result: [ValidationDiagnostic], kind: String) -> [ValidationDiagnostic] {
        guard !result.contains(where: { $0.severity == .error }) else { return result }
        return result + [ValidationDiagnostic(severity: .info, code: "decisionAnalysis.\(kind).valid", message: "Decision analysis model is valid")]
    }

    private static func error(_ code: String, _ message: String, _ path: String) -> ValidationDiagnostic { ValidationDiagnostic(severity: .error, code: code, message: message, path: path) }
}

public protocol DecisionAnalysisBackend: Sendable {
    var capabilities: SolverCapabilities { get }
    func validationReport(for model: DecisionAnalysisModelEnvelope) -> ValidationReport
    func solve(_ model: DecisionAnalysisModelEnvelope, options: SolverOptions) throws -> DecisionAnalysisSolutionEnvelope
    func runMetadata(for model: DecisionAnalysisModelEnvelope) -> SolverRunMetadata
}

public extension DecisionAnalysisBackend {
    func validationReport(for model: DecisionAnalysisModelEnvelope) -> ValidationReport { ValidationReport(backend: capabilities.backendKind, diagnostics: DecisionAnalysisValidator.diagnostics(for: model)) }
    func solve(_ model: DecisionAnalysisModelEnvelope) throws -> DecisionAnalysisSolutionEnvelope { try solve(model, options: SolverOptions()) }
    func solutionDocument(for model: DecisionAnalysisModelEnvelope, solution: DecisionAnalysisSolutionEnvelope) -> DecisionAnalysisSolutionDocument { DecisionAnalysisSolutionDocument(backend: runMetadata(for: model), model: model, solution: solution) }
}

public struct NativeEducationalDecisionAnalysisBackend: DecisionAnalysisBackend {
    public init() {}
    public var capabilities: SolverCapabilities { SolverCapabilities(backendKind: .nativeEducational, solves: true, validates: true, exportsStructuredSolution: true, notes: ["Deterministic educational decision-analysis methods."]) }
    public func solve(_ model: DecisionAnalysisModelEnvelope, options _: SolverOptions = SolverOptions()) throws -> DecisionAnalysisSolutionEnvelope {
        try DecisionAnalysisValidator.validate(model)
        switch model {
        case .payoff(let value): return .payoff(try DecisionPayoffSolver.solve(value))
        case .bayesian(let value): return .bayesian(try BayesianAnalysisSolver.solve(value))
        case .decisionTree(let value): return .decisionTree(try DecisionTreeSolver.solve(value))
        case .zeroSumGame(let value): return .zeroSumGame(try ZeroSumGameSolver.solve(value, linearProgrammingBackend: NativeEducationalLinearProgrammingBackend()))
        }
    }
    public func runMetadata(for model: DecisionAnalysisModelEnvelope) -> SolverRunMetadata {
        let algorithm: String
        switch model.kind { case .payoff: algorithm = "expectedValueOfInformation"; case .bayesian: algorithm = "bayesRule"; case .decisionTree: algorithm = "decisionTreeRollback"; case .zeroSumGame: algorithm = "linearProgrammingMixedStrategy" }
        return SolverRunMetadata(backendKind: .nativeEducational, algorithm: algorithm, exactness: .exact, notes: ["Deterministic fixture-scale educational implementation."])
    }
}

public struct ValidateOnlyDecisionAnalysisBackend: DecisionAnalysisBackend {
    public init() {}
    public var capabilities: SolverCapabilities { SolverCapabilities(backendKind: .validateOnly, solves: false, validates: true, exportsStructuredSolution: false) }
    public func solve(_ model: DecisionAnalysisModelEnvelope, options _: SolverOptions = SolverOptions()) throws -> DecisionAnalysisSolutionEnvelope { throw DecisionAnalysisModelError.invalidModel("validateOnly backend does not solve \(model.kind.rawValue)") }
    public func runMetadata(for model: DecisionAnalysisModelEnvelope) -> SolverRunMetadata { SolverRunMetadata(backendKind: .validateOnly, algorithm: "validationOnly", exactness: .exact, notes: ["Validates \(model.kind.rawValue) without solving."]) }
}

public enum DecisionAnalysisBackends {
    public static func backend(for kind: SolverBackendKind) -> (any DecisionAnalysisBackend)? {
        switch kind { case .nativeEducational: NativeEducationalDecisionAnalysisBackend(); case .validateOnly: ValidateOnlyDecisionAnalysisBackend(); case .externalHighPerformance: nil }
    }
}

public enum DecisionAnalysisModelJSON {
    public static func encodeModel(_ value: DecisionAnalysisModelEnvelope) throws -> Data { try encoder.encode(value) }
    public static func decodeModel(from data: Data) throws -> DecisionAnalysisModelEnvelope { try JSONDecoder().decode(DecisionAnalysisModelEnvelope.self, from: data) }
    public static func encodeSolutionDocument(_ value: DecisionAnalysisSolutionDocument) throws -> Data { try encoder.encode(value) }
    public static func decodeSolutionDocument(from data: Data) throws -> DecisionAnalysisSolutionDocument { try JSONDecoder().decode(DecisionAnalysisSolutionDocument.self, from: data) }
    public static func encodeValidation(_ value: DecisionAnalysisValidationDocument) throws -> Data { try encoder.encode(value) }
    private static var encoder: JSONEncoder { NormalizedJSONCoding.encoder() }
}

public extension WinQSBDecisionAnalysisParser {
    static func parseModelEnvelope(from data: Data) throws -> DecisionAnalysisModelEnvelope {
        guard let text = data.legacyLatin1String, let first = text.split(whereSeparator: { $0.isNewline }).first else { throw DecisionAnalysisModelError.unsupportedFormat }
        let fields = first.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard fields.count > 2, fields[0] == "DA" else { throw DecisionAnalysisModelError.unsupportedFormat }
        switch fields[2] { case "PT": return .payoff(try parsePayoff(from: data)); case "BA": return .bayesian(try parseBayesianAnalysis(from: data)); case "DT": return .decisionTree(try parseDecisionTree(from: data)); case "ZS": return .zeroSumGame(try parseZeroSumGame(from: data)); default: throw DecisionAnalysisModelError.unsupportedFormat }
    }
}
