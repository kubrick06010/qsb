import Foundation
import QSBCore
import Testing

@testable import QSBMacApp

@Test("NLP tables round trip expressions, bounds, and empty constraints")
func nonlinearTablesRoundTrip() throws {
  let model = try NonlinearProgrammingJSON.decodeUncheckedModel(
    from: Data(SampleModels.nonlinearProgrammingJSON.utf8))
  var draft = NonlinearProgrammingDraft(model)
  try draft.replaceVariables(with: draft.variablesTable())
  try draft.replaceConstraints(with: draft.constraintsTable())
  #expect(try draft.makeModel() == model)
  try draft.replaceConstraints(with: "Constraint\tExpression\tRelation\tRHS")
  #expect(draft.constraints.isEmpty)
  let before = draft
  #expect(throws: SpreadsheetTransferError.self) {
    try draft.replaceVariables(with: "Variable\tLower Bound\tUpper Bound\nx\tbad\t10")
  }
  #expect(draft == before)
}

@Test("NLP invalid bounds and expressions remain diagnosable")
func nonlinearInvalidInput() throws {
  var draft = NonlinearProgrammingDraft.blank()
  draft.objectiveExpression = "unknown + ("
  #expect(draft.draftDiagnostics().contains { $0.severity == .error })
  draft.variables[0].upperBound = "bad"
  #expect(throws: OptimizationDraftError.self) { try draft.makeModel() }
  #expect(draft.variables[0].upperBound == "bad")
}

@Test("NLP malformed dimensions are reported without indexing crashes")
func nonlinearMalformedDimensions() throws {
  let model = NonlinearProgram(
    title: "Invalid", sense: .minimize, objectiveExpression: "x^2",
    variableNames: ["x"], lowerBounds: [], upperBounds: [], constraints: [],
    normalizedStrictInequalities: false)
  var draft = NonlinearProgrammingDraft(model)
  #expect(throws: OptimizationDraftError.self) { try draft.makeModel() }
  #expect(draft.draftDiagnostics().contains { $0.severity == .error })
  try draft.replaceVariables(with: "Variable\tLower Bound\tUpper Bound\nx\t0\t10")
  #expect(try draft.makeModel().lowerBounds == [0])
}

@MainActor
@Test("NLP native workspace validates, solves, exports, and undoes edits")
func nonlinearWorkspaceWorkflow() throws {
  let workspace = QSBWorkspace()
  workspace.loadSample(.nonlinearProgramming)
  let original = try #require(workspace.nonlinearProgrammingDraft)
  workspace.validateCurrentModel()
  #expect(workspace.modelState == .valid)
  workspace.runCurrentModel()
  #expect(workspace.runState == .solved)
  var changed = original
  changed.variables[0].upperBound = "bad"
  let undo = UndoManager()
  workspace.replaceNonlinearProgrammingDraft(changed, undoManager: undo)
  workspace.validateCurrentModel()
  #expect(workspace.modelState == .invalid)
  #expect(!workspace.validationDiagnostics.isEmpty)
  undo.undo()
  #expect(workspace.nonlinearProgrammingDraft == original)
  undo.redo()
  #expect(workspace.nonlinearProgrammingDraft == changed)
  undo.undo()
  workspace.beginModelExport()
  #expect(
    try NonlinearProgrammingJSON.decodeUncheckedModel(from: Data(workspace.modelJSON.utf8))
      == original.makeModel())
  workspace.startNewQuadraticProgramming()
  #expect(workspace.nonlinearProgrammingDraft == nil)
}

@MainActor
@Test("NLP file import and explicit JSON Apply use the native draft")
func nonlinearNativeImport() throws {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    .appendingPathExtension("json")
  try Data(SampleModels.nonlinearProgrammingJSON.utf8).write(to: url)
  defer { try? FileManager.default.removeItem(at: url) }
  let workspace = QSBWorkspace()
  workspace.importModel(from: url)
  #expect(workspace.nonlinearProgrammingDraft != nil)
  workspace.modelJSON = SampleModels.nonlinearProgrammingJSON
  workspace.applyNonlinearProgrammingJSONToNativeEditor()
  #expect(workspace.nonlinearProgrammingDraft != nil)
  #expect(workspace.quadraticProgrammingDraft == nil)
  workspace.startNewNonlinearProgramming()
  #expect(workspace.nonlinearProgrammingDraft != nil)
  workspace.validateCurrentModel()
  #expect(workspace.modelState == .valid)
  workspace.startNewQualityControl()
  #expect(workspace.nonlinearProgrammingDraft == nil)
}

@Test("NLP tables repair independently and retain unambiguous row identities")
func nonlinearIndependentSpreadsheetRepair() throws {
  var draft = NonlinearProgrammingDraft.blank()
  draft.title = ""
  draft.objectiveExpression = ""
  draft.constraints = [NonlinearConstraintDraft(name: "c", expression: "unfinished", rhs: "bad")]
  let variableID = draft.variables[0].id
  let constraintID = draft.constraints[0].id
  try draft.replaceVariables(with: "Variable\tLower Bound\tUpper Bound\nx1\t-2\t20")
  #expect(draft.variables[0].id == variableID)
  #expect(draft.constraints[0].rhs == "bad")
  draft.variables[0].upperBound = "unfinished"
  try draft.replaceConstraints(with: "Constraint\tExpression\tRelation\tRHS\nc\tx1^2\t<=\t4")
  #expect(draft.constraints[0].id == constraintID)
  #expect(draft.variables[0].upperBound == "unfinished")
  #expect(draft.title.isEmpty && draft.objectiveExpression.isEmpty)
  let before = draft
  #expect(throws: OptimizationDraftError.self) { try draft.replaceConstraints(with: "c\t\t<=\t4") }
  #expect(draft == before)
  try draft.replaceVariables(with: "Variable\t0\t1")
  #expect(draft.variables[0].name == "Variable")
  try draft.replaceVariables(with: "x\t0\t1\nx\t1\t2")
  #expect(draft.variables[0].id != draft.variables[1].id)
}

@Test("NLP retains excess imported bounds until explicit dimension review")
func nonlinearExcessImportedBounds() throws {
  let model = NonlinearProgram(title: "Review", sense: .minimize, objectiveExpression: "x^2",
    variableNames: ["x"], lowerBounds: [0, -7, nil], upperBounds: [10, 12],
    constraints: [], normalizedStrictInequalities: false)
  var draft = NonlinearProgrammingDraft(model)
  #expect(draft.variables.map(\.name) == ["x", "", ""])
  #expect(draft.variables.map(\.lowerBound) == ["0.0", "-7.0", ""])
  #expect(draft.variables.map(\.upperBound) == ["10.0", "12.0", ""])
  draft.variables[1].name = "y"
  draft.variables[2].name = "z"
  #expect(throws: OptimizationDraftError.self) { try draft.makeModel() }
  let ids = draft.variables.map(\.id)
  draft.confirmImportedDimensions()
  #expect(draft.variables.map(\.id) == ids)
  #expect(try draft.makeModel().lowerBounds == model.lowerBounds)
  #expect(try draft.makeModel().upperBounds == [10, 12, nil])
}

@MainActor
@Test("NLP imported dimension review can be undone without losing bounds")
func nonlinearDimensionReviewUndo() throws {
  let workspace = QSBWorkspace()
  workspace.loadSample(.nonlinearProgramming)
  let model = NonlinearProgram(title: "Review", sense: .minimize, objectiveExpression: "x^2",
    variableNames: ["x"], lowerBounds: [0], upperBounds: [], constraints: [],
    normalizedStrictInequalities: false)
  let original = NonlinearProgrammingDraft(model)
  workspace.replaceNonlinearProgrammingDraft(original)
  var reviewed = original
  reviewed.confirmImportedDimensions()
  let undo = UndoManager()
  workspace.replaceNonlinearProgrammingDraft(reviewed, undoManager: undo, actionName: "Review Imported Dimensions")
  #expect(try reviewed.makeModel().upperBounds == [nil])
  undo.undo()
  #expect(workspace.nonlinearProgrammingDraft == original)
  undo.redo()
  #expect(workspace.nonlinearProgrammingDraft == reviewed)
}
