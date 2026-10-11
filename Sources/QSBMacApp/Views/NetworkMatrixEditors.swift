import AppKit
import SwiftUI

struct AssignmentEditorView: View {
    @Bindable var workspace: QSBWorkspace
    @State private var transferIssue: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(title: workspace.modelTitle, subtitle: "Native Assignment matrix editor · \(workspace.modelState.rawValue)")
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button("Add Worker", systemImage: "plus") { workspace.updateAssignmentDraft { _ = $0.addRow() } }
                        .accessibilityIdentifier("network-assignment-add-row")
                    Text("\(workspace.assignmentDraft?.rows.count ?? 0) workers")
                        .accessibilityIdentifier("network-assignment-row-count")
                    Button("Add Task", systemImage: "plus") { workspace.updateAssignmentDraft { _ = $0.addColumn() } }
                        .accessibilityIdentifier("network-assignment-add-column")
                    Text("\(workspace.assignmentDraft?.columns.count ?? 0) tasks")
                        .accessibilityIdentifier("network-assignment-column-count")
                    Spacer()
                    Button("Validate") { workspace.validateCurrentModel() }
                        .keyboardShortcut("v", modifiers: [.command, .shift])
                    Button("Run") { workspace.startCurrentModelRun() }
                        .keyboardShortcut("r", modifiers: [.command])
                        .buttonStyle(.borderedProminent)
                }
                HStack {
                    Button("Paste Table", systemImage: "doc.on.clipboard", action: pasteTable)
                        .help("Replace the matrix from Excel, Numbers, LibreOffice, TSV, or CSV. Include worker and task headers to replace names too.")
                    Button("Copy Table", systemImage: "doc.on.doc", action: copyTable)
                        .help("Copy worker names, task names, and costs as tab-separated text")
                    Text("Excel, Numbers, LibreOffice, TSV, or CSV")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)

            if let transferIssue {
                Label(transferIssue, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 18)
                    .accessibilityLabel("Table import error: \(transferIssue)")
            }

            if let draft = workspace.assignmentDraft {
                ScrollView([.vertical, .horizontal]) {
                    Grid(horizontalSpacing: 10, verticalSpacing: 8) {
                        GridRow {
                            Text("Workers / Tasks").font(.headline)
                            ForEach(draft.columns) { column in
                                VStack(spacing: 3) {
                                    TextField("Task", text: columnName(column.id))
                                        .frame(width: 110)
                                        .accessibilityLabel("Task name")
                                    Button("Remove", systemImage: "minus.circle") { removeColumn(column.id) }
                                        .labelStyle(.iconOnly)
                                        .accessibilityLabel("Remove task")
                                }
                            }
                        }
                        ForEach(Array(draft.rows.enumerated()), id: \.element.id) { rowIndex, row in
                            GridRow {
                                HStack {
                                    TextField("Worker", text: rowName(row.id))
                                        .frame(width: 120)
                                        .accessibilityLabel("Worker name")
                                    Button("Remove", systemImage: "minus.circle") { removeRow(row.id) }
                                        .labelStyle(.iconOnly)
                                        .accessibilityLabel("Remove worker")
                                }
                                ForEach(Array(draft.columns.enumerated()), id: \.element.id) { columnIndex, column in
                                    TextField("Cost", text: cost(rowIndex, columnIndex))
                                        .frame(width: 110)
                                        .textFieldStyle(.roundedBorder)
                                        .accessibilityLabel("Cost for \(row.name) and \(column.name)")
                                }
                            }
                        }
                    }
                    .padding(18)
                }
            } else {
                ContentUnavailableView("No Assignment model", systemImage: "tablecells", description: Text("Choose Assignment from New Model or open an Assignment model."))
            }
        }
        .navigationTitle("Assignment Definition")
    }

    private func rowName(_ id: UUID) -> Binding<String> {
        Binding(get: { workspace.assignmentDraft?.rows.first(where: { $0.id == id })?.name ?? "" }, set: { value in
            workspace.updateAssignmentDraft { draft in
                guard let index = draft.rows.firstIndex(where: { $0.id == id }) else { return }
                draft.rows[index].name = value
            }
        })
    }

    private func columnName(_ id: UUID) -> Binding<String> {
        Binding(get: { workspace.assignmentDraft?.columns.first(where: { $0.id == id })?.name ?? "" }, set: { value in
            workspace.updateAssignmentDraft { draft in
                guard let index = draft.columns.firstIndex(where: { $0.id == id }) else { return }
                draft.columns[index].name = value
            }
        })
    }

    private func cost(_ row: Int, _ column: Int) -> Binding<String> {
        Binding(get: {
            guard let draft = workspace.assignmentDraft, draft.costs.indices.contains(row), draft.costs[row].indices.contains(column) else { return "" }
            return draft.costs[row][column]
        }, set: { value in
            workspace.updateAssignmentDraft { draft in
                guard draft.costs.indices.contains(row), draft.costs[row].indices.contains(column) else { return }
                draft.costs[row][column] = value
            }
        })
    }

    private func removeRow(_ id: UUID) {
        workspace.updateAssignmentDraft { draft in
            guard let index = draft.rows.firstIndex(where: { $0.id == id }) else { return }
            draft.removeRow(at: index)
        }
    }

    private func removeColumn(_ id: UUID) {
        workspace.updateAssignmentDraft { draft in
            guard let index = draft.columns.firstIndex(where: { $0.id == id }) else { return }
            draft.removeColumn(at: index)
        }
    }

    private func pasteTable() {
        guard let text = NSPasteboard.general.string(forType: .string) else {
            transferIssue = SpreadsheetTransferError.emptyClipboard.description
            return
        }
        guard var updated = workspace.assignmentDraft else { return }
        do {
            try updated.replaceTable(withTabularText: text)
            workspace.updateAssignmentDraft { $0 = updated }
            transferIssue = nil
        } catch {
            transferIssue = String(describing: error)
        }
    }

    private func copyTable() {
        guard let draft = workspace.assignmentDraft else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(draft.tabularText(), forType: .string)
        transferIssue = nil
    }
}

struct TransportationEditorView: View {
    @Bindable var workspace: QSBWorkspace
    @State private var transferIssue: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(title: workspace.modelTitle, subtitle: "Native Transportation matrix editor · \(workspace.modelState.rawValue)")
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button("Add Source", systemImage: "plus") { workspace.updateTransportationDraft { _ = $0.addSource() } }
                        .accessibilityIdentifier("network-transport-add-source")
                    Text("\(workspace.transportationDraft?.sources.count ?? 0) sources")
                        .accessibilityIdentifier("network-transport-source-count")
                    Button("Add Destination", systemImage: "plus") { workspace.updateTransportationDraft { _ = $0.addDestination() } }
                        .accessibilityIdentifier("network-transport-add-destination")
                    Text("\(workspace.transportationDraft?.destinations.count ?? 0) destinations")
                        .accessibilityIdentifier("network-transport-destination-count")
                    Spacer()
                    Button("Validate") { workspace.validateCurrentModel() }
                        .keyboardShortcut("v", modifiers: [.command, .shift])
                    Button("Run") { workspace.startCurrentModelRun() }
                        .keyboardShortcut("r", modifiers: [.command])
                        .buttonStyle(.borderedProminent)
                }
                HStack {
                    Button("Paste Table", systemImage: "doc.on.clipboard", action: pasteTable)
                        .help("Replace the transportation table from Excel, Numbers, LibreOffice, TSV, or CSV. Include headers, demand, and supply to replace the whole model table.")
                    Button("Copy Table", systemImage: "doc.on.doc", action: copyTable)
                        .help("Copy sources, destinations, costs, supply, and demand as tab-separated text")
                    Text("Excel, Numbers, LibreOffice, TSV, or CSV")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)

            if let transferIssue {
                Label(transferIssue, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 18)
                    .accessibilityLabel("Table import error: \(transferIssue)")
            }

            if let draft = workspace.transportationDraft {
                ScrollView([.vertical, .horizontal]) {
                    Grid(horizontalSpacing: 10, verticalSpacing: 8) {
                        GridRow {
                            Text("Sources / Destinations").font(.headline)
                            ForEach(draft.destinations) { destination in
                                VStack(spacing: 3) {
                                    TextField("Destination", text: destinationName(destination.id))
                                        .frame(width: 120)
                                        .accessibilityLabel("Destination name")
                                    TextField("Demand", text: demand(destination.id))
                                        .frame(width: 120)
                                        .accessibilityLabel("Demand for \(destination.name)")
                                    Button("Remove", systemImage: "minus.circle") { removeDestination(destination.id) }
                                        .labelStyle(.iconOnly)
                                        .accessibilityLabel("Remove destination")
                                }
                            }
                            Text("Supply").font(.headline)
                        }
                        ForEach(Array(draft.sources.enumerated()), id: \.element.id) { rowIndex, source in
                            GridRow {
                                HStack {
                                    TextField("Source", text: sourceName(source.id))
                                        .frame(width: 120)
                                        .accessibilityLabel("Source name")
                                    Button("Remove", systemImage: "minus.circle") { removeSource(source.id) }
                                        .labelStyle(.iconOnly)
                                        .accessibilityLabel("Remove source")
                                }
                                ForEach(Array(draft.destinations.enumerated()), id: \.element.id) { columnIndex, destination in
                                    TextField("Cost", text: cost(rowIndex, columnIndex))
                                        .frame(width: 120)
                                        .textFieldStyle(.roundedBorder)
                                        .accessibilityLabel("Cost from \(source.name) to \(destination.name)")
                                }
                                TextField("Supply", text: supply(source.id))
                                    .frame(width: 120)
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel("Supply for \(source.name)")
                            }
                        }
                    }
                    .padding(18)
                }
            } else {
                ContentUnavailableView("No Transportation model", systemImage: "tablecells", description: Text("Choose Transportation from New Model or open a Transportation model."))
            }
        }
        .navigationTitle("Transportation Definition")
    }

    private func sourceName(_ id: UUID) -> Binding<String> { textBinding(get: { $0.sources.first(where: { $0.id == id })?.name ?? "" }) { draft, value in if let i = draft.sources.firstIndex(where: { $0.id == id }) { draft.sources[i].name = value } } }
    private func supply(_ id: UUID) -> Binding<String> { textBinding(get: { $0.sources.first(where: { $0.id == id })?.supply ?? "" }) { draft, value in if let i = draft.sources.firstIndex(where: { $0.id == id }) { draft.sources[i].supply = value } } }
    private func destinationName(_ id: UUID) -> Binding<String> { textBinding(get: { $0.destinations.first(where: { $0.id == id })?.name ?? "" }) { draft, value in if let i = draft.destinations.firstIndex(where: { $0.id == id }) { draft.destinations[i].name = value } } }
    private func demand(_ id: UUID) -> Binding<String> { textBinding(get: { $0.destinations.first(where: { $0.id == id })?.demand ?? "" }) { draft, value in if let i = draft.destinations.firstIndex(where: { $0.id == id }) { draft.destinations[i].demand = value } } }

    private func textBinding(get: @escaping (TransportationDraft) -> String, set: @escaping (inout TransportationDraft, String) -> Void) -> Binding<String> {
        Binding(get: { workspace.transportationDraft.map(get) ?? "" }, set: { value in workspace.updateTransportationDraft { set(&$0, value) } })
    }

    private func cost(_ row: Int, _ column: Int) -> Binding<String> {
        Binding(get: {
            guard let draft = workspace.transportationDraft, draft.costs.indices.contains(row), draft.costs[row].indices.contains(column) else { return "" }
            return draft.costs[row][column]
        }, set: { value in workspace.updateTransportationDraft { draft in guard draft.costs.indices.contains(row), draft.costs[row].indices.contains(column) else { return }; draft.costs[row][column] = value } })
    }
    private func removeSource(_ id: UUID) { workspace.updateTransportationDraft { draft in if let i = draft.sources.firstIndex(where: { $0.id == id }) { draft.removeSource(at: i) } } }
    private func removeDestination(_ id: UUID) { workspace.updateTransportationDraft { draft in if let i = draft.destinations.firstIndex(where: { $0.id == id }) { draft.removeDestination(at: i) } } }

    private func pasteTable() {
        guard let text = NSPasteboard.general.string(forType: .string) else {
            transferIssue = SpreadsheetTransferError.emptyClipboard.description
            return
        }
        guard var updated = workspace.transportationDraft else { return }
        do {
            try updated.replaceTable(withTabularText: text)
            workspace.updateTransportationDraft { $0 = updated }
            transferIssue = nil
        } catch {
            transferIssue = String(describing: error)
        }
    }

    private func copyTable() {
        guard let draft = workspace.transportationDraft else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(draft.tabularText(), forType: .string)
        transferIssue = nil
    }
}
