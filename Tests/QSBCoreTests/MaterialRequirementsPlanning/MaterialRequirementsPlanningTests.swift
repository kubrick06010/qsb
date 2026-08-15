import Foundation
import Testing
@testable import QSBCore

@Test func parsesWinQSBMaterialRequirementsPlanningFixture() throws {
    let model = try legacyMRPModel()
    #expect(model.title == "MRP Example Problem")
    #expect(model.bucketNames == ["Overdue"] + (1...12).map { "Week \($0)" })
    #expect(model.items.count == 7)
    #expect(Set(model.items.map(\.lotSizingRule)) == [.lotForLot, .economicOrderQuantity, .leastUnitCost, .leastTotalCost, .partPeriodBalancing])

    let a100 = try #require(model.items.first { $0.identifier == "A100" })
    #expect(a100.safetyStock == 50)
    #expect(a100.initialOnHand == 75)
    #expect(a100.scheduledReceipts == [0, 0, 50, 0, 70, 0, 0, 0, 0, 0, 0, 0, 0])
    #expect(a100.capacity == [nil, 120, 120, 120, 120, 120, 150, 150, 150, 150, 100, 100, 100])

    let aBill = try #require(model.billsOfMaterial.first { $0.parentIdentifier == "A100" })
    #expect(aBill.components == [MRPComponent(itemIdentifier: "C200", quantityPerParent: 1), MRPComponent(itemIdentifier: "D200", quantityPerParent: 1), MRPComponent(itemIdentifier: "F300", quantityPerParent: 3)])
}

@Test func explodesWinQSBMaterialRequirementsAcrossAllLevels() throws {
    let model = try legacyMRPModel()
    let solution = try NativeEducationalMaterialRequirementsPlanningBackend().solve(model)
    #expect(solution.schedules.count == 7)
    let schedules = Dictionary(uniqueKeysWithValues: solution.schedules.map { ($0.itemIdentifier, $0) })
    let a = try #require(schedules["A100"]), b = try #require(schedules["B100"])
    let c = try #require(schedules["C200"]), d = try #require(schedules["D200"])
    let e = try #require(schedules["E200"]), f = try #require(schedules["F300"]), g = try #require(schedules["G300"])

    #expect(a.grossRequirements.reduce(0, +) == 1_030)
    #expect(a.plannedOrderReceipts.reduce(0, +) == 885)
    #expect(a.plannedOrderReleases == [0, 0, 0, 0, 0, 0, 275, 0, 300, 0, 240, 70, 0])
    #expect(b.plannedOrderReleases.reduce(0, +) == 615)
    #expect(c.grossRequirements.reduce(0, +) == 2_205)
    #expect(d.grossRequirements.reduce(0, +) == 1_570)
    #expect(e.grossRequirements.reduce(0, +) == 660)
    #expect(f.grossRequirements.reduce(0, +) == 5_844)
    #expect(g.grossRequirements.reduce(0, +) == 4_978)
    #expect(c.plannedOrderReceipts.reduce(0, +) == 1_885)
    #expect(f.plannedOrderReceipts.reduce(0, +) == 5_995)
    #expect(g.plannedOrderReceipts.reduce(0, +) == 5_527)
    #expect(a.capacityExcess.reduce(0, +) == 415)
    #expect(solution.schedules.allSatisfy { schedule in schedule.projectedOnHand.allSatisfy { $0 >= -1e-9 } })
}

@Test func roundTripsAndValidatesMaterialRequirementsPlanningBackends() throws {
    let model = try legacyMRPModel()
    #expect(try MaterialRequirementsPlanningJSON.decodeModel(from: MaterialRequirementsPlanningJSON.encodeModel(model)) == model)
    let native = NativeEducationalMaterialRequirementsPlanningBackend()
    let solution = try native.solve(model)
    let document = native.solutionDocument(for: model, solution: solution)
    #expect(try MaterialRequirementsPlanningJSON.decodeSolution(from: MaterialRequirementsPlanningJSON.encodeSolution(document)) == document)
    #expect(native.runMetadata(for: model).exactness == .heuristic)
    #expect(ValidateOnlyMaterialRequirementsPlanningBackend().validationReport(for: model).isValid)
    #expect(MaterialRequirementsPlanningBackends.backend(for: .externalHighPerformance) == nil)

    let cycle = MaterialRequirementsPlanningModel(title: model.title, timeUnit: model.timeUnit, periodsPerYear: model.periodsPerYear, bucketNames: model.bucketNames, items: model.items, billsOfMaterial: model.billsOfMaterial + [MRPBillOfMaterial(parentIdentifier: "G300", components: [MRPComponent(itemIdentifier: "A100", quantityPerParent: 1)])], masterProductionSchedule: model.masterProductionSchedule)
    let report = ValidateOnlyMaterialRequirementsPlanningBackend().validationReport(for: cycle)
    #expect(!report.isValid)
    #expect(report.diagnostics.contains { $0.code == "mrp.bomCycle" })
    let duplicateParent = MaterialRequirementsPlanningModel(title: model.title, timeUnit: model.timeUnit, periodsPerYear: model.periodsPerYear, bucketNames: model.bucketNames, items: model.items, billsOfMaterial: model.billsOfMaterial + [model.billsOfMaterial[0]], masterProductionSchedule: model.masterProductionSchedule)
    #expect(ValidateOnlyMaterialRequirementsPlanningBackend().validationReport(for: duplicateParent).diagnostics.contains { $0.code == "mrp.bomParent" })
    do {
        _ = try ValidateOnlyMaterialRequirementsPlanningBackend().solve(model)
        Issue.record("validateOnly unexpectedly exploded an MRP model")
    } catch {
        #expect(String(describing: error).contains("validateOnly"))
    }
}

private func legacyMRPModel() throws -> MaterialRequirementsPlanningModel {
    try WinQSBMaterialRequirementsPlanningParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("QSB.MR_"))))
}

