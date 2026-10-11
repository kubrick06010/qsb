import Foundation
import Testing
import QSBCore
@testable import QSBMacApp

@Test("MRP draft preserves item, schedule, and bill-of-materials data")
func materialRequirementsPlanningDraftRoundTrip() throws {
    let model = try MaterialRequirementsPlanningJSON.decodeModel(
        from: Data(SampleModels.materialRequirementsPlanningJSON.utf8)
    )
    let draft = MaterialRequirementsPlanningDraft(model)

    #expect(try draft.makeModel() == model)
    #expect(draft.items.count == 2)
    #expect(draft.bucketNames.count == 5)
    #expect(draft.billComponents.count == 1)
    #expect(!draft.draftDiagnostics().contains { $0.severity == .error })
}

@Test("MRP item renames and bucket edits keep dependent tables aligned")
func materialRequirementsPlanningDimensionSafeEditing() throws {
    let model = try MaterialRequirementsPlanningJSON.decodeModel(
        from: Data(SampleModels.materialRequirementsPlanningJSON.utf8)
    )
    var draft = MaterialRequirementsPlanningDraft(model)
    let finalID = try #require(draft.items.first(where: { $0.identifier == "FINAL" })?.id)

    draft.renameItem(id: finalID, to: "ASSEMBLY")
    #expect(draft.billComponents.first?.parentIdentifier == "ASSEMBLY")
    #expect(draft.items.first(where: { $0.id == finalID })?.masterProductionSchedule != nil)

    let newBucket = draft.addBucket()
    #expect(draft.items.allSatisfy { $0.scheduledReceipts.count == draft.bucketNames.count })
    #expect(draft.items.allSatisfy { $0.capacity.count == draft.bucketNames.count })
    #expect(draft.items.first(where: { $0.id == finalID })?.masterProductionSchedule?.count == draft.bucketNames.count)

    draft.removeBucket(at: newBucket)
    let rebuilt = try draft.makeModel()
    #expect(rebuilt.items.first?.identifier == "ASSEMBLY")
    #expect(rebuilt.billsOfMaterial.first?.parentIdentifier == "ASSEMBLY")
}

@Test("MRP spreadsheet transfers are complete and atomic")
func materialRequirementsPlanningSpreadsheetTransfers() throws {
    let model = try MaterialRequirementsPlanningJSON.decodeModel(
        from: Data(SampleModels.materialRequirementsPlanningJSON.utf8)
    )
    var draft = MaterialRequirementsPlanningDraft(model)

    let itemTable = draft.itemTabularText()
    let scheduleTable = draft.scheduleTabularText()
    let billTable = draft.billTabularText()
    try draft.replaceItems(withTabularText: itemTable)
    try draft.replaceSchedules(withTabularText: scheduleTable)
    try draft.replaceBillComponents(withTabularText: billTable)
    #expect(try draft.makeModel() == model)

    let before = draft
    var invalidRows = try SpreadsheetTable(text: scheduleTable).rows
    invalidRows[1][2] = "invalid"
    let invalidSchedule = invalidRows.map { $0.joined(separator: "\t") }.joined(separator: "\n")
    #expect(throws: SpreadsheetTransferError.self) {
        try draft.replaceSchedules(withTabularText: invalidSchedule)
    }
    #expect(draft == before)

    try draft.replaceBillComponents(withTabularText: MaterialRequirementsPlanningDraft.billHeaders.joined(separator: "\t"))
    #expect(draft.billComponents.isEmpty)
}

@MainActor
@Test("workspace routes native MRP drafts through validation, solving, and export")
func materialRequirementsPlanningDraftWorkspaceWorkflow() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.materialRequirementsPlanning)
    #expect(workspace.materialRequirementsPlanningDraft != nil)
    guard case .materialRequirementsPlanning = workspace.currentModelFamily else {
        Issue.record("Expected material-requirements-planning family")
        return
    }

    workspace.validateCurrentModel()
    #expect(workspace.modelState == .valid)
    workspace.runCurrentModel()
    #expect(workspace.runState == .solved)
    workspace.beginModelExport()
    #expect(workspace.isExportingModel)
    let exported = try MaterialRequirementsPlanningJSON.decodeModel(from: Data(workspace.modelJSON.utf8))
    #expect(exported.items.count == 2)
    #expect(exported.bucketNames.count == 5)
}

@MainActor
@Test("MRP workspace reports invalid native fields and participates in undo and redo")
func materialRequirementsPlanningInvalidStateAndUndo() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.materialRequirementsPlanning)
    let original = try #require(workspace.materialRequirementsPlanningDraft)
    var changed = original
    changed.items[0].annualDemand = "not a number"
    let undoManager = UndoManager()

    workspace.replaceMaterialRequirementsPlanningDraft(changed, undoManager: undoManager, actionName: "Edit Annual Demand")
    workspace.validateCurrentModel()
    #expect(workspace.modelState == .invalid)
    #expect(workspace.validationDiagnostics.contains { $0.path?.contains("annualDemand") == true })

    undoManager.undo()
    #expect(workspace.materialRequirementsPlanningDraft == original)
    undoManager.redo()
    #expect(workspace.materialRequirementsPlanningDraft == changed)
}

@Test("MRP tables repair independently without changing unfinished fields or matching row identities")
func mrpIndependentTableRepair() throws {
    let model = try MaterialRequirementsPlanningJSON.decodeModel(from: Data(SampleModels.materialRequirementsPlanningJSON.utf8))
    var draft = MaterialRequirementsPlanningDraft(model)
    let itemTable = draft.itemTabularText()
    let schedules = draft.scheduleTabularText()
    let bills = draft.billTabularText()
    let itemIDs = draft.items.map(\.id)
    let billIDs = draft.billComponents.map(\.id)
    draft.title = ""
    draft.items[0].unitCost = "unfinished"
    try draft.replaceSchedules(withTabularText: schedules)
    try draft.replaceBillComponents(withTabularText: bills)
    #expect(draft.items[0].unitCost == "unfinished")
    #expect(draft.billComponents.map(\.id) == billIDs)
    try draft.replaceItems(withTabularText: itemTable)
    #expect(draft.items.map(\.id) == itemIDs)
    #expect(draft.title.isEmpty)
    #expect(draft.draftDiagnostics().contains { $0.severity == .error })
}

@Test("MRP rejects ambiguous labels and duplicate item identities atomically")
func mrpAmbiguousTableLabels() throws {
    var draft = MaterialRequirementsPlanningDraft.blank()
    var rows = try SpreadsheetTable(text: draft.itemTabularText()).rows
    rows.append(rows[1])
    let before = draft
    #expect(throws: SpreadsheetTransferError.self) {
        try draft.replaceItems(withTabularText: rows.map { $0.joined(separator: "\t") }.joined(separator: "\n"))
    }
    #expect(draft == before)
    draft.bucketNames[1] = draft.bucketNames[0]
    let ambiguous = draft
    #expect(throws: SpreadsheetTransferError.self) { try draft.replaceSchedules(withTabularText: draft.scheduleTabularText()) }
    #expect(draft == ambiguous)
    draft.bucketNames[1] = "Period 1"
    rows = try SpreadsheetTable(text: draft.itemTabularText()).rows
    rows[1][4] = ""
    let withUnit = draft
    #expect(throws: SpreadsheetTransferError.self) {
        try draft.replaceItems(withTabularText: rows.map { $0.joined(separator: "\t") }.joined(separator: "\n"))
    }
    #expect(draft == withUnit)
    draft.bucketNames[0] = "Period 4"
    let added = draft.addBucket()
    #expect(draft.bucketNames[added] == "Period 5")
}

@Test("MRP schedule keys preserve identifiers and buckets containing separator characters")
func mrpSchedulePairKeys() throws {
    var draft = MaterialRequirementsPlanningDraft.blank()
    draft.bucketNames = ["B\u{1f}C", "C"]
    draft.items = [
        MRPItemDraft(identifier: "A", scheduledReceipts: ["1", "2"], capacity: ["", "3"]),
        MRPItemDraft(identifier: "A\u{1f}B", scheduledReceipts: ["4", "5"], capacity: ["6", ""])
    ]
    let before = draft
    try draft.replaceSchedules(withTabularText: draft.scheduleTabularText())
    #expect(draft == before)
}

@Test("MRP incomplete imported schedules remain safe to copy, remove, and repair")
func mrpIncompleteScheduleRepair() throws {
    var draft = MaterialRequirementsPlanningDraft.blank()
    draft.items[0].scheduledReceipts = ["7"]
    draft.items[0].capacity = []
    draft.items[0].masterProductionSchedule = ["9"]
    #expect(draft.draftDiagnostics().contains { $0.severity == .error })
    let rows = try SpreadsheetTable(text: draft.scheduleTabularText()).rows
    #expect(rows[1][2] == "7")
    #expect(rows[2][2].isEmpty)
    draft.removeBucket(at: 3)
    var repairedRows = try SpreadsheetTable(text: draft.scheduleTabularText()).rows
    for index in repairedRows.indices.dropFirst() where repairedRows[index][2].isEmpty { repairedRows[index][2] = "0" }
    try draft.replaceSchedules(withTabularText: repairedRows.map { $0.joined(separator: "\t") }.joined(separator: "\n"))
    #expect(try draft.makeModel().items[0].scheduledReceipts == [7, 0, 0])
    #expect(try draft.makeModel().masterProductionSchedule["ITEM1"] == [9, 0, 0])
}

private func mrpImportedDimensionFixture(orphan: Bool = false) -> MaterialRequirementsPlanningModel {
    let item = MRPItem(identifier: "ITEM1", levelCode: "0", sourceCode: "M", materialType: "Item", unit: "unit",
        leadTime: 0, lotSizingRule: .lotForLot, lotSizingLookahead: nil, annualDemand: 0, unitCost: 1,
        orderingCost: 2, annualHoldingCost: 3, description: "Retained item", safetyStock: 0, initialOnHand: 0,
        scheduledReceipts: [7, 8], capacity: [nil])
    var mps = ["ITEM1": [11.0, 12, 13]]
    if orphan { mps["ORPHAN"] = [21, 22, 23, 24] }
    return MaterialRequirementsPlanningModel(title: "Imported plan", timeUnit: "Period", periodsPerYear: 12,
        bucketNames: ["Overdue"], items: [item], billsOfMaterial: [], masterProductionSchedule: mps)
}

@Test("MRP imported dimensions retain extra cells and require explicit native review and repair")
func mrpImportedDimensionReview() throws {
    var draft = MaterialRequirementsPlanningDraft(mrpImportedDimensionFixture())
    #expect(draft.hasImportedDimensionIssue)
    #expect(draft.bucketNames == ["Overdue", "", ""])
    #expect(draft.items[0].scheduledReceipts == ["7.0", "8.0", ""])
    #expect(draft.items[0].capacity == ["", "", ""])
    #expect(draft.items[0].masterProductionSchedule == ["11.0", "12.0", "13.0"])
    #expect(throws: MaterialRequirementsPlanningDraftError.self) { try draft.makeModel() }
    draft.confirmImportedDimensions()
    #expect(throws: MaterialRequirementsPlanningDraftError.self) { try draft.makeModel() }
    draft.bucketNames[1] = "Period 1"
    draft.bucketNames[2] = "Period 2"
    #expect(throws: MaterialRequirementsPlanningDraftError.self) { try draft.makeModel() }
    draft.items[0].scheduledReceipts[2] = "9"
    let repaired = try draft.makeModel()
    #expect(repaired.items[0].scheduledReceipts == [7, 8, 9])
    #expect(repaired.items[0].capacity == [nil, nil, nil])
    #expect(repaired.masterProductionSchedule["ITEM1"] == [11, 12, 13])
    #expect(try MaterialRequirementsPlanningJSON.decodeModel(from: MaterialRequirementsPlanningJSON.encodeModel(repaired)) == repaired)
}

@Test("MRP orphan MPS rows become incomplete native items and survive spreadsheet repair")
func mrpOrphanScheduleRepair() throws {
    var draft = MaterialRequirementsPlanningDraft(mrpImportedDimensionFixture(orphan: true))
    #expect(draft.items.map(\.identifier) == ["ITEM1", "ORPHAN"])
    #expect(draft.items[1].unit.isEmpty)
    #expect(draft.items[1].leadTime.isEmpty)
    #expect(draft.items[1].masterProductionSchedule == ["21.0", "22.0", "23.0", "24.0"])
    let identity = draft.items[1].id
    draft.renameItem(id: identity, to: "FINISHED")
    for index in 1..<draft.bucketNames.count { draft.bucketNames[index] = "Period \(index)" }
    var items = try SpreadsheetTable(text: draft.itemTabularText()).rows
    items[2][4] = "unit"
    items[2][5] = "0"
    for column in [8, 9, 10, 11, 13, 14] { items[2][column] = "0" }
    try draft.replaceItems(withTabularText: items.map { $0.joined(separator: "\t") }.joined(separator: "\n"))
    #expect(draft.items[1].id == identity)
    var schedules = try SpreadsheetTable(text: draft.scheduleTabularText()).rows
    for index in schedules.indices.dropFirst() where schedules[index][2].isEmpty { schedules[index][2] = "0" }
    try draft.replaceSchedules(withTabularText: schedules.map { $0.joined(separator: "\t") }.joined(separator: "\n"))
    #expect(draft.hasImportedDimensionIssue)
    draft.confirmImportedDimensions()
    let repaired = try draft.makeModel()
    #expect(repaired.masterProductionSchedule["FINISHED"] == [21, 22, 23, 24])
    #expect(repaired.masterProductionSchedule["ITEM1"] == [11, 12, 13, 0])
    #expect(!MaterialRequirementsPlanningValidator.diagnostics(for: repaired).contains { $0.severity == .error })
}

@MainActor
@Test("MRP JSON Apply exposes dimension review and its acceptance supports undo redo")
func mrpDimensionReviewWorkspaceUndo() throws {
    let workspace = QSBWorkspace()
    workspace.modelJSON = String(decoding: try MaterialRequirementsPlanningJSON.encodeModel(mrpImportedDimensionFixture(orphan: true)), as: UTF8.self)
    workspace.applyMaterialRequirementsPlanningJSONToNativeEditor()
    let imported = try #require(workspace.materialRequirementsPlanningDraft)
    #expect(imported.hasImportedDimensionIssue)
    #expect(workspace.selectedPane == .model)
    let undo = UndoManager()
    var accepted = imported
    accepted.confirmImportedDimensions()
    workspace.replaceMaterialRequirementsPlanningDraft(accepted, undoManager: undo, actionName: "Review Imported MRP Dimensions")
    workspace.validateCurrentModel()
    #expect(workspace.modelState == .invalid)
    undo.undo()
    #expect(workspace.materialRequirementsPlanningDraft == imported)
    undo.redo()
    #expect(workspace.materialRequirementsPlanningDraft == accepted)
}
