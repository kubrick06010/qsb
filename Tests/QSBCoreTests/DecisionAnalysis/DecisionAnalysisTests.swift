import Foundation
import Testing
@testable import QSBCore

@Test func parsesAndSolvesWinQSBPayoffFixture() throws {
    let url = legacyFixtureURL("PAYOFF.DA_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBDecisionAnalysisParser.parsePayoff(from: expanded)
    let solution = try DecisionPayoffSolver.solve(problem)

    #expect(problem.title == "QSB P.277")
    #expect(problem.states == ["High", "Medium", "Low"])
    #expect(problem.indicators == ["Favorable", "Unfavorable", "Neutral"])
    #expect(problem.decisions == ["Advertise", "Do Nothing", "Pricing"])
    #expect(solution.bestPriorDecision == "Pricing")
    #expect(abs(solution.bestPriorExpectedValue - 56300) < 1e-8)
    #expect(solution.priorExpectedValues == [
        DecisionExpectedValue(decision: "Advertise", expectedValue: 55000),
        DecisionExpectedValue(decision: "Do Nothing", expectedValue: -7000),
        DecisionExpectedValue(decision: "Pricing", expectedValue: 56300)
    ])
    #expect(abs(solution.expectedValueWithSampleInformation - 57170) < 1e-8)
    #expect(abs(solution.expectedValueOfSampleInformation - 870) < 1e-8)
    #expect(abs(solution.expectedValueWithPerfectInformation - 59500) < 1e-8)
    #expect(abs(solution.expectedValueOfPerfectInformation - 3200) < 1e-8)
    #expect(solution.indicatorAnalyses.map(\.bestDecision) == ["Advertise", "Pricing", "Pricing"])
    #expect(abs(solution.indicatorAnalyses[0].probability - 0.33) < 1e-8)
    #expect(abs(solution.indicatorAnalyses[0].bestExpectedValue - 65454.54545454546) < 1e-8)
}

@Test func parsesAndSolvesWinQSBDecisionTreeFixture() throws {
    let url = legacyFixtureURL("DTREE.DA_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let tree = try WinQSBDecisionAnalysisParser.parseDecisionTree(from: expanded)
    let solution = try DecisionTreeSolver.solve(tree)

    #expect(tree.title == "QSB P.283")
    #expect(tree.rootID == 1)
    #expect(tree.nodes.count == 40)
    #expect(tree.nodes[0] == DecisionTreeNode(
        id: 1,
        name: "Survey",
        kind: .chance,
        childIDs: [2, 3, 4]
    ))
    #expect(tree.nodes[13] == DecisionTreeNode(
        id: 14,
        name: "High",
        kind: .terminal,
        childIDs: [],
        payoff: 100000,
        probability: 0.36
    ))
    #expect(abs(solution.expectedValue - 57213.215998367516) < 1e-8)
    #expect(solution.policy.map(\.nodeID) == [2, 3, 4])
    #expect(solution.policy.map(\.nodeName) == ["Favorable", "Unfavorable", "Neutral"])
    #expect(solution.policy.map(\.selectedChildID) == [5, 10, 13])
    #expect(solution.policy.map(\.selectedChildName) == ["Advertise", "Pricing", "Pricing"])
    #expect(abs(solution.policy[0].expectedValue - 65454.545454545456) < 1e-8)
    #expect(abs(solution.policy[1].expectedValue - 51252.52525252525) < 1e-8)
    #expect(abs(solution.policy[2].expectedValue - 55170) < 1e-8)
}

@Test func parsesAndSolvesWinQSBBayesianFixture() throws {
    let url = legacyFixtureURL("BAYESIAN.DA_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBDecisionAnalysisParser.parseBayesianAnalysis(from: expanded)
    let solution = try BayesianAnalysisSolver.solve(problem)

    #expect(problem.title == "QSB P.272")
    #expect(problem.states == ["High", "Medium", "Low"])
    #expect(problem.priorProbabilities == [0.20, 0.50, 0.30])
    #expect(problem.outcomes == ["Favorable", "Unfavorable", "Neutral"])
    #expect(solution.outcomes.count == 3)
    #expect(abs(solution.outcomes[0].probability - 0.33) < 1e-8)
    #expect(abs(solution.outcomes[0].posteriorProbabilities[0] - 0.36363636363636365) < 1e-8)
    #expect(abs(solution.outcomes[0].posteriorProbabilities[1] - 0.4545454545454546) < 1e-8)
    #expect(abs(solution.outcomes[0].posteriorProbabilities[2] - 0.18181818181818182) < 1e-8)
    #expect(abs(solution.outcomes[1].probability - 0.355) < 1e-8)
    #expect(abs(solution.outcomes[1].posteriorProbabilities[0] - 0.1126760563380282) < 1e-8)
    #expect(abs(solution.outcomes[1].posteriorProbabilities[1] - 0.4225352112676056) < 1e-8)
    #expect(abs(solution.outcomes[1].posteriorProbabilities[2] - 0.46478873239436624) < 1e-8)
    #expect(abs(solution.outcomes[2].probability - 0.315) < 1e-8)
    #expect(abs(solution.outcomes[2].posteriorProbabilities[0] - 0.126984126984127) < 1e-8)
    #expect(abs(solution.outcomes[2].posteriorProbabilities[1] - 0.634920634920635) < 1e-8)
    #expect(abs(solution.outcomes[2].posteriorProbabilities[2] - 0.23809523809523808) < 1e-8)
}

@Test func parsesAndSolvesWinQSBZeroSumGameFixture() throws {
    let url = legacyFixtureURL("GAME.DA_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let game = try WinQSBDecisionAnalysisParser.parseZeroSumGame(from: expanded)
    let solution = try ZeroSumGameSolver.solve(game)

    #expect(game.title == "Marketing Game")
    #expect(game.rowStrategies == ["Strategy1-1", "Strategy1-2", "Strategy1-3", "Strategy1-4", "Strategy1-5"])
    #expect(game.columnStrategies == ["Strategy2-1", "Strategy2-2", "Strategy2-3", "Strategy2-4"])
    #expect(abs(solution.value - 10.265525246662797) < 1e-8)
    #expect(abs(solution.rowStrategy[0].probability - 0) < 1e-8)
    #expect(abs(solution.rowStrategy[1].probability - 0.173824724318050) < 1e-8)
    #expect(abs(solution.rowStrategy[2].probability - 0) < 1e-8)
    #expect(abs(solution.rowStrategy[3].probability - 0.389146836912362) < 1e-8)
    #expect(abs(solution.rowStrategy[4].probability - 0.437028438769588) < 1e-8)
    #expect(abs(solution.columnStrategy[0].probability - 0.515670342426001) < 1e-8)
    #expect(abs(solution.columnStrategy[1].probability - 0.342716192687174) < 1e-8)
    #expect(abs(solution.columnStrategy[2].probability - 0) < 1e-8)
    #expect(abs(solution.columnStrategy[3].probability - 0.141613464886825) < 1e-8)
}

@Test func validatesWinQSBZeroSumGameFixtureWithBackendDiagnostics() throws {
    let url = legacyFixtureURL("GAME.DA_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let game = try WinQSBDecisionAnalysisParser.parseZeroSumGame(from: expanded)
    let diagnostics = ZeroSumGameValidator.diagnostics(for: game)
    let report = ValidationReport(backend: .validateOnly, diagnostics: diagnostics)

    #expect(report.backend == .validateOnly)
    #expect(report.isValid)
    #expect(diagnostics.contains {
        $0.severity == .info && $0.code == "decisionAnalysis.zeroSumGame.valid"
    })
}

@Test func roundTripsNormalizedDecisionAnalysisModelsAndSolutions() throws {
    let fixtures = ["PAYOFF.DA_", "BAYESIAN.DA_", "DTREE.DA_", "GAME.DA_"]
    let backend = NativeEducationalDecisionAnalysisBackend()

    for fixture in fixtures {
        let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL(fixture)))
        let model = try WinQSBDecisionAnalysisParser.parseModelEnvelope(from: expanded)
        let encodedModel = try DecisionAnalysisModelJSON.encodeModel(model)
        #expect(try DecisionAnalysisModelJSON.decodeModel(from: encodedModel) == model)

        let solution = try backend.solve(model)
        #expect(solution.kind == model.kind)
        let document = backend.solutionDocument(for: model, solution: solution)
        let encodedSolution = try DecisionAnalysisModelJSON.encodeSolutionDocument(document)
        #expect(try DecisionAnalysisModelJSON.decodeSolutionDocument(from: encodedSolution) == document)
    }
}

@Test func routesDecisionAnalysisThroughNamedBackendsAndStructuredValidation() throws {
    let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("PAYOFF.DA_")))
    let model = try WinQSBDecisionAnalysisParser.parseModelEnvelope(from: expanded)
    let native = NativeEducationalDecisionAnalysisBackend()
    let validateOnly = ValidateOnlyDecisionAnalysisBackend()

    #expect(native.capabilities.solves)
    #expect(native.runMetadata(for: model).algorithm == "expectedValueOfInformation")
    #expect(native.runMetadata(for: model).exactness == .exact)
    #expect(validateOnly.validationReport(for: model).isValid)
    #expect(DecisionAnalysisBackends.backend(for: .externalHighPerformance) == nil)

    let invalid = DecisionAnalysisModelEnvelope.bayesian(BayesianAnalysisProblem(
        title: "Invalid",
        states: ["A", "B"],
        priorProbabilities: [0.8, 0.8],
        outcomes: ["Yes"],
        likelihoods: [[0.5, 0.5]]
    ))
    let report = validateOnly.validationReport(for: invalid)
    #expect(!report.isValid)
    #expect(report.diagnostics.contains { $0.code == "decisionAnalysis.priors.sum" })
    #expect(report.diagnostics.contains { $0.code == "decisionAnalysis.bayesian.likelihoods.sum" })

    do {
        _ = try validateOnly.solve(model)
        Issue.record("validateOnly unexpectedly solved a decision-analysis model")
    } catch {
        #expect(String(describing: error).contains("validateOnly"))
    }
}

