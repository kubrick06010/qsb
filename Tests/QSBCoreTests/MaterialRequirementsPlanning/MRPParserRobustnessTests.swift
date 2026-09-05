import Foundation
import Testing
@testable import QSBCore

@Suite struct MRPParserRobustnessTests {
    @Test func parsesAndSolvesIndependentMinimalModel() throws {
        let model = try WinQSBMaterialRequirementsPlanningParser.parse(from: payload())
        #expect(model.masterProductionSchedule == ["A": [0, 3]])
        #expect(model.items[0].capacity == [nil, nil])
        #expect(try MaterialRequirementsPlanningJSON.decodeModel(
            from: MaterialRequirementsPlanningJSON.encodeModel(model)
        ) == model)
        let solution = try MaterialRequirementsPlanningSolver.solve(model)
        #expect(solution.schedules[0].plannedOrderReceipts == [0, 3])
    }

    @Test(arguments: ["MPS", "Inventory", "Capacity"])
    func rejectsDuplicateRows(section: String) throws {
        try expectInvalid(payload(duplicateSection: section), containing: "Duplicate item 'A' in \(section)")
    }

    @Test(arguments: ["MPS", "Inventory", "Capacity"])
    func rejectsMissingRowIdentifiers(section: String) throws {
        try expectInvalid(payload(emptyIdentifierSection: section), containing: "Missing item identifier in \(section)")
    }

    @Test(arguments: ["/", "/2", "A/", "A/0", "A/-1", "A/nan", "A/2/3"])
    func rejectsMalformedComponents(component: String) throws {
        try expectInvalid(payload(component: component), containing: "Invalid BOM component")
    }

    private func expectInvalid(_ data: Data, containing message: String) throws {
        do {
            _ = try WinQSBMaterialRequirementsPlanningParser.parse(from: data)
            Issue.record("Malformed MRP input was accepted")
        } catch MaterialRequirementsPlanningError.invalidModel(let detail) {
            #expect(detail.contains(message))
        }
    }

    private func payload(
        duplicateSection: String? = nil,
        emptyIdentifierSection: String? = nil,
        component: String? = nil
    ) -> Data {
        var rows = [
            "MRP\tSynthetic\t1\tWeek\t1\t52\t0",
            "**Item Master",
            "A\t0\tP\tFinished\tEach\t0\tLFL\t\t1\t10\t1\t2\t1\t\tSynthetic item",
            "**BOM"
        ]
        if let component { rows.append("A\t\(component)") }
        for (section, values) in [("MPS", "0\t3"), ("Inventory", "0\t0\t0\t0"), ("Capacity", "m")] {
            rows.append("**\(section)")
            let identifier = emptyIdentifierSection == section ? "" : "A"
            let row = "\(identifier)\t\(values)"
            rows.append(row)
            if duplicateSection == section { rows.append(row) }
        }
        return Data(rows.joined(separator: "\n").utf8)
    }
}
