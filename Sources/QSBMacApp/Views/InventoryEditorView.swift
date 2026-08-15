import SwiftUI
import QSBCore

struct InventoryEditorView: View {
    @Bindable var workspace: QSBWorkspace

    private var selectedKind: Binding<InventoryProblemKind> {
        Binding(
            get: { workspace.inventoryDraft?.kind ?? .eoq },
            set: { kind in workspace.startNewInventory(kind) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(title: workspace.modelTitle, subtitle: "Native Inventory editor · \(workspace.modelState.rawValue)")
            if let draft = workspace.inventoryDraft {
                Picker("Inventory model", selection: selectedKind) {
                    Text("EOQ").tag(InventoryProblemKind.eoq)
                    Text("Quantity Discount EOQ").tag(InventoryProblemKind.quantityDiscountEOQ)
                    Text("Newsvendor").tag(InventoryProblemKind.newsboy)
                    Text("Lot Sizing").tag(InventoryProblemKind.lotSizing)
                    Text("Stochastic Review").tag(InventoryProblemKind.stochasticReview)
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .accessibilityLabel("Inventory model variant")

                if case .stochasticReview = draft {
                    StochasticInventoryEditorView(workspace: workspace)
                } else {
                    ScrollView([.vertical, .horizontal]) {
                        editor(draft)
                            .padding(18)
                            .frame(minWidth: 680, alignment: .topLeading)
                    }
                }
            } else {
                ContentUnavailableView("No Inventory model", systemImage: "shippingbox", description: Text("Choose an Inventory variant from New Model, or open a normalized or legacy Inventory model."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Inventory Definition")
    }

    @ViewBuilder
    private func editor(_ draft: InventoryDraft) -> some View {
        switch draft {
        case .eoq:
            EOQEditor(workspace: workspace)
        case .quantityDiscount:
            QuantityDiscountEditor(workspace: workspace)
        case .newsboy:
            NewsboyEditor(workspace: workspace)
        case .lotSizing:
            LotSizingEditor(workspace: workspace)
        case .stochasticReview:
            StochasticInventoryEditorView(workspace: workspace)
        }
    }
}

private struct EOQEditor: View {
    @Bindable var workspace: QSBWorkspace

    var body: some View {
        Form {
            Section("Model identity") {
                TextField("Title", text: field(\InventoryEOQDraft.title))
                TextField("Time unit", text: field(\InventoryEOQDraft.timeUnit))
            }
            Section("EOQ inputs") {
                TextField("Demand", text: field(\InventoryEOQDraft.demand))
                TextField("Setup cost", text: field(\InventoryEOQDraft.setupCost))
                TextField("Holding cost", text: field(\InventoryEOQDraft.holdingCost))
            }
            Section("Optional inputs") {
                TextField("Shortage cost", text: field(\InventoryEOQDraft.shortageCost))
                TextField("Replenishment / production rate", text: field(\InventoryEOQDraft.replenishmentRate))
                TextField("Lead time", text: field(\InventoryEOQDraft.leadTime))
                TextField("Acquisition cost", text: field(\InventoryEOQDraft.acquisitionCost))
                TextField("Known order quantity", text: field(\InventoryEOQDraft.knownOrderQuantity))
            }
            Section {
                Label("Derived quantities are calculated by QSBCore when the model is validated and run.", systemImage: "function")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func field(_ keyPath: WritableKeyPath<InventoryEOQDraft, String>) -> Binding<String> {
        Binding(get: {
            guard case .eoq(let draft) = workspace.inventoryDraft else { return "" }
            return draft[keyPath: keyPath]
        }, set: { value in
            workspace.updateInventoryDraft { draft in
                guard case .eoq(var valueDraft) = draft else { return }
                valueDraft[keyPath: keyPath] = value
                draft = .eoq(valueDraft)
            }
        })
    }
}

private struct QuantityDiscountEditor: View {
    @Bindable var workspace: QSBWorkspace

    var body: some View {
        Form {
            Section("Model identity") {
                TextField("Title", text: field(\InventoryQuantityDiscountDraft.title))
                TextField("Time unit", text: field(\InventoryQuantityDiscountDraft.timeUnit))
            }
            Section("Demand and cost inputs") {
                TextField("Demand", text: field(\InventoryQuantityDiscountDraft.demand))
                TextField("Setup cost", text: field(\InventoryQuantityDiscountDraft.setupCost))
                TextField("Holding cost", text: field(\InventoryQuantityDiscountDraft.holdingCost))
                TextField("Acquisition cost", text: field(\InventoryQuantityDiscountDraft.acquisitionCost))
                TextField("Known order quantity", text: field(\InventoryQuantityDiscountDraft.knownOrderQuantity))
            }
            Section {
                HStack {
                    Text("Discount tiers")
                    Spacer()
                    Button { workspace.updateInventoryDraft { $0.addDiscountBreak() } } label: {
                        Text("Add Tier")
                    }
                    .accessibilityLabel("Add discount tier")
                    .accessibilityIdentifier("inventory-add-tier")
                }
                ForEach(discountIndices, id: \.self) { index in
                    HStack {
                        Text("Tier \(index + 1)")
                            .frame(width: 70, alignment: .leading)
                        TextField("Minimum quantity", text: tierField(index, \InventoryDiscountBreakDraft.minimumQuantity))
                        TextField("Discount %", text: tierField(index, \InventoryDiscountBreakDraft.discountPercent))
                        Button("Remove", systemImage: "minus.circle") { workspace.updateInventoryDraft { $0.removeDiscountBreak(at: index) } }
                            .labelStyle(.iconOnly)
                            .disabled(discountIndices.count == 1)
                            .accessibilityLabel("Remove discount tier \(index + 1)")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var discountIndices: Range<Int> {
        guard case .quantityDiscount(let draft) = workspace.inventoryDraft else { return 0..<0 }
        return draft.discountBreaks.indices
    }

    private func field(_ keyPath: WritableKeyPath<InventoryQuantityDiscountDraft, String>) -> Binding<String> {
        Binding(get: {
            guard case .quantityDiscount(let draft) = workspace.inventoryDraft else { return "" }
            return draft[keyPath: keyPath]
        }, set: { value in
            workspace.updateInventoryDraft { draft in
                guard case .quantityDiscount(var valueDraft) = draft else { return }
                valueDraft[keyPath: keyPath] = value
                draft = .quantityDiscount(valueDraft)
            }
        })
    }

    private func tierField(_ index: Int, _ keyPath: WritableKeyPath<InventoryDiscountBreakDraft, String>) -> Binding<String> {
        Binding(get: {
            guard case .quantityDiscount(let draft) = workspace.inventoryDraft, draft.discountBreaks.indices.contains(index) else { return "" }
            return draft.discountBreaks[index][keyPath: keyPath]
        }, set: { value in
            workspace.updateInventoryDraft { draft in
                guard case .quantityDiscount(var valueDraft) = draft, valueDraft.discountBreaks.indices.contains(index) else { return }
                valueDraft.discountBreaks[index][keyPath: keyPath] = value
                draft = .quantityDiscount(valueDraft)
            }
        })
    }
}

private struct NewsboyEditor: View {
    @Bindable var workspace: QSBWorkspace

    var body: some View {
        Form {
            Section("Model identity") {
                TextField("Title", text: field(\InventoryNewsboyDraft.title))
                TextField("Time unit", text: field(\InventoryNewsboyDraft.timeUnit))
                TextField("Demand distribution", text: field(\InventoryNewsboyDraft.demandDistribution))
            }
            Section("Demand and economics") {
                TextField("Mean demand", text: field(\InventoryNewsboyDraft.meanDemand))
                TextField("Standard deviation", text: field(\InventoryNewsboyDraft.standardDeviation))
                TextField("Setup cost", text: field(\InventoryNewsboyDraft.setupCost))
                TextField("Acquisition cost", text: field(\InventoryNewsboyDraft.acquisitionCost))
                TextField("Selling price", text: field(\InventoryNewsboyDraft.sellingPrice))
                TextField("Shortage cost", text: field(\InventoryNewsboyDraft.shortageCost))
                TextField("Salvage value", text: field(\InventoryNewsboyDraft.salvageValue))
            }
            Section("Optional inputs") {
                TextField("Initial inventory", text: field(\InventoryNewsboyDraft.initialInventory))
                TextField("Known order quantity", text: field(\InventoryNewsboyDraft.knownOrderQuantity))
                TextField("Desired service level (%)", text: field(\InventoryNewsboyDraft.desiredServiceLevelPercent))
            }
        }
        .formStyle(.grouped)
    }

    private func field(_ keyPath: WritableKeyPath<InventoryNewsboyDraft, String>) -> Binding<String> {
        Binding(get: {
            guard case .newsboy(let draft) = workspace.inventoryDraft else { return "" }
            return draft[keyPath: keyPath]
        }, set: { value in
            workspace.updateInventoryDraft { draft in
                guard case .newsboy(var valueDraft) = draft else { return }
                valueDraft[keyPath: keyPath] = value
                draft = .newsboy(valueDraft)
            }
        })
    }
}

private struct LotSizingEditor: View {
    @Bindable var workspace: QSBWorkspace

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("Model identity") {
                HStack {
                    TextField("Title", text: field(\InventoryLotSizingDraft.title))
                    TextField("Time unit", text: field(\InventoryLotSizingDraft.timeUnit))
                }
                .padding(8)
            }
            HStack {
                Text("Periods (\(periodIndices.count))")
                    .font(.headline)
                    .accessibilityIdentifier("inventory-period-count")
                Spacer()
                Button { workspace.updateInventoryDraft { $0.addLotSizingPeriod() } } label: {
                    Text("Add Period")
                }
                .accessibilityLabel("Add lot sizing period")
                .accessibilityIdentifier("inventory-add-period")
            }
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 6) {
                    periodHeader
                    ForEach(periodIndices, id: \.self) { index in
                        HStack(spacing: 6) {
                            Text("Period \(index + 1)")
                                .frame(width: 90, alignment: .leading)
                            TextField("Name", text: periodField(index, \InventoryLotSizingPeriodDraft.name))
                                .frame(width: 120)
                            TextField("Demand", text: periodField(index, \InventoryLotSizingPeriodDraft.demand))
                                .frame(width: 90)
                            TextField("Setup", text: periodField(index, \InventoryLotSizingPeriodDraft.setupCost))
                                .frame(width: 90)
                            TextField("Variable", text: periodField(index, \InventoryLotSizingPeriodDraft.unitVariableCost))
                                .frame(width: 90)
                            TextField("Holding", text: periodField(index, \InventoryLotSizingPeriodDraft.unitHoldingCost))
                                .frame(width: 90)
                            TextField("Backorder", text: periodField(index, \InventoryLotSizingPeriodDraft.unitBackorderCost))
                                .frame(width: 90)
                            Button("Remove", systemImage: "minus.circle") { workspace.updateInventoryDraft { $0.removeLotSizingPeriod(at: index) } }
                                .labelStyle(.iconOnly)
                                .disabled(periodIndices.count == 1)
                                .accessibilityLabel("Remove period \(index + 1)")
                        }
                    }
                }
                .padding(8)
            }
            Label("Demand is integral in the existing lot-sizing model. Semantic checks remain in QSBCore.", systemImage: "info.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var periodHeader: some View {
        HStack(spacing: 6) {
            Text("").frame(width: 90)
            ForEach(["Name", "Demand", "Setup", "Variable", "Holding", "Backorder"], id: \.self) { title in
                Text(title).font(.caption.bold()).frame(width: title == "Name" ? 120 : 90, alignment: .leading)
            }
            Text("").frame(width: 28)
        }
    }

    private var periodIndices: Range<Int> {
        guard case .lotSizing(let draft) = workspace.inventoryDraft else { return 0..<0 }
        return draft.periods.indices
    }

    private func field(_ keyPath: WritableKeyPath<InventoryLotSizingDraft, String>) -> Binding<String> {
        Binding(get: {
            guard case .lotSizing(let draft) = workspace.inventoryDraft else { return "" }
            return draft[keyPath: keyPath]
        }, set: { value in
            workspace.updateInventoryDraft { draft in
                guard case .lotSizing(var valueDraft) = draft else { return }
                valueDraft[keyPath: keyPath] = value
                draft = .lotSizing(valueDraft)
            }
        })
    }

    private func periodField(_ index: Int, _ keyPath: WritableKeyPath<InventoryLotSizingPeriodDraft, String>) -> Binding<String> {
        Binding(get: {
            guard case .lotSizing(let draft) = workspace.inventoryDraft, draft.periods.indices.contains(index) else { return "" }
            return draft.periods[index][keyPath: keyPath]
        }, set: { value in
            workspace.updateInventoryDraft { draft in
                guard case .lotSizing(var valueDraft) = draft, valueDraft.periods.indices.contains(index) else { return }
                valueDraft.periods[index][keyPath: keyPath] = value
                draft = .lotSizing(valueDraft)
            }
        })
    }
}
