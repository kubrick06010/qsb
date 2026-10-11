import Foundation
import Testing
import QSBCore
@testable import QSBMacApp

@Test("zero-sum draft preserves imported values while resizing both strategy axes")
func zeroSumDraftRoundTripAndDimensions() throws {
    let game = ZeroSumGame(
        title: "Precise game",
        rowStrategies: ["Up", "Down"], columnStrategies: ["Left", "Right"],
        payoffs: [[1.2345678901234567, -2.5], [3.0, 0.125]]
    )
    var draft = try #require(ZeroSumGameDraft(.zeroSumGame(game)))
    #expect(try draft.makeModel() == .zeroSumGame(game))
    draft.addRowStrategy()
    draft.addColumnStrategy()
    #expect(draft.payoffs.count == 3)
    #expect(draft.payoffs.allSatisfy { $0.count == 3 })
    draft.removeRowStrategy(at: 2)
    draft.removeColumnStrategy(at: 2)
    #expect(try draft.makeModel() == .zeroSumGame(game))

    draft.payoffs[1][0] = "NaN"
    #expect(draft.draftDiagnostics().contains { $0.path == "model.payoffs.1.0" && $0.severity == .error })
}

@Test("zero-sum spreadsheet transfer replaces strategy names and payoffs atomically")
func zeroSumSpreadsheetTransfer() throws {
    var draft = ZeroSumGameDraft.blank()
    try draft.replaceTable(
        withTabularText: """
        Player 1 / Player 2\tLeft\tCenter\tRight
        Up\t2\t0\t-1
        Down\t-2\t1\t3
        """
    )
    guard case .zeroSumGame(let model) = try draft.makeModel() else { Issue.record("Expected zero-sum model"); return }
    #expect(model.rowStrategies == ["Up", "Down"])
    #expect(model.columnStrategies == ["Left", "Center", "Right"])
    #expect(model.payoffs == [[2, 0, -1], [-2, 1, 3]])
    #expect(draft.tabularText().hasPrefix("Player 1 / Player 2\tLeft\tCenter\tRight"))

    let before = draft
    #expect(throws: SpreadsheetTransferError.self) {
        try draft.replaceTable(withTabularText: "Player 1 / Player 2\tLeft\nUp\tnot-a-number")
    }
    #expect(draft == before)
}

@Test("new zero-sum game validates, solves, and exports through the shared decision backend")
func zeroSumDraftWorkspaceWorkflow() throws {
    let workspace = QSBWorkspace()
    workspace.startNewDecisionAnalysis(.zeroSumGame)
    #expect(workspace.zeroSumGameDraft != nil)
    #expect(workspace.decisionDraft == nil)
    workspace.validateCurrentModel()
    #expect(workspace.modelState == .valid)
    workspace.runCurrentModel()
    #expect(workspace.runState == .solved)
    #expect(try #require(workspace.decisionAnalysisSolution).model.kind == .zeroSumGame)

    workspace.updateZeroSumGameDraft { $0.title = "Edited game" }
    workspace.beginModelExport()
    #expect(workspace.isExportingModel)
    #expect(try DecisionAnalysisModelJSON.decodeModel(from: Data(workspace.modelDocument.text.utf8)).title == "Edited game")
    workspace.isExportingModel = false
    workspace.updateZeroSumGameDraft { $0.payoffs[0][0] = "invalid" }
    workspace.beginModelExport()
    #expect(!workspace.isExportingModel)
    #expect(workspace.validationDiagnostics.contains { $0.path == "model.payoffs.0.0" })
}

@Test("zero-sum JSON import and Apply route to the matching native editor")
func zeroSumDraftJSONRouting() throws {
    let game = ZeroSumGame(
        title: "Imported game", rowStrategies: ["A", "B"],
        columnStrategies: ["X", "Y"], payoffs: [[1, -1], [-1, 1]]
    )
    let json = String(decoding: try DecisionAnalysisModelJSON.encodeModel(.zeroSumGame(game)), as: UTF8.self)
    let workspace = QSBWorkspace(modelJSON: json)
    #expect(try workspace.zeroSumGameDraft?.makeModel() == .zeroSumGame(game))

    let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
    try Data(json.utf8).write(to: source)
    defer { try? FileManager.default.removeItem(at: source) }
    let imported = QSBWorkspace()
    imported.importModel(from: source)
    #expect(try imported.zeroSumGameDraft?.makeModel() == .zeroSumGame(game))

    workspace.modelJSON = SampleModels.decisionTreeJSON
    workspace.applyDecisionAnalysisJSONToNativeEditor()
    #expect(workspace.zeroSumGameDraft == nil)
    #expect(workspace.decisionTreeDraft != nil)
    #expect(workspace.selectedPane == .model)

    workspace.loadSample(.payoffAnalysis)
    #expect(workspace.zeroSumGameDraft == nil)
    #expect(workspace.decisionDraft?.kind == .payoff)
}
