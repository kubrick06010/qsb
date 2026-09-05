import Foundation
import QSBCore

enum MarkovDraftError: Error, Equatable, CustomStringConvertible {
    case emptyTitle
    case emptyStates
    case emptyStateName(path: String)
    case invalidNumber(path: String, value: String)
    case invalidInteger(path: String, value: String)
    case dimension(path: String)

    var path: String {
        switch self {
        case .emptyTitle: "model.title"
        case .emptyStates: "model.states"
        case .emptyStateName(let path), .invalidNumber(let path, _), .invalidInteger(let path, _), .dimension(let path): path
        }
    }

    var description: String {
        switch self {
        case .emptyTitle: "Enter a model title."
        case .emptyStates: "Add at least one state."
        case .emptyStateName: "State names must not be empty."
        case .invalidNumber(let path, let value): "Enter a finite number for \(path) (received ‘\(value)’)."
        case .invalidInteger(let path, let value): "Enter a whole number for \(path) (received ‘\(value)’)."
        case .dimension(let path): "The Markov draft is dimensionally inconsistent at \(path)."
        }
    }
}

struct MarkovStateDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var costText: String
    var initialProbabilityText: String

    init(
        id: UUID = UUID(),
        name: String,
        costText: String = "0",
        initialProbabilityText: String = "0"
    ) {
        self.id = id
        self.name = name
        self.costText = costText
        self.initialProbabilityText = initialProbabilityText
    }
}

struct MarkovDraft: Equatable, Sendable {
    var title: String
    var states: [MarkovStateDraft]
    var transitionMatrix: [[String]]
    var includesInitialDistribution: Bool
    var periodsText: String

    init(
        title: String,
        states: [MarkovStateDraft],
        transitionMatrix: [[String]],
        includesInitialDistribution: Bool,
        periodsText: String
    ) {
        self.title = title
        self.states = states
        self.transitionMatrix = transitionMatrix
        self.includesInitialDistribution = includesInitialDistribution
        self.periodsText = periodsText
    }

    static func blank() -> Self {
        Self(
            title: "New Markov Analysis",
            states: [
                MarkovStateDraft(name: "State 1", costText: "0", initialProbabilityText: "1"),
                MarkovStateDraft(name: "State 2", costText: "0", initialProbabilityText: "0")
            ],
            transitionMatrix: [["0.8", "0.2"], ["0.3", "0.7"]],
            includesInitialDistribution: true,
            periodsText: "10"
        )
    }

    init(_ request: MarkovAnalysisRequest) {
        title = request.model.title
        states = request.model.states.enumerated().map { index, name in
            MarkovStateDraft(
                name: name,
                costText: request.model.stateCosts.indices.contains(index) ? Self.format(request.model.stateCosts[index]) : "0",
                initialProbabilityText: request.model.initialProbabilities.flatMap { $0.indices.contains(index) ? Self.format($0[index]) : nil } ?? "0"
            )
        }
        transitionMatrix = request.model.transitionMatrix.map { $0.map(Self.format) }
        includesInitialDistribution = request.model.initialProbabilities != nil
        periodsText = String(request.periods)
    }

    func makeRequest() throws -> MarkovAnalysisRequest {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { throw MarkovDraftError.emptyTitle }
        guard !states.isEmpty else { throw MarkovDraftError.emptyStates }
        let count = states.count
        guard transitionMatrix.count == count,
              transitionMatrix.allSatisfy({ $0.count == count })
        else { throw MarkovDraftError.dimension(path: "model.transitionMatrix") }

        let names = try states.enumerated().map { index, state in
            let name = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { throw MarkovDraftError.emptyStateName(path: "model.states.\(index)") }
            return name
        }
        let matrix = try transitionMatrix.enumerated().map { row, values in
            try values.enumerated().map { column, value in
                try Self.number(value, path: "model.transitionMatrix.\(row).\(column)")
            }
        }
        let costs = try states.enumerated().map { index, state in
            try Self.number(state.costText, path: "model.stateCosts.\(index)")
        }
        let initial = try includesInitialDistribution ? states.enumerated().map { index, state in
            try Self.number(state.initialProbabilityText, path: "model.initialProbabilities.\(index)")
        } : nil
        let periods = try Self.integer(periodsText, path: "periods")

        return MarkovAnalysisRequest(
            model: MarkovChainModel(
                title: trimmedTitle,
                states: names,
                transitionMatrix: matrix,
                initialProbabilities: initial,
                stateCosts: costs
            ),
            periods: periods
        )
    }

    func draftDiagnostics() -> [ValidationDiagnostic] {
        var diagnostics: [ValidationDiagnostic] = []
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            diagnostics.append(draftDiagnostic(code: "model_title", message: "Enter a model title.", path: "model.title"))
        }
        if states.isEmpty {
            diagnostics.append(draftDiagnostic(code: "model_states", message: "Add at least one state.", path: "model.states"))
        }
        let count = states.count
        if transitionMatrix.count != count || transitionMatrix.contains(where: { $0.count != count }) {
            diagnostics.append(draftDiagnostic(code: "model_transitionMatrix", message: "The transition matrix must have one row and column per state.", path: "model.transitionMatrix"))
        }
        for (index, state) in states.enumerated() {
            if state.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                diagnostics.append(draftDiagnostic(code: "model_states_\(index)", message: "State names must not be empty.", path: "model.states.\(index)"))
            }
            if Self.parseNumber(state.costText) == nil {
                diagnostics.append(draftDiagnostic(code: "model_stateCosts_\(index)", message: "Enter a finite number for model.stateCosts.\(index).", path: "model.stateCosts.\(index)"))
            }
            if includesInitialDistribution, Self.parseNumber(state.initialProbabilityText) == nil {
                diagnostics.append(draftDiagnostic(code: "model_initialProbabilities_\(index)", message: "Enter a finite number for model.initialProbabilities.\(index).", path: "model.initialProbabilities.\(index)"))
            }
        }
        for (row, values) in transitionMatrix.enumerated() {
            for (column, value) in values.enumerated() where Self.parseNumber(value) == nil {
                diagnostics.append(draftDiagnostic(code: "model_transitionMatrix_\(row)_\(column)", message: "Enter a finite number for model.transitionMatrix.\(row).\(column).", path: "model.transitionMatrix.\(row).\(column)"))
            }
        }
        if Int(periodsText.trimmingCharacters(in: .whitespacesAndNewlines)) == nil {
            diagnostics.append(draftDiagnostic(code: "periods", message: "Enter a whole number for periods.", path: "periods"))
        }
        if !diagnostics.isEmpty { return diagnostics }
        do {
            return MarkovValidator.diagnostics(for: try makeRequest())
        } catch let error as MarkovDraftError {
            return [ValidationDiagnostic(
                severity: .error,
                code: "markov.draft.\(error.path.replacingOccurrences(of: ".", with: "_"))",
                message: error.description,
                path: error.path
            )]
        } catch {
            return [ValidationDiagnostic(severity: .error, code: "markov.draft.invalid", message: error.localizedDescription)]
        }
    }

    private func draftDiagnostic(code: String, message: String, path: String) -> ValidationDiagnostic {
        ValidationDiagnostic(severity: .error, code: "markov.draft.\(code)", message: message, path: path)
    }

    mutating func addState() {
        let newIndex = states.count
        states.append(MarkovStateDraft(name: nextStateName()))
        for row in transitionMatrix.indices {
            transitionMatrix[row].append("0")
        }
        var newRow = Array(repeating: "0", count: states.count)
        newRow[newIndex] = "1"
        transitionMatrix.append(newRow)
    }

    mutating func removeState(at index: Int) {
        guard states.indices.contains(index), states.count > 1 else { return }
        states.remove(at: index)
        transitionMatrix.remove(at: index)
        for row in transitionMatrix.indices where transitionMatrix[row].indices.contains(index) {
            transitionMatrix[row].remove(at: index)
        }
    }

    mutating func setIncludesInitialDistribution(_ enabled: Bool) {
        includesInitialDistribution = enabled
        guard enabled, !states.isEmpty,
              !states.contains(where: { Double($0.initialProbabilityText) != 0 })
        else { return }
        states[0].initialProbabilityText = "1"
    }

    private func nextStateName() -> String {
        let names = Set(states.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) })
        var number = states.count + 1
        while names.contains("State \(number)") { number += 1 }
        return "State \(number)"
    }

    private static func number(_ value: String, path: String) throws -> Double {
        guard let number = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)), number.isFinite
        else { throw MarkovDraftError.invalidNumber(path: path, value: value) }
        return number
    }

    private static func parseNumber(_ value: String) -> Double? {
        guard let number = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)), number.isFinite else { return nil }
        return number
    }

    private static func integer(_ value: String, path: String) throws -> Int {
        guard let number = Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        else { throw MarkovDraftError.invalidInteger(path: path, value: value) }
        return number
    }

    private static func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }
}
