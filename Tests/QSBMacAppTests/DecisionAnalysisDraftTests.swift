import Foundation
import Testing
import QSBCore
@testable import QSBMacApp

@Test("decision drafts preserve precise values and matrix dimensions")
func decisionDraftRoundTripAndDimensions() throws {
    let model = DecisionPayoffProblem(
        title: "Precise payoff", states: ["Open", "Closed"],
        priorProbabilities: [0.12345678901234567, 0.8765432109876543],
        indicators: ["Positive", "Negative"],
        indicatorLikelihoods: [[0.8123456789012345, 0.21234567890123456],
                               [0.18765432109876545, 0.7876543210987654]],
        decisions: ["Invest", "Wait"],
        payoffs: [[13.123456789012345, -7.123456789012345], [1.0, 2.0]]
    )
    var draft = try #require(DecisionAnalysisDraft(.payoff(model)))
    #expect(try draft.makeModel() == .payoff(model))

    draft.addState()
    #expect(draft.priorProbabilities.count == 3)
    #expect(draft.likelihoods.allSatisfy { $0.count == 3 })
    #expect(draft.payoffs.allSatisfy { $0.count == 3 })
    draft.addObservation()
    draft.addDecision()
    #expect(draft.likelihoods.count == 3)
    #expect(draft.payoffs.count == 3)
    draft.removeState(at: 2)
    draft.removeObservation(at: 2)
    draft.removeDecision(at: 2)
    #expect(try draft.makeModel() == .payoff(model))
}

@Test("decision draft reports field paths for invalid numeric input")
func decisionDraftInputDiagnostics() throws {
    var draft = try #require(DecisionAnalysisDraft.blank(.bayesian))
    draft.likelihoods[1][0] = "not a number"
    #expect(draft.draftDiagnostics().contains { $0.path == "model.likelihoods.1.0" && $0.severity == .error })
    draft.likelihoods[1][0] = "0.2"
    #expect(!draft.draftDiagnostics().contains { $0.severity == .error })
}

@Test("decision spreadsheet transfer keeps states, likelihoods, and payoffs aligned")
func decisionSpreadsheetTransfer() throws {
    var draft = try #require(DecisionAnalysisDraft.blank(.payoff))
    try draft.replaceStates(
        withTabularText: "State\tPrior Probability\nGrowth\t0.6\nRecession\t0.4"
    )
    try draft.replaceLikelihoods(
        withTabularText: "Indicator\tGrowth\tRecession\nPositive\t0.8\t0.2\nNegative\t0.2\t0.8"
    )
    try draft.replacePayoffs(
        withTabularText: "Decision\tGrowth\tRecession\nInvest\t20\t-5\nWait\t4\t4"
    )

    guard case .payoff(let model) = try draft.makeModel() else { Issue.record("Expected payoff model"); return }
    #expect(model.states == ["Growth", "Recession"])
    #expect(model.indicators == ["Positive", "Negative"])
    #expect(model.decisions == ["Invest", "Wait"])
    #expect(model.payoffs == [[20, -5], [4, 4]])
    #expect(draft.statesTabularText().hasPrefix("State\tPrior Probability"))
    #expect(draft.likelihoodsTabularText().hasPrefix("Indicator\tGrowth\tRecession"))

    let before = draft
    #expect(throws: SpreadsheetTransferError.self) {
        try draft.replaceLikelihoods(withTabularText: "Indicator\tGrowth\tWrong\nPositive\t0.8\t0.2")
    }
    #expect(draft == before)
}

@Test("Bayesian spreadsheet transfer uses outcome terminology and remains typed")
func bayesianSpreadsheetTransfer() throws {
    var draft = try #require(DecisionAnalysisDraft.blank(.bayesian))
    try draft.replaceLikelihoods(
        withTabularText: "Outcome\tState 1\tState 2\nYes\t0.7\t0.1\nNo\t0.3\t0.9"
    )
    guard case .bayesian(let model) = try draft.makeModel() else { Issue.record("Expected Bayesian model"); return }
    #expect(model.outcomes == ["Yes", "No"])
    #expect(model.likelihoods == [[0.7, 0.1], [0.3, 0.9]])
}

@Test("payoff and Bayesian drafts validate and solve through the existing backend")
func decisionDraftWorkspaceWorkflow() throws {
    for kind in [DecisionAnalysisProblemKind.payoff, .bayesian] {
        let workspace = QSBWorkspace()
        workspace.startNewDecisionAnalysis(kind)
        #expect(workspace.decisionDraft?.kind == kind)
        workspace.validateCurrentModel()
        #expect(workspace.modelState == .valid)
        workspace.runCurrentModel()
        #expect(workspace.runState == .solved)
        #expect(try #require(workspace.decisionAnalysisSolution).model.kind == kind)
        let model = try DecisionAnalysisModelJSON.decodeModel(from: Data(workspace.modelJSON.utf8))
        #expect(model.kind == kind)
    }
}

@Test("decision samples and JSON Apply select the correct native editor")
func decisionDraftJSONRouting() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.payoffAnalysis)
    #expect(workspace.decisionDraft?.kind == .payoff)

    let replacement = BayesianAnalysisProblem(
        title: "Evidence", states: ["A", "B"], priorProbabilities: [0.25, 0.75],
        outcomes: ["Yes", "No"], likelihoods: [[0.6, 0.2], [0.4, 0.8]]
    )
    workspace.modelJSON = String(decoding: try DecisionAnalysisModelJSON.encodeModel(.bayesian(replacement)), as: UTF8.self)
    workspace.applyDecisionAnalysisJSONToNativeEditor()
    #expect(workspace.decisionDraft?.kind == .bayesian)
    #expect(try workspace.decisionDraft?.makeModel() == .bayesian(replacement))

    let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
    try Data(workspace.modelJSON.utf8).write(to: source)
    defer { try? FileManager.default.removeItem(at: source) }
    let imported = QSBWorkspace()
    imported.importModel(from: source)
    #expect(imported.decisionDraft?.kind == .bayesian)
    #expect(try imported.decisionDraft?.makeModel() == .bayesian(replacement))

    workspace.modelJSON = SampleModels.decisionTreeJSON
    workspace.applyDecisionAnalysisJSONToNativeEditor()
    #expect(workspace.decisionDraft == nil)
    #expect(workspace.decisionTreeDraft != nil)
    #expect(workspace.selectedPane == .model)

    workspace.loadSample(.decisionTree)
    #expect(workspace.decisionDraft == nil)
    #expect(workspace.decisionTreeDraft != nil)
    guard case .decisionAnalysis(.decisionTree) = workspace.currentModelFamily else {
        Issue.record("Decision tree should open in its native editor")
        return
    }
}

@Test("export materializes current native decision values and rejects malformed fields")
func decisionDraftExportUsesCurrentValues() throws {
    let workspace = QSBWorkspace()
    workspace.startNewDecisionAnalysis(.bayesian)
    workspace.updateDecisionDraft { $0.title = "Edited evidence" }
    workspace.beginModelExport()
    #expect(workspace.isExportingModel)
    #expect(try DecisionAnalysisModelJSON.decodeModel(from: Data(workspace.modelDocument.text.utf8)).title == "Edited evidence")

    workspace.isExportingModel = false
    workspace.updateDecisionDraft { $0.priorProbabilities[0] = "oops" }
    workspace.beginModelExport()
    #expect(!workspace.isExportingModel)
    #expect(workspace.validationDiagnostics.contains { $0.path == "model.priorProbabilities.0" })
}
