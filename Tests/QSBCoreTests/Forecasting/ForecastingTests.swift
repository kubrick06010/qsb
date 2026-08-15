import Foundation
import Testing
@testable import QSBCore

@Test func parsesAndSolvesWinQSBRegressionFixture() throws {
    let url = legacyFixtureURL("LINEREG.FC_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let model = try WinQSBForecastingParser.parseRegression(from: expanded)
    let solution = try RegressionSolver.solve(model)

    #expect(model.title == "QSB P.320")
    #expect(model.dependentVariable == "Utility")
    #expect(model.independentVariables == ["Temperature", "Insulation"])
    #expect(model.observations.count == 15)
    #expect(abs(solution.intercept - -79.74016339) < 1e-6)
    #expect(abs((solution.coefficients["Temperature"] ?? 0) - 3.12107883) < 1e-6)
    #expect(abs((solution.coefficients["Insulation"] ?? 0) - -1.16911892) < 1e-6)
    #expect(abs(solution.sumSquaredErrors - 945.0928939790944) < 1e-6)
    #expect(abs(solution.rSquared - 0.9036199052397135) < 1e-8)
}

@Test func parsesAndSolvesWinQSBTimeSeriesFixture() throws {
    let url = legacyFixtureURL("SALES.FC_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let model = try WinQSBForecastingParser.parseTimeSeries(from: expanded)
    let solution = try TimeSeriesTrendSolver.solve(model, periodsAhead: 2)

    #expect(model.title == "Sales")
    #expect(model.timeUnit == "month")
    #expect(model.valueName == "Historical Data")
    #expect(model.observations.count == 24)
    #expect(model.observations[0] == TimeSeriesObservation(label: "1", value: 398))
    #expect(model.observations[23] == TimeSeriesObservation(label: "24", value: 580))
    #expect(abs(solution.intercept - 364.00724637681157) < 1e-8)
    #expect(abs(solution.slope - 7.8560869565217395) < 1e-8)
    #expect(abs(solution.meanActual - 462.2083333333333) < 1e-8)
    #expect(abs(solution.meanAbsoluteDeviation - 19.660398550724647) < 1e-8)
    #expect(abs(solution.meanSquaredError - 763.5058635265701) < 1e-8)
    #expect(abs((solution.meanAbsolutePercentageError ?? 0) - 4.756017322660986) < 1e-8)
    #expect(abs(solution.fittedValues[0].fitted - 371.8633333333333) < 1e-8)
    #expect(abs(solution.fittedValues[23].residual - 27.446666666666715) < 1e-8)
    #expect(solution.forecasts[0].label == "month 25")
    #expect(abs(solution.forecasts[0].value - 560.409420289855) < 1e-8)
    #expect(solution.forecasts[1].label == "month 26")
    #expect(abs(solution.forecasts[1].value - 568.2655072463767) < 1e-8)
}

@Test func solvesWinQSBTimeSeriesMovingAverageFixture() throws {
    let url = legacyFixtureURL("SALES.FC_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let model = try WinQSBForecastingParser.parseTimeSeries(from: expanded)
    let solution = try TimeSeriesMovingAverageSolver.solve(model, windowSize: 3, periodsAhead: 2)

    #expect(solution.windowSize == 3)
    #expect(solution.fittedValues.count == 21)
    #expect(solution.fittedValues[0].label == "4")
    #expect(abs(solution.fittedValues[0].fitted - 361) < 1e-8)
    #expect(abs(solution.fittedValues[0].residual - 39) < 1e-8)
    #expect(abs(solution.fittedValues[20].fitted - 536.6666666666666) < 1e-8)
    #expect(abs(solution.fittedValues[20].residual - 43.33333333333337) < 1e-8)
    #expect(abs(solution.meanAbsoluteDeviation - 27.333333333333332) < 1e-8)
    #expect(abs(solution.meanSquaredError - 1038.1269841269839) < 1e-8)
    #expect(abs((solution.meanAbsolutePercentageError ?? 0) - 5.787621607603826) < 1e-8)
    #expect(solution.forecasts[0].label == "month 25")
    #expect(abs(solution.forecasts[0].value - 561.6666666666666) < 1e-8)
    #expect(solution.forecasts[1].label == "month 26")
    #expect(abs(solution.forecasts[1].value - 565.5555555555555) < 1e-8)
}

@Test func solvesWinQSBTimeSeriesExponentialSmoothingFixture() throws {
    let url = legacyFixtureURL("SALES.FC_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let model = try WinQSBForecastingParser.parseTimeSeries(from: expanded)
    let solution = try TimeSeriesExponentialSmoothingSolver.solve(model, alpha: 0.3, periodsAhead: 2)

    #expect(abs(solution.alpha - 0.3) < 1e-8)
    #expect(solution.initialForecast == 398)
    #expect(solution.fittedValues.count == 23)
    #expect(solution.fittedValues[0].label == "2")
    #expect(abs(solution.fittedValues[0].fitted - 398) < 1e-8)
    #expect(abs(solution.fittedValues[0].residual - -3) < 1e-8)
    #expect(abs(solution.fittedValues[22].fitted - 525.8154718472708) < 1e-8)
    #expect(abs(solution.fittedValues[22].residual - 54.18452815272917) < 1e-8)
    #expect(abs(solution.meanAbsoluteDeviation - 33.06544413695933) < 1e-8)
    #expect(abs(solution.meanSquaredError - 1584.054281714657) < 1e-8)
    #expect(abs((solution.meanAbsolutePercentageError ?? 0) - 7.548062767326426) < 1e-8)
    #expect(solution.forecasts[0].label == "month 25")
    #expect(abs(solution.forecasts[0].value - 542.0708302930896) < 1e-8)
    #expect(solution.forecasts[1].label == "month 26")
    #expect(abs(solution.forecasts[1].value - 542.0708302930896) < 1e-8)
}

@Test func solvesWinQSBTimeSeriesSeasonalFixture() throws {
    let url = legacyFixtureURL("SALES.FC_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let model = try WinQSBForecastingParser.parseTimeSeries(from: expanded)
    let solution = try TimeSeriesSeasonalDecompositionSolver.solve(model, seasonLength: 12, periodsAhead: 2)

    #expect(solution.seasonLength == 12)
    #expect(abs(solution.intercept - 364.00724637681157) < 1e-8)
    #expect(abs(solution.slope - 7.8560869565217395) < 1e-8)
    #expect(abs(solution.meanActual - 462.2083333333333) < 1e-8)
    #expect(solution.seasonalFactors.count == 12)
    #expect(abs(solution.seasonalFactors[0].factor - 1.0499924580475422) < 1e-8)
    #expect(abs(solution.seasonalFactors[2].factor - 0.864921337178654) < 1e-8)
    #expect(abs(solution.seasonalFactors[11].factor - 1.0376019214236234) < 1e-8)
    #expect(abs(solution.fittedValues[0].fitted - 390.45369542441915) < 1e-8)
    #expect(abs(solution.fittedValues[0].residual - 7.546304575580848) < 1e-8)
    #expect(abs(solution.fittedValues[23].fitted - 573.3304003556945) < 1e-8)
    #expect(abs(solution.fittedValues[23].residual - 6.669599644305549) < 1e-8)
    #expect(abs(solution.meanAbsoluteDeviation - 13.815133582745851) < 1e-8)
    #expect(abs(solution.meanSquaredError - 356.955914221362) < 1e-8)
    #expect(abs((solution.meanAbsolutePercentageError ?? 0) - 3.256967972141938) < 1e-8)
    #expect(solution.forecasts[0].label == "month 25")
    #expect(abs(solution.forecasts[0].value - 588.425664723143) < 1e-8)
    #expect(solution.forecasts[1].label == "month 26")
    #expect(abs(solution.forecasts[1].value - 574.2974425729508) < 1e-8)
}

@Test func roundTripsNormalizedForecastingRequestsAndSolutions() throws {
    let sales = try WinQSBForecastingParser.parseModelEnvelope(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("SALES.FC_"))))
    let regression = try WinQSBForecastingParser.parseModelEnvelope(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("LINEREG.FC_"))))
    let requests = [
        ForecastingRequest(model: sales, method: .linearTrend, periodsAhead: 2),
        ForecastingRequest(model: sales, method: .movingAverage, periodsAhead: 2, windowSize: 3),
        ForecastingRequest(model: sales, method: .exponentialSmoothing, periodsAhead: 2, alpha: 0.3),
        ForecastingRequest(model: sales, method: .multiplicativeSeasonalDecomposition, periodsAhead: 2, seasonLength: 12),
        ForecastingRequest(model: regression, method: .ordinaryLeastSquares)
    ]
    let backend = NativeEducationalForecastingBackend()
    for request in requests {
        let encodedRequest = try ForecastingModelJSON.encodeRequest(request)
        #expect(try ForecastingModelJSON.decodeRequest(from: encodedRequest) == request)
        let solution = try backend.solve(request)
        #expect(solution.method == request.method)
        let document = backend.solutionDocument(for: request, solution: solution)
        let encodedSolution = try ForecastingModelJSON.encodeSolutionDocument(document)
        #expect(try ForecastingModelJSON.decodeSolutionDocument(from: encodedSolution) == document)
    }
}

@Test func routesForecastingThroughNamedBackendsAndStructuredValidation() throws {
    let model = try WinQSBForecastingParser.parseModelEnvelope(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("SALES.FC_"))))
    let valid = ForecastingRequest(model: model, method: .movingAverage, windowSize: 3)
    let invalid = ForecastingRequest(model: model, method: .movingAverage, windowSize: 24)
    let native = NativeEducationalForecastingBackend()
    let validateOnly = ValidateOnlyForecastingBackend()

    #expect(native.runMetadata(for: valid).algorithm == "movingAverage")
    #expect(native.runMetadata(for: valid).exactness == .approximate)
    #expect(validateOnly.validationReport(for: valid).isValid)
    #expect(!validateOnly.validationReport(for: invalid).isValid)
    #expect(validateOnly.validationReport(for: invalid).diagnostics.contains { $0.code == "forecasting.movingAverage.window.invalid" })
    #expect(ForecastingBackends.backend(for: .externalHighPerformance) == nil)
    do {
        _ = try validateOnly.solve(valid)
        Issue.record("validateOnly unexpectedly solved a forecasting request")
    } catch {
        #expect(String(describing: error).contains("validateOnly"))
    }
}

