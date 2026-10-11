import Foundation
import Testing
import QSBCore
@testable import QSBMacApp

@Test("decision tree draft preserves node topology and optional numeric values")
func decisionTreeDraftRoundTrip() throws {
    let tree = DecisionTree(
        title: "Precise tree", rootID: 9,
        nodes: [
            DecisionTreeNode(id: 9, name: "Choose", kind: .decision, childIDs: [5, 7], payoff: 1.25),
            DecisionTreeNode(id: 5, name: "Risk", kind: .chance, childIDs: [10, 11], probability: 0.4),
            DecisionTreeNode(id: 7, name: "Certain", kind: .terminal, childIDs: [], payoff: 4, probability: 0.6),
            DecisionTreeNode(id: 10, name: "Win", kind: .terminal, childIDs: [], payoff: 1.2345678901234567, probability: 0.25),
            DecisionTreeNode(id: 11, name: "Lose", kind: .terminal, childIDs: [], payoff: -2.5, probability: 0.75)
        ]
    )
    var draft = try #require(DecisionTreeDraft(.decisionTree(tree)))
    #expect(try draft.makeModel() == .decisionTree(tree))

    draft.nodes[0].childIDs = "5, broken"
    #expect(draft.draftDiagnostics().contains { $0.path == "model.nodes.9.childIDs" && $0.severity == .error })
    #expect(!draft.canAddTerminalChild(to: 9))
    let unchanged = draft
    draft.addTerminalChild(to: 9)
    #expect(draft == unchanged)

    draft.nodes[0].childIDs = "5, 7"
    draft.nodes[3].probability = "NaN"
    #expect(draft.draftDiagnostics().contains { $0.path == "model.nodes.10.probability" })
}

@Test("decision tree draft adds and removes a leaf while preserving parent links")
func decisionTreeDraftStructuralEdits() throws {
    var draft = DecisionTreeDraft.blank()
    let original = try draft.makeModel()
    draft.addTerminalChild(to: 1)
    #expect(draft.nodes.map(\.id) == [1, 2, 3, 4])
    #expect(draft.nodes[0].childIDs == "2, 3, 4")
    #expect(try draft.makeModel() != original)
    draft.removeLeaf(id: 4)
    #expect(try draft.makeModel() == original)
    #expect(!draft.canRemoveLeaf(id: 1))
    #expect(!draft.canAddTerminalChild(to: 2))
}

@Test("decision tree new, sample, import, JSON Apply, validation, solve, and export route through QSBCore")
func decisionTreeDraftWorkspaceWorkflow() throws {
    let workspace = QSBWorkspace()
    workspace.startNewDecisionAnalysis(.decisionTree)
    #expect(workspace.decisionTreeDraft != nil)
    if case .decisionAnalysis(.decisionTree) = workspace.currentModelFamily {
        #expect(true)
    } else {
        Issue.record("Expected a decision tree model")
    }
    workspace.validateCurrentModel()
    #expect(workspace.modelState == .valid)
    workspace.runCurrentModel()
    #expect(workspace.runState == .solved)
    #expect(try #require(workspace.decisionAnalysisSolution).model.kind == .decisionTree)

    workspace.updateDecisionTreeDraft { $0.nodes[1].payoff = "7" }
    workspace.beginModelExport()
    #expect(workspace.isExportingModel)
    let exported = try DecisionAnalysisModelJSON.decodeModel(from: Data(workspace.modelDocument.text.utf8))
    #expect(exported.kind == .decisionTree)
    workspace.isExportingModel = false
    workspace.updateDecisionTreeDraft { $0.nodes[1].payoff = "bad" }
    workspace.beginModelExport()
    #expect(!workspace.isExportingModel)
    #expect(workspace.validationDiagnostics.contains { $0.path == "model.nodes.2.payoff" })

    workspace.loadSample(.decisionTree)
    #expect(workspace.decisionTreeDraft != nil)
    workspace.applyDecisionAnalysisJSONToNativeEditor()
    #expect(workspace.selectedPane == .model)

    let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
    try Data(SampleModels.decisionTreeJSON.utf8).write(to: source)
    defer { try? FileManager.default.removeItem(at: source) }
    let imported = QSBWorkspace()
    imported.importModel(from: source)
    #expect(imported.decisionTreeDraft != nil)
    #expect(try imported.decisionTreeDraft?.makeModel() == DecisionAnalysisModelJSON.decodeModel(from: Data(SampleModels.decisionTreeJSON.utf8)))
}
