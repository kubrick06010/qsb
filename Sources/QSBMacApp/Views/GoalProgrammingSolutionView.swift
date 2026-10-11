import SwiftUI
import QSBCore

struct GoalProgrammingSolutionView: View {
    let document: GoalProgrammingSolutionDocument

    private var summaryColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 170), spacing: 12, alignment: .leading)]
    }

    private var variableColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 220), spacing: 12, alignment: .leading)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeaderView(
                    title: document.model.title,
                    subtitle: "Preemptive goal programming · \(document.backend.algorithmDisplayName)"
                )

                LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 12) {
                    metric("Priorities", "\(document.solution.goalOutcomes.count)")
                    metric("Variables", "\(document.model.variableNames.count)")
                    metric("Constraints", "\(document.model.constraints.count)")
                    metric("Exactness", document.backend.exactnessDisplayName)
                }

                priorityOutcomes
                variableValues
                runContext
            }
            .padding(20)
            .frame(maxWidth: 1100, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var priorityOutcomes: some View {
        GroupBox("Priority outcomes") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(document.solution.goalOutcomes.enumerated()), id: \.offset) { index, outcome in
                    if index > 0 { Divider() }
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(outcome.priority)")
                            .font(.headline.monospacedDigit())
                            .frame(width: 30, height: 30)
                            .background(.tint.opacity(0.14), in: Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(outcome.name).font(.headline)
                            Text(outcome.sense.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 12)
                        Text(number(outcome.value))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Priority \(outcome.priority), \(outcome.name)")
                    .accessibilityValue("\(outcome.sense.rawValue), value \(number(outcome.value))")
                }
            }
            .padding(4)
        }
    }

    private var variableValues: some View {
        GroupBox("Decision variables") {
            LazyVGrid(columns: variableColumns, alignment: .leading, spacing: 12) {
                ForEach(Array(document.model.variableNames.enumerated()), id: \.offset) { index, name in
                    let value = document.solution.variableValues[name] ?? 0
                    let type = document.model.variableTypes[index]
                    let lower = document.model.lowerBounds[index]
                    let upper = document.model.upperBounds[index]

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(name).font(.headline)
                            Spacer()
                            Text(number(value)).font(.headline).monospacedDigit()
                        }
                        Text("\(type.rawValue.capitalized) · \(bounds(lower: lower, upper: upper))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Variable \(name)")
                    .accessibilityValue("Value \(number(value)), \(type.rawValue), \(bounds(lower: lower, upper: upper))")
                }
            }
            .padding(4)
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

    private func bounds(lower: Double, upper: Double?) -> String {
        "bounds \(number(lower))…\(upper.map(number) ?? "∞")"
    }

    private func number(_ value: Double) -> String {
        let displayValue = abs(value) < 1e-9 ? 0 : value
        return displayValue.formatted(.number.precision(.fractionLength(0...6)))
    }
}
