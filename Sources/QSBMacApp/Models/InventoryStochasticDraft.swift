import Foundation
import QSBCore

struct InventoryStochasticDraft: Equatable, Sendable {
    var title: String
    var timeUnit: String
    var policy: StochasticInventoryPolicy
    var demandDistribution: String
    var meanDemand: String
    var demandStandardDeviation: String
    var setupCost: String
    var acquisitionCost: String
    var holdingCost: String
    var backorderFraction: String
    var backorderCost: String
    var lostSalesFraction: String
    var lostSalesCost: String
    var fixedShortageCost: String
    var leadTimeDistribution: String
    var leadTime: String
    var averageOrderSize: String
    var reviewCost: String

    init(
        title: String = "New Stochastic Inventory Model",
        timeUnit: String = "year",
        policy: StochasticInventoryPolicy = .continuousFixedOrderQuantity,
        demandDistribution: String = "Normal",
        meanDemand: String = "100",
        demandStandardDeviation: String = "10",
        setupCost: String = "100",
        acquisitionCost: String = "1",
        holdingCost: String = "1",
        backorderFraction: String = "1",
        backorderCost: String = "1",
        lostSalesFraction: String = "0",
        lostSalesCost: String = "",
        fixedShortageCost: String = "",
        leadTimeDistribution: String = "Constant",
        leadTime: String = "1",
        averageOrderSize: String = "",
        reviewCost: String = ""
    ) {
        self.title = title; self.timeUnit = timeUnit; self.policy = policy
        self.demandDistribution = demandDistribution; self.meanDemand = meanDemand
        self.demandStandardDeviation = demandStandardDeviation; self.setupCost = setupCost
        self.acquisitionCost = acquisitionCost; self.holdingCost = holdingCost
        self.backorderFraction = backorderFraction; self.backorderCost = backorderCost
        self.lostSalesFraction = lostSalesFraction; self.lostSalesCost = lostSalesCost
        self.fixedShortageCost = fixedShortageCost; self.leadTimeDistribution = leadTimeDistribution
        self.leadTime = leadTime; self.averageOrderSize = averageOrderSize; self.reviewCost = reviewCost
    }

    init(_ model: StochasticInventoryModel) {
        title = model.title; timeUnit = model.timeUnit; policy = model.policy
        demandDistribution = model.demandDistribution; meanDemand = Self.format(model.meanDemand)
        demandStandardDeviation = Self.format(model.demandStandardDeviation); setupCost = Self.format(model.setupCost)
        acquisitionCost = Self.format(model.acquisitionCost); holdingCost = Self.format(model.holdingCost)
        backorderFraction = Self.format(model.backorderFraction); backorderCost = model.backorderCost.map(Self.format) ?? ""
        lostSalesFraction = Self.format(model.lostSalesFraction); lostSalesCost = model.lostSalesCost.map(Self.format) ?? ""
        fixedShortageCost = model.fixedShortageCost.map(Self.format) ?? ""
        leadTimeDistribution = model.leadTimeDistribution; leadTime = Self.format(model.leadTime)
        averageOrderSize = model.averageOrderSize.map(Self.format) ?? ""
        reviewCost = model.reviewCost.map(Self.format) ?? ""
    }

    func makeModel() throws -> StochasticInventoryModel {
        StochasticInventoryModel(
            title: try titleValue(), timeUnit: timeUnit, policy: policy,
            demandDistribution: demandDistribution, meanDemand: try number(meanDemand, path: "meanDemand"),
            demandStandardDeviation: try number(demandStandardDeviation, path: "demandStandardDeviation"),
            setupCost: try number(setupCost, path: "setupCost"), acquisitionCost: try number(acquisitionCost, path: "acquisitionCost"),
            holdingCost: try number(holdingCost, path: "holdingCost"), backorderFraction: try number(backorderFraction, path: "backorderFraction"),
            backorderCost: try optionalNumber(backorderCost, path: "backorderCost"),
            lostSalesFraction: try number(lostSalesFraction, path: "lostSalesFraction"),
            lostSalesCost: try optionalNumber(lostSalesCost, path: "lostSalesCost"),
            fixedShortageCost: try optionalNumber(fixedShortageCost, path: "fixedShortageCost"),
            leadTimeDistribution: leadTimeDistribution, leadTime: try number(leadTime, path: "leadTime"),
            averageOrderSize: try optionalNumber(averageOrderSize, path: "averageOrderSize"),
            reviewCost: try optionalNumber(reviewCost, path: "reviewCost")
        )
    }

    private func titleValue() throws -> String {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw InventoryDraftError.emptyTitle }
        return value
    }

    private func number(_ text: String, path: String) throws -> Double {
        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)), value.isFinite else {
            throw InventoryDraftError.invalidNumber(path: path, value: text)
        }
        return value
    }

    private func optionalNumber(_ text: String, path: String) throws -> Double? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return try number(text, path: path)
    }

    private static func format(_ value: Double) -> String { String(value) }
}
