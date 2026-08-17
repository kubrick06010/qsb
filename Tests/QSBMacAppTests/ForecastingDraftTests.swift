import Testing
import QSBCore
@testable import QSBMacApp

struct ForecastingDraftTests {
    @Test("all forecasting methods round trip through typed requests")
    func everyMethodRoundTrip() throws {
        let series = TimeSeriesModel(title: "Sales", timeUnit: "month", valueName: "Demand", observations: [
            TimeSeriesObservation(label: "Jan", value: 10), TimeSeriesObservation(label: "Feb", value: 12),
            TimeSeriesObservation(label: "Mar", value: 11), TimeSeriesObservation(label: "Apr", value: 14)
        ])
        let regression = RegressionModel(title: "Demand regression", dependentVariable: "Demand", independentVariables: ["Time"], observations: [
            RegressionObservation(label: "1", dependentValue: 10, independentValues: [1]),
            RegressionObservation(label: "2", dependentValue: 12, independentValues: [2]),
            RegressionObservation(label: "3", dependentValue: 14, independentValues: [3])
        ])
        let requests = [
            ForecastingRequest(model: .timeSeries(series), method: .linearTrend, periodsAhead: 2),
            ForecastingRequest(model: .timeSeries(series), method: .movingAverage, periodsAhead: 2, windowSize: 2),
            ForecastingRequest(model: .timeSeries(series), method: .exponentialSmoothing, periodsAhead: 2, alpha: 0.3),
            ForecastingRequest(model: .timeSeries(series), method: .multiplicativeSeasonalDecomposition, periodsAhead: 2, seasonLength: 2),
            ForecastingRequest(model: .regression(regression), method: .ordinaryLeastSquares)
        ]
        for request in requests {
            let roundTrip = try ForecastingDraft(request).makeRequest()
            #expect(roundTrip == request)
        }
    }

    @Test("time-series rows mutate without reordering")
    func rowMutations() throws {
        var draft = ForecastingDraft.blank(.movingAverage)
        let initial = draft.observationsCount
        draft.addObservation()
        #expect(draft.observationsCount == initial + 1)
        draft.removeObservation(at: 0)
        #expect(draft.observationsCount == initial)
        let request = try draft.makeRequest()
        guard case .timeSeries(let model) = request.model else { Issue.record("Expected time-series model"); return }
        #expect(model.observations.first?.label == "Period 2")
    }

    @Test("method switching preserves time-series observations")
    func methodSwitching() throws {
        var draft = ForecastingDraft.blank(.linearTrend)
        let originalCount = draft.observationsCount
        draft.switchMethod(to: .exponentialSmoothing)
        #expect(draft.method == .exponentialSmoothing)
        #expect(draft.observationsCount == originalCount)
        draft.switchMethod(to: .ordinaryLeastSquares)
        #expect(draft.observationsCount == originalCount)
    }

    @Test("draft diagnostics stay separate from core semantic validation")
    func diagnostics() {
        var draft = ForecastingDraft.blank(.movingAverage)
        draft.switchMethod(to: .movingAverage)
        guard case .movingAverage(let base, _, let periods) = draft else { Issue.record("Expected moving average"); return }
        draft = .movingAverage(base, windowSize: "not a number", periodsAhead: periods)
        let diagnostics = draft.draftDiagnostics()
        #expect(diagnostics.first?.code == "forecasting.draft.windowSize")
    }

    @Test("editor-created request enters the existing forecasting backend")
    func runIntegration() throws {
        let request = try ForecastingDraft.blank(.linearTrend).makeRequest()
        let solution = try NativeEducationalForecastingBackend().solve(request)
        guard case .linearTrend(let result) = solution else { Issue.record("Expected linear trend solution"); return }
        #expect(result.forecasts.count == request.periodsAhead)
    }
}
