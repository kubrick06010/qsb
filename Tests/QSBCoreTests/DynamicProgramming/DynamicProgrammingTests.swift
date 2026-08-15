import Foundation
import Testing
@testable import QSBCore

@Test func parsesAndSolvesWinQSBKnapsackFixture() throws {
    let url = legacyFixtureURL("KNAPSACK.DP_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBDynamicProgrammingParser.parseKnapsack(from: expanded)
    let solution = try KnapsackSolver.solve(problem)

    #expect(problem.title == "QSB P.112")
    #expect(problem.capacity == 20)
    #expect(problem.items == [
        KnapsackItem(name: "A", available: 5, capacityRequired: 10, returnPerUnit: 8),
        KnapsackItem(name: "B", available: 3, capacityRequired: 6, returnPerUnit: 10),
        KnapsackItem(name: "C", available: 4, capacityRequired: 3, returnPerUnit: 4),
        KnapsackItem(name: "D", available: 2, capacityRequired: 5, returnPerUnit: 7)
    ])
    #expect(abs(solution.totalReturn - 31) < 1e-8)
    #expect(solution.capacityUsed == 20)
    #expect(solution.selections == [
        KnapsackSelection(item: "B", quantity: 2, capacityUsed: 12, returnValue: 20),
        KnapsackSelection(item: "C", quantity: 1, capacityUsed: 3, returnValue: 4),
        KnapsackSelection(item: "D", quantity: 1, capacityUsed: 5, returnValue: 7)
    ])
}

@Test func parsesAndSolvesWinQSBStagecoachFixture() throws {
    let url = legacyFixtureURL("STAGE.DP_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBDynamicProgrammingParser.parseStagecoach(from: expanded)
    let solution = try StagecoachSolver.solve(problem)

    #expect(problem.title == "QSB 119")
    #expect(problem.nodes == ["Node1", "Node2", "Node3", "Node4", "Node5", "Node6", "Node7", "Node8", "Node9", "Node10"])
    #expect(problem.arcs.count == 20)
    #expect(solution.source == "Node1")
    #expect(solution.sink == "Node10")
    #expect(abs(solution.totalCost - 19) < 1e-8)
    #expect(solution.path == ["Node1", "Node3", "Node5", "Node8", "Node10"])
}

@Test func roundTripsNormalizedDynamicProgrammingModelsAndSolutions() throws {
    let fixtures: [(String, DynamicProgrammingProblemKind)] = [
        ("KNAPSACK.DP_", .boundedKnapsack),
        ("STAGE.DP_", .stagecoach),
        ("PRODINVT.DP_", .productionInventory)
    ]
    let backend = NativeEducationalDynamicProgrammingBackend()

    for (fileName, expectedKind) in fixtures {
        let data = try Data(contentsOf: legacyFixtureURL(fileName))
        let model = try WinQSBDynamicProgrammingParser.parseModelEnvelope(from: LegacyCompressedFile.expandedData(from: data))
        #expect(model.kind == expectedKind)

        let encodedModel = try DynamicProgrammingModelJSON.encodeModel(model)
        #expect(try DynamicProgrammingModelJSON.decodeModel(from: encodedModel) == model)

        let solution = try backend.solve(model)
        #expect(solution.kind == expectedKind)
        #expect(!solution.trace.isEmpty)
        let document = backend.solutionDocument(for: model, solution: solution)
        let encodedSolution = try DynamicProgrammingModelJSON.encodeSolutionDocument(document)
        #expect(try DynamicProgrammingModelJSON.decodeSolutionDocument(from: encodedSolution) == document)
    }
}

@Test func routesDynamicProgrammingModelsThroughNamedBackends() throws {
    let native = NativeEducationalDynamicProgrammingBackend()
    let validateOnly = ValidateOnlyDynamicProgrammingBackend()
    let data = try Data(contentsOf: legacyFixtureURL("KNAPSACK.DP_"))
    let model = try WinQSBDynamicProgrammingParser.parseModelEnvelope(from: LegacyCompressedFile.expandedData(from: data))

    #expect(native.capabilities.solves)
    #expect(native.runMetadata(for: model).algorithm == "boundedKnapsackDynamicProgramming")
    #expect(native.runMetadata(for: model).exactness == .fixtureScale)
    #expect(validateOnly.validationReport(for: model).isValid)
    #expect(DynamicProgrammingBackends.backend(for: .externalHighPerformance) == nil)

    let invalid = DynamicProgrammingModelEnvelope.boundedKnapsack(KnapsackProblem(title: "invalid", capacity: 0, items: []))
    let report = validateOnly.validationReport(for: invalid)
    #expect(!report.isValid)
    #expect(report.diagnostics.contains { $0.code == "dynamicProgramming.boundedKnapsack.capacity.nonpositive" })
    #expect(report.diagnostics.contains { $0.code == "dynamicProgramming.boundedKnapsack.items.empty" })

    do {
        _ = try validateOnly.solve(model)
        Issue.record("validateOnly unexpectedly solved a dynamic-programming model")
    } catch {
        #expect(String(describing: error).contains("validateOnly"))
    }
}

