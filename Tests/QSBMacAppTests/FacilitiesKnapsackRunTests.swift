import Foundation
import QSBCore
import Testing
@testable import QSBMacApp

private enum AsyncFamily: CaseIterable, Sendable {
    case knapsack, line, location, layout
    var sample: SampleModel {
        switch self {
        case .knapsack: .boundedKnapsack
        case .line: .lineBalancing
        case .location: .facilityLocation
        case .layout: .facilityLayout
        }
    }
}

@MainActor
private func asyncWorkspace(_ family: AsyncFamily) -> QSBWorkspace {
    let workspace = QSBWorkspace()
    workspace.loadSample(family.sample)
    return workspace
}

@MainActor
private func gatedRun(_ workspace: QSBWorkspace, family: AsyncFamily, gate: DispatchSemaphore,
                      fail: Bool = false) -> Task<Void, Never>? {
    if family == .knapsack {
        return workspace.startKnapsackRun { request in
            #expect(!Thread.isMainThread)
            gate.wait()
            if fail { throw DynamicProgrammingModelError.invalidModel("Worker failure") }
            return try KnapsackRunOperation.run(request)
        }
    }
    return workspace.startFacilitiesRun { request, strategy in
        #expect(!Thread.isMainThread)
        gate.wait()
        if fail { throw FacilitiesModelError.invalidModel("Worker failure") }
        return try FacilitiesRunOperation.run(request, strategy: strategy)
    }
}

@MainActor
private func rename(_ workspace: QSBWorkspace, family: AsyncFamily, title: String) throws {
    switch family {
    case .knapsack:
        var draft = try #require(workspace.knapsackDraft)
        draft.title = title
        workspace.replaceKnapsackDraft(draft)
    case .line:
        var draft = try #require(workspace.lineBalancingDraft)
        draft.title = title
        workspace.replaceLineBalancingDraft(draft)
    case .location:
        var draft = try #require(workspace.facilityLocationDraft)
        draft.title = title
        workspace.replaceFacilityLocationDraft(draft)
    case .layout:
        var draft = try #require(workspace.facilityLayoutDraft)
        draft.title = title
        workspace.replaceFacilityLayoutDraft(draft)
    }
}

@MainActor
@Test("Facilities and knapsack UI runs compute off main and preserve typed synchronous results")
func facilitiesKnapsackInteractiveRuns() async throws {
    for family in AsyncFamily.allCases {
        let workspace = asyncWorkspace(family)
        workspace.runCurrentModel()
        #expect(workspace.runState == .solved)
        let expected = workspace.solutionJSON
        let label = workspace.lastResultLabel
        let gate = DispatchSemaphore(value: 0)
        let task = try #require(gatedRun(workspace, family: family, gate: gate))
        #expect(workspace.runState == .solving)
        #expect(workspace.statusSystemImage == "hourglass")
        #expect(workspace.solutionJSON.isEmpty)
        #expect(workspace.startCurrentModelRun() == nil)
        gate.signal()
        await task.value
        #expect(workspace.runState == .solved && workspace.selectedPane == .solution)
        #expect(workspace.solutionJSON == expected && workspace.lastResultLabel == label)
    }
}

@MainActor
@Test("Facilities and knapsack ignore computations after edit, replacement or validation")
func facilitiesKnapsackStaleEdits() async throws {
    for family in AsyncFamily.allCases {
        for change in 0..<3 {
            let workspace = asyncWorkspace(family)
            let gate = DispatchSemaphore(value: 0)
            let task = try #require(gatedRun(workspace, family: family, gate: gate))
            if change == 0 { try rename(workspace, family: family, title: "Edited model") }
            else if change == 1 { workspace.startNewGoalProgramming() }
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
@Test("Facilities and knapsack check backend JSON and layout strategy before accepting output")
func facilitiesKnapsackChangedOptions() async throws {
    for family in AsyncFamily.allCases {
        for changeJSON in [false, true] {
            let workspace = asyncWorkspace(family)
            let gate = DispatchSemaphore(value: 0)
            let task = try #require(gatedRun(workspace, family: family, gate: gate))
            if changeJSON { workspace.modelJSON = "unfinished JSON" }
            else { workspace.selectedBackend = .validateOnly }
            gate.signal()
            await task.value
            #expect(workspace.runState == .notRun && workspace.solutionJSON.isEmpty)
        }
    }
    for family in [AsyncFamily.layout, .location] {
        let workspace = asyncWorkspace(family)
        let gate = DispatchSemaphore(value: 0)
        let task = try #require(gatedRun(workspace, family: family, gate: gate))
        workspace.selectedLayoutStrategy = .pairwiseSwap
        gate.signal()
        await task.value
        #expect(workspace.runState == (family == .layout ? .notRun : .solved))
    }
    let layout = asyncWorkspace(.layout)
    layout.selectedLayoutStrategy = .pairwiseSwap
    try await #require(layout.startFacilitiesRun { request, strategy in
        #expect(strategy == .pairwiseSwap)
        return try FacilitiesRunOperation.run(request, strategy: strategy)
    }).value
    #expect(layout.runState == .solved)
    let document = try FacilitiesModelJSON.decodeSolutionDocument(from: Data(layout.solutionJSON.utf8))
    #expect(document.backend.algorithm.contains("pairwise"))
}

@MainActor
@Test("Facilities and knapsack expose validation unavailable invalid and worker failure outcomes")
func facilitiesKnapsackBackendStates() async throws {
    for family in AsyncFamily.allCases {
        let workspace = asyncWorkspace(family)
        workspace.selectedBackend = .validateOnly
        try await #require(workspace.startCurrentModelRun()).value
        #expect(workspace.modelState == .valid && workspace.runState == .notRun)
        #expect(workspace.selectedPane == .validation && !workspace.validationJSON.isEmpty)
        workspace.selectedBackend = .externalHighPerformance
        #expect(workspace.externalBackendSummary.contains("no external solver integration"))
        try await #require(workspace.startCurrentModelRun()).value
        #expect(workspace.runState == .failed && workspace.lastErrorMessage?.contains("QSB Native") == true)
        workspace.selectedBackend = .nativeEducational
        let gate = DispatchSemaphore(value: 0)
        let task = try #require(gatedRun(workspace, family: family, gate: gate, fail: true))
        gate.signal()
        await task.value
        #expect(workspace.runState == .failed && workspace.lastErrorMessage?.contains("Worker failure") == true)
        try rename(workspace, family: family, title: "")
        #expect(workspace.startCurrentModelRun() == nil)
        #expect(workspace.modelState == .invalid && workspace.selectedPane == .validation)
    }
    for family in [AsyncFamily.knapsack, .line] {
        let workspace = asyncWorkspace(family)
        if family == .knapsack {
            var draft = try #require(workspace.knapsackDraft)
            draft.capacity = "-1"
            workspace.replaceKnapsackDraft(draft)
        } else {
            var draft = try #require(workspace.lineBalancingDraft)
            draft.cycleTime = "-1"
            workspace.replaceLineBalancingDraft(draft)
        }
        try await #require(workspace.startCurrentModelRun()).value
        #expect(workspace.modelState == .invalid && workspace.selectedPane == .validation)
        #expect(workspace.runState == .notRun && workspace.solutionJSON.isEmpty)
    }
}

@MainActor
@Test("Superseded facilities and knapsack results and errors cannot replace current state")
func facilitiesKnapsackSuperseded() async throws {
    for family in AsyncFamily.allCases {
        for fail in [false, true] {
            let workspace = asyncWorkspace(family)
            let gate = DispatchSemaphore(value: 0)
            let old = try #require(gatedRun(workspace, family: family, gate: gate, fail: fail))
            defer { gate.signal() }
            try rename(workspace, family: family, title: "Current model")
            try await #require(workspace.startCurrentModelRun()).value
            let result = workspace.solutionJSON
            let status = workspace.status
            #expect(workspace.runState == .solved)
            gate.signal()
            await old.value
            #expect(workspace.solutionJSON == result && workspace.status == status)
            #expect(workspace.lastErrorMessage == nil)
        }
    }
}
