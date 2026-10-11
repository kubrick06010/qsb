import SwiftUI
import QSBCore

struct DecisionTreeEditorView: View {
    @Bindable var workspace: QSBWorkspace

    private var draft: DecisionTreeDraft? { workspace.decisionTreeDraft }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(title: workspace.modelTitle, subtitle: "Native decision tree editor · \(workspace.modelState.rawValue)")
            if let draft {
                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 16) {
                        actionBar
                        issues(draft)
                        GroupBox("Tree") {
                            HStack(spacing: 16) {
                                field("Title", value: titleBinding, width: 300, id: "tree-title")
                                Picker("Root node", selection: rootBinding) {
                                    if !draft.nodes.contains(where: { $0.id == draft.rootID }) {
                                        Text("Missing node \(draft.rootID)").tag(draft.rootID)
                                    }
                                    ForEach(Array(draft.nodes.enumerated()), id: \.offset) { _, node in
                                        Text("\(node.id) · \(node.name)").tag(node.id)
                                    }
                                }
                                .frame(width: 220)
                                .accessibilityIdentifier("tree-root")
                            }
                            .padding(8)
                        }
                        Text("Each node lists its child IDs in order. A chance node reads probabilities from its children; sibling probabilities are normalized when they do not sum to one.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 640, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(draft.nodes.indices, id: \.self) { index in
                            nodeSection(draft.nodes[index], index: index, draft: draft)
                        }
                    }
                    .padding(20)
                    .frame(minWidth: 680, alignment: .topLeading)
                }
            }
        }
        .navigationTitle("Decision Tree Definition")
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button("Validate", systemImage: "checkmark.seal") { workspace.validateCurrentModel() }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            Button("Run", systemImage: "play.circle") { workspace.startCurrentModelRun() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(workspace.modelState == .invalid || workspace.runState == .solving)
            Spacer()
            Text("Decision Tree")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func nodeSection(_ node: DecisionTreeNodeDraft, index: Int, draft: DecisionTreeDraft) -> some View {
        GroupBox("Node \(node.id)\(node.id == draft.rootID ? " · Root" : "")") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Picker("Kind", selection: kindBinding(at: index)) {
                        Text("Decision").tag(DecisionTreeNodeKind.decision)
                        Text("Chance").tag(DecisionTreeNodeKind.chance)
                        Text("Terminal").tag(DecisionTreeNodeKind.terminal)
                    }
                    .frame(width: 180)
                    .accessibilityIdentifier("tree-kind-\(node.id)")
                    field("Node \(node.id) name", value: nodeBinding(at: index, get: { $0.name }, set: { $0.name = $1 }), width: 280, id: "tree-name-\(node.id)")
                }
                HStack(spacing: 12) {
                    field("Child IDs for node \(node.id)", value: nodeBinding(at: index, get: { $0.childIDs }, set: { $0.childIDs = $1 }), width: 200, id: "tree-children-\(node.id)")
                    field("Payoff for node \(node.id)", value: nodeBinding(at: index, get: { $0.payoff }, set: { $0.payoff = $1 }), width: 130, id: "tree-payoff-\(node.id)")
                    field("Probability for node \(node.id)", value: nodeBinding(at: index, get: { $0.probability }, set: { $0.probability = $1 }), width: 130, id: "tree-probability-\(node.id)")
                }
                HStack(spacing: 10) {
                    Button("Add Terminal Child", systemImage: "plus") {
                        workspace.updateDecisionTreeDraft { $0.addTerminalChild(to: node.id) }
                    }
                    .disabled(!draft.canAddTerminalChild(to: node.id))
                    .accessibilityIdentifier("tree-add-child-\(node.id)")
                    Button("Remove Leaf", systemImage: "minus.circle") {
                        workspace.updateDecisionTreeDraft { $0.removeLeaf(id: node.id) }
                    }
                    .disabled(!draft.canRemoveLeaf(id: node.id))
                    .accessibilityLabel("Remove leaf node \(node.id)")
                    .accessibilityIdentifier("tree-remove-node-\(node.id)")
                }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private func issues(_ draft: DecisionTreeDraft) -> some View {
        let diagnostics = draft.draftDiagnostics().filter { $0.severity == .error || $0.severity == .warning }
        if !diagnostics.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                    Label(diagnostic.message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(diagnostic.severity == .error ? .red : .orange)
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    private func field(_ label: String, value: Binding<String>, width: CGFloat, id: String) -> some View {
        TextField(label, text: value)
            .textFieldStyle(.roundedBorder)
            .frame(width: width)
            .accessibilityLabel(label)
            .accessibilityIdentifier(id)
    }

    private var rootBinding: Binding<Int> {
        Binding(
            get: { workspace.decisionTreeDraft?.rootID ?? 0 },
            set: { value in workspace.updateDecisionTreeDraft { $0.rootID = value } }
        )
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { workspace.decisionTreeDraft?.title ?? "" },
            set: { value in workspace.updateDecisionTreeDraft { $0.title = value } }
        )
    }

    private func kindBinding(at index: Int) -> Binding<DecisionTreeNodeKind> {
        Binding(
            get: { workspace.decisionTreeDraft.flatMap { $0.nodes.indices.contains(index) ? $0.nodes[index].kind : nil } ?? .terminal },
            set: { value in workspace.updateDecisionTreeDraft { if $0.nodes.indices.contains(index) { $0.nodes[index].kind = value } } }
        )
    }

    private func nodeBinding(
        at index: Int,
        get: @escaping (DecisionTreeNodeDraft) -> String,
        set: @escaping (inout DecisionTreeNodeDraft, String) -> Void
    ) -> Binding<String> {
        Binding(
            get: { workspace.decisionTreeDraft.flatMap { $0.nodes.indices.contains(index) ? get($0.nodes[index]) : nil } ?? "" },
            set: { value in workspace.updateDecisionTreeDraft { if $0.nodes.indices.contains(index) { set(&$0.nodes[index], value) } } }
        )
    }
}
