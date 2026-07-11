import Foundation

public enum SolverBackendKind: String, Codable, CaseIterable, Sendable {
    case nativeEducational
    case validateOnly
    case externalHighPerformance
}

public struct SolverOptions: Codable, Equatable, Sendable {
    public let timeLimitSeconds: Double?
    public let nodeLimit: Int?
    public let tolerance: Double?
    public let randomSeed: Int?
    public let explain: Bool

    public init(
        timeLimitSeconds: Double? = nil,
        nodeLimit: Int? = nil,
        tolerance: Double? = nil,
        randomSeed: Int? = nil,
        explain: Bool = false
    ) {
        self.timeLimitSeconds = timeLimitSeconds
        self.nodeLimit = nodeLimit
        self.tolerance = tolerance
        self.randomSeed = randomSeed
        self.explain = explain
    }
}

public struct SolverCapabilities: Codable, Equatable, Sendable {
    public let backendKind: SolverBackendKind
    public let solves: Bool
    public let validates: Bool
    public let exportsStructuredSolution: Bool
    public let notes: [String]

    public init(
        backendKind: SolverBackendKind,
        solves: Bool,
        validates: Bool,
        exportsStructuredSolution: Bool,
        notes: [String] = []
    ) {
        self.backendKind = backendKind
        self.solves = solves
        self.validates = validates
        self.exportsStructuredSolution = exportsStructuredSolution
        self.notes = notes
    }
}

public enum SolverExactness: String, Codable, Sendable {
    case exact
    case heuristic
    case approximate
    case closedForm
    case fixtureScale
}

public struct SolverRunMetadata: Codable, Equatable, Sendable {
    public let backendKind: SolverBackendKind
    public let algorithm: String
    public let exactness: SolverExactness
    public let notes: [String]

    public init(
        backendKind: SolverBackendKind,
        algorithm: String,
        exactness: SolverExactness,
        notes: [String] = []
    ) {
        self.backendKind = backendKind
        self.algorithm = algorithm
        self.exactness = exactness
        self.notes = notes
    }
}

public struct SolverRequest<Model>: Sendable where Model: Sendable {
    public let model: Model
    public let backend: SolverBackendKind
    public let options: SolverOptions

    public init(
        model: Model,
        backend: SolverBackendKind = .nativeEducational,
        options: SolverOptions = SolverOptions()
    ) {
        self.model = model
        self.backend = backend
        self.options = options
    }
}

public enum ValidationSeverity: String, Codable, Sendable {
    case info
    case warning
    case error
}

public struct ValidationDiagnostic: Codable, Equatable, Sendable {
    public let severity: ValidationSeverity
    public let code: String
    public let message: String
    public let path: String?

    public init(
        severity: ValidationSeverity,
        code: String,
        message: String,
        path: String? = nil
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.path = path
    }
}

public struct ValidationReport: Codable, Equatable, Sendable {
    public let backend: SolverBackendKind
    public let diagnostics: [ValidationDiagnostic]

    public init(
        backend: SolverBackendKind = .validateOnly,
        diagnostics: [ValidationDiagnostic]
    ) {
        self.backend = backend
        self.diagnostics = diagnostics
    }

    public var isValid: Bool {
        !diagnostics.contains { $0.severity == .error }
    }
}
