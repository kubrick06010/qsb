import Testing
import QSBCore
@testable import QSBMacApp

struct InventoryDraftTests {
    @Test("EOQ draft converts and preserves optional inputs")
    func eoqRoundTrip() throws {
        let model = EOQModel(title: "EOQ", timeUnit: "year", demand: 1200, setupCost: 80, holdingCost: 4, shortageCost: 2, replenishmentRate: 5000, leadTime: 0.25, acquisitionCost: 3, knownOrderQuantity: 100)
        let envelope = try InventoryDraft(.eoq(model)).makeModel()
        #expect(envelope == .eoq(model))
    }

    @Test("quantity discount draft keeps tier dimensions safe")
    func quantityDiscountMutations() throws {
        var draft = InventoryDraft.blank(.quantityDiscountEOQ)
        draft.addDiscountBreak()
        draft.addDiscountBreak()
        draft.removeDiscountBreak(at: 1)
        guard case .quantityDiscount(let value) = draft else { Issue.record("Expected quantity discount draft"); return }
        #expect(value.discountBreaks.count == 2)
        let model = try draft.makeModel()
        guard case .quantityDiscountEOQ(let typed) = model else { Issue.record("Expected quantity discount model"); return }
        #expect(typed.discountBreaks.count == 2)
    }

    @Test("newsboy draft round trips through typed model")
    func newsboyRoundTrip() throws {
        let model = NewsboyModel(title: "Newsboy", timeUnit: "day", demandDistribution: "Normal", meanDemand: 100, standardDeviation: 12, setupCost: 0, acquisitionCost: 4, sellingPrice: 9, shortageCost: 2, salvageValue: 1, initialInventory: 5, knownOrderQuantity: 100, desiredServiceLevelPercent: 95)
        #expect(try InventoryDraft(.newsboy(model)).makeModel() == .newsboy(model))
    }

    @Test("lot sizing period mutations preserve vector shape")
    func lotSizingMutations() throws {
        var draft = InventoryDraft.blank(.lotSizing)
        draft.addLotSizingPeriod()
        draft.addLotSizingPeriod()
        draft.removeLotSizingPeriod(at: 1)
        guard case .lotSizing(let value) = draft else { Issue.record("Expected lot sizing draft"); return }
        #expect(value.periods.count == 2)
        let model = try draft.makeModel()
        guard case .lotSizing(let typed) = model else { Issue.record("Expected lot sizing model"); return }
        #expect(typed.periods.count == value.periods.count)
    }

    @Test("incomplete draft diagnostics are separate from core validation")
    func draftDiagnostics() {
        var draft = InventoryDraft.blank(.eoq)
        guard case .eoq(var value) = draft else { Issue.record("Expected EOQ draft"); return }
        value.demand = "not a number"
        draft = .eoq(value)
        let diagnostics = draft.draftDiagnostics()
        #expect(diagnostics.count == 1)
        #expect(diagnostics[0].code.hasPrefix("inventory.draft."))
        #expect(diagnostics[0].path == "demand")
    }

    @Test("stochastic review remains representable without a native editor")
    func stochasticRoundTrip() throws {
        let model = StochasticInventoryModel(title: "Stochastic", timeUnit: "year", policy: .periodicFixedOrderInterval, demandDistribution: "Normal", meanDemand: 100, demandStandardDeviation: 10, setupCost: 50, acquisitionCost: 2, holdingCost: 1, backorderFraction: 1, backorderCost: 3, lostSalesFraction: 0, lostSalesCost: nil, fixedShortageCost: nil, leadTimeDistribution: "Constant", leadTime: 1, averageOrderSize: nil, reviewCost: 10)
        #expect(try InventoryDraft(.stochasticReview(model)).makeModel() == .stochasticReview(model))
    }

    @Test("draft JSON round trip preserves a lot-sizing envelope")
    func jsonRoundTrip() throws {
        let model = LotSizingModel(title: "Plan", timeUnit: "month", periods: [
            LotSizingPeriod(name: "P1", demand: 10, setupCost: 20, unitVariableCost: 2, unitHoldingCost: 1, unitBackorderCost: 3),
            LotSizingPeriod(name: "P2", demand: 12, setupCost: 20, unitVariableCost: 2, unitHoldingCost: 1, unitBackorderCost: 3)
        ])
        let envelope = InventoryModelEnvelope.lotSizing(model)
        let decoded = try InventoryModelJSON.decodeUncheckedModel(from: InventoryModelJSON.encodeModel(envelope))
        #expect(decoded == envelope)
        #expect(try InventoryDraft(decoded).makeModel() == envelope)
    }

    @Test("native EOQ draft uses the existing Inventory backend")
    func runIntegration() throws {
        let draft = InventoryDraft.blank(.eoq)
        let envelope = try draft.makeModel()
        guard case .eoq(let model) = envelope else { Issue.record("Expected EOQ model"); return }
        let solution = try NativeEducationalInventoryBackend().solve(model)
        #expect(solution.economicOrderQuantity > 0)
    }
}
