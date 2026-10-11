import Foundation
import Testing
import QSBCore
@testable import QSBMacApp

@Test("simulation draft preserves components, routes, and distributions")
func simulationDraftRoundTrip() throws {
    let model = try SimulationJSON.decodeUncheckedModel(from: Data(SampleModels.simulationJSON.utf8))
    let draft = SimulationDraft(model)

    #expect(try draft.makeModel() == model)
    #expect(draft.components.count == 3)
    #expect(draft.components.first?.interarrivalTime?.kind == .exponential)
    #expect(draft.components.last?.serviceRules.count == 1)
    #expect(!draft.draftDiagnostics().contains { $0.severity == .error })
}

@Test("simulation component rename keeps route targets aligned")
func simulationDraftReferenceSafeRename() throws {
    let model = try SimulationJSON.decodeUncheckedModel(from: Data(SampleModels.simulationJSON.utf8))
    var draft = SimulationDraft(model)
    let queueID = try #require(draft.components.first(where: { $0.name == "Queue" })?.id)

    draft.renameComponent(id: queueID, to: "Waiting Line")
    #expect(draft.components.first?.routes.first?.target == "Waiting Line")
    #expect(try draft.makeModel().components.first?.routes.first?.target == "Waiting Line")
}

@Test("simulation spreadsheet transfers are complete and atomic")
func simulationSpreadsheetTransfers() throws {
    let model = try SimulationJSON.decodeUncheckedModel(from: Data(SampleModels.simulationJSON.utf8))
    var draft = SimulationDraft(model)
    let components = draft.componentTabularText()
    let routes = draft.routeTabularText()
    let services = draft.serviceTabularText()

    try draft.replaceComponents(withTabularText: components)
    try draft.replaceRoutes(withTabularText: routes)
    try draft.replaceServiceRules(withTabularText: services)
    #expect(try draft.makeModel() == model)

    let before = draft
    var invalidRows = try SpreadsheetTable(text: routes).rows
    invalidRows[1][2] = "not a probability"
    let invalid = invalidRows.map { $0.joined(separator: "\t") }.joined(separator: "\n")
    #expect(throws: SpreadsheetTransferError.self) { try draft.replaceRoutes(withTabularText: invalid) }
    #expect(draft == before)
}

@MainActor
@Test("workspace routes native simulation drafts through validation, solving, and export")
func simulationDraftWorkspaceWorkflow() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.simulation)
    #expect(workspace.simulationDraft != nil)
    guard case .simulation = workspace.currentModelFamily else {
        Issue.record("Expected simulation family")
        return
    }

    workspace.validateCurrentModel()
    #expect(workspace.modelState == .valid)
    workspace.runCurrentModel()
    #expect(workspace.runState == .solved)
    workspace.beginModelExport()
    #expect(workspace.isExportingModel)
    let exported = try SimulationJSON.decodeUncheckedModel(from: Data(workspace.modelJSON.utf8))
    #expect(exported.components.count == 3)
}

@MainActor
@Test("simulation workspace reports invalid native fields and participates in undo and redo")
func simulationInvalidStateAndUndo() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.simulation)
    let original = try #require(workspace.simulationDraft)
    var changed = original
    changed.components[0].interarrivalTime?.parameters[0] = "not a number"
    let undoManager = UndoManager()

    workspace.replaceSimulationDraft(changed, undoManager: undoManager, actionName: "Edit Arrival Distribution")
    workspace.validateCurrentModel()
    #expect(workspace.modelState == .invalid)
    #expect(workspace.validationDiagnostics.contains { $0.path?.contains("interarrivalTime") == true })

    undoManager.undo()
    #expect(workspace.simulationDraft == original)
    undoManager.redo()
    #expect(workspace.simulationDraft == changed)
}

@Test("Simulation tables repair independently without consuming other unfinished sections")
func simulationIndependentSpreadsheetRepair() throws {
    var draft = SimulationDraft.blank()
    let componentTable = draft.componentTabularText()
    let routeTable = draft.routeTabularText()
    let serviceTable = draft.serviceTabularText()
    let componentIDs = draft.components.map(\.id)
    draft.title = ""
    draft.timeUnit = ""
    draft.components[0].routes[0].probability = "unfinished route"
    draft.components[1].queueCapacity = "unfinished capacity"
    draft.components[2].serviceRules[0].distribution.parameters = ["unfinished service"]
    try draft.replaceRoutes(withTabularText: routeTable)
    #expect(draft.components[1].queueCapacity == "unfinished capacity")
    #expect(draft.components[2].serviceRules[0].distribution.parameters == ["unfinished service"])
    draft.components[0].routes[0].probability = "unfinished route"
    try draft.replaceServiceRules(withTabularText: serviceTable)
    #expect(draft.components[0].routes[0].probability == "unfinished route")
    #expect(draft.components[1].queueCapacity == "unfinished capacity")
    let routeID = draft.components[0].routes[0].id
    try draft.replaceComponents(withTabularText: componentTable)
    #expect(draft.components.map(\.id) == componentIDs)
    #expect(draft.components[0].routes[0].id == routeID)
    #expect(draft.components[0].routes[0].probability == "unfinished route")
    #expect(draft.title.isEmpty && draft.timeUnit.isEmpty)
    try draft.replaceRoutes(withTabularText: SimulationDraft.routeHeaders.joined(separator: "\t"))
    try draft.replaceServiceRules(withTabularText: SimulationDraft.serviceHeaders.joined(separator: "\t"))
    #expect(draft.components.allSatisfy { $0.routes.isEmpty && $0.serviceRules.isEmpty })
}

@Test("Simulation spreadsheet identities survive reorder and structured keys avoid collisions")
func simulationSpreadsheetIdentities() throws {
    var draft = SimulationDraft.blank()
    draft.components = [
        SimulationComponentDraft(name: "a|b", kind: .queue, routes: [SimulationRouteDraft(target: "c")],
            serviceRules: [SimulationServiceRuleDraft(entityType: "c")]),
        SimulationComponentDraft(name: "a", kind: .queue, routes: [SimulationRouteDraft(target: "b|c")],
            serviceRules: [SimulationServiceRuleDraft(entityType: "b|c")])
    ]
    let routeIDs = draft.components.map { $0.routes[0].id }
    let serviceIDs = draft.components.map { $0.serviceRules[0].id }
    try draft.replaceRoutes(withTabularText: "a\tb|c\t0.5\t2\nA|B\tC\t1\t3")
    try draft.replaceServiceRules(withTabularText: "a\tb|c\tconstant\t2\nA|B\tC\tconstant\t3")
    #expect(draft.components.map { $0.routes[0].id } == routeIDs)
    #expect(draft.components.map { $0.serviceRules[0].id } == serviceIDs)
    try draft.replaceRoutes(withTabularText: "a\tb|c\t0.5\t2\na\tB|C\t0.5\t3")
    #expect(draft.components[1].routes[0].id != draft.components[1].routes[1].id)
    #expect(draft.components[1].routes.allSatisfy { $0.id != routeIDs[1] })
    try draft.replaceServiceRules(withTabularText: "a\tb|c\tconstant\t2\na\tB|C\tconstant\t3")
    #expect(draft.components[1].serviceRules[0].id != draft.components[1].serviceRules[1].id)
}

@Test("Simulation complete headers preserve reserved-looking names and rejected paste is atomic")
func simulationCompleteHeadersAndAtomicPaste() throws {
    var draft = SimulationDraft.blank()
    draft.components = [SimulationComponentDraft(name: "Source", kind: .queue), SimulationComponentDraft(name: "Server", kind: .server)]
    try draft.replaceRoutes(withTabularText: "Source\tServer\t1\t0")
    try draft.replaceServiceRules(withTabularText: "Server\tSource\tconstant\t2")
    #expect(draft.components[0].routes.count == 1)
    #expect(draft.components[1].serviceRules.count == 1)
    let before = draft
    for table in ["Missing\tServer\t1\t0", "Source\tServer\tbad\t0", "Source\tServer\t1"] {
        #expect(throws: SpreadsheetTransferError.self) { try draft.replaceRoutes(withTabularText: table) }
        #expect(draft == before)
    }
    #expect(throws: SpreadsheetTransferError.self) { try draft.replaceServiceRules(withTabularText: "Server\tSource\tconstant\tbad") }
    #expect(draft == before)
    var duplicate = draft
    duplicate.components.append(SimulationComponentDraft(name: "source", kind: .queue))
    let ambiguous = duplicate
    #expect(throws: SpreadsheetTransferError.self) { try duplicate.replaceRoutes(withTabularText: "Source\tServer\t1\t0") }
    #expect(duplicate == ambiguous)
}

@MainActor
@Test("Simulation independent spreadsheet repair participates in undo and redo")
func simulationSpreadsheetRepairUndo() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.simulation)
    var original = try #require(workspace.simulationDraft)
    original.title = ""
    workspace.replaceSimulationDraft(original)
    var repaired = original
    var rows = try SpreadsheetTable(text: repaired.routeTabularText()).rows
    rows[1][3] = "7"
    try repaired.replaceRoutes(withTabularText: rows.map { $0.joined(separator: "\t") }.joined(separator: "\n"))
    let undo = UndoManager()
    workspace.replaceSimulationDraft(repaired, undoManager: undo, actionName: "Paste Routes")
    #expect(workspace.simulationDraft == repaired)
    undo.undo()
    #expect(workspace.simulationDraft == original)
    undo.redo()
    #expect(workspace.simulationDraft == repaired)
}
