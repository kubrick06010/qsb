import SwiftUI

struct NetworkFlowEditorView: View {
    @Bindable var workspace: QSBWorkspace

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(title: workspace.modelTitle, subtitle: "Native CNF balance editor · (workspace.modelState.rawValue)")
            HStack {
                Button("Add Node", systemImage: "plus") { workspace.updateNetworkFlowDraft { _ = $0.addNode() } }
                    .accessibilityIdentifier("network-cnf-add-node")
                Text("\(workspace.networkFlowDraft?.nodes.count ?? 0) nodes")
                    .accessibilityIdentifier("network-cnf-node-count")
                Button("Add Arc", systemImage: "plus") { workspace.updateNetworkFlowDraft { _ = $0.addArc() } }
                    .accessibilityIdentifier("network-cnf-add-arc")
                Text("\(workspace.networkFlowDraft?.arcs.count ?? 0) arcs")
                    .accessibilityIdentifier("network-cnf-arc-count")
                Spacer()
                Button("Validate") { workspace.validateCurrentModel() }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                Button("Run") { workspace.solveCurrentModel() }
                    .keyboardShortcut("r", modifiers: [.command])
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)

            if let draft = workspace.networkFlowDraft {
                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 18) {
                        TextField("Model title", text: titleBinding)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 420)
                            .accessibilityLabel("CNF model title")
                        nodeTable(draft)
                        arcTable(draft)
                        Label("Supply and demand are preserved as node balances. If totals differ, QSBCore reports the existing automatic dummy adjustment during validation and solving.", systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    .padding(18)
                    .frame(minWidth: 760, alignment: .topLeading)
                }
            } else {
                ContentUnavailableView("No minimum-cost transshipment model", systemImage: "arrow.triangle.branch", description: Text("Choose Minimum-Cost Transshipment from New Model or open a CNF model."))
            }
        }
        .navigationTitle("Minimum-Cost Transshipment Definition")
    }

    private func nodeTable(_ draft: NetworkFlowDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nodes and balances").font(.headline)
            Grid(horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("Node").font(.subheadline.weight(.semibold))
                    Text("Supply").font(.subheadline.weight(.semibold))
                    Text("Demand").font(.subheadline.weight(.semibold))
                    Text("")
                }
                ForEach(Array(draft.nodes.enumerated()), id: \.element.id) { index, node in
                    GridRow {
                        TextField("Node", text: nodeName(node.id))
                            .frame(width: 180)
                            .accessibilityLabel("Node \(index + 1) name")
                        TextField("Supply", text: balance(node.id, isSupply: true))
                            .frame(width: 120)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Supply for \(node.name)")
                        TextField("Demand", text: balance(node.id, isSupply: false))
                            .frame(width: 120)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Demand for \(node.name)")
                        Button("Remove", systemImage: "minus.circle") { removeNode(node.id) }
                            .labelStyle(.iconOnly)
                            .accessibilityLabel("Remove node \(node.name)")
                    }
                }
            }
        }
    }

    private func arcTable(_ draft: NetworkFlowDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Directed arcs").font(.headline)
            Grid(horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("From").font(.subheadline.weight(.semibold))
                    Text("To").font(.subheadline.weight(.semibold))
                    Text("Cost").font(.subheadline.weight(.semibold))
                    Text("")
                }
                ForEach(Array(draft.arcs.enumerated()), id: \.element.id) { index, arc in
                    GridRow {
                        endpointPicker("From", selection: endpoint(arc.id, from: true), draft: draft)
                            .frame(width: 180)
                            .accessibilityLabel("Arc \(index + 1) source")
                        endpointPicker("To", selection: endpoint(arc.id, from: false), draft: draft)
                            .frame(width: 180)
                            .accessibilityLabel("Arc \(index + 1) destination")
                        TextField("Cost", text: arcCost(arc.id))
                            .frame(width: 120)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Arc \(index + 1) cost")
                        Button("Remove", systemImage: "minus.circle") { removeArc(arc.id) }
                            .labelStyle(.iconOnly)
                            .accessibilityLabel("Remove arc \(index + 1)")
                    }
                }
            }
        }
    }

    private var titleBinding: Binding<String> {
        Binding(get: { workspace.networkFlowDraft?.title ?? "" }, set: { value in workspace.updateNetworkFlowDraft { $0.title = value } })
    }

    private func nodeName(_ id: UUID) -> Binding<String> { textBinding(get: { $0.nodes.first(where: { $0.id == id })?.name ?? "" }) { draft, value in if let index = draft.nodes.firstIndex(where: { $0.id == id }) { draft.nodes[index].name = value } } }
    private func balance(_ id: UUID, isSupply: Bool) -> Binding<String> { textBinding(get: { let node = $0.nodes.first(where: { $0.id == id }); return isSupply ? node?.supply ?? "" : node?.demand ?? "" }) { draft, value in if let index = draft.nodes.firstIndex(where: { $0.id == id }) { if isSupply { draft.nodes[index].supply = value } else { draft.nodes[index].demand = value } } } }

    private func textBinding(get: @escaping (NetworkFlowDraft) -> String, set: @escaping (inout NetworkFlowDraft, String) -> Void) -> Binding<String> {
        Binding(get: { workspace.networkFlowDraft.map(get) ?? "" }, set: { value in workspace.updateNetworkFlowDraft { set(&$0, value) } })
    }

    private func endpoint(_ arcID: UUID, from: Bool) -> Binding<UUID?> {
        Binding(get: { let arc = workspace.networkFlowDraft?.arcs.first(where: { $0.id == arcID }); return from ? arc?.fromNodeID : arc?.toNodeID }, set: { value in workspace.updateNetworkFlowDraft { draft in guard let index = draft.arcs.firstIndex(where: { $0.id == arcID }) else { return }; if from { draft.arcs[index].fromNodeID = value } else { draft.arcs[index].toNodeID = value } } })
    }

    private func endpointPicker(_ title: String, selection: Binding<UUID?>, draft: NetworkFlowDraft) -> some View {
        Picker(title, selection: selection) {
            Text("Choose…").tag(nil as UUID?)
            ForEach(draft.nodes) { node in Text(node.name.isEmpty ? "Unnamed" : node.name).tag(Optional(node.id)) }
        }
        .labelsHidden()
    }

    private func arcCost(_ id: UUID) -> Binding<String> { textBinding(get: { $0.arcs.first(where: { $0.id == id })?.costText ?? "" }) { draft, value in if let index = draft.arcs.firstIndex(where: { $0.id == id }) { draft.arcs[index].costText = value } } }
    private func removeNode(_ id: UUID) { workspace.updateNetworkFlowDraft { $0.removeNode(id: id) } }
    private func removeArc(_ id: UUID) { workspace.updateNetworkFlowDraft { $0.removeArc(id: id) } }
}
