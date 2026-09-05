import SwiftUI
import QSBCore

struct MarkovSolutionView: View {
    let document: MarkovSolutionDocument

    private var states: [String] { document.request.model.states }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeaderView(
                    title: document.request.model.title,
                    subtitle: "Markov analysis · \(document.backend.algorithm)"
                )
                HStack(spacing: 12) {
                    metric("States", "\(states.count)")
                    metric("Stationary cost", number(document.solution.stationaryExpectedCost))
                    metric("Transient periods", document.solution.transientResults.isEmpty ? "Not supplied" : "\(document.solution.transientResults.count)")
                }
                stationaryTable
                if !document.solution.transientResults.isEmpty {
                    transientTable
                }
                GroupBox("Assumptions") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Row-vector convention: S(t + 1) = S(t)P.")
                        Text("Stationary analysis uses the exact native linear-system method for a unique stationary distribution.")
                        Text("Transient results are propagated only when the model supplies an initial distribution.")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                }
                GroupBox("Run context") {
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("Backend", value: document.backend.backendKind.rawValue)
                        LabeledContent("Algorithm", value: document.backend.algorithm)
                        LabeledContent("Exactness", value: document.backend.exactness.rawValue)
                    }
                    .padding(4)
                }
            }
            .padding(20)
        }
    }

    private var stationaryTable: some View {
        GroupBox("Stationary distribution") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(states.enumerated()), id: \.offset) { index, state in
                    probabilityRow(
                        label: state,
                        probability: document.solution.stationaryProbabilities[safe: index] ?? 0,
                        detail: "Long-run probability"
                    )
                }
            }
            .padding(4)
        }
    }

    private var transientTable: some View {
        GroupBox("Transient propagation") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(document.solution.transientResults, id: \.period) { result in
                    DisclosureGroup("Period \(result.period) · expected cost \(number(result.expectedCost))") {
                        ForEach(Array(states.enumerated()), id: \.offset) { index, state in
                            probabilityRow(
                                label: state,
                                probability: result.probabilities[safe: index] ?? 0,
                                detail: "Period \(result.period) probability"
                            )
                        }
                    }
                }
            }
            .padding(4)
        }
    }

    private func probabilityRow(label: String, probability: Double, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(number(probability)).monospacedDigit()
            }
            ProgressView(value: min(max(probability, 0), 1))
                .tint(.accentColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue("\(detail): \(number(probability))")
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func number(_ value: Double) -> String {
        value.formatted(.number.precision(.significantDigits(6)))
    }
}

private extension Array where Element == Double {
    subscript(safe index: Int) -> Double? {
        indices.contains(index) ? self[index] : nil
    }
}
