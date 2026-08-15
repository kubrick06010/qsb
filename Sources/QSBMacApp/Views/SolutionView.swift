import SwiftUI

private enum SolutionPresentation: String, CaseIterable, Identifiable {
    case visual
    case json

    var id: String { rawValue }
}

struct SolutionView: View {
    @Bindable var workspace: QSBWorkspace
    @State private var presentation: SolutionPresentation = .visual

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(
                title: "Solution",
                subtitle: workspace.solutionSubtitle
            )

            if workspace.solutionJSON.isEmpty {
                ContentUnavailableView(
                    "No Solution",
                    systemImage: "function",
                    description: Text("Choose the matching solve action from the toolbar or Solve menu.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let networkSolution = workspace.networkSolution {
                presentationPicker(visualLabel: "Diagram", systemImage: "point.3.connected.trianglepath.dotted")

                switch presentation {
                case .visual:
                    NetworkSolutionView(document: networkSolution)
                case .json:
                    solutionEditor
                }
            } else if let schedulingSolution = workspace.schedulingSolution {
                presentationPicker(visualLabel: "Timeline", systemImage: "chart.bar.xaxis")

                switch presentation {
                case .visual:
                    SchedulingGanttView(document: schedulingSolution)
                case .json:
                    solutionEditor
                }
            } else if let forecastingSolution = workspace.forecastingSolution {
                presentationPicker(visualLabel: "Chart", systemImage: "chart.xyaxis.line")

                switch presentation {
                case .visual:
                    ForecastingSolutionView(document: forecastingSolution)
                case .json:
                    solutionEditor
                }
            } else if let inventorySolution = workspace.inventorySolution {
                presentationPicker(visualLabel: "Analysis", systemImage: "chart.bar.xaxis")

                switch presentation {
                case .visual:
                    InventorySolutionView(document: inventorySolution)
                case .json:
                    solutionEditor
                }
            } else if let dynamicProgrammingSolution = workspace.dynamicProgrammingSolution {
                presentationPicker(visualLabel: "Stages", systemImage: "tablecells")

                switch presentation {
                case .visual:
                    DynamicProgrammingSolutionView(document: dynamicProgrammingSolution)
                case .json:
                    solutionEditor
                }
            } else if let decisionAnalysisSolution = workspace.decisionAnalysisSolution,
                      case .decisionTree = decisionAnalysisSolution.solution {
                presentationPicker(visualLabel: "Tree", systemImage: "point.3.connected.trianglepath.dotted")

                switch presentation {
                case .visual:
                    DecisionTreeSolutionView(document: decisionAnalysisSolution)
                case .json:
                    solutionEditor
                }
            } else if let facilityLayout = workspace.facilityLayoutPresentation {
                presentationPicker(visualLabel: "Layout", systemImage: "square.grid.3x3")

                switch presentation {
                case .visual:
                    FacilityLayoutSolutionView(presentation: facilityLayout)
                case .json:
                    solutionEditor
                }
            } else {
                solutionEditor
            }
        }
        .navigationTitle("Solution")
        .onChange(of: workspace.solutionJSON) {
            presentation = .visual
        }
    }

    private var solutionEditor: some View {
        TextEditor(text: .constant(workspace.solutionJSON))
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(12)
    }

    private func presentationPicker(visualLabel: String, systemImage: String) -> some View {
        HStack {
            Picker("Presentation", selection: $presentation) {
                Label(visualLabel, systemImage: systemImage)
                    .tag(SolutionPresentation.visual)
                Label("JSON", systemImage: "curlybraces")
                    .tag(SolutionPresentation.json)
            }
            .pickerStyle(.segmented)
            .frame(width: 220)

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
