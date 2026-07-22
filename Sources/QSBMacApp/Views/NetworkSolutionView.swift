import Foundation
import QSBCore
import SwiftUI

struct NetworkSolutionView: View {
    let document: NetworkSolutionDocument

    @State private var showInactiveConnections = false
    @State private var zoom = 1.0

    private var diagram: NetworkDiagramData {
        NetworkDiagramData(document: document)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summary
            Divider()
            controls
            Divider()

            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 0) {
                            diagramView
                                .frame(minWidth: 560, minHeight: 430)
                            Divider()
                            detail
                                .frame(width: 340)
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            diagramView
                                .frame(minWidth: 560, minHeight: 430)
                            Divider()
                            detail
                                .frame(minWidth: 560)
                        }
                    }
                    .frame(
                        minWidth: geometry.size.width,
                        minHeight: geometry.size.height,
                        alignment: .topLeading
                    )
                }
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 3) {
                Text(document.model.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(diagram.kindLabel) · \(document.backend.algorithm)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 16)

            metric(value: diagram.objectiveValue, label: diagram.objectiveLabel)
            metric(value: "\(diagram.nodes.count)", label: "Nodes")
            metric(value: "\(diagram.activeEdges.count)", label: diagram.connectionLabel)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Toggle("All connections", isOn: $showInactiveConnections)
                .toggleStyle(.checkbox)

            Divider()
                .frame(height: 18)

            Label("Scale", systemImage: "arrow.up.left.and.arrow.down.right")
                .font(.callout)
            Slider(value: $zoom, in: 0.75...1.6, step: 0.05)
                .frame(width: 140)
            Text("\(Int((zoom * 100).rounded()))%")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
            Button {
                zoom = 1
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .help("Reset diagram scale")

            Spacer()

            Text(exactnessLabel)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    private var diagramView: some View {
        NetworkDiagramCanvas(
            data: diagram,
            showInactiveConnections: showInactiveConnections,
            zoom: zoom
        )
        .padding(18)
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(diagram.detailTitle)
                    .font(.headline)
                Spacer()
                Text("\(diagram.detailRows.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(16)

            Divider()

            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(diagram.detailRows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.primary)
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                            if let secondary = row.secondary {
                                Text(secondary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 8)
                        Text(row.value)
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    Divider()
                }
            }

            if let note = diagram.note {
                Label(note, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(16)
            }
        }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var exactnessLabel: String {
        switch document.backend.exactness {
        case .exact: "Exact"
        case .closedForm: "Closed form"
        case .fixtureScale: "Fixture scale"
        case .heuristic: "Heuristic"
        case .approximate: "Approximate"
        }
    }
}

private struct NetworkDiagramCanvas: View {
    let data: NetworkDiagramData
    let showInactiveConnections: Bool
    let zoom: Double

    private let nodeDiameter: CGFloat = 48

    var body: some View {
        GeometryReader { geometry in
            let size = CGSize(
                width: max(geometry.size.width, 500) * zoom,
                height: max(geometry.size.height, 390) * zoom
            )
            let positions = data.positions(in: size, inset: 72)
            let visibleEdges = data.edges.filter { showInactiveConnections || $0.isActive }

            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    for edge in visibleEdges {
                        guard let from = positions[edge.from], let to = positions[edge.to] else { continue }
                        draw(edge, from: from, to: to, in: &context)
                    }
                }

                ForEach(Array(visibleEdges.enumerated()), id: \.element.id) { index, edge in
                    if let from = positions[edge.from], let to = positions[edge.to] {
                        Text(edge.label)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(edge.isActive ? Color.primary : Color.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 3))
                            .position(labelPosition(from: from, to: to, index: index))
                    }
                }

                ForEach(data.nodes) { node in
                    if let position = positions[node.id] {
                        VStack(spacing: 3) {
                            ZStack {
                                Circle()
                                    .fill(nodeFill(node))
                                Circle()
                                    .stroke(nodeStroke(node), lineWidth: node.isActive ? 3 : 1.5)
                                Text(node.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(nodeText(node))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.55)
                                    .padding(5)
                            }
                            .frame(width: nodeDiameter, height: nodeDiameter)

                            if let role = node.role {
                                Text(role)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .position(x: position.x, y: position.y + (node.role == nil ? 0 : 8))
                        .help(node.help)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(node.help)
                    }
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
    }

    private func draw(
        _ edge: NetworkDiagramEdge,
        from: CGPoint,
        to: CGPoint,
        in context: inout GraphicsContext
    ) {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let radius = nodeDiameter / 2 + 2
        let start = CGPoint(x: from.x + cos(angle) * radius, y: from.y + sin(angle) * radius)
        let end = CGPoint(x: to.x - cos(angle) * radius, y: to.y - sin(angle) * radius)
        let color = edge.isActive ? Color.accentColor : Color.secondary.opacity(0.28)
        let width: CGFloat = edge.isActive ? 3 : 1

        var line = Path()
        line.move(to: start)
        line.addLine(to: end)
        context.stroke(line, with: .color(color), lineWidth: width)

        guard edge.isDirected else { return }
        let arrowLength: CGFloat = edge.isActive ? 11 : 8
        let arrowWidth: CGFloat = edge.isActive ? 6 : 4
        let base = CGPoint(x: end.x - cos(angle) * arrowLength, y: end.y - sin(angle) * arrowLength)
        let perpendicular = CGPoint(x: -sin(angle) * arrowWidth, y: cos(angle) * arrowWidth)
        var arrow = Path()
        arrow.move(to: end)
        arrow.addLine(to: CGPoint(x: base.x + perpendicular.x, y: base.y + perpendicular.y))
        arrow.addLine(to: CGPoint(x: base.x - perpendicular.x, y: base.y - perpendicular.y))
        arrow.closeSubpath()
        context.fill(arrow, with: .color(color))
    }

    private func labelPosition(from: CGPoint, to: CGPoint, index: Int) -> CGPoint {
        let midpoint = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
        let length = max(hypot(to.x - from.x, to.y - from.y), 1)
        let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
        return CGPoint(
            x: midpoint.x - (to.y - from.y) / length * 10 * direction,
            y: midpoint.y + (to.x - from.x) / length * 10 * direction
        )
    }

    private func nodeFill(_ node: NetworkDiagramNode) -> Color {
        switch node.role {
        case "Source", "Supply": Color.green.opacity(0.18)
        case "Sink", "Demand": Color.orange.opacity(0.18)
        default: node.isActive ? Color.accentColor.opacity(0.16) : Color(nsColor: .controlBackgroundColor)
        }
    }

    private func nodeStroke(_ node: NetworkDiagramNode) -> Color {
        node.isActive ? .accentColor : .secondary.opacity(0.55)
    }

    private func nodeText(_ node: NetworkDiagramNode) -> Color {
        node.isActive ? .primary : .secondary
    }
}

private struct NetworkDiagramData {
    let kind: NetworkProblemKind
    let nodes: [NetworkDiagramNode]
    let edges: [NetworkDiagramEdge]
    let layout: NetworkDiagramLayout
    let objectiveLabel: String
    let objectiveValue: String
    let detailTitle: String
    let detailRows: [NetworkDetailRow]
    let note: String?

    var activeEdges: [NetworkDiagramEdge] { edges.filter(\.isActive) }
    var kindLabel: String { kind.displayName }
    var connectionLabel: String { kind == .minimumSpanningTree ? "Tree edges" : "Active" }

    init(document: NetworkSolutionDocument) {
        kind = document.model.kind

        switch (document.model, document.solution) {
        case (.shortestPath(let model), .shortestPath(let solution)):
            let selected = DirectedConnection.keys(for: solution.path)
            nodes = Self.graphNodes(model.nodes, active: selected.nodes, source: solution.source, sink: solution.sink)
            edges = model.arcs.enumerated().map { index, arc in
                NetworkDiagramEdge(id: index, from: arc.from, to: arc.to, label: Self.number(arc.cost), isActive: selected.edges.contains(.init(arc.from, arc.to)), isDirected: true)
            }
            layout = .circular
            objectiveLabel = "Path cost"
            objectiveValue = Self.number(solution.totalCost)
            detailTitle = "Route"
            detailRows = zip(solution.path, solution.path.dropFirst()).map { from, to in
                let cost = model.arcs.first { $0.from == from && $0.to == to }?.cost ?? 0
                return NetworkDetailRow(primary: "\(from) → \(to)", secondary: "Arc cost", value: Self.number(cost))
            }
            note = "Only the chosen route is highlighted."

        case (.minimumSpanningTree(let model), .minimumSpanningTree(let solution)):
            let selected = Set(solution.edges.map { UndirectedConnection($0.from, $0.to) })
            let activeNodes = Set(solution.edges.flatMap { [$0.from, $0.to] })
            nodes = Self.graphNodes(model.nodes, active: activeNodes)
            edges = model.edges.enumerated().map { index, edge in
                NetworkDiagramEdge(id: index, from: edge.from, to: edge.to, label: Self.number(edge.cost), isActive: selected.contains(.init(edge.from, edge.to)), isDirected: false)
            }
            layout = .circular
            objectiveLabel = "Tree cost"
            objectiveValue = Self.number(solution.totalCost)
            detailTitle = "Tree edges"
            detailRows = solution.edges.map { NetworkDetailRow(primary: "\($0.from) — \($0.to)", secondary: "Edge cost", value: Self.number($0.cost)) }
            note = "The selected undirected edges form the minimum spanning tree."

        case (.maxFlow(let model), .maxFlow(let solution)):
            let flows = Dictionary(uniqueKeysWithValues: solution.arcFlows.map { (DirectedConnection($0.from, $0.to), $0.flow) })
            let active = Set(flows.filter { $0.value > 1e-8 }.map(\.key))
            nodes = Self.graphNodes(model.nodes, active: active.nodes, source: solution.source, sink: solution.sink)
            edges = model.arcs.enumerated().map { index, arc in
                let flow = flows[.init(arc.from, arc.to)] ?? 0
                return NetworkDiagramEdge(id: index, from: arc.from, to: arc.to, label: flow > 1e-8 ? "\(Self.number(flow)) / \(Self.number(arc.cost))" : Self.number(arc.cost), isActive: flow > 1e-8, isDirected: true)
            }
            layout = .circular
            objectiveLabel = "Maximum flow"
            objectiveValue = Self.number(solution.maxFlow)
            detailTitle = "Positive flows"
            detailRows = solution.arcFlows.filter { $0.flow > 1e-8 }.map { flow in
                let capacity = model.arcs.first { $0.from == flow.from && $0.to == flow.to }?.cost ?? 0
                return NetworkDetailRow(primary: "\(flow.from) → \(flow.to)", secondary: "Flow / capacity", value: "\(Self.number(flow.flow)) / \(Self.number(capacity))")
            }
            note = "Active labels show flow / capacity."

        case (.travelingSalesperson(let model), .travelingSalesperson(let solution)):
            let selected = DirectedConnection.keys(for: solution.tour)
            nodes = Self.graphNodes(model.nodes, active: selected.nodes, source: solution.source)
            edges = model.arcs.enumerated().map { index, arc in
                NetworkDiagramEdge(id: index, from: arc.from, to: arc.to, label: Self.number(arc.cost), isActive: selected.edges.contains(.init(arc.from, arc.to)), isDirected: true)
            }
            layout = .circular
            objectiveLabel = "Tour cost"
            objectiveValue = Self.number(solution.totalCost)
            detailTitle = "Tour"
            detailRows = zip(solution.tour, solution.tour.dropFirst()).map { from, to in
                let cost = model.arcs.first { $0.from == from && $0.to == to }?.cost ?? 0
                return NetworkDetailRow(primary: "\(from) → \(to)", secondary: "Arc cost", value: Self.number(cost))
            }
            note = "The highlighted cycle starts and ends at \(solution.source)."

        case (.minimumCostFlow(let model), .minimumCostFlow(let solution)):
            let flows = Dictionary(uniqueKeysWithValues: solution.arcFlows.map { (DirectedConnection($0.from, $0.to), $0.quantity) })
            let active = Set(flows.filter { $0.value > 1e-8 }.map(\.key))
            let roles = Dictionary(uniqueKeysWithValues: model.nodes.enumerated().compactMap { index, node in
                if model.supply[index] > 1e-8 { return (node, "Supply") }
                if model.demand[index] > 1e-8 { return (node, "Demand") }
                return nil
            })
            nodes = Self.graphNodes(model.nodes, active: active.nodes, roles: roles)
            edges = model.arcs.enumerated().map { index, arc in
                let quantity = flows[.init(arc.from, arc.to)] ?? 0
                return NetworkDiagramEdge(id: index, from: arc.from, to: arc.to, label: quantity > 1e-8 ? "\(Self.number(quantity)) @ \(Self.number(arc.cost))" : Self.number(arc.cost), isActive: quantity > 1e-8, isDirected: true)
            }
            layout = .circular
            objectiveLabel = "Minimum cost"
            objectiveValue = Self.number(solution.totalCost)
            detailTitle = "Positive flows"
            detailRows = solution.arcFlows.filter { $0.quantity > 1e-8 }.map { NetworkDetailRow(primary: "\($0.from) → \($0.to)", secondary: "Quantity @ unit cost", value: "\(Self.number($0.quantity)) @ \(Self.number($0.unitCost))") } + solution.balanceAdjustments.map { NetworkDetailRow(primary: $0.node, secondary: $0.kind, value: Self.number($0.quantity)) }
            note = solution.balanceAdjustments.isEmpty ? "Active labels show quantity @ unit cost." : "Dummy balance adjustments are included in the detail list."

        case (.assignment(let model), .assignment(let solution)):
            let selected = Set(solution.assignments.map { DirectedConnection($0.worker, $0.task) })
            let workerIDs = Dictionary(uniqueKeysWithValues: model.workers.map { ($0, "worker:\($0)") })
            let taskIDs = Dictionary(uniqueKeysWithValues: model.tasks.map { ($0, "task:\($0)") })
            nodes = model.workers.map { NetworkDiagramNode(id: workerIDs[$0]!, label: $0, role: "Worker", isActive: selected.nodes.contains($0), help: "\($0), worker") }
                + model.tasks.map { NetworkDiagramNode(id: taskIDs[$0]!, label: $0, role: "Task", isActive: selected.nodes.contains($0), help: "\($0), task") }
            edges = model.workers.enumerated().flatMap { workerIndex, worker in
                model.tasks.enumerated().map { taskIndex, task in
                    let id = workerIndex * model.tasks.count + taskIndex
                    return NetworkDiagramEdge(id: id, from: workerIDs[worker]!, to: taskIDs[task]!, label: Self.number(model.costs[workerIndex][taskIndex]), isActive: selected.contains(.init(worker, task)), isDirected: false)
                }
            }
            layout = .bipartite(left: model.workers.map { workerIDs[$0]! }, right: model.tasks.map { taskIDs[$0]! })
            objectiveLabel = "Assignment cost"
            objectiveValue = Self.number(solution.totalCost)
            detailTitle = "Assignments"
            detailRows = solution.assignments.map { NetworkDetailRow(primary: "\($0.worker) → \($0.task)", secondary: "Assignment cost", value: Self.number($0.cost)) }
            note = "Enable all connections to compare the full cost matrix."

        case (.transportation(let model), .transportation(let solution)):
            let shipments = Dictionary(uniqueKeysWithValues: solution.shipments.map { (DirectedConnection($0.origin, $0.destination), $0.quantity) })
            let active = Set(shipments.filter { $0.value > 1e-8 }.map(\.key))
            let originIDs = Dictionary(uniqueKeysWithValues: model.origins.map { ($0, "origin:\($0)") })
            let destinationIDs = Dictionary(uniqueKeysWithValues: model.destinations.map { ($0, "destination:\($0)") })
            nodes = model.origins.map { NetworkDiagramNode(id: originIDs[$0]!, label: $0, role: "Origin", isActive: active.nodes.contains($0), help: "\($0), origin") }
                + model.destinations.map { NetworkDiagramNode(id: destinationIDs[$0]!, label: $0, role: "Destination", isActive: active.nodes.contains($0), help: "\($0), destination") }
            edges = model.origins.enumerated().flatMap { originIndex, origin in
                model.destinations.enumerated().map { destinationIndex, destination in
                    let quantity = shipments[.init(origin, destination)] ?? 0
                    let cost = model.costs[originIndex][destinationIndex]
                    let id = originIndex * model.destinations.count + destinationIndex
                    return NetworkDiagramEdge(id: id, from: originIDs[origin]!, to: destinationIDs[destination]!, label: quantity > 1e-8 ? "\(Self.number(quantity)) @ \(Self.number(cost))" : Self.number(cost), isActive: quantity > 1e-8, isDirected: true)
                }
            }
            layout = .bipartite(left: model.origins.map { originIDs[$0]! }, right: model.destinations.map { destinationIDs[$0]! })
            objectiveLabel = "Transport cost"
            objectiveValue = Self.number(solution.totalCost)
            detailTitle = "Shipments"
            detailRows = solution.shipments.filter { $0.quantity > 1e-8 }.map { NetworkDetailRow(primary: "\($0.origin) → \($0.destination)", secondary: "Quantity @ unit cost", value: "\(Self.number($0.quantity)) @ \(Self.number($0.unitCost))") }
            note = "Active labels show quantity @ unit cost."

        default:
            nodes = []
            edges = []
            layout = .circular
            objectiveLabel = "Result"
            objectiveValue = "—"
            detailTitle = "Connections"
            detailRows = []
            note = "The model and solution kinds do not match."
        }
    }

    func positions(in size: CGSize, inset: CGFloat) -> [String: CGPoint] {
        switch layout {
        case .circular:
            guard !nodes.isEmpty else { return [:] }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radiusX = max(80, size.width / 2 - inset)
            let radiusY = max(80, size.height / 2 - inset - 12)
            var result: [String: CGPoint] = [:]
            for (index, node) in nodes.enumerated() {
                let angle = -Double.pi / 2 + 2 * Double.pi * Double(index) / Double(nodes.count)
                let x = center.x + cos(angle) * radiusX
                let y = center.y + sin(angle) * radiusY
                result[node.id] = CGPoint(x: x, y: y)
            }
            return result
        case .bipartite(let left, let right):
            var result: [String: CGPoint] = [:]
            for (index, node) in left.enumerated() {
                result[node] = CGPoint(x: inset, y: Self.columnY(index: index, count: left.count, height: size.height, inset: inset))
            }
            for (index, node) in right.enumerated() {
                result[node] = CGPoint(x: size.width - inset, y: Self.columnY(index: index, count: right.count, height: size.height, inset: inset))
            }
            return result
        }
    }

    private static func columnY(index: Int, count: Int, height: CGFloat, inset: CGFloat) -> CGFloat {
        guard count > 1 else { return height / 2 }
        return inset + CGFloat(index) * (height - 2 * inset) / CGFloat(count - 1)
    }

    private static func graphNodes(
        _ names: [String],
        active: Set<String>,
        source: String? = nil,
        sink: String? = nil,
        roles: [String: String] = [:]
    ) -> [NetworkDiagramNode] {
        names.map { name in
            let role = name == source ? "Source" : name == sink ? "Sink" : roles[name]
            return NetworkDiagramNode(id: name, label: name, role: role, isActive: active.contains(name), help: role.map { "\(name), \($0.lowercased())" } ?? name)
        }
    }

    private static func number(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 1e-8 { return String(Int(rounded)) }
        return String(format: "%.3f", value)
    }
}

private struct NetworkDiagramNode: Identifiable {
    let id: String
    let label: String
    let role: String?
    let isActive: Bool
    let help: String
}

private struct NetworkDiagramEdge: Identifiable {
    let id: Int
    let from: String
    let to: String
    let label: String
    let isActive: Bool
    let isDirected: Bool
}

private struct NetworkDetailRow: Identifiable {
    let id = UUID()
    let primary: String
    let secondary: String?
    let value: String
}

private enum NetworkDiagramLayout {
    case circular
    case bipartite(left: [String], right: [String])
}

private struct DirectedConnection: Hashable {
    let from: String
    let to: String

    init(_ from: String, _ to: String) {
        self.from = from
        self.to = to
    }

    static func keys(for sequence: [String]) -> (edges: Set<DirectedConnection>, nodes: Set<String>) {
        (Set(zip(sequence, sequence.dropFirst()).map(DirectedConnection.init)), Set(sequence))
    }
}

private extension Set where Element == DirectedConnection {
    var nodes: Set<String> { Swift.Set<String>(flatMap { [$0.from, $0.to] }) }
}

private struct UndirectedConnection: Hashable {
    let first: String
    let second: String

    init(_ lhs: String, _ rhs: String) {
        if lhs <= rhs {
            first = lhs
            second = rhs
        } else {
            first = rhs
            second = lhs
        }
    }
}

private extension NetworkProblemKind {
    var displayName: String {
        switch self {
        case .minimumCostFlow: "Minimum-cost flow"
        case .shortestPath: "Shortest path"
        case .minimumSpanningTree: "Minimum spanning tree"
        case .maxFlow: "Maximum flow"
        case .travelingSalesperson: "Traveling salesperson"
        case .assignment: "Assignment"
        case .transportation: "Transportation"
        }
    }
}
