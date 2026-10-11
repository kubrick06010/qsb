import Charts
import QSBCore
import SwiftUI

struct NonlinearProgrammingSolutionView: View {
    let document: NonlinearProgramSolutionDocument

    private var variables: [NonlinearVariableValue] {
        document.model.variableNames.enumerated().map { index, name in
            NonlinearVariableValue(
                index: index,
                name: name,
                value: document.solution.variableValues[name] ?? 0,
                lower: document.model.lowerBounds[index],
                upper: document.model.upperBounds[index]
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeaderView(
                    title: document.model.title,
                    subtitle: "Nonlinear programming · \(document.backend.algorithmDisplayName)"
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 12)], alignment: .leading, spacing: 12) {
                    metric("Objective", number(document.solution.objectiveValue))
                    metric("Sense", document.model.sense.rawValue.capitalized)
                    metric("Iterations", "\(document.solution.iterations)")
                    metric("Maximum violation", number(document.solution.maximumViolation))
                    metric("Exactness", document.backend.exactnessDisplayName)
                }

                objectiveDefinition
                variableChart
                variableDetails
                constraintEvaluations
                runContext
            }
            .padding(20)
            .frame(maxWidth: 1080, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var objectiveDefinition: some View {
        GroupBox("Objective") {
            LabeledContent(document.model.sense.rawValue.capitalized) {
                Text(document.model.objectiveExpression)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
            .padding(4)
        }
    }

    private var variableChart: some View {
        GroupBox("Candidate variable values") {
            ScrollView(.horizontal) {
                Chart(variables) { variable in
                    BarMark(x: .value("Variable", variable.name), y: .value("Value", variable.value))
                        .foregroundStyle(Color.teal.gradient)
                        .accessibilityLabel("Variable \(variable.name)")
                        .accessibilityValue(number(variable.value))
                    RuleMark(y: .value("Zero", 0)).foregroundStyle(.secondary)
                }
                .frame(width: max(560, CGFloat(variables.count) * 86), height: 245)
                .padding(.vertical, 8)
            }
        }
    }

    private var variableDetails: some View {
        GroupBox("Variables") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], alignment: .leading, spacing: 12) {
                ForEach(variables) { variable in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(variable.name).font(.headline)
                            Spacer()
                            Text(number(variable.value)).font(.headline).monospacedDigit()
                        }
                        Text(bounds(variable)).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Variable \(variable.name)")
                    .accessibilityValue("Value \(number(variable.value)), \(bounds(variable))")
                }
            }
            .padding(4)
        }
    }

    private var constraintEvaluations: some View {
        GroupBox("Constraint evaluations") {
            if document.solution.constraintEvaluations.isEmpty {
                Text("No nonlinear constraints")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal) {
                    Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 8) {
                        GridRow {
                            heading("Constraint")
                            heading("Value")
                            heading("Relation")
                            heading("Right side")
                            heading("Violation")
                        }
                        Divider().gridCellUnsizedAxes(.horizontal)
                        ForEach(Array(document.solution.constraintEvaluations.enumerated()), id: \.offset) { _, evaluation in
                            GridRow {
                                Text(evaluation.name).fontWeight(.semibold)
                                value(evaluation.value)
                                Text(evaluation.relation.rawValue)
                                value(evaluation.rhs)
                                value(evaluation.violation)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Constraint \(evaluation.name)")
                        }
                    }
                    .padding(4)
                }
            }
        }
    }

    private var runContext: some View {
        GroupBox("Run context") {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Backend", value: document.backend.backendDisplayName)
                LabeledContent("Algorithm", value: document.backend.algorithmDisplayName)
                LabeledContent("Exactness", value: document.backend.exactnessDisplayName)
                if document.model.normalizedStrictInequalities {
                    Label("Strict legacy inequalities were normalized to non-strict boundaries.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                ForEach(Array(document.backend.notes.enumerated()), id: \.offset) { _, note in
                    Label(note, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(4)
        }
    }

    private func bounds(_ variable: NonlinearVariableValue) -> String {
        "bounds \(variable.lower.map(number) ?? "−∞")…\(variable.upper.map(number) ?? "∞")"
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    private func heading(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
    }

    private func value(_ number: Double) -> some View {
        Text(self.number(number)).monospacedDigit().frame(minWidth: 72, alignment: .trailing)
    }

    private func number(_ value: Double) -> String {
        let displayValue = abs(value) < 1e-9 ? 0 : value
        return displayValue.formatted(.number.precision(.fractionLength(0...6)))
    }
}

private struct NonlinearVariableValue: Identifiable {
    let index: Int
    let name: String
    let value: Double
    let lower: Double?
    let upper: Double?

    var id: Int { index }
}
