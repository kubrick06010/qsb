import Testing
import QSBCore
@testable import QSBMacApp

@Test("quality-control sample produces a typed control chart for the native result view")
func qualityControlSampleProducesTypedPresentation() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.qualityControl)

    guard case .qualityControl(.cChart) = workspace.currentModelFamily else {
        Issue.record("Expected c-chart Quality Control family detection")
        return
    }

    workspace.runCurrentModel()

    let document = try #require(workspace.qualityControlSolution)
    #expect(document.model.title == "Weekly Defect Count")
    guard case .cChart(let chart) = document.solution else {
        Issue.record("Expected a c-chart solution")
        return
    }
    #expect(chart.points.count == 10)
    #expect(chart.outsideLimitIndexes == [7])
    #expect(chart.points[6].isOutsideLimits)
    #expect(document.backend.exactness == .exact)
    #expect(workspace.runState == .solved)
}
