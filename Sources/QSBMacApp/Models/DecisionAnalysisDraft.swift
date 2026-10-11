import Foundation
import QSBCore

enum DecisionAnalysisDraftError: Error, Equatable, CustomStringConvertible {
    case emptyTitle
    case invalidNumber(path: String, value: String)

    var path: String {
        switch self {
        case .emptyTitle: "model.title"
        case .invalidNumber(let path, _): path
        }
    }

    var description: String {
        switch self {
        case .emptyTitle: "Enter a model title."
        case .invalidNumber(let path, let value): "Enter a finite number for \(path) (received ‘\(value)’)."
        }
    }
}

struct DecisionAnalysisDraft: Equatable, Sendable {
    let kind: DecisionAnalysisProblemKind
    var title: String
    var states: [String]
    var priorProbabilities: [String]
    var observations: [String]
    var likelihoods: [[String]]
    var decisions: [String]
    var payoffs: [[String]]

    private init(
        kind: DecisionAnalysisProblemKind, title: String, states: [String],
        priorProbabilities: [String], observations: [String], likelihoods: [[String]],
        decisions: [String], payoffs: [[String]]
    ) {
        self.kind = kind
        self.title = title
        self.states = states
        self.priorProbabilities = priorProbabilities
        self.observations = observations
        self.likelihoods = likelihoods
        self.decisions = decisions
        self.payoffs = payoffs
    }

    static func blank(_ kind: DecisionAnalysisProblemKind) -> Self? {
        guard kind == .payoff || kind == .bayesian else { return nil }
        return Self(
            kind: kind,
            title: kind == .payoff ? "New Payoff Analysis" : "New Bayesian Analysis",
            states: ["State 1", "State 2"],
            priorProbabilities: ["0.5", "0.5"],
            observations: kind == .payoff ? ["Indicator 1", "Indicator 2"] : ["Outcome 1", "Outcome 2"],
            likelihoods: [["0.8", "0.2"], ["0.2", "0.8"]],
            decisions: kind == .payoff ? ["Decision 1", "Decision 2"] : [],
            payoffs: kind == .payoff ? [["10", "0"], ["0", "10"]] : []
        )
    }

    init?(_ envelope: DecisionAnalysisModelEnvelope) {
        switch envelope {
        case .payoff(let model):
            // Malformed matrix shapes stay in JSON so the editor never invents or drops cells.
            guard Self.hasEditableDimensions(
                states: model.states, priors: model.priorProbabilities,
                observations: model.indicators, likelihoods: model.indicatorLikelihoods,
                decisions: model.decisions, payoffs: model.payoffs
            ) else { return nil }
            self.init(
                kind: .payoff, title: model.title, states: model.states,
                priorProbabilities: model.priorProbabilities.map { String($0) },
                observations: model.indicators,
                likelihoods: model.indicatorLikelihoods.map { $0.map { String($0) } },
                decisions: model.decisions,
                payoffs: model.payoffs.map { $0.map { String($0) } }
            )
        case .bayesian(let model):
            guard Self.hasEditableDimensions(
                states: model.states, priors: model.priorProbabilities,
                observations: model.outcomes, likelihoods: model.likelihoods,
                decisions: [], payoffs: []
            ) else { return nil }
            self.init(
                kind: .bayesian, title: model.title, states: model.states,
                priorProbabilities: model.priorProbabilities.map { String($0) },
                observations: model.outcomes,
                likelihoods: model.likelihoods.map { $0.map { String($0) } },
                decisions: [], payoffs: []
            )
        case .decisionTree, .zeroSumGame:
            return nil
        }
    }

    func makeModel() throws -> DecisionAnalysisModelEnvelope {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecisionAnalysisDraftError.emptyTitle
        }
        let priors = try priorProbabilities.enumerated().map { index, text in
            try Self.number(text, path: "model.priorProbabilities.\(index)")
        }
        let probabilities = try likelihoods.enumerated().map { row, values in
            try values.enumerated().map { column, text in
                let field = kind == .payoff ? "indicatorLikelihoods" : "likelihoods"
                return try Self.number(text, path: "model.\(field).\(row).\(column)")
            }
        }
        switch kind {
        case .payoff:
            let values = try payoffs.enumerated().map { row, entries in
                try entries.enumerated().map { column, text in
                    try Self.number(text, path: "model.payoffs.\(row).\(column)")
                }
            }
            return .payoff(DecisionPayoffProblem(
                title: title, states: states, priorProbabilities: priors,
                indicators: observations, indicatorLikelihoods: probabilities,
                decisions: decisions, payoffs: values
            ))
        case .bayesian:
            return .bayesian(BayesianAnalysisProblem(
                title: title, states: states, priorProbabilities: priors,
                outcomes: observations, likelihoods: probabilities
            ))
        case .decisionTree, .zeroSumGame:
            throw DecisionAnalysisModelError.invalidModel("This native editor supports payoff and Bayesian models.")
        }
    }

    func draftDiagnostics() -> [ValidationDiagnostic] {
        do {
            return DecisionAnalysisValidator.diagnostics(for: try makeModel())
        } catch let error as DecisionAnalysisDraftError {
            return [ValidationDiagnostic(
                severity: .error,
                code: "decisionAnalysis.draft.\(error.path.replacingOccurrences(of: ".", with: "_"))",
                message: error.description,
                path: error.path
            )]
        } catch {
            return [ValidationDiagnostic(
                severity: .error, code: "decisionAnalysis.draft.invalid",
                message: error.localizedDescription
            )]
        }
    }

    mutating func addState() {
        states.append(Self.uniqueName(prefix: "State", existing: states))
        priorProbabilities.append("0")
        for index in likelihoods.indices { likelihoods[index].append("0") }
        for index in payoffs.indices { payoffs[index].append("0") }
    }

    mutating func removeState(at index: Int) {
        guard states.count > 1, states.indices.contains(index) else { return }
        states.remove(at: index)
        priorProbabilities.remove(at: index)
        for row in likelihoods.indices { likelihoods[row].remove(at: index) }
        for row in payoffs.indices { payoffs[row].remove(at: index) }
    }

    mutating func addObservation() {
        observations.append(Self.uniqueName(prefix: kind == .payoff ? "Indicator" : "Outcome", existing: observations))
        likelihoods.append(Array(repeating: "0", count: states.count))
    }

    mutating func removeObservation(at index: Int) {
        guard observations.count > 1, observations.indices.contains(index) else { return }
        observations.remove(at: index)
        likelihoods.remove(at: index)
    }

    mutating func addDecision() {
        guard kind == .payoff else { return }
        decisions.append(Self.uniqueName(prefix: "Decision", existing: decisions))
        payoffs.append(Array(repeating: "0", count: states.count))
    }

    mutating func removeDecision(at index: Int) {
        guard kind == .payoff, decisions.count > 1, decisions.indices.contains(index) else { return }
        decisions.remove(at: index)
        payoffs.remove(at: index)
    }

    func statesTabularText() -> String {
        let rows = states.indices.map { [states[$0], priorProbabilities[$0]] }
        return (["State\tPrior Probability"] + rows.map { $0.joined(separator: "\t") }).joined(separator: "\n")
    }

    mutating func replaceStates(withTabularText text: String) throws {
        var rows = try SpreadsheetTable(text: text).rows
        if rows[0][0].lowercased().filter(\.isLetter) == "state" { rows.removeFirst() }
        guard !rows.isEmpty else { throw SpreadsheetTransferError.emptyClipboard }

        var names: [String] = []
        var priors: [String] = []
        for (index, values) in rows.enumerated() {
            let row = index + 1
            guard values.count == 2 else {
                throw SpreadsheetTransferError.inconsistentColumns(expected: 2, actual: values.count, row: row)
            }
            let name = values[0].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                throw SpreadsheetTransferError.invalidValue(values[0], column: "State", row: row)
            }
            try SpreadsheetTable.requireFinite(values[1], column: "Prior Probability", row: row)
            names.append(name)
            priors.append(values[1])
        }

        let newCount = names.count
        likelihoods = likelihoods.map { Self.resized($0, to: newCount) }
        payoffs = payoffs.map { Self.resized($0, to: newCount) }
        states = names
        priorProbabilities = priors
    }

    func likelihoodsTabularText() -> String {
        namedMatrixTabularText(firstColumn: kind == .payoff ? "Indicator" : "Outcome", names: observations, values: likelihoods)
    }

    mutating func replaceLikelihoods(withTabularText text: String) throws {
        let parsed = try Self.parseNamedMatrix(
            text,
            firstColumn: kind == .payoff ? "Indicator" : "Outcome",
            stateNames: states
        )
        observations = parsed.names
        likelihoods = parsed.values
    }

    func payoffsTabularText() -> String {
        namedMatrixTabularText(firstColumn: "Decision", names: decisions, values: payoffs)
    }

    mutating func replacePayoffs(withTabularText text: String) throws {
        guard kind == .payoff else { return }
        let parsed = try Self.parseNamedMatrix(text, firstColumn: "Decision", stateNames: states)
        decisions = parsed.names
        payoffs = parsed.values
    }

    private func namedMatrixTabularText(firstColumn: String, names: [String], values: [[String]]) -> String {
        let header = [firstColumn] + states
        let rows = names.indices.map { [names[$0]] + values[$0] }
        return ([header] + rows).map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }

    private static func parseNamedMatrix(
        _ text: String,
        firstColumn: String,
        stateNames: [String]
    ) throws -> (names: [String], values: [[String]]) {
        var rows = try SpreadsheetTable(text: text).rows
        let normalizedFirstColumn = firstColumn.lowercased().filter(\.isLetter)
        if rows[0][0].lowercased().filter(\.isLetter) == normalizedFirstColumn {
            let pastedStates = Array(rows[0].dropFirst())
            guard pastedStates == stateNames else {
                throw SpreadsheetTransferError.invalidValue(
                    pastedStates.joined(separator: ", "),
                    column: "State headers",
                    row: 1
                )
            }
            rows.removeFirst()
        }
        guard !rows.isEmpty else { throw SpreadsheetTransferError.emptyClipboard }

        var names: [String] = []
        var matrix: [[String]] = []
        for (index, rowValues) in rows.enumerated() {
            let row = index + 1
            let expected = stateNames.count + 1
            guard rowValues.count == expected else {
                throw SpreadsheetTransferError.inconsistentColumns(expected: expected, actual: rowValues.count, row: row)
            }
            let name = rowValues[0].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                throw SpreadsheetTransferError.invalidValue(rowValues[0], column: firstColumn, row: row)
            }
            let values = Array(rowValues.dropFirst())
            for (column, value) in values.enumerated() {
                try SpreadsheetTable.requireFinite(value, column: stateNames[column], row: row)
            }
            names.append(name)
            matrix.append(values)
        }
        return (names, matrix)
    }

    private static func resized(_ values: [String], to count: Int) -> [String] {
        var result = Array(values.prefix(count))
        result.append(contentsOf: repeatElement("0", count: max(0, count - result.count)))
        return result
    }

    private static func number(_ text: String, path: String) throws -> Double {
        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)), value.isFinite else {
            throw DecisionAnalysisDraftError.invalidNumber(path: path, value: text)
        }
        return value
    }

    private static func uniqueName(prefix: String, existing: [String]) -> String {
        var index = 1
        while existing.contains("\(prefix) \(index)") { index += 1 }
        return "\(prefix) \(index)"
    }

    private static func hasEditableDimensions(
        states: [String], priors: [Double], observations: [String], likelihoods: [[Double]],
        decisions: [String], payoffs: [[Double]]
    ) -> Bool {
        priors.count == states.count && likelihoods.count == observations.count
            && likelihoods.allSatisfy { $0.count == states.count }
            && payoffs.count == decisions.count
            && payoffs.allSatisfy { $0.count == states.count }
    }
}
