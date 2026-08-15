import SwiftUI
import QSBCore
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var workspace: QSBWorkspace
    @State private var isShowingInspector = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $workspace.selectedPane, workspace: workspace)
        } detail: {
            switch workspace.selectedPane ?? .model {
            case .overview:
                if workspace.hasModel {
                    ModelOverviewView(workspace: workspace)
                } else {
                    EmptyWorkspaceView(workspace: workspace)
                }
            case .model:
                ModelEditorView(workspace: workspace)
            case .validation:
                ValidationView(workspace: workspace)
            case .run:
                RunConfigurationView(workspace: workspace)
            case .solution:
                SolutionView(workspace: workspace)
            case .json:
                JSONRepresentationView(workspace: workspace, solution: workspace.hasSolution)
            case .runDetails:
                RunDetailsView(workspace: workspace)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    Button("LP Sample") {
                        workspace.loadSample(.linearProgram)
                    }
                    Button("ILP Sample") {
                        workspace.loadSample(.integerProgram)
                    }
                    Divider()
                    Button("TSP Network Sample") {
                        workspace.loadSample(.travelingSalesperson)
                    }
                    Button("Facility Layout Sample") {
                        workspace.loadSample(.facilityLayout)
                    }
                    Divider()
                    Button("EOQ Inventory Sample") {
                        workspace.loadSample(.economicOrderQuantity)
                    }
                    Button("Bounded Knapsack Sample") {
                        workspace.loadSample(.boundedKnapsack)
                    }
                    Button("Linear Trend Forecast Sample") {
                        workspace.loadSample(.linearTrendForecast)
                    }
                    Divider()
                    Button("Payoff Analysis Sample") {
                        workspace.loadSample(.payoffAnalysis)
                    }
                    Button("Decision Tree Sample") {
                        workspace.loadSample(.decisionTree)
                    }
                    Button("Simulation Sample") {
                        workspace.loadSample(.simulation)
                    }
                    Divider()
                    Button("Quadratic Programming Sample") {
                        workspace.loadSample(.quadraticProgramming)
                    }
                    Button("Nonlinear Programming Sample") {
                        workspace.loadSample(.nonlinearProgramming)
                    }
                    Button("Markov Analysis Sample") {
                        workspace.loadSample(.markov)
                    }
                    Button("Goal Programming Sample") {
                        workspace.loadSample(.goalProgramming)
                    }
                } label: {
                    Label("Samples", systemImage: "tray.and.arrow.down")
                }

                Button {
                    workspace.isImportingModel = true
                } label: {
                    Label("Open", systemImage: "folder")
                }

                Button {
                    workspace.startNewLinearProgram()
                } label: {
                    Label("New", systemImage: "plus")
                }

                Button {
                    workspace.validateCurrentModel()
                } label: {
                    Label("Validate", systemImage: "checkmark.seal")
                }
                .disabled(!workspace.hasModel || workspace.modelState == .validating)

                Button {
                    workspace.runCurrentModel()
                } label: {
                    Label("Solve", systemImage: "play.circle")
                }
                .help("Solve the current model with the selected backend")
                .disabled(!workspace.canSolveCurrentModel || workspace.runState == .solving)

                Button {
                    workspace.isExportingModel = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(!workspace.hasModel)

                Button {
                    isShowingInspector.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
                }
                .help("Show or hide the inspector")
            }
        }
        .inspector(isPresented: $isShowingInspector) {
            WorkbenchInspectorView(workspace: workspace)
                .inspectorColumnWidth(min: 220, ideal: 280, max: 360)
        }
        .fileImporter(
            isPresented: $workspace.isImportingModel,
            allowedContentTypes: [.json, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                workspace.importModel(from: url)
            case .failure(let error):
                workspace.status = "Import failed: \(error)"
            }
        }
        .fileExporter(
            isPresented: $workspace.isExportingModel,
            document: workspace.modelDocument,
            contentType: .json,
            defaultFilename: "qsb-model"
        ) { result in
            workspace.recordExportResult(result, label: "model")
        }
        .fileExporter(
            isPresented: $workspace.isExportingSolution,
            document: workspace.solutionDocument,
            contentType: .json,
            defaultFilename: "qsb-solution"
        ) { result in
            workspace.recordExportResult(result, label: "solution")
        }
        .safeAreaInset(edge: .bottom) {
            StatusBar(workspace: workspace)
        }
    }
}
