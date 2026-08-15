import SwiftUI
import QSBCore
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var workspace: QSBWorkspace
    @State private var isShowingLPEntryMock = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $workspace.selectedPane)
        } detail: {
            switch workspace.selectedPane ?? .model {
            case .model:
                ModelEditorView(workspace: workspace)
            case .solution:
                SolutionView(workspace: workspace)
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
                    Button("LP Entry Mock") {
                        isShowingLPEntryMock = true
                    }
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
                    workspace.isExportingModel = true
                } label: {
                    Label("Export Model", systemImage: "square.and.arrow.up")
                }

                Picker("Backend", selection: $workspace.selectedBackend) {
                    Text("Native").tag(SolverBackendKind.nativeEducational)
                    Text("Validate").tag(SolverBackendKind.validateOnly)
                }
                .pickerStyle(.segmented)

                if workspace.isFacilityLayoutModel {
                    Picker("Layout Strategy", selection: $workspace.selectedLayoutStrategy) {
                        Text("Initial").tag(FacilityLayoutSolvingStrategy.initial)
                        Text("Pairwise").tag(FacilityLayoutSolvingStrategy.pairwiseSwap)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }

                Button {
                    workspace.validateCurrentModel()
                } label: {
                    Label("Validate", systemImage: "checkmark.seal")
                }

                Button {
                    workspace.solve(.relaxation)
                } label: {
                    Label("Solve LP", systemImage: "play")
                }
                .disabled(!workspace.isLinearProgrammingModel)

                Button {
                    workspace.solve(.integer)
                } label: {
                    Label("Solve ILP", systemImage: "number")
                }
                .disabled(!workspace.isLinearProgrammingModel)

                Button {
                    workspace.solveCurrentModel()
                } label: {
                    Label("Solve", systemImage: "play.circle")
                }
                .help("Solve the current model with the selected backend")
                .disabled(!workspace.canSolveCurrentModel)
            }
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
            StatusBar(text: workspace.status)
        }
        .sheet(isPresented: $isShowingLPEntryMock) {
            LinearProgrammingEntryMockView()
        }
    }
}
