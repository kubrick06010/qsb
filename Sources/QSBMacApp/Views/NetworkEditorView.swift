import SwiftUI
import QSBCore

struct NetworkEditorView: View {
    @Bindable var workspace: QSBWorkspace

    @State private var selectedNodeID: UUID?
    @State private var selectedArcID: UUID?
    @State private var addArcFrom: UUID?
    @State private var addArcTo: UUID?
    @State private var gestureFeedback: String?
    @State private var canvasInteracted = false
    // This is a transient editing buffer: NetworkDraft remains authoritative and
    // is mutated only after a valid Return commit; Escape or invalid input leaves it unchanged.
    @State private var inlineArcID: UUID?
    @State private var inlineArcValue = ""
    @State private var inlineArcOriginalValue = ""
    @State private var inlineArcError: String?
    @FocusState private var focusedField: NetworkEditorFocusField?

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
                            onSelectArc: { selectArc($0, focusValue: false) },
                            onEditArc: beginInlineArcEdit,
                            onCreateNode: createNode,
                            onFastConnect: fastConnect,
                            inlineArcID: inlineArcID,
                            inlineArcValue: $inlineArcValue,
                            inlineArcError: inlineArcError,
                            onCommitInlineArc: commitInlineArc,
                            onCancelInlineArc: cancelInlineArcEdit,
                            gestureFeedback: gestureFeedback,
                            sourceNodeName: selectedNodeID.map { nodeName(for: $0) },
                            showInitialHint: !canvasInteracted
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
                var result: (id: UUID, created: Bool)?
                workspace.updateNetworkDraft { draft in
                    result = draft.addArcIfMissing(from: from, to: to)
                }
                guard let result else { return }
                selectArc(result.id, focusValue: false)
                gestureFeedback = result.created ? nil : "That connection already exists."
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
                .focused($focusedField, equals: .nodeName(draft.nodes[index].id))
                .accessibilityLabel("Node \(index + 1) name")
                .accessibilityIdentifier("network-selected-node-name")
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
                .focused($focusedField, equals: .arcValue(draft.arcs[index].id))
                .accessibilityLabel(draft.kind == .maxFlow ? "Arc capacity" : "Arc cost")
                .accessibilityIdentifier("network-selected-arc-value")
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
                .accessibilityIdentifier("network-node-\(index + 1)")
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
                    selectArc(arc.id, focusValue: false)
                } label: {
                    Label("\(from) \(draft.kind.usesDirectedArcs ? "→" : "—") \(to) · \(arc.costText)", systemImage: selectedArcID == arc.id ? "line.diagonal" : "arrow.left.and.right")
                }
                .buttonStyle(.link)
                .accessibilityLabel("Connection \(index + 1), \(from) to \(to), \(arc.costText)")
                .accessibilityIdentifier("network-arc-\(index + 1)")
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
        cancelInlineArcEdit()
        selectedNodeID = id
        selectedArcID = nil
        canvasInteracted = true
        gestureFeedback = nil
        focusedField = nil
    }

    private func selectArc(_ id: UUID, focusValue: Bool) {
        if inlineArcID != id { cancelInlineArcEdit() }
        selectedArcID = id
        selectedNodeID = nil
        canvasInteracted = true
        gestureFeedback = nil
        if focusValue {
            DispatchQueue.main.async {
                focusedField = .arcValue(id)
            }
        } else {
            focusedField = nil
        }
    }

    private func createNode(at point: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let position = NetworkDraftPosition(
            x: min(max(Double(point.x / size.width), 0.06), 0.94),
            y: min(max(Double(point.y / size.height), 0.08), 0.92)
        )
        var id: UUID?
        workspace.updateNetworkDraft { draft in
            id = draft.addNode(position: position)
        }
        guard let id else { return }
        selectedNodeID = id
        selectedArcID = nil
        canvasInteracted = true
        gestureFeedback = nil
        DispatchQueue.main.async {
            focusedField = .nodeName(id)
        }
    }

    private func fastConnect(to destination: UUID) {
        canvasInteracted = true
        guard let source = selectedNodeID else { return }
        guard source != destination else {
            gestureFeedback = "Choose another node to connect from \(nodeName(for: source))."
            return
        }

        let result = workspace.networkDraft.map { draft in
            draft.existingArcID(from: source, to: destination)
        } ?? nil
        if let existing = result {
            selectArc(existing, focusValue: false)
            gestureFeedback = "That connection already exists."
            return
        }

        workspace.updateNetworkDraft { draft in
            _ = draft.addArcIfMissing(from: source, to: destination)
        }
        selectedNodeID = source
        selectedArcID = nil
        focusedField = nil
        gestureFeedback = "Connected \(nodeName(for: source)) to \(nodeName(for: destination))."
    }

    private func beginInlineArcEdit(_ id: UUID) {
        guard let value = workspace.networkDraft?.arcs.first(where: { $0.id == id })?.costText else { return }
        selectArc(id, focusValue: true)
        inlineArcID = id
        inlineArcValue = value
        inlineArcOriginalValue = value
        inlineArcError = nil
        DispatchQueue.main.async { focusedField = .arcValue(id) }
    }

    private func commitInlineArc() {
        guard let id = inlineArcID else { return }
        var committed = false
        workspace.updateNetworkDraft { draft in
            committed = draft.commitArcCost(id: id, value: inlineArcValue)
        }
        guard committed else {
            inlineArcError = "Enter a non-negative number."
            return
        }
        inlineArcID = nil
        inlineArcError = nil
        gestureFeedback = nil
    }

    private func cancelInlineArcEdit() {
        guard inlineArcID != nil else { return }
        inlineArcValue = inlineArcOriginalValue
        inlineArcID = nil
        inlineArcError = nil
    }

    private func nodeName(for id: UUID) -> String {
        workspace.networkDraft?.nodes.first(where: { $0.id == id })?.name ?? "node"
    }

    private func deleteSelection() {
        cancelInlineArcEdit()
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

private enum NetworkEditorFocusField: Hashable {
    case nodeName(UUID)
    case arcValue(UUID)
}

private struct NetworkGraphCanvas: View {
    let draft: NetworkDraft
    let selectedNodeID: UUID?
    let selectedArcID: UUID?
    let onSelectNode: (UUID) -> Void
    let onSelectArc: (UUID) -> Void
    let onEditArc: (UUID) -> Void
    let onCreateNode: (CGPoint, CGSize) -> Void
    let onFastConnect: (UUID) -> Void
    let inlineArcID: UUID?
    @Binding var inlineArcValue: String
    let inlineArcError: String?
    let onCommitInlineArc: () -> Void
    let onCancelInlineArc: () -> Void
    let gestureFeedback: String?
    let sourceNodeName: String?
    let showInitialHint: Bool

    @State private var hoveredNodeID: UUID?
    @State private var hoveredArcID: UUID?
    @State private var connectionDragSourceID: UUID?
    @State private var connectionDragLocation: CGPoint?
    @State private var connectionDestinationID: UUID?
    @FocusState private var inlineEditorFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            let canvasSize = geometry.size
            let points = Dictionary(uniqueKeysWithValues: draft.nodes.map { node in
                (node.id, CGPoint(x: node.position.x * canvasSize.width, y: node.position.y * canvasSize.height))
            })
            ZStack(alignment: .topLeading) {
                // Interactive nodes, arcs, labels, and the connection handle are
                // layered above this backstop so their gestures cannot create a
                // node through the empty-canvas double-click handler.
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture(count: 2).onEnded { value in
                        onCreateNode(value.location, canvasSize)
                    })
                    .zIndex(0)
                    .help("Double-click empty space to add a node.")

                Canvas { context, _ in
                    for arc in draft.arcs {
                        guard let from = arc.fromNodeID.flatMap({ points[$0] }), let to = arc.toNodeID.flatMap({ points[$0] }) else { continue }
                        var path = Path()
                        path.move(to: from)
                        path.addLine(to: to)
                        let isSelected = selectedArcID == arc.id
                        let isHovered = hoveredArcID == arc.id
                        context.stroke(path, with: .color(isSelected ? .accentColor : .secondary), lineWidth: isSelected ? 3 : (isHovered ? 2.5 : 1.5))
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
                .allowsHitTesting(false)
                .zIndex(1)

                ForEach(draft.arcs) { arc in
                    if let from = arc.fromNodeID.flatMap({ points[$0] }), let to = arc.toNodeID.flatMap({ points[$0] }) {
                        arcHitTarget(arc, from: from, to: to, in: canvasSize)
                        arcLabel(arc, from: from, to: to)
                    }
                }
                if let sourceID = connectionDragSourceID,
                   let source = points[sourceID],
                   let location = connectionDragLocation {
                    Path { path in
                        path.move(to: source)
                        path.addLine(to: location)
                    }
                    .stroke(Color.accentColor.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .allowsHitTesting(false)
                }
                ForEach(draft.nodes) { node in
                    if let point = points[node.id] {
                        graphNodeButton(node, at: point)
                        if selectedNodeID == node.id {
                            connectionHandle(node, at: point, in: canvasSize, points: points)
                        }
                    }
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .coordinateSpace(name: "networkCanvas")
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Network graph editor")
            .overlay(alignment: .bottomLeading) {
                if let gestureFeedback {
                    canvasHint(gestureFeedback, isFeedback: true)
                } else if let sourceNodeName {
                    canvasHint("Drag the connector or Control-click another node to connect from \(sourceNodeName)", isFeedback: false)
                } else if showInitialHint {
                    canvasHint("Double-click to add nodes · Select a node to connect", isFeedback: false)
                }
            }
        }
    }

    private func graphNodeButton(_ node: NetworkNodeDraft, at point: CGPoint) -> some View {
        let label = node.name.isEmpty ? "?" : node.name
        let selected = selectedNodeID == node.id
        let hovered = hoveredNodeID == node.id
        return Button {
            onSelectNode(node.id)
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .padding(7)
                .frame(minWidth: 52, minHeight: 42)
                .background(selected ? Color.accentColor.opacity(0.22) : (hovered ? Color.accentColor.opacity(0.10) : Color(nsColor: .controlBackgroundColor)), in: Circle())
                .overlay(Circle().stroke(selected ? Color.accentColor : (hovered ? Color.accentColor : Color.secondary), lineWidth: selected ? 3 : (hovered ? 2 : 1)))
        }
        .buttonStyle(.plain)
        .highPriorityGesture(
            TapGesture().modifiers(.control).onEnded {
                onFastConnect(node.id)
            }
        )
        .onHover { isHovered in
            hoveredNodeID = isHovered ? node.id : nil
        }
        .position(point)
        .zIndex(4)
        .accessibilityLabel("Graph node \(label)")
        .accessibilityIdentifier("network-graph-node-\(node.id.uuidString)")
        .accessibilityHint(selected ? "Selected source node. Control-click another node to create an arc." : "Click to select. Control-click another node to create an arc.")
        .help(selected ? "Selected source node. Control-click another node to create an arc." : "Click to select. Control-click another node to create an arc.")
    }

    private func connectionHandle(
        _ node: NetworkNodeDraft,
        at point: CGPoint,
        in size: CGSize,
        points: [UUID: CGPoint]
    ) -> some View {
        let active = connectionDragSourceID == node.id
        let target = connectionDestinationID != nil && connectionDestinationID != node.id
        let sourceLabel = node.name.isEmpty ? "this node" : node.name
        let handleHelp = "Drag to another node to connect from " + sourceLabel + "."
        return ZStack {
            Circle()
                .fill(Color.accentColor.opacity(active ? 0.32 : 0.18))
            Image(systemName: "arrow.turn.down.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: 22, height: 22)
        .overlay(Circle().stroke(Color.accentColor.opacity(active ? 0.9 : 0.55), lineWidth: active ? 2 : 1))
        .scaleEffect(target ? 1.08 : 1)
        .position(
            x: min(max(point.x + 30, 14), size.width - 14),
            y: min(max(point.y - 26, 14), size.height - 14)
        )
        .contentShape(Circle())
        .zIndex(5)
        .gesture(
            // Handle-local coordinates are too small for reliable destination
            // hit testing; the named space keeps the drag location aligned with
            // the node points used by the canvas.
            DragGesture(minimumDistance: 2, coordinateSpace: .named("networkCanvas"))
                .onChanged { value in
                    connectionDragSourceID = node.id
                    connectionDragLocation = value.location
                    connectionDestinationID = destinationID(at: value.location, excluding: node.id, points: points)
                }
                .onEnded { value in
                    let destination = destinationID(at: value.location, excluding: node.id, points: points)
                    connectionDragSourceID = nil
                    connectionDragLocation = nil
                    connectionDestinationID = nil
                    if let destination {
                        onFastConnect(destination)
                    }
                }
        )
        .accessibilityElement()
        .accessibilityLabel("Connect from \(node.name.isEmpty ? "node" : node.name)")
        .accessibilityHint("Drag to another node to create an arc.")
        .help(handleHelp)
    }

    private func destinationID(at location: CGPoint, excluding sourceID: UUID, points: [UUID: CGPoint]) -> UUID? {
        points
            .filter { $0.key != sourceID }
            .min { lhs, rhs in distance(from: lhs.value, to: location) < distance(from: rhs.value, to: location) }
            .flatMap { distance(from: $0.value, to: location) <= 34 ? $0.key : nil }
    }

    private func distance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    private func arcHitTarget(_ arc: NetworkArcDraft, from: CGPoint, to: CGPoint, in size: CGSize) -> some View {
        let isSelected = selectedArcID == arc.id
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = max(sqrt(dx * dx + dy * dy), 1)
        let endpointInset = min(28, length / 2)
        let hitFrom = CGPoint(x: from.x + dx / length * endpointInset, y: from.y + dy / length * endpointInset)
        let hitTo = CGPoint(x: to.x - dx / length * endpointInset, y: to.y - dy / length * endpointInset)
        let hitShape = ArcLineShape(from: hitFrom, to: hitTo)
        return Button {
            onSelectArc(arc.id)
        } label: {
            hitShape
                .stroke(.clear, lineWidth: 28)
                .contentShape(hitShape.stroke(lineWidth: 28))
        }
        .buttonStyle(.plain)
        .frame(width: size.width, height: size.height)
        // Keep the visible edge thin while giving pointer users a practical
        // hit target instead of requiring pixel-perfect clicks.
        .contentShape(hitShape.stroke(lineWidth: 28))
        .zIndex(2)
        .highPriorityGesture(
            TapGesture(count: 2).onEnded {
                onEditArc(arc.id)
            }
        )
        .onHover { isHovered in
            hoveredArcID = isHovered ? arc.id : nil
        }
        .opacity(isSelected ? 0.45 : (hoveredArcID == arc.id ? 0.08 : 0.01))
        .accessibilityLabel("Connection, \(arc.costText)")
        .accessibilityIdentifier("network-graph-arc-\(arc.id.uuidString)")
        .accessibilityHint("Double-click to edit arc properties.")
        .help("Double-click to edit.")
    }

    private func arcLabel(_ arc: NetworkArcDraft, from: CGPoint, to: CGPoint) -> some View {
        let midpoint = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = max(sqrt(dx * dx + dy * dy), 1)
        let offset = CGPoint(x: -dy / length * 10, y: dx / length * 10)
        return Group {
            if inlineArcID == arc.id {
                VStack(alignment: .leading, spacing: 3) {
                    TextField(draft.kind == .maxFlow ? "Capacity" : "Cost", text: $inlineArcValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption2.monospacedDigit())
                        .frame(width: 88)
                        .focused($inlineEditorFocused)
                        .onSubmit(onCommitInlineArc)
                        .onExitCommand(perform: onCancelInlineArc)
                        .onAppear { inlineEditorFocused = true }
                        .accessibilityLabel(draft.kind == .maxFlow ? "Inline arc capacity" : "Inline arc cost")
                        .accessibilityIdentifier("network-inline-arc-value")
                    if let inlineArcError {
                        Text(inlineArcError)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            } else {
                Text(arc.costText)
                    .font(.caption2.monospacedDigit())
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.thinMaterial, in: Capsule())
            }
        }
            .position(x: midpoint.x + offset.x, y: midpoint.y + offset.y)
            .zIndex(inlineArcID == arc.id ? 6 : 3)
            .allowsHitTesting(inlineArcID == arc.id)
    }

    private func canvasHint(_ text: String, isFeedback: Bool) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(isFeedback ? .primary : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.thinMaterial, in: Capsule())
            .padding(10)
            .allowsHitTesting(false)
    }
}

private struct ArcLineShape: Shape {
    let from: CGPoint
    let to: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        return path
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
