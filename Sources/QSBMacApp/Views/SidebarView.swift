import SwiftUI

struct SidebarView: View {
    @Binding var selection: WorkspacePane?
    @Bindable var workspace: QSBWorkspace

    var body: some View {
        List(selection: $selection) {
            Section("Current Model") {
                navigationRow(.overview)
                navigationRow(.model)
                if workspace.hasModel {
                    navigationRow(.validation)
                }
            }

            if workspace.hasModel {
                Section("Run") {
                    navigationRow(.run)
                }
            }

            if workspace.hasSolution {
                Section("Current Solution") {
                    navigationRow(.solution)
                    navigationRow(.json)
                    navigationRow(.runDetails)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("QSB")
        .safeAreaInset(edge: .bottom) {
            Button {
                workspace.startNewModelSelection()
            } label: {
                Label("New Model", systemImage: "plus")
            }
            .accessibilityIdentifier("workbench-new")
            .keyboardShortcut("n", modifiers: [.command])
            .padding(10)
        }
    }

    @ViewBuilder
    private func navigationRow(_ pane: WorkspacePane) -> some View {
        Label(pane.title, systemImage: pane.systemImage)
            .tag(pane)
    }
}
