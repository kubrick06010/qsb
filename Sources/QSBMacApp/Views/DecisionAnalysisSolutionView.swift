import SwiftUI
import QSBCore

struct DecisionAnalysisSolutionView: View {
    let document: DecisionAnalysisSolutionDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch (document.model, document.solution) {
                case (.payoff(let model), .payoff(let solution)):
                    PayoffAnalysisPresentation(model: model, solution: solution)
                case (.bayesian(let model), .bayesian(let solution)):
                    BayesianAnalysisPresentation(model: model, solution: solution)
                case (.zeroSumGame(let model), .zeroSumGame(let solution)):
                    ZeroSumGamePresentation(model: model, solution: solution)
                default:
                    ContentUnavailableView("Mismatched Decision Analysis result", systemImage: "exclamationmark.triangle")
                }
                RunMetadataView(metadata: document.backend)
            }
            .padding(20)
        }
    }
}

private struct PayoffAnalysisPresentation: View {
    let model: DecisionPayoffProblem
    let solution: DecisionPayoffSolution

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.title).font(.title2.weight(.semibold))
            Text("Expected values by decision and state, with the value of information.")
                .foregroundStyle(.secondary)

            GroupBox("Payoff table") {
                ScrollView(.horizontal) {
                    Grid(alignment: .trailing, horizontalSpacing: 14, verticalSpacing: 8) {
                        GridRow {
                            Text("Decision").bold().gridColumnAlignment(.leading)
                            ForEach(model.states, id: \.self) { Text($0).bold() }
                            Text("Expected value").bold()
                        }
                        ForEach(Array(model.decisions.enumerated()), id: \.offset) { index, decision in
                            GridRow {
                                Text(decision).gridColumnAlignment(.leading)
                                ForEach(model.payoffs[safe: index] ?? [], id: \.self) { value in
                                    Text(Self.number(value)).monospacedDigit()
                                }
                                Text(Self.number(solution.priorExpectedValues[safe: index]?.expectedValue ?? 0))
                                    .monospacedDigit()
                            }
                        }
                    }
                    .padding(4)
                }
            }

            HStack(spacing: 12) {
                metric("Best decision", solution.bestPriorDecision)
                metric("Expected value", Self.number(solution.bestPriorExpectedValue))
                metric("Perfect information", Self.number(solution.expectedValueOfPerfectInformation))
            }

            GroupBox("Information value") {
                VStack(alignment: .leading, spacing: 8) {
                    valueRow("With sample information", solution.expectedValueWithSampleInformation)
                    valueRow("Value of sample information", solution.expectedValueOfSampleInformation)
                    valueRow("With perfect information", solution.expectedValueWithPerfectInformation)
                    valueRow("Value of perfect information", solution.expectedValueOfPerfectInformation)
                }
                .padding(4)
            }

            if !solution.indicatorAnalyses.isEmpty {
                GroupBox("Indicator recommendations") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(solution.indicatorAnalyses.enumerated()), id: \.offset) { _, analysis in
                            HStack {
                                Text(analysis.indicator)
                                Spacer()
                                Text("P = \(Self.number(analysis.probability))")
                                    .foregroundStyle(.secondary)
                                Text(analysis.bestDecision)
                                    .bold()
                                Text(Self.number(analysis.bestExpectedValue))
                                    .monospacedDigit()
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Indicator \(analysis.indicator)")
                            .accessibilityValue("Best decision \(analysis.bestDecision), expected value \(Self.number(analysis.bestExpectedValue))")
                        }
                    }
                    .padding(4)
                }
            }
        }
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

    private func valueRow(_ label: String, _ value: Double) -> some View {
        LabeledContent(label, value: Self.number(value))
    }

    private static func number(_ value: Double) -> String { value.formatted(.number.precision(.significantDigits(6))) }
}

private struct BayesianAnalysisPresentation: View {
    let model: BayesianAnalysisProblem
    let solution: BayesianAnalysisSolution

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.title).font(.title2.weight(.semibold))
            Text("Posterior state probabilities for each observed outcome.")
                .foregroundStyle(.secondary)
            GroupBox("Posterior probabilities") {
                ScrollView(.horizontal) {
                    Grid(alignment: .trailing, horizontalSpacing: 14, verticalSpacing: 8) {
                        GridRow {
                            Text("Outcome").bold().gridColumnAlignment(.leading)
                            Text("Probability").bold()
                            ForEach(model.states, id: \.self) { Text($0).bold() }
                        }
                        ForEach(Array(solution.outcomes.enumerated()), id: \.offset) { _, outcome in
                            GridRow {
                                Text(outcome.outcome).gridColumnAlignment(.leading)
                                Text(Self.number(outcome.probability)).monospacedDigit()
                                ForEach(outcome.posteriorProbabilities, id: \.self) { value in
                                    Text(Self.number(value)).monospacedDigit()
                                }
                            }
                        }
                    }
                    .padding(4)
                }
            }
        }
    }

    private static func number(_ value: Double) -> String { value.formatted(.number.precision(.significantDigits(6))) }
}

private struct ZeroSumGamePresentation: View {
    let model: ZeroSumGame
    let solution: ZeroSumGameSolution

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.title).font(.title2.weight(.semibold))
            Text("Mixed strategies and the value of the zero-sum game.")
                .foregroundStyle(.secondary)
            GroupBox("Payoff matrix") {
                ScrollView(.horizontal) {
                    Grid(alignment: .trailing, horizontalSpacing: 14, verticalSpacing: 8) {
                        GridRow {
                            Text("Row strategy").bold().gridColumnAlignment(.leading)
                            ForEach(model.columnStrategies, id: \.self) { Text($0).bold() }
                        }
                        ForEach(Array(model.rowStrategies.enumerated()), id: \.offset) { index, strategy in
                            GridRow {
                                Text(strategy).gridColumnAlignment(.leading)
                                ForEach(model.payoffs[safe: index] ?? [], id: \.self) { Text(Self.number($0)).monospacedDigit() }
                            }
                        }
                    }
                    .padding(4)
                }
            }
            HStack(spacing: 12) {
                metric("Game value", Self.number(solution.value))
                metric("Row strategy", mixedStrategySummary(solution.rowStrategy))
                metric("Column strategy", mixedStrategySummary(solution.columnStrategy))
            }
            strategyList(title: "Row player", values: solution.rowStrategy)
            strategyList(title: "Column player", values: solution.columnStrategy)
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
    }

    private func strategyList(title: String, values: [StrategyProbability]) -> some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, item in
                    HStack {
                        Text(item.strategy)
                        Spacer()
                        Text(Self.number(item.probability)).monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("(title) strategy (item.strategy)")
                    .accessibilityValue("Probability (Self.number(item.probability))")
                }
            }
            .padding(4)
        }
    }

    private func mixedStrategySummary(_ values: [StrategyProbability]) -> String {
        values.filter { $0.probability > 0.0001 }.map { "\($0.strategy): \(Self.number($0.probability))" }.joined(separator: ", ")
    }

    private static func number(_ value: Double) -> String { value.formatted(.number.precision(.significantDigits(6))) }
}

private struct RunMetadataView: View {
    let metadata: SolverRunMetadata

    var body: some View {
        GroupBox("Run context") {
            LabeledContent("Backend", value: metadata.backendKind.rawValue)
            LabeledContent("Algorithm", value: metadata.algorithm)
            LabeledContent("Exactness", value: metadata.exactness.rawValue)
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
