import Foundation

public enum StochasticInventoryPolicy: String, Codable, CaseIterable, Hashable, Sendable {
    case continuousFixedOrderQuantity
    case continuousOrderUpTo
    case periodicFixedOrderInterval
    case periodicOptionalReplenishment
}

public struct StochasticInventoryModel: Codable, Equatable, Sendable {
    public let title: String
    public let timeUnit: String
    public let policy: StochasticInventoryPolicy
    public let demandDistribution: String
    public let meanDemand: Double
    public let demandStandardDeviation: Double
    public let setupCost: Double
    public let acquisitionCost: Double
    public let holdingCost: Double
    public let backorderFraction: Double
    public let backorderCost: Double?
    public let lostSalesFraction: Double
    public let lostSalesCost: Double?
    public let fixedShortageCost: Double?
    public let leadTimeDistribution: String
    public let leadTime: Double
    public let averageOrderSize: Double?
    public let reviewCost: Double?

    public init(title: String, timeUnit: String, policy: StochasticInventoryPolicy, demandDistribution: String, meanDemand: Double, demandStandardDeviation: Double, setupCost: Double, acquisitionCost: Double, holdingCost: Double, backorderFraction: Double, backorderCost: Double?, lostSalesFraction: Double, lostSalesCost: Double?, fixedShortageCost: Double?, leadTimeDistribution: String, leadTime: Double, averageOrderSize: Double?, reviewCost: Double?) {
        self.title = title; self.timeUnit = timeUnit; self.policy = policy
        self.demandDistribution = demandDistribution; self.meanDemand = meanDemand
        self.demandStandardDeviation = demandStandardDeviation; self.setupCost = setupCost
        self.acquisitionCost = acquisitionCost; self.holdingCost = holdingCost
        self.backorderFraction = backorderFraction; self.backorderCost = backorderCost
        self.lostSalesFraction = lostSalesFraction; self.lostSalesCost = lostSalesCost
        self.fixedShortageCost = fixedShortageCost; self.leadTimeDistribution = leadTimeDistribution
        self.leadTime = leadTime; self.averageOrderSize = averageOrderSize; self.reviewCost = reviewCost
    }
}

public struct StochasticInventoryCostBreakdown: Codable, Equatable, Sendable {
    public let orderingCost: Double
    public let reviewCost: Double
    public let holdingCost: Double
    public let expectedShortageCost: Double
    public let acquisitionCost: Double
    public let totalRelevantCost: Double
    public let totalCost: Double
}

public struct StochasticInventorySolution: Codable, Equatable, Sendable {
    public let policy: StochasticInventoryPolicy
    public let orderQuantity: Double
    public let reorderPoint: Double?
    public let orderUpToLevel: Double?
    public let reviewInterval: Double?
    public let protectionPeriod: Double
    public let protectionDemandMean: Double
    public let protectionDemandStandardDeviation: Double
    public let safetyStock: Double
    public let serviceLevel: Double
    public let expectedShortagePerCycle: Double
    public let expectedCyclesPerTimeUnit: Double
    public let costs: StochasticInventoryCostBreakdown
}

public enum StochasticInventoryValidator {
    public static func diagnostics(for model: StochasticInventoryModel) -> [ValidationDiagnostic] {
        var diagnostics = commonInventoryDiagnostics(title: model.title, timeUnit: model.timeUnit, codePrefix: "inventory.stochastic")
        let positive: [(Double, String, String)] = [
            (model.meanDemand, "mean demand", "model.meanDemand"),
            (model.demandStandardDeviation, "demand standard deviation", "model.demandStandardDeviation"),
            (model.holdingCost, "holding cost", "model.holdingCost"),
            (model.setupCost, "setup cost", "model.setupCost")
        ]
        for (value, name, path) in positive { appendPositiveError(value, name: name, path: path, codePrefix: "inventory.stochastic", to: &diagnostics) }
        for (value, name, path) in [(model.acquisitionCost, "acquisition cost", "model.acquisitionCost"), (model.leadTime, "lead time", "model.leadTime")] {
            appendNonnegativeError(value, name: name, path: path, codePrefix: "inventory.stochastic", to: &diagnostics)
        }
        for (value, name, path) in [(model.backorderCost, "backorder cost", "model.backorderCost"), (model.lostSalesCost, "lost-sales cost", "model.lostSalesCost"), (model.fixedShortageCost, "fixed shortage cost", "model.fixedShortageCost")] {
            if let value { appendNonnegativeError(value, name: name, path: path, codePrefix: "inventory.stochastic", to: &diagnostics) }
        }
        if model.demandDistribution.caseInsensitiveCompare("Normal") != .orderedSame {
            diagnostics.append(ValidationDiagnostic(severity: .error, code: "inventory.stochastic.distribution.unsupported", message: "Only normal demand is supported by the native stochastic backend.", path: "model.demandDistribution"))
        }
        if model.leadTimeDistribution.caseInsensitiveCompare("Constant") != .orderedSame {
            diagnostics.append(ValidationDiagnostic(severity: .error, code: "inventory.stochastic.leadTimeDistribution.unsupported", message: "Only constant lead time is supported by the native stochastic backend.", path: "model.leadTimeDistribution"))
        }
        if !model.backorderFraction.isFinite || !model.lostSalesFraction.isFinite || model.backorderFraction < 0 || model.lostSalesFraction < 0 || model.backorderFraction + model.lostSalesFraction > 1.000001 {
            diagnostics.append(ValidationDiagnostic(severity: .error, code: "inventory.stochastic.shortageFractions.invalid", message: "Shortage fractions must be nonnegative and sum to at most one.", path: "model"))
        }
        let penalty = effectiveShortagePenalty(model)
        if !penalty.isFinite || penalty <= 0 {
            diagnostics.append(ValidationDiagnostic(severity: .error, code: "inventory.stochastic.shortageCost.nonpositive", message: "A positive effective shortage penalty is required.", path: "model"))
        }
        if model.policy == .continuousOrderUpTo && !(model.averageOrderSize.map { $0.isFinite && $0 > 0 } ?? false) {
            diagnostics.append(ValidationDiagnostic(severity: .error, code: "inventory.stochastic.averageOrderSize.invalid", message: "Continuous order-up-to models require a positive average order size.", path: "model.averageOrderSize"))
        }
        if (model.policy == .periodicFixedOrderInterval || model.policy == .periodicOptionalReplenishment) && !(model.reviewCost.map { $0.isFinite && $0 >= 0 } ?? false) {
            diagnostics.append(ValidationDiagnostic(severity: .error, code: "inventory.stochastic.reviewCost.invalid", message: "Periodic review models require a nonnegative review cost.", path: "model.reviewCost"))
        }
        if !diagnostics.contains(where: { $0.severity == .error }) {
            diagnostics.append(ValidationDiagnostic(severity: .info, code: "inventory.stochastic.valid", message: "Stochastic inventory model is valid"))
        }
        return diagnostics
    }

    public static func validate(_ model: StochasticInventoryModel) throws {
        try throwFirstInventoryValidationError(diagnostics(for: model))
    }
}

public enum StochasticInventorySolver {
    public static func solve(_ model: StochasticInventoryModel) throws -> StochasticInventorySolution {
        try StochasticInventoryValidator.validate(model)
        switch model.policy {
        case .continuousFixedOrderQuantity:
            return continuous(model, fixedQuantity: nil, orderUpTo: false)
        case .continuousOrderUpTo:
            return continuous(model, fixedQuantity: model.averageOrderSize, orderUpTo: true)
        case .periodicFixedOrderInterval:
            return periodicFixedInterval(model)
        case .periodicOptionalReplenishment:
            return periodicOptional(model)
        }
    }

    private static func continuous(_ model: StochasticInventoryModel, fixedQuantity: Double?, orderUpTo: Bool) -> StochasticInventorySolution {
        let penalty = effectiveShortagePenalty(model)
        let mean = model.meanDemand * model.leadTime
        let deviation = model.demandStandardDeviation * sqrt(model.leadTime)
        var quantity = fixedQuantity ?? sqrt(2 * model.meanDemand * model.setupCost / model.holdingCost)
        var values = normalPolicy(quantity: quantity, mean: mean, deviation: deviation, holding: model.holdingCost, penalty: penalty, demand: model.meanDemand)
        if fixedQuantity == nil {
            for _ in 0..<100 {
                let updated = sqrt(2 * model.meanDemand * (model.setupCost + penalty * values.shortage) / model.holdingCost)
                if abs(updated - quantity) < 1e-10 { quantity = updated; break }
                quantity = updated
                values = normalPolicy(quantity: quantity, mean: mean, deviation: deviation, holding: model.holdingCost, penalty: penalty, demand: model.meanDemand)
            }
            values = normalPolicy(quantity: quantity, mean: mean, deviation: deviation, holding: model.holdingCost, penalty: penalty, demand: model.meanDemand)
        }
        let cycles = model.meanDemand / quantity
        let review = 0.0
        let costs = costs(model: model, quantity: quantity, safety: values.safety, shortage: values.shortage, cycles: cycles, reviewCost: review)
        return StochasticInventorySolution(policy: model.policy, orderQuantity: quantity, reorderPoint: values.level, orderUpToLevel: orderUpTo ? values.level + quantity : nil, reviewInterval: nil, protectionPeriod: model.leadTime, protectionDemandMean: mean, protectionDemandStandardDeviation: deviation, safetyStock: values.safety, serviceLevel: values.service, expectedShortagePerCycle: values.shortage, expectedCyclesPerTimeUnit: cycles, costs: costs)
    }

    private static func periodicFixedInterval(_ model: StochasticInventoryModel) -> StochasticInventorySolution {
        let reviewCost = model.reviewCost ?? 0
        let interval = sqrt(2 * (model.setupCost + reviewCost) / (model.holdingCost * model.meanDemand))
        let quantity = model.meanDemand * interval
        let protection = model.leadTime + interval
        let mean = model.meanDemand * protection
        let deviation = model.demandStandardDeviation * sqrt(protection)
        let values = normalPolicy(quantity: quantity, mean: mean, deviation: deviation, holding: model.holdingCost, penalty: effectiveShortagePenalty(model), demand: model.meanDemand)
        let cycles = 1 / interval
        let costs = costs(model: model, quantity: quantity, safety: values.safety, shortage: values.shortage, cycles: cycles, reviewCost: reviewCost * cycles)
        return StochasticInventorySolution(policy: model.policy, orderQuantity: quantity, reorderPoint: nil, orderUpToLevel: values.level, reviewInterval: interval, protectionPeriod: protection, protectionDemandMean: mean, protectionDemandStandardDeviation: deviation, safetyStock: values.safety, serviceLevel: values.service, expectedShortagePerCycle: values.shortage, expectedCyclesPerTimeUnit: cycles, costs: costs)
    }

    private static func periodicOptional(_ model: StochasticInventoryModel) -> StochasticInventorySolution {
        let reviewCost = model.reviewCost ?? 0
        let interval = reviewCost > 0 ? sqrt(2 * reviewCost / (model.holdingCost * model.meanDemand)) : 1 / model.meanDemand
        let quantity = sqrt(2 * model.meanDemand * model.setupCost / model.holdingCost)
        let protection = model.leadTime + interval
        let mean = model.meanDemand * protection
        let deviation = model.demandStandardDeviation * sqrt(protection)
        let values = normalPolicy(quantity: quantity, mean: mean, deviation: deviation, holding: model.holdingCost, penalty: effectiveShortagePenalty(model), demand: model.meanDemand)
        let orderCycles = model.meanDemand / quantity
        let reviewCycles = 1 / interval
        let costs = costs(model: model, quantity: quantity, safety: values.safety, shortage: values.shortage, cycles: orderCycles, reviewCost: reviewCost * reviewCycles)
        return StochasticInventorySolution(policy: model.policy, orderQuantity: quantity, reorderPoint: values.level, orderUpToLevel: values.level + quantity, reviewInterval: interval, protectionPeriod: protection, protectionDemandMean: mean, protectionDemandStandardDeviation: deviation, safetyStock: values.safety, serviceLevel: values.service, expectedShortagePerCycle: values.shortage, expectedCyclesPerTimeUnit: orderCycles, costs: costs)
    }

    private static func normalPolicy(quantity: Double, mean: Double, deviation: Double, holding: Double, penalty: Double, demand: Double) -> (level: Double, safety: Double, service: Double, shortage: Double) {
        let tail = min(0.999999, max(0.000001, holding * quantity / (penalty * demand)))
        let service = 1 - tail
        let z = inverseNormal(service)
        let shortage = deviation * (normalDensity(z) - z * tail)
        return (mean + z * deviation, z * deviation, service, max(0, shortage))
    }

    private static func costs(model: StochasticInventoryModel, quantity: Double, safety: Double, shortage: Double, cycles: Double, reviewCost: Double) -> StochasticInventoryCostBreakdown {
        let ordering = model.setupCost * cycles
        let holding = model.holdingCost * max(0, quantity / 2 + safety)
        let shortageCost = effectiveShortagePenalty(model) * shortage * cycles + (model.fixedShortageCost ?? 0) * cycles * max(0, 1 - normalCDF(safety / max(model.demandStandardDeviation * sqrt(max(model.leadTime, 1e-12)), 1e-12)))
        let acquisition = model.acquisitionCost * model.meanDemand
        let relevant = ordering + reviewCost + holding + shortageCost
        return StochasticInventoryCostBreakdown(orderingCost: ordering, reviewCost: reviewCost, holdingCost: holding, expectedShortageCost: shortageCost, acquisitionCost: acquisition, totalRelevantCost: relevant, totalCost: relevant + acquisition)
    }

    private static func normalDensity(_ z: Double) -> Double { exp(-0.5 * z * z) / sqrt(2 * Double.pi) }
    private static func normalCDF(_ z: Double) -> Double { 0.5 * (1 + erf(z / sqrt(2))) }
    private static func inverseNormal(_ p: Double) -> Double {
        let a = [-39.6968302866538, 220.946098424521, -275.928510446969, 138.357751867269, -30.6647980661472, 2.50662827745924]
        let b = [-54.4760987982241, 161.585836858041, -155.698979859887, 66.8013118877197, -13.2806815528857]
        let c = [-0.00778489400243029, -0.322396458041136, -2.40075827716184, -2.54973253934373, 4.37466414146497, 2.93816398269878]
        let d = [0.00778469570904146, 0.32246712907004, 2.445134137143, 3.75440866190742]
        if p < 0.02425 { let q = sqrt(-2 * log(p)); return (((((c[0]*q+c[1])*q+c[2])*q+c[3])*q+c[4])*q+c[5])/((((d[0]*q+d[1])*q+d[2])*q+d[3])*q+1) }
        if p > 0.97575 { return -inverseNormal(1 - p) }
        let q = p - 0.5, r = q * q
        return (((((a[0]*r+a[1])*r+a[2])*r+a[3])*r+a[4])*r+a[5])*q/(((((b[0]*r+b[1])*r+b[2])*r+b[3])*r+b[4])*r+1)
    }
}

private func effectiveShortagePenalty(_ model: StochasticInventoryModel) -> Double {
    model.backorderFraction * (model.backorderCost ?? 0) + model.lostSalesFraction * (model.lostSalesCost ?? 0)
}

public extension WinQSBInventoryParser {
    static func parseStochasticInventory(from data: Data) throws -> StochasticInventoryModel {
        guard let text = data.legacyLatin1String else { throw InventoryModelError.unsupportedFormat }
        let rows = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").split(separator: "\n", omittingEmptySubsequences: true).map { $0.split(separator: "\t", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } }
        guard let metadata = rows.first, metadata.count >= 5, metadata[0] == "ITS", let mode = Int(metadata[3]), (4...7).contains(mode) else { throw InventoryModelError.unsupportedFormat }
        let entries = Dictionary(uniqueKeysWithValues: rows.dropFirst(2).filter { $0.count >= 2 && !$0[0].hasPrefix("(Not used)") }.map { ($0[0].lowercased(), $0[1]) })
        func required(_ key: String) throws -> Double { guard let raw = entries[key], let value = Double(raw), value.isFinite else { throw InventoryModelError.invalidNumericValue(entries[key] ?? key) }; return value }
        func optional(_ key: String) throws -> Double? { guard let raw = entries[key], !raw.isEmpty, raw.lowercased() != "m" else { return nil }; guard let value = Double(raw), value.isFinite else { throw InventoryModelError.invalidNumericValue(raw) }; return value }
        let policy: StochasticInventoryPolicy = switch mode {
        case 4: .continuousFixedOrderQuantity
        case 5: .continuousOrderUpTo
        case 6: .periodicFixedOrderInterval
        default: .periodicOptionalReplenishment
        }
        let model = StochasticInventoryModel(title: metadata[1], timeUnit: metadata[2], policy: policy, demandDistribution: entries["demand distribution (in year)"] ?? "", meanDemand: try required("mean (u)"), demandStandardDeviation: try required("standard deviation (s>0)"), setupCost: try required("order or setup cost"), acquisitionCost: try required("unit acquisition cost"), holdingCost: try required("unit holding cost per year"), backorderFraction: (try optional("estimated % of shortage will be backordered") ?? 0) / 100, backorderCost: try optional("unit backorder cost"), lostSalesFraction: (try optional("estimated % of shortage will be lost") ?? 0) / 100, lostSalesCost: try optional("unit lost-sales cost"), fixedShortageCost: try optional("fixed cost if shortage occurs"), leadTimeDistribution: entries["lead time distribution (in year)"] ?? "", leadTime: try required("constant value"), averageOrderSize: try optional("average order size"), reviewCost: try optional("review cost per review"))
        try StochasticInventoryValidator.validate(model)
        return model
    }
}
