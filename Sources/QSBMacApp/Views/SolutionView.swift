import SwiftUI

struct SolutionView: View {
    @Bindable var workspace: QSBWorkspace

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
            } else {
                TextEditor(text: .constant(workspace.solutionJSON))
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(12)
            }
        }
        .navigationTitle("Solution")
    }
}
