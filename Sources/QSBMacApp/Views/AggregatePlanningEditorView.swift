import SwiftUI
import QSBCore

struct AggregatePlanningEditorView: View {
    private enum PeriodSection: String, CaseIterable, Identifiable {
        case demand = "Demand & capacity"
        case production = "Production costs"
        case inventory = "Inventory & sourcing"
        case workforce = "Workforce"
        var id: String { rawValue }
    }

    @Bindable var workspace: QSBWorkspace
    @Environment(\.undoManager) private var undoManager
    @FocusState private var focusedPeriodID: UUID?
    @State private var section: PeriodSection = .demand
    @State private var transferIssue: String?

    private var draft: AggregatePlanningDraft? { workspace.aggregatePlanningDraft }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(title: workspace.modelTitle, subtitle: "Native aggregate-planning editor · \(workspace.modelState.rawValue)")
            if let draft {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 16) {
                        actionBar
                        issues(draft)
                        modelSection(draft)
                        periodSection(draft)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .navigationTitle("Aggregate Planning Definition")
        .onChange(of: draft?.periods.map(\.id) ?? []) { previous, current in
            guard let focusedPeriodID, !current.contains(focusedPeriodID) else { return }
            let index = previous.firstIndex(of: focusedPeriodID) ?? 0
            self.focusedPeriodID = current.isEmpty ? nil : current[min(index, current.count - 1)]
        }
        .onChange(of: section) { _, _ in transferIssue = nil }
    }

    private var actionBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                actionButtons
                Spacer()
                Text("Every period column is preserved in Copy Table")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) { actionButtons }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button("Validate", systemImage: "checkmark.seal") { workspace.validateCurrentModel() }
            .keyboardShortcut("v", modifiers: [.command, .shift])
        Button("Run", systemImage: "play.circle") { workspace.startCurrentModelRun() }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(workspace.modelState == .invalid || workspace.runState == .solving)
    }

    private func modelSection(_ draft: AggregatePlanningDraft) -> some View {
        GroupBox("Plan settings") {
            VStack(alignment: .leading, spacing: 10) {
                if draft.hasImportedDimensionIssue {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Review imported period dimensions", systemImage: "exclamationmark.triangle")
                        Text("All imported values are retained. Name extra periods and fill missing required cells. Blank maximum cells mean no upper limit; review them before accepting the displayed dimensions.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Use Displayed Dimensions") {
                            update("Review Imported Plan Dimensions") { $0.confirmImportedDimensions() }
                        }
                    }
                    .accessibilityElement(children: .contain)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) { primaryFields(draft) }
                    VStack(alignment: .leading, spacing: 10) { primaryFields(draft) }
                }
                Toggle("Regular capacity is specified per workforce unit", isOn: boolBinding(
                    get: { $0.capacityIsPerWorker }, set: { $0.capacityIsPerWorker = $1 }, action: "Change Capacity Basis"
                ))
                .accessibilityHint("When enabled, initial workforce is required and regular capacity is interpreted per worker")
                if draft.capacityIsPerWorker {
                    labeledField("Initial workforce", text: stringBinding(
                        get: { $0.initialWorkforce }, set: { $0.initialWorkforce = $1 }, action: "Edit Initial Workforce"
                    ), width: 140, id: "aggregate-initial-workforce")
                }
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func primaryFields(_ draft: AggregatePlanningDraft) -> some View {
        labeledField("Title", text: stringBinding(get: { $0.title }, set: { $0.title = $1 }, action: "Edit Plan Title"), width: 280, id: "aggregate-title")
        labeledField("Workforce unit", text: stringBinding(get: { $0.workforceUnit }, set: { $0.workforceUnit = $1 }, action: "Edit Workforce Unit"), width: 130, id: "aggregate-workforce-unit")
        labeledField("Capacity unit", text: stringBinding(get: { $0.capacityUnit }, set: { $0.capacityUnit = $1 }, action: "Edit Capacity Unit"), width: 130, id: "aggregate-capacity-unit")
        labeledField("Initial inventory", text: stringBinding(get: { $0.initialInventory }, set: { $0.initialInventory = $1 }, action: "Edit Initial Inventory"), width: 130, id: "aggregate-initial-inventory")
        VStack(alignment: .leading, spacing: 4) {
            Text("Planning formulation").font(.caption).foregroundStyle(.secondary)
            Picker("Planning formulation", selection: Binding(
                get: { draft.method.rawValue },
                set: { raw in if let method = AggregatePlanningLegacyMethod(rawValue: raw) { update("Change Planning Formulation") { $0.method = method } } }
            )) {
                Text("Simple").tag(AggregatePlanningLegacyMethod.simple.rawValue)
                Text("Transportation").tag(AggregatePlanningLegacyMethod.transportation.rawValue)
                Text("Linear programming").tag(AggregatePlanningLegacyMethod.linearProgramming.rawValue)
            }
            .labelsHidden()
            .frame(width: 190)
            .accessibilityLabel("Planning formulation")
        }
    }

    private func periodSection(_ draft: AggregatePlanningDraft) -> some View {
        GroupBox("Periods") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Period fields", selection: $section) {
                    ForEach(PeriodSection.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 860, alignment: .leading)
                .accessibilityLabel("Visible period fields")
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 8) {
                        periodHeader
                        ForEach(draft.periods) { period in periodRow(period, count: draft.periods.count) }
                    }
                    .padding(.bottom, 4)
                }
                HStack(spacing: 10) {
                    Button("Add Period", systemImage: "plus") {
                        var newID: UUID?
                        update("Add Period") { newID = $0.addPeriod() }
                        focusedPeriodID = newID
                    }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .accessibilityHint("Adds a period and moves keyboard focus to its name")
                    SpreadsheetTransferActions(subject: "all aggregate-planning period fields", issue: transferIssue, paste: pastePeriods, copy: copyPeriods)
                }
                Text("Copy Table exports all 20 columns even when one field group is visible. Blank maximum cells mean no upper limit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var periodHeader: some View {
        HStack(spacing: 8) {
            header("Period", 150)
            switch section {
            case .demand:
                header("Demand", 110); header("Regular capacity", 120); header("Capacity / unit", 115)
            case .production:
                header("Regular cost", 110); header("Undertime cost", 115); header("Overtime capacity", 125)
                header("Overtime cost", 110); header("Other unit cost", 115)
            case .inventory:
                header("Min inventory", 110); header("Max inventory", 110); header("Holding cost", 110)
                header("Max subcontract", 125); header("Subcontract cost", 120); header("Max backorder", 115); header("Backorder cost", 115)
            case .workforce:
                header("Min workforce", 115); header("Max workforce", 115); header("Hiring cost", 110); header("Dismissal cost", 115)
            }
            Color.clear.frame(width: 28, height: 1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    private func periodRow(_ period: AggregatePlanningPeriodDraft, count: Int) -> some View {
        HStack(spacing: 8) {
            periodField("Period name", period: period, keyPath: \.name, width: 150, focusID: period.id)
            switch section {
            case .demand:
                periodField("Demand for \(period.name)", period: period, keyPath: \.demand, width: 110)
                periodField("Regular capacity for \(period.name)", period: period, keyPath: \.regularCapacity, width: 120)
                periodField("Capacity requirement per unit for \(period.name)", period: period, keyPath: \.capacityRequirementPerUnit, width: 115)
            case .production:
                periodField("Regular cost for \(period.name)", period: period, keyPath: \.regularCost, width: 110)
                periodField("Undertime cost for \(period.name)", period: period, keyPath: \.undertimeCost, width: 115)
                periodField("Overtime capacity for \(period.name)", period: period, keyPath: \.overtimeCapacity, width: 125)
                periodField("Overtime cost for \(period.name)", period: period, keyPath: \.overtimeCost, width: 110)
                periodField("Other unit production cost for \(period.name)", period: period, keyPath: \.otherUnitProductionCost, width: 115)
            case .inventory:
                periodField("Minimum inventory for \(period.name)", period: period, keyPath: \.minimumInventory, width: 110)
                periodField("Maximum inventory for \(period.name)", period: period, keyPath: \.maximumInventory, width: 110)
                periodField("Inventory holding cost for \(period.name)", period: period, keyPath: \.inventoryHoldingCost, width: 110)
                periodField("Maximum subcontracting for \(period.name)", period: period, keyPath: \.maximumSubcontracting, width: 125)
                periodField("Subcontracting cost for \(period.name)", period: period, keyPath: \.subcontractingCost, width: 120)
                periodField("Maximum backorder for \(period.name)", period: period, keyPath: \.maximumBackorder, width: 115)
                periodField("Backorder cost for \(period.name)", period: period, keyPath: \.backorderCost, width: 115)
            case .workforce:
                periodField("Minimum workforce for \(period.name)", period: period, keyPath: \.minimumWorkforce, width: 115)
                periodField("Maximum workforce for \(period.name)", period: period, keyPath: \.maximumWorkforce, width: 115)
                periodField("Hiring cost for \(period.name)", period: period, keyPath: \.hiringCost, width: 110)
                periodField("Dismissal cost for \(period.name)", period: period, keyPath: \.dismissalCost, width: 115)
            }
            Button {
                guard let periods = draft?.periods,
                      let index = periods.firstIndex(where: { $0.id == period.id }), periods.count > 1 else { return }
                let nextID = periods[index == periods.count - 1 ? index - 1 : index + 1].id
                update("Remove Period") { $0.removePeriod(id: period.id) }
                focusedPeriodID = nextID
            } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
                .disabled(count <= 1)
                .accessibilityLabel("Remove period \(period.name)")
        }
    }

    @ViewBuilder
    private func periodField(_ label: String, period: AggregatePlanningPeriodDraft, keyPath: WritableKeyPath<AggregatePlanningPeriodDraft, String>, width: CGFloat, focusID: UUID? = nil) -> some View {
        let field = TextField(label, text: Binding(
            get: { workspace.aggregatePlanningDraft?.periods.first(where: { $0.id == period.id })?[keyPath: keyPath] ?? "" },
            set: { value in update("Edit Period") { draft in
                guard let index = draft.periods.firstIndex(where: { $0.id == period.id }) else { return }
                draft.periods[index][keyPath: keyPath] = value
            } }
        ))
        .textFieldStyle(.roundedBorder)
        .frame(width: width)
        .accessibilityLabel(label)
        if let focusID { field.focused($focusedPeriodID, equals: focusID) } else { field }
    }

    @ViewBuilder
    private func issues(_ draft: AggregatePlanningDraft) -> some View {
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
            .accessibilityLabel("Aggregate-planning input issues")
        }
    }

    private func labeledField(_ label: String, text: Binding<String>, width: CGFloat, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: text).textFieldStyle(.roundedBorder).frame(width: width)
                .accessibilityLabel(label).accessibilityIdentifier(id)
        }
    }

    private func header(_ title: String, _ width: CGFloat) -> some View { Text(title).frame(width: width, alignment: .leading) }

    private func stringBinding(get: @escaping (AggregatePlanningDraft) -> String, set: @escaping (inout AggregatePlanningDraft, String) -> Void, action: String) -> Binding<String> {
        Binding(get: { workspace.aggregatePlanningDraft.map(get) ?? "" }, set: { value in update(action) { set(&$0, value) } })
    }

    private func boolBinding(get: @escaping (AggregatePlanningDraft) -> Bool, set: @escaping (inout AggregatePlanningDraft, Bool) -> Void, action: String) -> Binding<Bool> {
        Binding(get: { workspace.aggregatePlanningDraft.map(get) ?? false }, set: { value in update(action) { set(&$0, value) } })
    }

    private func update(_ actionName: String, _ mutation: (inout AggregatePlanningDraft) -> Void) {
        guard var next = workspace.aggregatePlanningDraft else { return }
        mutation(&next)
        workspace.replaceAggregatePlanningDraft(next, undoManager: undoManager, actionName: actionName)
    }

    private func pastePeriods() {
        do {
            guard var next = draft else { throw SpreadsheetTransferError.emptyClipboard }
            try next.replacePeriods(withTabularText: SpreadsheetClipboard.read())
            workspace.replaceAggregatePlanningDraft(next, undoManager: undoManager, actionName: "Paste Aggregate Plan")
            if !next.periods.contains(where: { $0.id == focusedPeriodID }) {
                focusedPeriodID = next.periods.first?.id
            }
            transferIssue = nil
        } catch { transferIssue = String(describing: error) }
    }

    private func copyPeriods() {
        guard let draft else { return }
        SpreadsheetClipboard.write(draft.tabularText())
        transferIssue = nil
    }
}
