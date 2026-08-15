import Foundation

public struct MarkovChainModel: Codable, Equatable, Sendable {
    public let title: String
    public let states: [String]
    public let transitionMatrix: [[Double]]
    public let initialProbabilities: [Double]?
    public let stateCosts: [Double]

    public init(title: String, states: [String], transitionMatrix: [[Double]], initialProbabilities: [Double]?, stateCosts: [Double]) {
        self.title = title
        self.states = states
        self.transitionMatrix = transitionMatrix
        self.initialProbabilities = initialProbabilities
        self.stateCosts = stateCosts
    }
}

public struct MarkovAnalysisRequest: Codable, Equatable, Sendable {
    public let model: MarkovChainModel
    public let periods: Int

    public init(model: MarkovChainModel, periods: Int = 10) {
        self.model = model
        self.periods = periods
    }
}

public struct MarkovPeriodResult: Codable, Equatable, Sendable {
    public let period: Int
    public let probabilities: [Double]
    public let expectedCost: Double
}

public struct MarkovAnalysisSolution: Codable, Equatable, Sendable {
    public let stationaryProbabilities: [Double]
    public let stationaryExpectedCost: Double
    public let transientResults: [MarkovPeriodResult]
}

public struct MarkovSolutionDocument: Codable, Equatable, Sendable {
    public let backend: SolverRunMetadata
    public let request: MarkovAnalysisRequest
    public let solution: MarkovAnalysisSolution
}

public struct MarkovValidationDocument: Codable, Equatable, Sendable {
    public let backend: SolverBackendKind
    public let isValid: Bool
    public let diagnostics: [ValidationDiagnostic]

    public init(backend: SolverBackendKind, diagnostics: [ValidationDiagnostic]) {
        self.backend = backend
        self.isValid = !diagnostics.contains { $0.severity == .error }
        self.diagnostics = diagnostics
    }
}

public enum MarkovModelError: Error, CustomStringConvertible {
    case unsupportedFormat
    case invalidModel(String)
    case noUniqueStationaryDistribution

    public var description: String {
        switch self {
        case .unsupportedFormat: "Unsupported Markov model format"
        case .invalidModel(let detail): "Invalid Markov model: \(detail)"
        case .noUniqueStationaryDistribution: "Markov chain does not have a unique stationary distribution"
        }
    }
}

public enum WinQSBMarkovParser {
    public static func parse(from data: Data) throws -> MarkovChainModel {
        guard let text = data.legacyLatin1String else { throw MarkovModelError.unsupportedFormat }
        let rows = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } }
        guard rows.count >= 5, rows[0].count >= 3, rows[0][0] == "MKP",
              let count = Int(rows[0][2]), count > 0, rows[1].count >= count + 1,
              rows.count >= count + 4
        else { throw MarkovModelError.unsupportedFormat }
        let states = Array(rows[1][1...count])
        var matrix: [[Double]] = []
        for index in 0..<count {
            let row = rows[2 + index]
            guard row.count >= count + 1 else { throw MarkovModelError.unsupportedFormat }
            matrix.append(try row[1...count].map { $0.isEmpty ? 0 : try number($0) })
        }
        let initialRow = rows[2 + count]
        let costRow = rows[3 + count]
        guard initialRow.count >= count + 1, costRow.count >= count + 1,
              initialRow[0].lowercased().hasPrefix("initial prob"), costRow[0].lowercased().hasPrefix("state cost")
        else { throw MarkovModelError.unsupportedFormat }
        let initialValues = Array(initialRow[1...count])
        let initial = initialValues.allSatisfy(\.isEmpty) ? nil : try initialValues.map { $0.isEmpty ? 0 : try number($0) }
        let costs = try costRow[1...count].map(number)
        return MarkovChainModel(title: rows[0][1], states: states, transitionMatrix: matrix, initialProbabilities: initial, stateCosts: costs)
    }

    private static func number(_ raw: String) throws -> Double {
        guard let value = Double(raw), value.isFinite else { throw MarkovModelError.invalidModel("Invalid numeric value \(raw)") }
        return value
    }
}

public enum MarkovValidator {
    public static func diagnostics(for request: MarkovAnalysisRequest) -> [ValidationDiagnostic] {
        let model = request.model
        var result: [ValidationDiagnostic] = []
        let count = model.states.count
        if count == 0 { result.append(error("states.empty", "At least one state is required.", "model.states")) }
        if model.states.contains(where: { $0.isEmpty }) { result.append(error("states.name", "State names must not be empty.", "model.states")) }
        if Set(model.states).count != count { result.append(error("states.duplicate", "State names must be unique.", "model.states")) }
        if model.transitionMatrix.count != count || model.transitionMatrix.contains(where: { $0.count != count }) { result.append(error("transition.dimension", "Transition matrix must be square with one row per state.", "model.transitionMatrix")) }
        for (rowIndex, row) in model.transitionMatrix.enumerated() {
            if row.contains(where: { !$0.isFinite || $0 < 0 || $0 > 1 }) { result.append(error("transition.probability", "Transition probabilities must be finite and between zero and one.", "model.transitionMatrix.\(rowIndex)")) }
            if row.count == count, row.allSatisfy(\.isFinite), abs(row.reduce(0, +) - 1) > 1e-8 { result.append(error("transition.rowSum", "Each transition row must sum to one.", "model.transitionMatrix.\(rowIndex)")) }
        }
        if model.stateCosts.count != count { result.append(error("cost.dimension", "State cost count must match state count.", "model.stateCosts")) }
        if model.stateCosts.contains(where: { !$0.isFinite }) { result.append(error("cost.finite", "State costs must be finite.", "model.stateCosts")) }
        if let initial = model.initialProbabilities {
            if initial.count != count { result.append(error("initial.dimension", "Initial probability count must match state count.", "model.initialProbabilities")) }
            if initial.contains(where: { !$0.isFinite || $0 < 0 || $0 > 1 }) { result.append(error("initial.probability", "Initial probabilities must be finite and between zero and one.", "model.initialProbabilities")) }
            if initial.count == count, initial.allSatisfy(\.isFinite), abs(initial.reduce(0, +) - 1) > 1e-8 { result.append(error("initial.sum", "Initial probabilities must sum to one.", "model.initialProbabilities")) }
        }
        if request.periods < 0 { result.append(error("periods.nonnegative", "Analysis periods must be nonnegative.", "periods")) }
        guard !result.contains(where: { $0.severity == .error }) else { return result }
        return [ValidationDiagnostic(severity: .info, code: "markov.valid", message: "Markov analysis request is valid")]
    }

    public static func validate(_ request: MarkovAnalysisRequest) throws {
        if let item = diagnostics(for: request).first(where: { $0.severity == .error }) { throw MarkovModelError.invalidModel(item.message) }
    }

    private static func error(_ suffix: String, _ message: String, _ path: String) -> ValidationDiagnostic {
        ValidationDiagnostic(severity: .error, code: "markov.\(suffix)", message: message, path: path)
    }
}

public enum MarkovSolver {
    public static func solve(_ request: MarkovAnalysisRequest) throws -> MarkovAnalysisSolution {
        try MarkovValidator.validate(request)
        let model = request.model
        let stationary = try stationaryDistribution(matrix: model.transitionMatrix)
        var transient: [MarkovPeriodResult] = []
        if var current = model.initialProbabilities {
            transient.append(MarkovPeriodResult(period: 0, probabilities: current, expectedCost: dot(current, model.stateCosts)))
            if request.periods > 0 {
                for period in 1...request.periods {
                    current = multiply(current, by: model.transitionMatrix)
                    transient.append(MarkovPeriodResult(period: period, probabilities: current, expectedCost: dot(current, model.stateCosts)))
                }
            }
        }
        return MarkovAnalysisSolution(stationaryProbabilities: stationary, stationaryExpectedCost: dot(stationary, model.stateCosts), transientResults: transient)
    }

    private static func stationaryDistribution(matrix: [[Double]]) throws -> [Double] {
        let count = matrix.count
        var augmented = Array(repeating: Array(repeating: 0.0, count: count + 1), count: count)
        for row in 0..<(count - 1) {
            for column in 0..<count { augmented[row][column] = matrix[column][row] - (row == column ? 1 : 0) }
        }
        for column in 0..<count { augmented[count - 1][column] = 1 }
        augmented[count - 1][count] = 1
        for pivot in 0..<count {
            var best = pivot
            for row in pivot..<count where abs(augmented[row][pivot]) > abs(augmented[best][pivot]) { best = row }
            guard abs(augmented[best][pivot]) > 1e-12 else { throw MarkovModelError.noUniqueStationaryDistribution }
            if best != pivot { augmented.swapAt(best, pivot) }
            let divisor = augmented[pivot][pivot]
            for column in pivot...count { augmented[pivot][column] /= divisor }
            for row in 0..<count where row != pivot {
                let factor = augmented[row][pivot]
                for column in pivot...count { augmented[row][column] -= factor * augmented[pivot][column] }
            }
        }
        return augmented.map { abs($0[count]) < 1e-12 ? 0 : $0[count] }
    }

    private static func multiply(_ vector: [Double], by matrix: [[Double]]) -> [Double] {
        matrix.indices.map { column in matrix.indices.reduce(0) { $0 + vector[$1] * matrix[$1][column] } }
    }

    private static func dot(_ lhs: [Double], _ rhs: [Double]) -> Double { zip(lhs, rhs).reduce(0) { $0 + $1.0 * $1.1 } }
}

public protocol MarkovBackend: Sendable {
    var capabilities: SolverCapabilities { get }
    func validationReport(for request: MarkovAnalysisRequest) -> ValidationReport
    func solve(_ request: MarkovAnalysisRequest, options: SolverOptions) throws -> MarkovAnalysisSolution
    func runMetadata(for request: MarkovAnalysisRequest) -> SolverRunMetadata
}

public extension MarkovBackend {
    func validationReport(for request: MarkovAnalysisRequest) -> ValidationReport { ValidationReport(backend: capabilities.backendKind, diagnostics: MarkovValidator.diagnostics(for: request)) }
    func solve(_ request: MarkovAnalysisRequest) throws -> MarkovAnalysisSolution { try solve(request, options: SolverOptions()) }
    func solutionDocument(for request: MarkovAnalysisRequest, solution: MarkovAnalysisSolution) -> MarkovSolutionDocument { MarkovSolutionDocument(backend: runMetadata(for: request), request: request, solution: solution) }
}

public struct NativeEducationalMarkovBackend: MarkovBackend {
    public init() {}
    public var capabilities: SolverCapabilities { SolverCapabilities(backendKind: .nativeEducational, solves: true, validates: true, exportsStructuredSolution: true, notes: ["Finite-state homogeneous Markov chain analysis."]) }
    public func solve(_ request: MarkovAnalysisRequest, options _: SolverOptions = SolverOptions()) throws -> MarkovAnalysisSolution { try MarkovSolver.solve(request) }
    public func runMetadata(for _: MarkovAnalysisRequest) -> SolverRunMetadata { SolverRunMetadata(backendKind: .nativeEducational, algorithm: "stationaryLinearSystemAndForwardPropagation", exactness: .exact, notes: ["Solves pi P = pi with sum(pi)=1; propagates supplied initial probabilities by repeated matrix multiplication."]) }
}

public struct ValidateOnlyMarkovBackend: MarkovBackend {
    public init() {}
    public var capabilities: SolverCapabilities { SolverCapabilities(backendKind: .validateOnly, solves: false, validates: true, exportsStructuredSolution: false) }
    public func solve(_ request: MarkovAnalysisRequest, options _: SolverOptions = SolverOptions()) throws -> MarkovAnalysisSolution { throw MarkovModelError.invalidModel("validateOnly backend does not solve Markov requests") }
    public func runMetadata(for _: MarkovAnalysisRequest) -> SolverRunMetadata { SolverRunMetadata(backendKind: .validateOnly, algorithm: "validationOnly", exactness: .exact, notes: ["Validates a Markov request without solving."]) }
}

public enum MarkovBackends {
    public static func backend(for kind: SolverBackendKind) -> (any MarkovBackend)? {
        switch kind { case .nativeEducational: NativeEducationalMarkovBackend(); case .validateOnly: ValidateOnlyMarkovBackend(); case .externalHighPerformance: nil }
    }
}

public enum MarkovJSON {
    public static func encodeRequest(_ value: MarkovAnalysisRequest) throws -> Data { try encoder.encode(value) }
    public static func decodeRequest(from data: Data) throws -> MarkovAnalysisRequest { try JSONDecoder().decode(MarkovAnalysisRequest.self, from: data) }
    public static func encodeSolution(_ value: MarkovSolutionDocument) throws -> Data { try encoder.encode(value) }
    public static func decodeSolution(from data: Data) throws -> MarkovSolutionDocument { try JSONDecoder().decode(MarkovSolutionDocument.self, from: data) }
    public static func encodeValidation(_ value: MarkovValidationDocument) throws -> Data { try encoder.encode(value) }
    private static var encoder: JSONEncoder { NormalizedJSONCoding.encoder() }
}
