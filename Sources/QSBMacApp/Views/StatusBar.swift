import SwiftUI

struct StatusBar: View {
    @Bindable var workspace: QSBWorkspace

    var body: some View {
        HStack {
            if workspace.runState == .solving {
                ProgressView().controlSize(.small).accessibilityHidden(true)
            }
            Image(systemName: workspace.statusSystemImage)
                .foregroundStyle(workspace.statusColor)
                .accessibilityHidden(true)
            Text(workspace.status)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(workspace.status)
            Spacer()
            Text("Model: \(workspace.modelState.rawValue) · Run: \(workspace.runState.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.bar)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(workspace.status). Model \(workspace.modelState.rawValue). Run \(workspace.runState.rawValue)")
    }
}
