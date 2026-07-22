import Foundation

public enum ForecastingModelKind: String, Codable, Sendable { case timeSeries, regression }
public enum ForecastingMethod: String, Codable, CaseIterable, Sendable {
    case linearTrend, movingAverage, exponentialSmoothing, multiplicativeSeasonalDecomposition, ordinaryLeastSquares
}

public enum ForecastingModelEnvelope: Codable, Equatable, Sendable {
    case timeSeries(TimeSeriesModel)
    case regression(RegressionModel)

    private enum Keys: String, CodingKey { case kind, model }
    public var kind: ForecastingModelKind { switch self { case .timeSeries: .timeSeries; case .regression: .regression } }
    public var title: String { switch self { case .timeSeries(let model): model.title; case .regression(let model): model.title } }

    public init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: Keys.self)
        switch try box.decode(ForecastingModelKind.self, forKey: .kind) {
        case .timeSeries: self = .timeSeries(try box.decode(TimeSeriesModel.self, forKey: .model))
        case .regression: self = .regression(try box.decode(RegressionModel.self, forKey: .model))
        }
    }
    public func encode(to encoder: Encoder) throws {
        var box = encoder.container(keyedBy: Keys.self); try box.encode(kind, forKey: .kind)
        switch self { case .timeSeries(let model): try box.encode(model, forKey: .model); case .regression(let model): try box.encode(model, forKey: .model) }
    }
}

public struct ForecastingRequest: Codable, Equatable, Sendable {
    public let model: ForecastingModelEnvelope
    public let method: ForecastingMethod
    public let periodsAhead: Int
    public let windowSize: Int?
    public let alpha: Double?
    public let seasonLength: Int?

    public init(model: ForecastingModelEnvelope, method: ForecastingMethod, periodsAhead: Int = 1, windowSize: Int? = nil, alpha: Double? = nil, seasonLength: Int? = nil) {
        self.model = model; self.method = method; self.periodsAhead = periodsAhead; self.windowSize = windowSize; self.alpha = alpha; self.seasonLength = seasonLength
    }
}

public enum ForecastingSolutionEnvelope: Codable, Equatable, Sendable {
    case linearTrend(TimeSeriesTrendSolution)
    case movingAverage(TimeSeriesMovingAverageSolution)
    case exponentialSmoothing(TimeSeriesExponentialSmoothingSolution)
    case multiplicativeSeasonalDecomposition(TimeSeriesSeasonalDecompositionSolution)
    case ordinaryLeastSquares(RegressionSolution)

    private enum Keys: String, CodingKey { case method, result }
    public var method: ForecastingMethod {
        switch self { case .linearTrend: .linearTrend; case .movingAverage: .movingAverage; case .exponentialSmoothing: .exponentialSmoothing; case .multiplicativeSeasonalDecomposition: .multiplicativeSeasonalDecomposition; case .ordinaryLeastSquares: .ordinaryLeastSquares }
    }
    public init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: Keys.self)
        switch try box.decode(ForecastingMethod.self, forKey: .method) {
        case .linearTrend: self = .linearTrend(try box.decode(TimeSeriesTrendSolution.self, forKey: .result))
        case .movingAverage: self = .movingAverage(try box.decode(TimeSeriesMovingAverageSolution.self, forKey: .result))
        case .exponentialSmoothing: self = .exponentialSmoothing(try box.decode(TimeSeriesExponentialSmoothingSolution.self, forKey: .result))
        case .multiplicativeSeasonalDecomposition: self = .multiplicativeSeasonalDecomposition(try box.decode(TimeSeriesSeasonalDecompositionSolution.self, forKey: .result))
        case .ordinaryLeastSquares: self = .ordinaryLeastSquares(try box.decode(RegressionSolution.self, forKey: .result))
        }
    }
    public func encode(to encoder: Encoder) throws {
        var box = encoder.container(keyedBy: Keys.self); try box.encode(method, forKey: .method)
        switch self { case .linearTrend(let value): try box.encode(value, forKey: .result); case .movingAverage(let value): try box.encode(value, forKey: .result); case .exponentialSmoothing(let value): try box.encode(value, forKey: .result); case .multiplicativeSeasonalDecomposition(let value): try box.encode(value, forKey: .result); case .ordinaryLeastSquares(let value): try box.encode(value, forKey: .result) }
    }
}

public struct ForecastingSolutionDocument: Codable, Equatable, Sendable {
    public let backend: SolverRunMetadata; public let title: String; public let request: ForecastingRequest; public let solution: ForecastingSolutionEnvelope
}
public struct ForecastingValidationDocument: Codable, Equatable, Sendable {
    public let method: ForecastingMethod; public let backend: SolverBackendKind; public let isValid: Bool; public let diagnostics: [ValidationDiagnostic]
    public init(method: ForecastingMethod, backend: SolverBackendKind, diagnostics: [ValidationDiagnostic]) { self.method = method; self.backend = backend; self.isValid = !diagnostics.contains { $0.severity == .error }; self.diagnostics = diagnostics }
}

public enum ForecastingValidator {
    public static func diagnostics(for request: ForecastingRequest) -> [ValidationDiagnostic] {
        var result: [ValidationDiagnostic] = []
        func error(_ code: String, _ message: String, _ path: String) { result.append(ValidationDiagnostic(severity: .error, code: code, message: message, path: path)) }
        if request.model.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result.append(ValidationDiagnostic(severity: .warning, code: "forecasting.title.empty", message: "Model title is empty.", path: "model.model.title")) }
        if request.periodsAhead <= 0 { error("forecasting.periodsAhead.nonpositive", "Forecast horizon must be positive.", "periodsAhead") }
        switch request.model {
        case .timeSeries(let model):
            if request.method == .ordinaryLeastSquares { error("forecasting.method.modelMismatch", "Ordinary least squares requires a regression model.", "method") }
            if model.valueName.isEmpty { error("forecasting.timeSeries.valueName.empty", "Value name must not be empty.", "model.model.valueName") }
            if model.observations.contains(where: { $0.label.isEmpty || !$0.value.isFinite }) { error("forecasting.timeSeries.observation.invalid", "Observation labels and values must be valid.", "model.model.observations") }
            let count = model.observations.count
            if count < 2 { error("forecasting.timeSeries.observations.insufficient", "At least two observations are required.", "model.model.observations") }
            if request.method == .movingAverage, request.windowSize == nil || request.windowSize! <= 0 || request.windowSize! >= count { error("forecasting.movingAverage.window.invalid", "Window size must be positive and smaller than the observation count.", "windowSize") }
            if request.method == .exponentialSmoothing, request.alpha == nil || !request.alpha!.isFinite || request.alpha! <= 0 || request.alpha! > 1 { error("forecasting.exponentialSmoothing.alpha.invalid", "Alpha must be in (0, 1].", "alpha") }
            if request.method == .multiplicativeSeasonalDecomposition, request.seasonLength == nil || request.seasonLength! <= 1 || count < request.seasonLength! * 2 { error("forecasting.seasonal.seasonLength.invalid", "Season length must exceed one and have at least two complete seasons.", "seasonLength") }
        case .regression(let model):
            if request.method != .ordinaryLeastSquares { error("forecasting.method.modelMismatch", "Time-series methods require a time-series model.", "method") }
            if model.dependentVariable.isEmpty || model.independentVariables.isEmpty { error("forecasting.regression.variables.invalid", "Dependent and independent variable names are required.", "model.model") }
            if Set(model.independentVariables).count != model.independentVariables.count { error("forecasting.regression.variables.duplicate", "Independent variable names must be unique.", "model.model.independentVariables") }
            if model.observations.count <= model.independentVariables.count { error("forecasting.regression.observations.insufficient", "Regression requires more observations than independent variables.", "model.model.observations") }
            if model.observations.contains(where: { !$0.dependentValue.isFinite || $0.independentValues.count != model.independentVariables.count || !$0.independentValues.allSatisfy(\.isFinite) }) { error("forecasting.regression.observation.invalid", "Observation dimensions and values must be valid.", "model.model.observations") }
        }
        return result
    }
    public static func validate(_ request: ForecastingRequest) throws { if let item = diagnostics(for: request).first(where: { $0.severity == .error }) { throw ForecastingModelError.invalidModel(item.message) } }
}

public protocol ForecastingBackend: Sendable {
    var capabilities: SolverCapabilities { get }
    func validationReport(for request: ForecastingRequest) -> ValidationReport
    func solve(_ request: ForecastingRequest, options: SolverOptions) throws -> ForecastingSolutionEnvelope
    func runMetadata(for request: ForecastingRequest) -> SolverRunMetadata
}
public extension ForecastingBackend {
    func validationReport(for request: ForecastingRequest) -> ValidationReport { ValidationReport(backend: capabilities.backendKind, diagnostics: ForecastingValidator.diagnostics(for: request)) }
    func solve(_ request: ForecastingRequest) throws -> ForecastingSolutionEnvelope { try solve(request, options: SolverOptions()) }
    func solutionDocument(for request: ForecastingRequest, solution: ForecastingSolutionEnvelope) -> ForecastingSolutionDocument { ForecastingSolutionDocument(backend: runMetadata(for: request), title: request.model.title, request: request, solution: solution) }
}
public struct NativeEducationalForecastingBackend: ForecastingBackend {
    public init() {}
    public var capabilities: SolverCapabilities { SolverCapabilities(backendKind: .nativeEducational, solves: true, validates: true, exportsStructuredSolution: true, notes: ["Deterministic educational forecasting methods."]) }
    public func solve(_ request: ForecastingRequest, options _: SolverOptions = SolverOptions()) throws -> ForecastingSolutionEnvelope {
        try ForecastingValidator.validate(request)
        switch (request.model, request.method) {
        case (.timeSeries(let model), .linearTrend): return .linearTrend(try TimeSeriesTrendSolver.solve(model, periodsAhead: request.periodsAhead))
        case (.timeSeries(let model), .movingAverage): return .movingAverage(try TimeSeriesMovingAverageSolver.solve(model, windowSize: request.windowSize!, periodsAhead: request.periodsAhead))
        case (.timeSeries(let model), .exponentialSmoothing): return .exponentialSmoothing(try TimeSeriesExponentialSmoothingSolver.solve(model, alpha: request.alpha!, periodsAhead: request.periodsAhead))
        case (.timeSeries(let model), .multiplicativeSeasonalDecomposition): return .multiplicativeSeasonalDecomposition(try TimeSeriesSeasonalDecompositionSolver.solve(model, seasonLength: request.seasonLength!, periodsAhead: request.periodsAhead))
        case (.regression(let model), .ordinaryLeastSquares): return .ordinaryLeastSquares(try RegressionSolver.solve(model))
        default: throw ForecastingModelError.invalidModel("forecast method does not match model kind")
        }
    }
    public func runMetadata(for request: ForecastingRequest) -> SolverRunMetadata { SolverRunMetadata(backendKind: .nativeEducational, algorithm: request.method.rawValue, exactness: request.method == .ordinaryLeastSquares || request.method == .linearTrend ? .exact : .approximate, notes: ["Educational fixture-scale implementation."]) }
}
public struct ValidateOnlyForecastingBackend: ForecastingBackend {
    public init() {}
    public var capabilities: SolverCapabilities { SolverCapabilities(backendKind: .validateOnly, solves: false, validates: true, exportsStructuredSolution: false) }
    public func solve(_ request: ForecastingRequest, options _: SolverOptions = SolverOptions()) throws -> ForecastingSolutionEnvelope { throw ForecastingModelError.invalidModel("validateOnly backend does not solve \(request.method.rawValue)") }
    public func runMetadata(for request: ForecastingRequest) -> SolverRunMetadata { SolverRunMetadata(backendKind: .validateOnly, algorithm: "validationOnly", exactness: .exact, notes: ["Validates \(request.method.rawValue) without solving."]) }
}
public enum ForecastingBackends {
    public static func backend(for kind: SolverBackendKind) -> (any ForecastingBackend)? { switch kind { case .nativeEducational: NativeEducationalForecastingBackend(); case .validateOnly: ValidateOnlyForecastingBackend(); case .externalHighPerformance: nil } }
}
public enum ForecastingModelJSON {
    public static func encodeRequest(_ request: ForecastingRequest) throws -> Data { try encoder.encode(request) }
    public static func decodeRequest(from data: Data) throws -> ForecastingRequest { try JSONDecoder().decode(ForecastingRequest.self, from: data) }
    public static func encodeSolutionDocument(_ value: ForecastingSolutionDocument) throws -> Data { try encoder.encode(value) }
    public static func decodeSolutionDocument(from data: Data) throws -> ForecastingSolutionDocument { try JSONDecoder().decode(ForecastingSolutionDocument.self, from: data) }
    public static func encodeValidation(_ value: ForecastingValidationDocument) throws -> Data { try encoder.encode(value) }
    private static var encoder: JSONEncoder { let value = JSONEncoder(); value.outputFormatting = [.prettyPrinted, .sortedKeys]; return value }
}
public extension WinQSBForecastingParser {
    static func parseModelEnvelope(from data: Data) throws -> ForecastingModelEnvelope {
        guard let text = data.legacyLatin1String, let line = text.split(whereSeparator: { $0.isNewline }).first else { throw ForecastingModelError.unsupportedFormat }
        let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard fields.count > 2, fields[0] == "FC" else { throw ForecastingModelError.unsupportedFormat }
        switch fields[2] { case "0": return .timeSeries(try parseTimeSeries(from: data)); case "1": return .regression(try parseRegression(from: data)); default: throw ForecastingModelError.unsupportedModel(fields[2]) }
    }
}
