import Foundation
import Testing
@testable import QSBCore

@Test func parsesAndSolvesWinQSBEOQFixture() throws {
    let url = legacyFixtureURL("EOQ.IT_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let model = try WinQSBInventoryParser.parseEOQ(from: expanded)
    let solution = try EOQSolver.solve(model)

    #expect(model.title == "QSB209")
    #expect(model.timeUnit == "year")
    #expect(model.demand == 600)
    #expect(model.setupCost == 50)
    #expect(model.holdingCost == 60)
    #expect(model.acquisitionCost == 300)
    #expect(model.knownOrderQuantity == 60)
    #expect(abs(solution.economicOrderQuantity - 31.622776601683793) < 1e-8)
    #expect(abs(solution.optimum.setupCost - 948.6832980505138) < 1e-8)
    #expect(abs(solution.optimum.holdingCost - 948.6832980505138) < 1e-8)
    #expect(abs(solution.optimum.totalRelevantCost - 1897.3665961010277) < 1e-8)
    #expect(abs(solution.optimum.totalCost - 181897.366596101) < 1e-6)
    #expect(abs((solution.knownQuantity?.totalRelevantCost ?? 0) - 2300) < 1e-8)
    #expect(abs((solution.knownQuantity?.totalCost ?? 0) - 182300) < 1e-8)
}

@Test func parsesAndSolvesWinQSBQuantityDiscountEOQFixture() throws {
    let url = legacyFixtureURL("DISCOUNT.IT_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let model = try WinQSBInventoryParser.parseQuantityDiscountEOQ(from: expanded)
    let solution = try QuantityDiscountEOQSolver.solve(model)

    #expect(model.title == "Inventory Problem")
    #expect(model.demand == 600)
    #expect(model.setupCost == 50)
    #expect(model.holdingCost == 60)
    #expect(model.acquisitionCost == 300)
    #expect(model.discountBreaks == [
        QuantityDiscountBreak(minimumQuantity: 50, discountPercent: 2),
        QuantityDiscountBreak(minimumQuantity: 80, discountPercent: 5)
    ])
    #expect(abs(solution.unconstrainedEOQ - 31.622776601683793) < 1e-8)
    #expect(solution.candidates.count == 3)
    #expect(abs(solution.candidates[0].cost.totalCost - 181897.36659610103) < 1e-6)
    #expect(abs(solution.candidates[1].cost.totalCost - 178500) < 1e-8)
    #expect(abs(solution.candidates[2].cost.totalCost - 173775) < 1e-8)
    #expect(solution.optimum.minimumQuantity == 80)
    #expect(solution.optimum.discountPercent == 5)
    #expect(solution.optimum.unitAcquisitionCost == 285)
    #expect(solution.optimum.cost.orderQuantity == 80)
    #expect(abs(solution.optimum.cost.totalRelevantCost - 2775) < 1e-8)
    #expect(abs(solution.optimum.cost.totalCost - 173775) < 1e-8)
}

@Test func parsesAndSolvesWinQSBNewsboyFixture() throws {
    let url = legacyFixtureURL("NEWSBOY.IT_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let model = try WinQSBInventoryParser.parseNewsboy(from: expanded)
    let solution = try NewsboySolver.solve(model)

    #expect(model.title == "Inventory Problem")
    #expect(model.timeUnit == "year")
    #expect(model.demandDistribution == "Normal")
    #expect(model.meanDemand == 1000)
    #expect(model.standardDeviation == 100)
    #expect(model.setupCost == 300)
    #expect(model.acquisitionCost == 20)
    #expect(model.sellingPrice == 30)
    #expect(model.shortageCost == 10)
    #expect(model.salvageValue == 15)
    #expect(abs(solution.criticalRatio - 0.8) < 1e-8)
    #expect(abs(solution.optimum.orderQuantity - 1084.1621233572914) < 1e-5)
    #expect(abs(solution.optimum.serviceLevel - 0.8) < 1e-7)
    #expect(abs(solution.optimum.expectedSales - 988.8362326306775) < 1e-5)
    #expect(abs(solution.optimum.expectedLeftover - 95.32589072661399) < 1e-5)
    #expect(abs(solution.optimum.expectedShortage - 11.163767369322542) < 1e-5)
    #expect(abs(solution.optimum.expectedProfit - 9000.095198980482) < 1e-5)
}

@Test func parsesAndSolvesWinQSBLotSizingFixture() throws {
    let url = legacyFixtureURL("LOTSIZE.IT_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let model = try WinQSBInventoryParser.parseLotSizing(from: expanded)
    let solution = try LotSizingSolver.solve(model)

    #expect(model.title == "Inventory Problem")
    #expect(model.timeUnit == "month")
    #expect(model.periods == [
        LotSizingPeriod(name: "1", demand: 20, setupCost: 30, unitVariableCost: 3, unitHoldingCost: 5, unitBackorderCost: 1),
        LotSizingPeriod(name: "2", demand: 30, setupCost: 40, unitVariableCost: 3, unitHoldingCost: 2, unitBackorderCost: 1),
        LotSizingPeriod(name: "3", demand: 40, setupCost: 30, unitVariableCost: 4, unitHoldingCost: 2, unitBackorderCost: 1),
        LotSizingPeriod(name: "4", demand: 30, setupCost: 50, unitVariableCost: 4, unitHoldingCost: 1, unitBackorderCost: 1),
        LotSizingPeriod(name: "5", demand: 30, setupCost: 40, unitVariableCost: 4.5, unitHoldingCost: 2, unitBackorderCost: 1),
        LotSizingPeriod(name: "6", demand: 35, setupCost: 30, unitVariableCost: 4.5, unitHoldingCost: 1, unitBackorderCost: 1)
    ])
    #expect(abs(solution.totalCost - 907.5) < 1e-8)
    #expect(solution.decisions == [
        LotSizingDecision(period: "1", demand: 20, productionQuantity: 0, endingInventory: -20, setupCost: 0, variableCost: 0, holdingCost: 0, backorderCost: 20, totalCost: 20),
        LotSizingDecision(period: "2", demand: 30, productionQuantity: 50, endingInventory: 0, setupCost: 40, variableCost: 150, holdingCost: 0, backorderCost: 0, totalCost: 190),
        LotSizingDecision(period: "3", demand: 40, productionQuantity: 40, endingInventory: 0, setupCost: 30, variableCost: 160, holdingCost: 0, backorderCost: 0, totalCost: 190),
        LotSizingDecision(period: "4", demand: 30, productionQuantity: 60, endingInventory: 30, setupCost: 50, variableCost: 240, holdingCost: 30, backorderCost: 0, totalCost: 320),
        LotSizingDecision(period: "5", demand: 30, productionQuantity: 0, endingInventory: 0, setupCost: 0, variableCost: 0, holdingCost: 0, backorderCost: 0, totalCost: 0),
        LotSizingDecision(period: "6", demand: 35, productionQuantity: 35, endingInventory: 0, setupCost: 30, variableCost: 157.5, holdingCost: 0, backorderCost: 0, totalCost: 187.5)
    ])
}

@Test func roundTripsNormalizedInventoryModelsAndSolutions() throws {
    let fixtureNames = ["EOQ.IT_", "DISCOUNT.IT_", "NEWSBOY.IT_", "LOTSIZE.IT_", "CRSQ.IT_", "CRSS.IT_", "PRRS.IT_", "PRRSS.IT_"]
    let expectedKinds: [InventoryProblemKind] = [.eoq, .quantityDiscountEOQ, .newsboy, .lotSizing, .stochasticReview, .stochasticReview, .stochasticReview, .stochasticReview]
    let nativeBackend = NativeEducationalInventoryBackend()

    for (fixtureName, expectedKind) in zip(fixtureNames, expectedKinds) {
        let data = try Data(contentsOf: legacyFixtureURL(fixtureName))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let model = try WinQSBInventoryParser.parseModelEnvelope(from: expanded)
        #expect(model.kind == expectedKind)

        let encodedModel = try InventoryModelJSON.encodeModel(model)
        #expect(try InventoryModelJSON.decodeModel(from: encodedModel) == model)

        let solution = try nativeBackend.solve(model)
        #expect(solution.kind == expectedKind)
        let document = nativeBackend.solutionDocument(for: model, solution: solution)
        #expect(document.kind == expectedKind)
        #expect(document.backend.backendKind == .nativeEducational)
        #expect(!document.assumptions.isEmpty)

        let encodedSolution = try InventoryModelJSON.encodeSolutionDocument(document)
        #expect(try InventoryModelJSON.decodeSolutionDocument(from: encodedSolution) == document)
    }
}

@Test func parsesAndSolvesAllWinQSBStochasticInventoryPolicies() throws {
    let fixtures: [(String, StochasticInventoryPolicy)] = [
        ("CRSQ.IT_", .continuousFixedOrderQuantity),
        ("CRSS.IT_", .continuousOrderUpTo),
        ("PRRS.IT_", .periodicFixedOrderInterval),
        ("PRRSS.IT_", .periodicOptionalReplenishment)
    ]
    var solutions: [StochasticInventoryPolicy: StochasticInventorySolution] = [:]
    for (fixture, policy) in fixtures {
        let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL(fixture)))
        let model = try WinQSBInventoryParser.parseStochasticInventory(from: expanded)
        #expect(model.policy == policy)
        #expect(model.meanDemand == 1_000)
        #expect(model.demandStandardDeviation == 100)
        #expect(model.leadTime > 0.08332 && model.leadTime < 0.08334)
        #expect(model.backorderFraction == 1)
        #expect(model.backorderCost == 20)
        solutions[policy] = try StochasticInventorySolver.solve(model)
    }
    let q = try #require(solutions[.continuousFixedOrderQuantity])
    #expect(abs(q.orderQuantity - 155.025984159998) < 1e-6)
    #expect(abs((q.reorderPoint ?? 0) - 124.382959946781) < 1e-6)
    #expect(abs(q.serviceLevel - 0.922487007920001) < 1e-8)
    let s = try #require(solutions[.continuousOrderUpTo])
    #expect(s.orderQuantity == 50)
    #expect(abs((s.orderUpToLevel ?? 0) - 189.912173835284) < 1e-6)
    let periodic = try #require(solutions[.periodicFixedOrderInterval])
    #expect(abs((periodic.reviewInterval ?? 0) - 0.173205080756888) < 1e-8)
    #expect(abs(periodic.orderQuantity - 173.205080756888) < 1e-8)
    let optional = try #require(solutions[.periodicOptionalReplenishment])
    #expect(abs((optional.reviewInterval ?? 0) - 0.1) < 1e-10)
    #expect(abs(optional.orderQuantity - 141.42135623731) < 1e-8)
    #expect(solutions.values.allSatisfy { $0.costs.totalCost > 50_000 && $0.serviceLevel > 0 && $0.serviceLevel < 1 })
}

@Test func validatesStochasticInventoryAssumptionsAndBackendRouting() throws {
    let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("CRSQ.IT_")))
    let model = try WinQSBInventoryParser.parseStochasticInventory(from: expanded)
    let invalid = StochasticInventoryModel(title: model.title, timeUnit: model.timeUnit, policy: model.policy, demandDistribution: "Poisson", meanDemand: model.meanDemand, demandStandardDeviation: model.demandStandardDeviation, setupCost: model.setupCost, acquisitionCost: model.acquisitionCost, holdingCost: model.holdingCost, backorderFraction: model.backorderFraction, backorderCost: model.backorderCost, lostSalesFraction: model.lostSalesFraction, lostSalesCost: model.lostSalesCost, fixedShortageCost: model.fixedShortageCost, leadTimeDistribution: "Variable", leadTime: model.leadTime, averageOrderSize: model.averageOrderSize, reviewCost: model.reviewCost)
    let validate = ValidateOnlyInventoryBackend()
    let report = validate.validationReport(for: invalid)
    #expect(!report.isValid)
    #expect(report.diagnostics.contains { $0.code == "inventory.stochastic.distribution.unsupported" })
    #expect(report.diagnostics.contains { $0.code == "inventory.stochastic.leadTimeDistribution.unsupported" })
    #expect(NativeEducationalInventoryBackend().runMetadata(for: model).exactness == .approximate)
    do {
        _ = try validate.solve(model)
        Issue.record("validateOnly unexpectedly solved a stochastic inventory model")
    } catch {
        #expect(String(describing: error).contains("validateOnly"))
    }
}

@Test func routesInventoryModelsThroughNamedBackends() throws {
    let eoqData = try LegacyCompressedFile.expandedData(
        from: Data(contentsOf: legacyFixtureURL("EOQ.IT_"))
    )
    let discountData = try LegacyCompressedFile.expandedData(
        from: Data(contentsOf: legacyFixtureURL("DISCOUNT.IT_"))
    )
    let newsboyData = try LegacyCompressedFile.expandedData(
        from: Data(contentsOf: legacyFixtureURL("NEWSBOY.IT_"))
    )
    let lotSizingData = try LegacyCompressedFile.expandedData(
        from: Data(contentsOf: legacyFixtureURL("LOTSIZE.IT_"))
    )
    let eoq = try WinQSBInventoryParser.parseEOQ(from: eoqData)
    let discount = try WinQSBInventoryParser.parseQuantityDiscountEOQ(from: discountData)
    let newsboy = try WinQSBInventoryParser.parseNewsboy(from: newsboyData)
    let lotSizing = try WinQSBInventoryParser.parseLotSizing(from: lotSizingData)

    let nativeBackend = NativeEducationalInventoryBackend()
    #expect(nativeBackend.capabilities.backendKind == .nativeEducational)
    #expect(nativeBackend.capabilities.solves)
    #expect(abs(try nativeBackend.solve(eoq).economicOrderQuantity - 31.622776601683793) < 1e-8)
    #expect(abs(try nativeBackend.solve(discount).optimum.cost.orderQuantity - 80) < 1e-8)
    #expect(abs(try nativeBackend.solve(newsboy).criticalRatio - 0.8) < 1e-8)
    #expect(abs(try nativeBackend.solve(lotSizing).totalCost - 907.5) < 1e-8)
    #expect(nativeBackend.runMetadata(for: eoq).exactness == .closedForm)
    #expect(nativeBackend.runMetadata(for: discount).algorithm == "allUnitsDiscountTierEnumeration")
    #expect(nativeBackend.runMetadata(for: newsboy).algorithm == "normalDemandCriticalFractile")
    #expect(nativeBackend.runMetadata(for: lotSizing).exactness == .fixtureScale)

    let validateBackend = ValidateOnlyInventoryBackend()
    #expect(validateBackend.capabilities.backendKind == .validateOnly)
    #expect(!validateBackend.capabilities.solves)
    #expect(validateBackend.validationReport(for: eoq).isValid)
    #expect(validateBackend.validationReport(for: discount).isValid)
    #expect(validateBackend.validationReport(for: newsboy).isValid)
    #expect(validateBackend.validationReport(for: lotSizing).isValid)

    let invalidEOQ = EOQModel(
        title: "Invalid production rate",
        timeUnit: "year",
        demand: 10,
        setupCost: 5,
        holdingCost: 2,
        replenishmentRate: 10
    )
    let invalidReport = validateBackend.validationReport(for: invalidEOQ)
    #expect(!invalidReport.isValid)
    #expect(invalidReport.diagnostics.contains {
        $0.code == "inventory.eoq.replenishmentRate.insufficient" && $0.severity == .error
    })

    do {
        _ = try validateBackend.solve(eoq)
        Issue.record("Expected validateOnly backend to reject EOQ solving")
    } catch {
        #expect(String(describing: error).contains("validateOnly"))
    }

    #expect(InventoryBackends.backend(for: .nativeEducational) != nil)
    #expect(InventoryBackends.backend(for: .validateOnly) != nil)
    #expect(InventoryBackends.backend(for: .externalHighPerformance) == nil)
}

@Test func parsesAndSolvesWinQSBProductionInventoryFixture() throws {
    let url = legacyFixtureURL("PRODINVT.DP_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBDynamicProgrammingParser.parseProductionInventory(from: expanded)
    let solution = try ProductionInventorySolver.solve(problem)

    #expect(problem.title == "QSB P.116")
    #expect(problem.periods.count == 4)
    #expect(problem.periods[0] == ProductionInventoryPeriod(
        name: "January",
        demand: 4,
        productionCapacity: 6,
        storageCapacity: 4,
        setupCost: 500,
        productionUnitCost: 300,
        holdingUnitCost: 100
    ))
    #expect(abs(solution.totalCost - 7080) < 1e-8)
    #expect(solution.decisions == [
        ProductionInventoryDecision(period: "January", beginningInventory: 0, productionQuantity: 5, demand: 4, endingInventory: 1, cost: 2100),
        ProductionInventoryDecision(period: "February", beginningInventory: 1, productionQuantity: 4, demand: 5, endingInventory: 0, cost: 1730),
        ProductionInventoryDecision(period: "March", beginningInventory: 0, productionQuantity: 3, demand: 3, endingInventory: 0, cost: 1250),
        ProductionInventoryDecision(period: "April", beginningInventory: 0, productionQuantity: 4, demand: 4, endingInventory: 0, cost: 2000)
    ])
}

