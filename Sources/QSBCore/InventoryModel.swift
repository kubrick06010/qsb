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

extension InventoryModelEnvelope: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case model
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(InventoryProblemKind.self, forKey: .kind) {
        case .eoq:
            self = .eoq(try container.decode(EOQModel.self, forKey: .model))
        case .quantityDiscountEOQ:
            self = .quantityDiscountEOQ(try container.decode(QuantityDiscountEOQModel.self, forKey: .model))
        case .newsboy:
            self = .newsboy(try container.decode(NewsboyModel.self, forKey: .model))
        case .lotSizing:
            self = .lotSizing(try container.decode(LotSizingModel.self, forKey: .model))
        case .stochasticReview:
            self = .stochasticReview(try container.decode(StochasticInventoryModel.self, forKey: .model))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .eoq(let model):
            try container.encode(model, forKey: .model)
        case .quantityDiscountEOQ(let model):
            try container.encode(model, forKey: .model)
        case .newsboy(let model):
            try container.encode(model, forKey: .model)
        case .lotSizing(let model):
            try container.encode(model, forKey: .model)
        case .stochasticReview(let model):
            try container.encode(model, forKey: .model)
        }
    }
}

extension InventorySolutionEnvelope: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case solution
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(InventoryProblemKind.self, forKey: .kind) {
        case .eoq:
            self = .eoq(try container.decode(EOQSolution.self, forKey: .solution))
        case .quantityDiscountEOQ:
            self = .quantityDiscountEOQ(try container.decode(QuantityDiscountEOQSolution.self, forKey: .solution))
        case .newsboy:
            self = .newsboy(try container.decode(NewsboySolution.self, forKey: .solution))
        case .lotSizing:
            self = .lotSizing(try container.decode(LotSizingSolution.self, forKey: .solution))
        case .stochasticReview:
            self = .stochasticReview(try container.decode(StochasticInventorySolution.self, forKey: .solution))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .eoq(let solution):
            try container.encode(solution, forKey: .solution)
        case .quantityDiscountEOQ(let solution):
            try container.encode(solution, forKey: .solution)
        case .newsboy(let solution):
            try container.encode(solution, forKey: .solution)
        case .lotSizing(let solution):
            try container.encode(solution, forKey: .solution)
        case .stochasticReview(let solution):
            try container.encode(solution, forKey: .solution)
        }
    }
}

extension InventorySolutionDocument: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case backend
        case title
        case timeUnit
        case assumptions
        case solution
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(InventoryProblemKind.self, forKey: .kind)
        backend = try container.decode(SolverRunMetadata.self, forKey: .backend)
        title = try container.decode(String.self, forKey: .title)
        timeUnit = try container.decode(String.self, forKey: .timeUnit)
        assumptions = try container.decode([String].self, forKey: .assumptions)
        switch kind {
        case .eoq:
            solution = .eoq(try container.decode(EOQSolution.self, forKey: .solution))
        case .quantityDiscountEOQ:
            solution = .quantityDiscountEOQ(try container.decode(QuantityDiscountEOQSolution.self, forKey: .solution))
        case .newsboy:
            solution = .newsboy(try container.decode(NewsboySolution.self, forKey: .solution))
        case .lotSizing:
            solution = .lotSizing(try container.decode(LotSizingSolution.self, forKey: .solution))
        case .stochasticReview:
            solution = .stochasticReview(try container.decode(StochasticInventorySolution.self, forKey: .solution))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(backend, forKey: .backend)
        try container.encode(title, forKey: .title)
        try container.encode(timeUnit, forKey: .timeUnit)
        try container.encode(assumptions, forKey: .assumptions)
        switch solution {
        case .eoq(let solution):
            try container.encode(solution, forKey: .solution)
        case .quantityDiscountEOQ(let solution):
            try container.encode(solution, forKey: .solution)
        case .newsboy(let solution):
            try container.encode(solution, forKey: .solution)
        case .lotSizing(let solution):
            try container.encode(solution, forKey: .solution)
        case .stochasticReview(let solution):
            try container.encode(solution, forKey: .solution)
        }
    }
}

public enum InventoryModelJSON {
    public static func decodeUncheckedModel(from data: Data) throws -> InventoryModelEnvelope {
        try decoder.decode(InventoryModelEnvelope.self, from: data)
    }

    public static func decodeModel(from data: Data) throws -> InventoryModelEnvelope {
        let envelope = try decodeUncheckedModel(from: data)
        try InventoryValidator.validate(envelope)
        return envelope
    }

    public static func encodeModel(_ envelope: InventoryModelEnvelope) throws -> Data {
        try encoder.encode(envelope)
    }

    public static func encodeSolutionDocument(_ document: InventorySolutionDocument) throws -> Data {
        try encoder.encode(document)
    }

    public static func decodeSolutionDocument(from data: Data) throws -> InventorySolutionDocument {
        try decoder.decode(InventorySolutionDocument.self, from: data)
    }

    public static func validationDocument(
        for envelope: InventoryModelEnvelope,
        backend: SolverBackendKind = .validateOnly
    ) -> InventoryValidationDocument {
        InventoryValidationDocument(
            kind: envelope.kind,
            backend: backend,
            diagnostics: InventoryValidator.diagnostics(for: envelope)
        )
    }

    public static func encodeValidation(_ document: InventoryValidationDocument) throws -> Data {
        try encoder.encode(document)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder { JSONDecoder() }
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

public enum EOQValidator {
    public static func diagnostics(for model: EOQModel) -> [ValidationDiagnostic] {
        var diagnostics = commonInventoryDiagnostics(
            title: model.title,
            timeUnit: model.timeUnit,
            codePrefix: "inventory.eoq"
        )
        appendPositiveError(model.demand, name: "demand", path: "model.demand", codePrefix: "inventory.eoq", to: &diagnostics)
        appendPositiveError(model.setupCost, name: "setup cost", path: "model.setupCost", codePrefix: "inventory.eoq", to: &diagnostics)
        appendPositiveError(model.holdingCost, name: "holding cost", path: "model.holdingCost", codePrefix: "inventory.eoq", to: &diagnostics)

        for (name, path, value) in [
            ("shortage cost", "model.shortageCost", model.shortageCost),
            ("replenishment rate", "model.replenishmentRate", model.replenishmentRate),
            ("lead time", "model.leadTime", model.leadTime),
            ("acquisition cost", "model.acquisitionCost", model.acquisitionCost),
            ("known order quantity", "model.knownOrderQuantity", model.knownOrderQuantity)
        ] {
            if let value {
                appendNonnegativeError(value, name: name, path: path, codePrefix: "inventory.eoq", to: &diagnostics)
            }
        }
        if let quantity = model.knownOrderQuantity, quantity == 0 {
            diagnostics.append(errorDiagnostic(
                code: "inventory.eoq.knownQuantity.nonpositive",
                message: "Known order quantity must be positive.",
                path: "model.knownOrderQuantity"
            ))
        }
        if let rate = model.replenishmentRate, rate <= model.demand {
            diagnostics.append(errorDiagnostic(
                code: "inventory.eoq.replenishmentRate.insufficient",
                message: "Replenishment rate must be greater than demand.",
                path: "model.replenishmentRate"
            ))
        }
        if model.shortageCost != nil {
            diagnostics.append(ValidationDiagnostic(
                severity: .warning,
                code: "inventory.eoq.shortageCost.unused",
                message: "The current native EOQ formula reports shortage cost but does not optimize planned shortages.",
                path: "model.shortageCost"
            ))
        }
        return diagnostics
    }

    public static func validate(_ model: EOQModel) throws {
        try throwFirstInventoryValidationError(diagnostics(for: model))
    }
}

public enum QuantityDiscountEOQValidator {
    public static func diagnostics(for model: QuantityDiscountEOQModel) -> [ValidationDiagnostic] {
        var diagnostics = commonInventoryDiagnostics(
            title: model.title,
            timeUnit: model.timeUnit,
            codePrefix: "inventory.quantityDiscountEOQ"
        )
        let prefix = "inventory.quantityDiscountEOQ"
        appendPositiveError(model.demand, name: "demand", path: "model.demand", codePrefix: prefix, to: &diagnostics)
        appendPositiveError(model.setupCost, name: "setup cost", path: "model.setupCost", codePrefix: prefix, to: &diagnostics)
        appendPositiveError(model.holdingCost, name: "holding cost", path: "model.holdingCost", codePrefix: prefix, to: &diagnostics)
        appendNonnegativeError(model.acquisitionCost, name: "acquisition cost", path: "model.acquisitionCost", codePrefix: prefix, to: &diagnostics)

        var seenMinimums: Set<Double> = []
        for (index, discountBreak) in model.discountBreaks.enumerated() {
            let path = "model.discountBreaks[\(index)]"
            appendPositiveError(
                discountBreak.minimumQuantity,
                name: "discount minimum quantity",
                path: "\(path).minimumQuantity",
                codePrefix: prefix,
                to: &diagnostics
            )
            guard discountBreak.discountPercent.isFinite,
                  discountBreak.discountPercent >= 0,
                  discountBreak.discountPercent < 100
            else {
                diagnostics.append(errorDiagnostic(
                    code: "\(prefix).discountPercent.invalid",
                    message: "Discount percentages must be finite and in the range [0, 100).",
                    path: "\(path).discountPercent"
                ))
                continue
            }
            if !seenMinimums.insert(discountBreak.minimumQuantity).inserted {
                diagnostics.append(errorDiagnostic(
                    code: "\(prefix).minimumQuantity.duplicate",
                    message: "Discount minimum quantities must be unique.",
                    path: "\(path).minimumQuantity"
                ))
            }
        }
        if model.discountBreaks.map(\.minimumQuantity) != model.discountBreaks.map(\.minimumQuantity).sorted() {
            diagnostics.append(ValidationDiagnostic(
                severity: .warning,
                code: "\(prefix).breaks.unsorted",
                message: "Discount breaks will be evaluated in ascending minimum-quantity order.",
                path: "model.discountBreaks"
            ))
        }
        if let quantity = model.knownOrderQuantity {
            appendPositiveError(quantity, name: "known order quantity", path: "model.knownOrderQuantity", codePrefix: prefix, to: &diagnostics)
        }
        return diagnostics
    }

    public static func validate(_ model: QuantityDiscountEOQModel) throws {
        try throwFirstInventoryValidationError(diagnostics(for: model))
    }
}

public enum NewsboyValidator {
    public static func diagnostics(for model: NewsboyModel) -> [ValidationDiagnostic] {
        var diagnostics = commonInventoryDiagnostics(
            title: model.title,
            timeUnit: model.timeUnit,
            codePrefix: "inventory.newsboy"
        )
        let prefix = "inventory.newsboy"
        if model.demandDistribution.lowercased() != "normal" {
            diagnostics.append(errorDiagnostic(
                code: "\(prefix).distribution.unsupported",
                message: "The native newsboy backend currently supports only normal demand.",
                path: "model.demandDistribution"
            ))
        }
        appendPositiveError(model.meanDemand, name: "mean demand", path: "model.meanDemand", codePrefix: prefix, to: &diagnostics)
        appendPositiveError(model.standardDeviation, name: "standard deviation", path: "model.standardDeviation", codePrefix: prefix, to: &diagnostics)
        appendNonnegativeError(model.setupCost, name: "setup cost", path: "model.setupCost", codePrefix: prefix, to: &diagnostics)
        appendNonnegativeError(model.acquisitionCost, name: "acquisition cost", path: "model.acquisitionCost", codePrefix: prefix, to: &diagnostics)
        appendNonnegativeError(model.sellingPrice, name: "selling price", path: "model.sellingPrice", codePrefix: prefix, to: &diagnostics)
        appendNonnegativeError(model.shortageCost, name: "shortage cost", path: "model.shortageCost", codePrefix: prefix, to: &diagnostics)
        appendNonnegativeError(model.salvageValue, name: "salvage value", path: "model.salvageValue", codePrefix: prefix, to: &diagnostics)
        if model.sellingPrice < model.acquisitionCost {
            diagnostics.append(errorDiagnostic(
                code: "\(prefix).sellingPrice.belowAcquisition",
                message: "Selling price must be at least the acquisition cost.",
                path: "model.sellingPrice"
            ))
        }
        if model.acquisitionCost <= model.salvageValue {
            diagnostics.append(errorDiagnostic(
                code: "\(prefix).salvageValue.tooHigh",
                message: "Acquisition cost must be greater than salvage value.",
                path: "model.salvageValue"
            ))
        }
        if model.sellingPrice - model.acquisitionCost + model.shortageCost <= 0 {
            diagnostics.append(errorDiagnostic(
                code: "\(prefix).underageCost.nonpositive",
                message: "Selling margin plus shortage cost must be positive.",
                path: "model.sellingPrice"
            ))
        }
        for (name, path, value) in [
            ("initial inventory", "model.initialInventory", model.initialInventory),
            ("known order quantity", "model.knownOrderQuantity", model.knownOrderQuantity)
        ] {
            if let value {
                appendNonnegativeError(value, name: name, path: path, codePrefix: prefix, to: &diagnostics)
            }
        }
        if let percent = model.desiredServiceLevelPercent,
           !percent.isFinite || percent <= 0 || percent >= 100 {
            diagnostics.append(errorDiagnostic(
                code: "\(prefix).serviceLevel.invalid",
                message: "Desired service level must be finite and between 0 and 100 percent.",
                path: "model.desiredServiceLevelPercent"
            ))
        }
        return diagnostics
    }

    public static func validate(_ model: NewsboyModel) throws {
        try throwFirstInventoryValidationError(diagnostics(for: model))
    }
}

public enum LotSizingValidator {
    public static func diagnostics(for model: LotSizingModel) -> [ValidationDiagnostic] {
        var diagnostics = commonInventoryDiagnostics(
            title: model.title,
            timeUnit: model.timeUnit,
            codePrefix: "inventory.lotSizing"
        )
        let prefix = "inventory.lotSizing"
        if model.periods.isEmpty {
            diagnostics.append(errorDiagnostic(
                code: "\(prefix).periods.empty",
                message: "Lot sizing requires at least one period.",
                path: "model.periods"
            ))
            return diagnostics
        }

        var labels: Set<String> = []
        for (index, period) in model.periods.enumerated() {
            let path = "model.periods[\(index)]"
            if period.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                diagnostics.append(errorDiagnostic(
                    code: "\(prefix).period.name.empty",
                    message: "Every lot-sizing period needs a label.",
                    path: "\(path).name"
                ))
            } else if !labels.insert(period.name).inserted {
                diagnostics.append(ValidationDiagnostic(
                    severity: .warning,
                    code: "\(prefix).period.name.duplicate",
                    message: "Period labels should be unique for unambiguous solution output.",
                    path: "\(path).name"
                ))
            }
            if period.demand < 0 {
                diagnostics.append(errorDiagnostic(
                    code: "\(prefix).period.demand.negative",
                    message: "Period demand must be nonnegative.",
                    path: "\(path).demand"
                ))
            }
            for (name, keyPath, value) in [
                ("setup cost", "setupCost", period.setupCost),
                ("unit variable cost", "unitVariableCost", period.unitVariableCost),
                ("unit holding cost", "unitHoldingCost", period.unitHoldingCost),
                ("unit backorder cost", "unitBackorderCost", period.unitBackorderCost)
            ] {
                appendNonnegativeError(value, name: name, path: "\(path).\(keyPath)", codePrefix: prefix, to: &diagnostics)
            }
        }
        return diagnostics
    }

    public static func validate(_ model: LotSizingModel) throws {
        try throwFirstInventoryValidationError(diagnostics(for: model))
    }
}

public enum InventoryValidator {
    public static func diagnostics(for envelope: InventoryModelEnvelope) -> [ValidationDiagnostic] {
        switch envelope {
        case .eoq(let model): EOQValidator.diagnostics(for: model)
        case .quantityDiscountEOQ(let model): QuantityDiscountEOQValidator.diagnostics(for: model)
        case .newsboy(let model): NewsboyValidator.diagnostics(for: model)
        case .lotSizing(let model): LotSizingValidator.diagnostics(for: model)
        case .stochasticReview(let model): StochasticInventoryValidator.diagnostics(for: model)
        }
    }

    public static func validate(_ envelope: InventoryModelEnvelope) throws {
        try throwFirstInventoryValidationError(diagnostics(for: envelope))
    }
}

public protocol InventoryBackend: Sendable {
    var capabilities: SolverCapabilities { get }

    func validationReport(for model: EOQModel) -> ValidationReport
    func validationReport(for model: QuantityDiscountEOQModel) -> ValidationReport
    func validationReport(for model: NewsboyModel) -> ValidationReport
    func validationReport(for model: LotSizingModel) -> ValidationReport
    func validationReport(for model: StochasticInventoryModel) -> ValidationReport

    func solve(_ model: EOQModel, options: SolverOptions) throws -> EOQSolution
    func solve(_ model: QuantityDiscountEOQModel, options: SolverOptions) throws -> QuantityDiscountEOQSolution
    func solve(_ model: NewsboyModel, options: SolverOptions) throws -> NewsboySolution
    func solve(_ model: LotSizingModel, options: SolverOptions) throws -> LotSizingSolution
    func solve(_ model: StochasticInventoryModel, options: SolverOptions) throws -> StochasticInventorySolution

    func runMetadata(for model: EOQModel) -> SolverRunMetadata
    func runMetadata(for model: QuantityDiscountEOQModel) -> SolverRunMetadata
    func runMetadata(for model: NewsboyModel) -> SolverRunMetadata
    func runMetadata(for model: LotSizingModel) -> SolverRunMetadata
    func runMetadata(for model: StochasticInventoryModel) -> SolverRunMetadata
}

public extension InventoryBackend {
    func validationReport(for model: EOQModel) -> ValidationReport {
        ValidationReport(backend: capabilities.backendKind, diagnostics: EOQValidator.diagnostics(for: model))
    }

    func validationReport(for model: QuantityDiscountEOQModel) -> ValidationReport {
        ValidationReport(backend: capabilities.backendKind, diagnostics: QuantityDiscountEOQValidator.diagnostics(for: model))
    }

    func validationReport(for model: NewsboyModel) -> ValidationReport {
        ValidationReport(backend: capabilities.backendKind, diagnostics: NewsboyValidator.diagnostics(for: model))
    }

    func validationReport(for model: LotSizingModel) -> ValidationReport {
        ValidationReport(backend: capabilities.backendKind, diagnostics: LotSizingValidator.diagnostics(for: model))
    }

    func validationReport(for model: StochasticInventoryModel) -> ValidationReport {
        ValidationReport(backend: capabilities.backendKind, diagnostics: StochasticInventoryValidator.diagnostics(for: model))
    }

    func validationReport(for envelope: InventoryModelEnvelope) -> ValidationReport {
        switch envelope {
        case .eoq(let model): validationReport(for: model)
        case .quantityDiscountEOQ(let model): validationReport(for: model)
        case .newsboy(let model): validationReport(for: model)
        case .lotSizing(let model): validationReport(for: model)
        case .stochasticReview(let model): validationReport(for: model)
        }
    }

    func solve(_ model: EOQModel) throws -> EOQSolution { try solve(model, options: SolverOptions()) }
    func solve(_ model: QuantityDiscountEOQModel) throws -> QuantityDiscountEOQSolution { try solve(model, options: SolverOptions()) }
    func solve(_ model: NewsboyModel) throws -> NewsboySolution { try solve(model, options: SolverOptions()) }
    func solve(_ model: LotSizingModel) throws -> LotSizingSolution { try solve(model, options: SolverOptions()) }
    func solve(_ model: StochasticInventoryModel) throws -> StochasticInventorySolution { try solve(model, options: SolverOptions()) }

    func solve(
        _ envelope: InventoryModelEnvelope,
        options: SolverOptions = SolverOptions()
    ) throws -> InventorySolutionEnvelope {
        switch envelope {
        case .eoq(let model): .eoq(try solve(model, options: options))
        case .quantityDiscountEOQ(let model): .quantityDiscountEOQ(try solve(model, options: options))
        case .newsboy(let model): .newsboy(try solve(model, options: options))
        case .lotSizing(let model): .lotSizing(try solve(model, options: options))
        case .stochasticReview(let model): .stochasticReview(try solve(model, options: options))
        }
    }

    func runMetadata(for envelope: InventoryModelEnvelope) -> SolverRunMetadata {
        switch envelope {
        case .eoq(let model): runMetadata(for: model)
        case .quantityDiscountEOQ(let model): runMetadata(for: model)
        case .newsboy(let model): runMetadata(for: model)
        case .lotSizing(let model): runMetadata(for: model)
        case .stochasticReview(let model): runMetadata(for: model)
        }
    }

    func solutionDocument(
        for model: InventoryModelEnvelope,
        solution: InventorySolutionEnvelope
    ) -> InventorySolutionDocument {
        InventorySolutionDocument(
            backend: runMetadata(for: model),
            title: model.title,
            timeUnit: model.timeUnit,
            assumptions: inventoryAssumptions(for: model.kind),
            solution: solution
        )
    }
}

public struct NativeEducationalInventoryBackend: InventoryBackend {
    public init() {}

    public var capabilities: SolverCapabilities {
        SolverCapabilities(
            backendKind: .nativeEducational,
            solves: true,
            validates: true,
            exportsStructuredSolution: true,
            notes: [
                "Uses closed-form EOQ and normal-demand newsvendor methods.",
                "Uses exact tier enumeration for all-units discounts.",
                "Uses fixture-scale dynamic programming for finite-horizon lot sizing."
            ]
        )
    }

    public func solve(_ model: EOQModel, options _: SolverOptions = SolverOptions()) throws -> EOQSolution {
        try EOQSolver.solve(model)
    }

    public func solve(_ model: QuantityDiscountEOQModel, options _: SolverOptions = SolverOptions()) throws -> QuantityDiscountEOQSolution {
        try QuantityDiscountEOQSolver.solve(model)
    }

    public func solve(_ model: NewsboyModel, options _: SolverOptions = SolverOptions()) throws -> NewsboySolution {
        try NewsboySolver.solve(model)
    }

    public func solve(_ model: LotSizingModel, options _: SolverOptions = SolverOptions()) throws -> LotSizingSolution {
        try LotSizingSolver.solve(model)
    }

    public func solve(_ model: StochasticInventoryModel, options _: SolverOptions = SolverOptions()) throws -> StochasticInventorySolution {
        try StochasticInventorySolver.solve(model)
    }

    public func runMetadata(for model: EOQModel) -> SolverRunMetadata {
        SolverRunMetadata(
            backendKind: .nativeEducational,
            algorithm: model.replenishmentRate == nil ? "economicOrderQuantityClosedForm" : "economicProductionQuantityClosedForm",
            exactness: .closedForm,
            notes: inventoryAssumptions(for: .eoq)
        )
    }

    public func runMetadata(for model: QuantityDiscountEOQModel) -> SolverRunMetadata {
        SolverRunMetadata(
            backendKind: .nativeEducational,
            algorithm: "allUnitsDiscountTierEnumeration",
            exactness: .exact,
            notes: inventoryAssumptions(for: .quantityDiscountEOQ)
        )
    }

    public func runMetadata(for model: NewsboyModel) -> SolverRunMetadata {
        SolverRunMetadata(
            backendKind: .nativeEducational,
            algorithm: "normalDemandCriticalFractile",
            exactness: .closedForm,
            notes: inventoryAssumptions(for: .newsboy)
        )
    }

    public func runMetadata(for model: LotSizingModel) -> SolverRunMetadata {
        SolverRunMetadata(
            backendKind: .nativeEducational,
            algorithm: "finiteHorizonInventoryDynamicProgramming",
            exactness: .fixtureScale,
            notes: inventoryAssumptions(for: .lotSizing)
        )
    }

    public func runMetadata(for model: StochasticInventoryModel) -> SolverRunMetadata {
        SolverRunMetadata(
            backendKind: .nativeEducational,
            algorithm: "normalDemand\(model.policy.rawValue.prefix(1).uppercased())\(model.policy.rawValue.dropFirst())Approximation",
            exactness: .approximate,
            notes: inventoryAssumptions(for: .stochasticReview)
        )
    }
}

public struct ValidateOnlyInventoryBackend: InventoryBackend {
    public init() {}

    public var capabilities: SolverCapabilities {
        SolverCapabilities(
            backendKind: .validateOnly,
            solves: false,
            validates: true,
            exportsStructuredSolution: false,
            notes: ["Runs inventory validation without solving the model."]
        )
    }

    public func solve(_ model: EOQModel, options _: SolverOptions = SolverOptions()) throws -> EOQSolution {
        throw validationOnlyInventoryError(for: .eoq)
    }

    public func solve(_ model: QuantityDiscountEOQModel, options _: SolverOptions = SolverOptions()) throws -> QuantityDiscountEOQSolution {
        throw validationOnlyInventoryError(for: .quantityDiscountEOQ)
    }

    public func solve(_ model: NewsboyModel, options _: SolverOptions = SolverOptions()) throws -> NewsboySolution {
        throw validationOnlyInventoryError(for: .newsboy)
    }

    public func solve(_ model: LotSizingModel, options _: SolverOptions = SolverOptions()) throws -> LotSizingSolution {
        throw validationOnlyInventoryError(for: .lotSizing)
    }

    public func solve(_ model: StochasticInventoryModel, options _: SolverOptions = SolverOptions()) throws -> StochasticInventorySolution {
        throw validationOnlyInventoryError(for: .stochasticReview)
    }

    public func runMetadata(for model: EOQModel) -> SolverRunMetadata { validationMetadata(for: .eoq) }
    public func runMetadata(for model: QuantityDiscountEOQModel) -> SolverRunMetadata { validationMetadata(for: .quantityDiscountEOQ) }
    public func runMetadata(for model: NewsboyModel) -> SolverRunMetadata { validationMetadata(for: .newsboy) }
    public func runMetadata(for model: LotSizingModel) -> SolverRunMetadata { validationMetadata(for: .lotSizing) }
    public func runMetadata(for model: StochasticInventoryModel) -> SolverRunMetadata { validationMetadata(for: .stochasticReview) }

    private func validationMetadata(for kind: InventoryProblemKind) -> SolverRunMetadata {
        SolverRunMetadata(
            backendKind: .validateOnly,
            algorithm: "validationOnly",
            exactness: .exact,
            notes: ["Validates the \(kind.rawValue) model without solving it."]
        )
    }
}

public enum InventoryBackends {
    public static func backend(for kind: SolverBackendKind) -> (any InventoryBackend)? {
        switch kind {
        case .nativeEducational: NativeEducationalInventoryBackend()
        case .validateOnly: ValidateOnlyInventoryBackend()
        case .externalHighPerformance: nil
        }
    }
}

private func inventoryAssumptions(for kind: InventoryProblemKind) -> [String] {
    switch kind {
    case .eoq:
        ["Constant deterministic demand and instantaneous replenishment unless a production rate is supplied."]
    case .quantityDiscountEOQ:
        ["All-units percentage discounts with constant deterministic demand and holding cost independent of unit price."]
    case .newsboy:
        ["Single-period normal demand with linear underage and overage economics."]
    case .lotSizing:
        ["Integer production, zero initial inventory, and a balanced zero-inventory final state."]
    case .stochasticReview:
        ["Normal independent demand, constant lead time, expected-shortage loss functions, and continuous decision quantities.", "Periodic capacity constraints and empirical demand distributions are not modeled."]
    }
}

private func validationOnlyInventoryError(for kind: InventoryProblemKind) -> InventoryModelError {
    .invalidModel("validateOnly backend does not solve \(kind.rawValue) models")
}

func commonInventoryDiagnostics(
    title: String,
    timeUnit: String,
    codePrefix: String
) -> [ValidationDiagnostic] {
    var diagnostics: [ValidationDiagnostic] = []
    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        diagnostics.append(ValidationDiagnostic(
            severity: .warning,
            code: "\(codePrefix).title.empty",
            message: "Model title is empty.",
            path: "model.title"
        ))
    }
    if timeUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        diagnostics.append(errorDiagnostic(
            code: "\(codePrefix).timeUnit.empty",
            message: "Time unit must not be empty.",
            path: "model.timeUnit"
        ))
    }
    return diagnostics
}

func appendPositiveError(
    _ value: Double,
    name: String,
    path: String,
    codePrefix: String,
    to diagnostics: inout [ValidationDiagnostic]
) {
    guard value.isFinite, value > 0 else {
        diagnostics.append(errorDiagnostic(
            code: "\(codePrefix).\(path.split(separator: ".").last ?? "value").nonpositive",
            message: "\(name.capitalized) must be finite and positive.",
            path: path
        ))
        return
    }
}

func appendNonnegativeError(
    _ value: Double,
    name: String,
    path: String,
    codePrefix: String,
    to diagnostics: inout [ValidationDiagnostic]
) {
    guard value.isFinite, value >= 0 else {
        diagnostics.append(errorDiagnostic(
            code: "\(codePrefix).\(path.split(separator: ".").last ?? "value").negative",
            message: "\(name.capitalized) must be finite and nonnegative.",
            path: path
        ))
        return
    }
}

private func errorDiagnostic(code: String, message: String, path: String) -> ValidationDiagnostic {
    ValidationDiagnostic(severity: .error, code: code, message: message, path: path)
}

func throwFirstInventoryValidationError(_ diagnostics: [ValidationDiagnostic]) throws {
    if let diagnostic = diagnostics.first(where: { $0.severity == .error }) {
        throw InventoryModelError.invalidModel(diagnostic.message)
    }
}

public enum WinQSBInventoryParser {
    public static func parseModelEnvelope(from data: Data) throws -> InventoryModelEnvelope {
        guard let text = data.legacyLatin1String,
              let firstLine = text
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
                .split(separator: "\n", omittingEmptySubsequences: true)
                .first
        else {
            throw InventoryModelError.unsupportedFormat
        }
        let metadata = firstLine
            .split(separator: "\t", omittingEmptySubsequences: false)
            .map(clean)
        guard metadata.count >= 5, metadata[0] == "ITS" else {
            throw InventoryModelError.unsupportedFormat
        }
        switch (metadata[3], metadata[4]) {
        case ("0", "0"):
            return .eoq(try parseEOQ(from: data))
        case ("1", "1"):
            return .quantityDiscountEOQ(try parseQuantityDiscountEOQ(from: data))
        case ("2", "2"):
            return .newsboy(try parseNewsboy(from: data))
        case ("3", _):
            return .lotSizing(try parseLotSizing(from: data))
        case ("4", _), ("5", _), ("6", _), ("7", _):
            return .stochasticReview(try parseStochasticInventory(from: data))
        default:
            throw InventoryModelError.unsupportedModel(
                "recognized ITS variant \(metadata[3]) \(metadata[4]) has no normalized model yet"
            )
        }
    }

    public static func parseEOQ(from data: Data) throws -> EOQModel {
        guard let text = data.legacyLatin1String else {
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
        guard let text = data.legacyLatin1String else {
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
