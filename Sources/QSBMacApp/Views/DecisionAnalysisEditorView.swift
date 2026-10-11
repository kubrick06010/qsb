import SwiftUI
import QSBCore

struct DecisionAnalysisEditorView: View {
    @Bindable var workspace: QSBWorkspace
    @State private var statesTransferIssue: String?
    @State private var likelihoodsTransferIssue: String?
    @State private var payoffsTransferIssue: String?

    private var draft: DecisionAnalysisDraft? { workspace.decisionDraft }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(
                title: workspace.modelTitle,
                subtitle: "Native decision editor · \(workspace.modelState.rawValue)"
            )
            if let draft {
                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 16) {
                        actionBar
                        issues(draft)
                        modelSection(draft)
                        statesSection(draft)
                        likelihoodSection(draft)
                        if draft.kind == .payoff { payoffSection(draft) }
                    }
                    .padding(20)
                    .frame(minWidth: 680, alignment: .topLeading)
                }
            }
        }
        .navigationTitle("Decision Analysis Definition")
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
            Text(workspace.currentModelFamily.displayName)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func modelSection(_ draft: DecisionAnalysisDraft) -> some View {
        GroupBox("Model") {
            HStack {
                field("Title", value: binding(
                    get: { $0.title }, set: { $0.title = $1 }
                ), width: 300, id: "decision-title")
                Text(draft.kind.displayName)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(8)
        }
    }

    private func statesSection(_ draft: DecisionAnalysisDraft) -> some View {
        GroupBox("States and prior probabilities") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(draft.states.indices, id: \.self) { index in
                    HStack(spacing: 10) {
                        field("State \(index + 1)", value: binding(
                            get: { Self.value($0.states, at: index) },
                            set: { if $0.states.indices.contains(index) { $0.states[index] = $1 } }
                        ), width: 180, id: "decision-state-\(index)")
                        field("Prior probability for \(draft.states[index])", value: binding(
                            get: { Self.value($0.priorProbabilities, at: index) },
                            set: { if $0.priorProbabilities.indices.contains(index) { $0.priorProbabilities[index] = $1 } }
                        ), width: 130, id: "decision-prior-\(index)")
                        removeButton("Remove state \(draft.states[index])") {
                            workspace.updateDecisionDraft { $0.removeState(at: index) }
                        }
                        .disabled(draft.states.count <= 1)
                    }
                }
                Button("Add State", systemImage: "plus") {
                    workspace.updateDecisionDraft { $0.addState() }
                }
                SpreadsheetTransferActions(
                    subject: "states and prior probabilities",
                    issue: statesTransferIssue,
                    paste: pasteStates,
                    copy: copyStates
                )
            }
            .padding(8)
        }
    }

    private func likelihoodSection(_ draft: DecisionAnalysisDraft) -> some View {
        GroupBox(draft.kind == .payoff ? "Indicator likelihoods" : "Outcome likelihoods") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Each cell is the probability of that indicator or outcome given the state. Each state column must sum to one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Text(draft.kind == .payoff ? "Indicator" : "Outcome")
                        .frame(width: 180, alignment: .leading)
                    ForEach(draft.states.indices, id: \.self) { state in
                        Text(draft.states[state])
                            .frame(width: 110, alignment: .leading)
                    }
                }
                ForEach(draft.observations.indices, id: \.self) { row in
                    HStack(spacing: 10) {
                        field(draft.kind == .payoff ? "Indicator \(row + 1)" : "Outcome \(row + 1)", value: binding(
                            get: { Self.value($0.observations, at: row) },
                            set: { if $0.observations.indices.contains(row) { $0.observations[row] = $1 } }
                        ), width: 180, id: "decision-observation-\(row)")
                        ForEach(draft.states.indices, id: \.self) { column in
                            field("\(draft.observations[row]) given \(draft.states[column])", value: binding(
                                get: { Self.value($0.likelihoods, row: row, column: column) },
                                set: { if Self.contains($0.likelihoods, row: row, column: column) { $0.likelihoods[row][column] = $1 } }
                            ), width: 110, id: "decision-likelihood-\(row)-\(column)")
                        }
                        removeButton("Remove \(draft.observations[row])") {
                            workspace.updateDecisionDraft { $0.removeObservation(at: row) }
                        }
                        .disabled(draft.observations.count <= 1)
                    }
                }
                Button(draft.kind == .payoff ? "Add Indicator" : "Add Outcome", systemImage: "plus") {
                    workspace.updateDecisionDraft { $0.addObservation() }
                }
                SpreadsheetTransferActions(
                    subject: draft.kind == .payoff ? "indicator likelihoods" : "outcome likelihoods",
                    issue: likelihoodsTransferIssue,
                    paste: pasteLikelihoods,
                    copy: copyLikelihoods
                )
            }
            .padding(8)
        }
    }

    private func payoffSection(_ draft: DecisionAnalysisDraft) -> some View {
        GroupBox("Decision payoffs") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("Decision").frame(width: 180, alignment: .leading)
                    ForEach(draft.states.indices, id: \.self) { state in
                        Text(draft.states[state]).frame(width: 110, alignment: .leading)
                    }
                }
                ForEach(draft.decisions.indices, id: \.self) { row in
                    HStack(spacing: 10) {
                        field("Decision \(row + 1)", value: binding(
                            get: { Self.value($0.decisions, at: row) },
                            set: { if $0.decisions.indices.contains(row) { $0.decisions[row] = $1 } }
                        ), width: 180, id: "decision-choice-\(row)")
                        ForEach(draft.states.indices, id: \.self) { column in
                            field("Payoff for \(draft.decisions[row]) in \(draft.states[column])", value: binding(
                                get: { Self.value($0.payoffs, row: row, column: column) },
                                set: { if Self.contains($0.payoffs, row: row, column: column) { $0.payoffs[row][column] = $1 } }
                            ), width: 110, id: "decision-payoff-\(row)-\(column)")
                        }
                        removeButton("Remove decision \(draft.decisions[row])") {
                            workspace.updateDecisionDraft { $0.removeDecision(at: row) }
                        }
                        .disabled(draft.decisions.count <= 1)
                    }
                }
                Button("Add Decision", systemImage: "plus") {
                    workspace.updateDecisionDraft { $0.addDecision() }
                }
                SpreadsheetTransferActions(
                    subject: "decision payoffs",
                    issue: payoffsTransferIssue,
                    paste: pastePayoffs,
                    copy: copyPayoffs
                )
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private func issues(_ draft: DecisionAnalysisDraft) -> some View {
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

    private func removeButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: "minus.circle") }
            .buttonStyle(.borderless)
            .accessibilityLabel(label)
    }

    private func binding(
        get: @escaping (DecisionAnalysisDraft) -> String,
        set: @escaping (inout DecisionAnalysisDraft, String) -> Void
    ) -> Binding<String> {
        Binding(
            get: { workspace.decisionDraft.map(get) ?? "" },
            set: { value in workspace.updateDecisionDraft { set(&$0, value) } }
        )
    }

    private static func value(_ values: [String], at index: Int) -> String {
        values.indices.contains(index) ? values[index] : ""
    }

    private static func contains(_ matrix: [[String]], row: Int, column: Int) -> Bool {
        matrix.indices.contains(row) && matrix[row].indices.contains(column)
    }

    private static func value(_ matrix: [[String]], row: Int, column: Int) -> String {
        contains(matrix, row: row, column: column) ? matrix[row][column] : ""
    }

    private func pasteStates() {
        updateFromClipboard(issue: $statesTransferIssue) { draft, text in
            try draft.replaceStates(withTabularText: text)
        }
    }

    private func pasteLikelihoods() {
        updateFromClipboard(issue: $likelihoodsTransferIssue) { draft, text in
            try draft.replaceLikelihoods(withTabularText: text)
        }
    }

    private func pastePayoffs() {
        updateFromClipboard(issue: $payoffsTransferIssue) { draft, text in
            try draft.replacePayoffs(withTabularText: text)
        }
    }

    private func copyStates() {
        guard let draft else { return }
        SpreadsheetClipboard.write(draft.statesTabularText())
        statesTransferIssue = nil
    }

    private func copyLikelihoods() {
        guard let draft else { return }
        SpreadsheetClipboard.write(draft.likelihoodsTabularText())
        likelihoodsTransferIssue = nil
    }

    private func copyPayoffs() {
        guard let draft else { return }
        SpreadsheetClipboard.write(draft.payoffsTabularText())
        payoffsTransferIssue = nil
    }

    private func updateFromClipboard(
        issue: Binding<String?>,
        apply: (inout DecisionAnalysisDraft, String) throws -> Void
    ) {
        do {
            let text = try SpreadsheetClipboard.read()
            guard var draft = workspace.decisionDraft else { return }
            try apply(&draft, text)
            workspace.updateDecisionDraft { $0 = draft }
            issue.wrappedValue = nil
        } catch {
            issue.wrappedValue = String(describing: error)
        }
    }
}
