import SwiftUI

struct SidebarView: View {
    @Binding var selection: WorkspacePane?

    var body: some View {
        List(WorkspacePane.allCases, selection: $selection) { pane in
            Label(pane.title, systemImage: pane.systemImage)
                .tag(pane)
        }
        .listStyle(.sidebar)
        .navigationTitle("QSB")
    }
}
