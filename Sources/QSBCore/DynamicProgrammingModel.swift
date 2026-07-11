import Foundation

public struct KnapsackItem: Codable, Equatable, Sendable {
    public let name: String
    public let available: Int
    public let capacityRequired: Int
    public let returnPerUnit: Double

    public init(name: String, available: Int, capacityRequired: Int, returnPerUnit: Double) {
        self.name = name
        self.available = available
        self.capacityRequired = capacityRequired
        self.returnPerUnit = returnPerUnit
    }
}

public struct KnapsackProblem: Codable, Equatable, Sendable {
    public let title: String
    public let capacity: Int
    public let items: [KnapsackItem]

    public init(title: String, capacity: Int, items: [KnapsackItem]) {
        self.title = title
        self.capacity = capacity
        self.items = items
    }
}

public struct KnapsackSelection: Codable, Equatable, Sendable {
    public let item: String
    public let quantity: Int
    public let capacityUsed: Int
    public let returnValue: Double
}

public struct KnapsackSolution: Codable, Equatable, Sendable {
    public let totalReturn: Double
    public let capacityUsed: Int
    public let selections: [KnapsackSelection]
}

public struct StagecoachArc: Codable, Equatable, Sendable {
    public let from: String
    public let to: String
    public let cost: Double

    public init(from: String, to: String, cost: Double) {
        self.from = from
        self.to = to
        self.cost = cost
    }
}

public struct StagecoachProblem: Codable, Equatable, Sendable {
    public let title: String
    public let nodes: [String]
    public let arcs: [StagecoachArc]

    public init(title: String, nodes: [String], arcs: [StagecoachArc]) {
        self.title = title
        self.nodes = nodes
        self.arcs = arcs
    }
}

public struct StagecoachSolution: Codable, Equatable, Sendable {
    public let source: String
    public let sink: String
    public let totalCost: Double
    public let path: [String]
}

public struct ProductionInventoryPeriod: Codable, Equatable, Sendable {
    public let name: String
    public let demand: Int
    public let productionCapacity: Int
    public let storageCapacity: Int
    public let setupCost: Double
    public let productionUnitCost: Double
    public let holdingUnitCost: Double

    public init(
        name: String,
        demand: Int,
        productionCapacity: Int,
        storageCapacity: Int,
        setupCost: Double,
        productionUnitCost: Double,
        holdingUnitCost: Double
    ) {
        self.name = name
        self.demand = demand
        self.productionCapacity = productionCapacity
        self.storageCapacity = storageCapacity
        self.setupCost = setupCost
        self.productionUnitCost = productionUnitCost
        self.holdingUnitCost = holdingUnitCost
    }
}

public struct ProductionInventoryProblem: Codable, Equatable, Sendable {
    public let title: String
    public let periods: [ProductionInventoryPeriod]

    public init(title: String, periods: [ProductionInventoryPeriod]) {
        self.title = title
        self.periods = periods
    }
}

public struct ProductionInventoryDecision: Codable, Equatable, Sendable {
    public let period: String
    public let beginningInventory: Int
    public let productionQuantity: Int
    public let demand: Int
    public let endingInventory: Int
    public let cost: Double
}

public struct ProductionInventorySolution: Codable, Equatable, Sendable {
    public let totalCost: Double
    public let decisions: [ProductionInventoryDecision]
}

public enum DynamicProgrammingModelError: Error, CustomStringConvertible {
    case unsupportedFormat
    case invalidNumericValue(String)
    case invalidModel(String)

    public var description: String {
        switch self {
        case .unsupportedFormat:
            "Unsupported dynamic programming model format"
        case .invalidNumericValue(let value):
            "Invalid numeric value: \(value)"
        case .invalidModel(let detail):
            "Invalid dynamic programming model: \(detail)"
        }
    }
}

public enum WinQSBDynamicProgrammingParser {
    public static func parseProductionInventory(from data: Data) throws -> ProductionInventoryProblem {
        guard let text = String(data: data, encoding: .isoLatin1) else {
            throw DynamicProgrammingModelError.unsupportedFormat
        }

        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(clean) }

        guard let metadata = lines.first,
              metadata.count >= 4,
              metadata[0] == "DP",
              metadata[2] == "PIS",
              let periodCount = Int(metadata[3]),
              periodCount > 0,
              lines.count >= periodCount + 2
        else {
            throw DynamicProgrammingModelError.unsupportedFormat
        }

        let periods = try lines[2..<(2 + periodCount)].map { row in
            guard row.count >= 7,
                  let demand = Int(row[2]),
                  let productionCapacity = Int(row[3]),
                  let storageCapacity = Int(row[4]),
                  let setupCost = Double(row[5])
            else {
                throw DynamicProgrammingModelError.unsupportedFormat
            }
            let costs = try parseProductionInventoryCost(row[6])
            return ProductionInventoryPeriod(
                name: row[1],
                demand: demand,
                productionCapacity: productionCapacity,
                storageCapacity: storageCapacity,
                setupCost: setupCost,
                productionUnitCost: costs.production,
                holdingUnitCost: costs.holding
            )
        }

        return ProductionInventoryProblem(title: metadata[1], periods: periods)
    }

    public static func parseStagecoach(from data: Data) throws -> StagecoachProblem {
        guard let text = String(data: data, encoding: .isoLatin1) else {
            throw DynamicProgrammingModelError.unsupportedFormat
        }

        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(clean) }

        guard let metadata = lines.first,
              metadata.count >= 4,
              metadata[0] == "DP",
              metadata[2] == "SC",
              let nodeCount = Int(metadata[3]),
              nodeCount > 1,
              lines.count >= nodeCount + 2
        else {
            throw DynamicProgrammingModelError.unsupportedFormat
        }

        let header = lines[1]
        guard header.count >= nodeCount + 1 else {
            throw DynamicProgrammingModelError.unsupportedFormat
        }
        let nodes = Array(header[1...nodeCount])

        var arcs: [StagecoachArc] = []
        for rowIndex in 0..<nodeCount {
            let row = lines[2 + rowIndex]
            guard row.count >= nodeCount + 1 else {
                throw DynamicProgrammingModelError.unsupportedFormat
            }

            let from = row[0]
            for columnIndex in 0..<nodeCount {
                let rawCost = row[columnIndex + 1]
                guard !rawCost.isEmpty else { continue }
                guard let cost = Double(rawCost), cost.isFinite else {
                    throw DynamicProgrammingModelError.invalidNumericValue(rawCost)
                }
                arcs.append(StagecoachArc(from: from, to: nodes[columnIndex], cost: cost))
            }
        }

        return StagecoachProblem(title: metadata[1], nodes: nodes, arcs: arcs)
    }

    public static func parseKnapsack(from data: Data) throws -> KnapsackProblem {
        guard let text = String(data: data, encoding: .isoLatin1) else {
            throw DynamicProgrammingModelError.unsupportedFormat
        }

        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(clean) }

        guard let metadata = lines.first,
              metadata.count >= 4,
              metadata[0] == "DP",
              metadata[2] == "KS",
              let itemCount = Int(metadata[3]),
              itemCount > 0,
              lines.count >= itemCount + 3
        else {
            throw DynamicProgrammingModelError.unsupportedFormat
        }

        let items = try lines[2..<(2 + itemCount)].map { row in
            guard row.count >= 5,
                  let available = Int(row[2]),
                  let capacityRequired = Int(row[3])
            else {
                throw DynamicProgrammingModelError.unsupportedFormat
            }
            return KnapsackItem(
                name: row[1],
                available: available,
                capacityRequired: capacityRequired,
                returnPerUnit: try parseReturnCoefficient(row[4])
            )
        }

        let capacityRow = lines[2 + itemCount]
        guard capacityRow.count >= 3,
              capacityRow[0].lowercased() == "knapsack",
              let capacity = Int(capacityRow[2])
        else {
            throw DynamicProgrammingModelError.unsupportedFormat
        }

        return KnapsackProblem(title: metadata[1], capacity: capacity, items: items)
    }

    private static func parseReturnCoefficient(_ value: String) throws -> Double {
        let prefix = value.prefix { character in
            character.isNumber || character == "." || character == "-"
        }
        guard !prefix.isEmpty, let number = Double(prefix), number.isFinite else {
            throw DynamicProgrammingModelError.invalidNumericValue(value)
        }
        return number
    }

    private static func parseProductionInventoryCost(_ value: String) throws -> (production: Double, holding: Double) {
        let parts = value.split(separator: "+").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2 else {
            throw DynamicProgrammingModelError.invalidNumericValue(value)
        }

        func coefficient(_ suffix: Character) throws -> Double {
            guard let part = parts.first(where: { $0.uppercased().hasSuffix(String(suffix)) }) else {
                throw DynamicProgrammingModelError.invalidNumericValue(value)
            }
            let numberText = part.dropLast()
            guard let number = Double(numberText), number.isFinite else {
                throw DynamicProgrammingModelError.invalidNumericValue(value)
            }
            return number
        }

        return (try coefficient("P"), try coefficient("H"))
    }

    private static func clean(_ value: Substring) -> String {
        String(value).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum ProductionInventorySolver {
    public static func solve(_ problem: ProductionInventoryProblem) throws -> ProductionInventorySolution {
        try validate(problem)

        let periodCount = problem.periods.count
        let maxInventory = problem.periods.map(\.storageCapacity).max() ?? 0
        let infeasible = Double.infinity
        var best = Array(
            repeating: Array(repeating: infeasible, count: maxInventory + 1),
            count: periodCount + 1
        )
        var bestProduction = Array(
            repeating: Array(repeating: -1, count: maxInventory + 1),
            count: periodCount
        )
        var nextInventory = Array(
            repeating: Array(repeating: -1, count: maxInventory + 1),
            count: periodCount
        )
        best[periodCount][0] = 0

        for periodIndex in stride(from: periodCount - 1, through: 0, by: -1) {
            let period = problem.periods[periodIndex]
            for beginningInventory in 0...maxInventory {
                var bestCost = infeasible
                var chosenProduction = -1
                var chosenEndingInventory = -1

                for production in 0...period.productionCapacity {
                    let endingInventory = beginningInventory + production - period.demand
                    guard endingInventory >= 0, endingInventory <= period.storageCapacity else { continue }
                    let productionCost = Double(production) * period.productionUnitCost
                    let holdingCost = Double(endingInventory) * period.holdingUnitCost
                    let setupCost = production > 0 ? period.setupCost : 0
                    let currentCost = productionCost + holdingCost + setupCost
                    let futureCost = best[periodIndex + 1][endingInventory]
                    guard futureCost.isFinite else { continue }
                    let candidate = currentCost + futureCost
                    if candidate < bestCost - 1e-9 {
                        bestCost = candidate
                        chosenProduction = production
                        chosenEndingInventory = endingInventory
                    }
                }

                best[periodIndex][beginningInventory] = bestCost
                bestProduction[periodIndex][beginningInventory] = chosenProduction
                nextInventory[periodIndex][beginningInventory] = chosenEndingInventory
            }
        }

        guard best[0][0].isFinite else {
            throw DynamicProgrammingModelError.invalidModel("no feasible production/inventory plan exists")
        }

        var decisions: [ProductionInventoryDecision] = []
        var inventory = 0
        for periodIndex in 0..<periodCount {
            let period = problem.periods[periodIndex]
            let production = bestProduction[periodIndex][inventory]
            let endingInventory = nextInventory[periodIndex][inventory]
            guard production >= 0, endingInventory >= 0 else {
                throw DynamicProgrammingModelError.invalidModel("could not reconstruct production/inventory plan")
            }
            let cost = Double(production) * period.productionUnitCost
                + Double(endingInventory) * period.holdingUnitCost
                + (production > 0 ? period.setupCost : 0)
            decisions.append(ProductionInventoryDecision(
                period: period.name,
                beginningInventory: inventory,
                productionQuantity: production,
                demand: period.demand,
                endingInventory: endingInventory,
                cost: cost
            ))
            inventory = endingInventory
        }

        return ProductionInventorySolution(totalCost: best[0][0], decisions: decisions)
    }

    private static func validate(_ problem: ProductionInventoryProblem) throws {
        guard !problem.periods.isEmpty else {
            throw DynamicProgrammingModelError.invalidModel("production/inventory periods must not be empty")
        }
        for period in problem.periods {
            guard !period.name.isEmpty,
                  period.demand >= 0,
                  period.productionCapacity >= 0,
                  period.storageCapacity >= 0,
                  period.setupCost >= 0,
                  period.productionUnitCost.isFinite,
                  period.productionUnitCost >= 0,
                  period.holdingUnitCost.isFinite,
                  period.holdingUnitCost >= 0
            else {
                throw DynamicProgrammingModelError.invalidModel("production/inventory period values must be valid")
            }
        }
    }
}

public enum StagecoachSolver {
    public static func solve(
        _ problem: StagecoachProblem,
        source: String? = nil,
        sink: String? = nil
    ) throws -> StagecoachSolution {
        try validate(problem)

        let source = source ?? problem.nodes[0]
        let sink = sink ?? problem.nodes[problem.nodes.count - 1]
        guard problem.nodes.contains(source), problem.nodes.contains(sink) else {
            throw DynamicProgrammingModelError.invalidModel("source and sink must exist in nodes")
        }

        let adjacency = Dictionary(grouping: problem.arcs, by: \.from)
        var distances = Dictionary(uniqueKeysWithValues: problem.nodes.map { ($0, Double.infinity) })
        var predecessors: [String: String] = [:]
        distances[source] = 0

        for node in problem.nodes {
            guard let currentDistance = distances[node], currentDistance.isFinite else { continue }
            for arc in adjacency[node, default: []] {
                let candidate = currentDistance + arc.cost
                if candidate < (distances[arc.to] ?? .infinity) {
                    distances[arc.to] = candidate
                    predecessors[arc.to] = node
                }
            }
        }

        guard let totalCost = distances[sink], totalCost.isFinite else {
            throw DynamicProgrammingModelError.invalidModel("no stagecoach route exists")
        }

        var path = [sink]
        var current = sink
        while current != source {
            guard let predecessor = predecessors[current] else {
                throw DynamicProgrammingModelError.invalidModel("could not reconstruct stagecoach route")
            }
            path.append(predecessor)
            current = predecessor
        }

        return StagecoachSolution(
            source: source,
            sink: sink,
            totalCost: totalCost,
            path: path.reversed()
        )
    }

    private static func validate(_ problem: StagecoachProblem) throws {
        guard problem.nodes.count > 1 else {
            throw DynamicProgrammingModelError.invalidModel("stagecoach model must contain at least two nodes")
        }
        guard Set(problem.nodes).count == problem.nodes.count else {
            throw DynamicProgrammingModelError.invalidModel("stagecoach node names must be unique")
        }
        let nodeSet = Set(problem.nodes)
        for arc in problem.arcs {
            guard nodeSet.contains(arc.from), nodeSet.contains(arc.to), arc.cost >= 0, arc.cost.isFinite else {
                throw DynamicProgrammingModelError.invalidModel("stagecoach arcs must reference valid nodes and nonnegative costs")
            }
        }
    }
}

public enum KnapsackSolver {
    public static func solve(_ problem: KnapsackProblem) throws -> KnapsackSolution {
        try validate(problem)

        let itemCount = problem.items.count
        var best = Array(
            repeating: Array(repeating: 0.0, count: problem.capacity + 1),
            count: itemCount + 1
        )
        var selectedQuantity = Array(
            repeating: Array(repeating: 0, count: problem.capacity + 1),
            count: itemCount + 1
        )

        for itemIndex in 1...itemCount {
            let item = problem.items[itemIndex - 1]
            for capacity in 0...problem.capacity {
                var bestValue = best[itemIndex - 1][capacity]
                var bestQuantity = 0
                let maxQuantity = min(item.available, capacity / item.capacityRequired)
                if maxQuantity > 0 {
                    for quantity in 1...maxQuantity {
                        let remainingCapacity = capacity - quantity * item.capacityRequired
                        let candidate = best[itemIndex - 1][remainingCapacity] + Double(quantity) * item.returnPerUnit
                        if candidate > bestValue + 1e-9 {
                            bestValue = candidate
                            bestQuantity = quantity
                        }
                    }
                }
                best[itemIndex][capacity] = bestValue
                selectedQuantity[itemIndex][capacity] = bestQuantity
            }
        }

        var remainingCapacity = problem.capacity
        var quantities = Array(repeating: 0, count: itemCount)
        for itemIndex in stride(from: itemCount, through: 1, by: -1) {
            let quantity = selectedQuantity[itemIndex][remainingCapacity]
            quantities[itemIndex - 1] = quantity
            remainingCapacity -= quantity * problem.items[itemIndex - 1].capacityRequired
        }

        let selections = quantities.enumerated().compactMap { index, quantity -> KnapsackSelection? in
            guard quantity > 0 else { return nil }
            let item = problem.items[index]
            return KnapsackSelection(
                item: item.name,
                quantity: quantity,
                capacityUsed: quantity * item.capacityRequired,
                returnValue: Double(quantity) * item.returnPerUnit
            )
        }
        let capacityUsed = selections.reduce(0) { $0 + $1.capacityUsed }

        return KnapsackSolution(
            totalReturn: best[itemCount][problem.capacity],
            capacityUsed: capacityUsed,
            selections: selections
        )
    }

    private static func validate(_ problem: KnapsackProblem) throws {
        guard problem.capacity > 0 else {
            throw DynamicProgrammingModelError.invalidModel("capacity must be positive")
        }
        guard !problem.items.isEmpty else {
            throw DynamicProgrammingModelError.invalidModel("items must not be empty")
        }
        for item in problem.items {
            guard !item.name.isEmpty,
                  item.available >= 0,
                  item.capacityRequired > 0,
                  item.returnPerUnit.isFinite
            else {
                throw DynamicProgrammingModelError.invalidModel("knapsack item values must be valid")
            }
        }
    }
}
