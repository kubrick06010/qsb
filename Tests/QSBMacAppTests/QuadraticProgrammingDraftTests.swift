import Foundation
import Testing
import QSBCore
@testable import QSBMacApp

@Test("quadratic-programming draft round trips and keeps matrix dimensions aligned")
func quadraticProgrammingDraftRoundTrip() throws {
    let model = try QuadraticProgrammingJSON.decodeUncheckedModel(from: Data(SampleModels.quadraticProgrammingJSON.utf8))
    var draft = QuadraticProgrammingDraft(model)
    #expect(try draft.makeModel() == model)
    let id = draft.addVariable()
    #expect(draft.quadraticMatrix.count == 2 && draft.quadraticMatrix.allSatisfy { $0.count == 2 })
    draft.removeVariable(id: id)
    #expect(try draft.makeModel() == model)
}

@Test("quadratic-programming table transfer is atomic")
func quadraticProgrammingTableTransfer() throws {
    var draft = QuadraticProgrammingDraft(try QuadraticProgrammingJSON.decodeUncheckedModel(from: Data(SampleModels.quadraticProgrammingJSON.utf8)))
    try draft.replaceVariables(with: draft.variablesTable())
    try draft.replaceQuadratic(with: draft.quadraticTable())
    let before = draft
    #expect(throws: SpreadsheetTransferError.self) { try draft.replaceQuadratic(with: "Variable\tx\nx\tbad") }
    #expect(draft == before)
}

@MainActor
@Test("workspace routes native quadratic programs and supports undo")
func quadraticProgrammingWorkspaceWorkflow() throws {
    let workspace = QSBWorkspace(); workspace.loadSample(.quadraticProgramming)
    let original = try #require(workspace.quadraticProgrammingDraft)
    workspace.validateCurrentModel(); #expect(workspace.modelState == .valid)
    workspace.runCurrentModel(); #expect(workspace.runState == .solved)
    var changed = original; changed.linearCoefficients[0] = "bad"
    let undo = UndoManager(); workspace.replaceQuadraticProgrammingDraft(changed, undoManager: undo)
    workspace.validateCurrentModel(); #expect(workspace.modelState == .invalid)
    undo.undo(); #expect(workspace.quadraticProgrammingDraft == original)
}

@Test("QP variable table preserves coupled objective and constraints when reordered")
func quadraticVariablePastePreservesModel() throws {
    let model = QuadraticProgram(title: "Coupled", sense: .minimize,
        variableNames: ["a", "b"], linearCoefficients: [-3, -7],
        quadraticMatrix: [[4, 1], [1, 2]],
        constraints: [LinearConstraint(name: "Capacity", coefficients: [2, 5], relation: .lessThanOrEqual, rhs: 20)],
        lowerBounds: [nil, 0], upperBounds: [10, 12], variableTypes: [.continuous, .continuous])
    var draft = QuadraticProgrammingDraft(model)
    try draft.replaceVariables(with: draft.variablesTable())
    #expect(try draft.makeModel() == model)
    try draft.replaceVariables(with: "Variable\tType\tLower Bound\tUpper Bound\tLinear Coefficient\nb\tcontinuous\t0\t12\t-7\na\tcontinuous\t\t10\t-3")
    let reordered = try draft.makeModel()
    #expect(reordered.quadraticMatrix == [[2, 1], [1, 4]])
    #expect(reordered.constraints[0].coefficients == [5, 2])
    let before = draft
    #expect(throws: SpreadsheetTransferError.self) {
        try draft.replaceQuadratic(with: "Variable\ta\tb\na\t4\t1\nb\t1\t2")
    }
    #expect(draft == before)
}

@Test("QP malformed imported dimensions remain diagnosable without an indexing crash")
func quadraticMalformedDimensions() throws {
    let model = QuadraticProgram(title: "Invalid", sense: .minimize, variableNames: ["a", "b"],
        linearCoefficients: [], quadraticMatrix: [], constraints: [],
        lowerBounds: [], upperBounds: [], variableTypes: [])
    let draft = QuadraticProgrammingDraft(model)
    #expect(draft.draftDiagnostics().contains { $0.severity == .error })
    #expect(throws: OptimizationDraftError.self) { try draft.makeModel() }
}

@MainActor
@Test("QP normalized file import opens the native draft and exports edits")
func quadraticNativeFileImport() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
    try Data(SampleModels.quadraticProgrammingJSON.utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    let workspace = QSBWorkspace()
    workspace.importModel(from: url)
    var draft = try #require(workspace.quadraticProgrammingDraft)
    draft.linearCoefficients[0] = "-6"
    workspace.replaceQuadraticProgrammingDraft(draft)
    workspace.beginModelExport()
    #expect(try QuadraticProgrammingJSON.decodeUncheckedModel(from: Data(workspace.modelJSON.utf8)).linearCoefficients == [-6])
    workspace.startNewQualityControl()
    #expect(workspace.quadraticProgrammingDraft == nil)
}

@Test("QP malformed imports retain extra coefficients and allow explicit native repair")
func quadraticNativeDimensionRepair() throws {
    let model = QuadraticProgram(title: "Incomplete", sense: .minimize,
        variableNames: ["a"], linearCoefficients: [-1, -2], quadraticMatrix: [[4, 1], [1, 3]],
        constraints: [LinearConstraint(name: "Capacity", coefficients: [2, 5], relation: .lessThanOrEqual, rhs: 10)],
        lowerBounds: [], upperBounds: [], variableTypes: [])
    var draft = QuadraticProgrammingDraft(model)
    #expect(draft.variables.count == 2)
    #expect(draft.variables[1].name.isEmpty)
    #expect(draft.quadraticMatrix == [["4.0", "1.0"], ["1.0", "3.0"]])
    #expect(draft.constraints[0].coefficients == ["2.0", "5.0"])
    draft.confirmImportedDimensions()
    #expect(throws: OptimizationDraftError.self) { try draft.makeModel() }
    draft.variables[1].name = "b"
    let repaired = try draft.makeModel()
    #expect(repaired.linearCoefficients == [-1, -2])
    #expect(repaired.quadraticMatrix == model.quadraticMatrix)
    #expect(repaired.constraints == model.constraints)
    #expect(repaired.lowerBounds == [nil, nil])
    #expect(repaired.variableTypes == [.continuous, .continuous])
}

@Test("QP section pastes repair incomplete drafts independently and remain atomic")
func quadraticIndependentTableRepair() throws {
    let model = QuadraticProgram(title: "Incomplete", sense: .minimize,
        variableNames: ["a", "b"], linearCoefficients: [], quadraticMatrix: [],
        constraints: [LinearConstraint(name: "Capacity", coefficients: [], relation: .lessThanOrEqual, rhs: 10)],
        lowerBounds: [], upperBounds: [], variableTypes: [])
    var draft = QuadraticProgrammingDraft(model)
    try draft.replaceVariables(with: "Variable\tType\tLower Bound\tUpper Bound\tLinear Coefficient\na\tcontinuous\t0\t10\t-1\nb\tcontinuous\t0\t10\t-2")
    #expect(!draft.hasImportedDimensionIssue)
    #expect(draft.draftDiagnostics().contains { $0.severity == .error })
    try draft.replaceQuadratic(with: "Variable\ta\tb\na\t4\t1\nb\t1\t3")
    #expect(draft.draftDiagnostics().contains { $0.severity == .error })
    try draft.replaceConstraints(with: "Constraint\ta\tb\tRelation\tRHS\nCapacity\t2\t5\t<=\t10")
    #expect(draft.draftDiagnostics().allSatisfy { $0.severity != .error })
    let before = draft
    #expect(throws: SpreadsheetTransferError.self) {
        try draft.replaceVariables(with: "a\tcontinuous\t0\t10\t")
    }
    #expect(draft == before)
}

@Test("QP variable identities and names remain distinct across remove add and paste")
func quadraticVariableIdentityRetention() throws {
    var draft = QuadraticProgrammingDraft.blank()
    let second = draft.addVariable()
    let third = draft.addVariable()
    draft.removeVariable(id: second)
    _ = draft.addVariable()
    #expect(Set(draft.variables.map(\.name)).count == 3)
    let thirdName = try #require(draft.variables.first { $0.id == third }?.name)
    var table = try SpreadsheetTable(text: draft.variablesTable()).rows
    let header = table.removeFirst()
    try draft.replaceVariables(with: ([header] + table.reversed()).map { $0.joined(separator: "\t") }.joined(separator: "\n"))
    #expect(draft.variables.first { $0.name == thirdName }?.id == third)
    try draft.replaceVariables(with: "Variable\tType\tLower Bound\tUpper Bound\tLinear Coefficient\na\tcontinuous\t0\t10\t0\na\tcontinuous\t0\t10\t0")
    #expect(Set(draft.variables.map(\.id)).count == 2)
    #expect(draft.draftDiagnostics().contains { $0.severity == .error })
}

@MainActor
@Test("QP imported-dimension review supports undo redo without losing coefficients")
func quadraticDimensionReviewUndo() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.quadraticProgramming)
    let source = QuadraticProgram(title: "Review", sense: .minimize,
        variableNames: ["a"], linearCoefficients: [-2], quadraticMatrix: [[4]], constraints: [],
        lowerBounds: [], upperBounds: [], variableTypes: [])
    let original = QuadraticProgrammingDraft(source)
    workspace.replaceQuadraticProgrammingDraft(original)
    var reviewed = original
    reviewed.confirmImportedDimensions()
    let undoManager = UndoManager()
    workspace.replaceQuadraticProgrammingDraft(reviewed, undoManager: undoManager, actionName: "Review Dimensions")
    workspace.validateCurrentModel()
    #expect(workspace.modelState == .valid)
    undoManager.undo()
    #expect(workspace.quadraticProgrammingDraft == original)
    workspace.validateCurrentModel()
    #expect(workspace.modelState == .invalid)
    undoManager.redo()
    #expect(workspace.quadraticProgrammingDraft == reviewed)
    #expect(try workspace.quadraticProgrammingDraft?.makeModel().quadraticMatrix == [[4]])
}
