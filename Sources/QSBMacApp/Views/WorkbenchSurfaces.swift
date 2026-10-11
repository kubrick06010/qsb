import SwiftUI
import QSBCore

struct EmptyWorkspaceView: View {
    @Bindable var workspace: QSBWorkspace

    var body: some View {
        ContentUnavailableView {
            Label("Start a QSB model", systemImage: "square.stack.3d.up")
        } description: {
            Text("Open a legacy or normalized model, or choose New to browse the model families.")
        } actions: {
            HStack {
                Button("Open") { workspace.isImportingModel = true }
                    .keyboardShortcut("o", modifiers: [.command])
                Button("New") { workspace.startNewModelSelection() }
                    .keyboardShortcut("n", modifiers: [.command])
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ModelOverviewView: View {
    @Bindable var workspace: QSBWorkspace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderView(title: workspace.modelTitle, subtitle: workspace.currentModelFamily.editorSubtitle)
                HStack(spacing: 12) {
                    StateCard(title: "Model", value: workspace.modelState.rawValue, systemImage: workspace.modelState.systemImage)
                    StateCard(title: "Run", value: workspace.runState.rawValue, systemImage: workspace.runState.systemImage)
                }
                GroupBox("Source") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Origin", value: workspace.modelSource)
                        LabeledContent("Representation", value: "Normalized QSBCore JSON")
                        LabeledContent("Family", value: workspace.currentModelFamily.displayName)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
                GroupBox("Next actions") {
                    HStack {
                        Button("Edit Definition") { workspace.selectedPane = .model }
                        Button("Validate") { workspace.validateCurrentModel() }
                            .buttonStyle(.borderedProminent)
                        if workspace.canSolveCurrentModel {
                            Button("Run") { workspace.startCurrentModelRun() }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Overview")
    }
}

struct ValidationView: View {
    @Bindable var workspace: QSBWorkspace

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(title: "Validation", subtitle: workspace.validationSummary)
            if workspace.validationDiagnostics.isEmpty && workspace.validationJSON.isEmpty {
                ContentUnavailableView("No validation run", systemImage: "checkmark.seal", description: Text("Validate the current model to see structured diagnostics."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("Diagnostics") {
                        if workspace.validationDiagnostics.isEmpty {
                            Label("No diagnostics", systemImage: "checkmark.circle")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(workspace.validationDiagnostics.enumerated()), id: \.offset) { _, diagnostic in
                                DiagnosticRow(diagnostic: diagnostic)
                            }
                        }
                    }
                    Section("Structured report") {
                        TextEditor(text: .constant(workspace.validationJSON))
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 180)
                            .accessibilityLabel("Structured validation report JSON")
                    }
                }
            }
        }
        .navigationTitle("Validation")
    }
}

struct RunConfigurationView: View {
    @Bindable var workspace: QSBWorkspace

    var body: some View {
        Form {
            Section("Model") {
                LabeledContent("Model", value: workspace.modelTitle)
                LabeledContent("State", value: workspace.modelState.rawValue)
            }
            Section("Run configuration") {
                Picker("Solver", selection: $workspace.selectedBackend) {
                    Text("QSB Native").tag(SolverBackendKind.nativeEducational)
                    Text("Validate only").tag(SolverBackendKind.validateOnly)
                    Text("External solver").tag(SolverBackendKind.externalHighPerformance)
                }
                if workspace.isFacilityLayoutModel {
                    Picker("Layout strategy", selection: $workspace.selectedLayoutStrategy) {
                        Text("Initial").tag(FacilityLayoutSolvingStrategy.initial)
                        Text("Pairwise swap").tag(FacilityLayoutSolvingStrategy.pairwiseSwap)
                    }
                }
                if workspace.isSimulationModel {
                    Stepper(
                        "Replications: \(workspace.simulationReplications)",
                        value: $workspace.simulationReplications,
                        in: 1...100
                    )
                    .accessibilityLabel("Simulation replications")
                    .accessibilityValue("\(workspace.simulationReplications)")
                    Text("Multiple replications use independent deterministic seeds and report 95% confidence intervals.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if workspace.selectedBackend == .externalHighPerformance {
                    Text(workspace.externalBackendSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if let error = workspace.lastErrorMessage {
                    Label(error, systemImage: "exclamationmark.octagon.fill")
                        .foregroundStyle(.red)
                }
            }
            Section {
                Button(workspace.selectedBackend == .validateOnly ? "Validate" : "Run") {
                    workspace.startCurrentModelRun()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(workspace.modelState == .empty || workspace.runState == .solving)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .navigationTitle("Run")
    }
}

struct RunDetailsView: View {
    @Bindable var workspace: QSBWorkspace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeaderView(title: "Run Details", subtitle: workspace.solutionSubtitle)
                GroupBox("State") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Run", value: workspace.runState.rawValue)
                        LabeledContent("Backend", value: workspace.runBackendLabel)
                        LabeledContent("Model", value: workspace.modelTitle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Metadata") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(workspace.runNotes, id: \.self) { note in
                            Label(note, systemImage: "info.circle")
                        }
                        if workspace.runNotes.isEmpty {
                            Text("Run metadata is available in the solution JSON when this family provides it.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Run Details")
    }
}

struct JSONRepresentationView: View {
    @Bindable var workspace: QSBWorkspace
    let solution: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(
                title: solution ? "Solution JSON" : "Model JSON",
                subtitle: solution ? "Advanced result representation" : "Advanced model representation"
            )
            jsonApplyBar
            TextEditor(text: solution ? .constant(workspace.solutionJSON) : $workspace.modelJSON)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(12)
                .accessibilityLabel(solution ? "Solution JSON" : "Model JSON")
        }
        .navigationTitle(solution ? "Solution JSON" : "Model JSON")
    }

    @ViewBuilder
    private var jsonApplyBar: some View {
        if !solution && workspace.isForecastingModel {
            HStack {
                Text("JSON changes are applied explicitly to the native Forecasting draft.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Apply JSON to Forecasting Editor") {
                    workspace.applyForecastingJSONToNativeEditor()
                }
            }
            .padding(.horizontal, 12)
        } else if !solution && workspace.isLinearProgrammingModel {
            HStack {
                Text("JSON changes are applied explicitly to the native LP draft.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Apply JSON to LP Editor") {
                    workspace.applyModelJSONToNativeEditor()
                }
            }
            .padding(.horizontal, 12)
        } else if !solution && workspace.isInventoryModel {
            HStack {
                Text("JSON changes are applied explicitly to the native Inventory draft.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Apply JSON to Inventory Editor") {
                    workspace.applyInventoryJSONToNativeEditor()
                }
            }
            .padding(.horizontal, 12)
        } else if !solution && workspace.isNetworkModel {
            HStack {
                Text("JSON changes are applied explicitly to the native Network draft when the variant has a graph editor.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Apply JSON to Network Editor") {
                    workspace.applyNetworkJSONToNativeEditor()
                }
            }
            .padding(.horizontal, 12)
        } else if !solution && workspace.isMarkovModel {
            HStack {
                Text("JSON changes are applied explicitly to the native Markov editor.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Apply JSON to Markov Editor") {
                    workspace.applyMarkovJSONToNativeEditor()
                }
            }
            .padding(.horizontal, 12)
        } else if !solution && (workspace.decisionDraft != nil || workspace.zeroSumGameDraft != nil) {
            HStack {
                Text("JSON changes are applied explicitly to the native Decision Analysis draft.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Apply JSON to Decision Analysis Editor") {
                    workspace.applyDecisionAnalysisJSONToNativeEditor()
                }
            }
            .padding(.horizontal, 12)
        } else if !solution && workspace.queuingDraft != nil {
            HStack {
                Text("JSON changes are applied explicitly to the native Queuing draft.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Apply JSON to Queuing Editor") {
                    workspace.applyQueuingJSONToNativeEditor()
                }
            }
            .padding(.horizontal, 12)
        } else if !solution && workspace.projectSchedulingDraft != nil {
            HStack {
                Text("JSON changes are applied explicitly to the native Project Scheduling draft.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Apply JSON to Project Scheduling Editor") {
                    workspace.applyProjectSchedulingJSONToNativeEditor()
                }
            }
            .padding(.horizontal, 12)
        } else if !solution && workspace.aggregatePlanningDraft != nil {
            HStack {
                Text("JSON changes are applied explicitly to the native Aggregate Planning draft.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Apply JSON to Aggregate Planning Editor") {
                    workspace.applyAggregatePlanningJSONToNativeEditor()
                }
            }
            .padding(.horizontal, 12)
        } else if !solution && workspace.materialRequirementsPlanningDraft != nil {
            HStack {
                Text("JSON changes are applied explicitly to the native Material Requirements Planning draft.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Apply JSON to MRP Editor") {
                    workspace.applyMaterialRequirementsPlanningJSONToNativeEditor()
                }
            }
            .padding(.horizontal, 12)
        } else if !solution && workspace.simulationDraft != nil {
            HStack {
                Text("JSON changes are applied explicitly to the native Simulation draft.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Apply JSON to Simulation Editor") {
                    workspace.applySimulationJSONToNativeEditor()
                }
            }
            .padding(.horizontal, 12)
        } else if !solution && workspace.knapsackDraft != nil {
            HStack {
                Text("JSON changes are applied explicitly to the native Bounded Knapsack draft.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Apply JSON to Knapsack Editor") {
                    workspace.applyKnapsackJSONToNativeEditor()
                }
            }
            .padding(.horizontal, 12)
        } else if !solution && workspace.acceptanceSamplingDraft != nil {
            HStack {
                Text("JSON changes are applied explicitly to the native Acceptance Sampling draft.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Apply JSON to Acceptance Sampling Editor") {
                    workspace.applyAcceptanceSamplingJSONToNativeEditor()
                }
            }
            .padding(.horizontal, 12)
        } else if !solution && workspace.qualityControlDraft != nil {
            HStack {
                Text("JSON changes are applied explicitly to the native Quality Control draft.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Apply JSON to Quality Control Editor") {
                    workspace.applyQualityControlJSONToNativeEditor()
                }
            }
            .padding(.horizontal, 12)
        } else if !solution && workspace.facilityLayoutDraft != nil {
            HStack {
                Text("Apply JSON changes explicitly to the native Facility Layout draft.").font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Apply JSON to Layout Editor") { workspace.applyFacilityLayoutJSONToNativeEditor() }
            }.padding(.horizontal, 12)
        } else if !solution && workspace.lineBalancingDraft != nil {
            HStack {
                Text("Apply JSON changes explicitly to the native Line Balancing draft.").font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Apply JSON to Line Editor") { workspace.applyLineBalancingJSONToNativeEditor() }
            }.padding(.horizontal, 12)
        } else if !solution && workspace.facilityLocationDraft != nil {
            HStack {
                Text("Apply JSON changes explicitly to the native Facility Location draft.").font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Apply JSON to Location Editor") { workspace.applyFacilityLocationJSONToNativeEditor() }
            }.padding(.horizontal, 12)
        } else if !solution && workspace.goalProgrammingDraft != nil {
            HStack {
                Text("Apply JSON changes explicitly to the native Goal Programming draft.")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Apply JSON to Goal Editor") { workspace.applyGoalProgrammingJSONToNativeEditor() }
            }.padding(.horizontal, 12)
        } else if !solution && workspace.nonlinearProgrammingDraft != nil {
            HStack {
                Text("Apply JSON changes explicitly to the native Nonlinear Programming draft.")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Apply JSON to NLP Editor") { workspace.applyNonlinearProgrammingJSONToNativeEditor() }
            }.padding(.horizontal, 12)
        } else if !solution && workspace.quadraticProgrammingDraft != nil {
            HStack {
                Text("JSON changes are applied explicitly to the native Quadratic Programming draft.").font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Apply JSON to QP Editor") { workspace.applyQuadraticProgrammingJSONToNativeEditor() }
            }.padding(.horizontal, 12)
        }
    }
}

struct WorkbenchInspectorView: View {
    @Bindable var workspace: QSBWorkspace

    var body: some View {
        Form {
            Section("Properties") {
                LabeledContent("Model", value: workspace.modelTitle)
                LabeledContent("Family", value: workspace.currentModelFamily.displayName)
                LabeledContent("Source", value: workspace.modelSource)
            }
            Section("Status") {
                Label(workspace.modelState.rawValue, systemImage: workspace.modelState.systemImage)
                Label(workspace.runState.rawValue, systemImage: workspace.runState.systemImage)
            }
            Section("Diagnostics") {
                if workspace.validationDiagnostics.isEmpty {
                    Text("No diagnostics")
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(workspace.validationDiagnostics.count) diagnostic(s)")
                }
            }
            Section("Run") {
                LabeledContent("Backend", value: workspace.runBackendLabel)
                Button("Open Run Configuration") {
                    workspace.selectedPane = .run
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Inspector")
    }
}

private struct StateCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading) {
                Text(value).font(.headline)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .font(.title3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct DiagnosticRow: View {
    let diagnostic: ValidationDiagnostic

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(diagnostic.message)
                Text(diagnostic.code + (diagnostic.path.map { " · \($0)" } ?? ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: diagnostic.severity == .error ? "xmark.octagon.fill" : diagnostic.severity == .warning ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .foregroundStyle(diagnostic.severity == .error ? .red : diagnostic.severity == .warning ? .orange : .secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(diagnostic.severity.rawValue): \(diagnostic.message)")
    }
}

private extension ModelLifecycleState {
    var systemImage: String {
        switch self {
        case .empty: "tray"
        case .editing: "pencil"
        case .validating: "hourglass"
        case .invalid: "xmark.octagon"
        case .valid: "checkmark.seal"
        }
    }
}

private extension RunLifecycleState {
    var systemImage: String {
        switch self {
        case .notRun: "circle.dashed"
        case .validating: "hourglass"
        case .solving: "play.circle"
        case .solved: "checkmark.circle"
        case .failed: "exclamationmark.octagon"
        }
    }
}
