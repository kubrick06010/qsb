import Foundation
public enum NewsboySolver {
    public static func solve(_ model: NewsboyModel) throws -> NewsboySolution {
        try NewsboyValidator.validate(model)

        let underageCost = model.sellingPrice - model.acquisitionCost + model.shortageCost
        let overageCost = model.acquisitionCost - model.salvageValue
        let criticalRatio = underageCost / (underageCost + overageCost)
        let optimumPosition = model.meanDemand + model.standardDeviation * inverseStandardNormalCDF(criticalRatio)
        let initialInventory = model.initialInventory ?? 0
        let optimumQuantity = max(0, optimumPosition - initialInventory)
        let optimum = evaluation(orderQuantity: optimumQuantity, model: model)
        let knownQuantity = model.knownOrderQuantity.map {
            evaluation(orderQuantity: $0, model: model)
        }
        let desiredQuantity = model.desiredServiceLevelPercent.map { percent in
            max(0, model.meanDemand + model.standardDeviation * inverseStandardNormalCDF(percent / 100) - initialInventory)
        }

        return NewsboySolution(
            criticalRatio: criticalRatio,
            optimum: optimum,
            knownQuantity: knownQuantity,
            desiredServiceLevelQuantity: desiredQuantity
        )
    }

    private static func evaluation(orderQuantity: Double, model: NewsboyModel) -> NewsboyEvaluation {
        let inventoryPosition = orderQuantity + (model.initialInventory ?? 0)
        let z = (inventoryPosition - model.meanDemand) / model.standardDeviation
        let serviceLevel = standardNormalCDF(z)
        let expectedShortage = model.standardDeviation * (standardNormalPDF(z) - z * (1 - serviceLevel))
        let expectedLeftover = model.standardDeviation * (standardNormalPDF(z) + z * serviceLevel)
        let expectedSales = model.meanDemand - expectedShortage
        let expectedProfit = model.sellingPrice * expectedSales
            + model.salvageValue * expectedLeftover
            - model.acquisitionCost * orderQuantity
            - model.shortageCost * expectedShortage
            - model.setupCost

        return NewsboyEvaluation(
            orderQuantity: orderQuantity,
            inventoryPosition: inventoryPosition,
            serviceLevel: serviceLevel,
            expectedSales: expectedSales,
            expectedLeftover: expectedLeftover,
            expectedShortage: expectedShortage,
            expectedProfit: expectedProfit
        )
    }

    private static func standardNormalPDF(_ value: Double) -> Double {
        exp(-0.5 * value * value) / sqrt(2 * Double.pi)
    }

    private static func standardNormalCDF(_ value: Double) -> Double {
        0.5 * erfc(-value / sqrt(2))
    }

    private static func inverseStandardNormalCDF(_ probability: Double) -> Double {
        precondition(probability > 0 && probability < 1)

        let a = [
            -3.969683028665376e+01,
            2.209460984245205e+02,
            -2.759285104469687e+02,
            1.383577518672690e+02,
            -3.066479806614716e+01,
            2.506628277459239e+00
        ]
        let b = [
            -5.447609879822406e+01,
            1.615858368580409e+02,
            -1.556989798598866e+02,
            6.680131188771972e+01,
            -1.328068155288572e+01
        ]
        let c = [
            -7.784894002430293e-03,
            -3.223964580411365e-01,
            -2.400758277161838e+00,
            -2.549732539343734e+00,
            4.374664141464968e+00,
            2.938163982698783e+00
        ]
        let d = [
            7.784695709041462e-03,
            3.224671290700398e-01,
            2.445134137142996e+00,
            3.754408661907416e+00
        ]

        let low = 0.02425
        let high = 1 - low

        if probability < low {
            let q = sqrt(-2 * log(probability))
            return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5])
                / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        }
        if probability > high {
            let q = sqrt(-2 * log(1 - probability))
            return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5])
                / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        }

        let q = probability - 0.5
        let r = q * q
        return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q
            / (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1)
    }
}

