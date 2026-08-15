import SwiftUI
import QSBCore

struct StochasticInventoryEditorView: View {
    @Bindable var workspace: QSBWorkspace

    var body: some View {
        Form {
            Section("Model identity") {
                TextField("Title", text: field(\.title))
                TextField("Time unit", text: field(\.timeUnit))
                Picker("Policy", selection: policyBinding) {
                    Text("Continuous · fixed order quantity").tag(StochasticInventoryPolicy.continuousFixedOrderQuantity)
                    Text("Continuous · order-up-to").tag(StochasticInventoryPolicy.continuousOrderUpTo)
                    Text("Periodic · fixed order interval").tag(StochasticInventoryPolicy.periodicFixedOrderInterval)
                    Text("Periodic · optional replenishment").tag(StochasticInventoryPolicy.periodicOptionalReplenishment)
                }
                .accessibilityIdentifier("inventory-stochastic-policy")
            }
            Section("Demand") {
                TextField("Demand distribution", text: field(\.demandDistribution))
                    .accessibilityIdentifier("inventory-stochastic-demand-distribution")
                TextField("Mean demand", text: field(\.meanDemand))
                TextField("Demand standard deviation", text: field(\.demandStandardDeviation))
            }
            Section("Ordering and economics") {
                TextField("Setup / order cost", text: field(\.setupCost))
                TextField("Unit acquisition cost", text: field(\.acquisitionCost))
                TextField("Unit holding cost", text: field(\.holdingCost))
                TextField("Backorder fraction (0–1)", text: field(\.backorderFraction))
                TextField("Backorder cost", text: field(\.backorderCost))
                TextField("Lost-sales fraction (0–1)", text: field(\.lostSalesFraction))
                TextField("Lost-sales cost", text: field(\.lostSalesCost))
                TextField("Fixed shortage cost", text: field(\.fixedShortageCost))
            }
            Section("Lead time") {
                TextField("Lead-time distribution", text: field(\.leadTimeDistribution))
                    .accessibilityIdentifier("inventory-stochastic-leadtime-distribution")
                TextField("Lead time", text: field(\.leadTime))
            }
            if isContinuousOrderUpTo {
                Section("Order-up-to policy") {
                    TextField("Average order size", text: field(\.averageOrderSize))
                }
            }
            if isPeriodicPolicy {
                Section("Periodic review policy") {
                    TextField("Review cost per review", text: field(\.reviewCost))
                }
            }
            Section {
                Label("Normal demand and constant lead time are the distributions supported by the existing native stochastic backend. Semantic validation remains in QSBCore.", systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(18)
        .navigationTitle("Stochastic Inventory Definition")
    }

    private var isContinuousOrderUpTo: Bool {
        workspace.inventoryStochasticDraft?.policy == .continuousOrderUpTo
    }

    private var isPeriodicPolicy: Bool {
        switch workspace.inventoryStochasticDraft?.policy {
        case .periodicFixedOrderInterval, .periodicOptionalReplenishment: true
        default: false
        }
    }

    private var policyBinding: Binding<StochasticInventoryPolicy> {
        Binding(get: { workspace.inventoryStochasticDraft?.policy ?? .continuousFixedOrderQuantity }, set: { value in
            workspace.updateInventoryDraft { draft in
                guard case .stochasticReview(var stochastic) = draft else { return }
                stochastic.policy = value
                draft = .stochasticReview(stochastic)
            }
        })
    }

    private func field(_ keyPath: WritableKeyPath<InventoryStochasticDraft, String>) -> Binding<String> {
        Binding(get: { workspace.inventoryStochasticDraft.map { $0[keyPath: keyPath] } ?? "" }, set: { value in
            workspace.updateInventoryDraft { draft in
                guard case .stochasticReview(var stochastic) = draft else { return }
                stochastic[keyPath: keyPath] = value
                draft = .stochasticReview(stochastic)
            }
        })
    }
}
