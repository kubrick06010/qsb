import Charts
import QSBCore
import SwiftUI

struct QuadraticProgrammingSolutionView: View {
    let document: QuadraticProgramSolutionDocument

    private var variables: [OptimizationVariableValue] {
        document.model.variableNames.enumerated().map { index, name in
            OptimizationVariableValue(
                index: index,
                name: name,
                value: document.solution.variableValues[name] ?? 0,
                lower: document.model.lowerBounds[index],
                upper: document.model.upperBounds[index],
                domain: document.model.variableTypes[index].rawValue
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeaderView(
                    title: document.model.title,
                    subtitle: "Quadratic programming · \(document.backend.algorithmDisplayName)"
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 12)], alignment: .leading, spacing: 12) {
                    metric("Objective", number(document.solution.objectiveValue))
                    metric("Sense", document.model.sense.rawValue.capitalized)
                    metric("Variables", "\(variables.count)")
                    metric("Active constraints", "\(document.solution.activeConstraints.count)")
                    metric("Exactness", document.backend.exactnessDisplayName)
                }

                variableChart
                variableDetails
                activeConstraints
                runContext
            }
            .padding(20)
            .frame(maxWidth: 1080, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var variableChart: some View {
        GroupBox("Optimal variable values") {
            ScrollView(.horizontal) {
                Chart(variables) { variable in
                    BarMark(x: .value("Variable", variable.name), y: .value("Value", variable.value))
                        .foregroundStyle(Color.blue.gradient)
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
        GroupBox("Decision variables") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], alignment: .leading, spacing: 12) {
                ForEach(variables) { variable in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(variable.name).font(.headline)
                            Spacer()
                            Text(number(variable.value)).font(.headline).monospacedDigit()
                        }
                        Text("\(variable.domain.capitalized) · \(bounds(variable))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Variable \(variable.name)")
                    .accessibilityValue("Value \(number(variable.value)), \(variable.domain), \(bounds(variable))")
                }
            }
            .padding(4)
        }
    }

    private var activeConstraints: some View {
        GroupBox("Active constraints and bounds") {
            if document.solution.activeConstraints.isEmpty {
                Text("No named constraint or bound is active at the optimum.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(document.solution.activeConstraints, id: \.self) { name in
                        Label(name, systemImage: "equal.circle")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var runContext: some View {
        GroupBox("Run context") {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Backend", value: document.backend.backendDisplayName)
                LabeledContent("Algorithm", value: document.backend.algorithmDisplayName)
                LabeledContent("Exactness", value: document.backend.exactnessDisplayName)
                ForEach(Array(document.backend.notes.enumerated()), id: \.offset) { _, note in
                    Label(note, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(4)
        }
    }

    private func bounds(_ variable: OptimizationVariableValue) -> String {
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

    private func number(_ value: Double) -> String {
        let displayValue = abs(value) < 1e-9 ? 0 : value
        return displayValue.formatted(.number.precision(.fractionLength(0...6)))
    }
}

private struct OptimizationVariableValue: Identifiable {
    let index: Int
    let name: String
    let value: Double
    let lower: Double?
    let upper: Double?
    let domain: String

    var id: Int { index }
}
