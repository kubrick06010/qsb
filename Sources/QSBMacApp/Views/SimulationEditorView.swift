import SwiftUI
import QSBCore

enum SimulationEditorSection: String, CaseIterable, Identifiable {
    case components = "Components"
    case routes = "Routes"
    case serviceRules = "Service Rules"
    var id: Self { self }
}

struct SimulationEditorView: View {
    private enum FieldFocus: Hashable {
        case component(UUID)
        case route(UUID)
        case service(UUID)
        case addRoute
        case addService
    }

    private enum DistributionSlot { case interarrival, batch }

    @Bindable var workspace: QSBWorkspace
    @Environment(\.undoManager) private var undoManager
    @FocusState private var focusedField: FieldFocus?
    @State private var selectedSection: SimulationEditorSection
    @State private var selectedComponentID: UUID?
    @State private var transferIssue: String?

    private var draft: SimulationDraft? { workspace.simulationDraft }
    private var selectedComponent: SimulationComponentDraft? {
        guard let draft else { return nil }
        return draft.components.first(where: { $0.id == selectedComponentID }) ?? draft.components.first
    }

    init(workspace: QSBWorkspace, initialSection: SimulationEditorSection = .components) {
        self.workspace = workspace
        _selectedSection = State(initialValue: initialSection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(
                title: workspace.modelTitle,
                subtitle: "Native component network editor · \(workspace.modelState.rawValue)"
            )
            if let draft {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 16) {
                        actionBar
                        issues(draft)
                        modelSection(draft)
                        Picker("Definition section", selection: $selectedSection) {
                            ForEach(SimulationEditorSection.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 620)
                        .accessibilityLabel("Simulation definition section")
                        switch selectedSection {
                        case .components: componentsSection(draft)
                        case .routes: routesSection(draft)
                        case .serviceRules: servicesSection(draft)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 1_260, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .navigationTitle("Simulation Definition")
        .onAppear { selectFirstComponentIfNeeded() }
        .onChange(of: draft?.components ?? []) { previous, current in
            selectedComponentID = repairedEditorRowSelection(selectedComponentID, previous: previous.map(\.id), current: current.map(\.id))
            selectFirstComponentIfNeeded()
            repairFocus(previous: previous)
        }
        .onChange(of: selectedComponentID) { _, _ in repairFocus(previous: draft?.components ?? []) }
        .onChange(of: selectedSection) { _, section in
            focusedField = nil
            selectedComponentID = preferredComponentID(for: section)
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
            .accessibilityHint("Checks component names, routes, queue settings, and service rules")
        Button("Run", systemImage: "play.circle") { workspace.startCurrentModelRun() }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(workspace.modelState == .invalid || workspace.runState == .solving)
            .accessibilityHint("Runs the simulation with the selected replication count")
    }

    private var familyLabel: some View {
        Text(workspace.currentModelFamily.displayName).font(.callout).foregroundStyle(.secondary)
    }

    private func modelSection(_ draft: SimulationDraft) -> some View {
        GroupBox("Model") {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 16) { modelFields(draft) }
                VStack(alignment: .leading, spacing: 10) { modelFields(draft) }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private func modelFields(_ draft: SimulationDraft) -> some View {
        labeledField("Title", text: modelBinding(\.title, action: "Edit Simulation Title"), width: 320, id: "simulation-title")
        labeledField("Time unit", text: modelBinding(\.timeUnit, action: "Edit Time Unit"), width: 130, id: "simulation-time-unit")
        VStack(alignment: .leading, spacing: 4) {
            Text("Representation").font(.caption).foregroundStyle(.secondary)
            Picker("Representation", selection: Binding(
                get: { draft.representation },
                set: { value in update("Change Representation") { $0.representation = value } }
            )) {
                Text("Matrix").tag(SimulationRepresentation.matrix)
                Text("Graphic").tag(SimulationRepresentation.graphic)
            }
            .labelsHidden().pickerStyle(.segmented).frame(width: 190)
            .accessibilityLabel("Simulation representation")
        }
        Text("\(draft.components.count) components")
            .font(.callout).foregroundStyle(.secondary)
            .accessibilityLabel("\(draft.components.count) simulation components")
    }

    private func componentsSection(_ draft: SimulationDraft) -> some View {
        GroupBox("Components") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Select one source, queue, server, or gate to edit. Copy Table exports the complete component master.")
                    .font(.caption).foregroundStyle(.secondary)
                componentSelectionBar(draft)
                if let component = selectedComponent {
                    identitySection(component)
                    commonRulesSection(component)
                    kindSpecificSection(component)
                }
                HStack(alignment: .top, spacing: 10) {
                    Button("Add Component", systemImage: "plus") {
                        var id: UUID?
                        update("Add Component") { id = $0.addComponent() }
                        selectedComponentID = id
                        if let id { focusedField = .component(id) }
                    }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .accessibilityHint("Adds a component and moves keyboard focus to its name")
                    SpreadsheetTransferActions(subject: "simulation components", issue: transferIssue, paste: pasteComponents, copy: copyComponents)
                }
            }
            .padding(8)
        }
    }

    private func componentSelectionBar(_ draft: SimulationDraft) -> some View {
        HStack(spacing: 10) {
            Picker("Component", selection: Binding(
                get: { selectedComponent?.id }, set: { selectedComponentID = $0 }
            )) {
                ForEach(draft.components) { component in
                    Text(component.name.isEmpty ? "Untitled component" : component.name).tag(Optional(component.id))
                }
            }
            .frame(maxWidth: 330).accessibilityLabel("Simulation component to edit")
            if let component = selectedComponent {
                Button("Remove Component", systemImage: "minus.circle") {
                    update("Remove Component") { $0.removeComponent(id: component.id) }
                    selectedComponentID = workspace.simulationDraft?.components.first?.id
                }
                .disabled(draft.components.count <= 1)
                .accessibilityLabel("Remove component \(component.name)")
            }
        }
    }

    private func identitySection(_ component: SimulationComponentDraft) -> some View {
        GroupBox("Identity") {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 14) { identityFields(component) }
                VStack(alignment: .leading, spacing: 10) { identityFields(component) }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private func identityFields(_ component: SimulationComponentDraft) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Name").font(.caption).foregroundStyle(.secondary)
            TextField("Component name", text: Binding(
                get: { currentComponent(component.id)?.name ?? "" },
                set: { value in update("Rename Component") { $0.renameComponent(id: component.id, to: value) } }
            ))
            .textFieldStyle(.roundedBorder).frame(width: 240)
            .focused($focusedField, equals: .component(component.id))
            .accessibilityLabel("Component name")
            .accessibilityIdentifier("simulation-component-name-\(component.id.uuidString)")
        }
        VStack(alignment: .leading, spacing: 4) {
            Text("Kind").font(.caption).foregroundStyle(.secondary)
            Picker("Component kind", selection: Binding(
                get: { currentComponent(component.id)?.kind ?? .queue },
                set: { value in update("Change Component Kind") { $0.changeKind(id: component.id, to: value) } }
            )) {
                Text("Customer / Source").tag(SimulationComponentKind.customer)
                Text("Queue").tag(SimulationComponentKind.queue)
                Text("Server").tag(SimulationComponentKind.server)
                Text("Gate").tag(SimulationComponentKind.gate)
            }
            .labelsHidden().frame(width: 210)
            .accessibilityLabel("Kind of \(component.name)")
        }
    }

    private func commonRulesSection(_ component: SimulationComponentDraft) -> some View {
        GroupBox("Rules and attributes") {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 12) { commonRuleFields(component) }
                VStack(alignment: .leading, spacing: 10) { commonRuleFields(component) }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private func commonRuleFields(_ component: SimulationComponentDraft) -> some View {
        componentField("Input rule", component: component, keyPath: \.inputRule, width: 190)
        componentField("Output rule", component: component, keyPath: \.outputRule, width: 190)
        componentField("Attribute value", component: component, keyPath: \.attributeValue, width: 130)
    }

    @ViewBuilder
    private func kindSpecificSection(_ component: SimulationComponentDraft) -> some View {
        switch component.kind {
        case .customer:
            GroupBox("Arrivals") {
                VStack(alignment: .leading, spacing: 12) {
                    if component.interarrivalTime != nil { distributionEditor("Interarrival time", component: component, slot: .interarrival) }
                    if component.batchSize != nil { distributionEditor("Batch size", component: component, slot: .batch) }
                }
                .padding(8)
            }
        case .queue:
            GroupBox("Queue policy") {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom, spacing: 12) { queueFields(component) }
                    VStack(alignment: .leading, spacing: 10) { queueFields(component) }
                }
                .padding(8)
            }
        case .server:
            Text("Define entity-specific durations in Service Rules and incoming paths in Routes.")
                .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)
        case .gate:
            Text("Use Routes to define gate destinations and branching probabilities.")
                .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)
        }
    }

    @ViewBuilder
    private func queueFields(_ component: SimulationComponentDraft) -> some View {
        componentField("Discipline", component: component, keyPath: \.queueDiscipline, width: 160)
        componentField("Capacity", component: component, keyPath: \.queueCapacity, width: 120)
    }

    private func distributionEditor(
        _ label: String, component: SimulationComponentDraft, slot: DistributionSlot
    ) -> some View {
        let distribution = distribution(for: component, slot: slot)
        return VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption.weight(.semibold))
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 10) { distributionFields(label, component: component, slot: slot, distribution: distribution) }
                VStack(alignment: .leading, spacing: 8) { distributionFields(label, component: component, slot: slot, distribution: distribution) }
            }
        }
    }

    @ViewBuilder
    private func distributionFields(
        _ label: String, component: SimulationComponentDraft, slot: DistributionSlot,
        distribution: SimulationDistributionDraft?
    ) -> some View {
        if let distribution {
            VStack(alignment: .leading, spacing: 4) {
                Text("Distribution").font(.caption).foregroundStyle(.secondary)
                Picker("\(label) distribution", selection: Binding(
                    get: { self.distribution(for: currentComponent(component.id), slot: slot)?.kind ?? .constant },
                    set: { value in
                        updateComponent(component.id, "Change Distribution") { row in
                            switch slot {
                            case .interarrival: row.interarrivalTime?.changeKind(to: value)
                            case .batch: row.batchSize?.changeKind(to: value)
                            }
                        }
                    }
                )) {
                    ForEach(distributionKinds, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                .labelsHidden().frame(width: 170)
                .accessibilityLabel("\(label) distribution")
            }
            ForEach(distribution.parameters.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 4) {
                    Text(distribution.parameterLabels[safe: index] ?? "Parameter \(index + 1)")
                        .font(.caption).foregroundStyle(.secondary)
                    TextField("", text: Binding(
                        get: { self.distribution(for: currentComponent(component.id), slot: slot)?.parameters[safe: index] ?? "" },
                        set: { value in
                            updateComponent(component.id, "Edit Distribution") { row in
                                switch slot {
                                case .interarrival:
                                    guard row.interarrivalTime?.parameters.indices.contains(index) == true else { return }
                                    row.interarrivalTime?.parameters[index] = value
                                case .batch:
                                    guard row.batchSize?.parameters.indices.contains(index) == true else { return }
                                    row.batchSize?.parameters[index] = value
                                }
                            }
                        }
                    ))
                    .textFieldStyle(.roundedBorder).frame(width: 130)
                    .accessibilityLabel("\(label) \(distribution.parameterLabels[safe: index] ?? "parameter \(index + 1)")")
                }
            }
        }
    }

    private func routesSection(_ draft: SimulationDraft) -> some View {
        GroupBox("Routes") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Routes belong to the selected source component. Probabilities and transfer times remain explicit.")
                    .font(.caption).foregroundStyle(.secondary)
                componentSelectionBar(draft)
                if let component = selectedComponent {
                    ScrollView(.horizontal) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                header("Target", width: 200); header("Probability", width: 120)
                                header("Transfer time", width: 130); Color.clear.frame(width: 28, height: 1)
                            }
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            ForEach(component.routes) { route in routeRow(route, component: component) }
                        }
                        .padding(.bottom, 4)
                    }
                    HStack(alignment: .top, spacing: 10) {
                        Button("Add Route", systemImage: "plus") {
                            var id: UUID?
                            update("Add Route") { id = $0.addRoute(to: component.id) }
                            if let id { focusedField = .route(id) }
                        }
                        .keyboardShortcut("n", modifiers: [.command, .shift])
                        .focused($focusedField, equals: .addRoute)
                        .accessibilityHint("Adds a route and moves focus to its target")
                        SpreadsheetTransferActions(subject: "all simulation routes", issue: transferIssue, paste: pasteRoutes, copy: copyRoutes)
                    }
                }
            }
            .padding(8)
        }
    }

    private func routeRow(_ route: SimulationRouteDraft, component: SimulationComponentDraft) -> some View {
        HStack(spacing: 8) {
            routeField("Route target from \(component.name)", route: route, component: component, keyPath: \.target, width: 200, focus: true)
            routeField("Route probability from \(component.name) to \(route.target)", route: route, component: component, keyPath: \.probability, width: 120)
            routeField("Transfer time from \(component.name) to \(route.target)", route: route, component: component, keyPath: \.transferTime, width: 130)
            Button {
                update("Remove Route") { $0.removeRoute(route.id, from: component.id) }
                let rows = draft?.components.first { $0.id == component.id }?.routes.map(\.id) ?? []
                focusedField = repairedEditorRowSelection(route.id, previous: component.routes.map(\.id), current: rows).map { .route($0) } ?? .addRoute
            } label: { Image(systemName: "minus.circle") }
            .buttonStyle(.borderless).accessibilityLabel("Remove route to \(route.target)")
        }
    }

    private func servicesSection(_ draft: SimulationDraft) -> some View {
        GroupBox("Service rules") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Each rule maps an entity type to a service-time distribution for the selected component.")
                    .font(.caption).foregroundStyle(.secondary)
                componentSelectionBar(draft)
                if let component = selectedComponent {
                    ForEach(component.serviceRules) { rule in serviceRule(rule, component: component) }
                    HStack(alignment: .top, spacing: 10) {
                        Button("Add Service Rule", systemImage: "plus") {
                            var id: UUID?
                            update("Add Service Rule") { id = $0.addServiceRule(to: component.id) }
                            if let id { focusedField = .service(id) }
                        }
                        .keyboardShortcut("n", modifiers: [.command, .shift])
                        .focused($focusedField, equals: .addService)
                        .accessibilityHint("Adds a service rule and moves focus to its entity type")
                        SpreadsheetTransferActions(subject: "all service rules", issue: transferIssue, paste: pasteServices, copy: copyServices)
                    }
                }
            }
            .padding(8)
        }
    }

    private func serviceRule(_ rule: SimulationServiceRuleDraft, component: SimulationComponentDraft) -> some View {
        GroupBox(rule.entityType.isEmpty ? "New rule" : rule.entityType) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .bottom, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Entity type").font(.caption).foregroundStyle(.secondary)
                        TextField("Entity type", text: Binding(
                            get: { currentServiceRule(rule.id, componentID: component.id)?.entityType ?? "" },
                            set: { value in updateServiceRule(rule.id, componentID: component.id, "Edit Service Rule") { $0.entityType = value } }
                        ))
                        .textFieldStyle(.roundedBorder).frame(width: 190)
                        .focused($focusedField, equals: .service(rule.id))
                        .accessibilityLabel("Entity type served by \(component.name)")
                    }
                    Button("Remove", systemImage: "minus.circle") {
                        update("Remove Service Rule") { $0.removeServiceRule(rule.id, from: component.id) }
                        let rows = draft?.components.first { $0.id == component.id }?.serviceRules.map(\.id) ?? []
                        focusedField = repairedEditorRowSelection(rule.id, previous: component.serviceRules.map(\.id), current: rows).map { .service($0) } ?? .addService
                    }
                    .accessibilityLabel("Remove service rule for \(rule.entityType)")
                }
                serviceDistributionFields(rule, component: component)
            }
            .padding(8)
        }
    }

    private func serviceDistributionFields(_ rule: SimulationServiceRuleDraft, component: SimulationComponentDraft) -> some View {
        let distribution = rule.distribution
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 10) { serviceDistributionControls(rule, component: component, distribution: distribution) }
            VStack(alignment: .leading, spacing: 8) { serviceDistributionControls(rule, component: component, distribution: distribution) }
        }
    }

    @ViewBuilder
    private func serviceDistributionControls(
        _ rule: SimulationServiceRuleDraft, component: SimulationComponentDraft,
        distribution: SimulationDistributionDraft
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Distribution").font(.caption).foregroundStyle(.secondary)
            Picker("Service distribution", selection: Binding(
                get: { currentServiceRule(rule.id, componentID: component.id)?.distribution.kind ?? .constant },
                set: { value in updateServiceRule(rule.id, componentID: component.id, "Change Service Distribution") { $0.distribution.changeKind(to: value) } }
            )) {
                ForEach(distributionKinds, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            .labelsHidden().frame(width: 170).accessibilityLabel("Service distribution for \(rule.entityType)")
        }
        ForEach(distribution.parameters.indices, id: \.self) { index in
            VStack(alignment: .leading, spacing: 4) {
                Text(distribution.parameterLabels[safe: index] ?? "Parameter \(index + 1)")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("", text: Binding(
                    get: { currentServiceRule(rule.id, componentID: component.id)?.distribution.parameters[safe: index] ?? "" },
                    set: { value in
                        updateServiceRule(rule.id, componentID: component.id, "Edit Service Distribution") { draft in
                            guard draft.distribution.parameters.indices.contains(index) else { return }
                            draft.distribution.parameters[index] = value
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder).frame(width: 130)
                .accessibilityLabel("Service \(distribution.parameterLabels[safe: index] ?? "parameter \(index + 1)") for \(rule.entityType)")
            }
        }
    }

    @ViewBuilder
    private func issues(_ draft: SimulationDraft) -> some View {
        let diagnostics = draft.draftDiagnostics().filter { $0.severity != .info }
        if !diagnostics.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                    Label(diagnostic.message, systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(diagnostic.severity == .error ? .red : .orange)
                }
            }
            .accessibilityElement(children: .contain).accessibilityLabel("Simulation input issues")
        }
    }

    private var distributionKinds: [SimulationDistributionKind] { [.constant, .exponential, .normal, .uniform, .triangular] }

    private func componentField(
        _ label: String, component: SimulationComponentDraft,
        keyPath: WritableKeyPath<SimulationComponentDraft, String>, width: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: Binding(
                get: { currentComponent(component.id)?[keyPath: keyPath] ?? "" },
                set: { value in updateComponent(component.id, "Edit Component") { $0[keyPath: keyPath] = value } }
            ))
            .textFieldStyle(.roundedBorder).frame(width: width).accessibilityLabel("\(label) for \(component.name)")
        }
    }

    private func routeField(
        _ label: String, route: SimulationRouteDraft, component: SimulationComponentDraft,
        keyPath: WritableKeyPath<SimulationRouteDraft, String>, width: CGFloat, focus: Bool = false
    ) -> some View {
        let field = TextField("", text: Binding(
            get: { currentRoute(route.id, componentID: component.id)?[keyPath: keyPath] ?? "" },
            set: { value in updateRoute(route.id, componentID: component.id, "Edit Route") { $0[keyPath: keyPath] = value } }
        ))
        .textFieldStyle(.roundedBorder).frame(width: width).accessibilityLabel(label)
        return Group { if focus { field.focused($focusedField, equals: .route(route.id)) } else { field } }
    }

    private func labeledField(_ label: String, text: Binding<String>, width: CGFloat, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: text).textFieldStyle(.roundedBorder).frame(width: width)
                .accessibilityLabel(label).accessibilityIdentifier(id)
        }
    }

    private func header(_ text: String, width: CGFloat) -> some View { Text(text).frame(width: width, alignment: .leading) }

    private func modelBinding(_ keyPath: WritableKeyPath<SimulationDraft, String>, action: String) -> Binding<String> {
        Binding(get: { workspace.simulationDraft?[keyPath: keyPath] ?? "" }, set: { value in update(action) { $0[keyPath: keyPath] = value } })
    }

    private func currentComponent(_ id: UUID) -> SimulationComponentDraft? {
        workspace.simulationDraft?.components.first(where: { $0.id == id })
    }

    private func currentRoute(_ id: UUID, componentID: UUID) -> SimulationRouteDraft? {
        currentComponent(componentID)?.routes.first(where: { $0.id == id })
    }

    private func currentServiceRule(_ id: UUID, componentID: UUID) -> SimulationServiceRuleDraft? {
        currentComponent(componentID)?.serviceRules.first(where: { $0.id == id })
    }

    private func distribution(for component: SimulationComponentDraft?, slot: DistributionSlot) -> SimulationDistributionDraft? {
        switch slot { case .interarrival: component?.interarrivalTime; case .batch: component?.batchSize }
    }

    private func updateComponent(_ id: UUID, _ actionName: String, _ mutation: (inout SimulationComponentDraft) -> Void) {
        update(actionName) { draft in
            guard let index = draft.components.firstIndex(where: { $0.id == id }) else { return }
            mutation(&draft.components[index])
        }
    }

    private func updateRoute(
        _ id: UUID, componentID: UUID, _ actionName: String, _ mutation: (inout SimulationRouteDraft) -> Void
    ) {
        updateComponent(componentID, actionName) { component in
            guard let index = component.routes.firstIndex(where: { $0.id == id }) else { return }
            mutation(&component.routes[index])
        }
    }

    private func updateServiceRule(
        _ id: UUID, componentID: UUID, _ actionName: String, _ mutation: (inout SimulationServiceRuleDraft) -> Void
    ) {
        updateComponent(componentID, actionName) { component in
            guard let index = component.serviceRules.firstIndex(where: { $0.id == id }) else { return }
            mutation(&component.serviceRules[index])
        }
    }

    private func update(_ actionName: String, _ mutation: (inout SimulationDraft) -> Void) {
        guard var next = workspace.simulationDraft else { return }
        mutation(&next)
        workspace.replaceSimulationDraft(next, undoManager: undoManager, actionName: actionName)
    }

    private func repairFocus(previous: [SimulationComponentDraft]) {
        guard let draft else { focusedField = nil; return }
        switch focusedField {
        case let .component(id):
            focusedField = repairedEditorRowSelection(id, previous: previous.map(\.id), current: draft.components.map(\.id)).map { .component($0) }
        case let .route(id):
            let oldRows = previous.first { $0.routes.contains { $0.id == id } }?.routes.map(\.id) ?? []
            let rows = selectedComponent?.routes.map(\.id) ?? []
            focusedField = repairedEditorRowSelection(id, previous: oldRows, current: rows).map { .route($0) } ?? .addRoute
        case let .service(id):
            let oldRows = previous.first { $0.serviceRules.contains { $0.id == id } }?.serviceRules.map(\.id) ?? []
            let rows = selectedComponent?.serviceRules.map(\.id) ?? []
            focusedField = repairedEditorRowSelection(id, previous: oldRows, current: rows).map { .service($0) } ?? .addService
        default: break
        }
    }
    private func selectFirstComponentIfNeeded() {
        guard let draft else { selectedComponentID = nil; return }
        if selectedComponentID == nil || !draft.components.contains(where: { $0.id == selectedComponentID }) {
            selectedComponentID = preferredComponentID(for: selectedSection)
        }
    }

    private func preferredComponentID(for section: SimulationEditorSection) -> UUID? {
        guard let draft else { return nil }
        switch section {
        case .components:
            return draft.components.first?.id
        case .routes:
            return draft.components.first(where: { !$0.routes.isEmpty })?.id ?? draft.components.first?.id
        case .serviceRules:
            return draft.components.first(where: { !$0.serviceRules.isEmpty })?.id
                ?? draft.components.first(where: { $0.kind == .server })?.id
                ?? draft.components.first?.id
        }
    }

    private func pasteComponents() {
        do {
            var next = try requireDraft()
            let previousIDs = next.components.map(\.id)
            try next.replaceComponents(withTabularText: SpreadsheetClipboard.read())
            workspace.replaceSimulationDraft(next, undoManager: undoManager, actionName: "Paste Components")
            selectedComponentID = repairedEditorRowSelection(selectedComponentID,
                previous: previousIDs, current: next.components.map(\.id)) ?? next.components.first?.id
            transferIssue = nil
        } catch { transferIssue = String(describing: error) }
    }
    private func copyComponents() { guard let draft else { return }; SpreadsheetClipboard.write(draft.componentTabularText()); transferIssue = nil }

    private func pasteRoutes() {
        do {
            var next = try requireDraft(); try next.replaceRoutes(withTabularText: SpreadsheetClipboard.read())
            workspace.replaceSimulationDraft(next, undoManager: undoManager, actionName: "Paste Routes"); transferIssue = nil
        } catch { transferIssue = String(describing: error) }
    }
    private func copyRoutes() { guard let draft else { return }; SpreadsheetClipboard.write(draft.routeTabularText()); transferIssue = nil }

    private func pasteServices() {
        do {
            var next = try requireDraft(); try next.replaceServiceRules(withTabularText: SpreadsheetClipboard.read())
            workspace.replaceSimulationDraft(next, undoManager: undoManager, actionName: "Paste Service Rules"); transferIssue = nil
        } catch { transferIssue = String(describing: error) }
    }
    private func copyServices() { guard let draft else { return }; SpreadsheetClipboard.write(draft.serviceTabularText()); transferIssue = nil }

    private func requireDraft() throws -> SimulationDraft {
        guard let draft else { throw SpreadsheetTransferError.emptyClipboard }
        return draft
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}
