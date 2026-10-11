import SwiftUI
import QSBCore

struct QualityControlEditorView: View {
    @Bindable var workspace: QSBWorkspace
    @Environment(\.undoManager) private var undoManager
    private struct CellFocus: Hashable {
        var row: UUID
        var column: UUID
    }
    @FocusState private var focusedCell: CellFocus?
    @State private var transferIssue: String?

    private var draft: QualityControlDraft? { workspace.qualityControlDraft }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(title: workspace.modelTitle, subtitle: "Native quality-control editor · \(workspace.modelState.rawValue)")
            if let draft {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 16) {
                        actionBar
                        issues(draft)
                        settings(draft)
                        observations(draft)
                    }
                    .padding(20)
                    .frame(maxWidth: 1_300, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .navigationTitle("Quality Control Definition")
        .onChange(of: draft?.rows.map(\.id) ?? []) { previous, current in
            guard let cell = focusedCell, !current.contains(cell.row) else { return }
            let index = previous.firstIndex(of: cell.row) ?? 0
            focusedCell = current.isEmpty ? nil : CellFocus(row: current[min(index, current.count - 1)], column: cell.column)
        }
        .onChange(of: draft?.columns.map(\.id) ?? []) { previous, current in
            guard let cell = focusedCell, !current.contains(cell.column) else { return }
            let index = previous.firstIndex(of: cell.column) ?? 0
            focusedCell = current.isEmpty ? nil : CellFocus(row: cell.row, column: current[min(index, current.count - 1)])
        }
    }

    private var actionBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { actionButtons; Spacer(); familyLabel }
            VStack(alignment: .leading, spacing: 8) { HStack(spacing: 10) { actionButtons }; familyLabel }
        }
    }

    @ViewBuilder private var actionButtons: some View {
        Button("Validate", systemImage: "checkmark.seal") { workspace.validateCurrentModel() }
            .keyboardShortcut("v", modifiers: [.command, .shift])
        Button("Run", systemImage: "play.circle") { workspace.startCurrentModelRun() }
            .buttonStyle(.borderedProminent).keyboardShortcut("r", modifiers: [.command])
            .disabled(workspace.modelState == .invalid || workspace.runState == .solving)
    }

    private var familyLabel: some View { Text(workspace.currentModelFamily.displayName).font(.callout).foregroundStyle(.secondary) }

    private func settings(_ draft: QualityControlDraft) -> some View {
        GroupBox("Analysis") {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 16) { settingsFields(draft) }
                VStack(alignment: .leading, spacing: 10) { settingsFields(draft) }
            }
            .padding(8)
        }
    }

    @ViewBuilder private func settingsFields(_ draft: QualityControlDraft) -> some View {
        labeledField("Title", text: binding(\.title, action: "Edit Title"), width: 300)
        VStack(alignment: .leading, spacing: 4) {
            Text("Analysis type").font(.caption).foregroundStyle(.secondary)
            Picker("Analysis type", selection: Binding(
                get: { draft.kind },
                set: { kind in
                    update("Change Analysis Type") { $0.switchKind(to: kind) }
                    focusedCell = nil
                    transferIssue = nil
                }
            )) {
                Text("c chart").tag(QualityControlProblemKind.cChart)
                Text("p chart").tag(QualityControlProblemKind.pChart)
                Text("X-bar / R").tag(QualityControlProblemKind.xbarRChart)
                Text("Pareto").tag(QualityControlProblemKind.pareto)
                Text("Normal probability").tag(QualityControlProblemKind.normalProbabilityPlot)
            }
            .labelsHidden().frame(width: 210).accessibilityLabel("Quality control analysis type")
            Text("Each analysis retains its table while you edit this model.").font(.caption).foregroundStyle(.secondary).frame(width: 210, alignment: .leading)
        }
        if draft.kind != .pareto {
            labeledField("Characteristic", text: binding(\.characteristic, action: "Edit Characteristic"), width: 220)
        }
    }

    private func observations(_ draft: QualityControlDraft) -> some View {
        GroupBox(draft.kind == .pareto ? "Subgroup counts" : draft.kind == .xbarRChart ? "Subgroup measurements" : "Observations") {
            VStack(alignment: .leading, spacing: 10) {
                Text(helpText(draft.kind)).font(.caption).foregroundStyle(.secondary)
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 8) {
                        headerRow(draft)
                        ForEach(Array(draft.rows.enumerated()), id: \.element.id) { index, row in
                            dataRow(row, index: index, draft: draft)
                        }
                    }
                    .padding(.bottom, 4)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 10) { tableActions(draft) }
                    VStack(alignment: .leading, spacing: 10) { tableActions(draft) }
                }
            }
            .padding(8)
        }
    }

    private func headerRow(_ draft: QualityControlDraft) -> some View {
        HStack(spacing: 8) {
            Text(draft.kind == .xbarRChart || draft.kind == .pareto ? "Subgroup" : "Observation")
                .frame(width: 80, alignment: .leading)
            ForEach(draft.columns) { column in
                if draft.kind == .pareto {
                    TextField("Category", text: columnBinding(column.id))
                        .textFieldStyle(.roundedBorder).frame(width: 150)
                        .accessibilityLabel("Pareto category name")
                } else {
                    Text(column.name).frame(width: 150, alignment: .leading)
                }
                if draft.kind == .pareto || draft.kind == .xbarRChart {
                    Button { removeColumn(column.id) } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless).frame(width: 20)
                        .disabled(draft.columns.count <= (draft.kind == .xbarRChart ? 2 : 1))
                        .accessibilityLabel("Remove column \(column.name)")
                }
            }
            Color.clear.frame(width: 28, height: 1)
        }
        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
    }

    private func dataRow(_ row: QualityControlRowDraft, index: Int, draft: QualityControlDraft) -> some View {
        HStack(spacing: 8) {
            Text("\(index + 1)").frame(width: 80, alignment: .leading).accessibilityLabel("Row \(index + 1)")
            ForEach(Array(draft.columns.enumerated()), id: \.element.id) { column, definition in
                TextField("", text: valueBinding(row.id, column: column))
                    .textFieldStyle(.roundedBorder).frame(width: 150)
                    .focused($focusedCell, equals: CellFocus(row: row.id, column: definition.id))
                    .accessibilityLabel("\(definition.name), row \(index + 1)")
                if draft.kind == .pareto || draft.kind == .xbarRChart { Color.clear.frame(width: 20, height: 1) }
            }
            Button { removeRow(row.id) } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless).frame(width: 28)
                .disabled(draft.rows.count <= (draft.kind == .normalProbabilityPlot ? 3 : 1))
                .accessibilityLabel("Remove row \(index + 1)")
        }
    }

    @ViewBuilder private func tableActions(_ draft: QualityControlDraft) -> some View {
        Button("Add Row", systemImage: "plus") {
            var id: UUID?
            update("Add Row") { id = $0.addRow() }
            if let id, let column = workspace.qualityControlDraft?.columns.first { focusedCell = CellFocus(row: id, column: column.id) }
        }
        .keyboardShortcut("n", modifiers: [.command, .shift]).accessibilityHint("Adds a row and moves keyboard focus to its first value")
        if draft.kind == .pareto || draft.kind == .xbarRChart {
            Button("Add Column", systemImage: "rectangle.split.3x1") {
                update("Add Column") { $0.addColumn() }
                if let current = workspace.qualityControlDraft, let row = current.rows.first, let column = current.columns.last {
                    focusedCell = CellFocus(row: row.id, column: column.id)
                }
            }
        }
        SpreadsheetTransferActions(subject: "quality-control table", issue: transferIssue, paste: pasteTable, copy: copyTable)
    }

    private func helpText(_ kind: QualityControlProblemKind) -> String {
        switch kind {
        case .cChart: "Enter a nonnegative defect count for each observation."
        case .pChart: "Enter the inspected sample size and defective proportion for each observation."
        case .xbarRChart: "Each row is one subgroup; all subgroups use the same 2–10 measurements."
        case .pareto: "Columns are defect categories and rows are observed subgroups."
        case .normalProbabilityPlot: "Enter at least three measurements for the probability plot."
        }
    }

    private func labeledField(_ label: String, text: Binding<String>, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: text).textFieldStyle(.roundedBorder).frame(width: width).accessibilityLabel(label)
        }
    }

    private func binding(_ keyPath: WritableKeyPath<QualityControlDraft, String>, action: String) -> Binding<String> {
        Binding(get: { workspace.qualityControlDraft?[keyPath: keyPath] ?? "" }, set: { value in update(action) { $0[keyPath: keyPath] = value } })
    }

    private func columnBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { workspace.qualityControlDraft?.columns.first(where: { $0.id == id })?.name ?? "" },
            set: { value in update("Rename Category") { draft in if let index = draft.columns.firstIndex(where: { $0.id == id }) { draft.columns[index].name = value } } }
        )
    }

    private func valueBinding(_ rowID: UUID, column: Int) -> Binding<String> {
        Binding(
            get: { workspace.qualityControlDraft?.rows.first(where: { $0.id == rowID })?.values[safe: column] ?? "" },
            set: { value in update("Edit Observation") { draft in if let index = draft.rows.firstIndex(where: { $0.id == rowID }), draft.rows[index].values.indices.contains(column) { draft.rows[index].values[column] = value } } }
        )
    }

    @ViewBuilder private func issues(_ draft: QualityControlDraft) -> some View {
        let diagnostics = draft.draftDiagnostics().filter { $0.severity != .info }
        if !diagnostics.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                    Label(diagnostic.message, systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(diagnostic.severity == .error ? .red : .orange)
                }
            }
            .accessibilityElement(children: .contain).accessibilityLabel("Quality control input issues")
        }
    }

    private func update(_ actionName: String, _ mutation: (inout QualityControlDraft) -> Void) {
        guard var next = workspace.qualityControlDraft else { return }
        mutation(&next)
        workspace.replaceQualityControlDraft(next, undoManager: undoManager, actionName: actionName)
    }
    private func removeRow(_ id: UUID) {
        guard let current = draft, let index = current.rows.firstIndex(where: { $0.id == id }) else { return }
        update("Remove Row") { $0.removeRow(id: id) }
        if let next = draft, !next.rows.isEmpty, let column = next.columns.first {
            focusedCell = CellFocus(row: next.rows[min(index, next.rows.count - 1)].id, column: column.id)
        }
    }
    private func removeColumn(_ id: UUID) {
        guard let current = draft, let index = current.columns.firstIndex(where: { $0.id == id }) else { return }
        let rowID = focusedCell?.row ?? current.rows.first?.id
        update("Remove Column") { $0.removeColumn(id: id) }
        if let next = draft, !next.columns.isEmpty, let rowID {
            focusedCell = CellFocus(row: rowID, column: next.columns[min(index, next.columns.count - 1)].id)
        }
    }
    private func pasteTable() {
        do {
            guard var next = draft else { throw SpreadsheetTransferError.emptyClipboard }
            try next.replaceTable(withTabularText: SpreadsheetClipboard.read())
            workspace.replaceQualityControlDraft(next, undoManager: undoManager, actionName: "Paste Quality Control Table")
            if !(focusedCell.map { cell in next.rows.contains { $0.id == cell.row } && next.columns.contains { $0.id == cell.column } } ?? false),
               let row = next.rows.first, let column = next.columns.first {
                focusedCell = CellFocus(row: row.id, column: column.id)
            }
            transferIssue = nil
        } catch { transferIssue = String(describing: error) }
    }
    private func copyTable() { guard let draft else { return }; SpreadsheetClipboard.write(draft.tabularText()); transferIssue = nil }
}

private extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}
