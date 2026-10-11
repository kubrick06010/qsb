import SwiftUI
import QSBCore

struct QueuingEditorView: View {
    @Bindable var workspace: QSBWorkspace
    @State private var pendingKind: QueuingProblemKind?

    private var draft: QueuingDraft? { workspace.queuingDraft }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(
                title: workspace.modelTitle,
                subtitle: "Native queue editor · \(workspace.modelState.rawValue)"
            )
            if let draft {
                actionBar
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                Divider()
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 16) {
                        draftIssues(draft)
                        modelIdentity
                        switch draft {
                        case .mm1:
                            mm1Definition
                        case .finiteCapacity:
                            finiteCapacityDefinition
                        }
                        interpretation
                    }
                    .padding(20)
                    .frame(maxWidth: 960, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            } else {
                ContentUnavailableView(
                    "No queue draft",
                    systemImage: "person.2.wave.2",
                    description: Text("Create a queue model, load the sample, or open a normalized request.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Queue Definition")
        .confirmationDialog(
            "Switch queue variant?",
            isPresented: Binding(
                get: { pendingKind != nil },
                set: { if !$0 { pendingKind = nil } }
            )
        ) {
            Button("Switch Variant", role: .destructive) {
                if let pendingKind { workspace.updateQueuingDraft { $0.setKind(pendingKind) } }
                pendingKind = nil
            }
            Button("Cancel", role: .cancel) { pendingKind = nil }
        } message: {
            Text("Switching variants starts a new queue definition and discards the current field values.")
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button("Validate", systemImage: "checkmark.seal") {
                workspace.validateCurrentModel()
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
            .accessibilityLabel("Validate queue model")
            .accessibilityIdentifier("queuing-validate")
            Button("Run", systemImage: "play.circle") {
                workspace.startCurrentModelRun()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(workspace.modelState == .invalid || workspace.runState == .solving)
            .accessibilityLabel("Run queue model")
            .accessibilityIdentifier("queuing-run")
            Spacer()
            Text(workspace.currentModelFamily.displayName)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var modelIdentity: some View {
        GroupBox("Model") {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: fieldColumns, alignment: .leading, spacing: 12) {
                    field("Title", value: titleBinding, id: "queuing-title")
                    field("Time unit", value: timeUnitBinding, id: "queuing-time-unit")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Variant").font(.caption).foregroundStyle(.secondary)
                        Picker("Variant", selection: kindBinding) {
                            Text(QueuingProblemKind.mm1.displayName).tag(QueuingProblemKind.mm1)
                            Text(QueuingProblemKind.finiteCapacity.displayName).tag(QueuingProblemKind.finiteCapacity)
                        }
                        .labelsHidden()
                        .accessibilityLabel("Queue variant")
                        .accessibilityIdentifier("queuing-variant")
                    }
                }
                Text("Choose a queue type, then enter its parameters and optional costs. Incomplete values remain visible until validation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
        }
    }

    private var mm1Definition: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("M/M/1 parameters") {
                VStack(alignment: .leading, spacing: 10) {
                    LazyVGrid(columns: fieldColumns, alignment: .leading, spacing: 12) {
                        field("Service rate (per time unit)", value: mm1Binding(\.serviceRate), id: "queuing-mm1-service-rate")
                        field("Arrival rate (per time unit)", value: mm1Binding(\.arrivalRate), id: "queuing-mm1-arrival-rate")
                    }
                    Text("The native closed-form solver requires arrival rate < service rate for a steady state.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }
            costFields(
                title: "Optional cost rates",
                values: [
                    ("Busy server", mm1Binding(\.busyServerCostPerTime), "queuing-mm1-busy-cost"),
                    ("Idle server", mm1Binding(\.idleServerCostPerTime), "queuing-mm1-idle-cost"),
                    ("Waiting customer", mm1Binding(\.customerWaitingCostPerTime), "queuing-mm1-waiting-cost"),
                    ("Customer in service", mm1Binding(\.customerBeingServedCostPerTime), "queuing-mm1-service-cost")
                ]
            )
        }
    }

    private var finiteCapacityDefinition: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Finite-capacity parameters") {
                VStack(alignment: .leading, spacing: 10) {
                    LazyVGrid(columns: fieldColumns, alignment: .leading, spacing: 12) {
                        field("Servers", value: finiteBinding(\.servers), id: "queuing-finite-servers")
                        field("Queue capacity", value: finiteBinding(\.queueCapacity), id: "queuing-finite-capacity")
                        field("Batch size", value: finiteBinding(\.batchSize), id: "queuing-finite-batch-size")
                        field("Mean service time", value: finiteBinding(\.meanServiceTime), id: "queuing-finite-service-time")
                        field("Service SD (optional)", value: finiteBinding(\.serviceTimeStandardDeviation), id: "queuing-finite-service-sd")
                        field("Mean interarrival time", value: finiteBinding(\.meanInterarrivalTime), id: "queuing-finite-interarrival-time")
                        field("Service distribution", value: finiteBinding(\.serviceDistribution), id: "queuing-finite-service-distribution")
                        field("Interarrival distribution", value: finiteBinding(\.interarrivalDistribution), id: "queuing-finite-interarrival-distribution")
                    }
                    Text("The native approximation requires unit batches and exponential interarrivals; non-exponential service is retained with an explicit validation warning.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
            }
            costFields(
                title: "Optional cost rates",
                values: [
                    ("Busy server", finiteBinding(\.busyServerCostPerTime), "queuing-finite-busy-cost"),
                    ("Idle server", finiteBinding(\.idleServerCostPerTime), "queuing-finite-idle-cost"),
                    ("Waiting customer", finiteBinding(\.customerWaitingCostPerTime), "queuing-finite-waiting-cost"),
                    ("Customer in service", finiteBinding(\.customerBeingServedCostPerTime), "queuing-finite-service-cost"),
                    ("Balked customer", finiteBinding(\.balkedCustomerCost), "queuing-finite-balked-cost"),
                    ("Queue capacity slot", finiteBinding(\.queueCapacityCostPerSlot), "queuing-finite-capacity-cost")
                ]
            )
        }
    }

    private func costFields(
        title: String,
        values: [(String, Binding<String>, String)]
    ) -> some View {
        GroupBox(title) {
            LazyVGrid(
                columns: fieldColumns,
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(values, id: \.2) { item in
                    field(item.0, value: item.1, id: item.2)
                }
            }
            .padding(8)
        }
    }

    private var interpretation: some View {
        GroupBox("Next steps") {
            Text("Validate or run the queue, then inspect the results or export normalized JSON.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(8)
        }
    }

    @ViewBuilder
    private func draftIssues(_ draft: QueuingDraft) -> some View {
        let issues = draft.draftDiagnostics().filter { $0.severity == .error }
        if !issues.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                    Label(issue.message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    private var fieldColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 240), spacing: 12, alignment: .leading)]
    }

    private func field(_ label: String, value: Binding<String>, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(label, text: value)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(label)
                .accessibilityIdentifier(id)
        }
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: {
                switch workspace.queuingDraft {
                case .mm1(let draft): draft.title
                case .finiteCapacity(let draft): draft.title
                case nil: ""
                }
            },
            set: { value in
                workspace.updateQueuingDraft { draft in
                    switch draft {
                    case .mm1: draft.updateMM1 { $0.title = value }
                    case .finiteCapacity: draft.updateFiniteCapacity { $0.title = value }
                    }
                }
            }
        )
    }

    private var timeUnitBinding: Binding<String> {
        Binding(
            get: {
                switch workspace.queuingDraft {
                case .mm1(let draft): draft.timeUnit
                case .finiteCapacity(let draft): draft.timeUnit
                case nil: ""
                }
            },
            set: { value in
                workspace.updateQueuingDraft { draft in
                    switch draft {
                    case .mm1: draft.updateMM1 { $0.timeUnit = value }
                    case .finiteCapacity: draft.updateFiniteCapacity { $0.timeUnit = value }
                    }
                }
            }
        )
    }

    private var kindBinding: Binding<QueuingProblemKind> {
        Binding(
            get: { workspace.queuingDraft?.kind ?? .mm1 },
            set: { value in
                if value != workspace.queuingDraft?.kind { pendingKind = value }
            }
        )
    }

    private func mm1Binding(_ keyPath: WritableKeyPath<MM1QueueDraft, String>) -> Binding<String> {
        Binding(
            get: {
                guard case .mm1(let draft) = workspace.queuingDraft else { return "" }
                return draft[keyPath: keyPath]
            },
            set: { value in workspace.updateQueuingDraft { $0.updateMM1 { $0[keyPath: keyPath] = value } } }
        )
    }

    private func finiteBinding(_ keyPath: WritableKeyPath<FiniteCapacityQueueDraft, String>) -> Binding<String> {
        Binding(
            get: {
                guard case .finiteCapacity(let draft) = workspace.queuingDraft else { return "" }
                return draft[keyPath: keyPath]
            },
            set: { value in workspace.updateQueuingDraft { $0.updateFiniteCapacity { $0[keyPath: keyPath] = value } } }
        )
    }
}
