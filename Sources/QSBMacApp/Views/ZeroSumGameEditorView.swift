import SwiftUI
import QSBCore

struct ZeroSumGameEditorView: View {
    @Bindable var workspace: QSBWorkspace
    @State private var transferIssue: String?

    private var draft: ZeroSumGameDraft? { workspace.zeroSumGameDraft }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(title: workspace.modelTitle, subtitle: "Native zero-sum game editor · \(workspace.modelState.rawValue)")
            if let draft {
                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 16) {
                        actionBar
                        issues(draft)
                        GroupBox("Model") {
                            field("Title", value: binding(get: { $0.title }, set: { $0.title = $1 }), width: 300, id: "game-title")
                                .padding(8)
                        }
                        matrix(draft)
                    }
                    .padding(20)
                    .frame(minWidth: 680, alignment: .topLeading)
                }
            }
        }
        .navigationTitle("Zero-Sum Game Definition")
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
            Text("Player 1 maximizes; Player 2 minimizes")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func matrix(_ draft: ZeroSumGameDraft) -> some View {
        GroupBox("Player 1 payoff matrix") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Player 1 chooses a row. Player 2 chooses a column. Each cell is Player 1's payoff.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Text("Player 1 / Player 2").frame(width: 180, alignment: .leading)
                    ForEach(draft.columnStrategies.indices, id: \.self) { column in
                        VStack(spacing: 4) {
                            field("Player 2 strategy \(column + 1)", value: binding(
                                get: { Self.value($0.columnStrategies, at: column) },
                                set: { if $0.columnStrategies.indices.contains(column) { $0.columnStrategies[column] = $1 } }
                            ), width: 110, id: "game-column-\(column)")
                            removeButton("Remove Player 2 strategy \(draft.columnStrategies[column])") {
                                workspace.updateZeroSumGameDraft { $0.removeColumnStrategy(at: column) }
                            }
                            .disabled(draft.columnStrategies.count <= 1)
                        }
                    }
                }
                ForEach(draft.rowStrategies.indices, id: \.self) { row in
                    HStack(spacing: 10) {
                        field("Player 1 strategy \(row + 1)", value: binding(
                            get: { Self.value($0.rowStrategies, at: row) },
                            set: { if $0.rowStrategies.indices.contains(row) { $0.rowStrategies[row] = $1 } }
                        ), width: 180, id: "game-row-\(row)")
                        ForEach(draft.columnStrategies.indices, id: \.self) { column in
                            field("Payoff for \(draft.rowStrategies[row]) against \(draft.columnStrategies[column])", value: binding(
                                get: { Self.value($0.payoffs, row: row, column: column) },
                                set: { if Self.contains($0.payoffs, row: row, column: column) { $0.payoffs[row][column] = $1 } }
                            ), width: 110, id: "game-payoff-\(row)-\(column)")
                        }
                        removeButton("Remove Player 1 strategy \(draft.rowStrategies[row])") {
                            workspace.updateZeroSumGameDraft { $0.removeRowStrategy(at: row) }
                        }
                        .disabled(draft.rowStrategies.count <= 1)
                    }
                }
                HStack {
                    Button("Add Player 1 Strategy", systemImage: "plus") {
                        workspace.updateZeroSumGameDraft { $0.addRowStrategy() }
                    }
                    Button("Add Player 2 Strategy", systemImage: "plus") {
                        workspace.updateZeroSumGameDraft { $0.addColumnStrategy() }
                    }
                }
                SpreadsheetTransferActions(
                    subject: "the zero-sum payoff matrix and strategy names",
                    issue: transferIssue,
                    paste: pasteTable,
                    copy: copyTable
                )
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private func issues(_ draft: ZeroSumGameDraft) -> some View {
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
        get: @escaping (ZeroSumGameDraft) -> String,
        set: @escaping (inout ZeroSumGameDraft, String) -> Void
    ) -> Binding<String> {
        Binding(
            get: { workspace.zeroSumGameDraft.map(get) ?? "" },
            set: { value in workspace.updateZeroSumGameDraft { set(&$0, value) } }
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

    private func pasteTable() {
        do {
            let text = try SpreadsheetClipboard.read()
            guard var draft = workspace.zeroSumGameDraft else { return }
            try draft.replaceTable(withTabularText: text)
            workspace.updateZeroSumGameDraft { $0 = draft }
            transferIssue = nil
        } catch {
            transferIssue = String(describing: error)
        }
    }

    private func copyTable() {
        guard let draft else { return }
        SpreadsheetClipboard.write(draft.tabularText())
        transferIssue = nil
    }
}
