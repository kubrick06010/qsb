import Foundation
import QSBCore
import Testing

@testable import QSBMacApp

@Test("Line task table round trips IDs, integer times, isolation, and successor lists")
func lineDraftRoundTrip() throws {
  let problem = LineBalancingProblem(
    title: "Line", timeUnit: "second", cycleTime: 10,
    tasks: [
      LineBalancingTask(id: 7, name: "Prepare", time: 2, isolated: false, successorIDs: [9, 11]),
      LineBalancingTask(id: 9, name: "Inspect", time: 3, isolated: true, successorIDs: []),
      LineBalancingTask(id: 11, name: "Pack", time: 2, isolated: false, successorIDs: []),
    ])
  var draft = LineBalancingDraft(problem)
  try draft.replaceTasks(with: draft.tasksTable())
  #expect(try draft.makeProblem() == problem)
  draft.tasks[0].successors = "9, 11"
  #expect(try draft.makeProblem().tasks[0].successorIDs == [9, 11])
  draft.tasks[0].successors = "9;11"
  #expect(try draft.makeProblem().tasks[0].successorIDs == [9, 11])
  let before = draft
  #expect(throws: OptimizationDraftError.self) {
    try draft.replaceTasks(
      with: "ID\tTask\tTime\tIsolated\tSuccessor IDs\n7\tPrepare\t2.5\tfalse\t9")
  }
  #expect(draft == before)
  #expect(throws: SpreadsheetTransferError.self) {
    try draft.replaceTasks(with: "ID\tTask\tTime\tIsolated\tSuccessor IDs\n7\tPrepare\t2\tmaybe\t9")
  }
  #expect(draft == before)
}

@Test("Line row removal retains missing successors for diagnosis and reordering retains IDs")
func lineDraftRowOperations() throws {
  var draft = LineBalancingDraft.blank()
  let second = draft.addTask()
  let secondSourceID = draft.tasks[1].sourceID
  draft.tasks[0].successors = secondSourceID
  draft.moveTask(id: second, by: -1)
  #expect(draft.tasks[0].id == second)
  #expect(draft.tasks[1].successors == secondSourceID)
  draft.removeTask(id: second)
  #expect(draft.tasks[0].successors == secondSourceID)
  #expect(
    draft.draftDiagnostics().contains { $0.code == "facilities.lineBalancing.successors.missing" })
}

@Test("Line invalid task references, cycles, bounds, and IDs use core diagnostics")
func lineDraftInvalidInput() throws {
  var draft = LineBalancingDraft.blank()
  _ = draft.addTask()
  draft.tasks[0].successors = "2"
  draft.tasks[1].successors = "1"
  #expect(
    draft.draftDiagnostics().contains { $0.code == "facilities.lineBalancing.precedence.cycle" })
  draft.tasks[1].sourceID = "1"
  #expect(
    draft.draftDiagnostics().contains { $0.code == "facilities.lineBalancing.tasks.duplicate" })
  draft.tasks[0].time = "bad"
  #expect(throws: OptimizationDraftError.self) { try draft.makeProblem() }
  #expect(draft.tasks[0].time == "bad")
  #expect(draft.draftDiagnostics().first?.message.contains("duration of Task 1") == true)
}

@MainActor
@Test("Line native workflow validates, solves, exports, and undoes removed dependencies")
func lineNativeWorkflow() throws {
  let workspace = QSBWorkspace()
  workspace.loadSample(.lineBalancing)
  let original = try #require(workspace.lineBalancingDraft)
  workspace.validateCurrentModel()
  #expect(workspace.modelState == .valid)
  workspace.runCurrentModel()
  #expect(workspace.runState == .solved)
  var changed = original
  changed.tasks[0].time = "bad"
  let undo = UndoManager()
  workspace.replaceLineBalancingDraft(changed, undoManager: undo)
  workspace.validateCurrentModel()
  #expect(workspace.modelState == .invalid && !workspace.validationDiagnostics.isEmpty)
  undo.undo()
  #expect(workspace.lineBalancingDraft == original)
  undo.redo()
  #expect(workspace.lineBalancingDraft == changed)
  undo.undo()
  var missingDependency = original
  missingDependency.removeTask(id: try #require(original.tasks.last).id)
  workspace.replaceLineBalancingDraft(missingDependency, undoManager: undo)
  workspace.validateCurrentModel()
  #expect(workspace.validationDiagnostics.contains { $0.code == "facilities.lineBalancing.successors.missing" })
  undo.undo()
  #expect(workspace.lineBalancingDraft == original)
  workspace.beginModelExport()
  #expect(
    try FacilitiesModelJSON.decodeUncheckedModel(from: Data(workspace.modelJSON.utf8))
      == .lineBalancing(original.makeProblem()))
  workspace.startNewFacilityLocation()
  #expect(workspace.lineBalancingDraft == nil)
}

@MainActor
@Test("Line native import, creation, and JSON Apply distinguish facilities kinds")
func lineNativeImport() throws {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    .appendingPathExtension("json")
  try Data(SampleModels.lineBalancingJSON.utf8).write(to: url)
  defer { try? FileManager.default.removeItem(at: url) }
  let workspace = QSBWorkspace()
  workspace.importModel(from: url)
  #expect(workspace.lineBalancingDraft != nil)
  workspace.startNewLineBalancing()
  workspace.validateCurrentModel()
  #expect(workspace.modelState == .valid)
  workspace.modelJSON = SampleModels.lineBalancingJSON
  workspace.applyLineBalancingJSONToNativeEditor()
  #expect(workspace.lineBalancingDraft != nil && workspace.facilityLocationDraft == nil)
  let previous = workspace.lineBalancingDraft
  workspace.modelJSON = SampleModels.facilityLocationJSON
  workspace.applyLineBalancingJSONToNativeEditor()
  #expect(workspace.lineBalancingDraft == previous)
  workspace.applyFacilityLocationJSONToNativeEditor()
  #expect(workspace.lineBalancingDraft == nil && workspace.facilityLocationDraft != nil)
  workspace.startNewGoalProgramming()
  #expect(workspace.lineBalancingDraft == nil)
}

@Test("line table repairs independently and matches task identity by numeric source ID")
func lineIndependentTableRepair() throws {
  var draft = LineBalancingDraft.blank()
  let first = draft.tasks[0].id
  let second = draft.addTask()
  draft.title = ""
  draft.cycleTime = "unfinished"
  try draft.replaceTasks(with: "id\ttask\ttime\tisolated\tsuccessor ids\n2\tRenamed second\t3\ttrue\t\n01\tRenamed first\t2\tfalse\t2")
  #expect(draft.tasks.map(\.id) == [second, first])
  #expect(draft.tasks[1].sourceID == "01" && draft.tasks[1].successors == "2")
  #expect(draft.title.isEmpty && draft.cycleTime == "unfinished")
  let before = draft
  #expect(throws: OptimizationDraftError.self) {
    try draft.replaceTasks(with: "1\tPrepare\t2\tfalse\t2\n2\tInspect\t3\ttrue\tunfinished")
  }
  #expect(draft == before)
  draft.title = "Repaired line"
  draft.cycleTime = "10"
  #expect(!draft.draftDiagnostics().contains { $0.severity == .error })
  #expect(try draft.makeProblem().tasks.map(\.id) == [2, 1])
}

@Test("line duplicate numeric IDs get separate identities and remain core validation errors")
func lineAmbiguousTableRows() throws {
  var draft = LineBalancingDraft.blank()
  let old = draft.tasks[0].id
  try draft.replaceTasks(with: "1\tPrepare\t2\tfalse\t\n01\tInspect\t3\ttrue\t")
  #expect(Set(draft.tasks.map(\.id)).count == 2)
  #expect(!draft.tasks.contains { $0.id == old })
  #expect(draft.draftDiagnostics().contains { $0.code == "facilities.lineBalancing.tasks.duplicate" })
}

@MainActor
@Test("line independent paste preserves broken settings and dependencies through undo redo")
func lineTableRepairUndo() throws {
  let workspace = QSBWorkspace()
  workspace.loadSample(.lineBalancing)
  var original = try #require(workspace.lineBalancingDraft)
  original.cycleTime = "unfinished"
  workspace.replaceLineBalancingDraft(original)
  let manager = UndoManager()
  var pasted = original
  var rows = pasted.tasksTable().components(separatedBy: "\n")
  rows.removeFirst()
  try pasted.replaceTasks(with: rows.reversed().joined(separator: "\n"))
  workspace.replaceLineBalancingDraft(pasted, undoManager: manager, actionName: "Paste Tasks")
  workspace.validateCurrentModel()
  #expect(workspace.modelState == .invalid)
  #expect(pasted.tasks.map(\.id) == original.tasks.map(\.id).reversed())
  manager.undo()
  #expect(workspace.lineBalancingDraft == original)
  manager.redo()
  #expect(workspace.lineBalancingDraft == pasted)
}
