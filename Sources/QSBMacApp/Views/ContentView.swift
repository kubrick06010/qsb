import SwiftUI
import QSBCore
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var workspace: QSBWorkspace

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
                    Button("TSP Network Sample") {
                        workspace.loadSample(.travelingSalesperson)
                    }
                    Button("Facility Layout Sample") {
                        workspace.loadSample(.facilityLayout)
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
                    workspace.solveNetwork()
                } label: {
                    Label("Solve Network", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .disabled(!workspace.isNetworkModel)

                Button {
                    workspace.solveFacilities()
                } label: {
                    Label("Solve Facilities", systemImage: "building.2")
                }
                .disabled(!workspace.isFacilitiesModel)
            }
        }
        .fileImporter(
            isPresented: $workspace.isImportingModel,
            allowedContentTypes: [.json],
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
    }
}
