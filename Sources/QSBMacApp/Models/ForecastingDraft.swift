import Foundation
import QSBCore

enum ForecastingDraftError: Error, Equatable, CustomStringConvertible {
    case emptyTitle
    case emptyRows(path: String)
    case invalidNumber(path: String, value: String)
    case invalidInteger(path: String, value: String)
    case emptyName(path: String)
    case dimension(path: String)

    var path: String {
        switch self {
        case .emptyTitle: "title"
        case .emptyRows(let path), .invalidNumber(let path, _), .invalidInteger(let path, _), .emptyName(let path), .dimension(let path): path
        }
    }

    var message: String {
        switch self {
        case .emptyTitle: "Enter a model title."
        case .emptyRows(let path): "Add at least one observation to \(path)."
        case .invalidNumber(let path, let value): "Enter a finite number for \(path) (received '\(value)')."
        case .invalidInteger(let path, let value): "Enter a whole number for \(path) (received '\(value)')."
        case .emptyName(let path): "Enter a name for \(path)."
        case .dimension(let path): "The editor data is dimensionally inconsistent at \(path)."
        }
    }

    var description: String { message }
}

struct ForecastingObservationDraft: Equatable, Sendable {
    var label: String
    var value: String

    init(label: String = "Period 1", value: String = "0") {
        self.label = label
        self.value = value
    }

    init(_ observation: TimeSeriesObservation) {
        label = observation.label
        value = ForecastingDraft.format(observation.value)
    }
}

struct ForecastingTimeSeriesBaseDraft: Equatable, Sendable {
    var title: String
    var timeUnit: String
    var valueName: String
    var observations: [ForecastingObservationDraft]

    init(title: String = "New Forecast", timeUnit: String = "period", valueName: String = "Value", observations: [ForecastingObservationDraft] = ForecastingDraft.defaultTimeSeriesObservations()) {
        self.title = title
        self.timeUnit = timeUnit
        self.valueName = valueName
        self.observations = observations
    }

    init(_ model: TimeSeriesModel) {
        title = model.title
        timeUnit = model.timeUnit
        valueName = model.valueName
        observations = model.observations.map(ForecastingObservationDraft.init)
    }

    func makeModel() throws -> TimeSeriesModel {
        try ForecastingDraft.makeTimeSeries(title: title, timeUnit: timeUnit, valueName: valueName, observations: observations)
    }
}

struct ForecastingRegressionObservationDraft: Equatable, Sendable {
    var label: String
    var dependentValue: String
    var independentValues: [String]
}

struct ForecastingRegressionDraft: Equatable, Sendable {
    var title: String
    var dependentVariable: String
    var independentVariables: [String]
    var observations: [ForecastingRegressionObservationDraft]

    init(title: String = "New Regression Forecast", dependentVariable: String = "Demand", independentVariables: [String] = ["Time"], observations: [ForecastingRegressionObservationDraft] = ForecastingDraft.defaultRegressionObservations()) {
        self.title = title
        self.dependentVariable = dependentVariable
        self.independentVariables = independentVariables
        self.observations = observations
    }

    init(_ model: RegressionModel) {
        title = model.title
        dependentVariable = model.dependentVariable
        independentVariables = model.independentVariables
        observations = model.observations.map {
            ForecastingRegressionObservationDraft(label: $0.label, dependentValue: ForecastingDraft.format($0.dependentValue), independentValues: $0.independentValues.map(ForecastingDraft.format))
        }
    }

    func makeModel() throws -> RegressionModel {
        let title = try ForecastingDraft.title(title)
        guard !independentVariables.isEmpty, !observations.isEmpty else {
            throw ForecastingDraftError.emptyRows(path: "observations")
        }
        guard !dependentVariable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ForecastingDraftError.emptyName(path: "dependentVariable")
        }
        guard independentVariables.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ForecastingDraftError.emptyName(path: "independentVariables")
        }
        let rows = try observations.enumerated().map { index, row in
            guard !row.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ForecastingDraftError.emptyName(path: "observations.\(index).label") }
            guard row.independentValues.count == independentVariables.count else { throw ForecastingDraftError.dimension(path: "observations.\(index).independentValues") }
            return RegressionObservation(label: row.label, dependentValue: try ForecastingDraft.number(row.dependentValue, path: "observations.\(index).dependentValue"), independentValues: try row.independentValues.enumerated().map { column, value in try ForecastingDraft.number(value, path: "observations.\(index).independentValues.\(column)") })
        }
        return RegressionModel(title: title, dependentVariable: dependentVariable, independentVariables: independentVariables, observations: rows)
    }
}

enum ForecastingDraft: Equatable, Sendable {
    case linearTrend(ForecastingTimeSeriesBaseDraft, periodsAhead: String)
    case movingAverage(ForecastingTimeSeriesBaseDraft, windowSize: String, periodsAhead: String)
    case exponentialSmoothing(ForecastingTimeSeriesBaseDraft, alpha: String, periodsAhead: String)
    case multiplicativeSeasonalDecomposition(ForecastingTimeSeriesBaseDraft, seasonLength: String, periodsAhead: String)
    case ordinaryLeastSquares(ForecastingRegressionDraft)

    static func blank(_ method: ForecastingMethod) -> Self {
        switch method {
        case .linearTrend: .linearTrend(ForecastingTimeSeriesBaseDraft(), periodsAhead: "2")
        case .movingAverage: .movingAverage(ForecastingTimeSeriesBaseDraft(), windowSize: "3", periodsAhead: "2")
        case .exponentialSmoothing: .exponentialSmoothing(ForecastingTimeSeriesBaseDraft(), alpha: "0.3", periodsAhead: "2")
        case .multiplicativeSeasonalDecomposition: .multiplicativeSeasonalDecomposition(ForecastingTimeSeriesBaseDraft(observations: defaultTimeSeriesObservations(count: 24)), seasonLength: "12", periodsAhead: "2")
        case .ordinaryLeastSquares: .ordinaryLeastSquares(ForecastingRegressionDraft())
        }
    }

    init(_ request: ForecastingRequest) {
        switch (request.model, request.method) {
        case (.timeSeries(let model), .linearTrend): self = .linearTrend(ForecastingTimeSeriesBaseDraft(model), periodsAhead: String(request.periodsAhead))
        case (.timeSeries(let model), .movingAverage): self = .movingAverage(ForecastingTimeSeriesBaseDraft(model), windowSize: String(request.windowSize ?? 0), periodsAhead: String(request.periodsAhead))
        case (.timeSeries(let model), .exponentialSmoothing): self = .exponentialSmoothing(ForecastingTimeSeriesBaseDraft(model), alpha: request.alpha.map(ForecastingDraft.format) ?? "", periodsAhead: String(request.periodsAhead))
        case (.timeSeries(let model), .multiplicativeSeasonalDecomposition): self = .multiplicativeSeasonalDecomposition(ForecastingTimeSeriesBaseDraft(model), seasonLength: String(request.seasonLength ?? 0), periodsAhead: String(request.periodsAhead))
        case (.regression(let model), .ordinaryLeastSquares): self = .ordinaryLeastSquares(ForecastingRegressionDraft(model))
        default: self = .linearTrend(ForecastingTimeSeriesBaseDraft(), periodsAhead: "1")
        }
    }

    var method: ForecastingMethod {
        switch self { case .linearTrend: .linearTrend; case .movingAverage: .movingAverage; case .exponentialSmoothing: .exponentialSmoothing; case .multiplicativeSeasonalDecomposition: .multiplicativeSeasonalDecomposition; case .ordinaryLeastSquares: .ordinaryLeastSquares }
    }

    var observationsCount: Int {
        switch self { case .ordinaryLeastSquares(let draft): draft.observations.count; case .linearTrend(let draft, _), .movingAverage(let draft, _, _), .exponentialSmoothing(let draft, _, _), .multiplicativeSeasonalDecomposition(let draft, _, _): draft.observations.count }
    }

    var title: String {
        switch self { case .ordinaryLeastSquares(let draft): draft.title; case .linearTrend(let draft, _), .movingAverage(let draft, _, _), .exponentialSmoothing(let draft, _, _), .multiplicativeSeasonalDecomposition(let draft, _, _): draft.title }
    }

    func makeRequest() throws -> ForecastingRequest {
        switch self {
        case .linearTrend(let base, let periods): return ForecastingRequest(model: .timeSeries(try base.makeModel()), method: .linearTrend, periodsAhead: try Self.integer(periods, path: "periodsAhead"))
        case .movingAverage(let base, let window, let periods): return ForecastingRequest(model: .timeSeries(try base.makeModel()), method: .movingAverage, periodsAhead: try Self.integer(periods, path: "periodsAhead"), windowSize: try Self.integer(window, path: "windowSize"))
        case .exponentialSmoothing(let base, let alpha, let periods): return ForecastingRequest(model: .timeSeries(try base.makeModel()), method: .exponentialSmoothing, periodsAhead: try Self.integer(periods, path: "periodsAhead"), alpha: try Self.number(alpha, path: "alpha"))
        case .multiplicativeSeasonalDecomposition(let base, let season, let periods): return ForecastingRequest(model: .timeSeries(try base.makeModel()), method: .multiplicativeSeasonalDecomposition, periodsAhead: try Self.integer(periods, path: "periodsAhead"), seasonLength: try Self.integer(season, path: "seasonLength"))
        case .ordinaryLeastSquares(let draft): return ForecastingRequest(model: .regression(try draft.makeModel()), method: .ordinaryLeastSquares)
        }
    }

    func draftDiagnostics() -> [ValidationDiagnostic] {
        do { return ForecastingValidator.diagnostics(for: try makeRequest()) }
        catch let error as ForecastingDraftError { return [ValidationDiagnostic(severity: .error, code: "forecasting.draft.\(error.path.replacingOccurrences(of: ".", with: "_"))", message: error.message, path: error.path)] }
        catch { return [ValidationDiagnostic(severity: .error, code: "forecasting.draft.invalid", message: error.localizedDescription, path: nil)] }
    }

    mutating func addObservation() {
        switch self {
        case .ordinaryLeastSquares(var draft):
            draft.observations.append(ForecastingRegressionObservationDraft(label: "Observation \(draft.observations.count + 1)", dependentValue: "0", independentValues: Array(repeating: "0", count: draft.independentVariables.count)))
            self = .ordinaryLeastSquares(draft)
        default:
            updateTimeSeries { $0.observations.append(ForecastingObservationDraft(label: "Period \($0.observations.count + 1)")) }
        }
    }
    mutating func removeObservation(at index: Int) {
        switch self {
        case .ordinaryLeastSquares(var draft):
            if draft.observations.indices.contains(index) { draft.observations.remove(at: index) }
            self = .ordinaryLeastSquares(draft)
        default:
            updateTimeSeries { if $0.observations.indices.contains(index) { $0.observations.remove(at: index) } }
        }
    }

    mutating func switchMethod(to method: ForecastingMethod) {
        guard method != self.method else { return }
        let oldBase: ForecastingTimeSeriesBaseDraft
        switch self {
        case .ordinaryLeastSquares(let draft):
            oldBase = ForecastingTimeSeriesBaseDraft(
                title: draft.title,
                valueName: draft.dependentVariable,
                observations: draft.observations.map { ForecastingObservationDraft(label: $0.label, value: $0.dependentValue) }
            )
        case .linearTrend(let base, _), .movingAverage(let base, _, _), .exponentialSmoothing(let base, _, _), .multiplicativeSeasonalDecomposition(let base, _, _):
            oldBase = base
        }
        switch method {
        case .linearTrend: self = .linearTrend(oldBase, periodsAhead: "2")
        case .movingAverage: self = .movingAverage(oldBase, windowSize: "3", periodsAhead: "2")
        case .exponentialSmoothing: self = .exponentialSmoothing(oldBase, alpha: "0.3", periodsAhead: "2")
        case .multiplicativeSeasonalDecomposition: self = .multiplicativeSeasonalDecomposition(oldBase, seasonLength: "12", periodsAhead: "2")
        case .ordinaryLeastSquares:
            self = .ordinaryLeastSquares(ForecastingRegressionDraft(
                title: oldBase.title,
                dependentVariable: oldBase.valueName,
                independentVariables: ["Time"],
                observations: oldBase.observations.enumerated().map { index, observation in
                    ForecastingRegressionObservationDraft(label: observation.label, dependentValue: observation.value, independentValues: [String(index + 1)])
                }
            ))
        }
    }

    private mutating func updateTimeSeries(_ update: (inout ForecastingTimeSeriesBaseDraft) -> Void) {
        switch self { case .linearTrend(var base, let periods): update(&base); self = .linearTrend(base, periodsAhead: periods); case .movingAverage(var base, let window, let periods): update(&base); self = .movingAverage(base, windowSize: window, periodsAhead: periods); case .exponentialSmoothing(var base, let alpha, let periods): update(&base); self = .exponentialSmoothing(base, alpha: alpha, periodsAhead: periods); case .multiplicativeSeasonalDecomposition(var base, let season, let periods): update(&base); self = .multiplicativeSeasonalDecomposition(base, seasonLength: season, periodsAhead: periods); case .ordinaryLeastSquares: break }
    }

    static func format(_ value: Double) -> String { value.rounded() == value ? String(Int(value)) : String(value) }
    static func defaultTimeSeriesObservations(count: Int = 6) -> [ForecastingObservationDraft] { (0..<count).map { ForecastingObservationDraft(label: "Period \($0 + 1)", value: String(100 + $0 * 5)) } }
    static func defaultRegressionObservations() -> [ForecastingRegressionObservationDraft] { (0..<4).map { ForecastingRegressionObservationDraft(label: "Observation \($0 + 1)", dependentValue: String(10 + $0 * 2), independentValues: [String($0 + 1)]) } }
    static func title(_ value: String) throws -> String { let value = value.trimmingCharacters(in: .whitespacesAndNewlines); guard !value.isEmpty else { throw ForecastingDraftError.emptyTitle }; return value }
    static func makeTimeSeries(title: String, timeUnit: String, valueName: String, observations: [ForecastingObservationDraft]) throws -> TimeSeriesModel { guard !observations.isEmpty else { throw ForecastingDraftError.emptyRows(path: "observations") }; let rows = try observations.enumerated().map { index, row in guard !row.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ForecastingDraftError.emptyName(path: "observations.\(index).label") }; return TimeSeriesObservation(label: row.label, value: try number(row.value, path: "observations.\(index).value")) }; return TimeSeriesModel(title: try ForecastingDraft.title(title), timeUnit: timeUnit, valueName: valueName, observations: rows) }
    static func number(_ value: String, path: String) throws -> Double { guard let number = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)), number.isFinite else { throw ForecastingDraftError.invalidNumber(path: path, value: value) }; return number }
    static func integer(_ value: String, path: String) throws -> Int { guard let number = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) else { throw ForecastingDraftError.invalidInteger(path: path, value: value) }; return number }
}
