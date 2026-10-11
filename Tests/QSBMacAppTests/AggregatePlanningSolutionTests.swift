import Testing
import QSBCore
@testable import QSBMacApp

@Test("aggregate-planning sample produces a typed document for the native result view")
func aggregatePlanningSampleProducesTypedPresentation() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.aggregatePlanning)

    guard case .aggregatePlanning = workspace.currentModelFamily else {
        Issue.record("Expected Aggregate Planning family detection")
        return
    }

    workspace.runCurrentModel()

    let document = try #require(workspace.aggregatePlanningSolution)
    #expect(document.model.title == "Three-Period Production Plan")
    #expect(document.solution.periods.map(\.period) == ["Jan", "Feb", "Mar"])
    #expect(document.solution.periods.count == document.model.demand.count)
    #expect(document.solution.totalCost == 610)
    #expect(document.solution.periods.reduce(0) { $0 + $1.regularProduction } == 300)
    #expect(document.backend.backendKind == .nativeEducational)
    #expect(document.backend.exactness == .exact)
    #expect(workspace.runState == .solved)
}
