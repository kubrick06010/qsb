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

public enum InventoryProblemKind: String, Codable, CaseIterable, Sendable {
    case eoq
    case quantityDiscountEOQ
    case newsboy
    case lotSizing
    case stochasticReview
}

public enum InventoryModelEnvelope: Equatable, Sendable {
    case eoq(EOQModel)
    case quantityDiscountEOQ(QuantityDiscountEOQModel)
    case newsboy(NewsboyModel)
    case lotSizing(LotSizingModel)
    case stochasticReview(StochasticInventoryModel)

    public var kind: InventoryProblemKind {
        switch self {
        case .eoq: .eoq
        case .quantityDiscountEOQ: .quantityDiscountEOQ
        case .newsboy: .newsboy
        case .lotSizing: .lotSizing
        case .stochasticReview: .stochasticReview
        }
    }

    public var title: String {
        switch self {
        case .eoq(let model): model.title
        case .quantityDiscountEOQ(let model): model.title
        case .newsboy(let model): model.title
        case .lotSizing(let model): model.title
        case .stochasticReview(let model): model.title
        }
    }

    public var timeUnit: String {
        switch self {
        case .eoq(let model): model.timeUnit
        case .quantityDiscountEOQ(let model): model.timeUnit
        case .newsboy(let model): model.timeUnit
        case .lotSizing(let model): model.timeUnit
        case .stochasticReview(let model): model.timeUnit
        }
    }
}

public enum InventorySolutionEnvelope: Equatable, Sendable {
    case eoq(EOQSolution)
    case quantityDiscountEOQ(QuantityDiscountEOQSolution)
    case newsboy(NewsboySolution)
    case lotSizing(LotSizingSolution)
    case stochasticReview(StochasticInventorySolution)

    public var kind: InventoryProblemKind {
        switch self {
        case .eoq: .eoq
        case .quantityDiscountEOQ: .quantityDiscountEOQ
        case .newsboy: .newsboy
        case .lotSizing: .lotSizing
        case .stochasticReview: .stochasticReview
        }
    }
}

public struct InventorySolutionDocument: Equatable, Sendable {
    public let backend: SolverRunMetadata
    public let title: String
    public let timeUnit: String
    public let assumptions: [String]
    public let solution: InventorySolutionEnvelope

    public init(
        backend: SolverRunMetadata,
        title: String,
        timeUnit: String,
        assumptions: [String],
        solution: InventorySolutionEnvelope
    ) {
        self.backend = backend
        self.title = title
        self.timeUnit = timeUnit
        self.assumptions = assumptions
        self.solution = solution
    }

    public var kind: InventoryProblemKind { solution.kind }
}

public struct InventoryValidationDocument: Codable, Equatable, Sendable {
    public let kind: InventoryProblemKind
    public let backend: SolverBackendKind
    public let isValid: Bool
    public let diagnostics: [ValidationDiagnostic]

    public init(
        kind: InventoryProblemKind,
        backend: SolverBackendKind = .validateOnly,
        diagnostics: [ValidationDiagnostic]
    ) {
        self.kind = kind
        self.backend = backend
        self.isValid = !diagnostics.contains { $0.severity == .error }
        self.diagnostics = diagnostics
    }
}

