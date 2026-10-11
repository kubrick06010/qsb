import SwiftUI
import QSBCore

private enum NewModelFamily: String, CaseIterable, Identifiable {
    case all
    case linearProgramming
    case inventory
    case networks
    case forecasting
    case analysis
    case queuing
    case optimization
    case planning
    case quality
    case simulation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All Models"
        case .linearProgramming: "Linear / Integer Programming"
        case .inventory: "Inventory"
        case .networks: "Networks"
        case .forecasting: "Forecasting"
        case .analysis: "Decision & Markov Analysis"
        case .queuing: "Queuing"
        case .optimization: "Optimization"
        case .planning: "Planning & Scheduling"
        case .quality: "Quality"
        case .simulation: "Simulation"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "square.grid.2x2"
        case .linearProgramming: "chart.line.uptrend.xyaxis"
        case .inventory: "shippingbox"
        case .networks: "point.3.connected.trianglepath.dotted"
        case .forecasting: "chart.xyaxis.line"
        case .analysis: "point.3.connected.trianglepath.dotted"
        case .queuing: "person.2.wave.2"
        case .optimization: "function"
        case .planning: "calendar.badge.clock"
        case .quality: "checkmark.seal"
        case .simulation: "waveform.path.ecg"
        }
    }

    var tint: Color {
        switch self {
        case .all, .linearProgramming: .accentColor
        case .inventory: .green
        case .networks: .purple
        case .forecasting: .orange
        case .analysis: .blue
        case .queuing: .teal
        case .optimization: .indigo
        case .planning: .cyan
        case .quality: .mint
        case .simulation: .pink
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
    case markov
    case queuing(QueuingProblemKind)
    case decisionAnalysis(DecisionAnalysisProblemKind)
    case projectScheduling
    case aggregatePlanning
    case materialRequirementsPlanning
    case simulation
    case boundedKnapsack
    case acceptanceSampling
    case qualityControl
    case quadraticProgramming
    case nonlinearProgramming
    case goalProgramming
    case facilityLocation
    case lineBalancing
    case facilityLayout
    case guided(SampleModel)
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
        case .markov:
            workspace.startNewMarkov()
        case .queuing(let kind):
            workspace.startNewQueuing(kind)
        case .decisionAnalysis(let kind):
            workspace.startNewDecisionAnalysis(kind)
        case .projectScheduling:
            workspace.startNewProjectScheduling()
        case .aggregatePlanning:
            workspace.startNewAggregatePlanning()
        case .materialRequirementsPlanning:
            workspace.startNewMaterialRequirementsPlanning()
        case .simulation:
            workspace.startNewSimulation()
        case .boundedKnapsack:
            workspace.startNewKnapsack()
        case .acceptanceSampling:
            workspace.startNewAcceptanceSampling()
        case .qualityControl:
            workspace.startNewQualityControl()
        case .facilityLayout:
            workspace.startNewFacilityLayout()
        case .lineBalancing:
            workspace.startNewLineBalancing()
        case .facilityLocation:
            workspace.startNewFacilityLocation()
        case .goalProgramming:
            workspace.startNewGoalProgramming()
        case .nonlinearProgramming:
            workspace.startNewNonlinearProgramming()
        case .quadraticProgramming:
            workspace.startNewQuadraticProgramming()
        case .guided(let sample):
            workspace.startNewGuidedModel(from: sample)
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
        let markov = NewModelTemplate(
            id: "markov-analysis", family: .analysis, title: "Markov Analysis",
            description: "Edit states, transition probabilities, costs, and transient periods.",
            systemImage: "point.3.connected.trianglepath.dotted", action: .markov
        )
        let decisions = [DecisionAnalysisProblemKind.payoff, .bayesian, .decisionTree, .zeroSumGame].map { kind in
            let description: String = switch kind {
            case .payoff: "Compare decisions with prior probabilities, evidence, and payoffs."
            case .bayesian: "Update state probabilities from observed outcomes."
            case .decisionTree: "Build decisions, chance branches, and terminal payoffs."
            case .zeroSumGame: "Compare two players' strategies with a payoff matrix."
            }
            return NewModelTemplate(
                id: "decision-\(kind.rawValue)", family: .analysis, title: kind.displayName,
                description: description,
                systemImage: kind == .decisionTree ? "point.3.connected.trianglepath.dotted" : "tablecells",
                action: .decisionAnalysis(kind)
            )
        }
        let queues = [QueuingProblemKind.mm1, .finiteCapacity].map { kind in
            NewModelTemplate(
                id: "queuing-\(kind.rawValue)", family: .queuing, title: kind.displayName,
                description: kind == .mm1
                    ? "Analyze a single-server queue with exponential arrivals and service."
                    : "Analyze a multi-server queue with limited waiting capacity.",
                systemImage: "person.2.wave.2", action: .queuing(kind)
            )
        }
        let guided = [
            NewModelTemplate(
                id: "guided-quadratic-programming", family: .optimization,
                title: "Quadratic Programming",
                description: "Edit variables, bounds, objective coefficients, a quadratic matrix, and constraints in native tables.",
                systemImage: "function", action: .quadraticProgramming
            ),
            NewModelTemplate(
                id: "guided-nonlinear-programming", family: .optimization,
                title: "Nonlinear Programming",
                description: "Edit an objective expression, variables, bounds, and constraints in a guided starter.",
                systemImage: "function", action: .nonlinearProgramming
            ),
            NewModelTemplate(
                id: "guided-goal-programming", family: .optimization,
                title: "Goal Programming",
                description: "Prioritize several objectives over shared variables and constraints.",
                systemImage: "list.number", action: .goalProgramming
            ),
            NewModelTemplate(
                id: "bounded-knapsack", family: .planning,
                title: "Bounded Knapsack",
                description: "Allocate limited capacity across bounded item quantities in a native table.",
                systemImage: "shippingbox.and.arrow.backward", action: .boundedKnapsack
            ),
            NewModelTemplate(
                id: "aggregate-planning", family: .planning,
                title: "Aggregate Planning",
                description: "Plan production, workforce, inventory, and backorders in native period tables.",
                systemImage: "chart.bar.xaxis", action: .aggregatePlanning
            ),
            NewModelTemplate(
                id: "material-requirements-planning", family: .planning,
                title: "Material Requirements Planning",
                description: "Edit items, time-phased schedules, inventory, and BOM relationships in native forms.",
                systemImage: "calendar.badge.clock", action: .materialRequirementsPlanning
            ),
            NewModelTemplate(
                id: "project-scheduling", family: .planning,
                title: "PERT / CPM",
                description: "Edit activities, predecessors, times, costs, and project settings in a native table.",
                systemImage: "point.3.connected.trianglepath.dotted", action: .projectScheduling
            ),
            NewModelTemplate(
                id: "guided-facility-layout", family: .planning,
                title: "Facility Layout",
                description: "Edit departments, areas, flows, and a starter placement.",
                systemImage: "square.grid.3x3", action: .facilityLayout
            ),
            NewModelTemplate(
                id: "guided-facility-location", family: .planning,
                title: "Facility Location",
                description: "Edit existing sites, coordinates, weights, and proposed facilities.",
                systemImage: "mappin.and.ellipse", action: .facilityLocation
            ),
            NewModelTemplate(
                id: "guided-line-balancing", family: .planning,
                title: "Line Balancing",
                description: "Edit tasks, precedence, cycle time, and station constraints.",
                systemImage: "rectangle.3.group", action: .lineBalancing
            ),
            NewModelTemplate(
                id: "guided-acceptance-sampling", family: .quality,
                title: "Acceptance Sampling",
                description: "Edit single or double plans, acceptance limits, AQL, RQL, risks, and costs.",
                systemImage: "chart.xyaxis.line", action: .acceptanceSampling
            ),
            NewModelTemplate(
                id: "guided-quality-control", family: .quality,
                title: "Quality Control",
                description: "Edit c, p, X-bar/R, Pareto, and probability-plot data in native tables.",
                systemImage: "chart.line.uptrend.xyaxis", action: .qualityControl
            ),
            NewModelTemplate(
                id: "simulation", family: .simulation,
                title: "Discrete-Event Simulation",
                description: "Edit components, routes, arrival distributions, and service rules in native forms.",
                systemImage: "waveform.path.ecg", action: .simulation
            )
        ]
        var templates = [linear]
        templates.append(contentsOf: inventory)
        templates.append(contentsOf: networks)
        templates.append(contentsOf: additionalNetworks)
        templates.append(contentsOf: forecasting)
        templates.append(markov)
        templates.append(contentsOf: decisions)
        templates.append(contentsOf: queues)
        templates.append(contentsOf: guided)
        return templates
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
