import Foundation

public struct EOQModel: Codable, Equatable, Sendable {
    public let title: String
    public let timeUnit: String
    public let demand: Double
    public let setupCost: Double
    public let holdingCost: Double
    public let shortageCost: Double?
    public let replenishmentRate: Double?
    public let leadTime: Double?
    public let acquisitionCost: Double?
    public let knownOrderQuantity: Double?

    public init(
        title: String,
        timeUnit: String,
        demand: Double,
        setupCost: Double,
        holdingCost: Double,
        shortageCost: Double? = nil,
        replenishmentRate: Double? = nil,
        leadTime: Double? = nil,
        acquisitionCost: Double? = nil,
        knownOrderQuantity: Double? = nil
    ) {
        self.title = title
        self.timeUnit = timeUnit
        self.demand = demand
        self.setupCost = setupCost
        self.holdingCost = holdingCost
        self.shortageCost = shortageCost
        self.replenishmentRate = replenishmentRate
        self.leadTime = leadTime
        self.acquisitionCost = acquisitionCost
        self.knownOrderQuantity = knownOrderQuantity
    }
}

public struct EOQCostBreakdown: Codable, Equatable, Sendable {
    public let orderQuantity: Double
    public let setupCost: Double
    public let holdingCost: Double
    public let acquisitionCost: Double
    public let totalRelevantCost: Double
    public let totalCost: Double
}

public struct EOQSolution: Codable, Equatable, Sendable {
    public let economicOrderQuantity: Double
    public let cycleCount: Double
    public let cycleLength: Double
    public let reorderPoint: Double?
    public let optimum: EOQCostBreakdown
    public let knownQuantity: EOQCostBreakdown?
}

public struct QuantityDiscountBreak: Codable, Equatable, Sendable {
    public let minimumQuantity: Double
    public let discountPercent: Double

    public init(minimumQuantity: Double, discountPercent: Double) {
        self.minimumQuantity = minimumQuantity
        self.discountPercent = discountPercent
    }
}

public struct QuantityDiscountEOQModel: Codable, Equatable, Sendable {
    public let title: String
    public let timeUnit: String
    public let demand: Double
    public let setupCost: Double
    public let holdingCost: Double
    public let acquisitionCost: Double
    public let discountBreaks: [QuantityDiscountBreak]
    public let knownOrderQuantity: Double?

    public init(
        title: String,
        timeUnit: String,
        demand: Double,
        setupCost: Double,
        holdingCost: Double,
        acquisitionCost: Double,
        discountBreaks: [QuantityDiscountBreak],
        knownOrderQuantity: Double? = nil
    ) {
        self.title = title
        self.timeUnit = timeUnit
        self.demand = demand
        self.setupCost = setupCost
        self.holdingCost = holdingCost
        self.acquisitionCost = acquisitionCost
        self.discountBreaks = discountBreaks
        self.knownOrderQuantity = knownOrderQuantity
    }
}

public struct QuantityDiscountCandidate: Codable, Equatable, Sendable {
    public let minimumQuantity: Double
    public let discountPercent: Double
    public let unitAcquisitionCost: Double
    public let cost: EOQCostBreakdown
}

public struct QuantityDiscountEOQSolution: Codable, Equatable, Sendable {
    public let unconstrainedEOQ: Double
    public let candidates: [QuantityDiscountCandidate]
    public let optimum: QuantityDiscountCandidate
    public let knownQuantity: QuantityDiscountCandidate?
}

public struct NewsboyModel: Codable, Equatable, Sendable {
    public let title: String
    public let timeUnit: String
    public let demandDistribution: String
    public let meanDemand: Double
    public let standardDeviation: Double
    public let setupCost: Double
    public let acquisitionCost: Double
    public let sellingPrice: Double
    public let shortageCost: Double
    public let salvageValue: Double
    public let initialInventory: Double?
    public let knownOrderQuantity: Double?
    public let desiredServiceLevelPercent: Double?

    public init(
        title: String,
        timeUnit: String,
        demandDistribution: String,
        meanDemand: Double,
        standardDeviation: Double,
        setupCost: Double,
        acquisitionCost: Double,
        sellingPrice: Double,
        shortageCost: Double,
        salvageValue: Double,
        initialInventory: Double? = nil,
        knownOrderQuantity: Double? = nil,
        desiredServiceLevelPercent: Double? = nil
    ) {
        self.title = title
        self.timeUnit = timeUnit
        self.demandDistribution = demandDistribution
        self.meanDemand = meanDemand
        self.standardDeviation = standardDeviation
        self.setupCost = setupCost
        self.acquisitionCost = acquisitionCost
        self.sellingPrice = sellingPrice
        self.shortageCost = shortageCost
        self.salvageValue = salvageValue
        self.initialInventory = initialInventory
        self.knownOrderQuantity = knownOrderQuantity
        self.desiredServiceLevelPercent = desiredServiceLevelPercent
    }
}

public struct NewsboyEvaluation: Codable, Equatable, Sendable {
    public let orderQuantity: Double
    public let inventoryPosition: Double
    public let serviceLevel: Double
    public let expectedSales: Double
    public let expectedLeftover: Double
    public let expectedShortage: Double
    public let expectedProfit: Double
}

public struct NewsboySolution: Codable, Equatable, Sendable {
    public let criticalRatio: Double
    public let optimum: NewsboyEvaluation
    public let knownQuantity: NewsboyEvaluation?
    public let desiredServiceLevelQuantity: Double?
}

public struct LotSizingPeriod: Codable, Equatable, Sendable {
    public let name: String
    public let demand: Int
    public let setupCost: Double
    public let unitVariableCost: Double
    public let unitHoldingCost: Double
    public let unitBackorderCost: Double

    public init(
        name: String,
        demand: Int,
        setupCost: Double,
        unitVariableCost: Double,
        unitHoldingCost: Double,
        unitBackorderCost: Double
    ) {
        self.name = name
        self.demand = demand
        self.setupCost = setupCost
        self.unitVariableCost = unitVariableCost
        self.unitHoldingCost = unitHoldingCost
        self.unitBackorderCost = unitBackorderCost
    }
}

public struct LotSizingModel: Codable, Equatable, Sendable {
    public let title: String
    public let timeUnit: String
    public let periods: [LotSizingPeriod]

    public init(title: String, timeUnit: String, periods: [LotSizingPeriod]) {
        self.title = title
        self.timeUnit = timeUnit
        self.periods = periods
    }
}

public struct LotSizingDecision: Codable, Equatable, Sendable {
    public let period: String
    public let demand: Int
    public let productionQuantity: Int
    public let endingInventory: Int
    public let setupCost: Double
    public let variableCost: Double
    public let holdingCost: Double
    public let backorderCost: Double
    public let totalCost: Double
}

public struct LotSizingSolution: Codable, Equatable, Sendable {
    public let totalCost: Double
    public let decisions: [LotSizingDecision]
}

public enum InventoryModelError: Error, CustomStringConvertible {
    case unsupportedFormat
    case unsupportedModel(String)
    case invalidNumericValue(String)
    case invalidModel(String)

    public var description: String {
        switch self {
        case .unsupportedFormat:
            "Unsupported inventory model format"
        case .unsupportedModel(let detail):
            "Unsupported inventory model: \(detail)"
        case .invalidNumericValue(let value):
            "Invalid numeric value: \(value)"
        case .invalidModel(let detail):
            "Invalid inventory model: \(detail)"
        }
    }
}

public enum WinQSBInventoryParser {
    public static func parseEOQ(from data: Data) throws -> EOQModel {
        guard let text = String(data: data, encoding: .isoLatin1) else {
            throw InventoryModelError.unsupportedFormat
        }

        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(clean) }

        guard let metadata = lines.first,
              metadata.count >= 5,
              metadata[0] == "ITS",
              metadata[3] == "0",
              metadata[4] == "0"
        else {
            throw InventoryModelError.unsupportedFormat
        }

        var entries: [String: String] = [:]
        for row in lines.dropFirst(2) where row.count >= 2 {
            entries[row[0].lowercased()] = row[1]
        }

        return EOQModel(
            title: metadata[1],
            timeUnit: metadata[2],
            demand: try requiredDouble(entries, "demand per year"),
            setupCost: try requiredDouble(entries, "order or setup cost per order"),
            holdingCost: try requiredDouble(entries, "unit holding cost per year"),
            shortageCost: try optionalDouble(entries["unit shortage cost per year"]),
            replenishmentRate: try optionalDouble(entries["replenishment or production rate per year"]),
            leadTime: try optionalDouble(entries["lead time for a new order in year"]),
            acquisitionCost: try optionalDouble(entries["unit acquisition cost without discount"]),
            knownOrderQuantity: try optionalDouble(entries["order quantity if you known"])
        )
    }

    public static func parseNewsboy(from data: Data) throws -> NewsboyModel {
        let (metadata, entries) = try parseEntryTable(from: data)
        guard metadata.count >= 5,
              metadata[0] == "ITS",
              metadata[3] == "2",
              metadata[4] == "2"
        else {
            throw InventoryModelError.unsupportedFormat
        }

        let distribution = entries["demand distribution (in year)"] ?? ""
        guard distribution.lowercased() == "normal" else {
            throw InventoryModelError.unsupportedModel("only normal newsboy demand is currently supported")
        }

        return NewsboyModel(
            title: metadata[1],
            timeUnit: metadata[2],
            demandDistribution: distribution,
            meanDemand: try requiredDouble(entries, "mean (u)"),
            standardDeviation: try requiredDouble(entries, "standard deviation (s>0)"),
            setupCost: try requiredDouble(entries, "order or setup cost"),
            acquisitionCost: try requiredDouble(entries, "unit acquisition cost"),
            sellingPrice: try requiredDouble(entries, "unit selling price"),
            shortageCost: try requiredDouble(entries, "unit shortage (opportunity) cost"),
            salvageValue: try requiredDouble(entries, "unit salvage value"),
            initialInventory: try optionalDouble(entries["initial inventory"]),
            knownOrderQuantity: try optionalDouble(entries["order quantity if you know"]),
            desiredServiceLevelPercent: try optionalDouble(entries["desired service level (%) if you know"])
        )
    }

    public static func parseQuantityDiscountEOQ(from data: Data) throws -> QuantityDiscountEOQModel {
        let (metadata, entries, lines) = try parseEntryTableWithLines(from: data)
        guard metadata.count >= 5,
              metadata[0] == "ITS",
              metadata[3] == "1",
              metadata[4] == "1"
        else {
            throw InventoryModelError.unsupportedFormat
        }

        let breakCount = Int(try requiredDouble(entries, "number of discount breaks (quantities)"))
        guard breakCount >= 0 else {
            throw InventoryModelError.invalidModel("discount break count must be nonnegative")
        }

        guard let breakCountRowIndex = lines.firstIndex(where: { row in
            row.first?.lowercased() == "number of discount breaks (quantities)"
        }) else {
            throw InventoryModelError.unsupportedFormat
        }

        let discountRowsStart = breakCountRowIndex + 4
        guard lines.count >= discountRowsStart + breakCount else {
            throw InventoryModelError.unsupportedFormat
        }

        let discountBreaks = try (0..<breakCount).map { offset in
            let row = lines[discountRowsStart + offset]
            guard row.count >= 3 else {
                throw InventoryModelError.unsupportedFormat
            }
            return QuantityDiscountBreak(
                minimumQuantity: try requiredDouble(row[1]),
                discountPercent: try requiredDouble(row[2])
            )
        }

        return QuantityDiscountEOQModel(
            title: metadata[1],
            timeUnit: metadata[2],
            demand: try requiredDouble(entries, "demand per year"),
            setupCost: try requiredDouble(entries, "order or setup cost per order"),
            holdingCost: try requiredDouble(entries, "unit holding cost per year"),
            acquisitionCost: try requiredDouble(entries, "unit acquisition cost without discount"),
            discountBreaks: discountBreaks,
            knownOrderQuantity: try optionalDouble(entries["order quantity if you known"])
        )
    }

    public static func parseLotSizing(from data: Data) throws -> LotSizingModel {
        let (metadata, _, lines) = try parseEntryTableWithLines(from: data)
        guard metadata.count >= 5,
              metadata[0] == "ITS",
              metadata[3] == "3",
              let periodCount = Int(metadata[4]),
              periodCount > 0,
              lines.count >= periodCount + 2
        else {
            throw InventoryModelError.unsupportedFormat
        }

        let periods = try lines[2..<(2 + periodCount)].map { row in
            guard row.count >= 6 else {
                throw InventoryModelError.unsupportedFormat
            }
            return LotSizingPeriod(
                name: row[0],
                demand: try requiredInt(row[1]),
                setupCost: try requiredDouble(row[2]),
                unitVariableCost: try requiredDouble(row[3]),
                unitHoldingCost: try requiredDouble(row[4]),
                unitBackorderCost: try requiredDouble(row[5])
            )
        }

        return LotSizingModel(
            title: metadata[1],
            timeUnit: metadata[2],
            periods: periods
        )
    }

    private static func parseEntryTable(from data: Data) throws -> ([String], [String: String]) {
        let (metadata, entries, _) = try parseEntryTableWithLines(from: data)
        return (metadata, entries)
    }

    private static func parseEntryTableWithLines(from data: Data) throws -> ([String], [String: String], [[String]]) {
        guard let text = String(data: data, encoding: .isoLatin1) else {
            throw InventoryModelError.unsupportedFormat
        }

        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(clean) }

        guard let metadata = lines.first, metadata.count >= 5 else {
            throw InventoryModelError.unsupportedFormat
        }

        var entries: [String: String] = [:]
        for row in lines.dropFirst(2) where row.count >= 2 {
            entries[row[0].lowercased()] = row[1]
        }
        return (metadata, entries, lines)
    }

    private static func requiredDouble(_ entries: [String: String], _ key: String) throws -> Double {
        guard let value = entries[key] else {
            throw InventoryModelError.unsupportedFormat
        }
        guard let number = try optionalDouble(value) else {
            throw InventoryModelError.invalidNumericValue(value)
        }
        return number
    }

    private static func requiredDouble(_ value: String) throws -> Double {
        guard let number = try optionalDouble(value) else {
            throw InventoryModelError.invalidNumericValue(value)
        }
        return number
    }

    private static func requiredInt(_ value: String) throws -> Int {
        let number = try requiredDouble(value)
        let rounded = number.rounded()
        guard abs(number - rounded) < 1e-8 else {
            throw InventoryModelError.unsupportedModel("lot sizing currently requires integer demand")
        }
        return Int(rounded)
    }

    private static func optionalDouble(_ value: String?) throws -> Double? {
        guard let value else {
            return nil
        }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.uppercased() != "M" else {
            return nil
        }
        guard let number = Double(normalized), number.isFinite else {
            throw InventoryModelError.invalidNumericValue(value)
        }
        return number
    }

    private static func clean(_ value: Substring) -> String {
        String(value).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum QuantityDiscountEOQSolver {
    public static func solve(_ model: QuantityDiscountEOQModel) throws -> QuantityDiscountEOQSolution {
        try validate(model)

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

    private static func validate(_ model: QuantityDiscountEOQModel) throws {
        guard model.demand > 0, model.setupCost >= 0, model.holdingCost > 0, model.acquisitionCost >= 0 else {
            throw InventoryModelError.invalidModel("discount EOQ demand, holding cost, and acquisition cost must be valid")
        }
        var previousMinimum = -Double.infinity
        for discountBreak in model.discountBreaks.sorted(by: { $0.minimumQuantity < $1.minimumQuantity }) {
            guard discountBreak.minimumQuantity > 0,
                  discountBreak.minimumQuantity > previousMinimum,
                  discountBreak.discountPercent >= 0,
                  discountBreak.discountPercent < 100
            else {
                throw InventoryModelError.invalidModel("discount breaks must have increasing positive quantities and discounts below 100%")
            }
            previousMinimum = discountBreak.minimumQuantity
        }
        if let knownOrderQuantity = model.knownOrderQuantity {
            guard knownOrderQuantity > 0 else {
                throw InventoryModelError.invalidModel("known order quantity must be positive")
            }
        }
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

public enum NewsboySolver {
    public static func solve(_ model: NewsboyModel) throws -> NewsboySolution {
        try validate(model)

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

    private static func validate(_ model: NewsboyModel) throws {
        guard model.meanDemand > 0, model.standardDeviation > 0 else {
            throw InventoryModelError.invalidModel("normal newsboy demand mean and standard deviation must be positive")
        }
        guard model.setupCost >= 0,
              model.acquisitionCost >= 0,
              model.sellingPrice >= model.acquisitionCost,
              model.shortageCost >= 0,
              model.salvageValue >= 0,
              model.acquisitionCost > model.salvageValue
        else {
            throw InventoryModelError.invalidModel("newsboy costs must be nonnegative with selling price >= acquisition cost > salvage value")
        }
        for value in [model.initialInventory, model.knownOrderQuantity, model.desiredServiceLevelPercent].compactMap({ $0 }) {
            guard value >= 0, value.isFinite else {
                throw InventoryModelError.invalidModel("optional newsboy values must be finite and nonnegative")
            }
        }
        if let desiredServiceLevelPercent = model.desiredServiceLevelPercent {
            guard desiredServiceLevelPercent > 0, desiredServiceLevelPercent < 100 else {
                throw InventoryModelError.invalidModel("desired service level must be between 0 and 100")
            }
        }
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

public enum LotSizingSolver {
    private struct SearchNode {
        let cost: Double
        let previousInventory: Int
        let productionQuantity: Int
        let decision: LotSizingDecision
    }

    public static func solve(_ model: LotSizingModel) throws -> LotSizingSolution {
        try validate(model)

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

    private static func validate(_ model: LotSizingModel) throws {
        guard !model.periods.isEmpty else {
            throw InventoryModelError.invalidModel("lot sizing requires at least one period")
        }
        for period in model.periods {
            guard !period.name.isEmpty,
                  period.demand >= 0,
                  period.setupCost >= 0,
                  period.unitVariableCost >= 0,
                  period.unitHoldingCost >= 0,
                  period.unitBackorderCost >= 0,
                  period.setupCost.isFinite,
                  period.unitVariableCost.isFinite,
                  period.unitHoldingCost.isFinite,
                  period.unitBackorderCost.isFinite
            else {
                throw InventoryModelError.invalidModel("lot sizing periods must have labels, nonnegative integer demand, and nonnegative finite costs")
            }
        }
    }
}

public enum EOQSolver {
    public static func solve(_ model: EOQModel) throws -> EOQSolution {
        try validate(model)

        let eoq: Double
        if let replenishmentRate = model.replenishmentRate {
            guard replenishmentRate > model.demand else {
                throw InventoryModelError.invalidModel("replenishment rate must be greater than demand")
            }
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

    private static func validate(_ model: EOQModel) throws {
        guard model.demand > 0, model.setupCost >= 0, model.holdingCost > 0 else {
            throw InventoryModelError.invalidModel("demand and holding cost must be positive, setup cost must be nonnegative")
        }
        for value in [model.shortageCost, model.replenishmentRate, model.leadTime, model.acquisitionCost, model.knownOrderQuantity].compactMap({ $0 }) {
            guard value >= 0, value.isFinite else {
                throw InventoryModelError.invalidModel("optional EOQ values must be finite and nonnegative")
            }
        }
        if let knownOrderQuantity = model.knownOrderQuantity {
            guard knownOrderQuantity > 0 else {
                throw InventoryModelError.invalidModel("known order quantity must be positive")
            }
        }
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
