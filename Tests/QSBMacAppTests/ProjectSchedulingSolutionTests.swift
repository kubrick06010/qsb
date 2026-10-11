import Testing
import QSBCore
@testable import QSBMacApp

@Test("CPM sample produces typed critical-path timings for the native result view")
func projectSchedulingSampleProducesTypedPresentation() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.projectScheduling)

    guard case .projectScheduling(.deterministicCPM) = workspace.currentModelFamily else {
        Issue.record("Expected CPM family detection")
        return
    }

    workspace.runCurrentModel()

    let document = try #require(workspace.projectSchedulingSolution)
    #expect(document.model.title == "Product Launch CPM")
    #expect(document.solution.projectDuration == 11)
    #expect(document.solution.criticalActivities == ["A", "C", "D"])
    #expect(document.solution.activityTimings.first { $0.name == "B" }?.slack == 6)
    #expect(document.solution.totalNormalCost == 360)
    #expect(document.backend.exactness == .exact)
    #expect(workspace.runState == .solved)
}
