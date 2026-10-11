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
    if let external = AggregatePlanningBackends.backend(for: .externalHighPerformance) {
        #expect(external.capabilities.solves)
        #expect(external.capabilities.backendKind == .externalHighPerformance)
    }

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

@Test func routesAggregatePlanningThroughExternalBackendSeam() throws {
    let model = try WinQSBAggregatePlanningParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("APLP.AP_"))))
    let native = try NativeEducationalAggregatePlanningBackend().solve(model)
    let external = HiGHSAggregatePlanningBackend(linearProgrammingBackend: NativeEducationalLinearProgrammingBackend())
    let solution = try external.solve(model)

    #expect(abs(solution.totalCost - native.totalCost) < 1e-7)
    #expect(solution.periods == native.periods)
    #expect(external.runMetadata(for: model).algorithm == "hiGHSAggregatePlanningLP")
}

@Test func solvesAggregatePlanningWithInstalledHiGHSWhenAvailable() throws {
    guard let backend = HiGHSAggregatePlanningBackend.discovered() else { return }
    let model = try WinQSBAggregatePlanningParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("APLP.AP_"))))
    let solution = try backend.solve(model)
    #expect(abs(solution.totalCost - 165_355.95238095237) < 1e-6)
}

@Test func solvesTwelvePeriodPlanningWithInstalledHiGHSWhenAvailable() throws {
    guard let backend = HiGHSAggregatePlanningBackend.discovered() else { return }
    let count = 12
    let zeros = Array(repeating: 0.0, count: count)
    let noCapacity = Array<Double?>(repeating: 0, count: count)
    let model = AggregatePlanningModel(
        title: "Twelve-period plan", method: .linearProgramming,
        periodNames: (1...count).map { "Month \($0)" },
        workforceUnit: "worker", capacityUnit: "unit",
        demand: Array(repeating: 10, count: count),
        initialWorkforce: nil, initialInventory: 0,
        regularCapacity: Array(repeating: 10, count: count),
        regularCost: Array(repeating: 2, count: count),
        undertimeCost: zeros, overtimeCapacity: zeros,
        overtimeCost: Array(repeating: 3, count: count),
        hiringCost: zeros, dismissalCost: zeros,
        maximumWorkforce: Array(repeating: nil, count: count),
        minimumWorkforce: zeros,
        maximumInventory: noCapacity, minimumInventory: zeros,
        inventoryHoldingCost: Array(repeating: 1, count: count),
        maximumSubcontracting: noCapacity,
        subcontractingCost: Array(repeating: 4, count: count),
        maximumBackorder: noCapacity,
        backorderCost: Array(repeating: 5, count: count),
        otherUnitProductionCost: zeros,
        capacityRequirementPerUnit: Array(repeating: 1, count: count),
        capacityIsPerWorker: false
    )

    let solution = try backend.solve(model)
    #expect(abs(solution.totalCost - 240) < 1e-7)
    #expect(solution.periods.count == count)
    #expect(solution.periods.allSatisfy {
        abs($0.regularProduction - 10) < 1e-7
            && abs($0.overtimeProduction) < 1e-7
            && abs($0.subcontracted) < 1e-7
            && abs($0.endingInventory) < 1e-7
            && abs($0.endingBackorder) < 1e-7
    })
}
