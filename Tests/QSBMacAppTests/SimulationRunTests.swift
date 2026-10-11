import Foundation
import QSBCore
import Testing
@testable import QSBMacApp

@MainActor
@Test("Simulation UI run exposes solving, avoids duplicate runs, and computes off the main thread")
func simulationInteractiveRun() async throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.simulation)
    workspace.simulationReplications = 2
    let gate = DispatchSemaphore(value: 0)
    let task = try #require(workspace.startSimulationRun { request in
        #expect(!Thread.isMainThread)
        gate.wait()
        return try SimulationRunOperation.run(request)
    })
    #expect(workspace.runState == .solving)
    #expect(workspace.statusSystemImage == "hourglass")
    #expect(workspace.status.contains("Running Simulation"))
    #expect(workspace.solutionJSON.isEmpty)
    #expect(workspace.startCurrentModelRun() == nil)
    gate.signal()
    await task.value
    #expect(workspace.runState == .solved)
    #expect(workspace.selectedPane == .solution)
    let document = try SimulationJSON.decodeSolution(from: Data(workspace.solutionJSON.utf8))
    #expect(document.solution.replications == 2)
    #expect(document.backend.backendKind == .nativeEducational)
}

@MainActor
@Test("Simulation pending results cannot overwrite an edited draft or a replacement model")
func simulationStaleResultAfterEdits() async throws {
    for replaceFamily in [false, true] {
        let workspace = QSBWorkspace()
        workspace.loadSample(.simulation)
        let gate = DispatchSemaphore(value: 0)
        let task = try #require(workspace.startSimulationRun { request in
            gate.wait()
            return try SimulationRunOperation.run(request)
        })
        if replaceFamily {
            workspace.startNewGoalProgramming()
        } else {
            var draft = try #require(workspace.simulationDraft)
            draft.title = "Unfinished revision"
            draft.components[0].name = ""
            workspace.replaceSimulationDraft(draft)
        }
        let sourceJSON = workspace.modelJSON
        let sourceStatus = workspace.status
        let sourcePane = workspace.selectedPane
        gate.signal()
        await task.value
        #expect(workspace.modelJSON == sourceJSON)
        #expect(workspace.status == sourceStatus)
        #expect(workspace.selectedPane == sourcePane)
        #expect(workspace.runState == .notRun)
        #expect(workspace.solutionJSON.isEmpty)
        #expect(workspace.lastErrorMessage == nil)
        if replaceFamily { #expect(workspace.goalProgrammingDraft != nil) }
        else { #expect(workspace.simulationDraft?.title == "Unfinished revision") }
    }
}

@MainActor
@Test("Simulation discards changed run options and stale errors")
func simulationStaleOptionsAndErrors() async throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.simulation)
    let gate = DispatchSemaphore(value: 0)
    let task = try #require(workspace.startSimulationRun { request in
        gate.wait()
        return try SimulationRunOperation.run(request)
    })
    workspace.simulationReplications = 3
    gate.signal()
    await task.value
    #expect(workspace.runState == .notRun)
    #expect(workspace.solutionJSON.isEmpty)
    #expect(workspace.status.contains("inputs changed"))
    let errorGate = DispatchSemaphore(value: 0)
    let failing = try #require(workspace.startSimulationRun { _ in
        errorGate.wait()
        throw SimulationError.invalidModel("Old failure")
    })
    workspace.startNewGoalProgramming()
    errorGate.signal()
    await failing.value
    #expect(workspace.lastErrorMessage == nil)
    #expect(workspace.runState == .notRun)
    #expect(workspace.goalProgrammingDraft != nil)
}

@MainActor
@Test("Simulation UI run preserves validation-only and unavailable-backend states and displays worker errors")
func simulationInteractiveBackendStates() async throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.simulation)
    workspace.selectedBackend = .validateOnly
    try await #require(workspace.startCurrentModelRun()).value
    #expect(workspace.runState == .notRun)
    #expect(workspace.modelState == .valid)
    #expect(workspace.selectedPane == .validation)
    #expect(!workspace.validationJSON.isEmpty)
    #expect(workspace.solutionJSON.isEmpty)
    workspace.selectedBackend = .externalHighPerformance
    #expect(workspace.externalBackendSummary.contains("Simulation has no external solver integration"))
    try await #require(workspace.startCurrentModelRun()).value
    #expect(workspace.runState == .failed)
    #expect(workspace.lastErrorMessage?.contains("QSB Native") == true)
    workspace.selectedBackend = .nativeEducational
    let failing = try #require(workspace.startSimulationRun { _ in
        throw SimulationError.invalidModel("Worker failure")
    })
    await failing.value
    #expect(workspace.runState == .failed)
    #expect(workspace.lastErrorMessage?.contains("Worker failure") == true)
    #expect(workspace.selectedPane == .run)
    #expect(workspace.solutionJSON.isEmpty)
}

@MainActor
@Test("A superseded Simulation run cannot replace a newer result")
func simulationSupersededRun() async throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.simulation)
    let gate = DispatchSemaphore(value: 0)
    let oldTask = try #require(workspace.startSimulationRun { request in
        gate.wait()
        return try SimulationRunOperation.run(request)
    })
    defer { gate.signal() }
    var draft = try #require(workspace.simulationDraft)
    draft.title = "Current model"
    workspace.replaceSimulationDraft(draft)
    workspace.simulationReplications = 3
    try await #require(workspace.startCurrentModelRun()).value
    #expect(workspace.runState == .solved)
    let currentResult = workspace.solutionJSON
    let currentStatus = workspace.status
    gate.signal()
    await oldTask.value
    #expect(workspace.solutionJSON == currentResult)
    #expect(workspace.status == currentStatus)
    let document = try SimulationJSON.decodeSolution(from: Data(currentResult.utf8))
    #expect(document.model.title == "Current model")
    #expect(document.solution.replications == 3)
}
