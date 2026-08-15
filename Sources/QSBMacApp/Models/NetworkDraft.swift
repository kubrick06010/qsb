import Foundation
import QSBCore

enum NetworkDraftKind: String, CaseIterable, Identifiable {
    case shortestPath
    case minimumSpanningTree
    case maxFlow
    case travelingSalesperson

    var id: String { rawValue }

    var problemKind: NetworkProblemKind {
        switch self {
        case .shortestPath: .shortestPath
        case .minimumSpanningTree: .minimumSpanningTree
        case .maxFlow: .maxFlow
        case .travelingSalesperson: .travelingSalesperson
        }
    }

    var displayName: String {
        switch self {
        case .shortestPath: "Shortest Path"
        case .minimumSpanningTree: "Minimum Spanning Tree"
        case .maxFlow: "Maximum Flow"
        case .travelingSalesperson: "Traveling Salesperson"
        }
    }

    var usesDirectedArcs: Bool {
        switch self {
        case .minimumSpanningTree: false
        case .shortestPath, .maxFlow, .travelingSalesperson: true
        }
    }

    var requiresSourceAndSink: Bool {
        self == .shortestPath || self == .maxFlow
    }

    var requiresSource: Bool {
        self == .travelingSalesperson || requiresSourceAndSink
    }
}

struct NetworkDraftPosition: Equatable, Sendable {
    var x: Double
    var y: Double
}

struct NetworkNodeDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var position: NetworkDraftPosition

    init(id: UUID = UUID(), name: String, position: NetworkDraftPosition) {
        self.id = id
        self.name = name
        self.position = position
    }
}

struct NetworkArcDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var fromNodeID: UUID?
    var toNodeID: UUID?
    var costText: String

    init(id: UUID = UUID(), fromNodeID: UUID? = nil, toNodeID: UUID? = nil, costText: String = "0") {
        self.id = id
        self.fromNodeID = fromNodeID
        self.toNodeID = toNodeID
        self.costText = costText
    }
}

enum NetworkDraftIssue: Equatable, Sendable {
    case emptyTitle
    case emptyNodeName(UUID)
    case duplicateNodeName(String)
    case missingArcEndpoint(UUID)
    case danglingArcEndpoint(UUID)
    case invalidArcCost(UUID)
    case missingSource
    case missingSink
    case sourceAndSinkMustDiffer

    var message: String {
        switch self {
        case .emptyTitle: "Model title must not be empty."
        case .emptyNodeName: "Node names must not be empty."
        case .duplicateNodeName(let name): "Node name ‘\(name)’ is used more than once."
        case .missingArcEndpoint: "Choose both endpoints for this arc."
        case .danglingArcEndpoint: "This arc refers to a node that no longer exists."
        case .invalidArcCost: "Enter a finite nonnegative cost or capacity."
        case .missingSource: "Choose a source node."
        case .missingSink: "Choose a sink node."
        case .sourceAndSinkMustDiffer: "Source and sink must be different nodes."
        }
    }
}

enum NetworkDraftError: Error, Equatable, CustomStringConvertible {
    case issues([NetworkDraftIssue])

    var description: String {
        switch self {
        case .issues(let issues):
            issues.map(\.message).joined(separator: " ")
        }
    }
}

struct NetworkDraft: Equatable, Sendable {
    var kind: NetworkDraftKind
    var title: String
    var nodes: [NetworkNodeDraft]
    var arcs: [NetworkArcDraft]
    var sourceNodeID: UUID?
    var sinkNodeID: UUID?

    static func blank(_ kind: NetworkDraftKind) -> Self {
        let first = NetworkNodeDraft(name: "Node 1", position: .init(x: 0.28, y: 0.5))
        let second = NetworkNodeDraft(name: "Node 2", position: .init(x: 0.72, y: 0.5))
        return Self(
            kind: kind,
            title: kind.displayName,
            nodes: [first, second],
            arcs: [NetworkArcDraft(fromNodeID: first.id, toNodeID: second.id)],
            sourceNodeID: kind.requiresSource ? first.id : nil,
            sinkNodeID: kind.requiresSourceAndSink ? second.id : nil
        )
    }

    init(
        kind: NetworkDraftKind,
        title: String,
        nodes: [NetworkNodeDraft],
        arcs: [NetworkArcDraft],
        sourceNodeID: UUID? = nil,
        sinkNodeID: UUID? = nil
    ) {
        self.kind = kind
        self.title = title
        self.nodes = nodes
        self.arcs = arcs
        self.sourceNodeID = sourceNodeID
        self.sinkNodeID = sinkNodeID
    }

    init?(envelope: NetworkModelEnvelope) {
        let kind: NetworkDraftKind
        let title: String
        let names: [String]
        let modelArcs: [NetworkArc]

        switch envelope {
        case .shortestPath(let model):
            kind = .shortestPath; title = model.title; names = model.nodes; modelArcs = model.arcs
        case .minimumSpanningTree(let model):
            kind = .minimumSpanningTree; title = model.title; names = model.nodes; modelArcs = model.edges
        case .maxFlow(let model):
            kind = .maxFlow; title = model.title; names = model.nodes; modelArcs = model.arcs
        case .travelingSalesperson(let model):
            kind = .travelingSalesperson; title = model.title; names = model.nodes; modelArcs = model.arcs
        case .minimumCostFlow, .assignment, .transportation:
            return nil
        }

        let draftNodes = names.enumerated().map { index, name in
            NetworkNodeDraft(
                name: name,
                position: Self.deterministicPosition(index: index, count: names.count)
            )
        }
        let idsByName = Dictionary(uniqueKeysWithValues: draftNodes.map { ($0.name, $0.id) })
        self.init(
            kind: kind,
            title: title,
            nodes: draftNodes,
            arcs: modelArcs.map { arc in
                NetworkArcDraft(
                    fromNodeID: idsByName[arc.from],
                    toNodeID: idsByName[arc.to],
                    costText: Self.number(arc.cost)
                )
            },
            sourceNodeID: kind.requiresSource ? draftNodes.first?.id : nil,
            sinkNodeID: kind.requiresSourceAndSink ? draftNodes.last?.id : nil
        )
    }

    func draftIssues() -> [NetworkDraftIssue] {
        var issues: [NetworkDraftIssue] = []
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append(.emptyTitle) }

        var seenNames = Set<String>()
        for node in nodes {
            let name = node.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty { issues.append(.emptyNodeName(node.id)) }
            if !name.isEmpty && !seenNames.insert(name).inserted { issues.append(.duplicateNodeName(name)) }
        }

        let nodeIDs = Set(nodes.map(\.id))
        for arc in arcs {
            guard let from = arc.fromNodeID, let to = arc.toNodeID else {
                issues.append(.missingArcEndpoint(arc.id))
                continue
            }
            guard nodeIDs.contains(from), nodeIDs.contains(to) else {
                issues.append(.danglingArcEndpoint(arc.id))
                continue
            }
            guard let cost = Double(arc.costText.trimmingCharacters(in: .whitespacesAndNewlines)), cost.isFinite, cost >= 0 else {
                issues.append(.invalidArcCost(arc.id))
                continue
            }
            _ = cost
        }

        if kind.requiresSource {
            if let sourceNodeID {
                if !nodeIDs.contains(sourceNodeID) { issues.append(.missingSource) }
            } else {
                issues.append(.missingSource)
            }
        }
        if kind.requiresSourceAndSink {
            if let sinkNodeID {
                if !nodeIDs.contains(sinkNodeID) { issues.append(.missingSink) }
            } else {
                issues.append(.missingSink)
            }
            if let sourceNodeID, let sinkNodeID, sourceNodeID == sinkNodeID {
                issues.append(.sourceAndSinkMustDiffer)
            }
        }
        return issues
    }

    func makeNetworkModel() throws -> NetworkModelEnvelope {
        let issues = draftIssues()
        guard issues.isEmpty else { throw NetworkDraftError.issues(issues) }

        let nodeByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.name.trimmingCharacters(in: .whitespacesAndNewlines)) })
        let modelNodes = orderedNodeNames(nodeByID: nodeByID)
        let modelArcs = try arcs.map { arc -> NetworkArc in
            guard let fromID = arc.fromNodeID, let toID = arc.toNodeID,
                  let from = nodeByID[fromID], let to = nodeByID[toID],
                  let cost = Double(arc.costText.trimmingCharacters(in: .whitespacesAndNewlines))
            else { throw NetworkDraftError.issues([.danglingArcEndpoint(arc.id)]) }
            return NetworkArc(from: from, to: to, cost: cost)
        }

        switch kind {
        case .shortestPath: return .shortestPath(.init(title: title, nodes: modelNodes, arcs: modelArcs))
        case .minimumSpanningTree: return .minimumSpanningTree(.init(title: title, nodes: modelNodes, edges: modelArcs))
        case .maxFlow: return .maxFlow(.init(title: title, nodes: modelNodes, arcs: modelArcs))
        case .travelingSalesperson: return .travelingSalesperson(.init(title: title, nodes: modelNodes, arcs: modelArcs))
        }
    }

    mutating func addNode(name: String? = nil) -> UUID {
        let node = NetworkNodeDraft(
            name: name ?? "Node \(nodes.count + 1)",
            position: Self.deterministicPosition(index: nodes.count, count: nodes.count + 1)
        )
        nodes.append(node)
        if kind.requiresSource && sourceNodeID == nil { sourceNodeID = node.id }
        if kind.requiresSourceAndSink && sinkNodeID == nil { sinkNodeID = node.id }
        return node.id
    }

    mutating func removeNode(id: UUID) {
        nodes.removeAll { $0.id == id }
        arcs.removeAll { $0.fromNodeID == id || $0.toNodeID == id }
        if sourceNodeID == id { sourceNodeID = nodes.first?.id }
        if sinkNodeID == id { sinkNodeID = nodes.last?.id }
    }

    mutating func addArc(from: UUID? = nil, to: UUID? = nil, costText: String = "0") -> UUID {
        let arc = NetworkArcDraft(id: UUID(), fromNodeID: from, toNodeID: to, costText: costText)
        arcs.append(arc)
        return arc.id
    }

    mutating func removeArc(id: UUID) {
        arcs.removeAll { $0.id == id }
    }

    private func orderedNodeNames(nodeByID: [UUID: String]) -> [String] {
        guard kind.requiresSource else { return nodes.compactMap { nodeByID[$0.id] } }
        let source = sourceNodeID.flatMap { nodeByID[$0] }
        let sink = sinkNodeID.flatMap { nodeByID[$0] }
        var result = nodes.compactMap { nodeByID[$0.id] }
        if let source, let index = result.firstIndex(of: source) { result.remove(at: index); result.insert(source, at: 0) }
        if kind.requiresSourceAndSink, let sink, let index = result.firstIndex(of: sink) { result.remove(at: index); result.append(sink) }
        return result
    }

    private static func deterministicPosition(index: Int, count: Int) -> NetworkDraftPosition {
        guard count > 0 else { return .init(x: 0.5, y: 0.5) }
        let angle = (Double(index) / Double(count)) * (Double.pi * 2) - Double.pi / 2
        return .init(x: 0.5 + cos(angle) * 0.34, y: 0.5 + sin(angle) * 0.34)
    }

    private static func number(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }
}
