import SwiftUI

struct ModelEditorView: View {
    @Bindable var workspace: QSBWorkspace

    var body: some View {
        if workspace.isLinearProgrammingModel {
            LinearProgrammingEditorView(workspace: workspace)
        } else if workspace.isInventoryModel, workspace.inventoryDraft != nil {
            InventoryEditorView(workspace: workspace)
        } else if workspace.isNetworkModel, workspace.networkDraft != nil {
            NetworkEditorView(workspace: workspace)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HeaderView(
                    title: workspace.modelTitle,
                    subtitle: "Model JSON · \(workspace.modelState.rawValue)"
                )

                if workspace.hasModel {
                    TextEditor(text: $workspace.modelJSON)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .accessibilityLabel("Normalized model JSON definition")
                } else {
                    EmptyWorkspaceView(workspace: workspace)
                }
            }
            .navigationTitle("Model")
        }
    }
}
