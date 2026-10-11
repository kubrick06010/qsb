import Testing
import QSBCore
@testable import QSBMacApp

@Test("simulation sample produces typed queue and server metrics")
func simulationSampleProducesTypedPresentation() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.simulation)
    workspace.runCurrentModel()

    let document = try #require(workspace.simulationSolution)
    #expect(document.model.title == "Service Desk Simulation")
    #expect(document.solution.generatedEntities > 0)
    #expect(document.solution.completedEntities > 0)
    #expect(document.solution.queueMetrics.map(\.name) == ["Queue"])
    #expect(document.solution.serverMetrics.map(\.name) == ["Clerk"])
    #expect(document.solution.queueMetrics[0].entered >= document.solution.completedEntities)
    #expect(document.solution.serverMetrics[0].utilization > 0)
    #expect(document.solution.replications == 1)
    #expect(document.backend.exactness == .approximate)
    #expect(workspace.runState == .solved)
}

@Test("simulation run configuration forwards replications to the backend")
func simulationRunConfigurationForwardsReplications() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.simulation)
    workspace.simulationReplications = 3
    workspace.runCurrentModel()

    let document = try #require(workspace.simulationSolution)
    #expect(document.solution.replications == 3)
    #expect(document.solution.queueLengthConfidenceIntervals["Queue"] != nil)
    #expect(document.solution.serverUtilizationConfidenceIntervals["Clerk"] != nil)
    #expect(workspace.status.contains("3 replications"))
}
