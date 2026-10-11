import Foundation
import QSBCore
import Testing
@testable import QSBMacApp

@MainActor
private func planningWorkspace(mrp: Bool) -> QSBWorkspace {
    let workspace = QSBWorkspace()
    workspace.loadSample(mrp ? .materialRequirementsPlanning : .aggregatePlanning)
    return workspace
}

@MainActor
private func gatedPlanningRun(_ workspace: QSBWorkspace, mrp: Bool, gate: DispatchSemaphore,
                             fail: Bool = false) -> Task<Void, Never>? {
    if mrp {
        return workspace.startMaterialRequirementsPlanningRun { request in
            #expect(!Thread.isMainThread)
            gate.wait()
            if fail { throw MaterialRequirementsPlanningError.invalidModel("Worker failure") }
            return try MaterialRequirementsPlanningRunOperation.run(request)
        }
    }
    return workspace.startAggregatePlanningRun { request in
        #expect(!Thread.isMainThread)
        gate.wait()
        if fail { throw AggregatePlanningError.invalidModel("Worker failure") }
        return try AggregatePlanningRunOperation.run(request)
    }
}

@MainActor
private func renamePlanningDraft(_ workspace: QSBWorkspace, mrp: Bool, title: String) throws {
    if mrp {
        var draft = try #require(workspace.materialRequirementsPlanningDraft)
        draft.title = title
        workspace.replaceMaterialRequirementsPlanningDraft(draft)
    } else {
        var draft = try #require(workspace.aggregatePlanningDraft)
        draft.title = title
        workspace.replaceAggregatePlanningDraft(draft)
    }
}

@MainActor
@Test("Aggregate and MRP UI runs publish pending state and produce typed core solutions off main")
func planningInteractiveRuns() async throws {
    for mrp in [false, true] {
        let workspace = planningWorkspace(mrp: mrp)
        let gate = DispatchSemaphore(value: 0)
        let task = try #require(gatedPlanningRun(workspace, mrp: mrp, gate: gate))
        #expect(workspace.runState == .solving)
        #expect(workspace.statusSystemImage == "hourglass")
        #expect(workspace.solutionJSON.isEmpty)
        #expect(workspace.startCurrentModelRun() == nil)
        gate.signal()
        await task.value
        #expect(workspace.runState == .solved && workspace.selectedPane == .solution)
        if mrp {
            let document = try MaterialRequirementsPlanningJSON.decodeSolution(from: Data(workspace.solutionJSON.utf8))
            #expect(!document.solution.schedules.isEmpty)
            #expect(workspace.lastResultLabel == "Material Requirements Planning Solution")
        } else {
            let document = try AggregatePlanningJSON.decodeSolution(from: Data(workspace.solutionJSON.utf8))
            #expect(document.solution.totalCost.isFinite)
            #expect(workspace.lastResultLabel == "Aggregate Planning Solution")
        }
    }
}

@MainActor
@Test("Planning runs ignore results after native edits, replacement families, or validation")
func planningStaleEdits() async throws {
    for mrp in [false, true] {
        for change in 0..<3 {
            let workspace = planningWorkspace(mrp: mrp)
            let gate = DispatchSemaphore(value: 0)
            let task = try #require(gatedPlanningRun(workspace, mrp: mrp, gate: gate))
            if change == 0 { try renamePlanningDraft(workspace, mrp: mrp, title: "Edited plan") }
            else if change == 1 { workspace.startNewGoalProgramming() }
            else { workspace.validateCurrentModel() }
            let status = workspace.status
            let pane = workspace.selectedPane
            let model = workspace.modelJSON
            let validation = workspace.validationJSON
            gate.signal()
            await task.value
            #expect(workspace.runState == .notRun)
            #expect(workspace.solutionJSON.isEmpty)
            #expect(workspace.status == status && workspace.selectedPane == pane)
            #expect(workspace.modelJSON == model && workspace.validationJSON == validation)
        }
    }
}

@MainActor
@Test("Planning runs discard changed backend and JSON and cannot overwrite a newer result")
func planningChangedSourcesAndSuperseded() async throws {
    for mrp in [false, true] {
        for changeJSON in [false, true] {
            let workspace = planningWorkspace(mrp: mrp)
            let gate = DispatchSemaphore(value: 0)
            let task = try #require(gatedPlanningRun(workspace, mrp: mrp, gate: gate))
            if changeJSON { workspace.modelJSON = "unfinished JSON" }
            else { workspace.selectedBackend = .validateOnly }
            gate.signal()
            await task.value
            #expect(workspace.runState == .notRun && workspace.solutionJSON.isEmpty)
        }
        let workspace = planningWorkspace(mrp: mrp)
        let gate = DispatchSemaphore(value: 0)
        let old = try #require(gatedPlanningRun(workspace, mrp: mrp, gate: gate))
        defer { gate.signal() }
        try renamePlanningDraft(workspace, mrp: mrp, title: "New plan")
        try await #require(workspace.startCurrentModelRun()).value
        #expect(workspace.runState == .solved)
        let current = workspace.solutionJSON
        let status = workspace.status
        gate.signal()
        await old.value
        #expect(workspace.solutionJSON == current && workspace.status == status)
    }
}

@MainActor
@Test("Planning UI retains validation-only, invalid native and invalid core states")
func planningInteractiveValidation() async throws {
    for mrp in [false, true] {
        let workspace = planningWorkspace(mrp: mrp)
        workspace.selectedBackend = .validateOnly
        try await #require(workspace.startCurrentModelRun()).value
        #expect(workspace.runState == .notRun && workspace.modelState == .valid)
        #expect(workspace.selectedPane == .validation && !workspace.validationJSON.isEmpty)
        try renamePlanningDraft(workspace, mrp: mrp, title: "")
        #expect(workspace.startCurrentModelRun() == nil)
        #expect(workspace.modelState == .invalid && workspace.selectedPane == .validation)
        try renamePlanningDraft(workspace, mrp: mrp, title: "Invalid domain")
        workspace.selectedBackend = .nativeEducational
        if mrp {
            var draft = try #require(workspace.materialRequirementsPlanningDraft)
            draft.items[0].leadTime = "-1"
            workspace.replaceMaterialRequirementsPlanningDraft(draft)
        } else {
            var draft = try #require(workspace.aggregatePlanningDraft)
            draft.periods[0].demand = "-1"
            workspace.replaceAggregatePlanningDraft(draft)
        }
        try await #require(workspace.startCurrentModelRun()).value
        #expect(workspace.modelState == .invalid && workspace.runState == .notRun)
        #expect(workspace.selectedPane == .validation && workspace.solutionJSON.isEmpty)
    }
}

@MainActor
@Test("Planning failures are visible only for current requests and MRP external guidance is accurate")
func planningInteractiveFailures() async throws {
    for mrp in [false, true] {
        let workspace = planningWorkspace(mrp: mrp)
        let gate = DispatchSemaphore(value: 0)
        let failing = try #require(gatedPlanningRun(workspace, mrp: mrp, gate: gate, fail: true))
        gate.signal()
        await failing.value
        #expect(workspace.runState == .failed && workspace.selectedPane == .run)
        #expect(workspace.lastErrorMessage?.contains("Worker failure") == true)
        let staleGate = DispatchSemaphore(value: 0)
        let stale = try #require(gatedPlanningRun(workspace, mrp: mrp, gate: staleGate, fail: true))
        workspace.startNewGoalProgramming()
        staleGate.signal()
        await stale.value
        #expect(workspace.lastErrorMessage == nil)
        #expect(workspace.goalProgrammingDraft != nil)
    }
    let mrp = planningWorkspace(mrp: true)
    mrp.selectedBackend = .externalHighPerformance
    #expect(mrp.externalBackendSummary.contains("MRP has no external solver integration"))
    try await #require(mrp.startCurrentModelRun()).value
    #expect(mrp.runState == .failed)
    #expect(mrp.lastErrorMessage?.contains("QSB Native") == true)
    let aggregate = planningWorkspace(mrp: false)
    let unavailable = try #require(aggregate.startAggregatePlanningRun { _ in .unavailable })
    await unavailable.value
    #expect(aggregate.runState == .failed)
}
