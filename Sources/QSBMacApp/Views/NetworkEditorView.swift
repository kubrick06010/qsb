import SwiftUI
import QSBCore

struct NetworkEditorView: View {
    @Bindable var workspace: QSBWorkspace

    @State private var selectedNodeID: UUID?
    @State private var selectedArcID: UUID?
    @State private var addArcFrom: UUID?
    @State private var addArcTo: UUID?

    private var draft: NetworkDraft? { workspace.networkDraft }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if let draft {
                HStack(alignment: .top, spacing: 0) {
                    ScrollView([.vertical, .horizontal]) {
                        NetworkGraphCanvas(
                            draft: draft,
                            selectedNodeID: selectedNodeID,
                            selectedArcID: selectedArcID,
                            onSelectNode: selectNode,
                            onSelectArc: selectArc
                        )
                        .frame(minWidth: 580, minHeight: 440)
                        .padding(18)
                    }
                    Divider()
                    inspector(draft)
                        .frame(width: 320)
                }
            } else {
                ContentUnavailableView("No Network draft", systemImage: "point.3.connected.trianglepath.dotted", description: Text("Choose a graph-native Network variant from New Model."))
            }
        }
        .navigationTitle("Network Definition")
        .onAppear(perform: setDefaultArcEndpoints)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(workspace.modelTitle)
                        .font(.title2.weight(.semibold))
                    Text("Native graph editor · \(workspace.networkDraft?.kind.displayName ?? "Network") · \(workspace.modelState.rawValue)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Validate") { workspace.validateCurrentModel() }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                    .help("Validate model (⌘⇧V)")
                    .accessibilityIdentifier("network-validate")
                Button("Run") { workspace.runCurrentModel() }
                    .keyboardShortcut("r", modifiers: [.command])
                    .buttonStyle(.borderedProminent)
                    .disabled(workspace.modelState == .invalid || workspace.runState == .solving)
                    .accessibilityIdentifier("network-run")
            }
            if let draft {
                HStack(spacing: 12) {
                    TextField("Model title", text: titleBinding)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)
                        .accessibilityLabel("Network model title")
                    Picker("Problem", selection: kindBinding) {
                        ForEach(NetworkDraftKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .frame(width: 220)
                    Text("\(draft.nodes.count) nodes · \(draft.arcs.count) \(draft.kind.usesDirectedArcs ? "arcs" : "edges")")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("network-node-count")
                    Spacer()
                }
                .padding(.bottom, 10)
            }
            draftIssuesView
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var draftIssuesView: some View {
        if let issues = draft?.draftIssues(), !issues.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                    Label(issue.message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.bottom, 4)
        }
    }

    private func inspector(_ draft: NetworkDraft) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                modelProperties(draft)
                Divider()
                if let selectedNodeID, let index = draft.nodes.firstIndex(where: { $0.id == selectedNodeID }) {
                    nodeProperties(index: index, draft: draft)
                } else if let selectedArcID, let index = draft.arcs.firstIndex(where: { $0.id == selectedArcID }) {
                    arcProperties(index: index, draft: draft)
                } else {
                    selectionHelp(draft)
                }
                Divider()
                accessibleNodeList(draft)
                accessibleArcList(draft)
            }
            .padding(16)
        }
        .accessibilityElement(children: .contain)
    }

    private func modelProperties(_ draft: NetworkDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Model properties").font(.headline)
            Button("Add Node", systemImage: "plus.circle") {
                workspace.updateNetworkDraft { draft in
                    let id = draft.addNode()
                    selectedNodeID = id
                    selectedArcID = nil
                }
            }
            .accessibilityIdentifier("network-add-node")
            HStack {
                Text("Nodes")
                Spacer()
                Text("\(draft.nodes.count)").monospacedDigit()
            }
            .accessibilityValue("\(draft.nodes.count) nodes")
            if draft.kind.requiresSource {
                nodePicker(title: "Source", selection: sourceBinding, draft: draft)
            }
            if draft.kind.requiresSourceAndSink {
                nodePicker(title: "Sink", selection: sinkBinding, draft: draft)
            }
            HStack {
                Text("Connections")
                Spacer()
                Text("\(draft.arcs.count)").monospacedDigit()
            }
            .accessibilityValue("\(draft.arcs.count) connections")
            Text("\(draft.arcs.count) connections")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("network-edge-count")
            addArcControls(draft)
            Button("Delete Selection", systemImage: "trash", role: .destructive) {
                deleteSelection()
            }
            .disabled(selectedNodeID == nil && selectedArcID == nil)
            .accessibilityIdentifier("network-delete-selection")
        }
    }

    private func addArcControls(_ draft: NetworkDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add \(draft.kind.usesDirectedArcs ? "arc" : "edge")")
                .font(.subheadline.weight(.medium))
            nodePicker(title: "From", selection: $addArcFrom, draft: draft)
            nodePicker(title: "To", selection: $addArcTo, draft: draft)
            Button("Add \(draft.kind.usesDirectedArcs ? "Arc" : "Edge")", systemImage: "arrow.right.circle") {
                guard let from = addArcFrom, let to = addArcTo else { return }
                workspace.updateNetworkDraft { draft in
                    let id = draft.addArc(from: from, to: to)
                    selectedArcID = id
                    selectedNodeID = nil
                }
            }
            .disabled(addArcFrom == nil || addArcTo == nil)
            .accessibilityIdentifier("network-add-arc")
        }
    }

    private func nodeProperties(index: Int, draft: NetworkDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Node properties").font(.headline)
            TextField("Name", text: nodeNameBinding(index))
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Node \(index + 1) name")
            Text("Node \(index + 1) of \(draft.nodes.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Delete Node", role: .destructive) { deleteSelection() }
                .disabled(draft.nodes.count <= 2)
        }
    }

    private func arcProperties(index: Int, draft: NetworkDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(draft.kind.usesDirectedArcs ? "Arc" : "Edge") properties").font(.headline)
            nodePicker(title: "From", selection: arcFromBinding(index), draft: draft)
            nodePicker(title: "To", selection: arcToBinding(index), draft: draft)
            TextField(draft.kind == .maxFlow ? "Capacity" : "Cost", text: arcCostBinding(index))
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(draft.kind == .maxFlow ? "Arc capacity" : "Arc cost")
            Button("Delete \(draft.kind.usesDirectedArcs ? "Arc" : "Edge")", role: .destructive) { deleteSelection() }
        }
    }

    private func selectionHelp(_ draft: NetworkDraft) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Selection").font(.headline)
            Text("Select a node or connection in the lists, or use the graph. Properties appear here.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("The graph uses deterministic layout positions for this editing session. Positions are not written to normalized JSON.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func accessibleNodeList(_ draft: NetworkDraft) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nodes").font(.headline)
            ForEach(Array(draft.nodes.enumerated()), id: \.element.id) { index, node in
                Button {
                    selectNode(node.id)
                } label: {
                    Label(node.name.isEmpty ? "Unnamed node \(index + 1)" : node.name, systemImage: selectedNodeID == node.id ? "circle.inset.filled" : "circle")
                }
                .buttonStyle(.link)
                .accessibilityLabel("Node \(node.name.isEmpty ? "\(index + 1)" : node.name)")
            }
        }
    }

    private func accessibleArcList(_ draft: NetworkDraft) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Connections").font(.headline)
            ForEach(Array(draft.arcs.enumerated()), id: \.element.id) { index, arc in
                let from = arc.fromNodeID.flatMap { id in draft.nodes.first { $0.id == id }?.name } ?? "?"
                let to = arc.toNodeID.flatMap { id in draft.nodes.first { $0.id == id }?.name } ?? "?"
                Button {
                    selectArc(arc.id)
                } label: {
                    Label("\(from) \(draft.kind.usesDirectedArcs ? "→" : "—") \(to) · \(arc.costText)", systemImage: selectedArcID == arc.id ? "line.diagonal" : "arrow.left.and.right")
                }
                .buttonStyle(.link)
                .accessibilityLabel("Connection \(index + 1), \(from) to \(to), \(arc.costText)")
            }
        }
    }

    private var titleBinding: Binding<String> {
        Binding(get: { workspace.networkDraft?.title ?? "" }, set: { value in workspace.updateNetworkDraft { $0.title = value } })
    }

    private var kindBinding: Binding<NetworkDraftKind> {
        Binding(get: { workspace.networkDraft?.kind ?? .shortestPath }, set: { kind in workspace.startNewNetwork(kind) })
    }

    private var sourceBinding: Binding<UUID?> {
        Binding(get: { workspace.networkDraft?.sourceNodeID }, set: { value in workspace.updateNetworkDraft { $0.sourceNodeID = value } })
    }

    private var sinkBinding: Binding<UUID?> {
        Binding(get: { workspace.networkDraft?.sinkNodeID }, set: { value in workspace.updateNetworkDraft { $0.sinkNodeID = value } })
    }

    private func nodePicker(title: String, selection: Binding<UUID?>, draft: NetworkDraft) -> some View {
        Picker(title, selection: selection) {
            Text("Choose…").tag(nil as UUID?)
            ForEach(draft.nodes) { node in
                Text(node.name.isEmpty ? "Unnamed" : node.name).tag(Optional(node.id))
            }
        }
        .labelsHidden()
        .accessibilityLabel(title)
    }

    private func nodeNameBinding(_ index: Int) -> Binding<String> {
        Binding(get: { workspace.networkDraft?.nodes[safe: index]?.name ?? "" }, set: { value in workspace.updateNetworkDraft { if $0.nodes.indices.contains(index) { $0.nodes[index].name = value } } })
    }

    private func arcFromBinding(_ index: Int) -> Binding<UUID?> {
        Binding(get: { workspace.networkDraft?.arcs[safe: index]?.fromNodeID }, set: { value in workspace.updateNetworkDraft { if $0.arcs.indices.contains(index) { $0.arcs[index].fromNodeID = value } } })
    }

    private func arcToBinding(_ index: Int) -> Binding<UUID?> {
        Binding(get: { workspace.networkDraft?.arcs[safe: index]?.toNodeID }, set: { value in workspace.updateNetworkDraft { if $0.arcs.indices.contains(index) { $0.arcs[index].toNodeID = value } } })
    }

    private func arcCostBinding(_ index: Int) -> Binding<String> {
        Binding(get: { workspace.networkDraft?.arcs[safe: index]?.costText ?? "" }, set: { value in workspace.updateNetworkDraft { if $0.arcs.indices.contains(index) { $0.arcs[index].costText = value } } })
    }

    private func setDefaultArcEndpoints() {
        guard let nodes = workspace.networkDraft?.nodes, addArcFrom == nil else { return }
        addArcFrom = nodes.first?.id
        addArcTo = nodes.dropFirst().first?.id ?? nodes.first?.id
    }

    private func selectNode(_ id: UUID) {
        selectedNodeID = id
        selectedArcID = nil
    }

    private func selectArc(_ id: UUID) {
        selectedArcID = id
        selectedNodeID = nil
    }

    private func deleteSelection() {
        if let selectedNodeID {
            workspace.updateNetworkDraft { $0.removeNode(id: selectedNodeID) }
        } else if let selectedArcID {
            workspace.updateNetworkDraft { $0.removeArc(id: selectedArcID) }
        }
        selectedNodeID = nil
        selectedArcID = nil
        setDefaultArcEndpoints()
    }
}

private struct NetworkGraphCanvas: View {
    let draft: NetworkDraft
    let selectedNodeID: UUID?
    let selectedArcID: UUID?
    let onSelectNode: (UUID) -> Void
    let onSelectArc: (UUID) -> Void

    var body: some View {
        GeometryReader { geometry in
            let canvasSize = geometry.size
            let points = Dictionary(uniqueKeysWithValues: draft.nodes.map { node in
                (node.id, CGPoint(x: node.position.x * canvasSize.width, y: node.position.y * canvasSize.height))
            })
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    for arc in draft.arcs {
                        guard let from = arc.fromNodeID.flatMap({ points[$0] }), let to = arc.toNodeID.flatMap({ points[$0] }) else { continue }
                        var path = Path()
                        path.move(to: from)
                        path.addLine(to: to)
                        let isSelected = selectedArcID == arc.id
                        context.stroke(path, with: .color(isSelected ? .accentColor : .secondary), lineWidth: isSelected ? 3 : 1.5)
                        if draft.kind.usesDirectedArcs {
                            let angle = atan2(to.y - from.y, to.x - from.x)
                            let tip = CGPoint(x: to.x - cos(angle) * 28, y: to.y - sin(angle) * 28)
                            let base = CGPoint(x: tip.x - cos(angle) * 10, y: tip.y - sin(angle) * 10)
                            let side = CGPoint(x: -sin(angle) * 5, y: cos(angle) * 5)
                            var arrow = Path()
                            arrow.move(to: tip)
                            arrow.addLine(to: CGPoint(x: base.x + side.x, y: base.y + side.y))
                            arrow.addLine(to: CGPoint(x: base.x - side.x, y: base.y - side.y))
                            arrow.closeSubpath()
                            context.fill(arrow, with: .color(isSelected ? .accentColor : .secondary))
                        }
                    }
                }
                ForEach(draft.nodes) { node in
                    if let point = points[node.id] {
                        graphNodeButton(node, at: point)
                    }
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Network graph editor")
        }
    }

    private func graphNodeButton(_ node: NetworkNodeDraft, at point: CGPoint) -> some View {
        let label = node.name.isEmpty ? "?" : node.name
        let selected = selectedNodeID == node.id
        return Button {
            onSelectNode(node.id)
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .padding(7)
                .frame(minWidth: 52, minHeight: 42)
                .background(selected ? Color.accentColor.opacity(0.22) : Color(nsColor: .controlBackgroundColor), in: Circle())
                .overlay(Circle().stroke(selected ? Color.accentColor : Color.secondary, lineWidth: selected ? 3 : 1))
        }
        .buttonStyle(.plain)
        .position(point)
        .accessibilityLabel("Graph node \(label)")
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
