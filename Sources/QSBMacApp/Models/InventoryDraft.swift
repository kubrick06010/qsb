import Foundation
import QSBCore

enum InventoryDraftError: Error, Equatable, CustomStringConvertible {
    case emptyTitle
    case invalidNumber(path: String, value: String)
    case emptyName(path: String)
    case emptyRows(path: String)
    case dimension(path: String)

    var path: String {
        switch self {
        case .emptyTitle: "title"
        case .invalidNumber(let path, _), .emptyName(let path), .emptyRows(let path), .dimension(let path): path
        }
    }

    var message: String {
        switch self {
        case .emptyTitle: "Enter a model title."
        case .invalidNumber(let path, let value): "Enter a finite number for \(path) (received '\(value)')."
        case .emptyName(let path): "Enter a name for \(path)."
        case .emptyRows(let path): "Add at least one row to \(path)."
        case .dimension(let path): "The editor data is dimensionally inconsistent at \(path)."
        }
    }

    var description: String { message }
}

struct InventoryDiscountBreakDraft: Equatable, Sendable {
    var minimumQuantity: String
    var discountPercent: String

    init(minimumQuantity: String = "0", discountPercent: String = "0") {
        self.minimumQuantity = minimumQuantity
        self.discountPercent = discountPercent
    }

    init(_ break: QuantityDiscountBreak) {
        minimumQuantity = InventoryDraft.format(`break`.minimumQuantity)
        discountPercent = InventoryDraft.format(`break`.discountPercent)
    }
}

struct InventoryLotSizingPeriodDraft: Equatable, Sendable {
    var name: String
    var demand: String
    var setupCost: String
    var unitVariableCost: String
    var unitHoldingCost: String
    var unitBackorderCost: String

    init(name: String = "Period 1", demand: String = "0", setupCost: String = "0", unitVariableCost: String = "0", unitHoldingCost: String = "0", unitBackorderCost: String = "0") {
        self.name = name
        self.demand = demand
        self.setupCost = setupCost
        self.unitVariableCost = unitVariableCost
        self.unitHoldingCost = unitHoldingCost
        self.unitBackorderCost = unitBackorderCost
    }

    init(_ period: LotSizingPeriod) {
        name = period.name
        demand = String(period.demand)
        setupCost = InventoryDraft.format(period.setupCost)
        unitVariableCost = InventoryDraft.format(period.unitVariableCost)
        unitHoldingCost = InventoryDraft.format(period.unitHoldingCost)
        unitBackorderCost = InventoryDraft.format(period.unitBackorderCost)
    }
}

struct InventoryEOQDraft: Equatable, Sendable {
    var title: String
    var timeUnit: String
    var demand: String
    var setupCost: String
    var holdingCost: String
    var shortageCost: String
    var replenishmentRate: String
    var leadTime: String
    var acquisitionCost: String
    var knownOrderQuantity: String

    init(title: String = "New EOQ Model", timeUnit: String = "year", demand: String = "1000", setupCost: String = "100", holdingCost: String = "2", shortageCost: String = "", replenishmentRate: String = "", leadTime: String = "", acquisitionCost: String = "", knownOrderQuantity: String = "") {
        self.title = title; self.timeUnit = timeUnit; self.demand = demand; self.setupCost = setupCost
        self.holdingCost = holdingCost; self.shortageCost = shortageCost; self.replenishmentRate = replenishmentRate
        self.leadTime = leadTime; self.acquisitionCost = acquisitionCost; self.knownOrderQuantity = knownOrderQuantity
    }

    init(_ model: EOQModel) {
        title = model.title; timeUnit = model.timeUnit; demand = InventoryDraft.format(model.demand)
        setupCost = InventoryDraft.format(model.setupCost); holdingCost = InventoryDraft.format(model.holdingCost)
        shortageCost = model.shortageCost.map(InventoryDraft.format) ?? ""
        replenishmentRate = model.replenishmentRate.map(InventoryDraft.format) ?? ""
        leadTime = model.leadTime.map(InventoryDraft.format) ?? ""
        acquisitionCost = model.acquisitionCost.map(InventoryDraft.format) ?? ""
        knownOrderQuantity = model.knownOrderQuantity.map(InventoryDraft.format) ?? ""
    }
}

struct InventoryQuantityDiscountDraft: Equatable, Sendable {
    var title: String
    var timeUnit: String
    var demand: String
    var setupCost: String
    var holdingCost: String
    var acquisitionCost: String
    var discountBreaks: [InventoryDiscountBreakDraft]
    var knownOrderQuantity: String

    init(title: String = "New Quantity Discount Model", timeUnit: String = "year", demand: String = "1000", setupCost: String = "100", holdingCost: String = "2", acquisitionCost: String = "10", discountBreaks: [InventoryDiscountBreakDraft] = [InventoryDiscountBreakDraft()], knownOrderQuantity: String = "") {
        self.title = title; self.timeUnit = timeUnit; self.demand = demand; self.setupCost = setupCost
        self.holdingCost = holdingCost; self.acquisitionCost = acquisitionCost; self.discountBreaks = discountBreaks
        self.knownOrderQuantity = knownOrderQuantity
    }

    init(_ model: QuantityDiscountEOQModel) {
        title = model.title; timeUnit = model.timeUnit; demand = InventoryDraft.format(model.demand)
        setupCost = InventoryDraft.format(model.setupCost); holdingCost = InventoryDraft.format(model.holdingCost)
        acquisitionCost = InventoryDraft.format(model.acquisitionCost)
        discountBreaks = model.discountBreaks.map(InventoryDiscountBreakDraft.init)
        knownOrderQuantity = model.knownOrderQuantity.map(InventoryDraft.format) ?? ""
    }
}

struct InventoryNewsboyDraft: Equatable, Sendable {
    var title: String
    var timeUnit: String
    var demandDistribution: String
    var meanDemand: String
    var standardDeviation: String
    var setupCost: String
    var acquisitionCost: String
    var sellingPrice: String
    var shortageCost: String
    var salvageValue: String
    var initialInventory: String
    var knownOrderQuantity: String
    var desiredServiceLevelPercent: String

    init(title: String = "New Newsboy Model", timeUnit: String = "day", demandDistribution: String = "Normal", meanDemand: String = "100", standardDeviation: String = "15", setupCost: String = "0", acquisitionCost: String = "5", sellingPrice: String = "10", shortageCost: String = "1", salvageValue: String = "2", initialInventory: String = "", knownOrderQuantity: String = "", desiredServiceLevelPercent: String = "") {
        self.title = title; self.timeUnit = timeUnit; self.demandDistribution = demandDistribution; self.meanDemand = meanDemand
        self.standardDeviation = standardDeviation; self.setupCost = setupCost; self.acquisitionCost = acquisitionCost
        self.sellingPrice = sellingPrice; self.shortageCost = shortageCost; self.salvageValue = salvageValue
        self.initialInventory = initialInventory; self.knownOrderQuantity = knownOrderQuantity
        self.desiredServiceLevelPercent = desiredServiceLevelPercent
    }

    init(_ model: NewsboyModel) {
        title = model.title; timeUnit = model.timeUnit; demandDistribution = model.demandDistribution
        meanDemand = InventoryDraft.format(model.meanDemand); standardDeviation = InventoryDraft.format(model.standardDeviation)
        setupCost = InventoryDraft.format(model.setupCost); acquisitionCost = InventoryDraft.format(model.acquisitionCost)
        sellingPrice = InventoryDraft.format(model.sellingPrice); shortageCost = InventoryDraft.format(model.shortageCost)
        salvageValue = InventoryDraft.format(model.salvageValue)
        initialInventory = model.initialInventory.map(InventoryDraft.format) ?? ""
        knownOrderQuantity = model.knownOrderQuantity.map(InventoryDraft.format) ?? ""
        desiredServiceLevelPercent = model.desiredServiceLevelPercent.map(InventoryDraft.format) ?? ""
    }
}

struct InventoryLotSizingDraft: Equatable, Sendable {
    var title: String
    var timeUnit: String
    var periods: [InventoryLotSizingPeriodDraft]

    init(title: String = "New Lot Sizing Model", timeUnit: String = "month", periods: [InventoryLotSizingPeriodDraft] = [InventoryLotSizingPeriodDraft()]) {
        self.title = title; self.timeUnit = timeUnit; self.periods = periods
    }

    init(_ model: LotSizingModel) {
        title = model.title; timeUnit = model.timeUnit; periods = model.periods.map(InventoryLotSizingPeriodDraft.init)
    }
}

enum InventoryDraft: Equatable, Sendable {
    case eoq(InventoryEOQDraft)
    case quantityDiscount(InventoryQuantityDiscountDraft)
    case newsboy(InventoryNewsboyDraft)
    case lotSizing(InventoryLotSizingDraft)
    case stochasticReview(StochasticInventoryModel)

    static func blank(_ kind: InventoryProblemKind) -> Self {
        switch kind {
        case .eoq: .eoq(InventoryEOQDraft())
        case .quantityDiscountEOQ: .quantityDiscount(InventoryQuantityDiscountDraft())
        case .newsboy: .newsboy(InventoryNewsboyDraft())
        case .lotSizing: .lotSizing(InventoryLotSizingDraft())
        case .stochasticReview:
            .stochasticReview(StochasticInventoryModel(
                title: "New Stochastic Inventory Model", timeUnit: "year", policy: .continuousFixedOrderQuantity,
                demandDistribution: "Normal", meanDemand: 100, demandStandardDeviation: 10, setupCost: 100,
                acquisitionCost: 1, holdingCost: 1, backorderFraction: 1, backorderCost: 1,
                lostSalesFraction: 0, lostSalesCost: nil, fixedShortageCost: nil,
                leadTimeDistribution: "Constant", leadTime: 1, averageOrderSize: nil, reviewCost: nil
            ))
        }
    }

    init(_ envelope: InventoryModelEnvelope) {
        switch envelope {
        case .eoq(let model): self = .eoq(InventoryEOQDraft(model))
        case .quantityDiscountEOQ(let model): self = .quantityDiscount(InventoryQuantityDiscountDraft(model))
        case .newsboy(let model): self = .newsboy(InventoryNewsboyDraft(model))
        case .lotSizing(let model): self = .lotSizing(InventoryLotSizingDraft(model))
        case .stochasticReview(let model): self = .stochasticReview(model)
        }
    }

    var kind: InventoryProblemKind {
        switch self {
        case .eoq: .eoq
        case .quantityDiscount: .quantityDiscountEOQ
        case .newsboy: .newsboy
        case .lotSizing: .lotSizing
        case .stochasticReview: .stochasticReview
        }
    }

    func makeModel() throws -> InventoryModelEnvelope {
        switch self {
        case .eoq(let draft): .eoq(try Self.makeEOQ(draft))
        case .quantityDiscount(let draft): .quantityDiscountEOQ(try Self.makeQuantityDiscount(draft))
        case .newsboy(let draft): .newsboy(try Self.makeNewsboy(draft))
        case .lotSizing(let draft): .lotSizing(try Self.makeLotSizing(draft))
        case .stochasticReview(let model): .stochasticReview(model)
        }
    }

    func draftDiagnostics() -> [ValidationDiagnostic] {
        do {
            let model = try makeModel()
            return InventoryValidator.diagnostics(for: model)
        } catch let error as InventoryDraftError {
            let code = "inventory.draft.\(error.path.replacingOccurrences(of: ".", with: "_"))"
            return [ValidationDiagnostic(severity: .error, code: code, message: error.message, path: error.path)]
        } catch {
            return [ValidationDiagnostic(severity: .error, code: "inventory.draft.invalid", message: error.localizedDescription, path: nil)]
        }
    }

    mutating func addDiscountBreak() {
        guard case .quantityDiscount(var draft) = self else { return }
        draft.discountBreaks.append(InventoryDiscountBreakDraft(minimumQuantity: "0", discountPercent: "0"))
        self = .quantityDiscount(draft)
    }

    mutating func removeDiscountBreak(at index: Int) {
        guard case .quantityDiscount(var draft) = self, draft.discountBreaks.indices.contains(index) else { return }
        draft.discountBreaks.remove(at: index)
        self = .quantityDiscount(draft)
    }

    mutating func addLotSizingPeriod() {
        guard case .lotSizing(var draft) = self else { return }
        draft.periods.append(InventoryLotSizingPeriodDraft(name: "Period \(draft.periods.count + 1)"))
        self = .lotSizing(draft)
    }

    mutating func removeLotSizingPeriod(at index: Int) {
        guard case .lotSizing(var draft) = self, draft.periods.indices.contains(index) else { return }
        draft.periods.remove(at: index)
        self = .lotSizing(draft)
    }

    private static func makeEOQ(_ draft: InventoryEOQDraft) throws -> EOQModel {
        EOQModel(title: try title(draft.title), timeUnit: draft.timeUnit, demand: try number(draft.demand, path: "demand"), setupCost: try number(draft.setupCost, path: "setupCost"), holdingCost: try number(draft.holdingCost, path: "holdingCost"), shortageCost: try optionalNumber(draft.shortageCost, path: "shortageCost"), replenishmentRate: try optionalNumber(draft.replenishmentRate, path: "replenishmentRate"), leadTime: try optionalNumber(draft.leadTime, path: "leadTime"), acquisitionCost: try optionalNumber(draft.acquisitionCost, path: "acquisitionCost"), knownOrderQuantity: try optionalNumber(draft.knownOrderQuantity, path: "knownOrderQuantity"))
    }

    private static func makeQuantityDiscount(_ draft: InventoryQuantityDiscountDraft) throws -> QuantityDiscountEOQModel {
        guard !draft.discountBreaks.isEmpty else { throw InventoryDraftError.emptyRows(path: "discountBreaks") }
        let breaks = try draft.discountBreaks.enumerated().map { index, item in
            QuantityDiscountBreak(minimumQuantity: try number(item.minimumQuantity, path: "discountBreaks.\(index).minimumQuantity"), discountPercent: try number(item.discountPercent, path: "discountBreaks.\(index).discountPercent"))
        }
        return QuantityDiscountEOQModel(title: try title(draft.title), timeUnit: draft.timeUnit, demand: try number(draft.demand, path: "demand"), setupCost: try number(draft.setupCost, path: "setupCost"), holdingCost: try number(draft.holdingCost, path: "holdingCost"), acquisitionCost: try number(draft.acquisitionCost, path: "acquisitionCost"), discountBreaks: breaks, knownOrderQuantity: try optionalNumber(draft.knownOrderQuantity, path: "knownOrderQuantity"))
    }

    private static func makeNewsboy(_ draft: InventoryNewsboyDraft) throws -> NewsboyModel {
        NewsboyModel(title: try title(draft.title), timeUnit: draft.timeUnit, demandDistribution: draft.demandDistribution, meanDemand: try number(draft.meanDemand, path: "meanDemand"), standardDeviation: try number(draft.standardDeviation, path: "standardDeviation"), setupCost: try number(draft.setupCost, path: "setupCost"), acquisitionCost: try number(draft.acquisitionCost, path: "acquisitionCost"), sellingPrice: try number(draft.sellingPrice, path: "sellingPrice"), shortageCost: try number(draft.shortageCost, path: "shortageCost"), salvageValue: try number(draft.salvageValue, path: "salvageValue"), initialInventory: try optionalNumber(draft.initialInventory, path: "initialInventory"), knownOrderQuantity: try optionalNumber(draft.knownOrderQuantity, path: "knownOrderQuantity"), desiredServiceLevelPercent: try optionalNumber(draft.desiredServiceLevelPercent, path: "desiredServiceLevelPercent"))
    }

    private static func makeLotSizing(_ draft: InventoryLotSizingDraft) throws -> LotSizingModel {
        guard !draft.periods.isEmpty else { throw InventoryDraftError.emptyRows(path: "periods") }
        let periods = try draft.periods.enumerated().map { index, item in
            let path = "periods.\(index)"
            guard !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw InventoryDraftError.emptyName(path: "\(path).name") }
            return LotSizingPeriod(name: item.name, demand: try integer(item.demand, path: "\(path).demand"), setupCost: try number(item.setupCost, path: "\(path).setupCost"), unitVariableCost: try number(item.unitVariableCost, path: "\(path).unitVariableCost"), unitHoldingCost: try number(item.unitHoldingCost, path: "\(path).unitHoldingCost"), unitBackorderCost: try number(item.unitBackorderCost, path: "\(path).unitBackorderCost"))
        }
        return LotSizingModel(title: try title(draft.title), timeUnit: draft.timeUnit, periods: periods)
    }

    private static func title(_ value: String) throws -> String {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw InventoryDraftError.emptyTitle }
        return value
    }

    private static func number(_ value: String, path: String) throws -> Double {
        guard let number = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)), number.isFinite else { throw InventoryDraftError.invalidNumber(path: path, value: value) }
        return number
    }

    private static func optionalNumber(_ value: String, path: String) throws -> Double? {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : try number(value, path: path)
    }

    private static func integer(_ value: String, path: String) throws -> Int {
        let number = try number(value, path: path)
        let rounded = number.rounded()
        guard abs(number - rounded) < 1e-8 else { throw InventoryDraftError.invalidNumber(path: path, value: value) }
        return Int(rounded)
    }

    fileprivate static func format(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 1e-10 { return String(Int(rounded)) }
        return String(format: "%.6g", value)
    }
}
