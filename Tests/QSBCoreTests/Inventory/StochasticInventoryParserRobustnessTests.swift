import Foundation
import Testing
@testable import QSBCore

@Suite struct StochasticInventoryParserRobustnessTests {
    @Test func acceptsUnusedPlaceholdersAndMixedCaseLabels() throws {
        let model = try WinQSBInventoryParser.parseStochasticInventory(from: payload())
        #expect(model.meanDemand == 100)
        #expect(model.backorderFraction == 1)
        #expect(model.policy == .continuousFixedOrderQuantity)
        let solution = try StochasticInventorySolver.solve(model)
        #expect(solution.orderQuantity.isFinite)
        #expect(solution.orderQuantity > 0)
    }

    @Test(arguments: ["Mean (u)", " mean (u) ", "MEAN (U)"])
    func rejectsDuplicateLabels(label: String) throws {
        do {
            _ = try WinQSBInventoryParser.parseStochasticInventory(from: payload(extraRow: "\(label)\t100"))
            Issue.record("Duplicate inventory row was accepted")
        } catch InventoryModelError.invalidModel(let detail) {
            #expect(detail == "Duplicate row 'mean (u)'")
        }
    }

    private func payload(extraRow: String? = nil) -> Data {
        var rows = [
            "ITS\tSynthetic inventory\tYear\t4\t0",
            "Parameter\tValue",
            "Demand distribution (in year)\tNormal",
            " MEAN (U) \t100",
            "Standard deviation (s>0)\t10",
            "Order or setup cost\t5",
            "Unit acquisition cost\t2",
            "Unit holding cost per year\t1",
            "Estimated % of shortage will be backordered\t100",
            "Unit backorder cost\t10",
            "Lead time distribution (in year)\tConstant",
            "Constant value\t0.1",
            "(Not used)\t0",
            "(Not used)\t0"
        ]
        if let extraRow { rows.append(extraRow) }
        return Data(rows.joined(separator: "\n").utf8)
    }
}
