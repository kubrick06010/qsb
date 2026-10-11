import Foundation
import QSBCore
import Testing

@testable import QSBMacApp

@Test("Layout table round trips retain geometry, fixed departments, and directed costs")
func layoutDraftRoundTrip() throws {
  let problem = FacilityLayoutProblem(
    title: "Two areas", rowCount: 2, columnCount: 2, objective: "MIN",
    departments: [
      FacilityLayoutDepartment(
        id: 7, name: "A", fixed: true, flowUnitCosts: [nil, 3],
        initialLayout: [
          .init(startRow: 1, startColumn: 1, endRow: 1, endColumn: 1),
          .init(startRow: 2, startColumn: 1, endRow: 2, endColumn: 1),
        ]),
      FacilityLayoutDepartment(
        id: 9, name: "B", fixed: false, flowUnitCosts: [5, nil],
        initialLayout: [.init(startRow: 1, startColumn: 2, endRow: 2, endColumn: 2)]),
    ])
  var draft = FacilityLayoutDraft(problem)
  let identities = draft.departments.map(\.id)
  try draft.replaceDepartments(with: draft.departmentsTable())
  try draft.replaceRectangles(with: draft.rectanglesTable())
  try draft.replaceCosts(with: draft.costsTable())
  #expect(try draft.makeProblem() == problem)
  try draft.replaceDepartments(with: "ID\tDepartment\tFixed\n9\tRenamed B\tfalse\n7\tA\ttrue")
  #expect(draft.departments.map(\.id) == identities.reversed())
  let reordered = try draft.makeProblem()
  #expect(reordered.departments.map(\.flowUnitCosts) == [[nil, 5], [3, nil]])
  #expect(reordered.departments[1].initialLayout == problem.departments[0].initialLayout)
  let before = draft
  #expect(throws: SpreadsheetTransferError.self) {
    try draft.replaceCosts(with: "Department\t[7] A\t[9] B\n[7] A\t\t3\n[9] B\t5\t")
  }
  #expect(draft == before)
  #expect(throws: SpreadsheetTransferError.self) {
    try draft.replaceDepartments(with: "ID\tDepartment\tFixed\n7\tA\ttrue\n7\tB\tfalse")
  }
  #expect(draft == before)
  #expect(throws: OptimizationDraftError.self) {
    try draft.replaceRectangles(
      with: "Department ID\tStart Row\tStart Column\tEnd Row\tEnd Column\n7\tbad\t1\t2\t1")
  }
  #expect(draft == before)
  #expect(throws: SpreadsheetTransferError.self) {
    try draft.replaceRectangles(
      with: "Department ID\tStart Row\tStart Column\tEnd Row\tEnd Column\n99\t1\t1\t2\t1")
  }
  #expect(draft == before)
}

@Test("Layout row edits retain matrix dimensions and preserve invalid geometry for repair")
func layoutDraftRowsAndInvalidInput() throws {
  var draft = FacilityLayoutDraft.blank()
  let original = try draft.makeProblem()
  let department = draft.addDepartment()
  #expect(draft.costs.count == 3 && draft.costs.allSatisfy { $0.count == 3 })
  draft.removeDepartment(id: department)
  #expect(try draft.makeProblem() == original)
  let id = draft.departments[0].id
  let addedRectangle = draft.addRectangle(departmentID: id)
  let rectangle = try #require(addedRectangle)
  draft.removeRectangle(departmentID: id, id: rectangle)
  #expect(try draft.makeProblem() == original)
  draft.departments[0].rectangles[0].endColumn = "99"
  #expect(draft.draftDiagnostics().contains { $0.code == "facilities.layout.initial.bounds" })
  draft.departments[0].rectangles[0].endColumn = "bad"
  #expect(throws: OptimizationDraftError.self) { try draft.makeProblem() }
  #expect(draft.departments[0].rectangles[0].endColumn == "bad")
}

@Test("Layout malformed cost dimensions and empty rectangle tables remain diagnosable")
func layoutMalformedDimensions() throws {
  let problem = FacilityLayoutProblem(
    title: "Broken", rowCount: 1, columnCount: 1, objective: "MIN",
    departments: [
      FacilityLayoutDepartment(
        id: 1, name: "A", fixed: false, flowUnitCosts: [],
        initialLayout: [.init(startRow: 1, startColumn: 1, endRow: 1, endColumn: 1)])
    ])
  var draft = FacilityLayoutDraft(problem)
  #expect(draft.draftDiagnostics().contains { $0.severity == .error })
  try draft.replaceCosts(with: "Department\t[1] A\n[1] A\t")
  #expect(try draft.makeProblem().departments[0].flowUnitCosts == [nil])
  try draft.replaceRectangles(with: "Department ID\tStart Row\tStart Column\tEnd Row\tEnd Column")
  #expect(draft.draftDiagnostics().contains { $0.code == "facilities.layout.initial.empty" })
}

@MainActor
@Test("Layout native workspace solves both strategies and supports undo/redo and export")
func layoutNativeWorkflow() throws {
  let workspace = QSBWorkspace()
  workspace.loadSample(.facilityLayout)
  let original = try #require(workspace.facilityLayoutDraft)
  workspace.validateCurrentModel()
  #expect(workspace.modelState == .valid)
  workspace.runCurrentModel()
  #expect(workspace.runState == .solved)
  #expect(workspace.facilityLayoutPresentation != nil)
  workspace.selectedLayoutStrategy = .pairwiseSwap
  workspace.runCurrentModel()
  #expect(workspace.runState == .solved)
  var changed = original
  changed.departments[0].rectangles[0].startRow = "bad"
  let undo = UndoManager()
  workspace.replaceFacilityLayoutDraft(changed, undoManager: undo)
  workspace.validateCurrentModel()
  #expect(workspace.modelState == .invalid && !workspace.validationDiagnostics.isEmpty)
  undo.undo()
  #expect(workspace.facilityLayoutDraft == original)
  undo.redo()
  #expect(workspace.facilityLayoutDraft == changed)
  undo.undo()
  workspace.beginModelExport()
  #expect(
    try FacilitiesModelJSON.decodeUncheckedModel(from: Data(workspace.modelJSON.utf8))
      == .layout(original.makeProblem()))
  workspace.startNewLineBalancing()
  #expect(workspace.facilityLayoutDraft == nil)
}

@MainActor
@Test("Layout native import, creation, and explicit JSON Apply preserve family routing")
func layoutNativeImport() throws {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    .appendingPathExtension("json")
  try Data(SampleModels.facilityLayoutJSON.utf8).write(to: url)
  defer { try? FileManager.default.removeItem(at: url) }
  let workspace = QSBWorkspace()
  workspace.importModel(from: url)
  #expect(workspace.facilityLayoutDraft != nil)
  workspace.startNewFacilityLayout()
  workspace.validateCurrentModel()
  #expect(workspace.modelState == .valid)
  workspace.modelJSON = SampleModels.facilityLayoutJSON
  workspace.applyFacilityLayoutJSONToNativeEditor()
  #expect(workspace.facilityLayoutDraft != nil && workspace.lineBalancingDraft == nil)
  let previous = workspace.facilityLayoutDraft
  workspace.modelJSON = SampleModels.lineBalancingJSON
  workspace.applyFacilityLayoutJSONToNativeEditor()
  #expect(workspace.facilityLayoutDraft == previous)
  workspace.applyLineBalancingJSONToNativeEditor()
  #expect(workspace.facilityLayoutDraft == nil && workspace.lineBalancingDraft != nil)
  workspace.loadSample(.facilityLocation)
  #expect(workspace.facilityLayoutDraft == nil)
}
