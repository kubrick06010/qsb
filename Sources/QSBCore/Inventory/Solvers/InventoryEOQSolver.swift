import Foundation
public enum EOQSolver {
    public static func solve(_ model: EOQModel) throws -> EOQSolution {
        try EOQValidator.validate(model)

        let eoq: Double
        if let replenishmentRate = model.replenishmentRate {
            eoq = sqrt((2 * model.demand * model.setupCost) / (model.holdingCost * (1 - model.demand / replenishmentRate)))
        } else {
            eoq = sqrt((2 * model.demand * model.setupCost) / model.holdingCost)
        }

        let optimum = costBreakdown(for: eoq, model: model)
        let knownQuantity = model.knownOrderQuantity.map {
            costBreakdown(for: $0, model: model)
        }
        let reorderPoint = model.leadTime.map { model.demand * $0 }

        return EOQSolution(
            economicOrderQuantity: eoq,
            cycleCount: model.demand / eoq,
            cycleLength: eoq / model.demand,
            reorderPoint: reorderPoint,
            optimum: optimum,
            knownQuantity: knownQuantity
        )
    }

    private static func costBreakdown(for orderQuantity: Double, model: EOQModel) -> EOQCostBreakdown {
        let setupCost = model.demand / orderQuantity * model.setupCost
        let holdingCost: Double
        if let replenishmentRate = model.replenishmentRate {
            holdingCost = orderQuantity / 2 * model.holdingCost * (1 - model.demand / replenishmentRate)
        } else {
            holdingCost = orderQuantity / 2 * model.holdingCost
        }
        let acquisitionCost = model.demand * (model.acquisitionCost ?? 0)
        let totalRelevantCost = setupCost + holdingCost
        return EOQCostBreakdown(
            orderQuantity: orderQuantity,
            setupCost: setupCost,
            holdingCost: holdingCost,
            acquisitionCost: acquisitionCost,
            totalRelevantCost: totalRelevantCost,
            totalCost: totalRelevantCost + acquisitionCost
        )
    }
}

