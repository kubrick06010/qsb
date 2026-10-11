import Foundation
import Testing
import QSBCore
@testable import QSBMacApp

@Test("CPM draft round trips through the typed project model")
func cpmDraftRoundTrip() throws {
    let model = ProjectSchedulingModelEnvelope.cpm(CPMProject(
        title: "Launch",
        timeUnit: "day",
        activities: [
            CPMActivity(name: "A", predecessors: [], normalTime: 4, crashTime: 2, normalCost: 100, crashCost: 140),
            CPMActivity(name: "B", predecessors: ["A"], normalTime: 3, crashTime: 2, normalCost: 80, crashCost: 100)
        ]
    ))
    let draft = ProjectSchedulingDraft(model)
    #expect(try draft.makeModel() == model)
    #expect(!draft.draftDiagnostics().contains { $0.severity == .error })
}

@Test("PERT draft preserves three-point estimates and validates precedence")
func pertDraftRoundTrip() throws {
    let model = ProjectSchedulingModelEnvelope.pert(PERTProject(
        title: "Research",
        timeUnit: "week",
        activities: [
            PERTActivity(name: "Study", predecessors: [], optimisticTime: 1, mostLikelyTime: 2, pessimisticTime: 4),
            PERTActivity(name: "Report", predecessors: ["Study"], optimisticTime: 2, mostLikelyTime: 3, pessimisticTime: 5)
        ]
    ))
    var draft = ProjectSchedulingDraft(model)
    #expect(try draft.makeModel() == model)
    draft.activities[0].predecessors = "Report"
    #expect(draft.draftDiagnostics().contains { $0.code == "project.precedence.cycle" })
}

@Test("project spreadsheet transfer is atomic and method aware")
func projectSpreadsheetTransfer() throws {
    var draft = ProjectSchedulingDraft.blank(.deterministicCPM)
    try draft.replaceActivities(withTabularText: """
    Activity\tPredecessors\tNormal Time\tCrash Time\tNormal Cost\tCrash Cost
    Design\t\t4\t3\t100\t140
    Build\tDesign\t6\t4\t200\t280
    """)
    guard case .cpm(let project) = try draft.makeModel() else { Issue.record("Expected CPM project"); return }
    #expect(project.activities.map(\.name) == ["Design", "Build"])
    #expect(project.activities[1].predecessors == ["Design"])
    #expect(draft.tabularText().hasPrefix("Activity\tPredecessors\tNormal Time"))

    let before = draft
    #expect(throws: SpreadsheetTransferError.self) {
        try draft.replaceActivities(withTabularText: "Build\tDesign\tnot-a-number\t4\t200\t280")
    }
    #expect(draft == before)
}

@MainActor
@Test("workspace routes project drafts through validation, solving, and export")
func projectDraftWorkspaceWorkflow() throws {
    let workspace = QSBWorkspace()
    workspace.startNewProjectScheduling(.deterministicCPM)
    #expect(workspace.projectSchedulingDraft != nil)
    guard case .projectScheduling(.deterministicCPM) = workspace.currentModelFamily else {
        Issue.record("Expected native CPM family")
        return
    }

    workspace.validateCurrentModel()
    #expect(workspace.modelState == .valid)
    workspace.runCurrentModel()
    #expect(workspace.runState == .solved)
    workspace.beginModelExport()
    #expect(workspace.isExportingModel)
    #expect(try ProjectSchedulingJSON.decodeModel(from: Data(workspace.modelJSON.utf8)).kind == .deterministicCPM)
}


@Test("method exploration retains both project formulations and incomplete values")
func projectMethodPreservation() throws {
    var draft = ProjectSchedulingDraft.blank()
    draft.activities[0].normalTime = "8"
    draft.activities[0].crashTime = "5"
    draft.activities[0].normalCost = "100"
    draft.activities[0].crashCost = "150"
    let cpm = draft.activities[0]
    draft.changeKind(to: .probabilisticPERT)
    #expect(draft.activities[0].optimisticTime == "8")
    draft.activities[0].optimisticTime = "unfinished"
    draft.activities[0].mostLikelyTime = "9"
    draft.activities[0].pessimisticTime = "12"
    draft.changeKind(to: .deterministicCPM)
    #expect(draft.activities[0].id == cpm.id)
    #expect(draft.activities[0].normalTime == "8" && draft.activities[0].crashTime == "5")
    #expect(draft.activities[0].normalCost == "100" && draft.activities[0].crashCost == "150")
    #expect(try draft.makeModel().kind == .deterministicCPM)
    draft.changeKind(to: .probabilisticPERT)
    #expect(draft.activities[0].optimisticTime == "unfinished")
    #expect(draft.activities[0].mostLikelyTime == "9" && draft.activities[0].pessimisticTime == "12")
    #expect(throws: ProjectSchedulingDraftError.self) { try draft.makeModel() }
}

@Test("first CPM visit uses core PERT expected time and then preserves edits")
func projectFirstCPMSeed() throws {
    var draft = ProjectSchedulingDraft.blank(.probabilisticPERT)
    draft.activities[0].optimisticTime = "1"
    draft.activities[0].mostLikelyTime = "2"
    draft.activities[0].pessimisticTime = "9"
    draft.changeKind(to: .deterministicCPM)
    let expected = PERTActivity(name: "A", predecessors: [], optimisticTime: 1, mostLikelyTime: 2, pessimisticTime: 9).expectedTime
    #expect(draft.activities[0].normalTime == String(expected))
    draft.activities[0].crashCost = "unfinished"
    draft.changeKind(to: .probabilisticPERT)
    draft.changeKind(to: .deterministicCPM)
    #expect(draft.activities[0].crashCost == "unfinished")
}

@Test("project table repair retains matching activities and hidden estimates independently")
func projectIndependentTableRepair() throws {
    var draft = ProjectSchedulingDraft.blank()
    draft.activities[0].name = "Activity"
    draft.changeKind(to: .probabilisticPERT)
    draft.activities[0].optimisticTime = "unfinished"
    draft.activities.append(ProjectActivityDraft(name: "Build"))
    let ids = draft.activities.map(\.id)
    draft.changeKind(to: .deterministicCPM)
    draft.title = ""
    draft.timeUnit = ""
    try draft.replaceActivities(withTabularText: "Build\tActivity\t6\t4\t200\t280\nActivity\t\t4\t3\t100\t140")
    #expect(draft.activities.map(\.id) == ids.reversed())
    #expect(draft.activities[1].optimisticTime == "unfinished")
    #expect(draft.title.isEmpty && draft.timeUnit.isEmpty)
    let before = draft
    #expect(throws: SpreadsheetTransferError.self) {
        try draft.replaceActivities(withTabularText: "Build\tActivity\t6\t4\t200\t280\nActivity\t\tbad\t3\t100\t140")
    }
    #expect(draft == before)
    draft.title = "Launch"
    draft.timeUnit = "day"
    #expect(!draft.draftDiagnostics().contains { $0.severity == .error })
    draft.changeKind(to: .probabilisticPERT)
    #expect(draft.activities[1].optimisticTime == "unfinished")
}

@Test("PERT paste preserves dormant CPM costs and ambiguous activities get separate identities")
func projectPERTTablePreservation() throws {
    var draft = ProjectSchedulingDraft.blank()
    draft.activities[0].name = "Design"
    draft.activities[0].normalCost = "unfinished"
    let id = draft.activities[0].id
    draft.changeKind(to: .probabilisticPERT)
    try draft.replaceActivities(withTabularText: "Activity\tPredecessors\tOptimistic Time\tMost Likely Time\tPessimistic Time\nDesign\t\t1\t2\t4")
    #expect(draft.activities[0].id == id)
    #expect(draft.activities[0].normalCost == "unfinished")
    try draft.replaceActivities(withTabularText: "Design\t\t1\t2\t4\nDesign\t\t2\t3\t5")
    #expect(Set(draft.activities.map(\.id)).count == 2)
    #expect(!draft.activities.contains { $0.id == id })
    #expect(draft.draftDiagnostics().contains { $0.severity == .error })
}

@MainActor
@Test("project method history and hidden input survive workspace undo and redo")
func projectMethodWorkspaceUndo() throws {
    let workspace = QSBWorkspace()
    workspace.startNewProjectScheduling(.deterministicCPM)
    let manager = UndoManager()
    var original = try #require(workspace.projectSchedulingDraft)
    original.activities[0].normalCost = "unfinished"
    workspace.replaceProjectSchedulingDraft(original)
    var pert = original
    pert.changeKind(to: .probabilisticPERT)
    workspace.replaceProjectSchedulingDraft(pert, undoManager: manager, actionName: "Change Method")
    workspace.validateCurrentModel()
    #expect(workspace.modelState == .valid)
    manager.undo()
    #expect(workspace.projectSchedulingDraft == original)
    workspace.validateCurrentModel()
    #expect(workspace.modelState == .invalid)
    manager.redo()
    #expect(workspace.projectSchedulingDraft == pert)
    var returned = try #require(workspace.projectSchedulingDraft)
    returned.changeKind(to: .deterministicCPM)
    #expect(returned.activities[0].normalCost == "unfinished")
}
