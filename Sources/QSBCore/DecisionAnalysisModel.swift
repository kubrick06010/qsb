import Foundation

public struct DecisionPayoffProblem: Codable, Equatable, Sendable {
    public let title: String
    public let states: [String]
    public let priorProbabilities: [Double]
    public let indicators: [String]
    public let indicatorLikelihoods: [[Double]]
    public let decisions: [String]
    public let payoffs: [[Double]]

    public init(
        title: String,
        states: [String],
        priorProbabilities: [Double],
        indicators: [String],
        indicatorLikelihoods: [[Double]],
        decisions: [String],
        payoffs: [[Double]]
    ) {
        self.title = title
        self.states = states
        self.priorProbabilities = priorProbabilities
        self.indicators = indicators
        self.indicatorLikelihoods = indicatorLikelihoods
        self.decisions = decisions
        self.payoffs = payoffs
    }
}

public struct DecisionExpectedValue: Codable, Equatable, Sendable {
    public let decision: String
    public let expectedValue: Double
}

public struct IndicatorDecisionAnalysis: Codable, Equatable, Sendable {
    public let indicator: String
    public let probability: Double
    public let posteriorProbabilities: [Double]
    public let expectedValues: [DecisionExpectedValue]
    public let bestDecision: String
    public let bestExpectedValue: Double
}

public struct DecisionPayoffSolution: Codable, Equatable, Sendable {
    public let priorExpectedValues: [DecisionExpectedValue]
    public let bestPriorDecision: String
    public let bestPriorExpectedValue: Double
    public let indicatorAnalyses: [IndicatorDecisionAnalysis]
    public let expectedValueWithSampleInformation: Double
    public let expectedValueOfSampleInformation: Double
    public let expectedValueWithPerfectInformation: Double
    public let expectedValueOfPerfectInformation: Double
}

public struct BayesianAnalysisProblem: Codable, Equatable, Sendable {
    public let title: String
    public let states: [String]
    public let priorProbabilities: [Double]
    public let outcomes: [String]
    public let likelihoods: [[Double]]

    public init(
        title: String,
        states: [String],
        priorProbabilities: [Double],
        outcomes: [String],
        likelihoods: [[Double]]
    ) {
        self.title = title
        self.states = states
        self.priorProbabilities = priorProbabilities
        self.outcomes = outcomes
        self.likelihoods = likelihoods
    }
}

public struct BayesianOutcomeAnalysis: Codable, Equatable, Sendable {
    public let outcome: String
    public let probability: Double
    public let posteriorProbabilities: [Double]
}

public struct BayesianAnalysisSolution: Codable, Equatable, Sendable {
    public let outcomes: [BayesianOutcomeAnalysis]
}

public struct ZeroSumGame: Codable, Equatable, Sendable {
    public let title: String
    public let rowStrategies: [String]
    public let columnStrategies: [String]
    public let payoffs: [[Double]]

    public init(title: String, rowStrategies: [String], columnStrategies: [String], payoffs: [[Double]]) {
        self.title = title
        self.rowStrategies = rowStrategies
        self.columnStrategies = columnStrategies
        self.payoffs = payoffs
    }
}

public struct StrategyProbability: Codable, Equatable, Sendable {
    public let strategy: String
    public let probability: Double
}

public struct ZeroSumGameSolution: Codable, Equatable, Sendable {
    public let value: Double
    public let rowStrategy: [StrategyProbability]
    public let columnStrategy: [StrategyProbability]
}

public enum ZeroSumGameValidator {
    public static func diagnostics(for game: ZeroSumGame) -> [ValidationDiagnostic] {
        var diagnostics: [ValidationDiagnostic] = []

        if game.rowStrategies.isEmpty {
            diagnostics.append(error(
                "decisionAnalysis.zeroSumGame.rowStrategies.empty",
                "zero-sum game row strategies must not be empty",
                path: "rowStrategies"
            ))
        }
        if game.columnStrategies.isEmpty {
            diagnostics.append(error(
                "decisionAnalysis.zeroSumGame.columnStrategies.empty",
                "zero-sum game column strategies must not be empty",
                path: "columnStrategies"
            ))
        }

        if Set(game.rowStrategies).count != game.rowStrategies.count {
            diagnostics.append(error(
                "decisionAnalysis.zeroSumGame.rowStrategies.duplicate",
                "zero-sum game row strategy names must be unique",
                path: "rowStrategies"
            ))
        }
        if Set(game.columnStrategies).count != game.columnStrategies.count {
            diagnostics.append(error(
                "decisionAnalysis.zeroSumGame.columnStrategies.duplicate",
                "zero-sum game column strategy names must be unique",
                path: "columnStrategies"
            ))
        }

        if game.payoffs.count != game.rowStrategies.count {
            diagnostics.append(error(
                "decisionAnalysis.zeroSumGame.payoffs.rows",
                "zero-sum game payoff row count must match row strategy count",
                path: "payoffs"
            ))
        }
        for (rowIndex, row) in game.payoffs.enumerated() where row.count != game.columnStrategies.count {
            diagnostics.append(error(
                "decisionAnalysis.zeroSumGame.payoffs.columns",
                "zero-sum game payoff column count must match column strategy count",
                path: payoffPath(game: game, rowIndex: rowIndex)
            ))
        }
        for (rowIndex, row) in game.payoffs.enumerated() {
            for (columnIndex, value) in row.enumerated() where value.isFinite == false {
                diagnostics.append(error(
                    "decisionAnalysis.zeroSumGame.payoffs.finite",
                    "zero-sum game payoffs must be finite",
                    path: payoffPath(game: game, rowIndex: rowIndex, columnIndex: columnIndex)
                ))
            }
        }

        guard diagnostics.contains(where: { $0.severity == .error }) == false else {
            return diagnostics
        }

        return diagnostics + [
            ValidationDiagnostic(
                severity: .info,
                code: "decisionAnalysis.zeroSumGame.valid",
                message: "Zero-sum game model is valid"
            )
        ]
    }

    public static func validate(_ game: ZeroSumGame) throws {
        if let diagnostic = diagnostics(for: game).first(where: { $0.severity == .error }) {
            throw DecisionAnalysisModelError.invalidModel(diagnostic.message)
        }
    }

    private static func error(_ code: String, _ message: String, path: String?) -> ValidationDiagnostic {
        ValidationDiagnostic(severity: .error, code: code, message: message, path: path)
    }

    private static func payoffPath(
        game: ZeroSumGame,
        rowIndex: Int,
        columnIndex: Int? = nil
    ) -> String {
        let row = rowIndex < game.rowStrategies.count ? game.rowStrategies[rowIndex] : "\(rowIndex)"
        guard let columnIndex else {
            return "payoffs.\(row)"
        }
        let column = columnIndex < game.columnStrategies.count ? game.columnStrategies[columnIndex] : "\(columnIndex)"
        return "payoffs.\(row).\(column)"
    }
}

public enum DecisionTreeNodeKind: String, Codable, Sendable {
    case decision
    case chance
    case terminal
}

public struct DecisionTreeNode: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let kind: DecisionTreeNodeKind
    public let childIDs: [Int]
    public let payoff: Double?
    public let probability: Double?

    public init(
        id: Int,
        name: String,
        kind: DecisionTreeNodeKind,
        childIDs: [Int],
        payoff: Double? = nil,
        probability: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.childIDs = childIDs
        self.payoff = payoff
        self.probability = probability
    }
}

public struct DecisionTree: Codable, Equatable, Sendable {
    public let title: String
    public let rootID: Int
    public let nodes: [DecisionTreeNode]

    public init(title: String, rootID: Int, nodes: [DecisionTreeNode]) {
        self.title = title
        self.rootID = rootID
        self.nodes = nodes
    }
}

public struct DecisionTreeNodeValue: Codable, Equatable, Sendable {
    public let nodeID: Int
    public let nodeName: String
    public let expectedValue: Double
    public let selectedChildID: Int?
    public let selectedChildName: String?
}

public struct DecisionTreePolicyDecision: Codable, Equatable, Sendable {
    public let nodeID: Int
    public let nodeName: String
    public let selectedChildID: Int
    public let selectedChildName: String
    public let expectedValue: Double
}

public struct DecisionTreeSolution: Codable, Equatable, Sendable {
    public let expectedValue: Double
    public let nodeValues: [DecisionTreeNodeValue]
    public let policy: [DecisionTreePolicyDecision]
}

public enum DecisionAnalysisModelError: Error, CustomStringConvertible {
    case unsupportedFormat
    case invalidNumericValue(String)
    case invalidModel(String)

    public var description: String {
        switch self {
        case .unsupportedFormat:
            "Unsupported decision analysis model format"
        case .invalidNumericValue(let value):
            "Invalid numeric value: \(value)"
        case .invalidModel(let detail):
            "Invalid decision analysis model: \(detail)"
        }
    }
}

public enum WinQSBDecisionAnalysisParser {
    public static func parseDecisionTree(from data: Data) throws -> DecisionTree {
        let lines = try tabularLines(from: data)

        guard let metadata = lines.first,
              metadata.count >= 4,
              metadata[0] == "DA",
              metadata[2] == "DT",
              let nodeCount = Int(metadata[3]),
              nodeCount > 0,
              lines.count >= nodeCount + 2
        else {
            throw DecisionAnalysisModelError.unsupportedFormat
        }

        let nodes = try lines[2..<(2 + nodeCount)].map { row -> DecisionTreeNode in
            guard row.count >= 6, let id = Int(row[0]) else {
                throw DecisionAnalysisModelError.unsupportedFormat
            }
            let childIDs = try parseChildIDs(row[3])
            let kind = try parseNodeKind(row[2], hasChildren: !childIDs.isEmpty)
            return DecisionTreeNode(
                id: id,
                name: row[1],
                kind: kind,
                childIDs: childIDs,
                payoff: try optionalDouble(row[4]),
                probability: try optionalDouble(row[5])
            )
        }

        guard let rootID = nodes.first?.id else {
            throw DecisionAnalysisModelError.unsupportedFormat
        }
        return DecisionTree(title: metadata[1], rootID: rootID, nodes: nodes)
    }

    public static func parseBayesianAnalysis(from data: Data) throws -> BayesianAnalysisProblem {
        let lines = try tabularLines(from: data)

        guard let metadata = lines.first,
              metadata.count >= 5,
              metadata[0] == "DA",
              metadata[2] == "BA",
              let stateCount = Int(metadata[3]),
              let outcomeCount = Int(metadata[4]),
              stateCount > 0,
              outcomeCount > 0,
              lines.count >= outcomeCount + 3
        else {
            throw DecisionAnalysisModelError.unsupportedFormat
        }

        let header = lines[1]
        guard header.count >= stateCount + 1 else {
            throw DecisionAnalysisModelError.unsupportedFormat
        }
        let states = Array(header[1...stateCount])

        let priorRow = lines[2]
        guard priorRow.count >= stateCount + 1,
              priorRow[0].lowercased() == "prior probability"
        else {
            throw DecisionAnalysisModelError.unsupportedFormat
        }
        let priorProbabilities = try priorRow[1...stateCount].map(parseDouble)

        var outcomes: [String] = []
        var likelihoods: [[Double]] = []
        for rowIndex in 0..<outcomeCount {
            let row = lines[3 + rowIndex]
            guard row.count >= stateCount + 1 else {
                throw DecisionAnalysisModelError.unsupportedFormat
            }
            outcomes.append(row[0])
            likelihoods.append(try row[1...stateCount].map(parseDouble))
        }

        return BayesianAnalysisProblem(
            title: metadata[1],
            states: states,
            priorProbabilities: priorProbabilities,
            outcomes: outcomes,
            likelihoods: likelihoods
        )
    }

    public static func parsePayoff(from data: Data) throws -> DecisionPayoffProblem {
        let lines = try tabularLines(from: data)

        guard let metadata = lines.first,
              metadata.count >= 6,
              metadata[0] == "DA",
              metadata[2] == "PT",
              let stateCount = Int(metadata[3]),
              let indicatorCount = Int(metadata[4]),
              let decisionCount = Int(metadata[5]),
              stateCount > 0,
              indicatorCount > 0,
              decisionCount > 0,
              lines.count >= 3 + indicatorCount + decisionCount
        else {
            throw DecisionAnalysisModelError.unsupportedFormat
        }

        let header = lines[1]
        guard header.count >= stateCount + 1 else {
            throw DecisionAnalysisModelError.unsupportedFormat
        }
        let states = Array(header[1...stateCount])

        let priorRow = lines[2]
        guard priorRow.count >= stateCount + 1,
              priorRow[0].lowercased() == "prior probability"
        else {
            throw DecisionAnalysisModelError.unsupportedFormat
        }
        let priorProbabilities = try priorRow[1...stateCount].map(parseDouble)

        var indicators: [String] = []
        var indicatorLikelihoods: [[Double]] = []
        for rowIndex in 0..<indicatorCount {
            let row = lines[3 + rowIndex]
            guard row.count >= stateCount + 1 else {
                throw DecisionAnalysisModelError.unsupportedFormat
            }
            indicators.append(row[0])
            indicatorLikelihoods.append(try row[1...stateCount].map(parseDouble))
        }

        var decisions: [String] = []
        var payoffs: [[Double]] = []
        for rowIndex in 0..<decisionCount {
            let row = lines[3 + indicatorCount + rowIndex]
            guard row.count >= stateCount + 1 else {
                throw DecisionAnalysisModelError.unsupportedFormat
            }
            decisions.append(row[0])
            payoffs.append(try row[1...stateCount].map(parseDouble))
        }

        return DecisionPayoffProblem(
            title: metadata[1],
            states: states,
            priorProbabilities: priorProbabilities,
            indicators: indicators,
            indicatorLikelihoods: indicatorLikelihoods,
            decisions: decisions,
            payoffs: payoffs
        )
    }

    public static func parseZeroSumGame(from data: Data) throws -> ZeroSumGame {
        let lines = try tabularLines(from: data)

        guard let metadata = lines.first,
              metadata.count >= 5,
              metadata[0] == "DA",
              metadata[2] == "ZS",
              let rowCount = Int(metadata[3]),
              let columnCount = Int(metadata[4]),
              rowCount > 0,
              columnCount > 0,
              lines.count >= rowCount + 2
        else {
            throw DecisionAnalysisModelError.unsupportedFormat
        }

        let header = lines[1]
        guard header.count >= columnCount + 1 else {
            throw DecisionAnalysisModelError.unsupportedFormat
        }
        let columnStrategies = Array(header[1...columnCount])

        var rowStrategies: [String] = []
        var payoffs: [[Double]] = []
        for rowIndex in 0..<rowCount {
            let row = lines[2 + rowIndex]
            guard row.count >= columnCount + 1 else {
                throw DecisionAnalysisModelError.unsupportedFormat
            }
            rowStrategies.append(row[0])
            payoffs.append(try row[1...columnCount].map(parseDouble))
        }

        return ZeroSumGame(
            title: metadata[1],
            rowStrategies: rowStrategies,
            columnStrategies: columnStrategies,
            payoffs: payoffs
        )
    }

    private static func tabularLines(from data: Data) throws -> [[String]] {
        guard let text = String(data: data, encoding: .isoLatin1) else {
            throw DecisionAnalysisModelError.unsupportedFormat
        }

        return text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(clean) }
    }

    private static func parseChildIDs(_ value: String) throws -> [Int] {
        guard !value.isEmpty else {
            return []
        }
        return try value.split(separator: ",").map { piece in
            let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let id = Int(trimmed) else {
                throw DecisionAnalysisModelError.unsupportedFormat
            }
            return id
        }
    }

    private static func parseNodeKind(_ value: String, hasChildren: Bool) throws -> DecisionTreeNodeKind {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty {
            return hasChildren ? .chance : .terminal
        }
        if normalized.hasPrefix("d") {
            return .decision
        }
        if normalized.hasPrefix("c") {
            return .chance
        }
        throw DecisionAnalysisModelError.unsupportedFormat
    }

    private static func parseDouble(_ value: String) throws -> Double {
        guard let number = Double(value), number.isFinite else {
            throw DecisionAnalysisModelError.invalidNumericValue(value)
        }
        return number
    }

    private static func optionalDouble(_ value: String) throws -> Double? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return nil
        }
        return try parseDouble(normalized)
    }

    private static func clean(_ value: Substring) -> String {
        String(value).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum BayesianAnalysisSolver {
    public static func solve(_ problem: BayesianAnalysisProblem) throws -> BayesianAnalysisSolution {
        try validate(problem)

        let outcomes = try problem.outcomes.indices.map { outcomeIndex in
            let likelihoods = problem.likelihoods[outcomeIndex]
            let probability = zip(problem.priorProbabilities, likelihoods).reduce(0.0) { partial, pair in
                partial + pair.0 * pair.1
            }
            guard probability > 1e-12 else {
                throw DecisionAnalysisModelError.invalidModel("outcome probabilities must be positive")
            }
            let posterior = zip(problem.priorProbabilities, likelihoods).map {
                $0.0 * $0.1 / probability
            }
            return BayesianOutcomeAnalysis(
                outcome: problem.outcomes[outcomeIndex],
                probability: probability,
                posteriorProbabilities: posterior
            )
        }

        return BayesianAnalysisSolution(outcomes: outcomes)
    }

    private static func validate(_ problem: BayesianAnalysisProblem) throws {
        let stateCount = problem.states.count
        guard stateCount > 0,
              problem.priorProbabilities.count == stateCount,
              !problem.outcomes.isEmpty,
              problem.likelihoods.count == problem.outcomes.count
        else {
            throw DecisionAnalysisModelError.invalidModel("Bayesian analysis dimensions are inconsistent")
        }
        guard abs(problem.priorProbabilities.reduce(0, +) - 1) < 1e-8,
              problem.priorProbabilities.allSatisfy({ $0 >= 0 && $0.isFinite })
        else {
            throw DecisionAnalysisModelError.invalidModel("prior probabilities must be nonnegative and sum to 1")
        }
        for likelihoods in problem.likelihoods {
            guard likelihoods.count == stateCount,
                  likelihoods.allSatisfy({ $0 >= 0 && $0.isFinite })
            else {
                throw DecisionAnalysisModelError.invalidModel("likelihood rows must match states")
            }
        }
        for stateIndex in 0..<stateCount {
            let columnTotal = problem.likelihoods.reduce(0.0) { $0 + $1[stateIndex] }
            guard abs(columnTotal - 1) < 1e-8 else {
                throw DecisionAnalysisModelError.invalidModel("likelihoods must sum to 1 for each state")
            }
        }
    }
}

public enum DecisionTreeSolver {
    private struct EvaluatedNode {
        let value: Double
        let selectedChildID: Int?
        let selectedChildName: String?
    }

    public static func solve(_ tree: DecisionTree) throws -> DecisionTreeSolution {
        let nodesByID = try validate(tree)
        var memo: [Int: EvaluatedNode] = [:]
        var visiting: Set<Int> = []
        let expectedValue = try evaluate(
            nodeID: tree.rootID,
            nodesByID: nodesByID,
            memo: &memo,
            visiting: &visiting
        ).value

        let sortedNodes = tree.nodes.sorted { $0.id < $1.id }
        let nodeValues = sortedNodes.compactMap { node -> DecisionTreeNodeValue? in
            guard let evaluated = memo[node.id] else { return nil }
            return DecisionTreeNodeValue(
                nodeID: node.id,
                nodeName: node.name,
                expectedValue: evaluated.value,
                selectedChildID: evaluated.selectedChildID,
                selectedChildName: evaluated.selectedChildName
            )
        }
        let policy = nodeValues.compactMap { value -> DecisionTreePolicyDecision? in
            guard let selectedChildID = value.selectedChildID,
                  let selectedChildName = value.selectedChildName else {
                return nil
            }
            return DecisionTreePolicyDecision(
                nodeID: value.nodeID,
                nodeName: value.nodeName,
                selectedChildID: selectedChildID,
                selectedChildName: selectedChildName,
                expectedValue: value.expectedValue
            )
        }

        return DecisionTreeSolution(
            expectedValue: expectedValue,
            nodeValues: nodeValues,
            policy: policy
        )
    }

    private static func evaluate(
        nodeID: Int,
        nodesByID: [Int: DecisionTreeNode],
        memo: inout [Int: EvaluatedNode],
        visiting: inout Set<Int>
    ) throws -> EvaluatedNode {
        if let cached = memo[nodeID] {
            return cached
        }
        guard !visiting.contains(nodeID) else {
            throw DecisionAnalysisModelError.invalidModel("decision tree must not contain cycles")
        }
        guard let node = nodesByID[nodeID] else {
            throw DecisionAnalysisModelError.invalidModel("decision tree references missing node \(nodeID)")
        }

        visiting.insert(nodeID)
        let payoff = node.payoff ?? 0
        let evaluated: EvaluatedNode
        switch node.kind {
        case .terminal:
            guard node.childIDs.isEmpty, let terminalPayoff = node.payoff else {
                throw DecisionAnalysisModelError.invalidModel("terminal decision tree nodes must have payoff and no children")
            }
            evaluated = EvaluatedNode(
                value: terminalPayoff,
                selectedChildID: nil,
                selectedChildName: nil
            )
        case .chance:
            guard !node.childIDs.isEmpty else {
                throw DecisionAnalysisModelError.invalidModel("chance nodes must have children")
            }
            let childProbabilities = try node.childIDs.map { childID -> Double in
                guard let probability = nodesByID[childID]?.probability,
                      probability >= 0,
                      probability.isFinite
                else {
                    throw DecisionAnalysisModelError.invalidModel("chance-node children must have nonnegative probabilities")
                }
                return probability
            }
            let totalProbability = childProbabilities.reduce(0, +)
            guard totalProbability > 1e-12 else {
                throw DecisionAnalysisModelError.invalidModel("chance-node probabilities must sum to a positive value")
            }
            let expectedValue = try zip(node.childIDs, childProbabilities).reduce(0.0) { partial, pair in
                let childValue = try evaluate(
                    nodeID: pair.0,
                    nodesByID: nodesByID,
                    memo: &memo,
                    visiting: &visiting
                ).value
                return partial + pair.1 / totalProbability * childValue
            }
            evaluated = EvaluatedNode(
                value: payoff + expectedValue,
                selectedChildID: nil,
                selectedChildName: nil
            )
        case .decision:
            guard !node.childIDs.isEmpty else {
                throw DecisionAnalysisModelError.invalidModel("decision nodes must have choices")
            }
            var bestChildID: Int?
            var bestChildName: String?
            var bestValue = -Double.infinity
            for childID in node.childIDs {
                guard let child = nodesByID[childID] else {
                    throw DecisionAnalysisModelError.invalidModel("decision tree references missing node \(childID)")
                }
                let childValue = try evaluate(
                    nodeID: childID,
                    nodesByID: nodesByID,
                    memo: &memo,
                    visiting: &visiting
                ).value
                if childValue > bestValue + 1e-9 {
                    bestValue = childValue
                    bestChildID = childID
                    bestChildName = child.name
                }
            }
            evaluated = EvaluatedNode(
                value: payoff + bestValue,
                selectedChildID: bestChildID,
                selectedChildName: bestChildName
            )
        }
        visiting.remove(nodeID)
        memo[nodeID] = evaluated
        return evaluated
    }

    private static func validate(_ tree: DecisionTree) throws -> [Int: DecisionTreeNode] {
        guard !tree.nodes.isEmpty else {
            throw DecisionAnalysisModelError.invalidModel("decision tree must contain nodes")
        }
        var nodesByID: [Int: DecisionTreeNode] = [:]
        for node in tree.nodes {
            guard !node.name.isEmpty || node.kind == .terminal else {
                throw DecisionAnalysisModelError.invalidModel("decision tree nonterminal nodes must have names")
            }
            guard nodesByID[node.id] == nil else {
                throw DecisionAnalysisModelError.invalidModel("decision tree node ids must be unique")
            }
            guard node.payoff.map({ $0.isFinite }) ?? true,
                  node.probability.map({ $0 >= 0 && $0.isFinite }) ?? true
            else {
                throw DecisionAnalysisModelError.invalidModel("decision tree payoff and probability values must be finite")
            }
            nodesByID[node.id] = node
        }
        guard nodesByID[tree.rootID] != nil else {
            throw DecisionAnalysisModelError.invalidModel("decision tree root node is missing")
        }
        for node in tree.nodes {
            for childID in node.childIDs {
                guard nodesByID[childID] != nil else {
                    throw DecisionAnalysisModelError.invalidModel("decision tree references missing node \(childID)")
                }
            }
        }
        return nodesByID
    }
}

public enum ZeroSumGameSolver {
    public static func solve(
        _ game: ZeroSumGame,
        linearProgrammingBackend: any LinearProgrammingBackend = NativeEducationalLinearProgrammingBackend()
    ) throws -> ZeroSumGameSolution {
        try ZeroSumGameValidator.validate(game)

        let minimumPayoff = game.payoffs.flatMap { $0 }.min() ?? 0
        let shift = max(0, -minimumPayoff + 1)
        let shiftedPayoffs = game.payoffs.map { row in
            row.map { $0 + shift }
        }

        let rowProgram = rowPlayerProgram(game: game, shiftedPayoffs: shiftedPayoffs)
        let rowSolution = try linearProgrammingBackend.solve(rowProgram, mode: .continuous)
        let columnProgram = columnPlayerProgram(game: game, shiftedPayoffs: shiftedPayoffs)
        let columnSolution = try linearProgrammingBackend.solve(columnProgram, mode: .continuous)

        let rowStrategy = game.rowStrategies.map { strategy in
            StrategyProbability(
                strategy: strategy,
                probability: cleanedProbability(rowSolution.variableValues["p_\(strategy)"] ?? 0)
            )
        }
        let columnStrategy = game.columnStrategies.map { strategy in
            StrategyProbability(
                strategy: strategy,
                probability: cleanedProbability(columnSolution.variableValues["q_\(strategy)"] ?? 0)
            )
        }

        return ZeroSumGameSolution(
            value: rowSolution.objectiveValue - shift,
            rowStrategy: rowStrategy,
            columnStrategy: columnStrategy
        )
    }

    private static func rowPlayerProgram(game: ZeroSumGame, shiftedPayoffs: [[Double]]) -> LinearProgram {
        let probabilityVariables = game.rowStrategies.map { "p_\($0)" }
        let valueVariable = "shiftedValue"
        let variableNames = probabilityVariables + [valueVariable]
        let objective = Array(repeating: 0.0, count: probabilityVariables.count) + [1]

        var constraints: [LinearConstraint] = [
            LinearConstraint(
                name: "probability_sum",
                coefficients: Array(repeating: 1.0, count: probabilityVariables.count) + [0],
                relation: .equal,
                rhs: 1
            )
        ]

        for columnIndex in game.columnStrategies.indices {
            let coefficients = shiftedPayoffs.map { $0[columnIndex] } + [-1]
            constraints.append(LinearConstraint(
                name: "column_\(game.columnStrategies[columnIndex])",
                coefficients: coefficients,
                relation: .greaterThanOrEqual,
                rhs: 0
            ))
        }

        return LinearProgram(
            title: game.title,
            sense: .maximize,
            variableNames: variableNames,
            objectiveCoefficients: objective,
            constraints: constraints
        )
    }

    private static func columnPlayerProgram(game: ZeroSumGame, shiftedPayoffs: [[Double]]) -> LinearProgram {
        let probabilityVariables = game.columnStrategies.map { "q_\($0)" }
        let valueVariable = "shiftedValue"
        let variableNames = probabilityVariables + [valueVariable]
        let objective = Array(repeating: 0.0, count: probabilityVariables.count) + [1]

        var constraints: [LinearConstraint] = [
            LinearConstraint(
                name: "probability_sum",
                coefficients: Array(repeating: 1.0, count: probabilityVariables.count) + [0],
                relation: .equal,
                rhs: 1
            )
        ]

        for rowIndex in game.rowStrategies.indices {
            let coefficients = shiftedPayoffs[rowIndex] + [-1]
            constraints.append(LinearConstraint(
                name: "row_\(game.rowStrategies[rowIndex])",
                coefficients: coefficients,
                relation: .lessThanOrEqual,
                rhs: 0
            ))
        }

        return LinearProgram(
            title: game.title,
            sense: .minimize,
            variableNames: variableNames,
            objectiveCoefficients: objective,
            constraints: constraints
        )
    }

    private static func cleanedProbability(_ value: Double) -> Double {
        abs(value) < 1e-9 ? 0 : value
    }
}

public enum DecisionPayoffSolver {
    public static func solve(_ problem: DecisionPayoffProblem) throws -> DecisionPayoffSolution {
        try validate(problem)

        let priorExpectedValues = expectedValues(probabilities: problem.priorProbabilities, problem: problem)
        let bestPrior = best(priorExpectedValues)

        var indicatorAnalyses: [IndicatorDecisionAnalysis] = []
        var expectedValueWithSampleInformation = 0.0

        for indicatorIndex in problem.indicators.indices {
            let likelihoods = problem.indicatorLikelihoods[indicatorIndex]
            let indicatorProbability = zip(problem.priorProbabilities, likelihoods).reduce(0.0) { partial, pair in
                partial + pair.0 * pair.1
            }
            guard indicatorProbability > 1e-12 else {
                throw DecisionAnalysisModelError.invalidModel("indicator probabilities must be positive")
            }
            let posterior = zip(problem.priorProbabilities, likelihoods).map {
                $0.0 * $0.1 / indicatorProbability
            }
            let posteriorExpectedValues = expectedValues(probabilities: posterior, problem: problem)
            let posteriorBest = best(posteriorExpectedValues)
            expectedValueWithSampleInformation += indicatorProbability * posteriorBest.expectedValue

            indicatorAnalyses.append(IndicatorDecisionAnalysis(
                indicator: problem.indicators[indicatorIndex],
                probability: indicatorProbability,
                posteriorProbabilities: posterior,
                expectedValues: posteriorExpectedValues,
                bestDecision: posteriorBest.decision,
                bestExpectedValue: posteriorBest.expectedValue
            ))
        }

        let expectedValueWithPerfectInformation = problem.states.indices.reduce(0.0) { partial, stateIndex in
            let bestPayoff = problem.payoffs.map { $0[stateIndex] }.max() ?? 0
            return partial + problem.priorProbabilities[stateIndex] * bestPayoff
        }

        return DecisionPayoffSolution(
            priorExpectedValues: priorExpectedValues,
            bestPriorDecision: bestPrior.decision,
            bestPriorExpectedValue: bestPrior.expectedValue,
            indicatorAnalyses: indicatorAnalyses,
            expectedValueWithSampleInformation: expectedValueWithSampleInformation,
            expectedValueOfSampleInformation: expectedValueWithSampleInformation - bestPrior.expectedValue,
            expectedValueWithPerfectInformation: expectedValueWithPerfectInformation,
            expectedValueOfPerfectInformation: expectedValueWithPerfectInformation - bestPrior.expectedValue
        )
    }

    private static func validate(_ problem: DecisionPayoffProblem) throws {
        let stateCount = problem.states.count
        guard stateCount > 0,
              problem.priorProbabilities.count == stateCount,
              !problem.indicators.isEmpty,
              problem.indicatorLikelihoods.count == problem.indicators.count,
              !problem.decisions.isEmpty,
              problem.payoffs.count == problem.decisions.count
        else {
            throw DecisionAnalysisModelError.invalidModel("decision payoff dimensions are inconsistent")
        }
        guard abs(problem.priorProbabilities.reduce(0, +) - 1) < 1e-8,
              problem.priorProbabilities.allSatisfy({ $0 >= 0 && $0.isFinite })
        else {
            throw DecisionAnalysisModelError.invalidModel("prior probabilities must be nonnegative and sum to 1")
        }
        for likelihoods in problem.indicatorLikelihoods {
            guard likelihoods.count == stateCount,
                  likelihoods.allSatisfy({ $0 >= 0 && $0.isFinite })
            else {
                throw DecisionAnalysisModelError.invalidModel("indicator likelihood rows must match states")
            }
        }
        for stateIndex in 0..<stateCount {
            let columnTotal = problem.indicatorLikelihoods.reduce(0.0) { $0 + $1[stateIndex] }
            guard abs(columnTotal - 1) < 1e-8 else {
                throw DecisionAnalysisModelError.invalidModel("indicator likelihoods must sum to 1 for each state")
            }
        }
        for payoffs in problem.payoffs {
            guard payoffs.count == stateCount,
                  payoffs.allSatisfy(\.isFinite)
            else {
                throw DecisionAnalysisModelError.invalidModel("payoff rows must match states")
            }
        }
    }

    private static func expectedValues(
        probabilities: [Double],
        problem: DecisionPayoffProblem
    ) -> [DecisionExpectedValue] {
        problem.decisions.indices.map { decisionIndex in
            DecisionExpectedValue(
                decision: problem.decisions[decisionIndex],
                expectedValue: zip(probabilities, problem.payoffs[decisionIndex]).reduce(0.0) {
                    $0 + $1.0 * $1.1
                }
            )
        }
    }

    private static func best(_ expectedValues: [DecisionExpectedValue]) -> DecisionExpectedValue {
        expectedValues.max {
            if abs($0.expectedValue - $1.expectedValue) > 1e-9 {
                return $0.expectedValue < $1.expectedValue
            }
            return $0.decision > $1.decision
        }!
    }
}
