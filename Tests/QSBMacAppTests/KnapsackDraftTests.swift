import Foundation
import Testing
import QSBCore
@testable import QSBMacApp

@Test("bounded-knapsack draft round trips through the normalized envelope")
func knapsackDraftRoundTrip() throws {
    let envelope = try DynamicProgrammingModelJSON.decodeUncheckedModel(from: Data(SampleModels.boundedKnapsackJSON.utf8))
    guard case .boundedKnapsack(let problem) = envelope else {
        Issue.record("Expected bounded knapsack")
        return
    }
    let draft = KnapsackDraft(problem)
    #expect(try draft.makeProblem() == problem)
    #expect(!draft.draftDiagnostics().contains { $0.severity == .error })
}

@Test("bounded-knapsack spreadsheet transfer is complete and atomic")
func knapsackSpreadsheetTransfer() throws {
    let envelope = try DynamicProgrammingModelJSON.decodeUncheckedModel(from: Data(SampleModels.boundedKnapsackJSON.utf8))
    guard case .boundedKnapsack(let problem) = envelope else { return }
    var draft = KnapsackDraft(problem)
    let table = draft.tabularText()
    try draft.replaceItems(withTabularText: table)
    #expect(try draft.makeProblem() == problem)

    let before = draft
    var rows = try SpreadsheetTable(text: table).rows
    rows[1][1] = "invalid"
    let invalid = rows.map { $0.joined(separator: "\t") }.joined(separator: "\n")
    #expect(throws: SpreadsheetTransferError.self) { try draft.replaceItems(withTabularText: invalid) }
    #expect(draft == before)
}

@MainActor
@Test("workspace routes native bounded-knapsack drafts through validation solving and export")
func knapsackWorkspaceWorkflow() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.boundedKnapsack)
    #expect(workspace.knapsackDraft != nil)
    guard case .dynamicProgramming(.boundedKnapsack) = workspace.currentModelFamily else {
        Issue.record("Expected bounded-knapsack family")
        return
    }
    workspace.validateCurrentModel()
    #expect(workspace.modelState == .valid)
    workspace.runCurrentModel()
    #expect(workspace.runState == .solved)
    workspace.beginModelExport()
    #expect(workspace.isExportingModel)
    let envelope = try DynamicProgrammingModelJSON.decodeUncheckedModel(from: Data(workspace.modelJSON.utf8))
    guard case .boundedKnapsack(let problem) = envelope else { return }
    #expect(problem.items.count == 4)
}

@MainActor
@Test("bounded-knapsack invalid fields and undo redo stay in the native draft")
func knapsackInvalidStateAndUndo() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.boundedKnapsack)
    let original = try #require(workspace.knapsackDraft)
    var changed = original
    changed.items[0].available = "invalid"
    let undoManager = UndoManager()
    workspace.replaceKnapsackDraft(changed, undoManager: undoManager, actionName: "Edit Availability")
    workspace.validateCurrentModel()
    #expect(workspace.modelState == .invalid)
    #expect(workspace.validationDiagnostics.contains { $0.path?.contains("available") == true })
    undoManager.undo()
    #expect(workspace.knapsackDraft == original)
    undoManager.redo()
    #expect(workspace.knapsackDraft == changed)
}

@Test("knapsack table repairs independently and retains identities through reorder")
func knapsackIndependentTableRepair() throws {
    var draft = KnapsackDraft.blank()
    draft.items[0].name = "Item"
    let first = draft.items[0].id
    let second = draft.addItem()
    draft.title = ""
    draft.capacity = "unfinished"
    try draft.replaceItems(withTabularText: "Item 2\t3\t2\t9\nItem\t4\t1\t5")
    #expect(draft.items.map(\.id) == [second, first])
    #expect(draft.items.map(\.name) == ["Item 2", "Item"])
    #expect(draft.title.isEmpty && draft.capacity == "unfinished")
    #expect(throws: KnapsackDraftError.self) { try draft.makeProblem() }
    let before = draft
    for invalid in [" \t1\t1\t3", "Item\t1.5\t1\t3", "Item\t1\t1\tinf"] {
        #expect(throws: SpreadsheetTransferError.self) { try draft.replaceItems(withTabularText: invalid) }
        #expect(draft == before)
    }
    draft.title = "Repaired"
    draft.capacity = "10"
    #expect(!draft.draftDiagnostics().contains { $0.severity == .error })
}

@Test("ambiguous knapsack names receive distinct identities and core duplicate diagnostics")
func knapsackAmbiguousTableRows() throws {
    var draft = KnapsackDraft.blank()
    draft.items[0].name = "Item"
    let old = draft.items[0].id
    try draft.replaceItems(withTabularText: "item\tavailable\tcapacity required\treturn per unit\nItem\t1\t1\t3\nItem\t2\t1\t4")
    #expect(Set(draft.items.map(\.id)).count == 2)
    #expect(!draft.items.contains { $0.id == old })
    #expect(draft.draftDiagnostics().contains { $0.code.contains("name.duplicate") })
}

@MainActor
@Test("independent knapsack paste preserves unfinished settings through undo redo")
func knapsackTableRepairUndo() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.boundedKnapsack)
    var original = try #require(workspace.knapsackDraft)
    original.capacity = "unfinished"
    workspace.replaceKnapsackDraft(original)
    let manager = UndoManager()
    var pasted = original
    var rows = pasted.tabularText().components(separatedBy: "\n")
    rows.removeFirst()
    try pasted.replaceItems(withTabularText: rows.reversed().joined(separator: "\n"))
    workspace.replaceKnapsackDraft(pasted, undoManager: manager, actionName: "Paste Items")
    workspace.validateCurrentModel()
    #expect(workspace.modelState == .invalid)
    #expect(pasted.items.map(\.id) == original.items.map(\.id).reversed())
    manager.undo()
    #expect(workspace.knapsackDraft == original)
    manager.redo()
    #expect(workspace.knapsackDraft == pasted)
}
