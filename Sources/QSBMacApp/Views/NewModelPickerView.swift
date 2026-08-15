import SwiftUI
import QSBCore

struct NewModelPickerView: View {
    @Bindable var workspace: QSBWorkspace
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HeaderView(title: "New Model", subtitle: "Choose an editor currently available in QSB")
            GroupBox("Optimization") {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        workspace.startNewLinearProgram()
                        dismiss()
                    } label: {
                        Label("Linear / Integer Programming", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .buttonStyle(.link)
                    .accessibilityIdentifier("new-model-linear-programming")
                    Text("Native editor for continuous, integer, binary, and unrestricted variables.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
            GroupBox("Inventory") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Choose a model variant")
                        .font(.headline)
                    ForEach([InventoryProblemKind.eoq, .quantityDiscountEOQ, .newsboy, .lotSizing], id: \.rawValue) { kind in
                        Button {
                            workspace.startNewInventory(kind)
                            dismiss()
                        } label: {
                            Label(kind.displayName, systemImage: "shippingbox")
                        }
                        .buttonStyle(.link)
                        .accessibilityIdentifier("new-model-inventory-\(kind.rawValue)")
                    }
                    Text("Stochastic Review remains available through JSON and legacy import; its native editor is deferred.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
            GroupBox("Other families") {
                Text("Open and solve are available for existing models. Native creation editors for other families will be added in later phases.")
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(minWidth: 520, idealWidth: 600, minHeight: 420)
    }
}
