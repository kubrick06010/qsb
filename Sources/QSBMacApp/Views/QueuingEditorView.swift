import SwiftUI
import QSBCore

struct QueuingEditorView: View {
    @Bindable var workspace: QSBWorkspace

    private var draft: QueuingDraft? { workspace.queuingDraft }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(
                title: workspace.modelTitle,
                subtitle: "Native queue editor · (workspace.modelState.rawValue)"
            )
            if let draft {
                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 16) {
                        actionBar
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
                    .frame(minWidth: 760, alignment: .topLeading)
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
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button("Validate", systemImage: "checkmark.seal") {
                workspace.validateCurrentModel()
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
            Button("Run", systemImage: "play.circle") {
                workspace.runCurrentModel()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(workspace.modelState == .invalid || workspace.runState == .solving)
            Spacer()
            Text(workspace.currentModelFamily.displayName)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var modelIdentity: some View {
        GroupBox("Model") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    field("Title", value: titleBinding, width: 300, id: "queuing-title")
                    field("Time unit", value: timeUnitBinding, width: 130, id: "queuing-time-unit")
                    Picker("Variant", selection: kindBinding) {
                        Text(QueuingProblemKind.mm1.displayName).tag(QueuingProblemKind.mm1)
                        Text(QueuingProblemKind.finiteCapacity.displayName).tag(QueuingProblemKind.finiteCapacity)
                    }
                    .frame(width: 240)
                    .accessibilityIdentifier("queuing-variant")
                }
                Text("The editor exposes the two supported normalized queue contracts. Values remain text until validation, so malformed input is not silently discarded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
        }
    }

    private var mm1Definition: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("M/M/1 parameters") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 14) {
                        field("Service rate (per time unit)", value: mm1Binding(\.serviceRate), width: 180, id: "queuing-mm1-service-rate")
                        field("Arrival rate (per time unit)", value: mm1Binding(\.arrivalRate), width: 180, id: "queuing-mm1-arrival-rate")
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
                    HStack(spacing: 14) {
                        field("Servers", value: finiteBinding(\.servers), width: 100, id: "queuing-finite-servers")
                        field("Queue capacity", value: finiteBinding(\.queueCapacity), width: 130, id: "queuing-finite-capacity")
                        field("Batch size", value: finiteBinding(\.batchSize), width: 100, id: "queuing-finite-batch-size")
                    }
                    HStack(spacing: 14) {
                        field("Mean service time", value: finiteBinding(\.meanServiceTime), width: 150, id: "queuing-finite-service-time")
                        field("Service SD (optional)", value: finiteBinding(\.serviceTimeStandardDeviation), width: 150, id: "queuing-finite-service-sd")
                        field("Mean interarrival time", value: finiteBinding(\.meanInterarrivalTime), width: 170, id: "queuing-finite-interarrival-time")
                    }
                    HStack(spacing: 14) {
                        field("Service distribution", value: finiteBinding(\.serviceDistribution), width: 180, id: "queuing-finite-service-distribution")
                        field("Interarrival distribution", value: finiteBinding(\.interarrivalDistribution), width: 200, id: "queuing-finite-interarrival-distribution")
                    }
                    Text("The native approximation requires unit batches and exponential interarrivals; non-exponential service is retained with an explicit validation warning.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                columns: [GridItem(.adaptive(minimum: 190), alignment: .leading)],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(values, id: \.2) { item in
                    field(item.0, value: item.1, width: 150, id: item.2)
                }
            }
            .padding(8)
        }
    }

    private var interpretation: some View {
        GroupBox("Interpretation") {
            Text("Queue definitions are converted to the existing QSBCore envelope and solved through QueuingBackend. Normalized JSON remains available as an explicit audit and interchange boundary.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
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

    private func field(_ label: String, value: Binding<String>, width: CGFloat, id: String) -> some View {
        LabeledContent(label) {
            TextField(label, text: value)
                .textFieldStyle(.roundedBorder)
                .frame(width: width)
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
            set: { value in workspace.updateQueuingDraft { $0.setKind(value) } }
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
