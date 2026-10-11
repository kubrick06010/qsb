import Testing
import QSBCore
@testable import QSBMacApp

@Test("new queue drafts use the shared backend and do not leak into another sample")
func newQueueDraftUsesExistingWorkflow() throws {
    let workspace = QSBWorkspace()
    workspace.startNewQueuing(.mm1)

    #expect(workspace.hasModel)
    #expect(workspace.modelTitle == "New M/M/1 Queue")
    guard case .queuing(.mm1) = workspace.currentModelFamily else {
        Issue.record("Expected a new queue draft to identify as Queuing")
        return
    }

    workspace.validateCurrentModel()
    #expect(workspace.modelState == .valid)
    workspace.runCurrentModel()
    #expect(workspace.runState == .solved)
    #expect(try #require(workspace.queuingSolution).kind == .mm1)
    #expect(workspace.modelJSON.contains("serviceRate"))

    workspace.loadSample(.linearProgram)
    #expect(workspace.queuingDraft == nil)
    guard case .linearProgramming = workspace.currentModelFamily else {
        Issue.record("Expected loading the LP sample to replace the queue family")
        return
    }
}

@Test("finite queue draft preserves imported numeric values and reports out-of-range integers")
func finiteQueueDraftRoundTripsWithoutNumericLoss() throws {
    let model = FiniteCapacityQueueModel(
        title: "Precise queue", timeUnit: "hour", servers: 2,
        serviceDistribution: "Exponential", meanServiceTime: 0.12345678901234567,
        interarrivalDistribution: "Exponential", meanInterarrivalTime: 0.3333333333333333,
        batchSize: 1, queueCapacity: 3, customerWaitingCostPerTime: 1.2345678901234567
    )
    var draft = QueuingDraft(.finiteCapacity(model))
    #expect(try draft.makeModel() == .finiteCapacity(model))

    draft.updateFiniteCapacity { $0.servers = "1e100" }
    #expect(draft.draftDiagnostics().contains { $0.code == "queuing.draft.servers" })
}
