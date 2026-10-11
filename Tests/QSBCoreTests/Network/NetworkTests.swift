import Foundation
import Testing
@testable import QSBCore

@Test func parsesAndSolvesWinQSBShortestPathFixture() throws {
    let url = legacyFixtureURL("SHTPATH.NE_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let network = try WinQSBNetworkParser.parseShortestPath(from: expanded)
    let solution = try ShortestPathSolver.solve(network)

    #expect(network.nodes.count == 10)
    #expect(network.arcs.count == 20)
    #expect(solution.source == "Node1")
    #expect(solution.sink == "Node10")
    #expect(abs(solution.totalCost - 29) < 1e-8)
    #expect(solution.path == ["Node1", "Node2", "Node5", "Node9", "Node10"])
}

@Test func parsesAndSolvesWinQSBMinimumCostNetworkFlowFixture() throws {
    let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("NETFLOW.NE_")))
    let problem = try WinQSBNetworkParser.parseMinimumCostFlow(from: expanded)
    let model = try WinQSBNetworkParser.parseModelEnvelope(from: expanded)
    let report = ValidateOnlyNetworkBackend().validationReport(for: model)
    let solution = try MinimumCostNetworkFlowSolver.solve(problem)

    #expect(problem.nodes == ["S1", "S2", "T1", "T2", "T3", "T4", "D1", "D2", "D3"])
    #expect(problem.arcs.count == 17)
    #expect(problem.supply.reduce(0, +) == 1950)
    #expect(problem.demand.reduce(0, +) == 2050)
    #expect(report.isValid)
    #expect(report.diagnostics.contains { $0.code == "network.CNF.balance.automatic" && $0.severity == .warning })
    #expect(abs(solution.totalCost - 7900) < 1e-8)
    #expect(solution.balanceAdjustments == [NetworkBalanceAdjustment(node: "D2", quantity: 100, kind: "dummySupply")])
}

@Test func parsesAndSolvesWinQSBAggregatePlanningTransportationFixture() throws {
    let model = try WinQSBAggregatePlanningParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("APTRP.AP_"))))
    let solution = try AggregatePlanningSolver.solve(model)
    #expect(model.method == .transportation)
    #expect(!model.capacityIsPerWorker)
    #expect(abs(solution.totalCost - 4_100) < 1e-9)
    #expect(solution.periods.map(\.regularProduction) == [450, 450, 750, 450])
    #expect(solution.periods.map(\.overtimeProduction) == [90, 90, 150, 90])
    #expect(solution.periods.map(\.subcontracted) == [20, 200, 200, 110])
    #expect(solution.periods.map(\.endingInventory) == [510, 400, 0, 300])
    try expectAggregatePlanningBalances(model: model, solution: solution)
}

@Test func parsesAndSolvesWinQSBMinimumSpanningTreeFixture() throws {
    let url = legacyFixtureURL("SPANTREE.NE_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let network = try WinQSBNetworkParser.parseMinimumSpanningTree(from: expanded)
    let solution = try MinimumSpanningTreeSolver.solve(network)

    #expect(network.nodes.count == 10)
    #expect(network.edges.count == 20)
    #expect(abs(solution.totalCost - 68) < 1e-8)
    #expect(solution.edges.count == 9)
    #expect(Set(solution.edges.map { "\($0.from)-\($0.to)" }).isSuperset(of: [
        "Node1-Node2",
        "Node1-Node4",
        "Node2-Node5",
        "Node4-Node6",
        "Node7-Node8",
        "Node1-Node3",
        "Node4-Node7",
        "Node9-Node10",
        "Node5-Node9"
    ]))
}

@Test func parsesAndSolvesWinQSBMaxFlowFixture() throws {
    let url = legacyFixtureURL("MAXFLOW.NE_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let network = try WinQSBNetworkParser.parseMaxFlow(from: expanded)
    let solution = try MaxFlowSolver.solve(network)

    #expect(network.nodes.count == 7)
    #expect(network.arcs.count == 23)
    #expect(solution.source == "Node1")
    #expect(solution.sink == "Node7")
    #expect(abs(solution.maxFlow - 30) < 1e-8)
}

@Test func parsesAndSolvesWinQSBTravelingSalespersonFixture() throws {
    let url = legacyFixtureURL("TSP.NE_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBNetworkParser.parseTravelingSalesperson(from: expanded)
    let solution = try TravelingSalespersonSolver.solve(problem)

    #expect(problem.nodes == ["LA", "DEV", "HOU", "DAL", "CMH", "NY"])
    #expect(problem.arcs.count == 26)
    #expect(solution.source == "LA")
    #expect(abs(solution.totalCost - 1130) < 1e-8)
    #expect(solution.tour == ["LA", "HOU", "NY", "CMH", "DAL", "DEV", "LA"])
}

@Test func parsesAndSolvesWinQSBAssignmentFixture() throws {
    let url = legacyFixtureURL("ASSIMENT.NE_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBNetworkParser.parseAssignment(from: expanded)
    let solution = try AssignmentSolver.solve(problem)

    #expect(problem.workers == ["John", "Peter", "Toshi", "Rudy"])
    #expect(problem.tasks == ["A", "B", "C", "D"])
    #expect(abs(solution.totalCost - 20) < 1e-8)
    #expect(solution.assignments == [
        AssignmentPair(worker: "John", task: "B", cost: 6),
        AssignmentPair(worker: "Peter", task: "C", cost: 3),
        AssignmentPair(worker: "Toshi", task: "A", cost: 2),
        AssignmentPair(worker: "Rudy", task: "D", cost: 9)
    ])
}

@Test func solvesRectangularAssignmentProblem() throws {
    let problem = AssignmentProblem(
        title: "Rectangular Assignment",
        workers: ["W1", "W2", "W3"],
        tasks: ["A", "B", "C", "D", "E"],
        costs: [
            [9, 2, 7, 8, 6],
            [6, 4, 3, 7, 5],
            [5, 8, 1, 8, 3]
        ]
    )

    let solution = try AssignmentSolver.solve(problem)

    #expect(abs(solution.totalCost - 8) < 1e-8)
    #expect(solution.assignments == [
        AssignmentPair(worker: "W1", task: "B", cost: 2),
        AssignmentPair(worker: "W2", task: "C", cost: 3),
        AssignmentPair(worker: "W3", task: "E", cost: 3)
    ])
}

@Test func parsesAndSolvesWinQSBTransportationFixture() throws {
    let url = legacyFixtureURL("TRNSPORT.NE_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBNetworkParser.parseTransportation(from: expanded)
    let solution = try TransportationSolver.solve(problem)

    #expect(problem.origins == ["Boston", "Denver", "Austin"])
    #expect(problem.destinations == ["Dallas", "Kansas", "Tampa", "Miami"])
    #expect(problem.supply == [100, 200, 400])
    #expect(problem.demand == [200, 100, 150, 250])
    #expect(abs(solution.totalCost - 3350) < 1e-8)
    #expect(solution.shipments == [
        TransportationShipment(origin: "Boston", destination: "Tampa", quantity: 50, unitCost: 5),
        TransportationShipment(origin: "Boston", destination: "Miami", quantity: 50, unitCost: 6),
        TransportationShipment(origin: "Denver", destination: "Miami", quantity: 200, unitCost: 6),
        TransportationShipment(origin: "Austin", destination: "Dallas", quantity: 200, unitCost: 2),
        TransportationShipment(origin: "Austin", destination: "Kansas", quantity: 100, unitCost: 5),
        TransportationShipment(origin: "Austin", destination: "Tampa", quantity: 100, unitCost: 7)
    ])
}

@Test func validatesWinQSBTransportationFixtureWithBackendDiagnostics() throws {
    let url = legacyFixtureURL("TRNSPORT.NE_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBNetworkParser.parseTransportation(from: expanded)
    let diagnostics = TransportationValidator.diagnostics(for: problem)
    let report = ValidationReport(backend: .validateOnly, diagnostics: diagnostics)

    #expect(report.backend == .validateOnly)
    #expect(report.isValid)
    #expect(diagnostics.contains {
        $0.severity == .info && $0.code == "network.transportation.valid"
    })
}

@Test func encodesAndDecodesNormalizedNetworkJSONModel() throws {
    let url = legacyFixtureURL("TSP.NE_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)
    let model = try WinQSBNetworkParser.parseModelEnvelope(from: expanded)

    let json = try NetworkModelJSON.encodeModel(model)
    let decoded = try NetworkModelJSON.decodeModel(from: json)

    #expect(decoded == model)
    #expect(String(data: json, encoding: .utf8)?.contains("\"kind\" : \"TSP\"") == true)
}

@Test func solvesDecodedNetworkJSONModel() throws {
    let url = legacyFixtureURL("SHTPATH.NE_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)
    let model = try WinQSBNetworkParser.parseModelEnvelope(from: expanded)
    let json = try NetworkModelJSON.encodeModel(model)
    let decoded = try NetworkModelJSON.decodeModel(from: json)

    guard case .shortestPath(let network) = decoded else {
        Issue.record("Expected shortest path network JSON")
        return
    }
    let solution = try ShortestPathSolver.solve(network)
    let solutionJSON = try NetworkModelJSON.encodeSolution(.shortestPath(solution))
    let solutionText = try #require(String(data: solutionJSON, encoding: .utf8))

    #expect(abs(solution.totalCost - 29) < 1e-8)
    #expect(solutionText.contains("\"kind\" : \"SPP\""))
    #expect(solutionText.contains("\"totalCost\" : 29"))
}

@Test func routesAllNetworkModelsThroughNamedBackends() throws {
    let fixtures = ["NETFLOW.NE_", "SHTPATH.NE_", "SPANTREE.NE_", "MAXFLOW.NE_", "TSP.NE_", "ASSIMENT.NE_", "TRNSPORT.NE_"]
    let expectedAlgorithms = ["continuousLinearProgramming", "dijkstra", "kruskal", "edmondsKarp", "heldKarpDynamicProgramming", "hungarianRectangular", "continuousLinearProgramming"]
    let native = NativeEducationalNetworkBackend()
    let validateOnly = ValidateOnlyNetworkBackend()

    for (fixture, algorithm) in zip(fixtures, expectedAlgorithms) {
        let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL(fixture)))
        let model = try WinQSBNetworkParser.parseModelEnvelope(from: expanded)
        #expect(validateOnly.validationReport(for: model).isValid)
        #expect(native.runMetadata(for: model).algorithm == algorithm)
        let solution = try native.solve(model)
        #expect(solution.kind == model.kind)
        let document = native.solutionDocument(for: model, solution: solution)
        let encoded = try NetworkModelJSON.encodeSolutionDocument(document)
        #expect(try NetworkModelJSON.decodeSolutionDocument(from: encoded) == document)
    }

    #expect(native.runMetadata(for: try WinQSBNetworkParser.parseModelEnvelope(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("TSP.NE_"))))).exactness == .fixtureScale)
    if let external = NetworkBackends.backend(for: .externalHighPerformance) {
        #expect(external.capabilities.solves)
        #expect(external.capabilities.backendKind == .externalHighPerformance)
    }
}

@Test func routesLPBackedNetworkVariantsThroughExternalBackendSeam() throws {
    let transportationData = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("TRNSPORT.NE_")))
    let transportation = try WinQSBNetworkParser.parseTransportation(from: transportationData)
    let flowData = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("NETFLOW.NE_")))
    let flow = try WinQSBNetworkParser.parseMinimumCostFlow(from: flowData)
    let backend = HiGHSNetworkBackend(linearProgrammingBackend: NativeEducationalLinearProgrammingBackend())

    guard case .transportation(let transportationSolution) = try backend.solve(.transportation(transportation)) else {
        Issue.record("Expected an external transportation solution")
        return
    }
    guard case .minimumCostFlow(let flowSolution) = try backend.solve(.minimumCostFlow(flow)) else {
        Issue.record("Expected an external minimum-cost-flow solution")
        return
    }
    #expect(abs(transportationSolution.totalCost - 3350) < 1e-8)
    #expect(abs(flowSolution.totalCost - 7900) < 1e-8)
    #expect(backend.runMetadata(for: .transportation(transportation)).algorithm == "hiGHSTransportationLP")
    #expect(backend.runMetadata(for: .minimumCostFlow(flow)).algorithm == "hiGHSMinimumCostFlowLP")

    do {
        _ = try backend.solve(.shortestPath(ShortestPathNetwork(
            title: "Native only", nodes: ["A", "B"], arcs: [NetworkArc(from: "A", to: "B", cost: 1)]
        )))
        Issue.record("Expected an explicit unsupported-translation error")
    } catch NetworkModelError.externalTranslationUnavailable {
        // The external backend must not silently replace native graph algorithms.
    }
    #expect(!backend.validationReport(for: .shortestPath(ShortestPathNetwork(
        title: "Native only", nodes: ["A", "B"], arcs: [NetworkArc(from: "A", to: "B", cost: 1)]
    ))).isValid)
}

@Test func solvesLPBackedNetworkWithInstalledHiGHSWhenAvailable() throws {
    guard let backend = HiGHSNetworkBackend.discovered() else { return }
    let data = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("TRNSPORT.NE_")))
    let model = try WinQSBNetworkParser.parseTransportation(from: data)
    let solution = try backend.solve(.transportation(model))
    guard case .transportation(let value) = solution else {
        Issue.record("Expected a transportation solution")
        return
    }
    #expect(abs(value.totalCost - 3350) < 1e-8)
}

@Test func solvesLargerTransportationWithInstalledHiGHSWhenAvailable() throws {
    guard let backend = HiGHSNetworkBackend.discovered() else { return }
    let count = 16
    let origins = (1...count).map { "Origin \($0)" }
    let destinations = (1...count).map { "Destination \($0)" }
    let problem = TransportationProblem(
        title: "Sixteen by sixteen transport",
        origins: origins,
        destinations: destinations,
        costs: (0..<count).map { origin in
            (0..<count).map { destination in
                origin == destination ? 0 : Double(10 + abs(origin - destination))
            }
        },
        supply: Array(repeating: 1, count: count),
        demand: Array(repeating: 1, count: count)
    )

    guard case .transportation(let solution) = try backend.solve(.transportation(problem)) else {
        Issue.record("Expected a transportation solution")
        return
    }
    #expect(abs(solution.totalCost) < 1e-7)
    #expect(solution.shipments.count == count)
    for index in 0..<count {
        #expect(solution.shipments.contains {
            $0.origin == origins[index] && $0.destination == destinations[index]
                && abs($0.quantity - 1) < 1e-7
        })
    }
}

@Test func solvesLargerMinimumCostFlowWithInstalledHiGHSWhenAvailable() throws {
    guard let backend = HiGHSNetworkBackend.discovered() else { return }
    let count = 24
    let nodes = (0..<count).map { "Node \($0)" }
    var arcs: [NetworkArc] = []
    for from in 0..<count {
        for to in (from + 1)..<count {
            let cost: Double = to == from + 1 ? 1 : Double(100 + to - from)
            arcs.append(NetworkArc(from: nodes[from], to: nodes[to], cost: cost))
        }
    }
    let problem = MinimumCostNetworkFlowProblem(
        title: "Twenty-four node flow", nodes: nodes, arcs: arcs,
        supply: [1] + Array(repeating: 0, count: count - 1),
        demand: Array(repeating: 0, count: count - 1) + [1]
    )

    guard case .minimumCostFlow(let solution) = try backend.solve(.minimumCostFlow(problem)) else {
        Issue.record("Expected a minimum-cost-flow solution")
        return
    }
    #expect(abs(solution.totalCost - Double(count - 1)) < 1e-7)
    #expect(solution.balanceAdjustments.isEmpty)
    #expect(solution.arcFlows.count == count - 1)
    for index in 0..<(count - 1) {
        let origin = nodes[index]
        let destination = nodes[index + 1]
        let flow = try #require(solution.arcFlows.first {
            $0.from == origin && $0.to == destination
        })
        #expect(abs(flow.quantity - 1) < 1e-7)
        #expect(abs(flow.unitCost - 1) < 1e-7)
    }
}

@Test func validatesNetworkModelsWithStructuredDiagnostics() throws {
    let invalidGraph = NetworkModelEnvelope.shortestPath(ShortestPathNetwork(
        title: "Invalid",
        nodes: ["A", "A"],
        arcs: [NetworkArc(from: "A", to: "B", cost: -1)]
    ))
    let graphReport = ValidateOnlyNetworkBackend().validationReport(for: invalidGraph)
    #expect(!graphReport.isValid)
    #expect(graphReport.diagnostics.contains { $0.code == "network.SPP.nodes.duplicate" })
    #expect(graphReport.diagnostics.contains { $0.code == "network.SPP.arc.endpoint" })
    #expect(graphReport.diagnostics.contains { $0.code == "network.SPP.arc.value" })

    let invalidAssignment = NetworkModelEnvelope.assignment(AssignmentProblem(
        title: "Invalid",
        workers: ["W1", "W2"],
        tasks: ["T1"],
        costs: [[1], [2]]
    ))
    let assignmentReport = ValidateOnlyNetworkBackend().validationReport(for: invalidAssignment)
    #expect(!assignmentReport.isValid)
    #expect(assignmentReport.diagnostics.contains { $0.code == "network.AP.tasks.insufficient" })

    do {
        _ = try ValidateOnlyNetworkBackend().solve(invalidGraph)
        Issue.record("validateOnly unexpectedly solved a network model")
    } catch {
        #expect(String(describing: error).contains("validateOnly"))
    }
}
