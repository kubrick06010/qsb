import Foundation
import QSBCore
import Testing
@testable import QSBMacApp

private let typedRunSamples: [SampleModel] = [.quadraticProgramming, .nonlinearProgramming, .goalProgramming, .acceptanceSampling, .qualityControl]

@MainActor
private func typedRunWorkspace(_ sample: SampleModel) -> QSBWorkspace {
    let workspace = QSBWorkspace()
    workspace.loadSample(sample)
    return workspace
}

@MainActor
private func renameTypedDraft(_ workspace: QSBWorkspace, title: String) throws {
    if var draft = workspace.quadraticProgrammingDraft { draft.title = title; workspace.replaceQuadraticProgrammingDraft(draft) }
    else if var draft = workspace.nonlinearProgrammingDraft { draft.title = title; workspace.replaceNonlinearProgrammingDraft(draft) }
    else if var draft = workspace.goalProgrammingDraft { draft.title = title; workspace.replaceGoalProgrammingDraft(draft) }
    else if var draft = workspace.acceptanceSamplingDraft { draft.title = title; workspace.replaceAcceptanceSamplingDraft(draft) }
    else if var draft = workspace.qualityControlDraft { draft.title = title; workspace.replaceQualityControlDraft(draft) }
    else { Issue.record("Expected a typed native draft") }
}

@MainActor
private func gatedTypedRun(_ workspace: QSBWorkspace, gate: DispatchSemaphore, fail: Bool = false) -> Task<Void, Never>? {
    workspace.startTypedModelRun { request in
        #expect(!Thread.isMainThread)
        gate.wait()
        if fail { throw NonlinearProgrammingError.invalidModel("Worker failure") }
        return try TypedModelRunOperation.run(request)
    }
}

@MainActor
@Test("Optimization and quality UI runs are off main and preserve normalized core results")
func typedModelInteractiveRuns() async throws {
    for sample in typedRunSamples {
        let workspace = typedRunWorkspace(sample)
        workspace.runCurrentModel()
        #expect(workspace.runState == .solved)
        let expected = workspace.solutionJSON
        let label = workspace.lastResultLabel
        let gate = DispatchSemaphore(value: 0)
        let task = try #require(gatedTypedRun(workspace, gate: gate))
        #expect(workspace.runState == .solving && workspace.statusSystemImage == "hourglass")
        #expect(workspace.solutionJSON.isEmpty && workspace.startCurrentModelRun() == nil)
        gate.signal()
        await task.value
        #expect(workspace.runState == .solved && workspace.selectedPane == .solution)
        #expect(workspace.solutionJSON == expected && workspace.lastResultLabel == label)
    }
}

@MainActor
@Test("Typed worker results cannot replace edited models, validation or replacement families")
func typedModelStaleEdits() async throws {
    for sample in typedRunSamples {
        for change in 0..<3 {
            let workspace = typedRunWorkspace(sample)
            let gate = DispatchSemaphore(value: 0)
            let task = try #require(gatedTypedRun(workspace, gate: gate))
            if change == 0 { try renameTypedDraft(workspace, title: "Edited model") }
            else if change == 1 { workspace.startNewProjectScheduling() }
            else { workspace.validateCurrentModel() }
            let status = workspace.status
            let pane = workspace.selectedPane
            let validation = workspace.validationJSON
            gate.signal()
            await task.value
            #expect(workspace.runState == .notRun && workspace.solutionJSON.isEmpty)
            #expect(workspace.status == status && workspace.selectedPane == pane)
            #expect(workspace.validationJSON == validation)
        }
    }
}

@MainActor
@Test("Typed runs check backend and JSON and ignore superseded results and errors")
func typedModelChangedSourcesAndSuperseded() async throws {
    for sample in typedRunSamples {
        for changeJSON in [false, true] {
            let workspace = typedRunWorkspace(sample)
            let gate = DispatchSemaphore(value: 0)
            let task = try #require(gatedTypedRun(workspace, gate: gate))
            if changeJSON { workspace.modelJSON = "unfinished JSON" }
            else { workspace.selectedBackend = .validateOnly }
            gate.signal()
            await task.value
            #expect(workspace.runState == .notRun && workspace.solutionJSON.isEmpty)
        }
        for fail in [false, true] {
            let workspace = typedRunWorkspace(sample)
            let gate = DispatchSemaphore(value: 0)
            let old = try #require(gatedTypedRun(workspace, gate: gate, fail: fail))
            defer { gate.signal() }
            try renameTypedDraft(workspace, title: "Current model")
            try await #require(workspace.startCurrentModelRun()).value
            let result = workspace.solutionJSON
            let status = workspace.status
            gate.signal()
            await old.value
            #expect(workspace.runState == .solved && workspace.lastErrorMessage == nil)
            #expect(workspace.solutionJSON == result && workspace.status == status)
        }
    }
}

@MainActor
@Test("Typed runs expose validation native errors and current worker failures")
func typedModelValidationAndFailure() async throws {
    for sample in typedRunSamples {
        let workspace = typedRunWorkspace(sample)
        workspace.selectedBackend = .validateOnly
        try await #require(workspace.startCurrentModelRun()).value
        #expect(workspace.modelState == .valid && workspace.runState == .notRun)
        #expect(workspace.selectedPane == .validation && !workspace.validationJSON.isEmpty)
        workspace.selectedBackend = .nativeEducational
        let gate = DispatchSemaphore(value: 0)
        let task = try #require(gatedTypedRun(workspace, gate: gate, fail: true))
        gate.signal()
        await task.value
        #expect(workspace.runState == .failed && workspace.lastErrorMessage?.contains("Worker failure") == true)
        try renameTypedDraft(workspace, title: "")
        #expect(workspace.startCurrentModelRun() == nil)
        #expect(workspace.modelState == .invalid && workspace.selectedPane == .validation)
    }
    let nonlinear = typedRunWorkspace(.nonlinearProgramming)
    var nlp = try #require(nonlinear.nonlinearProgrammingDraft)
    nlp.objectiveExpression = "missingVariable + 1"
    nonlinear.replaceNonlinearProgrammingDraft(nlp)
    try await #require(nonlinear.startCurrentModelRun()).value
    #expect(nonlinear.modelState == .invalid && nonlinear.selectedPane == .validation)
    let quality = typedRunWorkspace(.qualityControl)
    var qc = try #require(quality.qualityControlDraft)
    qc.rows[0].values[0] = "-1"
    quality.replaceQualityControlDraft(qc)
    try await #require(quality.startCurrentModelRun()).value
    #expect(quality.modelState == .invalid && quality.selectedPane == .validation)
}

@MainActor
@Test("Typed execution preserves quality and sampling variants and unavailable-backend guidance")
func typedModelVariantsAndBackends() async throws {
    for kind in [QualityControlProblemKind.cChart, .pChart, .xbarRChart, .pareto, .normalProbabilityPlot] {
        let workspace = QSBWorkspace()
        workspace.startNewQualityControl(kind)
        workspace.selectedBackend = .validateOnly
        let expected = try #require(workspace.qualityControlDraft).draftDiagnostics()
        try await #require(workspace.startCurrentModelRun()).value
        #expect(workspace.qualityControlDraft?.kind == kind)
        #expect(workspace.validationDiagnostics == expected)
        #expect(workspace.selectedPane == .validation)
    }
    for kind in [AcceptanceSamplingPlanKind.single, .double] {
        let workspace = QSBWorkspace()
        workspace.startNewAcceptanceSampling(kind)
        workspace.selectedBackend = .validateOnly
        try await #require(workspace.startCurrentModelRun()).value
        #expect(workspace.acceptanceSamplingDraft?.kind == kind)
        #expect(workspace.selectedPane == .validation)
    }
    for sample in typedRunSamples {
        let workspace = typedRunWorkspace(sample)
        workspace.selectedBackend = .externalHighPerformance
        let task = try #require(workspace.startTypedModelRun { _ in .unavailable })
        await task.value
        #expect(workspace.runState == .failed && workspace.selectedPane == .run)
        if [.nonlinearProgramming, .acceptanceSampling, .qualityControl].contains(sample) {
            #expect(workspace.externalBackendSummary.contains("no external solver integration"))
            #expect(workspace.lastErrorMessage?.contains("QSB Native") == true)
        }
    }
}
