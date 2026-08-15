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
                Button("New") { workspace.showNewModelPlaceholder() }
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
                            Button("Run") { workspace.solveCurrentModel() }
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
                Text("External solver integration is not configured in this build.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let error = workspace.lastErrorMessage {
                    Label(error, systemImage: "exclamationmark.octagon.fill")
                        .foregroundStyle(.red)
                }
            }
            Section {
                Button(workspace.selectedBackend == .validateOnly ? "Validate" : "Run") {
                    workspace.runCurrentModel()
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
            TextEditor(text: solution ? .constant(workspace.solutionJSON) : $workspace.modelJSON)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(12)
                .accessibilityLabel(solution ? "Solution JSON" : "Model JSON")
        }
        .navigationTitle(solution ? "Solution JSON" : "Model JSON")
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
