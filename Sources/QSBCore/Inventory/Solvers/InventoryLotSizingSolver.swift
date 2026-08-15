import Foundation
public enum LotSizingSolver {
    private struct SearchNode {
        let cost: Double
        let previousInventory: Int
        let productionQuantity: Int
        let decision: LotSizingDecision
    }

    public static func solve(_ model: LotSizingModel) throws -> LotSizingSolution {
        try LotSizingValidator.validate(model)

        let totalDemand = model.periods.reduce(0) { $0 + $1.demand }
        guard totalDemand > 0 else {
            return LotSizingSolution(
                totalCost: 0,
                decisions: model.periods.map {
                    LotSizingDecision(
                        period: $0.name,
                        demand: $0.demand,
                        productionQuantity: 0,
                        endingInventory: 0,
                        setupCost: 0,
                        variableCost: 0,
                        holdingCost: 0,
                        backorderCost: 0,
                        totalCost: 0
                    )
                }
            )
        }

        var costsByInventory = [0: 0.0]
        var layers: [[Int: SearchNode]] = []

        for period in model.periods {
            var nextLayer: [Int: SearchNode] = [:]
            for beginningInventory in costsByInventory.keys.sorted() {
                guard let baseCost = costsByInventory[beginningInventory] else { continue }
                for productionQuantity in 0...totalDemand {
                    let endingInventory = beginningInventory + productionQuantity - period.demand
                    guard endingInventory >= -totalDemand, endingInventory <= totalDemand else {
                        continue
                    }

                    let setupCost = productionQuantity > 0 ? period.setupCost : 0
                    let variableCost = Double(productionQuantity) * period.unitVariableCost
                    let holdingCost = endingInventory > 0 ? Double(endingInventory) * period.unitHoldingCost : 0
                    let backorderCost = endingInventory < 0 ? Double(-endingInventory) * period.unitBackorderCost : 0
                    let periodCost = setupCost + variableCost + holdingCost + backorderCost
                    let candidateCost = baseCost + periodCost

                    if let currentBest = nextLayer[endingInventory],
                       currentBest.cost <= candidateCost + 1e-9 {
                        continue
                    }

                    nextLayer[endingInventory] = SearchNode(
                        cost: candidateCost,
                        previousInventory: beginningInventory,
                        productionQuantity: productionQuantity,
                        decision: LotSizingDecision(
                            period: period.name,
                            demand: period.demand,
                            productionQuantity: productionQuantity,
                            endingInventory: endingInventory,
                            setupCost: setupCost,
                            variableCost: variableCost,
                            holdingCost: holdingCost,
                            backorderCost: backorderCost,
                            totalCost: periodCost
                        )
                    )
                }
            }
            layers.append(nextLayer)
            costsByInventory = nextLayer.mapValues(\.cost)
        }

        guard let finalNode = layers.last?[0] else {
            throw InventoryModelError.invalidModel("lot sizing problem has no balanced final plan")
        }

        var endingInventory = 0
        var decisions: [LotSizingDecision] = []
        for layerIndex in layers.indices.reversed() {
            guard let node = layers[layerIndex][endingInventory] else {
                throw InventoryModelError.invalidModel("lot sizing solution path could not be reconstructed")
            }
            decisions.append(node.decision)
            endingInventory = node.previousInventory
        }

        return LotSizingSolution(
            totalCost: finalNode.cost,
            decisions: decisions.reversed()
        )
    }

}

