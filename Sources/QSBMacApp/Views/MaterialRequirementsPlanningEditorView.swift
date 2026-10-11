import SwiftUI
import QSBCore

enum MaterialRequirementsPlanningEditorSection: String, CaseIterable, Identifiable {
    case items = "Items"
    case schedules = "Schedules"
    case billOfMaterials = "Bill of Materials"
    var id: Self { self }
}

struct MaterialRequirementsPlanningEditorView: View {
    private enum FieldFocus: Hashable {
        case item(UUID)
        case bucket(Int)
        case bill(UUID)
        case addBill
    }

    @Bindable var workspace: QSBWorkspace
    @Environment(\.undoManager) private var undoManager
    @FocusState private var focusedField: FieldFocus?
    @State private var selectedSection: MaterialRequirementsPlanningEditorSection
    @State private var selectedItemID: UUID?
    @State private var scheduleGroup: Int
    @State private var transferIssue: String?

    private var draft: MaterialRequirementsPlanningDraft? { workspace.materialRequirementsPlanningDraft }
    private var selectedItem: MRPItemDraft? {
        guard let draft else { return nil }
        return draft.items.first(where: { $0.id == selectedItemID }) ?? draft.items.first
    }

    init(
        workspace: QSBWorkspace,
        initialSection: MaterialRequirementsPlanningEditorSection = .items,
        initialScheduleGroup: Int = 0,
        initialItemID: UUID? = nil
    ) {
        self.workspace = workspace
        _selectedSection = State(initialValue: initialSection)
        _scheduleGroup = State(initialValue: initialScheduleGroup)
        _selectedItemID = State(initialValue: initialItemID)
    }

    private var editorContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(
                title: workspace.modelTitle,
                subtitle: "Native item, schedule, and bill-of-materials editor · \(workspace.modelState.rawValue)"
            )
            if let draft {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 16) {
                        actionBar
                        issues(draft)
                        planSection(draft)
                        Picker("Definition section", selection: $selectedSection) {
                            ForEach(MaterialRequirementsPlanningEditorSection.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 620)
                        .accessibilityLabel("Material requirements planning section")

                        switch selectedSection {
                        case .items: itemSection(draft)
                        case .schedules: scheduleSection(draft)
                        case .billOfMaterials: billSection(draft)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 1_260, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
    }

    private var itemIDs: [UUID] { draft?.items.map(\.id) ?? [] }
    private var billIDs: [UUID] { draft?.billComponents.map(\.id) ?? [] }
    private var bucketCount: Int { draft?.bucketNames.count ?? 0 }

    var body: some View {
        editorContent
        .navigationTitle("Material Requirements Planning Definition")
        .onAppear { selectFirstItemIfNeeded() }
        .onChange(of: itemIDs) { previous, current in
            if let selectedItemID, !current.contains(selectedItemID) {
                let oldIndex = previous.firstIndex(of: selectedItemID) ?? 0
                self.selectedItemID = current.isEmpty ? nil : current[min(oldIndex, current.count - 1)]
            }
            selectFirstItemIfNeeded()
            if case let .item(id) = focusedField {
                focusedField = repairedEditorRowSelection(id, previous: previous, current: current).map { .item($0) }
            }
        }
        .onChange(of: billIDs) { previous, current in
            guard case let .bill(id) = focusedField else { return }
            focusedField = draft == nil ? nil : repairedEditorRowSelection(id, previous: previous, current: current).map { .bill($0) } ?? .addBill
        }
        .onChange(of: bucketCount) { _, count in
            scheduleGroup = min(max(0, scheduleGroup), max(0, MatrixEditorNavigation().groupCount(columnCount: count) - 1))
            if case let .bucket(index) = focusedField {
                let repaired = min(index, max(0, count - 1))
                focusedField = count > 0 ? .bucket(repaired) : nil
                scheduleGroup = repaired / MatrixEditorNavigation.columnsPerGroup
            }
        }
        .onChange(of: selectedSection) { _, _ in transferIssue = nil }
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
            .accessibilityHint("Checks item values, schedule dimensions, and the bill of materials")
        Button("Run", systemImage: "play.circle") { workspace.startCurrentModelRun() }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(workspace.modelState == .invalid || workspace.runState == .solving)
            .accessibilityHint("Explodes requirements using the selected backend")
    }

    private var familyLabel: some View {
        Text(workspace.currentModelFamily.displayName).font(.callout).foregroundStyle(.secondary)
    }

    private func planSection(_ draft: MaterialRequirementsPlanningDraft) -> some View {
        GroupBox("Plan") {
            VStack(alignment: .leading, spacing: 10) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom, spacing: 16) { planFields(draft) }
                    VStack(alignment: .leading, spacing: 10) { planFields(draft) }
                }
                if draft.hasImportedDimensionIssue {
                    Text("Imported schedules need review. All available cells are retained. Missing period names, receipts, and MPS quantities stay empty; blank capacity means unbounded. MPS entries without an item appear as incomplete items requiring metadata; their lot-sizing rule initially displays LFL. Review Items and Schedules before accepting the displayed periods.")
                        .font(.caption)
                    Button("Use Displayed Dimensions") {
                        update("Review Imported MRP Dimensions") { $0.confirmImportedDimensions() }
                    }
                    .accessibilityHint("Accepts displayed dimensions and blank unbounded capacities. Missing names, item metadata, receipts, and MPS values still need correction.")
                }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private func planFields(_ draft: MaterialRequirementsPlanningDraft) -> some View {
        labeledField("Title", text: planBinding(\.title, action: "Edit Plan Title"), width: 310, id: "mrp-title")
        labeledField("Time unit", text: planBinding(\.timeUnit, action: "Edit Time Unit"), width: 130, id: "mrp-time-unit")
        labeledField("Periods per year", text: planBinding(\.periodsPerYear, action: "Edit Periods Per Year"), width: 120, id: "mrp-periods-per-year")
        Text("\(draft.items.count) items · \(draft.bucketNames.count) buckets")
            .font(.callout).foregroundStyle(.secondary)
            .accessibilityLabel("\(draft.items.count) items and \(draft.bucketNames.count) time buckets")
    }

    private func itemSection(_ draft: MaterialRequirementsPlanningDraft) -> some View {
        GroupBox("Item master") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Select one item to edit. Copy Table exports every item as one spreadsheet range.")
                    .font(.caption).foregroundStyle(.secondary)
                selectionBar(draft)
                if let item = selectedItem {
                    itemIdentity(item)
                    itemPlanning(item)
                    itemCosts(item)
                }
                HStack(alignment: .top, spacing: 10) {
                    Button("Add Item", systemImage: "plus") {
                        var itemID: UUID?
                        update("Add Item") { itemID = $0.addItem() }
                        selectedItemID = itemID
                        if let itemID { focusedField = .item(itemID) }
                    }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .accessibilityHint("Adds an item and moves keyboard focus to its identifier")
                    SpreadsheetTransferActions(
                        subject: "MRP item master", issue: transferIssue,
                        paste: pasteItems, copy: copyItems
                    )
                }
            }
            .padding(8)
        }
    }

    private func selectionBar(_ draft: MaterialRequirementsPlanningDraft) -> some View {
        HStack(spacing: 10) {
            Picker("Item", selection: Binding(
                get: { selectedItem?.id },
                set: { selectedItemID = $0 }
            )) {
                ForEach(draft.items) { item in
                    Text(item.identifier.isEmpty ? "Untitled item" : item.identifier).tag(Optional(item.id))
                }
            }
            .frame(maxWidth: 320)
            .accessibilityLabel("Item to edit")
            if let item = selectedItem {
                Button("Remove Item", systemImage: "minus.circle") {
                    let index = draft.items.firstIndex(where: { $0.id == item.id }) ?? 0
                    update("Remove Item") { $0.removeItem(id: item.id) }
                    let remaining = workspace.materialRequirementsPlanningDraft?.items ?? []
                    selectedItemID = remaining.isEmpty ? nil : remaining[min(index, remaining.count - 1)].id
                    if selectedSection == .items, let selectedItemID { focusedField = .item(selectedItemID) }
                    else { focusedField = .bucket(bucketRange(count: draft.bucketNames.count).lowerBound) }
                }
                .disabled(draft.items.count <= 1)
                .accessibilityLabel("Remove item \(item.identifier)")
            }
        }
    }

    private func itemIdentity(_ item: MRPItemDraft) -> some View {
        GroupBox("Identity") {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 12) { itemIdentityFields(item) }
                VStack(alignment: .leading, spacing: 10) { itemIdentityFields(item) }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private func itemIdentityFields(_ item: MRPItemDraft) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Identifier").font(.caption).foregroundStyle(.secondary)
            TextField("Item identifier", text: Binding(
                get: { currentItem(item.id)?.identifier ?? "" },
                set: { value in update("Rename Item") { $0.renameItem(id: item.id, to: value) } }
            ))
            .textFieldStyle(.roundedBorder).frame(width: 160)
            .focused($focusedField, equals: .item(item.id))
            .accessibilityLabel("Item identifier")
            .accessibilityIdentifier("mrp-item-identifier-\(item.id.uuidString)")
        }
        itemField("Description", item: item, keyPath: \.description, width: 270)
        itemField("Level", item: item, keyPath: \.levelCode, width: 70)
        itemField("Source", item: item, keyPath: \.sourceCode, width: 80)
        itemField("Material type", item: item, keyPath: \.materialType, width: 130)
        itemField("Unit", item: item, keyPath: \.unit, width: 90)
    }

    private func itemPlanning(_ item: MRPItemDraft) -> some View {
        GroupBox("Planning policy") {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 12) { itemPlanningFields(item) }
                VStack(alignment: .leading, spacing: 10) { itemPlanningFields(item) }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private func itemPlanningFields(_ item: MRPItemDraft) -> some View {
        itemField("Lead time", item: item, keyPath: \.leadTime, width: 100)
        VStack(alignment: .leading, spacing: 4) {
            Text("Lot-sizing rule").font(.caption).foregroundStyle(.secondary)
            Picker("Lot-sizing rule", selection: Binding(
                get: { currentItem(item.id)?.lotSizingRule ?? .lotForLot },
                set: { value in updateItem(item.id, "Change Lot-Sizing Rule") { $0.lotSizingRule = value } }
            )) {
                ForEach([MRPLotSizingRule.lotForLot, .economicOrderQuantity, .leastUnitCost, .leastTotalCost, .partPeriodBalancing], id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .labelsHidden()
            .frame(width: 210)
            .accessibilityLabel("Lot-sizing rule for \(item.identifier)")
        }
        itemField("Lookahead", item: item, keyPath: \.lotSizingLookahead, width: 100)
    }

    private func itemCosts(_ item: MRPItemDraft) -> some View {
        GroupBox("Demand, inventory, and cost") {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 12) { itemCostFields(item) }
                VStack(alignment: .leading, spacing: 10) { itemCostFields(item) }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private func itemCostFields(_ item: MRPItemDraft) -> some View {
        itemField("Annual demand", item: item, keyPath: \.annualDemand, width: 110)
        itemField("Unit cost", item: item, keyPath: \.unitCost, width: 100)
        itemField("Ordering cost", item: item, keyPath: \.orderingCost, width: 110)
        itemField("Annual holding", item: item, keyPath: \.annualHoldingCost, width: 110)
        itemField("Safety stock", item: item, keyPath: \.safetyStock, width: 105)
        itemField("Initial on hand", item: item, keyPath: \.initialOnHand, width: 110)
    }

    private func scheduleSection(_ draft: MaterialRequirementsPlanningDraft) -> some View {
        GroupBox("Time-phased schedules") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Edit one item at a time. Copy Table transfers every item and bucket in a long-form range that remains usable for large plans.")
                    .font(.caption).foregroundStyle(.secondary)
                selectionBar(draft)
                if let item = selectedItem {
                    Toggle("Include a master production schedule for \(item.identifier)", isOn: Binding(
                        get: { currentItem(item.id)?.masterProductionSchedule != nil },
                        set: { enabled in
                            updateItem(item.id, "Toggle Master Production Schedule") { row in
                                row.masterProductionSchedule = enabled ? Array(repeating: "0", count: draft.bucketNames.count) : nil
                            }
                        }
                    ))
                    .accessibilityHint("When disabled, this item is driven only by parent requirements")
                    if draft.bucketNames.count > MatrixEditorNavigation.columnsPerGroup {
                        bucketNavigation(draft)
                    }
                    ScrollView(.horizontal) {
                        VStack(alignment: .leading, spacing: 8) {
                            scheduleHeader
                            ForEach(Array(bucketRange(count: draft.bucketNames.count)), id: \.self) { index in
                                scheduleRow(item, index: index, draft: draft)
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }
                HStack(alignment: .top, spacing: 10) {
                    Button("Add Bucket", systemImage: "plus") {
                        var index: Int?
                        update("Add Time Bucket") { index = $0.addBucket() }
                        if let index { scheduleGroup = index / MatrixEditorNavigation.columnsPerGroup; focusedField = .bucket(index) }
                    }
                    .accessibilityHint("Adds a time bucket to every item schedule")
                    SpreadsheetTransferActions(
                        subject: "all MRP schedules", issue: transferIssue,
                        paste: pasteSchedules, copy: copySchedules
                    )
                }
            }
            .padding(8)
        }
    }

    private func bucketRange(count: Int) -> Range<Int> {
        MatrixEditorNavigation(columnGroup: scheduleGroup).columns(columnCount: count)
    }

    private func bucketNavigation(_ draft: MaterialRequirementsPlanningDraft) -> some View {
        let groups = MatrixEditorNavigation().groupCount(columnCount: draft.bucketNames.count)
        let group = bucketRange(count: draft.bucketNames.count).lowerBound / MatrixEditorNavigation.columnsPerGroup
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Picker("Periods", selection: Binding(get: { group }, set: {
                    scheduleGroup = $0
                    focusedField = .bucket(bucketRange(count: draft.bucketNames.count).lowerBound)
                })) {
                    ForEach(0..<groups, id: \.self) { index in
                        let range = MatrixEditorNavigation(columnGroup: index).columns(columnCount: draft.bucketNames.count)
                        Text("\(range.lowerBound + 1)–\(range.upperBound)").tag(index)
                    }
                }.frame(width: 220).accessibilityLabel("MRP schedule period group")
                Button("Previous Periods") {
                    scheduleGroup = group - 1
                    focusedField = .bucket(bucketRange(count: draft.bucketNames.count).lowerBound)
                }.disabled(group == 0)
                Button("Next Periods") {
                    scheduleGroup = group + 1
                    focusedField = .bucket(bucketRange(count: draft.bucketNames.count).lowerBound)
                }.disabled(group + 1 == groups)
            }
            Text("Copy/Paste Table transfers every item and period, including periods outside this group.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var scheduleHeader: some View {
        HStack(spacing: 8) {
            header("Bucket", width: 170); header("Scheduled receipt", width: 130)
            header("Capacity", width: 120); header("MPS", width: 120)
            Color.clear.frame(width: 28, height: 1)
        }
        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
    }

    private func scheduleRow(_ item: MRPItemDraft, index: Int, draft: MaterialRequirementsPlanningDraft) -> some View {
        HStack(spacing: 8) {
            TextField("Bucket name", text: Binding(
                get: { workspace.materialRequirementsPlanningDraft?.bucketNames[safe: index] ?? "" },
                set: { value in update("Rename Time Bucket") { if $0.bucketNames.indices.contains(index) { $0.bucketNames[index] = value } } }
            ))
            .textFieldStyle(.roundedBorder).frame(width: 170)
            .focused($focusedField, equals: .bucket(index))
            .accessibilityLabel("Time bucket \(index + 1)")
            scheduleField("Scheduled receipt for \(item.identifier) in \(draft.bucketNames[index])", itemID: item.id, index: index, keyPath: \.scheduledReceipts, width: 130)
            scheduleField("Capacity for \(item.identifier) in \(draft.bucketNames[index])", itemID: item.id, index: index, keyPath: \.capacity, width: 120)
            TextField("MPS", text: Binding(
                get: { currentItem(item.id)?.masterProductionSchedule?[safe: index] ?? "" },
                set: { value in
                    updateItem(item.id, "Edit Master Production Schedule") { row in
                        guard row.masterProductionSchedule?.indices.contains(index) == true else { return }
                        row.masterProductionSchedule?[index] = value
                    }
                }
            ))
            .textFieldStyle(.roundedBorder).frame(width: 120)
            .disabled(item.masterProductionSchedule == nil)
            .accessibilityLabel("Master production schedule for \(item.identifier) in \(draft.bucketNames[index])")
            Button {
                update("Remove Time Bucket") { $0.removeBucket(at: index) }
                let count = workspace.materialRequirementsPlanningDraft?.bucketNames.count ?? 0
                let next = min(index, max(0, count - 1))
                scheduleGroup = next / MatrixEditorNavigation.columnsPerGroup
                focusedField = count > 0 ? .bucket(next) : nil
            } label: { Image(systemName: "minus.circle") }
            .buttonStyle(.borderless).disabled(draft.bucketNames.count <= 1)
            .accessibilityLabel("Remove time bucket \(draft.bucketNames[index])")
        }
    }

    private func billSection(_ draft: MaterialRequirementsPlanningDraft) -> some View {
        GroupBox("Bill of materials") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Each row says how many units of a component are required for one parent. Validation catches unknown items and cycles.")
                    .font(.caption).foregroundStyle(.secondary)
                if draft.billComponents.isEmpty {
                    Text("No bill-of-materials relationships. Add a component or paste a table.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            header("Parent", width: 180); header("Component", width: 180)
                            header("Quantity per parent", width: 150); Color.clear.frame(width: 28, height: 1)
                        }
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        ForEach(draft.billComponents) { row in billRow(row) }
                    }
                    .padding(.bottom, 4)
                }
                HStack(alignment: .top, spacing: 10) {
                    Button("Add Component", systemImage: "plus") {
                        var rowID: UUID?
                        update("Add BOM Component") { rowID = $0.addBillComponent() }
                        if let rowID { focusedField = .bill(rowID) }
                    }
                    .focused($focusedField, equals: .addBill)
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .accessibilityHint("Adds a bill-of-materials relationship and moves focus to its parent")
                    SpreadsheetTransferActions(
                        subject: "bill of materials", issue: transferIssue,
                        paste: pasteBills, copy: copyBills
                    )
                }
            }
            .padding(8)
        }
    }

    private func billRow(_ row: MRPBillComponentDraft) -> some View {
        HStack(spacing: 8) {
            billField("Parent item", row: row, keyPath: \.parentIdentifier, width: 180, focus: true)
            billField("Component item", row: row, keyPath: \.itemIdentifier, width: 180)
            billField("Quantity per parent", row: row, keyPath: \.quantityPerParent, width: 150)
            Button {
                let index = draft?.billComponents.firstIndex(where: { $0.id == row.id }) ?? 0
                update("Remove BOM Component") { $0.removeBillComponent(id: row.id) }
                let remaining = draft?.billComponents ?? []
                focusedField = remaining.isEmpty ? .addBill : .bill(remaining[min(index, remaining.count - 1)].id)
            } label: { Image(systemName: "minus.circle") }
            .buttonStyle(.borderless).accessibilityLabel("Remove component \(row.itemIdentifier) from \(row.parentIdentifier)")
        }
    }

    @ViewBuilder
    private func issues(_ draft: MaterialRequirementsPlanningDraft) -> some View {
        let diagnostics = draft.draftDiagnostics().filter { $0.severity != .info }
        if !diagnostics.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                    Label(diagnostic.message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(diagnostic.severity == .error ? .red : .orange)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Material requirements planning input issues")
        }
    }

    private func itemField(
        _ label: String, item: MRPItemDraft, keyPath: WritableKeyPath<MRPItemDraft, String>, width: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: Binding(
                get: { currentItem(item.id)?[keyPath: keyPath] ?? "" },
                set: { value in updateItem(item.id, "Edit Item") { $0[keyPath: keyPath] = value } }
            ))
            .textFieldStyle(.roundedBorder).frame(width: width)
            .accessibilityLabel("\(label) for \(item.identifier)")
        }
    }

    private func scheduleField(
        _ label: String, itemID: UUID, index: Int,
        keyPath: WritableKeyPath<MRPItemDraft, [String]>, width: CGFloat
    ) -> some View {
        TextField("", text: Binding(
            get: { currentItem(itemID)?[keyPath: keyPath][safe: index] ?? "" },
            set: { value in
                updateItem(itemID, "Edit Item Schedule") { item in
                    guard item[keyPath: keyPath].indices.contains(index) else { return }
                    item[keyPath: keyPath][index] = value
                }
            }
        ))
        .textFieldStyle(.roundedBorder).frame(width: width).accessibilityLabel(label)
    }

    private func billField(
        _ label: String, row: MRPBillComponentDraft,
        keyPath: WritableKeyPath<MRPBillComponentDraft, String>, width: CGFloat, focus: Bool = false
    ) -> some View {
        let field = TextField(label, text: Binding(
            get: { workspace.materialRequirementsPlanningDraft?.billComponents.first(where: { $0.id == row.id })?[keyPath: keyPath] ?? "" },
            set: { value in
                update("Edit BOM Component") { draft in
                    guard let index = draft.billComponents.firstIndex(where: { $0.id == row.id }) else { return }
                    draft.billComponents[index][keyPath: keyPath] = value
                }
            }
        ))
        .textFieldStyle(.roundedBorder).frame(width: width).accessibilityLabel(label)
        return Group {
            if focus { field.focused($focusedField, equals: .bill(row.id)) } else { field }
        }
    }

    private func labeledField(_ label: String, text: Binding<String>, width: CGFloat, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: text).textFieldStyle(.roundedBorder).frame(width: width)
                .accessibilityLabel(label).accessibilityIdentifier(id)
        }
    }

    private func header(_ text: String, width: CGFloat) -> some View {
        Text(text).frame(width: width, alignment: .leading)
    }

    private func planBinding(
        _ keyPath: WritableKeyPath<MaterialRequirementsPlanningDraft, String>, action: String
    ) -> Binding<String> {
        Binding(
            get: { workspace.materialRequirementsPlanningDraft?[keyPath: keyPath] ?? "" },
            set: { value in update(action) { $0[keyPath: keyPath] = value } }
        )
    }

    private func currentItem(_ id: UUID) -> MRPItemDraft? {
        workspace.materialRequirementsPlanningDraft?.items.first(where: { $0.id == id })
    }

    private func updateItem(_ id: UUID, _ actionName: String, _ mutation: (inout MRPItemDraft) -> Void) {
        update(actionName) { draft in
            guard let index = draft.items.firstIndex(where: { $0.id == id }) else { return }
            mutation(&draft.items[index])
        }
    }

    private func update(_ actionName: String, _ mutation: (inout MaterialRequirementsPlanningDraft) -> Void) {
        guard var next = workspace.materialRequirementsPlanningDraft else { return }
        mutation(&next)
        workspace.replaceMaterialRequirementsPlanningDraft(next, undoManager: undoManager, actionName: actionName)
    }

    private func selectFirstItemIfNeeded() {
        guard let draft else { selectedItemID = nil; return }
        if selectedItemID == nil || !draft.items.contains(where: { $0.id == selectedItemID }) {
            selectedItemID = draft.items.first?.id
        }
    }

    private func pasteItems() {
        do {
            var next = try requireDraft(); try next.replaceItems(withTabularText: SpreadsheetClipboard.read())
            workspace.replaceMaterialRequirementsPlanningDraft(next, undoManager: undoManager, actionName: "Paste Item Master")
            selectedItemID = next.items.first?.id; transferIssue = nil
            if let selectedItemID { focusedField = .item(selectedItemID) }
        } catch { transferIssue = String(describing: error) }
    }

    private func copyItems() { guard let draft else { return }; SpreadsheetClipboard.write(draft.itemTabularText()); transferIssue = nil }

    private func pasteSchedules() {
        do {
            var next = try requireDraft(); try next.replaceSchedules(withTabularText: SpreadsheetClipboard.read())
            workspace.replaceMaterialRequirementsPlanningDraft(next, undoManager: undoManager, actionName: "Paste Schedules")
            focusedField = .bucket(bucketRange(count: next.bucketNames.count).lowerBound)
            transferIssue = nil
        } catch { transferIssue = String(describing: error) }
    }

    private func copySchedules() { guard let draft else { return }; SpreadsheetClipboard.write(draft.scheduleTabularText()); transferIssue = nil }

    private func pasteBills() {
        do {
            var next = try requireDraft(); try next.replaceBillComponents(withTabularText: SpreadsheetClipboard.read())
            workspace.replaceMaterialRequirementsPlanningDraft(next, undoManager: undoManager, actionName: "Paste Bill of Materials")
            if case let .bill(id) = focusedField, next.billComponents.contains(where: { $0.id == id }) { }
            else { focusedField = next.billComponents.first.map { .bill($0.id) } ?? .addBill }
            transferIssue = nil
        } catch { transferIssue = String(describing: error) }
    }

    private func copyBills() { guard let draft else { return }; SpreadsheetClipboard.write(draft.billTabularText()); transferIssue = nil }

    private func requireDraft() throws -> MaterialRequirementsPlanningDraft {
        guard let draft else { throw SpreadsheetTransferError.emptyClipboard }
        return draft
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}
