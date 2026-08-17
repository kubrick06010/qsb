import SwiftUI
import QSBCore

private enum NewModelFamily: String, CaseIterable, Identifiable {
    case all
    case linearProgramming
    case inventory
    case networks
    case forecasting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All Models"
        case .linearProgramming: "Linear / Integer Programming"
        case .inventory: "Inventory"
        case .networks: "Networks"
        case .forecasting: "Forecasting"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "square.grid.2x2"
        case .linearProgramming: "chart.line.uptrend.xyaxis"
        case .inventory: "shippingbox"
        case .networks: "point.3.connected.trianglepath.dotted"
        case .forecasting: "chart.xyaxis.line"
        }
    }

    var tint: Color {
        switch self {
        case .all, .linearProgramming: .accentColor
        case .inventory: .green
        case .networks: .purple
        case .forecasting: .orange
        }
    }
}

private enum NewModelCreationAction: Hashable {
    case linearProgramming
    case inventory(InventoryProblemKind)
    case network(NetworkDraftKind)
    case assignment
    case transportation
    case minimumCostTransshipment
    case forecasting(ForecastingMethod)
}

private struct NewModelTemplate: Identifiable {
    let id: String
    let family: NewModelFamily
    let title: String
    let description: String
    let systemImage: String
    let action: NewModelCreationAction
}

struct NewModelPickerView: View {
    @Bindable var workspace: QSBWorkspace
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFamily: NewModelFamily = .all
    @State private var selectedTemplateID: String?

    private let templates: [NewModelTemplate] = Self.makeTemplates()

    private var selectedTemplate: NewModelTemplate? {
        templates.first { $0.id == selectedTemplateID }
    }

    private var visibleTemplates: [NewModelTemplate] {
        selectedFamily == .all ? templates : templates.filter { $0.family == selectedFamily }
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                List(selection: $selectedFamily) {
                    ForEach(NewModelFamily.allCases) { family in
                        Button {
                            selectedFamily = family
                        } label: {
                            Label(family.title, systemImage: family.systemImage)
                        }
                        .buttonStyle(.plain)
                        .tag(family)
                            .accessibilityIdentifier("new-model-family-\(family.rawValue)")
                    }
                }
                .listStyle(.sidebar)
                .navigationTitle("New Model")
                .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 270)
            } detail: {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(selectedFamily.title)
                            .font(.title2.weight(.semibold))
                        Text(selectedFamily == .all
                             ? "Choose a model template to start editing."
                             : "Choose a \(selectedFamily.title.lowercased()) model template.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 180), spacing: 16)],
                            spacing: 16
                        ) {
                            ForEach(visibleTemplates) { template in
                                NewModelTemplateCard(
                                    template: template,
                                    isSelected: selectedTemplateID == template.id
                                ) {
                                    selectedTemplateID = template.id
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                    }
                }
                .background(.regularMaterial)
            }
            .frame(minHeight: 500)

            Divider()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("new-model-cancel")
                Button("Create") { createSelectedModel() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedTemplate == nil)
                    .accessibilityIdentifier("new-model-create")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 900, idealWidth: 1_080, minHeight: 600, idealHeight: 700)
        .onChange(of: selectedFamily) { _, _ in
            selectedTemplateID = nil
        }
    }

    private func createSelectedModel() {
        guard let action = selectedTemplate?.action else { return }
        switch action {
        case .linearProgramming:
            workspace.startNewLinearProgram()
        case .inventory(let kind):
            workspace.startNewInventory(kind)
        case .network(let kind):
            workspace.startNewNetwork(kind)
        case .assignment:
            workspace.startNewAssignment()
        case .transportation:
            workspace.startNewTransportation()
        case .minimumCostTransshipment:
            workspace.startNewNetworkFlow()
        case .forecasting(let method):
            workspace.startNewForecasting(method)
        }
        dismiss()
    }

    private static func makeTemplates() -> [NewModelTemplate] {
        let linear = NewModelTemplate(
            id: "linear-programming",
            family: .linearProgramming,
            title: "Linear / Integer Programming",
            description: "Optimize decisions with linear, integer, or binary constraints.",
            systemImage: "chart.line.uptrend.xyaxis",
            action: .linearProgramming
        )
        let inventory = InventoryProblemKind.allCases.map { kind in
            NewModelTemplate(
                id: "inventory-\(kind.rawValue)", family: .inventory, title: kind.displayName,
                description: Self.inventoryDescription(for: kind), systemImage: "shippingbox", action: .inventory(kind)
            )
        }
        let networks = NetworkDraftKind.allCases.map { kind in
            NewModelTemplate(
                id: "network-\(kind.rawValue)", family: .networks, title: kind.displayName,
                description: Self.networkDescription(for: kind), systemImage: "point.3.connected.trianglepath.dotted", action: .network(kind)
            )
        }
        let additionalNetworks = [
            NewModelTemplate(id: "network-assignment", family: .networks, title: "Assignment", description: "Match tasks to resources at minimum total cost.", systemImage: "tablecells", action: .assignment),
            NewModelTemplate(id: "network-transportation", family: .networks, title: "Transportation", description: "Allocate shipments from sources to destinations at minimum cost.", systemImage: "tablecells", action: .transportation),
            NewModelTemplate(id: "network-minimum-cost-transshipment", family: .networks, title: "Minimum-Cost Transshipment", description: "Move flow through a network while minimizing total cost.", systemImage: "arrow.triangle.branch", action: .minimumCostTransshipment)
        ]
        let forecasting = ForecastingMethod.allCases.map { method in
            NewModelTemplate(
                id: "forecasting-\(method.rawValue)", family: .forecasting, title: method.displayName,
                description: Self.forecastingDescription(for: method), systemImage: "chart.xyaxis.line", action: .forecasting(method)
            )
        }
        return [linear] + inventory + networks + additionalNetworks + forecasting
    }

    private static func inventoryDescription(for kind: InventoryProblemKind) -> String {
        switch kind {
        case .eoq: "Calculate an economic order quantity for replenishment decisions."
        case .quantityDiscountEOQ: "Choose order quantities when unit costs change by volume."
        case .newsboy: "Set an order quantity for uncertain demand and limited inventory."
        case .lotSizing: "Plan production quantities across multiple demand periods."
        case .stochasticReview: "Choose a review policy for inventory under uncertain demand."
        }
    }

    private static func networkDescription(for kind: NetworkDraftKind) -> String {
        switch kind {
        case .shortestPath: "Find the least-cost route between nodes."
        case .minimumSpanningTree: "Connect all nodes with minimum total edge cost."
        case .maxFlow: "Find the maximum feasible flow through a capacitated network."
        case .travelingSalesperson: "Find a minimum-cost tour visiting every node."
        }
    }

    private static func forecastingDescription(for method: ForecastingMethod) -> String {
        switch method {
        case .linearTrend: "Forecast a series using a fitted linear trend."
        case .movingAverage: "Forecast using the average of recent observations."
        case .exponentialSmoothing: "Forecast by weighting recent observations more heavily."
        case .multiplicativeSeasonalDecomposition: "Separate trend and seasonal effects in a series."
        case .ordinaryLeastSquares: "Estimate relationships between a response and predictors."
        }
    }
}

private struct NewModelTemplateCard: View {
    let template: NewModelTemplate
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: template.systemImage)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(template.family.tint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(template.title)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                Text(template.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .padding(12)
                        .accessibilityLabel("Selected")
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("new-model-template-\(template.id)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}
