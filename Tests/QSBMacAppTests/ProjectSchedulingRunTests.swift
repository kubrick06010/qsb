import Foundation
import QSBCore
import Testing
@testable import QSBMacApp

@MainActor
@Test("Project UI execution publishes solving and computes CPM and PERT outside the main thread")
func projectInteractiveRun() async throws {
    for kind in [ProjectSchedulingProblemKind.deterministicCPM, .probabilisticPERT] {
        let workspace = QSBWorkspace()
        workspace.startNewProjectScheduling(kind)
        let gate = DispatchSemaphore(value: 0)
        let task = try #require(workspace.startProjectSchedulingRun { request in
            #expect(!Thread.isMainThread)
            #expect(request.model.kind == kind)
            gate.wait()
            return try ProjectSchedulingRunOperation.run(request)
        })
        #expect(workspace.runState == .solving)
        #expect(workspace.statusSystemImage == "hourglass")
        #expect(workspace.status.contains("Running \(kind.rawValue)"))
        #expect(workspace.solutionJSON.isEmpty)
        #expect(workspace.startCurrentModelRun() == nil)
        gate.signal()
        await task.value
        #expect(workspace.runState == .solved)
        #expect(workspace.selectedPane == .solution)
        let document = try ProjectSchedulingJSON.decodeSolution(from: Data(workspace.solutionJSON.utf8))
        #expect(document.model.kind == kind)
        #expect(document.solution.projectDuration == 1)
        #expect(document.backend.backendKind == .nativeEducational)
    }
}

@MainActor
@Test("Pending project results do not replace edited methods or replacement families")
func projectStaleRunAfterEdits() async throws {
    for replaceFamily in [false, true] {
        let workspace = QSBWorkspace()
        workspace.startNewProjectScheduling(.deterministicCPM)
        let gate = DispatchSemaphore(value: 0)
        let task = try #require(workspace.startProjectSchedulingRun { request in
            gate.wait()
            return try ProjectSchedulingRunOperation.run(request)
        })
        if replaceFamily {
            workspace.startNewGoalProgramming()
        } else {
            var draft = try #require(workspace.projectSchedulingDraft)
            draft.changeKind(to: .probabilisticPERT)
            draft.activities[0].optimisticTime = "unfinished"
            workspace.replaceProjectSchedulingDraft(draft)
        }
        let status = workspace.status
        let json = workspace.modelJSON
        let pane = workspace.selectedPane
        gate.signal()
        await task.value
        #expect(workspace.status == status && workspace.modelJSON == json)
        #expect(workspace.selectedPane == pane)
        #expect(workspace.runState == .notRun && workspace.solutionJSON.isEmpty)
        #expect(workspace.lastErrorMessage == nil)
    }
}

@MainActor
@Test("Project run rejects changed backend, raw JSON and stale errors")
func projectStaleRunSources() async throws {
    for changeJSON in [false, true] {
        let workspace = QSBWorkspace()
        workspace.startNewProjectScheduling(.deterministicCPM)
        let gate = DispatchSemaphore(value: 0)
        let task = try #require(workspace.startProjectSchedulingRun { request in
            gate.wait()
            return try ProjectSchedulingRunOperation.run(request)
        })
        if changeJSON { workspace.modelJSON = "unfinished JSON" }
        else { workspace.selectedBackend = .validateOnly }
        gate.signal()
        await task.value
        #expect(workspace.runState == .notRun)
        #expect(workspace.solutionJSON.isEmpty)
    }
    let validated = QSBWorkspace()
    validated.startNewProjectScheduling(.deterministicCPM)
    let validationGate = DispatchSemaphore(value: 0)
    let validationTask = try #require(validated.startProjectSchedulingRun { request in
        validationGate.wait()
        return try ProjectSchedulingRunOperation.run(request)
    })
    validated.validateCurrentModel()
    let validationJSON = validated.validationJSON
    validationGate.signal()
    await validationTask.value
    #expect(validated.runState == .notRun)
    #expect(validated.selectedPane == .validation)
    #expect(validated.validationJSON == validationJSON)
    #expect(validated.solutionJSON.isEmpty)

    let workspace = QSBWorkspace()
    workspace.startNewProjectScheduling(.deterministicCPM)
    let gate = DispatchSemaphore(value: 0)
    let task = try #require(workspace.startProjectSchedulingRun { _ in
        gate.wait()
        throw ProjectSchedulingError.invalidModel("Old worker failure")
    })
    workspace.startNewGoalProgramming()
    gate.signal()
    await task.value
    #expect(workspace.lastErrorMessage == nil)
    #expect(workspace.goalProgrammingDraft != nil)
}

@MainActor
@Test("Project UI execution retains validation-only, unavailable, invalid and failure states")
func projectInteractiveBackendStates() async throws {
    let workspace = QSBWorkspace()
    workspace.startNewProjectScheduling(.probabilisticPERT)
    workspace.selectedBackend = .validateOnly
    try await #require(workspace.startCurrentModelRun()).value
    #expect(workspace.runState == .notRun && workspace.modelState == .valid)
    #expect(workspace.selectedPane == .validation && !workspace.validationJSON.isEmpty)
    workspace.selectedBackend = .externalHighPerformance
    #expect(workspace.externalBackendSummary.contains("no external solver integration"))
    try await #require(workspace.startCurrentModelRun()).value
    #expect(workspace.runState == .failed)
    #expect(workspace.lastErrorMessage?.contains("QSB Native") == true)
    workspace.selectedBackend = .nativeEducational
    try await #require(workspace.startProjectSchedulingRun { _ in
        throw ProjectSchedulingError.invalidModel("Worker failure")
    }).value
    #expect(workspace.runState == .failed)
    #expect(workspace.lastErrorMessage?.contains("Worker failure") == true)
    #expect(workspace.selectedPane == .run)
    var draft = try #require(workspace.projectSchedulingDraft)
    draft.activities[0].optimisticTime = "unfinished"
    workspace.replaceProjectSchedulingDraft(draft)
    #expect(workspace.startCurrentModelRun() == nil)
    #expect(workspace.modelState == .invalid)
    #expect(workspace.solutionJSON.isEmpty)
    draft.activities[0].optimisticTime = "10"
    workspace.replaceProjectSchedulingDraft(draft)
    try await #require(workspace.startCurrentModelRun()).value
    #expect(workspace.modelState == .invalid)
    #expect(workspace.runState == .notRun)
    #expect(workspace.selectedPane == .validation)
    #expect(!workspace.validationJSON.isEmpty)
}

@MainActor
@Test("Superseded project computations cannot replace a newer schedule")
func projectSupersededRun() async throws {
    let workspace = QSBWorkspace()
    workspace.startNewProjectScheduling(.deterministicCPM)
    let gate = DispatchSemaphore(value: 0)
    let oldTask = try #require(workspace.startProjectSchedulingRun { request in
        gate.wait()
        return try ProjectSchedulingRunOperation.run(request)
    })
    defer { gate.signal() }
    var draft = try #require(workspace.projectSchedulingDraft)
    draft.title = "Current project"
    draft.activities[0].normalTime = "8"
    workspace.replaceProjectSchedulingDraft(draft)
    try await #require(workspace.startCurrentModelRun()).value
    let result = workspace.solutionJSON
    let status = workspace.status
    #expect(workspace.runState == .solved)
    gate.signal()
    await oldTask.value
    #expect(workspace.solutionJSON == result && workspace.status == status)
    let document = try ProjectSchedulingJSON.decodeSolution(from: Data(result.utf8))
    #expect(document.model.title == "Current project")
    #expect(document.solution.projectDuration == 8)
}
