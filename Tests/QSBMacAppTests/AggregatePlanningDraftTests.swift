import Foundation
import Testing
import QSBCore
@testable import QSBMacApp

@Test("aggregate-planning draft preserves every period vector")
func aggregatePlanningDraftRoundTrip() throws {
    let model = try AggregatePlanningJSON.decodeModel(from: Data(SampleModels.aggregatePlanningJSON.utf8))
    let draft = AggregatePlanningDraft(model)
    #expect(try draft.makeModel() == model)
    #expect(draft.periods.count == 3)
    #expect(!draft.draftDiagnostics().contains { $0.severity == .error })
}

@Test("aggregate-planning spreadsheet transfer replaces all period fields atomically")
func aggregatePlanningSpreadsheetTransfer() throws {
    var draft = AggregatePlanningDraft.blank()
    let first = [
        "Jan", "80", "100", "2", "0", "30", "3", "0", "0", "", "0", "50", "0", "0.5", "20", "4", "0", "8", "0", "1"
    ]
    let second = [
        "Feb", "120", "100", "2", "0", "30", "3", "0", "0", "", "0", "50", "0", "0.5", "20", "4", "0", "8", "0", "1"
    ]
    let text = ([AggregatePlanningDraft.headers] + [first, second]).map { $0.joined(separator: "\t") }.joined(separator: "\n")
    try draft.replacePeriods(withTabularText: text)

    let model = try draft.makeModel()
    #expect(model.periodNames == ["Jan", "Feb"])
    #expect(model.demand == [80, 120])
    #expect(model.maximumWorkforce == [nil, nil])
    #expect(model.maximumInventory == [50, 50])
    #expect(draft.tabularText().hasPrefix("Period\tDemand\tRegular Capacity"))

    let before = draft
    var invalid = second
    invalid[5] = "invalid"
    #expect(throws: SpreadsheetTransferError.self) {
        try draft.replacePeriods(withTabularText: invalid.joined(separator: "\t"))
    }
    #expect(draft == before)
}

@MainActor
@Test("workspace routes aggregate-planning drafts through validation and solving")
func aggregatePlanningDraftWorkspaceWorkflow() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.aggregatePlanning)
    #expect(workspace.aggregatePlanningDraft != nil)
    guard case .aggregatePlanning = workspace.currentModelFamily else {
        Issue.record("Expected aggregate-planning family")
        return
    }
    workspace.validateCurrentModel()
    #expect(workspace.modelState == .valid)
    workspace.runCurrentModel()
    #expect(workspace.runState == .solved)
    workspace.beginModelExport()
    #expect(workspace.isExportingModel)
    #expect(try AggregatePlanningJSON.decodeModel(from: Data(workspace.modelJSON.utf8)).periodNames.count == 3)
}


@Test("aggregate table repair is independent and retains unambiguous period identities")
func aggregatePlanningIndependentTableRepair() throws {
    var draft = AggregatePlanningDraft.blank()
    draft.periods[0].name = "Period"
    let firstID = draft.periods[0].id
    draft.periods.append(AggregatePlanningPeriodDraft(name: "February", demand: "bad"))
    let secondID = draft.periods[1].id
    draft.title = ""
    draft.initialInventory = "unfinished"
    draft.periods[1].demand = "120"
    let rows = draft.tabularText().components(separatedBy: "\n")
    draft.periods[1].demand = "bad"
    try draft.replacePeriods(withTabularText: [rows[2], rows[1]].joined(separator: "\n"))
    #expect(draft.periods.map(\.id) == [secondID, firstID])
    #expect(draft.periods.map(\.name) == ["February", "Period"])
    #expect(draft.periods[0].demand == "120")
    #expect(draft.title == "" && draft.initialInventory == "unfinished")
    #expect(throws: AggregatePlanningDraftError.self) { try draft.makeModel() }

    let before = draft
    var cells = rows[1].components(separatedBy: "\t")
    cells[0] = "   "
    #expect(throws: SpreadsheetTransferError.self) { try draft.replacePeriods(withTabularText: cells.joined(separator: "\t")) }
    #expect(draft == before)
}

@Test("ambiguous aggregate period names do not share identities and new names avoid collisions")
func aggregatePlanningAmbiguousPeriodIdentity() throws {
    var draft = AggregatePlanningDraft.blank()
    draft.periods[0].name = "Period 2"
    let newID = draft.addPeriod()
    #expect(draft.periods.last?.name == "Period 3")
    let rows = draft.tabularText().components(separatedBy: "\n")
    try draft.replacePeriods(withTabularText: [rows[1], rows[1], rows[2]].joined(separator: "\n"))
    #expect(Set(draft.periods.map(\.id)).count == 3)
    #expect(draft.periods.last?.id == newID)
}

private func aggregatePlanningUnequalVectorsJSON() throws -> Data {
    var object = try #require(JSONSerialization.jsonObject(with: Data(SampleModels.aggregatePlanningJSON.utf8)) as? [String: Any])
    object["periodNames"] = ["January"]
    object["demand"] = [80, 120, 160, 200]
    object["regularCapacity"] = [100]
    object["maximumInventory"] = [50]
    return try JSONSerialization.data(withJSONObject: object)
}

@Test("aggregate imports retain extra values and require explicit dimension and cell repair")
func aggregatePlanningImportedDimensionRepair() throws {
    let model = try AggregatePlanningJSON.decodeModel(from: aggregatePlanningUnequalVectorsJSON())
    var draft = AggregatePlanningDraft(model)
    #expect(draft.hasImportedDimensionIssue)
    #expect(draft.periods.count == 4)
    #expect(draft.periods.map(\.demand) == ["80.0", "120.0", "160.0", "200.0"])
    #expect(draft.periods[3].name == "")
    #expect(draft.periods[1].regularCapacity == "")
    #expect(draft.periods[1].maximumInventory == "")
    #expect(throws: AggregatePlanningDraftError.importedDimensions) { try draft.makeModel() }
    var acceptedOnly = draft
    acceptedOnly.confirmImportedDimensions()
    #expect(throws: AggregatePlanningDraftError.self) { try acceptedOnly.makeModel() }
    #expect(acceptedOnly.periods == draft.periods)
    let ids = draft.periods.map(\.id)
    var repaired = AggregatePlanningDraft.blank()
    repaired.periods = (1...4).map { AggregatePlanningPeriodDraft(name: "P\($0)", demand: "\($0 * 40)", regularCapacity: "200") }
    try draft.replacePeriods(withTabularText: repaired.tabularText())
    #expect(draft.hasImportedDimensionIssue)
    draft.confirmImportedDimensions()
    let normalized = try draft.makeModel()
    #expect(normalized.periodNames == ["P1", "P2", "P3", "P4"])
    #expect(try AggregatePlanningJSON.decodeModel(from: AggregatePlanningJSON.encodeModel(normalized)) == normalized)
    #expect(Set(ids).count == 4)
}

@MainActor
@Test("aggregate dimension review and table repair participate in workspace undo")
func aggregatePlanningRepairWorkspaceUndo() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.aggregatePlanning)
    workspace.modelJSON = String(decoding: try aggregatePlanningUnequalVectorsJSON(), as: UTF8.self)
    workspace.applyAggregatePlanningJSONToNativeEditor()
    let imported = try #require(workspace.aggregatePlanningDraft)
    #expect(imported.hasImportedDimensionIssue)
    let manager = UndoManager()
    manager.groupsByEvent = false
    var reviewed = imported
    reviewed.confirmImportedDimensions()
    manager.beginUndoGrouping()
    workspace.replaceAggregatePlanningDraft(reviewed, undoManager: manager, actionName: "Review Dimensions")
    manager.endUndoGrouping()
    workspace.validateCurrentModel()
    #expect(workspace.modelState == .invalid)
    manager.undo()
    #expect(workspace.aggregatePlanningDraft == imported)
    manager.redo()
    #expect(workspace.aggregatePlanningDraft == reviewed)

    let workforce = reviewed.initialWorkforce
    reviewed.capacityIsPerWorker.toggle()
    workspace.replaceAggregatePlanningDraft(reviewed)
    #expect(workspace.aggregatePlanningDraft?.initialWorkforce == workforce)
}
