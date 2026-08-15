import SwiftUI
import QSBCore

private struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading) {
                Text(value).font(.headline)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct LinearProgrammingSolutionView: View {
    let program: LinearProgram
    let solution: LinearProgramSolution

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    MetricCard(title: "Objective", value: format(solution.objectiveValue), systemImage: "target")
                    MetricCard(title: "Variables", value: "\(program.variableNames.count)", systemImage: "list.number")
                    MetricCard(title: "Constraints", value: "\(program.constraints.count)", systemImage: "equal.square")
                }
                GroupBox("Decision variables") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Variable").font(.caption.weight(.semibold))
                            Spacer()
                            Text("Value").font(.caption.weight(.semibold))
                        }
                        ForEach(Array(program.variableNames.enumerated()), id: \.offset) { _, name in
                            HStack {
                                Text(name)
                                Spacer()
                                Text(format(solution.variableValues[name] ?? 0)).monospacedDigit()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                }
                if !program.constraints.isEmpty {
                    GroupBox("Constraint details") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(program.constraints, id: \.name) { constraint in
                                let lhs = zip(constraint.coefficients, program.variableNames)
                                    .reduce(0) { partial, item in partial + item.0 * (solution.variableValues[item.1] ?? 0) }
                                LabeledContent(constraint.name, value: "\(format(lhs)) \(constraint.relation.rawValue) \(format(constraint.rhs))")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(24)
        }
    }

    private func format(_ value: Double) -> String {
        let rounded = value.rounded()
        return abs(value - rounded) < 1e-8 ? String(Int(rounded)) : String(format: "%.6f", value)
    }
}
