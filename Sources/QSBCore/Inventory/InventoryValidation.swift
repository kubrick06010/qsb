import Foundation
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

