import SwiftUI

struct ModelEditorView: View {
    @Bindable var workspace: QSBWorkspace

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(
                title: "Model",
                subtitle: workspace.currentModelFamily.editorSubtitle
            )

            TextEditor(text: $workspace.modelJSON)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(12)
        }
        .navigationTitle("Model")
    }
}
