import Foundation
import Testing
@testable import QSBCore

func legacyFixtureURL(_ filename: String) -> URL {
    legacyReferenceURL().appendingPathComponent(filename)
}

func legacyReferenceURL() -> URL {
    URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("reference")
        .appendingPathComponent("winqsb")
}

func legacySimulation(_ filename: String) throws -> SimulationModel {
    try WinQSBSimulationParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL(filename))))
}

func expectAggregatePlanningBalances(model: AggregatePlanningModel, solution: AggregatePlanningSolution) throws {
    var priorNetInventory = model.initialInventory
    for index in model.periodNames.indices {
        let period = solution.periods[index]
        let available = priorNetInventory + period.regularProduction + period.overtimeProduction + period.subcontracted
        let endingNetInventory = period.endingInventory - period.endingBackorder
        #expect(abs(available - model.demand[index] - endingNetInventory) < 1e-7)
        priorNetInventory = endingNetInventory
    }
}
