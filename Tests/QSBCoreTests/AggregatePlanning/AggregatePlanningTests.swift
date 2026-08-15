import Foundation
import Testing
@testable import QSBCore

@Test func parsesAndSolvesWinQSBAggregatePlanningWorkforceFixtures() throws {
    let lpModel = try WinQSBAggregatePlanningParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("APLP.AP_"))))
    let simpleModel = try WinQSBAggregatePlanningParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("APSIMPLE.AP_"))))
    let backend = NativeEducationalAggregatePlanningBackend()
    let lpSolution = try backend.solve(lpModel)
    let simpleSolution = try backend.solve(simpleModel)

    #expect(lpModel.method == .linearProgramming)
    #expect(simpleModel.method == .simple)
    #expect(lpModel.demand == simpleModel.demand)
    #expect(lpModel.capacityRequirementPerUnit == Array(repeating: 5, count: 6))
    #expect(simpleModel.capacityRequirementPerUnit == Array(repeating: 5, count: 6))
    #expect(abs(lpSolution.totalCost - 165_355.95238095237) < 1e-7)
    #expect(abs(simpleSolution.totalCost - lpSolution.totalCost) < 1e-7)
    #expect(abs((lpSolution.periods[2].workforce ?? -1) - 29.761904761904763) < 1e-9)
    #expect(abs(lpSolution.periods[5].subcontracted - 725) < 1e-9)
    #expect(lpSolution.periods.allSatisfy { abs($0.endingBackorder) < 1e-9 })
    try expectAggregatePlanningBalances(model: lpModel, solution: lpSolution)
}

@Test func roundTripsAndValidatesAggregatePlanningBackends() throws {
    let model = try WinQSBAggregatePlanningParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("APTRP.AP_"))))
    #expect(try AggregatePlanningJSON.decodeModel(from: AggregatePlanningJSON.encodeModel(model)) == model)
    let native = NativeEducationalAggregatePlanningBackend()
    let solution = try native.solve(model)
    let document = native.solutionDocument(for: model, solution: solution)
    #expect(try AggregatePlanningJSON.decodeSolution(from: AggregatePlanningJSON.encodeSolution(document)) == document)
    #expect(ValidateOnlyAggregatePlanningBackend().validationReport(for: model).isValid)
    #expect(AggregatePlanningBackends.backend(for: .externalHighPerformance) == nil)

    let invalid = AggregatePlanningModel(
        title: model.title, method: model.method, periodNames: model.periodNames,
        workforceUnit: model.workforceUnit, capacityUnit: model.capacityUnit,
        demand: model.demand, initialWorkforce: model.initialWorkforce, initialInventory: model.initialInventory,
        regularCapacity: model.regularCapacity, regularCost: model.regularCost,
        undertimeCost: model.undertimeCost, overtimeCapacity: model.overtimeCapacity,
        overtimeCost: model.overtimeCost, hiringCost: model.hiringCost,
        dismissalCost: model.dismissalCost, maximumWorkforce: model.maximumWorkforce,
        minimumWorkforce: model.minimumWorkforce, maximumInventory: model.maximumInventory,
        minimumInventory: model.minimumInventory, inventoryHoldingCost: model.inventoryHoldingCost,
        maximumSubcontracting: model.maximumSubcontracting, subcontractingCost: model.subcontractingCost,
        maximumBackorder: model.maximumBackorder, backorderCost: model.backorderCost,
        otherUnitProductionCost: model.otherUnitProductionCost,
        capacityRequirementPerUnit: [0, 1, 1, 1], capacityIsPerWorker: model.capacityIsPerWorker
    )
    let report = ValidateOnlyAggregatePlanningBackend().validationReport(for: invalid)
    #expect(!report.isValid)
    #expect(report.diagnostics.contains { $0.code == "aggregatePlanning.capacityRequirement" })
    do {
        _ = try ValidateOnlyAggregatePlanningBackend().solve(model)
        Issue.record("validateOnly unexpectedly solved an aggregate-planning model")
    } catch {
        #expect(String(describing: error).contains("validateOnly"))
    }
}
