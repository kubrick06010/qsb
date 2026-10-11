import Testing
import QSBCore
@testable import QSBMacApp

@Test("facility-location sample produces a typed map presentation")
func facilityLocationSampleProducesTypedPresentation() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.facilityLocation)
    workspace.runCurrentModel()

    let presentation = try #require(workspace.facilityLocationPresentation)
    #expect(presentation.problem.title == "Two-Warehouse Location")
    #expect(presentation.solution.placements.count == 1)
    let placement = try #require(presentation.solution.placements.first)
    #expect(placement.x == 0)
    #expect(placement.y == 0)
    #expect(placement.weightedDistance == 10)
    #expect(presentation.document.backend.exactness == .closedForm)
    #expect(workspace.runState == .solved)
}

@Test("line-balancing sample produces typed station assignments")
func lineBalancingSampleProducesTypedPresentation() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.lineBalancing)
    workspace.runCurrentModel()

    let presentation = try #require(workspace.lineBalancingPresentation)
    #expect(presentation.problem.title == "Compact Assembly Line")
    #expect(presentation.solution.stationCount == 2)
    #expect(presentation.solution.stations.map(\.workload) == [7, 5])
    #expect(presentation.solution.stations[0].taskNames == ["Prepare", "Inspect"])
    #expect(abs(presentation.solution.efficiency - (12.0 / 14.0)) < 1e-10)
    #expect(presentation.document.backend.exactness == .fixtureScale)
    #expect(workspace.runState == .solved)
}

@Test("layout canvas bounds large grids while retaining exact coordinates")
func facilityLayoutCanvasLargeGridMetrics() {
    let small = FacilityLayoutCanvasMetrics(rows: 9, columns: 13, zoom: 1)
    #expect(small.cellSize == 50)
    #expect(small.columnGridLines == Array(0...13))
    for dimension in [1_000, 1_000_000_000, Int.max] {
        let large = FacilityLayoutCanvasMetrics(rows: dimension, columns: dimension, zoom: 1.6)
        #expect(large.width.isFinite && large.width <= 1_920.0001)
        #expect(large.height.isFinite && large.height <= 1_920.0001)
        #expect(large.columnGridLines.first == 0)
        #expect(large.columnGridLines.last == dimension)
        #expect(large.columnGridLines.count <= 122)
        #expect(large.rowGridLines.count <= 122)
        #expect(zip(large.columnGridLines, large.columnGridLines.dropFirst()).allSatisfy { $0 < $1 })
    }
}
