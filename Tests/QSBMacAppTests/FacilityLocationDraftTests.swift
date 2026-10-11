import Foundation
import QSBCore
import Testing

@testable import QSBMacApp

@Test("Location draft round trips coordinates and directed interaction matrices")
func locationDraftRoundTrip() throws {
  let problem = FacilityLocationProblem(
    title: "Directed", distanceMeasure: .euclidean, objective: "MIN",
    facilities: [
      FacilityLocationFacility(
        id: 7, name: "A", isNew: false, x: 1, y: 2, interactionCosts: [nil, 3]),
      FacilityLocationFacility(
        id: 9, name: "New", isNew: true, x: nil, y: nil, interactionCosts: [5, nil]),
    ])
  var draft = FacilityLocationDraft(problem)
  let identities = draft.facilities.map(\.id)
  try draft.replaceFacilities(with: draft.facilitiesTable())
  try draft.replaceInteractions(with: draft.interactionsTable())
  #expect(try draft.makeProblem() == problem)
  try draft.replaceFacilities(
    with: "ID\tFacility\tNew\tX\tY\n9\tRenamed New\ttrue\t\t\n7\tA\tfalse\t1\t2")
  #expect(draft.facilities.map(\.id) == identities.reversed())
  #expect(try draft.makeProblem().facilities.map(\.interactionCosts) == [[nil, 5], [3, nil]])
  let before = draft
  #expect(throws: SpreadsheetTransferError.self) {
    try draft.replaceFacilities(with: "ID\tFacility\tNew\tX\tY\n9\tNew\ttrue\t\t\n9\tA\ttrue\t1\t2")
  }
  #expect(draft == before)
  #expect(throws: SpreadsheetTransferError.self) {
    try draft.replaceInteractions(with: "Facility\tA\tNew\nA\t\t3\nNew\t5\t")
  }
  #expect(draft == before)
  #expect(throws: OptimizationDraftError.self) {
    try draft.replaceFacilities(
      with: "ID\tFacility\tNew\tX\tY\n9\tNew\ttrue\t\t\n7\tA\tfalse\tbad\t2")
  }
  #expect(draft == before)
}

@Test("Location row operations retain directed interaction dimensions")
func locationDraftRows() throws {
  var draft = FacilityLocationDraft.blank()
  let before = try draft.makeProblem()
  let id = draft.addFacility()
  #expect(draft.interactions.count == 3 && draft.interactions.allSatisfy { $0.count == 3 })
  draft.removeFacility(id: id)
  #expect(try draft.makeProblem() == before)
  draft.facilities[0].x = "bad"
  #expect(draft.draftDiagnostics().contains { $0.severity == .error })
  #expect(draft.facilities[0].x == "bad")
}

@Test("Location malformed imported interaction dimensions can be repaired by a matrix paste")
func locationMalformedDimensions() throws {
  let problem = FacilityLocationProblem(
    title: "Broken", distanceMeasure: .rectilinear, objective: "MIN",
    facilities: [
      FacilityLocationFacility(id: 1, name: "A", isNew: false, x: 0, y: 0, interactionCosts: []),
      FacilityLocationFacility(
        id: 2, name: "New", isNew: true, x: nil, y: nil, interactionCosts: []),
    ])
  var draft = FacilityLocationDraft(problem)
  #expect(draft.draftDiagnostics().contains { $0.severity == .error })
  try draft.replaceInteractions(with: "Facility\tA\tNew\nA\t\t1\nNew\t\t")
  #expect(try draft.makeProblem().facilities[0].interactionCosts == [nil, 1])
}

@MainActor
@Test("Native Location draft solves, validates, exports, and supports undo/redo")
func locationNativeWorkflow() throws {
  let workspace = QSBWorkspace()
  workspace.loadSample(.facilityLocation)
  let original = try #require(workspace.facilityLocationDraft)
  workspace.validateCurrentModel()
  #expect(workspace.modelState == .valid)
  workspace.runCurrentModel()
  #expect(workspace.runState == .solved)
  var changed = original
  changed.facilities[0].x = "bad"
  let undo = UndoManager()
  workspace.replaceFacilityLocationDraft(changed, undoManager: undo)
  workspace.validateCurrentModel()
  #expect(workspace.modelState == .invalid && !workspace.validationDiagnostics.isEmpty)
  undo.undo()
  #expect(workspace.facilityLocationDraft == original)
  undo.redo()
  #expect(workspace.facilityLocationDraft == changed)
  undo.undo()
  workspace.beginModelExport()
  #expect(
    try FacilitiesModelJSON.decodeUncheckedModel(from: Data(workspace.modelJSON.utf8))
      == .location(original.makeProblem()))
  workspace.startNewGoalProgramming()
  #expect(workspace.facilityLocationDraft == nil)
}

@MainActor
@Test("Location native import and JSON Apply route by facilities envelope kind")
func locationNativeImport() throws {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    .appendingPathExtension("json")
  try Data(SampleModels.facilityLocationJSON.utf8).write(to: url)
  defer { try? FileManager.default.removeItem(at: url) }
  let workspace = QSBWorkspace()
  workspace.importModel(from: url)
  #expect(workspace.facilityLocationDraft != nil)
  workspace.startNewFacilityLocation()
  workspace.validateCurrentModel()
  #expect(workspace.modelState == .valid)
  workspace.modelJSON = SampleModels.facilityLocationJSON
  workspace.applyFacilityLocationJSONToNativeEditor()
  #expect(workspace.facilityLocationDraft != nil && workspace.goalProgrammingDraft == nil)
  let previous = workspace.facilityLocationDraft
  workspace.modelJSON = SampleModels.lineBalancingJSON
  workspace.applyFacilityLocationJSONToNativeEditor()
  #expect(workspace.facilityLocationDraft == previous)
  workspace.loadSample(.lineBalancing)
  #expect(workspace.facilityLocationDraft == nil)
}

@Test("Legacy Location IDs are scoped by existing and new roles during table reordering")
func locationScopedIdentity() throws {
    let problem = FacilityLocationProblem(title: "Legacy IDs", distanceMeasure: .rectilinear, objective: "MIN", facilities: [
        FacilityLocationFacility(id: 1, name: "F1", isNew: false, x: 0, y: 0, interactionCosts: [nil, 3]),
        FacilityLocationFacility(id: 1, name: "NF1", isNew: true, x: nil, y: nil, interactionCosts: [5, nil])])
    var draft = FacilityLocationDraft(problem)
    try draft.replaceFacilities(with: draft.facilitiesTable())
    #expect(try draft.makeProblem() == problem)
    try draft.replaceFacilities(with: "ID\tFacility\tNew\tX\tY\n1\tRenamed New\ttrue\t\t\n1\tRenamed Existing\tfalse\t0\t0")
    #expect(try draft.makeProblem().facilities.map(\.interactionCosts) == [[nil, 5], [3, nil]])
    try draft.replaceFacilities(with: "ID\tFacility\tNew\tX\tY\n1\tRenamed New\tfalse\t2\t3\n1\tRenamed Existing\ttrue\t\t")
    #expect(try draft.makeProblem().facilities.map(\.interactionCosts) == [[nil, 5], [3, nil]])
}
