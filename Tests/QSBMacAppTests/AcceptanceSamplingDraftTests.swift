import Foundation
import Testing
import QSBCore
@testable import QSBMacApp

@Test("acceptance-sampling drafts round trip single and double plans")
func acceptanceSamplingDraftRoundTrip() throws {
    let single = try AcceptanceSamplingJSON.decodeModel(from: Data(SampleModels.acceptanceSamplingJSON.utf8))
    #expect(try AcceptanceSamplingDraft(single).makeModel() == single)

    var doubleDraft = AcceptanceSamplingDraft.blank(.double)
    doubleDraft.title = "Two Stage Inspection"
    let double = try doubleDraft.makeModel()
    #expect(try AcceptanceSamplingDraft(double).makeModel() == double)
    #expect(!doubleDraft.draftDiagnostics().contains { $0.severity == .error })
}

@MainActor
@Test("workspace routes native acceptance-sampling drafts through validation solving and export")
func acceptanceSamplingWorkspaceWorkflow() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.acceptanceSampling)
    #expect(workspace.acceptanceSamplingDraft != nil)
    workspace.validateCurrentModel()
    #expect(workspace.modelState == .valid)
    workspace.runCurrentModel()
    #expect(workspace.runState == .solved)
    workspace.beginModelExport()
    #expect(workspace.isExportingModel)
    let decoded = try AcceptanceSamplingJSON.decodeModel(from: Data(workspace.modelJSON.utf8))
    #expect(decoded.title == "Incoming Lot Inspection")
}

@MainActor
@Test("acceptance-sampling invalid fields and undo redo stay in the native draft")
func acceptanceSamplingInvalidStateAndUndo() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.acceptanceSampling)
    let original = try #require(workspace.acceptanceSamplingDraft)
    var changed = original
    changed.sampleSize = "invalid"
    let undoManager = UndoManager()
    workspace.replaceAcceptanceSamplingDraft(changed, undoManager: undoManager, actionName: "Edit Sample Size")
    workspace.validateCurrentModel()
    #expect(workspace.modelState == .invalid)
    #expect(workspace.validationDiagnostics.contains { $0.path?.contains("sampleSize") == true })
    undoManager.undo()
    #expect(workspace.acceptanceSamplingDraft == original)
    undoManager.redo()
    #expect(workspace.acceptanceSamplingDraft == changed)
}
