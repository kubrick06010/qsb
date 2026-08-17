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
                    ForEach([InventoryProblemKind.eoq, .quantityDiscountEOQ, .newsboy, .lotSizing, .stochasticReview], id: \.rawValue) { kind in
                        Button {
                            workspace.startNewInventory(kind)
                            dismiss()
                        } label: {
                            Label(kind.displayName, systemImage: "shippingbox")
                        }
                        .buttonStyle(.link)
                        .accessibilityIdentifier("new-model-inventory-\(kind.rawValue)")
                    }
                    Text("Stochastic Review now uses a native policy-aware editor; the existing solver remains the source of all calculations.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
            GroupBox("Networks · native graph editor") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Choose a graph-native model")
                        .font(.headline)
                    ForEach(NetworkDraftKind.allCases) { kind in
                        Button {
                            workspace.startNewNetwork(kind)
                            dismiss()
                        } label: {
                            Label(kind.displayName, systemImage: "point.3.connected.trianglepath.dotted")
                        }
                        .buttonStyle(.link)
                        .accessibilityIdentifier("network-kind-\(kind.rawValue)")
                    }
                    Divider()
                    Text("Matrix editors")
                        .font(.headline)
                    Button {
                        workspace.startNewAssignment()
                        dismiss()
                    } label: {
                        Label("Assignment", systemImage: "tablecells")
                    }
                    .buttonStyle(.link)
                    .accessibilityIdentifier("network-kind-assignment")
                    Button {
                        workspace.startNewTransportation()
                        dismiss()
                    } label: {
                        Label("Transportation", systemImage: "tablecells")
                    }
                    .buttonStyle(.link)
                    .accessibilityIdentifier("network-kind-transportation")
                    Button {
                        workspace.startNewNetworkFlow()
                        dismiss()
                    } label: {
                        Label("Minimum-Cost Transshipment", systemImage: "arrow.triangle.branch")
                    }
                    .buttonStyle(.link)
                    .accessibilityIdentifier("network-kind-minimum-cost-flow")
                    Text("CNF uses a balance-aware network table; capacities are not part of the current QSBCore model.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
            GroupBox("Forecasting") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Choose a supported forecasting method").font(.headline)
                    ForEach(ForecastingMethod.allCases, id: \.rawValue) { method in
                        Button {
                            workspace.startNewForecasting(method)
                            dismiss()
                        } label: {
                            Label(method.displayName, systemImage: "chart.xyaxis.line")
                        }
                        .buttonStyle(.link)
                        .accessibilityIdentifier("new-model-forecasting-\(method.rawValue)")
                    }
                    Text("The native editor covers all current QSBCore forecasting methods; validation and solving remain in QSBCore.")
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
