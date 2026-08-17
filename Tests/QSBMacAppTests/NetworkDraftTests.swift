import Foundation
import Testing
@testable import QSBMacApp
@testable import QSBCore

@Test("blank graph draft has a deterministic valid shape")
func blankNetworkDraftConverts() throws {
    let draft = NetworkDraft.blank(.shortestPath)
    let model = try draft.makeNetworkModel()

    guard case .shortestPath(let network) = model else {
        Issue.record("Expected shortest path model")
        return
    }
    #expect(network.nodes == ["Node 1", "Node 2"])
    #expect(network.arcs.count == 1)
}

@Test("network draft round trips graph variants without changing semantics")
func networkDraftRoundTripsGraphVariants() throws {
    let models: [NetworkModelEnvelope] = [
        .shortestPath(ShortestPathNetwork(title: "SP", nodes: ["A", "B", "C"], arcs: [
            NetworkArc(from: "A", to: "B", cost: 2), NetworkArc(from: "B", to: "C", cost: 3)
        ])),
        .minimumSpanningTree(MinimumSpanningTreeNetwork(title: "MST", nodes: ["A", "B", "C"], edges: [
            NetworkArc(from: "A", to: "B", cost: 2), NetworkArc(from: "B", to: "C", cost: 3)
        ])),
        .maxFlow(MaxFlowNetwork(title: "Flow", nodes: ["S", "M", "T"], arcs: [
            NetworkArc(from: "S", to: "M", cost: 4), NetworkArc(from: "M", to: "T", cost: 3)
        ])),
        .travelingSalesperson(TravelingSalespersonProblem(title: "TSP", nodes: ["A", "B", "C"], arcs: [
            NetworkArc(from: "A", to: "B", cost: 2), NetworkArc(from: "B", to: "C", cost: 3), NetworkArc(from: "C", to: "A", cost: 4)
        ]))
    ]

    for model in models {
        let draft = try #require(NetworkDraft(envelope: model))
        #expect(try draft.makeNetworkModel() == model)
    }
}

@Test("node removal removes incident arcs and preserves unrelated arc identity")
func networkDraftNodeMutationIsSafe() throws {
    var draft = NetworkDraft.blank(.shortestPath)
    let middle = draft.addNode(name: "Middle")
    let first = try #require(draft.nodes.first?.id)
    let last = try #require(draft.nodes.dropFirst().first?.id)
    let unrelatedArc = draft.addArc(from: first, to: last, costText: "7")
    _ = draft.addArc(from: middle, to: last, costText: "2")

    draft.removeNode(id: middle)

    #expect(draft.nodes.contains { $0.id == middle } == false)
    #expect(draft.arcs.contains { $0.id == unrelatedArc })
    #expect(draft.arcs.allSatisfy { $0.fromNodeID != middle && $0.toNodeID != middle })
}

@Test("positioned node creation uses unique default names")
func networkDraftPositionedNodeCreationIsUnique() throws {
    var draft = NetworkDraft.blank(.shortestPath)
    let first = draft.addNode(position: NetworkDraftPosition(x: 0.2, y: 0.3))
    let second = draft.addNode(position: NetworkDraftPosition(x: 0.8, y: 0.7))

    let firstNode = try #require(draft.nodes.first { $0.id == first })
    let secondNode = try #require(draft.nodes.first { $0.id == second })
    #expect(firstNode.name == "Node 3")
    #expect(secondNode.name == "Node 4")
    #expect(firstNode.position == NetworkDraftPosition(x: 0.2, y: 0.3))
    #expect(secondNode.position == NetworkDraftPosition(x: 0.8, y: 0.7))
}

@Test("fast connection creates one arc and rejects duplicate destinations")
func networkDraftFastConnectionIsDuplicateSafe() throws {
    var draft = NetworkDraft.blank(.shortestPath)
    let source = try #require(draft.nodes.first?.id)
    let firstDestination = draft.addNode(name: "Node 3")
    let secondDestination = draft.addNode(name: "Node 4")

    let originalCount = draft.arcs.count
    let firstResult = draft.addArcIfMissing(from: source, to: secondDestination)
    let duplicateResult = draft.addArcIfMissing(from: source, to: secondDestination)
    let secondResult = draft.addArcIfMissing(from: source, to: firstDestination)

    #expect(firstResult.created)
    #expect(!duplicateResult.created)
    #expect(firstResult.id == duplicateResult.id)
    #expect(secondResult.created)
    #expect(draft.arcs.count == originalCount + 2)
}

@Test("undirected fast connection treats reversed endpoints as the same edge")
func networkDraftUndirectedConnectionIsDuplicateSafe() throws {
    var draft = NetworkDraft.blank(.minimumSpanningTree)
    let first = try #require(draft.nodes.first?.id)
    let second = try #require(draft.nodes.dropFirst().first?.id)

    let result = draft.addArcIfMissing(from: second, to: first)

    #expect(!result.created)
    #expect(draft.arcs.count == 1)
    #expect(result.id == draft.arcs[0].id)
}

@Test("inline arc value commit changes the existing draft field")
func networkDraftArcValueEditingUsesExistingField() throws {
    var draft = NetworkDraft.blank(.maxFlow)
    let arcID = try #require(draft.arcs.first?.id)
    let committed = draft.commitArcCost(id: arcID, value: "12.5")
    #expect(committed)

    #expect(draft.arcs[0].costText == "12.5")
    #expect(draft.draftIssues().isEmpty)
}

@Test("invalid or cancelled inline arc edits do not mutate the draft")
func networkDraftInlineArcValueRejectsInvalidInput() throws {
    var draft = NetworkDraft.blank(.shortestPath)
    let arcID = try #require(draft.arcs.first?.id)
    let original = draft.arcs[0].costText

    let malformed = draft.commitArcCost(id: arcID, value: "unfinished")
    #expect(!malformed)
    #expect(draft.arcs[0].costText == original)
    let negative = draft.commitArcCost(id: arcID, value: "-1")
    #expect(!negative)
    #expect(draft.arcs[0].costText == original)
    let valid = draft.commitArcCost(id: arcID, value: " 4.25 ")
    #expect(valid)
    #expect(draft.arcs[0].costText == " 4.25 ")
}

@Test("draft reports incomplete endpoints and invalid costs before core validation")
func networkDraftReportsStructuralIssues() {
    var draft = NetworkDraft.blank(.shortestPath)
    draft.arcs[0].fromNodeID = nil

    let issues = draft.draftIssues()
    #expect(issues.contains { if case .missingArcEndpoint = $0 { true } else { false } })

    draft.arcs[0].fromNodeID = draft.nodes.first?.id
    draft.arcs[0].costText = "unfinished"
    let costIssues = draft.draftIssues()
    #expect(costIssues.contains { if case .invalidArcCost = $0 { true } else { false } })
}

@Test("source and sink selections map to the existing first and last node semantics")
func networkDraftSourceSinkOrderPreservesCoreContract() throws {
    var draft = NetworkDraft.blank(.maxFlow)
    let source = try #require(draft.nodes.last?.id)
    let sink = try #require(draft.nodes.first?.id)
    draft.sourceNodeID = source
    draft.sinkNodeID = sink

    guard case .maxFlow(let model) = try draft.makeNetworkModel() else {
        Issue.record("Expected max-flow model")
        return
    }
    #expect(model.nodes.first == "Node 2")
    #expect(model.nodes.last == "Node 1")
}

@Test("network draft keeps normalized JSON as an explicit typed boundary")
func networkDraftJSONRoundTripPreservesModel() throws {
    var draft = NetworkDraft.blank(.travelingSalesperson)
    let third = draft.addNode(name: "Node 3")
    let first = try #require(draft.nodes.first?.id)
    _ = draft.addArc(from: third, to: first, costText: "4")

    let model = try draft.makeNetworkModel()
    let json = try NetworkModelJSON.encodeModel(model)
    let decoded = try NetworkModelJSON.decodeModel(from: json)
    let restored = try #require(NetworkDraft(envelope: decoded))

    #expect(try restored.makeNetworkModel() == model)
    #expect(String(decoding: json, as: UTF8.self).contains("\"kind\" : \"TSP\""))
}

@Test("native network backend solves a model created by the draft")
func networkDraftUsesExistingBackend() throws {
    var draft = NetworkDraft.blank(.shortestPath)
    draft.arcs[0].costText = "5"
    let model = try draft.makeNetworkModel()
    let backend = try #require(NetworkBackends.backend(for: .nativeEducational))

    let solution = try backend.solve(model)
    guard case .shortestPath(let value) = solution else {
        Issue.record("Expected shortest path solution")
        return
    }
    #expect(value.path == ["Node 1", "Node 2"])
    #expect(value.totalCost == 5)
}

@Test("assignment draft preserves rectangular dimensions and uses the existing backend")
func assignmentDraftRoundTripsAndSolves() throws {
    var draft = AssignmentDraft.blank()
    draft.rows = [AssignmentRowDraft(name: "A"), AssignmentRowDraft(name: "B")]
    draft.columns = [AssignmentColumnDraft(name: "X"), AssignmentColumnDraft(name: "Y"), AssignmentColumnDraft(name: "Z")]
    draft.costs = [["4", "1", "3"], ["2", "5", "6"]]

    let model = try draft.makeModel()
    #expect(model.workers == ["A", "B"])
    #expect(model.tasks.count == 3)
    let restored = AssignmentDraft(model: model)
    #expect(try restored.makeModel() == model)
    let backend = try #require(NetworkBackends.backend(for: .nativeEducational))
    guard case .assignment(let solution) = try backend.solve(.assignment(model)) else {
        Issue.record("Expected assignment solution")
        return
    }
    #expect(solution.totalCost == 3)
}

@Test("assignment row and column mutations preserve matrix dimensions")
func assignmentDraftMutationsAreDimensionallySafe() throws {
    var draft = AssignmentDraft.blank()
    _ = draft.addRow(name: "Extra")
    #expect(draft.costs.count == draft.rows.count)
    #expect(draft.costs.allSatisfy { $0.count == draft.columns.count })
    draft.removeRow(at: 0)
    _ = draft.addColumn(name: "Extra task")
    #expect(draft.costs.allSatisfy { $0.count == draft.columns.count })
    draft.removeColumn(at: 0)
    #expect(draft.costs.allSatisfy { $0.count == draft.columns.count })
}

@Test("transportation draft preserves supply demand alignment and JSON semantics")
func transportationDraftRoundTripsAndSolves() throws {
    let draft = TransportationDraft(
        title: "TP",
        sources: [TransportationSourceDraft(name: "S1", supply: "5"), TransportationSourceDraft(name: "S2", supply: "5")],
        destinations: [TransportationDestinationDraft(name: "D1", demand: "4"), TransportationDestinationDraft(name: "D2", demand: "6")],
        costs: [["1", "3"], ["2", "4"]]
    )
    let model = try draft.makeModel()
    #expect(NetworkValidator.diagnostics(for: .transportation(model)).contains { $0.severity == .info })
    let json = try NetworkModelJSON.encodeModel(.transportation(model))
    let decoded = try NetworkModelJSON.decodeModel(from: json)
    let restored = try #require(TransportationDraft(envelope: decoded))
    #expect(try restored.makeModel() == model)
    let backend = try #require(NetworkBackends.backend(for: .nativeEducational))
    guard case .transportation(let solution) = try backend.solve(.transportation(model)) else {
        Issue.record("Expected transportation solution")
        return
    }
    #expect(solution.totalCost == 27)
}

@Test("transportation source and destination mutations preserve matrix dimensions")
func transportationDraftMutationsAreDimensionallySafe() {
    var draft = TransportationDraft.blank()
    _ = draft.addSource(name: "Extra source", supply: "0")
    #expect(draft.costs.count == draft.sources.count)
    #expect(draft.costs.allSatisfy { $0.count == draft.destinations.count })
    draft.removeSource(at: 0)
    _ = draft.addDestination(name: "Extra destination", demand: "0")
    #expect(draft.costs.allSatisfy { $0.count == draft.destinations.count })
    draft.removeDestination(at: 0)
    #expect(draft.costs.allSatisfy { $0.count == draft.destinations.count })
}

@Test("matrix drafts report incomplete numeric cells before core validation")
func matrixDraftsReportInputIssues() {
    var assignment = AssignmentDraft.blank()
    assignment.costs[0][0] = "unfinished"
    #expect(assignment.draftIssues().contains { if case .invalidCost = $0 { true } else { false } })

    var transportation = TransportationDraft.blank()
    transportation.sources[0].supply = "unfinished"
    #expect(transportation.draftIssues().contains { if case .invalidSupply = $0 { true } else { false } })
}

@Test("workspace imports Assignment and Transportation JSON into their native drafts")
func workspaceLoadsMatrixNetworkDrafts() throws {
    let assignment = NetworkModelEnvelope.assignment(AssignmentProblem(title: "AP", workers: ["A"], tasks: ["X"], costs: [[1.0]]))
    let assignmentJSON = String(decoding: try NetworkModelJSON.encodeModel(assignment), as: UTF8.self)
    let assignmentWorkspace = QSBWorkspace(modelJSON: assignmentJSON)
    #expect(assignmentWorkspace.assignmentDraft != nil)
    #expect(assignmentWorkspace.networkDraft == nil)

    let transportation = NetworkModelEnvelope.transportation(TransportationProblem(title: "TP", origins: ["S"], destinations: ["D"], costs: [[2]], supply: [3], demand: [3]))
    let transportationJSON = String(decoding: try NetworkModelJSON.encodeModel(transportation), as: UTF8.self)
    let transportationWorkspace = QSBWorkspace(modelJSON: transportationJSON)
    #expect(transportationWorkspace.transportationDraft != nil)
    #expect(transportationWorkspace.networkDraft == nil)
}

@Test("CNF draft preserves node balances and arc semantics")
func networkFlowDraftRoundTripsAndSolves() throws {
    let model = MinimumCostNetworkFlowProblem(
        title: "Flow",
        nodes: ["Source", "Sink"],
        arcs: [NetworkArc(from: "Source", to: "Sink", cost: 3)],
        supply: [5, 0],
        demand: [0, 5]
    )
    let draft = NetworkFlowDraft(model)
    #expect(try draft.makeModel() == model)
    let json = try NetworkModelJSON.encodeModel(.minimumCostFlow(model))
    let restored = try #require(NetworkFlowDraft(envelope: NetworkModelJSON.decodeModel(from: json)))
    #expect(try restored.makeModel() == model)
    let solution = try NativeEducationalNetworkBackend().solve(.minimumCostFlow(model))
    guard case .minimumCostFlow(let value) = solution else {
        Issue.record("Expected minimum-cost flow solution")
        return
    }
    #expect(value.arcFlows.first?.quantity == 5)
    #expect(value.totalCost == 15)
}

@Test("CNF node removal removes incident arcs")
func networkFlowDraftNodeMutationIsSafe() {
    var draft = NetworkFlowDraft.blank()
    let middle = draft.addNode(name: "Middle")
    _ = draft.addArc(from: middle, to: draft.nodes.first?.id, costText: "2")
    draft.removeNode(id: middle)
    #expect(draft.nodes.contains { $0.id == middle } == false)
    #expect(draft.arcs.allSatisfy { $0.fromNodeID != middle && $0.toNodeID != middle })
}
