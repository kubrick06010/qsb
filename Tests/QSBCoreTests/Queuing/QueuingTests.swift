import Foundation
import Testing
@testable import QSBCore

@Test func parsesAndSimulatesWinQSSTwoServerQueueFixtures() throws {
    let exponential = try legacySimulation("QSS1.QS_")
    let constant = try legacySimulation("QSS2.QS_")
    #expect(exponential.representation == .matrix)
    #expect(exponential.components.count == 4)
    #expect(constant.components.count == 4)
    #expect(exponential.components.filter { $0.kind == .server }.count == 2)
    let first = try DiscreteEventSimulationSolver.solve(exponential, horizon: 100, seed: 7)
    let repeatRun = try DiscreteEventSimulationSolver.solve(exponential, horizon: 100, seed: 7)
    let second = try DiscreteEventSimulationSolver.solve(constant, horizon: 100, seed: 7)
    #expect(first == repeatRun)
    #expect(first.generatedEntities > 50)
    #expect(first.completedEntities > 0)
    #expect(second.serverMetrics.reduce(0) { $0 + $1.completed } > 0)
}

@Test func roundTripsNormalizedQueuingModelsAndBackends() throws {
    let fixtures = ["QUEUE1.QA_", "QUEUE2.QA_"]
    let native = NativeEducationalQueuingBackend()
    let validate = ValidateOnlyQueuingBackend()
    for fixture in fixtures {
        let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL(fixture)))
        let model = try WinQSBQueuingParser.parseModelEnvelope(from: expanded)
        let decoded = try QueuingModelJSON.decodeModel(from: QueuingModelJSON.encodeModel(model))
        #expect(decoded == model)
        #expect(validate.validationReport(for: model).isValid)
        let document = try native.solve(model)
        #expect(document.metrics.utilization > 0)
        #expect(String(decoding: try QueuingModelJSON.encodeSolution(document), as: UTF8.self).contains("metrics"))
    }
    #expect(QueuingBackends.backend(for: .externalHighPerformance) == nil)
}

@Test func parsesAndSolvesWinQSBMM1QueueFixture() throws {
    let url = legacyFixtureURL("QUEUE1.QA_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let model = try WinQSBQueuingParser.parseMM1(from: expanded)
    let solution = try MM1QueueSolver.solve(model)

    #expect(model.title == "Sample M/M/1 Problem")
    #expect(model.timeUnit == "hour")
    #expect(model.serviceRate == 3)
    #expect(model.arrivalRate == 2)
    #expect(abs(solution.utilization - 2.0 / 3.0) < 1e-8)
    #expect(abs(solution.probabilitySystemEmpty - 1.0 / 3.0) < 1e-8)
    #expect(abs(solution.averageNumberInSystem - 2) < 1e-8)
    #expect(abs(solution.averageNumberInQueue - 4.0 / 3.0) < 1e-8)
    #expect(abs(solution.averageTimeInSystem - 1) < 1e-8)
    #expect(abs(solution.averageTimeInQueue - 2.0 / 3.0) < 1e-8)
    #expect(abs((solution.cost?.busyServerCost ?? 0) - 400.0 / 3.0) < 1e-8)
    #expect(abs((solution.cost?.idleServerCost ?? 0) - 200.0 / 3.0) < 1e-8)
    #expect(abs((solution.cost?.customerWaitingCost ?? 0) - 200.0 / 3.0) < 1e-8)
    #expect(abs((solution.cost?.customerBeingServedCost ?? 0) - 100.0 / 3.0) < 1e-8)
    #expect(abs((solution.cost?.totalCost ?? 0) - 300) < 1e-8)
}

@Test func parsesAndSolvesWinQSBFiniteCapacityQueueFixture() throws {
    let url = legacyFixtureURL("QUEUE2.QA_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let model = try WinQSBQueuingParser.parseFiniteCapacity(from: expanded)
    let solution = try FiniteCapacityQueueSolver.solve(model)

    #expect(model.title == "Queuing Sample Problem 2")
    #expect(model.timeUnit == "hour")
    #expect(model.servers == 2)
    #expect(model.serviceDistribution == "Normal")
    #expect(model.meanServiceTime == 0.66666667)
    #expect(model.serviceTimeStandardDeviation == 0.2)
    #expect(model.interarrivalDistribution == "Exponential")
    #expect(model.meanInterarrivalTime == 0.5)
    #expect(model.batchSize == 1)
    #expect(model.queueCapacity == 3)
    #expect(abs(solution.arrivalRate - 2) < 1e-8)
    #expect(abs(solution.serviceRatePerServer - 1.4999999925) < 1e-8)
    #expect(abs(solution.effectiveArrivalRate - 1.8822447082925162) < 1e-8)
    #expect(abs(solution.utilization - 0.6274149059012466) < 1e-8)
    #expect(abs(solution.probabilitySystemEmpty - 0.22355105601214997) < 1e-8)
    #expect(abs(solution.probabilitySystemFull - 0.05887764585374193) < 1e-8)
    #expect(abs(solution.averageNumberInSystem - 1.7405703878879524) < 1e-8)
    #expect(abs(solution.averageNumberInQueue - 0.48574057608545923) < 1e-8)
    #expect(abs(solution.averageNumberBeingServed - 1.2548298118024932) < 1e-8)
    #expect(abs(solution.averageTimeInSystem - 0.9247311894248416) < 1e-8)
    #expect(abs(solution.averageTimeInQueue - 0.25806451942484154) < 1e-8)
    #expect(abs(solution.stateProbabilities.reduce(0, +) - 1) < 1e-8)
    #expect(abs((solution.cost?.busyServerCost ?? 0) - 125.48298118024933) < 1e-8)
    #expect(abs((solution.cost?.idleServerCost ?? 0) - 74.51701881975067) < 1e-8)
    #expect(abs((solution.cost?.customerWaitingCost ?? 0) - 24.28702880427296) < 1e-8)
    #expect(abs((solution.cost?.customerBeingServedCost ?? 0) - 62.74149059012466) < 1e-8)
    #expect(abs((solution.cost?.balkedCustomerCost ?? 0) - 7.065317502449032) < 1e-8)
    #expect(abs((solution.cost?.queueCapacityCost ?? 0) - 45) < 1e-8)
    #expect(abs((solution.cost?.totalCost ?? 0) - 339.09383689684665) < 1e-8)
}

@Test func validatesQueuingModelsWithStructuredDiagnostics() throws {
    let mm1Data = try Data(contentsOf: legacyFixtureURL("QUEUE1.QA_"))
    let mm1Expanded = try LegacyCompressedFile.expandedData(from: mm1Data)
    let mm1 = try WinQSBQueuingParser.parseMM1(from: mm1Expanded)
    let mm1Report = ValidationReport(
        backend: .validateOnly,
        diagnostics: MM1QueueValidator.diagnostics(for: mm1)
    )

    #expect(mm1Report.isValid)
    #expect(mm1Report.diagnostics.contains {
        $0.severity == .info && $0.code == "queuing.mm1.valid"
    })

    let unstable = MM1QueueModel(
        title: "Unstable",
        timeUnit: "hour",
        serviceRate: 2,
        arrivalRate: 2,
        customerWaitingCostPerTime: -1
    )
    let unstableDiagnostics = MM1QueueValidator.diagnostics(for: unstable)
    #expect(unstableDiagnostics.contains { $0.code == "queuing.mm1.unstable" && $0.severity == .error })
    #expect(unstableDiagnostics.contains {
        $0.code == "queuing.mm1.cost" && $0.path == "customerWaitingCostPerTime"
    })

    let invalidFinite = FiniteCapacityQueueModel(
        title: "Invalid finite queue",
        timeUnit: "hour",
        servers: 0,
        serviceDistribution: "Normal",
        meanServiceTime: 0,
        interarrivalDistribution: "Constant",
        meanInterarrivalTime: 0.5,
        batchSize: 2,
        queueCapacity: -1
    )
    let finiteDiagnostics = FiniteCapacityQueueValidator.diagnostics(for: invalidFinite)
    #expect(finiteDiagnostics.contains { $0.code == "queuing.finiteCapacity.servers" })
    #expect(finiteDiagnostics.contains { $0.code == "queuing.finiteCapacity.meanServiceTime" })
    #expect(finiteDiagnostics.contains { $0.code == "queuing.finiteCapacity.batchSize" })
    #expect(finiteDiagnostics.contains { $0.code == "queuing.finiteCapacity.queueCapacity" })
    #expect(finiteDiagnostics.contains { $0.code == "queuing.finiteCapacity.interarrivalDistribution" })
}

@Test func routesQueuingModelsThroughNamedBackends() throws {
    let mm1Data = try Data(contentsOf: legacyFixtureURL("QUEUE1.QA_"))
    let mm1Expanded = try LegacyCompressedFile.expandedData(from: mm1Data)
    let mm1 = try WinQSBQueuingParser.parseMM1(from: mm1Expanded)

    let finiteData = try Data(contentsOf: legacyFixtureURL("QUEUE2.QA_"))
    let finiteExpanded = try LegacyCompressedFile.expandedData(from: finiteData)
    let finite = try WinQSBQueuingParser.parseFiniteCapacity(from: finiteExpanded)

    let nativeBackend = NativeEducationalQueuingBackend()
    #expect(nativeBackend.capabilities.backendKind == .nativeEducational)
    #expect(nativeBackend.capabilities.solves)
    #expect(nativeBackend.capabilities.validates)
    #expect(nativeBackend.capabilities.exportsStructuredSolution)
    #expect(abs(try nativeBackend.solve(mm1).utilization - 2.0 / 3.0) < 1e-8)
    #expect(abs(try nativeBackend.solve(finite).effectiveArrivalRate - 1.8822447082925162) < 1e-8)

    let validateBackend = ValidateOnlyQueuingBackend()
    #expect(!validateBackend.capabilities.solves)
    #expect(validateBackend.validationReport(for: mm1).isValid)
    #expect(validateBackend.validationReport(for: finite).isValid)
    #expect(validateBackend.validationReport(for: finite).diagnostics.contains {
        $0.severity == .warning && $0.code == "queuing.finiteCapacity.serviceApproximation"
    })

    do {
        _ = try validateBackend.solve(mm1)
        Issue.record("Expected validateOnly backend to reject M/M/1 solving")
    } catch QueuingModelError.invalidModel(let message) {
        #expect(message.contains("validateOnly"))
    }

    let selectedBackend = try #require(QueuingBackends.backend(for: .nativeEducational))
    #expect(selectedBackend.capabilities.backendKind == .nativeEducational)
    #expect(QueuingBackends.backend(for: .externalHighPerformance) == nil)
}

@Test func encodesNormalizedQueuingSolutionDocuments() throws {
    let mm1Data = try Data(contentsOf: legacyFixtureURL("QUEUE1.QA_"))
    let mm1Expanded = try LegacyCompressedFile.expandedData(from: mm1Data)
    let mm1 = try WinQSBQueuingParser.parseMM1(from: mm1Expanded)
    let mm1Solution = try NativeEducationalQueuingBackend().solve(mm1)
    let mm1Document = QueuingSolutionJSON.mm1Document(
        model: mm1,
        solution: mm1Solution,
        backend: SolverRunMetadata(
            backendKind: .nativeEducational,
            algorithm: "mm1ClosedForm",
            exactness: .closedForm
        )
    )
    let mm1JSON = try QueuingSolutionJSON.encode(mm1Document)
    let decodedMM1 = try JSONDecoder().decode(QueuingSolutionDocument.self, from: mm1JSON)

    #expect(decodedMM1.kind == .mm1)
    #expect(decodedMM1.notation == "M/M/1")
    #expect(decodedMM1.backend.exactness == .closedForm)
    #expect(decodedMM1.metrics.servers == 1)
    #expect(decodedMM1.metrics.systemCapacity == nil)
    #expect(decodedMM1.metrics.blockingProbability == 0)
    #expect(abs(decodedMM1.metrics.averageNumberInQueue - 4.0 / 3.0) < 1e-8)
    #expect(abs((decodedMM1.cost?.totalCost ?? 0) - 300) < 1e-8)

    let finiteData = try Data(contentsOf: legacyFixtureURL("QUEUE2.QA_"))
    let finiteExpanded = try LegacyCompressedFile.expandedData(from: finiteData)
    let finite = try WinQSBQueuingParser.parseFiniteCapacity(from: finiteExpanded)
    let finiteSolution = try NativeEducationalQueuingBackend().solve(finite)
    let finiteDocument = QueuingSolutionJSON.finiteCapacityDocument(
        model: finite,
        solution: finiteSolution,
        backend: SolverRunMetadata(
            backendKind: .nativeEducational,
            algorithm: "finiteCapacityBirthDeath",
            exactness: .approximate
        )
    )
    let finiteJSON = try QueuingSolutionJSON.encode(finiteDocument)
    let decodedFinite = try JSONDecoder().decode(QueuingSolutionDocument.self, from: finiteJSON)
    let finiteText = try #require(String(data: finiteJSON, encoding: .utf8))

    #expect(decodedFinite.kind == .finiteCapacity)
    #expect(decodedFinite.notation == "M/G/2/5")
    #expect(decodedFinite.backend.exactness == .approximate)
    #expect(decodedFinite.metrics.systemCapacity == 5)
    #expect(decodedFinite.stateProbabilities.count == 6)
    #expect(abs(decodedFinite.metrics.blockingProbability - 0.05887764585374193) < 1e-8)
    #expect(abs((decodedFinite.cost?.totalCost ?? 0) - 339.09383689684665) < 1e-8)
    #expect(finiteText.contains("\"effectiveArrivalRate\""))
    #expect(finiteText.contains("\"stateProbabilities\""))
}

