import Foundation
public enum QuantityDiscountEOQSolver {
    public static func solve(_ model: QuantityDiscountEOQModel) throws -> QuantityDiscountEOQSolution {
        try QuantityDiscountEOQValidator.validate(model)

        let unconstrainedEOQ = sqrt((2 * model.demand * model.setupCost) / model.holdingCost)
        let tiers = ([QuantityDiscountBreak(minimumQuantity: 0, discountPercent: 0)] + model.discountBreaks)
            .sorted { $0.minimumQuantity < $1.minimumQuantity }

        let candidates = tiers.map { tier in
            candidate(for: max(unconstrainedEOQ, tier.minimumQuantity), tier: tier, model: model)
        }
        guard let optimum = candidates.min(by: { $0.cost.totalCost < $1.cost.totalCost }) else {
            throw InventoryModelError.invalidModel("at least one discount candidate is required")
        }

        let knownQuantity = model.knownOrderQuantity.map { quantity in
            let tier = tiers.last(where: { quantity >= $0.minimumQuantity }) ?? tiers[0]
            return candidate(for: quantity, tier: tier, model: model)
        }

        return QuantityDiscountEOQSolution(
            unconstrainedEOQ: unconstrainedEOQ,
            candidates: candidates,
            optimum: optimum,
            knownQuantity: knownQuantity
        )
    }

    private static func candidate(
        for orderQuantity: Double,
        tier: QuantityDiscountBreak,
        model: QuantityDiscountEOQModel
    ) -> QuantityDiscountCandidate {
        let unitAcquisitionCost = model.acquisitionCost * (1 - tier.discountPercent / 100)
        let setupCost = model.demand / orderQuantity * model.setupCost
        let holdingCost = orderQuantity / 2 * model.holdingCost
        let acquisitionCost = model.demand * unitAcquisitionCost
        let totalRelevantCost = setupCost + holdingCost
        let cost = EOQCostBreakdown(
            orderQuantity: orderQuantity,
            setupCost: setupCost,
            holdingCost: holdingCost,
            acquisitionCost: acquisitionCost,
            totalRelevantCost: totalRelevantCost,
            totalCost: totalRelevantCost + acquisitionCost
        )

        return QuantityDiscountCandidate(
            minimumQuantity: tier.minimumQuantity,
            discountPercent: tier.discountPercent,
            unitAcquisitionCost: unitAcquisitionCost,
            cost: cost
        )
    }
}

