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
