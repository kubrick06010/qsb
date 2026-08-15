import Foundation
import Testing
@testable import QSBCore

@Test func parsesAndSolvesWinQSBCAndPChartFixtures() throws {
    let cModel = try WinQSBQualityControlParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("C_CHART.QC_"))))
    let pModel = try WinQSBQualityControlParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("P_CHART.QC_"))))

    guard case .cChart(let cChart) = try QualityControlSolver.solve(cModel),
          case .pChart(let pChart) = try QualityControlSolver.solve(pModel) else {
        Issue.record("Expected c-chart and p-chart solutions")
        return
    }
    #expect(cChart.points.count == 26)
    #expect(cChart.outsideLimitIndexes == [6, 20])
    #expect(abs(cChart.points[0].centerLine - 19.846153846153847) < 1e-10)
    #expect(pChart.points.count == 30)
    #expect(pChart.outsideLimitIndexes == [15, 23])
    #expect(abs(pChart.points[0].centerLine - 0.23133333333333334) < 1e-10)
}

@Test func parsesAndSolvesWinQSBXbarRFixture() throws {
    let model = try WinQSBQualityControlParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("VARIABLE.QC_"))))
    guard case .xbarRChart(let solution) = try NativeEducationalQualityControlBackend().solve(model) else {
        Issue.record("Expected an Xbar-R solution")
        return
    }
    #expect(solution.meanChart.points.count == 50)
    #expect(abs(solution.grandMean - 74.001524) < 1e-9)
    #expect(abs(solution.averageRange - 0.02758) < 1e-9)
    #expect(solution.meanChart.outsideLimitIndexes == [28, 29, 36, 48])
    #expect(solution.rangeChart.outsideLimitIndexes == [28, 29, 36, 48])
}

@Test func parsesAndSolvesWinQSBParetoFixture() throws {
    let model = try WinQSBQualityControlParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("PARETO.QC_"))))
    guard case .pareto(let solution) = try QualityControlSolver.solve(model) else {
        Issue.record("Expected a Pareto solution")
        return
    }
    #expect(solution.totalCount == 152)
    #expect(solution.categories.map(\.name) == ["Bent Pins", "Misaligned", "Broken", "Miscellaneous", "Missing"])
    #expect(solution.categories.map(\.count) == [77, 28, 18, 16, 13])
    #expect(abs(solution.categories.last!.cumulativePercentage - 1) < 1e-12)
}

@Test func parsesAndSolvesWinQSBNormalProbabilityPlotFixture() throws {
    let model = try WinQSBQualityControlParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("PROBPLOT.QC_"))))
    guard case .normalProbabilityPlot(let solution) = try QualityControlSolver.solve(model) else {
        Issue.record("Expected a normal probability plot solution")
        return
    }
    #expect(solution.points.count == 20)
    #expect(abs(solution.mean - 10.0065) < 1e-10)
    #expect(abs(solution.sampleStandardDeviation - 0.33427494198953245) < 1e-10)
    #expect(abs(solution.correlation - 0.9994166884040918) < 1e-10)
}

@Test func roundTripsAndValidatesQualityControlBackends() throws {
    let model = try WinQSBQualityControlParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("C_CHART.QC_"))))
    #expect(try QualityControlJSON.decodeModel(from: QualityControlJSON.encodeModel(model)) == model)
    let native = NativeEducationalQualityControlBackend()
    let solution = try native.solve(model)
    let document = native.solutionDocument(for: model, solution: solution)
    #expect(try QualityControlJSON.decodeSolution(from: QualityControlJSON.encodeSolution(document)) == document)
    #expect(ValidateOnlyQualityControlBackend().validationReport(for: model).isValid)
    #expect(QualityControlBackends.backend(for: .externalHighPerformance) == nil)

    let invalid = QualityControlModelEnvelope.pChart(PChartModel(title: "Invalid", characteristic: "Defects", sampleSizes: [0], proportions: [1.2]))
    let report = ValidateOnlyQualityControlBackend().validationReport(for: invalid)
    #expect(!report.isValid)
    #expect(report.diagnostics.contains { $0.code == "qualityControl.pChart.values" })
    do {
        _ = try ValidateOnlyQualityControlBackend().solve(model)
        Issue.record("validateOnly unexpectedly solved a quality-control model")
    } catch {
        #expect(String(describing: error).contains("validateOnly"))
    }
}

