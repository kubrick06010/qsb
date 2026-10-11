import Testing
import QSBCore
@testable import QSBMacApp

@Test("MRP sample produces typed item schedules for the native result view")
func materialRequirementsPlanningSampleProducesTypedPresentation() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.materialRequirementsPlanning)

    guard case .materialRequirementsPlanning = workspace.currentModelFamily else {
        Issue.record("Expected Material Requirements Planning family detection")
        return
    }

    workspace.runCurrentModel()

    let document = try #require(workspace.materialRequirementsPlanningSolution)
    #expect(document.model.title == "Four-Week Assembly Plan")
    #expect(document.solution.bucketNames == ["Overdue", "Week 1", "Week 2", "Week 3", "Week 4"])
    #expect(document.solution.schedules.map(\.itemIdentifier) == ["FINAL", "COMP"])
    let final = try #require(document.solution.schedules.first { $0.itemIdentifier == "FINAL" })
    let component = try #require(document.solution.schedules.first { $0.itemIdentifier == "COMP" })
    #expect(final.plannedOrderReleases == [20, 0, 30, 10, 0])
    #expect(component.grossRequirements == [40, 0, 60, 20, 0])
    #expect(component.projectedOnHand == [10, 10, 10, 10, 10])
    #expect(document.backend.exactness == .heuristic)
    #expect(workspace.runState == .solved)
}
