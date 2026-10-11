import Testing
import QSBCore
@testable import QSBMacApp

@Test("acceptance-sampling sample produces a typed OC curve for the native result view")
func acceptanceSamplingSampleProducesTypedPresentation() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.acceptanceSampling)

    guard case .acceptanceSampling(.single) = workspace.currentModelFamily else {
        Issue.record("Expected single Acceptance Sampling family detection")
        return
    }

    workspace.runCurrentModel()

    let document = try #require(workspace.acceptanceSamplingSolution)
    #expect(document.model.title == "Incoming Lot Inspection")
    #expect(document.solution.operatingCharacteristic.count == 101)
    #expect(document.solution.operatingCharacteristic.first?.acceptanceProbability == 1)
    #expect(document.solution.operatingCharacteristic.last?.acceptanceProbability == 0)
    #expect(document.solution.producerRiskAtAQL > 0)
    #expect(document.solution.consumerRiskAtRQL > 0)
    #expect(document.backend.exactness == .exact)
    #expect(workspace.runState == .solved)
}
