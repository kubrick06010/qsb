import Foundation
import QSBCore

struct NetworkFlowNodeDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var supply: String
    var demand: String

    init(id: UUID = UUID(), name: String, supply: String = "0", demand: String = "0") {
        self.id = id; self.name = name; self.supply = supply; self.demand = demand
    }
}

enum NetworkFlowDraftIssue: Equatable, Sendable {
    case emptyTitle
    case emptyNodeName(UUID)
    case invalidBalance(UUID)
    case missingArcEndpoint(UUID)
    case danglingArcEndpoint(UUID)
    case invalidArcCost(UUID)

    var message: String {
        switch self {
        case .emptyTitle: "Model title must not be empty."
        case .emptyNodeName: "Node names must not be empty."
        case .invalidBalance: "Enter finite numeric supply and demand values."
        case .missingArcEndpoint: "Choose both endpoints for this arc."
        case .danglingArcEndpoint: "This arc refers to a node that no longer exists."
        case .invalidArcCost: "Enter a finite nonnegative arc cost."
        }
    }
}

enum NetworkFlowDraftError: Error, Equatable, CustomStringConvertible {
    case issues([NetworkFlowDraftIssue])

    var issues: [NetworkFlowDraftIssue] {
        if case .issues(let value) = self { return value }
        return []
    }

    var description: String {
        issues.map(\.message).joined(separator: " ")
    }
}

struct NetworkFlowDraft: Equatable, Sendable {
    var title: String
    var nodes: [NetworkFlowNodeDraft]
    var arcs: [NetworkArcDraft]

    init(title: String = "New Minimum-Cost Transshipment", nodes: [NetworkFlowNodeDraft], arcs: [NetworkArcDraft]) {
        self.title = title; self.nodes = nodes; self.arcs = arcs
    }

    static func blank() -> Self {
        Self(
            nodes: [
                NetworkFlowNodeDraft(name: "Node 1", supply: "10", demand: "0"),
                NetworkFlowNodeDraft(name: "Node 2", supply: "0", demand: "10")
            ],
            arcs: [NetworkArcDraft(costText: "1")]
        )
    }

    init(_ model: MinimumCostNetworkFlowProblem) {
        title = model.title
        nodes = model.nodes.indices.map { index in
            NetworkFlowNodeDraft(
                name: model.nodes[index],
                supply: model.supply.indices.contains(index) ? Self.format(model.supply[index]) : "",
                demand: model.demand.indices.contains(index) ? Self.format(model.demand[index]) : ""
            )
        }
        var ids: [String: UUID] = [:]
        for node in nodes where ids[node.name] == nil {
            ids[node.name] = node.id
        }
        arcs = model.arcs.map { arc in NetworkArcDraft(fromNodeID: ids[arc.from], toNodeID: ids[arc.to], costText: Self.format(arc.cost)) }
    }

    init?(envelope: NetworkModelEnvelope) {
        guard case .minimumCostFlow(let model) = envelope else { return nil }
        self.init(model)
    }

    func draftIssues() -> [NetworkFlowDraftIssue] {
        var issues: [NetworkFlowDraftIssue] = []
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append(.emptyTitle) }
        let ids = Set(nodes.map(\.id))
        for node in nodes {
            if node.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append(.emptyNodeName(node.id)) }
            if finite(node.supply) == nil || finite(node.demand) == nil { issues.append(.invalidBalance(node.id)) }
        }
        for arc in arcs {
            guard let from = arc.fromNodeID, let to = arc.toNodeID else { issues.append(.missingArcEndpoint(arc.id)); continue }
            if !ids.contains(from) || !ids.contains(to) { issues.append(.danglingArcEndpoint(arc.id)) }
            if let cost = finite(arc.costText), cost >= 0 {
                continue
            }
            issues.append(.invalidArcCost(arc.id))
        }
        return issues
    }

    func makeModel() throws -> MinimumCostNetworkFlowProblem {
        let issues = draftIssues()
        guard issues.isEmpty else { throw NetworkFlowDraftError.issues(issues) }
        let names = nodes.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        return MinimumCostNetworkFlowProblem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            nodes: names,
            arcs: arcs.compactMap { arc in
                guard let fromID = arc.fromNodeID, let toID = arc.toNodeID,
                      let from = nodes.first(where: { $0.id == fromID })?.name,
                      let to = nodes.first(where: { $0.id == toID })?.name,
                      let cost = finite(arc.costText) else { return nil }
                return NetworkArc(from: from, to: to, cost: cost)
            },
            supply: nodes.compactMap { finite($0.supply) },
            demand: nodes.compactMap { finite($0.demand) }
        )
    }

    @discardableResult
    mutating func addNode(name: String? = nil) -> UUID {
        let node = NetworkFlowNodeDraft(name: name ?? "Node \(nodes.count + 1)")
        nodes.append(node)
        return node.id
    }

    mutating func removeNode(id: UUID) {
        nodes.removeAll { $0.id == id }
        arcs.removeAll { $0.fromNodeID == id || $0.toNodeID == id }
    }

    @discardableResult
    mutating func addArc(from: UUID? = nil, to: UUID? = nil, costText: String = "0") -> UUID {
        let arc = NetworkArcDraft(fromNodeID: from ?? nodes.first?.id, toNodeID: to ?? nodes.dropFirst().first?.id, costText: costText)
        arcs.append(arc)
        return arc.id
    }

    mutating func removeArc(id: UUID) { arcs.removeAll { $0.id == id } }

    private func finite(_ text: String) -> Double? {
        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)), value.isFinite else { return nil }
        return value
    }

    private static func format(_ value: Double) -> String { String(value) }
}
