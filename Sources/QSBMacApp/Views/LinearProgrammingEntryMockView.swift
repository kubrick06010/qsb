import SwiftUI

// Preview-only UI concept. Model parsing, validation, and solving remain in QSBCore.
struct LinearProgrammingEntryMockView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var problemName = "Production mix"
    @State private var objective: LPObjective = .maximize
    @State private var variableCount = 2
    @State private var constraintCount = 3
    @State private var variableNames = ["x1", "x2"]
    @State private var objectiveCoefficients = [40.0, 30.0]
    @State private var constraintCoefficients = [
        [2.0, 1.0],
        [1.0, 2.0],
        [1.0, 1.0]
    ]
    @State private var constraintSigns = ["≤", "≤", "≤"]
    @State private var constraintRHS = [40.0, 50.0, 30.0]
    @State private var status = "Draft model · 2 variables · 3 constraints"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("New Linear Program")
                        .font(.title2.weight(.semibold))
                    Text("Native data-entry concept")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create Model") {
                    status = "Draft ready for validation"
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
            .background(.regularMaterial)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    modelDetails
                    variableTable
                    constraintsTable
                    assumptions
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
            HStack {
                Image(systemName: "circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption2)
                Text(status)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Preview only")
                    .foregroundStyle(.tertiary)
            }
            .font(.callout)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .frame(minWidth: 900, minHeight: 640)
    }

    private var modelDetails: some View {
        GroupBox("Model details") {
            HStack(alignment: .bottom, spacing: 16) {
                LabeledContent("Name") {
                    TextField("Model name", text: $problemName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                }
                Picker("Objective", selection: $objective) {
                    ForEach(LPObjective.allCases) { value in
                        Text(value.label).tag(value)
                    }
                }
                .pickerStyle(.menu)
                Spacer()
                Stepper("Variables: \(variableCount)", value: $variableCount, in: 1...6)
                    .onChange(of: variableCount) { _, newValue in
                        resizeVariables(to: newValue)
                    }
                Stepper("Constraints: \(constraintCount)", value: $constraintCount, in: 1...8)
                    .onChange(of: constraintCount) { _, newValue in
                        resizeConstraints(to: newValue)
                    }
            }
            .padding(.vertical, 4)
        }
    }

    private var variableTable: some View {
        GroupBox("Decision variables and objective") {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    Text("Variable").gridColumnAlignment(.leading)
                    Text("Objective coefficient")
                    Text("Lower bound")
                    Text("Upper bound")
                    Text("Type")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                ForEach(variableNames.indices, id: \.self) { index in
                    GridRow {
                        TextField("x", text: binding(for: $variableNames, at: index))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 110)
                        numberField(value: binding(for: $objectiveCoefficients, at: index))
                        numberField(value: .constant(0))
                        Text("∞")
                            .frame(width: 75, alignment: .leading)
                        Text("Continuous")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var constraintsTable: some View {
        GroupBox("Constraints") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Constraint")
                    ForEach(variableNames, id: \.self) { name in
                        Text(name)
                    }
                    Text("Relation")
                    Text("RHS")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                ForEach(constraintCoefficients.indices, id: \.self) { row in
                    GridRow {
                        Text("C\(row + 1)")
                            .foregroundStyle(.secondary)
                        ForEach(constraintCoefficients[row].indices, id: \.self) { column in
                            numberField(value: binding(for: $constraintCoefficients[row], at: column))
                        }
                        Picker("Relation", selection: binding(for: $constraintSigns, at: row)) {
                            ForEach(["≤", "=", "≥"], id: \.self, content: Text.init)
                        }
                        .labelsHidden()
                        .frame(width: 74)
                        numberField(value: binding(for: $constraintRHS, at: row))
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var assumptions: some View {
        GroupBox("Model assumptions") {
            VStack(alignment: .leading, spacing: 8) {
                Label("All variables are continuous and non-negative", systemImage: "checkmark.circle")
                Label("Coefficients and right-hand sides accept decimal values", systemImage: "checkmark.circle")
                Label("Validation will flag missing names, invalid bounds, and infeasible dimensions", systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private func numberField(value: Binding<Double>) -> some View {
        TextField("0", value: value, format: .number.precision(.fractionLength(0...3)))
            .textFieldStyle(.roundedBorder)
            .frame(width: 86)
    }

    private func binding<T>(for values: Binding<[T]>, at index: Int) -> Binding<T> {
        Binding(
            get: { values.wrappedValue[index] },
            set: { values.wrappedValue[index] = $0 }
        )
    }

    private func resizeVariables(to count: Int) {
        while variableNames.count < count {
            variableNames.append("x\(variableNames.count + 1)")
            objectiveCoefficients.append(0)
        }
        variableNames = Array(variableNames.prefix(count))
        objectiveCoefficients = Array(objectiveCoefficients.prefix(count))
        for row in constraintCoefficients.indices {
            constraintCoefficients[row].append(contentsOf: repeatElement(0, count: max(0, count - constraintCoefficients[row].count)))
            constraintCoefficients[row] = Array(constraintCoefficients[row].prefix(count))
        }
        status = "Draft model · \(count) variables · \(constraintCount) constraints"
    }

    private func resizeConstraints(to count: Int) {
        while constraintCoefficients.count < count {
            constraintCoefficients.append(Array(repeating: 0, count: variableCount))
            constraintSigns.append("≤")
            constraintRHS.append(0)
        }
        constraintCoefficients = Array(constraintCoefficients.prefix(count))
        constraintSigns = Array(constraintSigns.prefix(count))
        constraintRHS = Array(constraintRHS.prefix(count))
        status = "Draft model · \(variableCount) variables · \(count) constraints"
    }
}

private enum LPObjective: String, CaseIterable, Identifiable {
    case maximize
    case minimize

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}
