import Foundation
import QSBCore
import Testing

@testable import QSBMacApp

@Test("Goal draft tables preserve priority order and variable coefficients")
func goalDraftTablesRoundTrip() throws {
  let model = GoalProgram(
    title: "Priorities", variableNames: ["a", "b"],
    goals: [
      GoalObjective(name: "Profit", sense: .maximize, coefficients: [3, 7]),
      GoalObjective(name: "Cost", sense: .minimize, coefficients: [2, 5]),
    ],
    constraints: [
      LinearConstraint(name: "Capacity", coefficients: [4, 6], relation: .lessThanOrEqual, rhs: 20)
    ],
    lowerBounds: [0, 0], upperBounds: [10, 12], variableTypes: [.continuous, .continuous])
  var draft = GoalProgrammingDraft(model)
  try draft.replaceVariables(with: draft.variablesTable())
  try draft.replaceGoals(with: draft.goalsTable())
  try draft.replaceConstraints(with: draft.constraintsTable())
  #expect(try draft.makeModel() == model)
  try draft.replaceVariables(
    with: "Variable\tType\tLower Bound\tUpper Bound\nb\tcontinuous\t0\t12\na\tcontinuous\t0\t10")
  #expect(try draft.makeModel().goals[0].coefficients == [7, 3])
  #expect(try draft.makeModel().constraints[0].coefficients == [6, 4])
  let before = draft
  #expect(throws: SpreadsheetTransferError.self) {
    try draft.replaceGoals(with: "Goal\tSense\ta\tb\nProfit\tmax\t3\t7")
  }
  #expect(draft == before)
  #expect(throws: SpreadsheetTransferError.self) {
    try draft.replaceVariables(
      with: "Variable\tType\tLower Bound\tUpper Bound\na\tcontinuous\tbad\t10")
  }
  #expect(draft == before)
  try draft.replaceConstraints(with: "Constraint\tb\ta\tRelation\tRHS")
  #expect(draft.constraints.isEmpty)
}

@Test("Goal row operations maintain dimensions and reorder priorities")
func goalDraftRowOperations() throws {
  var draft = GoalProgrammingDraft.blank()
  let id = draft.addVariable()
  let second = draft.addGoal()
  let constraint = draft.addConstraint()
  draft.moveGoal(id: second, by: -1)
  #expect(draft.goals[0].id == second)
  draft.moveGoal(id: second, by: -1)
  #expect(draft.goals[0].id == second)
  draft.removeVariable(id: id)
  #expect(draft.goals.allSatisfy { $0.coefficients.count == 1 })
  #expect(draft.constraints.allSatisfy { $0.coefficients.count == 1 })
  draft.removeConstraint(id: constraint)
  draft.removeGoal(id: second)
  #expect(draft.goals.count == 1)
  #expect(try draft.makeModel().variableNames == ["x1"])
}

@Test("Goal malformed imported dimensions and invalid entries produce diagnostics")
func goalDraftInvalidInput() throws {
  let model = GoalProgram(
    title: "Malformed", variableNames: ["x"], goals: [], constraints: [], lowerBounds: [],
    upperBounds: [], variableTypes: [])
  let draft = GoalProgrammingDraft(model)
  #expect(throws: OptimizationDraftError.self) { try draft.makeModel() }
  #expect(draft.draftDiagnostics().contains { $0.severity == .error })
  var valid = GoalProgrammingDraft.blank()
  valid.goals[0].coefficients[0] = "bad"
  #expect(valid.draftDiagnostics().contains { $0.severity == .error })
  #expect(valid.goals[0].coefficients[0] == "bad")
}

@MainActor
@Test("Goal native workspace validates, solves, exports, and supports undo/redo")
func goalDraftWorkspaceWorkflow() throws {
  let workspace = QSBWorkspace()
  workspace.loadSample(.goalProgramming)
  let original = try #require(workspace.goalProgrammingDraft)
  workspace.validateCurrentModel()
  #expect(workspace.modelState == .valid)
  workspace.runCurrentModel()
  #expect(workspace.runState == .solved)
  var changed = original
  changed.goals[0].coefficients[0] = "bad"
  let undo = UndoManager()
  workspace.replaceGoalProgrammingDraft(changed, undoManager: undo)
  workspace.validateCurrentModel()
  #expect(workspace.modelState == .invalid)
  #expect(!workspace.validationDiagnostics.isEmpty)
  undo.undo()
  #expect(workspace.goalProgrammingDraft == original)
  undo.redo()
  #expect(workspace.goalProgrammingDraft == changed)
  undo.undo()
  workspace.beginModelExport()
  #expect(
    try GoalProgrammingJSON.decodeModel(from: Data(workspace.modelJSON.utf8))
      == original.makeModel())
  workspace.startNewNonlinearProgramming()
  #expect(workspace.goalProgrammingDraft == nil)
}

@MainActor
@Test("Goal native import, new model, and JSON Apply clear other family drafts")
func goalDraftImportAndCreation() throws {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    .appendingPathExtension("json")
  try Data(SampleModels.goalProgrammingJSON.utf8).write(to: url)
  defer { try? FileManager.default.removeItem(at: url) }
  let workspace = QSBWorkspace()
  workspace.importModel(from: url)
  #expect(workspace.goalProgrammingDraft != nil)
  workspace.startNewGoalProgramming()
  workspace.validateCurrentModel()
  #expect(workspace.modelState == .valid)
  workspace.modelJSON = SampleModels.nonlinearProgrammingJSON
  workspace.applyNonlinearProgrammingJSONToNativeEditor()
  #expect(workspace.goalProgrammingDraft == nil)
  workspace.modelJSON = SampleModels.goalProgrammingJSON
  workspace.applyGoalProgrammingJSONToNativeEditor()
  #expect(workspace.goalProgrammingDraft != nil)
  #expect(workspace.nonlinearProgrammingDraft == nil)
  workspace.startNewQualityControl()
  #expect(workspace.goalProgrammingDraft == nil)
}

@Test("Goal malformed dimensions retain extra coefficients and require explicit repair")
func goalImportedDimensionRepair() throws {
  let model = GoalProgram(title: "Incomplete", variableNames: ["a"], goals: [
    GoalObjective(name: "Profit", sense: .maximize, coefficients: [2, 5]),
    GoalObjective(name: "Cost", sense: .minimize, coefficients: [1, 3])
  ], constraints: [LinearConstraint(name: "Capacity", coefficients: [4, 6], relation: .lessThanOrEqual, rhs: 20)],
    lowerBounds: [], upperBounds: [], variableTypes: [])
  var draft = GoalProgrammingDraft(model)
  #expect(draft.variables.count == 2)
  #expect(draft.goals.map(\.coefficients) == [["2.0", "5.0"], ["1.0", "3.0"]])
  #expect(draft.constraints[0].coefficients == ["4.0", "6.0"])
  draft.confirmImportedDimensions()
  #expect(throws: OptimizationDraftError.self) { try draft.makeModel() }
  draft.variables[1].name = "b"
  draft.variables[0].lowerBound = "0"
  #expect(throws: OptimizationDraftError.self) { try draft.makeModel() }
  draft.variables[1].lowerBound = "0"
  let repaired = try draft.makeModel()
  #expect(repaired.goals == model.goals)
  #expect(repaired.constraints == model.constraints)
  #expect(repaired.variableTypes == [.continuous, .continuous])
  #expect(repaired.upperBounds == [nil, nil])
}

@Test("Goal section pastes repair independently while retaining atomic errors and row identities")
func goalIndependentTableRepair() throws {
  let model = GoalProgram(title: "Repair", variableNames: ["a", "b"], goals: [
    GoalObjective(name: "Profit", sense: .maximize, coefficients: [])
  ], constraints: [LinearConstraint(name: "Capacity", coefficients: [], relation: .lessThanOrEqual, rhs: 20)],
    lowerBounds: [], upperBounds: [], variableTypes: [])
  var draft = GoalProgrammingDraft(model)
  let identities = draft.variables.map(\.id)
  try draft.replaceVariables(with: "Variable\tType\tLower Bound\tUpper Bound\na\tcontinuous\t0\t10\nb\tcontinuous\t0\t10")
  #expect(!draft.hasImportedDimensionIssue)
  #expect(draft.variables.map(\.id) == identities)
  #expect(draft.draftDiagnostics().contains { $0.severity == .error })
  try draft.replaceGoals(with: "Goal\tSense\ta\tb\nProfit\tmaximize\t2\t5")
  #expect(draft.draftDiagnostics().contains { $0.severity == .error })
  try draft.replaceConstraints(with: "Constraint\ta\tb\tRelation\tRHS\nCapacity\t4\t6\t<=\t20")
  #expect(draft.draftDiagnostics().allSatisfy { $0.severity != .error })
  let before = draft
  #expect(throws: SpreadsheetTransferError.self) {
    try draft.replaceVariables(with: "a\tcontinuous\t\t10")
  }
  #expect(draft == before)
  draft.title = ""
  try draft.replaceConstraints(with: "Constraint\ta\tb\tRelation\tRHS")
  #expect(draft.constraints.isEmpty)
  #expect(draft.title.isEmpty)
}

@MainActor
@Test("Goal dimension review supports workspace undo redo")
func goalDimensionReviewUndo() throws {
  let workspace = QSBWorkspace()
  workspace.loadSample(.goalProgramming)
  let model = GoalProgram(title: "Review", variableNames: ["a"], goals: [
    GoalObjective(name: "Profit", sense: .maximize, coefficients: [1])
  ], constraints: [], lowerBounds: [0], upperBounds: [], variableTypes: [])
  let original = GoalProgrammingDraft(model)
  workspace.replaceGoalProgrammingDraft(original)
  var reviewed = original
  reviewed.confirmImportedDimensions()
  let undoManager = UndoManager()
  workspace.replaceGoalProgrammingDraft(reviewed, undoManager: undoManager, actionName: "Review Dimensions")
  workspace.validateCurrentModel()
  #expect(workspace.modelState == .valid)
  undoManager.undo()
  #expect(workspace.goalProgrammingDraft == original)
  workspace.validateCurrentModel()
  #expect(workspace.modelState == .invalid)
  undoManager.redo()
  #expect(workspace.goalProgrammingDraft == reviewed)
}

@MainActor
@Test("Dense Goal tables retain all coefficients through priority movement, paste, and undo")
func goalDenseTablesAndUndo() throws {
  let model = GoalProgram(title: "Dense priorities", variableNames: (1...40).map { "x\($0)" },
    goals: (1...35).map { row in GoalObjective(name: "Goal \(row)", sense: .maximize,
      coefficients: (1...40).map { Double(row * 100 + $0) }) },
    constraints: [LinearConstraint(name: "Capacity", coefficients: (1...40).map(Double.init), relation: .lessThanOrEqual, rhs: 1000)],
    lowerBounds: Array(repeating: 0, count: 40), upperBounds: Array(repeating: 10, count: 40),
    variableTypes: Array(repeating: .continuous, count: 40))
  let original = GoalProgrammingDraft(model)
  var draft = original
  let lastID = try #require(draft.goals.last?.id)
  draft.moveGoal(id: lastID, by: -1)
  #expect(draft.goals[33].id == lastID)
  #expect(draft.goals[33].coefficients.last == "3540.0")
  #expect(MatrixEditorNavigation(rowID: lastID, columnGroup: 3).rowIndex(in: draft.goals.map(\.id)) == 33)
  try draft.replaceGoals(with: draft.goalsTable())
  try draft.replaceConstraints(with: draft.constraintsTable())
  #expect(try draft.makeModel().goals[33] == model.goals[34])
  #expect(try draft.makeModel().constraints == model.constraints)
  let workspace = QSBWorkspace()
  workspace.startNewGoalProgramming()
  workspace.replaceGoalProgrammingDraft(original)
  let undo = UndoManager()
  workspace.replaceGoalProgrammingDraft(draft, undoManager: undo, actionName: "Move and Paste Priorities")
  undo.undo()
  #expect(workspace.goalProgrammingDraft == original)
  undo.redo()
  #expect(workspace.goalProgrammingDraft == draft)
}
