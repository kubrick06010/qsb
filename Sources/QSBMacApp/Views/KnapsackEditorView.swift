import SwiftUI

struct KnapsackEditorView: View {
    @Bindable var workspace: QSBWorkspace
    @Environment(\.undoManager) private var undoManager
    @FocusState private var focusedItemID: UUID?
    @State private var transferIssue: String?

    private var draft: KnapsackDraft? { workspace.knapsackDraft }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(title: workspace.modelTitle, subtitle: "Native bounded-knapsack editor · \(workspace.modelState.rawValue)")
            if let draft {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 16) {
                        actionBar
                        issues(draft)
                        settings(draft)
                        itemsSection(draft)
                    }
                    .padding(20)
                    .frame(maxWidth: 1_260, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .navigationTitle("Bounded Knapsack Definition")
        .onChange(of: draft?.items.map(\.id) ?? []) { previous, current in
            guard let focusedItemID, !current.contains(focusedItemID) else { return }
            let index = previous.firstIndex(of: focusedItemID) ?? 0
            self.focusedItemID = current.isEmpty ? nil : current[min(index, current.count - 1)]
        }
    }

    private var actionBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { actionButtons; Spacer(); familyLabel }
            VStack(alignment: .leading, spacing: 8) { HStack(spacing: 10) { actionButtons }; familyLabel }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button("Validate", systemImage: "checkmark.seal") { workspace.validateCurrentModel() }
            .keyboardShortcut("v", modifiers: [.command, .shift])
            .accessibilityHint("Checks capacity, item limits, and item values")
        Button("Run", systemImage: "play.circle") { workspace.startCurrentModelRun() }
            .buttonStyle(.borderedProminent).keyboardShortcut("r", modifiers: [.command])
            .disabled(workspace.modelState == .invalid || workspace.runState == .solving)
            .accessibilityHint("Solves the bounded knapsack through the selected backend")
    }

    private var familyLabel: some View {
        Text(workspace.currentModelFamily.displayName).font(.callout).foregroundStyle(.secondary)
    }

    private func settings(_ draft: KnapsackDraft) -> some View {
        GroupBox("Model") {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 16) { settingsFields(draft) }
                VStack(alignment: .leading, spacing: 10) { settingsFields(draft) }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private func settingsFields(_ draft: KnapsackDraft) -> some View {
        labeledField("Title", text: binding(\.title, action: "Edit Model Title"), width: 320, id: "knapsack-title")
        labeledField("Capacity", text: binding(\.capacity, action: "Edit Capacity"), width: 140, id: "knapsack-capacity")
        Text("\(draft.items.count) items").font(.callout).foregroundStyle(.secondary)
            .accessibilityLabel("\(draft.items.count) knapsack items")
    }

    private func itemsSection(_ draft: KnapsackDraft) -> some View {
        GroupBox("Items") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Each row sets the maximum quantity, capacity consumed, and return earned by one unit.")
                    .font(.caption).foregroundStyle(.secondary)
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            header("Item", width: 220); header("Available", width: 110)
                            header("Capacity required", width: 150); header("Return per unit", width: 140)
                            Color.clear.frame(width: 28, height: 1)
                        }
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        ForEach(draft.items) { item in itemRow(item, count: draft.items.count) }
                    }
                    .padding(.bottom, 4)
                }
                HStack(alignment: .top, spacing: 10) {
                    Button("Add Item", systemImage: "plus") {
                        var id: UUID?
                        update("Add Item") { id = $0.addItem() }
                        if let id { focusedItemID = id }
                    }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .accessibilityHint("Adds an item and moves keyboard focus to its name")
                    SpreadsheetTransferActions(subject: "knapsack items", issue: transferIssue, paste: pasteItems, copy: copyItems)
                }
            }
            .padding(8)
        }
    }

    private func itemRow(_ item: KnapsackItemDraft, count: Int) -> some View {
        HStack(spacing: 8) {
            itemField("Item name", item: item, keyPath: \.name, width: 220, focus: true)
            itemField("Available quantity for \(item.name)", item: item, keyPath: \.available, width: 110)
            itemField("Capacity required by \(item.name)", item: item, keyPath: \.capacityRequired, width: 150)
            itemField("Return per unit for \(item.name)", item: item, keyPath: \.returnPerUnit, width: 140)
            Button {
                guard let items = draft?.items,
                      let index = items.firstIndex(where: { $0.id == item.id }), items.count > 1 else { return }
                let nextID = items[index == items.count - 1 ? index - 1 : index + 1].id
                update("Remove Item") { $0.removeItem(id: item.id) }
                focusedItemID = nextID
            } label: { Image(systemName: "minus.circle") }
            .buttonStyle(.borderless).disabled(count <= 1).accessibilityLabel("Remove item \(item.name)")
        }
    }

    private func itemField(
        _ label: String, item: KnapsackItemDraft,
        keyPath: WritableKeyPath<KnapsackItemDraft, String>, width: CGFloat, focus: Bool = false
    ) -> some View {
        let field = TextField("", text: Binding(
            get: { workspace.knapsackDraft?.items.first(where: { $0.id == item.id })?[keyPath: keyPath] ?? "" },
            set: { value in
                update("Edit Item") { draft in
                    guard let index = draft.items.firstIndex(where: { $0.id == item.id }) else { return }
                    draft.items[index][keyPath: keyPath] = value
                }
            }
        ))
        .textFieldStyle(.roundedBorder).frame(width: width).accessibilityLabel(label)
        return Group { if focus { field.focused($focusedItemID, equals: item.id) } else { field } }
    }

    @ViewBuilder
    private func issues(_ draft: KnapsackDraft) -> some View {
        let diagnostics = draft.draftDiagnostics().filter { $0.severity != .info }
        if !diagnostics.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                    Label(diagnostic.message, systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(diagnostic.severity == .error ? .red : .orange)
                }
            }
            .accessibilityElement(children: .contain).accessibilityLabel("Bounded knapsack input issues")
        }
    }

    private func labeledField(_ label: String, text: Binding<String>, width: CGFloat, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: text).textFieldStyle(.roundedBorder).frame(width: width)
                .accessibilityLabel(label).accessibilityIdentifier(id)
        }
    }

    private func header(_ text: String, width: CGFloat) -> some View { Text(text).frame(width: width, alignment: .leading) }

    private func binding(_ keyPath: WritableKeyPath<KnapsackDraft, String>, action: String) -> Binding<String> {
        Binding(get: { workspace.knapsackDraft?[keyPath: keyPath] ?? "" }, set: { value in update(action) { $0[keyPath: keyPath] = value } })
    }

    private func update(_ actionName: String, _ mutation: (inout KnapsackDraft) -> Void) {
        guard var next = workspace.knapsackDraft else { return }
        mutation(&next)
        workspace.replaceKnapsackDraft(next, undoManager: undoManager, actionName: actionName)
    }

    private func pasteItems() {
        do {
            var next = try requireDraft(); try next.replaceItems(withTabularText: SpreadsheetClipboard.read())
            workspace.replaceKnapsackDraft(next, undoManager: undoManager, actionName: "Paste Knapsack Items")
            if !next.items.contains(where: { $0.id == focusedItemID }) { focusedItemID = next.items.first?.id }
            transferIssue = nil
        } catch { transferIssue = String(describing: error) }
    }
    private func copyItems() { guard let draft else { return }; SpreadsheetClipboard.write(draft.tabularText()); transferIssue = nil }
    private func requireDraft() throws -> KnapsackDraft { guard let draft else { throw SpreadsheetTransferError.emptyClipboard }; return draft }
}
