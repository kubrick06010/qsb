import SwiftUI

struct MarkovEditorView: View {
    @Bindable var workspace: QSBWorkspace

    private var draft: MarkovDraft? { workspace.markovDraft }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(
                title: workspace.modelTitle,
                subtitle: "Native Markov editor · \(workspace.modelState.rawValue)"
            )
            if let draft {
                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 16) {
                        actionBar
                        draftIssues(draft)
                        identityEditor
                        stateEditor(draft)
                        transitionEditor(draft)
                        interpretation
                    }
                    .padding(20)
                    .frame(minWidth: 820, alignment: .topLeading)
                }
            } else {
                ContentUnavailableView(
                    "No Markov draft",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("Create a Markov model, load the sample, or open a normalized request.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Markov Definition")
    }

    private var actionBar: some View {
        HStack {
            Text("Define states, transition probabilities, costs, and optional transient analysis.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Validate") { workspace.validateCurrentModel() }
                .keyboardShortcut("v", modifiers: [.command, .shift])
                .accessibilityIdentifier("markov-validate")
            Button("Run") { workspace.runCurrentModel() }
                .keyboardShortcut("r", modifiers: [.command])
                .buttonStyle(.borderedProminent)
                .disabled(workspace.runState == .solving)
                .accessibilityIdentifier("markov-run")
        }
    }

    private var identityEditor: some View {
        GroupBox("Analysis") {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                TextField("Model title", text: titleBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 260)
                    .accessibilityLabel("Markov model title")
                    .accessibilityIdentifier("markov-title")
                Toggle("Initial distribution", isOn: includesInitialBinding)
                    .accessibilityHint("Include a starting probability for transient propagation")
                    .accessibilityIdentifier("markov-initial-toggle")
                TextField("Periods", text: periodsBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .accessibilityLabel("Transient analysis periods")
                    .accessibilityIdentifier("markov-periods")
            }
            .padding(8)
        }
    }

    private func stateEditor(_ draft: MarkovDraft) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("States").font(.headline)
                    Text("\(draft.states.count)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        workspace.updateMarkovDraft { $0.addState() }
                    } label: {
                        Label("Add state", systemImage: "plus")
                    }
                    .accessibilityIdentifier("markov-add-state")
                }
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text("State").bold()
                        Text("Cost").bold()
                        if draft.includesInitialDistribution { Text("Initial probability").bold() }
                        Text("")
                    }
                    ForEach(Array(draft.states.enumerated()), id: \.element.id) { index, state in
                        GridRow {
                            TextField("State name", text: stateBinding(state.id, \.name))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 180)
                                .accessibilityLabel("State \(index + 1) name")
                            TextField("Cost", text: stateBinding(state.id, \.costText))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                .accessibilityLabel("Cost for \(state.name)")
                            if draft.includesInitialDistribution {
                                TextField("Probability", text: stateBinding(state.id, \.initialProbabilityText))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 130)
                                    .accessibilityLabel("Initial probability for \(state.name)")
                            }
                            Button("Remove", systemImage: "minus.circle", role: .destructive) {
                                workspace.updateMarkovDraft { $0.removeState(at: index) }
                            }
                            .labelStyle(.iconOnly)
                            .disabled(draft.states.count <= 1)
                            .help("Remove \(state.name)")
                            .accessibilityLabel("Remove state \(state.name)")
                        }
                    }
                }
            }
            .padding(8)
        }
    }

    private func transitionEditor(_ draft: MarkovDraft) -> some View {
        GroupBox("Transition matrix") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Each row is the current state; each column is the next state. Every row must sum to 1.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal) {
                    Grid(alignment: .trailing, horizontalSpacing: 8, verticalSpacing: 8) {
                        GridRow {
                            Text("From ↓ / To →").bold().gridColumnAlignment(.leading)
                            ForEach(draft.states) { state in
                                Text(state.name.isEmpty ? "Unnamed" : state.name)
                                    .font(.caption.bold())
                                    .frame(width: 88)
                            }
                            Text("Row sum").bold()
                        }
                        ForEach(Array(draft.states.enumerated()), id: \.element.id) { _, rowState in
                            let rowSumLabel = "Transition row sum for \(rowState.name)"
                            let rowSumText = rowSum(for: rowState.id, draft: draft)
                            let rowSumValid = rowSumIsOne(for: rowState.id, draft: draft)
                            GridRow {
                                Text(rowState.name.isEmpty ? "Unnamed" : rowState.name)
                                    .font(.callout.weight(.medium))
                                    .frame(width: 130, alignment: .leading)
                                ForEach(draft.states) { columnState in
                                    transitionField(from: rowState, to: columnState)
                                }
                                Text(rowSumText)
                                    .monospacedDigit()
                                    .foregroundStyle(rowSumValid ? Color.secondary : Color.red)
                                    .accessibilityLabel(rowSumLabel)
                            }
                        }
                    }
                    .padding(4)
                }
            }
            .padding(8)
        }
    }

    private var interpretation: some View {
        GroupBox("Interpretation") {
            Text("The native backend solves the stationary distribution exactly for chains with a unique stationary solution. When an initial distribution is enabled, it also propagates probabilities for the requested horizon. Layout and editor state do not alter the normalized model.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
    }

    @ViewBuilder
    private func draftIssues(_ draft: MarkovDraft) -> some View {
        let issues = draft.draftDiagnostics().filter { $0.severity == .error }
        if !issues.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                    Label(issue.message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { workspace.markovDraft?.title ?? "" },
            set: { value in workspace.updateMarkovDraft { $0.title = value } }
        )
    }

    private var periodsBinding: Binding<String> {
        Binding(
            get: { workspace.markovDraft?.periodsText ?? "" },
            set: { value in workspace.updateMarkovDraft { $0.periodsText = value } }
        )
    }

    private var includesInitialBinding: Binding<Bool> {
        Binding(
            get: { workspace.markovDraft?.includesInitialDistribution ?? false },
            set: { value in workspace.updateMarkovDraft { $0.setIncludesInitialDistribution(value) } }
        )
    }

    private func stateBinding(_ id: UUID, _ keyPath: WritableKeyPath<MarkovStateDraft, String>) -> Binding<String> {
        Binding(
            get: { workspace.markovDraft?.states.first(where: { $0.id == id })?[keyPath: keyPath] ?? "" },
            set: { value in
                workspace.updateMarkovDraft { draft in
                    guard let index = draft.states.firstIndex(where: { $0.id == id }) else { return }
                    draft.states[index][keyPath: keyPath] = value
                }
            }
        )
    }

    private func transitionBinding(rowID: UUID, columnID: UUID) -> Binding<String> {
        Binding(
            get: {
                guard let draft = workspace.markovDraft,
                      let row = draft.states.firstIndex(where: { $0.id == rowID }),
                      let column = draft.states.firstIndex(where: { $0.id == columnID }),
                      draft.transitionMatrix.indices.contains(row),
                      draft.transitionMatrix[row].indices.contains(column)
                else { return "" }
                return draft.transitionMatrix[row][column]
            },
            set: { value in
                workspace.updateMarkovDraft { draft in
                    guard let row = draft.states.firstIndex(where: { $0.id == rowID }),
                          let column = draft.states.firstIndex(where: { $0.id == columnID }),
                          draft.transitionMatrix.indices.contains(row),
                          draft.transitionMatrix[row].indices.contains(column)
                    else { return }
                    draft.transitionMatrix[row][column] = value
                }
            }
        )
    }

    private func transitionField(from row: MarkovStateDraft, to column: MarkovStateDraft) -> some View {
        let transitionLabel = "Transition from \(row.name) to \(column.name)"
        return TextField("0", text: transitionBinding(rowID: row.id, columnID: column.id))
            .textFieldStyle(.roundedBorder)
            .frame(width: 88)
            .accessibilityLabel(transitionLabel)
    }

    private func rowSum(for rowID: UUID, draft: MarkovDraft) -> String {
        guard let row = draft.states.firstIndex(where: { $0.id == rowID }),
              draft.transitionMatrix.indices.contains(row)
        else { return "—" }
        let values = draft.transitionMatrix[row].compactMap(Double.init)
        guard values.count == draft.states.count else { return "—" }
        return values.reduce(0, +).formatted(.number.precision(.fractionLength(0...4)))
    }

    private func rowSumIsOne(for rowID: UUID, draft: MarkovDraft) -> Bool {
        guard let row = draft.states.firstIndex(where: { $0.id == rowID }),
              draft.transitionMatrix.indices.contains(row)
        else { return false }
        let values = draft.transitionMatrix[row].compactMap(Double.init)
        return values.count == draft.states.count && abs(values.reduce(0, +) - 1) <= 1e-8
    }
}
