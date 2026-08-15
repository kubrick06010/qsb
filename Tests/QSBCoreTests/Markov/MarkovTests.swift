import Foundation
import Testing
@testable import QSBCore

@Test func parsesAndSolvesWinQSBMarkovFixtureWithInitialState() throws {
    let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("MKP1.MK_")))
    let model = try WinQSBMarkovParser.parse(from: expanded)
    let request = MarkovAnalysisRequest(model: model, periods: 10)
    let solution = try NativeEducationalMarkovBackend().solve(request)

    #expect(model.states == ["A", "B", "C"])
    #expect(model.initialProbabilities == [0, 1, 0])
    #expect(solution.transientResults.count == 11)
    #expect(solution.transientResults[1].probabilities == [0.4, 0.3, 0.3])
    #expect(abs(solution.stationaryProbabilities[0] - 0.26785714285714285) < 1e-8)
    #expect(abs(solution.stationaryExpectedCost - 3.8464285714285715) < 1e-8)
}

@Test func parsesAndSolvesWinQSBMarkovFixtureWithoutInitialState() throws {
    let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("MKP2.MK_")))
    let model = try WinQSBMarkovParser.parse(from: expanded)
    let solution = try MarkovSolver.solve(MarkovAnalysisRequest(model: model))

    #expect(model.states.count == 4)
    #expect(model.initialProbabilities == nil)
    #expect(solution.transientResults.isEmpty)
    #expect(abs(solution.stationaryProbabilities.reduce(0, +) - 1) < 1e-8)
    #expect(abs(solution.stationaryExpectedCost - 31.432482618771726) < 1e-8)
}

@Test func roundTripsAndValidatesMarkovBackends() throws {
    let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("MKP1.MK_")))
    let request = MarkovAnalysisRequest(model: try WinQSBMarkovParser.parse(from: expanded), periods: 3)
    let encoded = try MarkovJSON.encodeRequest(request)
    #expect(try MarkovJSON.decodeRequest(from: encoded) == request)
    let native = NativeEducationalMarkovBackend()
    let document = native.solutionDocument(for: request, solution: try native.solve(request))
    #expect(try MarkovJSON.decodeSolution(from: MarkovJSON.encodeSolution(document)) == document)
    #expect(ValidateOnlyMarkovBackend().validationReport(for: request).isValid)
    #expect(MarkovBackends.backend(for: .externalHighPerformance) == nil)

    let invalid = MarkovAnalysisRequest(model: MarkovChainModel(
        title: "Invalid", states: ["A", "B"], transitionMatrix: [[0.5, 0.4], [0.2, 0.8]],
        initialProbabilities: [1.2, -0.2], stateCosts: [1, 2]
    ))
    let report = ValidateOnlyMarkovBackend().validationReport(for: invalid)
    #expect(!report.isValid)
    #expect(report.diagnostics.contains { $0.code == "markov.transition.rowSum" })
    #expect(report.diagnostics.contains { $0.code == "markov.initial.probability" })
    do {
        _ = try ValidateOnlyMarkovBackend().solve(request)
        Issue.record("validateOnly unexpectedly solved a Markov request")
    } catch { #expect(String(describing: error).contains("validateOnly")) }
}

