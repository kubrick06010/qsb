import Foundation

public struct NetworkArc: Codable, Equatable, Sendable {
    public let from: String
    public let to: String
    public let cost: Double
}

public struct ShortestPathNetwork: Codable, Equatable, Sendable {
    public let title: String
    public let nodes: [String]
    public let arcs: [NetworkArc]

    public init(title: String, nodes: [String], arcs: [NetworkArc]) {
        self.title = title
        self.nodes = nodes
        self.arcs = arcs
    }
}

public struct ShortestPathSolution: Codable, Equatable, Sendable {
    public let source: String
    public let sink: String
    public let totalCost: Double
    public let path: [String]
}

public struct MinimumSpanningTreeNetwork: Codable, Equatable, Sendable {
    public let title: String
    public let nodes: [String]
    public let edges: [NetworkArc]

    public init(title: String, nodes: [String], edges: [NetworkArc]) {
        self.title = title
        self.nodes = nodes
        self.edges = edges
    }
}

public struct MinimumSpanningTreeSolution: Codable, Equatable, Sendable {
    public let totalCost: Double
    public let edges: [NetworkArc]
}

public struct MaxFlowNetwork: Codable, Equatable, Sendable {
    public let title: String
    public let nodes: [String]
    public let arcs: [NetworkArc]

    public init(title: String, nodes: [String], arcs: [NetworkArc]) {
        self.title = title
        self.nodes = nodes
        self.arcs = arcs
    }
}

public struct MaxFlowArcFlow: Codable, Equatable, Sendable {
    public let from: String
    public let to: String
    public let flow: Double
}

public struct MaxFlowSolution: Codable, Equatable, Sendable {
    public let source: String
    public let sink: String
    public let maxFlow: Double
    public let arcFlows: [MaxFlowArcFlow]
}

public struct TravelingSalespersonProblem: Codable, Equatable, Sendable {
    public let title: String
    public let nodes: [String]
    public let arcs: [NetworkArc]

    public init(title: String, nodes: [String], arcs: [NetworkArc]) {
        self.title = title
        self.nodes = nodes
        self.arcs = arcs
    }
}

public struct TravelingSalespersonSolution: Codable, Equatable, Sendable {
    public let source: String
    public let totalCost: Double
    public let tour: [String]
}

public struct AssignmentProblem: Codable, Equatable, Sendable {
    public let title: String
    public let workers: [String]
    public let tasks: [String]
    public let costs: [[Double]]

    public init(title: String, workers: [String], tasks: [String], costs: [[Double]]) {
        self.title = title
        self.workers = workers
        self.tasks = tasks
        self.costs = costs
    }
}

public struct AssignmentPair: Codable, Equatable, Sendable {
    public let worker: String
    public let task: String
    public let cost: Double
}

public struct AssignmentSolution: Codable, Equatable, Sendable {
    public let totalCost: Double
    public let assignments: [AssignmentPair]
}

public struct TransportationProblem: Codable, Equatable, Sendable {
    public let title: String
    public let origins: [String]
    public let destinations: [String]
    public let costs: [[Double]]
    public let supply: [Double]
    public let demand: [Double]

    public init(
        title: String,
        origins: [String],
        destinations: [String],
        costs: [[Double]],
        supply: [Double],
        demand: [Double]
    ) {
        self.title = title
        self.origins = origins
        self.destinations = destinations
        self.costs = costs
        self.supply = supply
        self.demand = demand
    }
}

public struct TransportationShipment: Codable, Equatable, Sendable {
    public let origin: String
    public let destination: String
    public let quantity: Double
    public let unitCost: Double
}

public struct TransportationSolution: Codable, Equatable, Sendable {
    public let totalCost: Double
    public let shipments: [TransportationShipment]
}

public enum TransportationValidator {
    public static func diagnostics(for problem: TransportationProblem) -> [ValidationDiagnostic] {
        var diagnostics: [ValidationDiagnostic] = []

        if problem.origins.isEmpty {
            diagnostics.append(error(
                "network.transportation.origins.empty",
                "transportation origins must not be empty",
                path: "origins"
            ))
        }
        if problem.destinations.isEmpty {
            diagnostics.append(error(
                "network.transportation.destinations.empty",
                "transportation destinations must not be empty",
                path: "destinations"
            ))
        }

        if Set(problem.origins).count != problem.origins.count {
            diagnostics.append(error(
                "network.transportation.origins.duplicate",
                "transportation origin labels must be unique",
                path: "origins"
            ))
        }
        if Set(problem.destinations).count != problem.destinations.count {
            diagnostics.append(error(
                "network.transportation.destinations.duplicate",
                "transportation destination labels must be unique",
                path: "destinations"
            ))
        }

        if problem.supply.count != problem.origins.count {
            diagnostics.append(error(
                "network.transportation.supply.dimension",
                "transportation supply count must match origin count",
                path: "supply"
            ))
        }
        if problem.demand.count != problem.destinations.count {
            diagnostics.append(error(
                "network.transportation.demand.dimension",
                "transportation demand count must match destination count",
                path: "demand"
            ))
        }
        if problem.costs.count != problem.origins.count {
            diagnostics.append(error(
                "network.transportation.costs.rows",
                "transportation cost row count must match origin count",
                path: "costs"
            ))
        }
        for (originIndex, row) in problem.costs.enumerated() where row.count != problem.destinations.count {
            diagnostics.append(error(
                "network.transportation.costs.columns",
                "transportation cost column count must match destination count",
                path: costPath(problem: problem, originIndex: originIndex)
            ))
        }

        for (index, value) in problem.supply.enumerated() where value < 0 || value.isFinite == false {
            diagnostics.append(error(
                "network.transportation.supply.nonnegative",
                "transportation supply values must be finite and nonnegative",
                path: quantityPath(labels: problem.origins, prefix: "supply", index: index)
            ))
        }
        for (index, value) in problem.demand.enumerated() where value < 0 || value.isFinite == false {
            diagnostics.append(error(
                "network.transportation.demand.nonnegative",
                "transportation demand values must be finite and nonnegative",
                path: quantityPath(labels: problem.destinations, prefix: "demand", index: index)
            ))
        }
        for (originIndex, row) in problem.costs.enumerated() {
            for (destinationIndex, value) in row.enumerated() where value < 0 || value.isFinite == false {
                diagnostics.append(error(
                    "network.transportation.costs.nonnegative",
                    "transportation cost values must be finite and nonnegative",
                    path: costPath(problem: problem, originIndex: originIndex, destinationIndex: destinationIndex)
                ))
            }
        }

        if problem.supply.count == problem.origins.count,
           problem.demand.count == problem.destinations.count,
           problem.supply.allSatisfy(\.isFinite),
           problem.demand.allSatisfy(\.isFinite) {
            let totalSupply = problem.supply.reduce(0, +)
            let totalDemand = problem.demand.reduce(0, +)
            if abs(totalSupply - totalDemand) >= 1e-8 {
                diagnostics.append(error(
                    "network.transportation.balance",
                    "transportation supply must equal demand",
                    path: "supply,demand"
                ))
            }
        }

        guard diagnostics.contains(where: { $0.severity == .error }) == false else {
            return diagnostics
        }

        return diagnostics + [
            ValidationDiagnostic(
                severity: .info,
                code: "network.transportation.valid",
                message: "Transportation model is valid"
            )
        ]
    }

    public static func validate(_ problem: TransportationProblem) throws {
        if let diagnostic = diagnostics(for: problem).first(where: { $0.severity == .error }) {
            throw NetworkModelError.invalidNetwork(diagnostic.message)
        }
    }

    private static func error(_ code: String, _ message: String, path: String?) -> ValidationDiagnostic {
        ValidationDiagnostic(severity: .error, code: code, message: message, path: path)
    }

    private static func quantityPath(labels: [String], prefix: String, index: Int) -> String {
        guard index < labels.count else {
            return "\(prefix).\(index)"
        }
        return "\(prefix).\(labels[index])"
    }

    private static func costPath(
        problem: TransportationProblem,
        originIndex: Int,
        destinationIndex: Int? = nil
    ) -> String {
        let origin = originIndex < problem.origins.count ? problem.origins[originIndex] : "\(originIndex)"
        guard let destinationIndex else {
            return "costs.\(origin)"
        }
        let destination = destinationIndex < problem.destinations.count ? problem.destinations[destinationIndex] : "\(destinationIndex)"
        return "costs.\(origin).\(destination)"
    }
}

public enum NetworkProblemKind: String, Codable, Sendable {
    case shortestPath = "SPP"
    case minimumSpanningTree = "MST"
    case maxFlow = "MFP"
    case travelingSalesperson = "TSP"
    case assignment = "AP"
    case transportation = "TP"
}

public enum NetworkModelEnvelope: Equatable, Sendable {
    case shortestPath(ShortestPathNetwork)
    case minimumSpanningTree(MinimumSpanningTreeNetwork)
    case maxFlow(MaxFlowNetwork)
    case travelingSalesperson(TravelingSalespersonProblem)
    case assignment(AssignmentProblem)
    case transportation(TransportationProblem)

    public var kind: NetworkProblemKind {
        switch self {
        case .shortestPath:
            .shortestPath
        case .minimumSpanningTree:
            .minimumSpanningTree
        case .maxFlow:
            .maxFlow
        case .travelingSalesperson:
            .travelingSalesperson
        case .assignment:
            .assignment
        case .transportation:
            .transportation
        }
    }
}

public enum NetworkSolutionEnvelope: Equatable, Sendable {
    case shortestPath(ShortestPathSolution)
    case minimumSpanningTree(MinimumSpanningTreeSolution)
    case maxFlow(MaxFlowSolution)
    case travelingSalesperson(TravelingSalespersonSolution)
    case assignment(AssignmentSolution)
    case transportation(TransportationSolution)

    public var kind: NetworkProblemKind {
        switch self {
        case .shortestPath:
            .shortestPath
        case .minimumSpanningTree:
            .minimumSpanningTree
        case .maxFlow:
            .maxFlow
        case .travelingSalesperson:
            .travelingSalesperson
        case .assignment:
            .assignment
        case .transportation:
            .transportation
        }
    }
}

extension NetworkModelEnvelope: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case model
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(NetworkProblemKind.self, forKey: .kind)
        switch kind {
        case .shortestPath:
            self = .shortestPath(try container.decode(ShortestPathNetwork.self, forKey: .model))
        case .minimumSpanningTree:
            self = .minimumSpanningTree(try container.decode(MinimumSpanningTreeNetwork.self, forKey: .model))
        case .maxFlow:
            self = .maxFlow(try container.decode(MaxFlowNetwork.self, forKey: .model))
        case .travelingSalesperson:
            self = .travelingSalesperson(try container.decode(TravelingSalespersonProblem.self, forKey: .model))
        case .assignment:
            self = .assignment(try container.decode(AssignmentProblem.self, forKey: .model))
        case .transportation:
            self = .transportation(try container.decode(TransportationProblem.self, forKey: .model))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .shortestPath(let model):
            try container.encode(model, forKey: .model)
        case .minimumSpanningTree(let model):
            try container.encode(model, forKey: .model)
        case .maxFlow(let model):
            try container.encode(model, forKey: .model)
        case .travelingSalesperson(let model):
            try container.encode(model, forKey: .model)
        case .assignment(let model):
            try container.encode(model, forKey: .model)
        case .transportation(let model):
            try container.encode(model, forKey: .model)
        }
    }
}

extension NetworkSolutionEnvelope: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case solution
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(NetworkProblemKind.self, forKey: .kind)
        switch kind {
        case .shortestPath:
            self = .shortestPath(try container.decode(ShortestPathSolution.self, forKey: .solution))
        case .minimumSpanningTree:
            self = .minimumSpanningTree(try container.decode(MinimumSpanningTreeSolution.self, forKey: .solution))
        case .maxFlow:
            self = .maxFlow(try container.decode(MaxFlowSolution.self, forKey: .solution))
        case .travelingSalesperson:
            self = .travelingSalesperson(try container.decode(TravelingSalespersonSolution.self, forKey: .solution))
        case .assignment:
            self = .assignment(try container.decode(AssignmentSolution.self, forKey: .solution))
        case .transportation:
            self = .transportation(try container.decode(TransportationSolution.self, forKey: .solution))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .shortestPath(let solution):
            try container.encode(solution, forKey: .solution)
        case .minimumSpanningTree(let solution):
            try container.encode(solution, forKey: .solution)
        case .maxFlow(let solution):
            try container.encode(solution, forKey: .solution)
        case .travelingSalesperson(let solution):
            try container.encode(solution, forKey: .solution)
        case .assignment(let solution):
            try container.encode(solution, forKey: .solution)
        case .transportation(let solution):
            try container.encode(solution, forKey: .solution)
        }
    }
}

public enum NetworkModelJSON {
    public static func decodeModel(from data: Data) throws -> NetworkModelEnvelope {
        try decoder.decode(NetworkModelEnvelope.self, from: data)
    }

    public static func encodeModel(_ model: NetworkModelEnvelope) throws -> Data {
        try encoder.encode(model)
    }

    public static func encodeSolution(_ solution: NetworkSolutionEnvelope) throws -> Data {
        try encoder.encode(solution)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        JSONDecoder()
    }
}

public enum NetworkModelError: Error, CustomStringConvertible {
    case unsupportedFormat
    case unsupportedProblemType(String)
    case invalidNumericValue(String)
    case invalidNetwork(String)
    case noPath(source: String, sink: String)

    public var description: String {
        switch self {
        case .unsupportedFormat:
            "Unsupported network model format"
        case .unsupportedProblemType(let type):
            "Unsupported network problem type: \(type)"
        case .invalidNumericValue(let value):
            "Invalid numeric value: \(value)"
        case .invalidNetwork(let detail):
            "Invalid network model: \(detail)"
        case .noPath(let source, let sink):
            "No path exists from \(source) to \(sink)"
        }
    }
}

public enum WinQSBNetworkParser {
    public static func problemKind(from data: Data) throws -> NetworkProblemKind {
        guard let metadata = metadata(from: data), metadata.count >= 3 else {
            throw NetworkModelError.unsupportedFormat
        }
        guard let kind = NetworkProblemKind(rawValue: metadata[2]) else {
            throw NetworkModelError.unsupportedProblemType(metadata[2])
        }
        return kind
    }

    public static func parseModelEnvelope(from data: Data) throws -> NetworkModelEnvelope {
        switch try problemKind(from: data) {
        case .shortestPath:
            return .shortestPath(try parseShortestPath(from: data))
        case .minimumSpanningTree:
            return .minimumSpanningTree(try parseMinimumSpanningTree(from: data))
        case .maxFlow:
            return .maxFlow(try parseMaxFlow(from: data))
        case .travelingSalesperson:
            return .travelingSalesperson(try parseTravelingSalesperson(from: data))
        case .assignment:
            return .assignment(try parseAssignment(from: data))
        case .transportation:
            return .transportation(try parseTransportation(from: data))
        }
    }

    public static func parseShortestPath(from data: Data) throws -> ShortestPathNetwork {
        let parsed = try parseNetworkMatrix(from: data, expectedProblemType: "SPP")
        return ShortestPathNetwork(title: parsed.problemType, nodes: parsed.nodes, arcs: parsed.arcs)
    }

    public static func parseMinimumSpanningTree(from data: Data) throws -> MinimumSpanningTreeNetwork {
        let parsed = try parseNetworkMatrix(from: data, expectedProblemType: "MST")
        return MinimumSpanningTreeNetwork(title: parsed.problemType, nodes: parsed.nodes, edges: parsed.arcs)
    }

    public static func parseMaxFlow(from data: Data) throws -> MaxFlowNetwork {
        let parsed = try parseNetworkMatrix(from: data, expectedProblemType: "MFP")
        return MaxFlowNetwork(title: parsed.problemType, nodes: parsed.nodes, arcs: parsed.arcs)
    }

    public static func parseTravelingSalesperson(from data: Data) throws -> TravelingSalespersonProblem {
        let parsed = try parseNetworkMatrix(from: data, expectedProblemType: "TSP")
        return TravelingSalespersonProblem(title: parsed.problemType, nodes: parsed.nodes, arcs: parsed.arcs)
    }

    public static func parseAssignment(from data: Data) throws -> AssignmentProblem {
        let parsed = try parseRectangularCostMatrix(from: data, expectedProblemType: "AP")
        return AssignmentProblem(
            title: parsed.problemType,
            workers: parsed.rowNames,
            tasks: parsed.columnNames,
            costs: parsed.costs
        )
    }

    public static func parseTransportation(from data: Data) throws -> TransportationProblem {
        let parsed = try parseTransportationMatrix(from: data)
        return TransportationProblem(
            title: parsed.problemType,
            origins: parsed.origins,
            destinations: parsed.destinations,
            costs: parsed.costs,
            supply: parsed.supply,
            demand: parsed.demand
        )
    }

    private struct ParsedNetworkMatrix {
        let problemType: String
        let nodes: [String]
        let arcs: [NetworkArc]
    }

    private struct ParsedRectangularCostMatrix {
        let problemType: String
        let rowNames: [String]
        let columnNames: [String]
        let costs: [[Double]]
    }

    private struct ParsedTransportationMatrix {
        let problemType: String
        let origins: [String]
        let destinations: [String]
        let costs: [[Double]]
        let supply: [Double]
        let demand: [Double]
    }

    private static func parseNetworkMatrix(
        from data: Data,
        expectedProblemType: String
    ) throws -> ParsedNetworkMatrix {
        guard let text = String(data: data, encoding: .isoLatin1) else {
            throw NetworkModelError.unsupportedFormat
        }

        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(clean) }

        guard
            lines.count >= 4,
            let metadata = lines.first,
            metadata.count >= 3,
            metadata[0] == "NET"
        else {
            throw NetworkModelError.unsupportedFormat
        }

        guard metadata[2] == expectedProblemType else {
            throw NetworkModelError.unsupportedProblemType(metadata[2])
        }

        let countRow = lines[1]
        guard let nodeCount = countRow.first.flatMap(Int.init), nodeCount > 1 else {
            throw NetworkModelError.unsupportedFormat
        }

        let header = lines[2]
        guard header.count >= nodeCount + 1 else {
            throw NetworkModelError.unsupportedFormat
        }
        let nodes = Array(header[1...nodeCount])

        guard lines.count >= 3 + nodeCount else {
            throw NetworkModelError.unsupportedFormat
        }

        var arcs: [NetworkArc] = []
        for rowIndex in 0..<nodeCount {
            let row = lines[3 + rowIndex]
            guard row.count >= nodeCount + 1 else {
                throw NetworkModelError.unsupportedFormat
            }

            let from = row[0]
            for columnIndex in 0..<nodeCount {
                let rawCost = row[columnIndex + 1]
                guard !rawCost.isEmpty else { continue }
                guard let cost = Double(rawCost), cost.isFinite else {
                    throw NetworkModelError.invalidNumericValue(rawCost)
                }
                guard cost >= 0 else {
                    throw NetworkModelError.invalidNetwork("Network costs must be nonnegative")
                }
                arcs.append(NetworkArc(from: from, to: nodes[columnIndex], cost: cost))
            }
        }

        return ParsedNetworkMatrix(problemType: metadata[2], nodes: nodes, arcs: arcs)
    }

    private static func metadata(from data: Data) -> [String]? {
        guard let text = String(data: data, encoding: .isoLatin1),
              let firstLine = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
        else {
            return nil
        }
        let metadata = firstLine.split(separator: "\t", omittingEmptySubsequences: false).map(clean)
        guard metadata.first == "NET" else {
            return nil
        }
        return metadata
    }

    private static func clean(_ value: Substring) -> String {
        String(value).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseRectangularCostMatrix(
        from data: Data,
        expectedProblemType: String
    ) throws -> ParsedRectangularCostMatrix {
        guard let text = String(data: data, encoding: .isoLatin1) else {
            throw NetworkModelError.unsupportedFormat
        }

        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(clean) }

        guard
            lines.count >= 4,
            let metadata = lines.first,
            metadata.count >= 3,
            metadata[0] == "NET"
        else {
            throw NetworkModelError.unsupportedFormat
        }

        guard metadata[2] == expectedProblemType else {
            throw NetworkModelError.unsupportedProblemType(metadata[2])
        }

        let countRow = lines[1]
        guard countRow.count >= 3,
              let rowCount = Int(countRow[1]),
              let columnCount = Int(countRow[2]),
              rowCount > 0,
              columnCount > 0
        else {
            throw NetworkModelError.unsupportedFormat
        }

        let header = lines[2]
        guard header.count >= columnCount + 1 else {
            throw NetworkModelError.unsupportedFormat
        }
        let columnNames = Array(header[1...columnCount])

        guard lines.count >= 3 + rowCount else {
            throw NetworkModelError.unsupportedFormat
        }

        var rowNames: [String] = []
        var costs: [[Double]] = []
        for rowIndex in 0..<rowCount {
            let row = lines[3 + rowIndex]
            guard row.count >= columnCount + 1 else {
                throw NetworkModelError.unsupportedFormat
            }

            rowNames.append(row[0])
            let costRow = try row[1...columnCount].map { value in
                guard let cost = Double(value), cost.isFinite else {
                    throw NetworkModelError.invalidNumericValue(value)
                }
                return cost
            }
            costs.append(costRow)
        }

        return ParsedRectangularCostMatrix(
            problemType: metadata[2],
            rowNames: rowNames,
            columnNames: columnNames,
            costs: costs
        )
    }

    private static func parseTransportationMatrix(from data: Data) throws -> ParsedTransportationMatrix {
        guard let text = String(data: data, encoding: .isoLatin1) else {
            throw NetworkModelError.unsupportedFormat
        }

        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(clean) }

        guard
            lines.count >= 5,
            let metadata = lines.first,
            metadata.count >= 3,
            metadata[0] == "NET",
            metadata[2] == "TP"
        else {
            throw NetworkModelError.unsupportedFormat
        }

        let countRow = lines[1]
        guard countRow.count >= 3,
              let originCount = Int(countRow[1]),
              let destinationCount = Int(countRow[2]),
              originCount > 0,
              destinationCount > 0
        else {
            throw NetworkModelError.unsupportedFormat
        }

        let header = lines[2]
        guard header.count >= destinationCount + 2 else {
            throw NetworkModelError.unsupportedFormat
        }
        let destinations = Array(header[1...destinationCount])

        guard lines.count >= 4 + originCount else {
            throw NetworkModelError.unsupportedFormat
        }

        var origins: [String] = []
        var costs: [[Double]] = []
        var supply: [Double] = []

        for rowIndex in 0..<originCount {
            let row = lines[3 + rowIndex]
            guard row.count >= destinationCount + 2 else {
                throw NetworkModelError.unsupportedFormat
            }
            origins.append(row[0])
            costs.append(try row[1...destinationCount].map(parseFiniteDouble))
            supply.append(try parseFiniteDouble(row[destinationCount + 1]))
        }

        let demandRow = lines[3 + originCount]
        guard demandRow.count >= destinationCount + 1,
              demandRow[0].lowercased() == "demand"
        else {
            throw NetworkModelError.unsupportedFormat
        }
        let demand = try demandRow[1...destinationCount].map(parseFiniteDouble)

        return ParsedTransportationMatrix(
            problemType: metadata[2],
            origins: origins,
            destinations: destinations,
            costs: costs,
            supply: supply,
            demand: demand
        )
    }

    private static func parseFiniteDouble(_ value: String) throws -> Double {
        guard let number = Double(value), number.isFinite else {
            throw NetworkModelError.invalidNumericValue(value)
        }
        return number
    }
}

public enum TransportationSolver {
    public static func solve(
        _ problem: TransportationProblem,
        linearProgrammingBackend: any LinearProgrammingBackend = NativeEducationalLinearProgrammingBackend()
    ) throws -> TransportationSolution {
        try TransportationValidator.validate(problem)

        let originCount = problem.origins.count
        let destinationCount = problem.destinations.count
        let variableNames = (0..<originCount).flatMap { originIndex in
            (0..<destinationCount).map { destinationIndex in
                "\(problem.origins[originIndex])_to_\(problem.destinations[destinationIndex])"
            }
        }
        let objective = problem.costs.flatMap { $0 }

        var constraints: [LinearConstraint] = []
        for originIndex in 0..<originCount {
            var coefficients = Array(repeating: 0.0, count: variableNames.count)
            for destinationIndex in 0..<destinationCount {
                coefficients[index(origin: originIndex, destination: destinationIndex, destinationCount: destinationCount)] = 1
            }
            constraints.append(LinearConstraint(
                name: "Supply_\(problem.origins[originIndex])",
                coefficients: coefficients,
                relation: .equal,
                rhs: problem.supply[originIndex]
            ))
        }

        for destinationIndex in 0..<destinationCount {
            var coefficients = Array(repeating: 0.0, count: variableNames.count)
            for originIndex in 0..<originCount {
                coefficients[index(origin: originIndex, destination: destinationIndex, destinationCount: destinationCount)] = 1
            }
            constraints.append(LinearConstraint(
                name: "Demand_\(problem.destinations[destinationIndex])",
                coefficients: coefficients,
                relation: .equal,
                rhs: problem.demand[destinationIndex]
            ))
        }

        let linearProgram = LinearProgram(
            title: problem.title,
            sense: .minimize,
            variableNames: variableNames,
            objectiveCoefficients: objective,
            constraints: constraints
        )
        let solution = try linearProgrammingBackend.solve(linearProgram, mode: .continuous)

        var shipments: [TransportationShipment] = []
        for originIndex in 0..<originCount {
            for destinationIndex in 0..<destinationCount {
                let variableName = variableNames[index(origin: originIndex, destination: destinationIndex, destinationCount: destinationCount)]
                let quantity = solution.variableValues[variableName] ?? 0
                guard quantity > 1e-8 else { continue }
                shipments.append(TransportationShipment(
                    origin: problem.origins[originIndex],
                    destination: problem.destinations[destinationIndex],
                    quantity: quantity,
                    unitCost: problem.costs[originIndex][destinationIndex]
                ))
            }
        }

        return TransportationSolution(totalCost: solution.objectiveValue, shipments: shipments)
    }

    private static func index(origin: Int, destination: Int, destinationCount: Int) -> Int {
        origin * destinationCount + destination
    }
}

public enum AssignmentSolver {
    public static func solve(_ problem: AssignmentProblem) throws -> AssignmentSolution {
        try validate(problem)
        let bestAssignment = try hungarianAssignment(costs: problem.costs)
        let bestCost = bestAssignment.enumerated().reduce(0.0) { partial, pair in
            partial + problem.costs[pair.offset][pair.element]
        }

        let assignments = bestAssignment.enumerated().map { workerIndex, taskIndex in
            AssignmentPair(
                worker: problem.workers[workerIndex],
                task: problem.tasks[taskIndex],
                cost: problem.costs[workerIndex][taskIndex]
            )
        }
        return AssignmentSolution(totalCost: bestCost, assignments: assignments)
    }

    private static func validate(_ problem: AssignmentProblem) throws {
        guard !problem.workers.isEmpty, !problem.tasks.isEmpty else {
            throw NetworkModelError.invalidNetwork("assignment rows and columns must not be empty")
        }
        guard problem.costs.count == problem.workers.count,
              problem.costs.allSatisfy({ $0.count == problem.tasks.count })
        else {
            throw NetworkModelError.invalidNetwork("assignment cost matrix dimensions do not match labels")
        }
        guard problem.workers.count <= problem.tasks.count else {
            throw NetworkModelError.invalidNetwork("assignment requires at least as many tasks as workers")
        }
        guard problem.costs.flatMap({ $0 }).allSatisfy({ $0.isFinite }) else {
            throw NetworkModelError.invalidNetwork("assignment costs must be finite")
        }
    }

    private static func hungarianAssignment(costs: [[Double]]) throws -> [Int] {
        let rowCount = costs.count
        let columnCount = costs[0].count
        var rowPotential = Array(repeating: 0.0, count: rowCount + 1)
        var columnPotential = Array(repeating: 0.0, count: columnCount + 1)
        var matchedRowForColumn = Array(repeating: 0, count: columnCount + 1)
        var previousColumn = Array(repeating: 0, count: columnCount + 1)

        for row in 1...rowCount {
            matchedRowForColumn[0] = row
            var currentColumn = 0
            var minimumReducedCost = Array(repeating: Double.infinity, count: columnCount + 1)
            var used = Array(repeating: false, count: columnCount + 1)

            repeat {
                used[currentColumn] = true
                let currentRow = matchedRowForColumn[currentColumn]
                var delta = Double.infinity
                var nextColumn = 0

                for column in 1...columnCount where !used[column] {
                    let reducedCost = costs[currentRow - 1][column - 1]
                        - rowPotential[currentRow]
                        - columnPotential[column]
                    if reducedCost < minimumReducedCost[column] {
                        minimumReducedCost[column] = reducedCost
                        previousColumn[column] = currentColumn
                    }
                    if minimumReducedCost[column] < delta {
                        delta = minimumReducedCost[column]
                        nextColumn = column
                    }
                }

                guard delta.isFinite else {
                    throw NetworkModelError.invalidNetwork("no feasible assignment exists")
                }

                for column in 0...columnCount {
                    if used[column] {
                        rowPotential[matchedRowForColumn[column]] += delta
                        columnPotential[column] -= delta
                    } else {
                        minimumReducedCost[column] -= delta
                    }
                }
                currentColumn = nextColumn
            } while matchedRowForColumn[currentColumn] != 0

            repeat {
                let nextColumn = previousColumn[currentColumn]
                matchedRowForColumn[currentColumn] = matchedRowForColumn[nextColumn]
                currentColumn = nextColumn
            } while currentColumn != 0
        }

        var assignment = Array(repeating: -1, count: rowCount)
        for column in 1...columnCount {
            let row = matchedRowForColumn[column]
            if row > 0 {
                assignment[row - 1] = column - 1
            }
        }

        guard !assignment.contains(-1) else {
            throw NetworkModelError.invalidNetwork("no feasible assignment exists")
        }
        return assignment
    }
}

public enum TravelingSalespersonSolver {
    public static func solve(
        _ problem: TravelingSalespersonProblem,
        source: String? = nil
    ) throws -> TravelingSalespersonSolution {
        guard !problem.nodes.isEmpty else {
            throw NetworkModelError.invalidNetwork("nodes must not be empty")
        }
        guard problem.nodes.count <= 20 else {
            throw NetworkModelError.invalidNetwork("TSP exact solver supports up to 20 nodes")
        }

        let source = source ?? problem.nodes[0]
        guard let sourceIndex = problem.nodes.firstIndex(of: source) else {
            throw NetworkModelError.invalidNetwork("source must exist in nodes")
        }
        let nodeSet = Set(problem.nodes)
        guard nodeSet.count == problem.nodes.count else {
            throw NetworkModelError.invalidNetwork("node names must be unique")
        }

        let nodeCount = problem.nodes.count
        var costs = Array(
            repeating: Array(repeating: Double.infinity, count: nodeCount),
            count: nodeCount
        )

        for arc in problem.arcs {
            guard let fromIndex = problem.nodes.firstIndex(of: arc.from),
                  let toIndex = problem.nodes.firstIndex(of: arc.to)
            else {
                throw NetworkModelError.invalidNetwork("arc endpoints must exist in nodes")
            }
            guard arc.cost >= 0, arc.cost.isFinite else {
                throw NetworkModelError.invalidNetwork("TSP costs must be finite and nonnegative")
            }
            if fromIndex != toIndex {
                costs[fromIndex][toIndex] = min(costs[fromIndex][toIndex], arc.cost)
            }
        }

        let fullMask = (1 << nodeCount) - 1
        let sourceMask = 1 << sourceIndex
        var bestCost = Array(
            repeating: Array(repeating: Double.infinity, count: nodeCount),
            count: 1 << nodeCount
        )
        var predecessor = Array(
            repeating: Array(repeating: -1, count: nodeCount),
            count: 1 << nodeCount
        )
        bestCost[sourceMask][sourceIndex] = 0

        for mask in 0...fullMask where mask & sourceMask != 0 {
            for current in 0..<nodeCount {
                let currentCost = bestCost[mask][current]
                guard currentCost.isFinite else { continue }

                for next in 0..<nodeCount where mask & (1 << next) == 0 {
                    let arcCost = costs[current][next]
                    guard arcCost.isFinite else { continue }

                    let nextMask = mask | (1 << next)
                    let candidate = currentCost + arcCost
                    if candidate < bestCost[nextMask][next] - 1e-9 {
                        bestCost[nextMask][next] = candidate
                        predecessor[nextMask][next] = current
                    }
                }
            }
        }

        var bestEnd = -1
        var bestTourCost = Double.infinity
        for end in 0..<nodeCount where end != sourceIndex {
            let returnCost = costs[end][sourceIndex]
            guard returnCost.isFinite else { continue }
            let candidate = bestCost[fullMask][end] + returnCost
            if candidate < bestTourCost - 1e-9 {
                bestTourCost = candidate
                bestEnd = end
            }
        }

        guard bestEnd >= 0, bestTourCost.isFinite else {
            throw NetworkModelError.invalidNetwork("no Hamiltonian cycle exists")
        }

        var reversedPath: [Int] = []
        var mask = fullMask
        var current = bestEnd
        while current != sourceIndex {
            reversedPath.append(current)
            let previous = predecessor[mask][current]
            guard previous >= 0 else {
                throw NetworkModelError.invalidNetwork("could not reconstruct TSP tour")
            }
            mask ^= 1 << current
            current = previous
        }

        let nodePath = [sourceIndex] + reversedPath.reversed() + [sourceIndex]
        return TravelingSalespersonSolution(
            source: source,
            totalCost: bestTourCost,
            tour: nodePath.map { problem.nodes[$0] }
        )
    }
}

public enum MaxFlowSolver {
    public static func solve(
        _ network: MaxFlowNetwork,
        source: String? = nil,
        sink: String? = nil
    ) throws -> MaxFlowSolution {
        guard !network.nodes.isEmpty else {
            throw NetworkModelError.invalidNetwork("nodes must not be empty")
        }

        let source = source ?? network.nodes[0]
        let sink = sink ?? network.nodes[network.nodes.count - 1]
        let nodeSet = Set(network.nodes)
        guard nodeSet.contains(source), nodeSet.contains(sink), source != sink else {
            throw NetworkModelError.invalidNetwork("source and sink must be distinct existing nodes")
        }

        var residual = Dictionary(uniqueKeysWithValues: network.nodes.map { node in
            (node, Dictionary(uniqueKeysWithValues: network.nodes.map { ($0, 0.0) }))
        })
        var originalCapacity: [String: [String: Double]] = residual

        for arc in network.arcs {
            guard nodeSet.contains(arc.from), nodeSet.contains(arc.to) else {
                throw NetworkModelError.invalidNetwork("arc endpoints must exist in nodes")
            }
            guard arc.cost >= 0 else {
                throw NetworkModelError.invalidNetwork("capacities must be nonnegative")
            }
            residual[arc.from]![arc.to, default: 0] += arc.cost
            originalCapacity[arc.from]![arc.to, default: 0] += arc.cost
        }

        var maxFlow = 0.0
        while let path = augmentingPath(in: residual, nodes: network.nodes, source: source, sink: sink) {
            let increment = path.reduce(Double.infinity) { partial, edge in
                min(partial, residual[edge.from]?[edge.to] ?? 0)
            }
            guard increment.isFinite, increment > 1e-9 else {
                break
            }

            for edge in path {
                residual[edge.from]![edge.to]! -= increment
                residual[edge.to]![edge.from, default: 0] += increment
            }
            maxFlow += increment
        }

        var arcFlows: [MaxFlowArcFlow] = []
        for from in network.nodes {
            for to in network.nodes {
                let capacity = originalCapacity[from]?[to] ?? 0
                guard capacity > 0 else { continue }
                let remaining = residual[from]?[to] ?? 0
                let flow = max(0, capacity - remaining)
                if flow > 1e-9 {
                    arcFlows.append(MaxFlowArcFlow(from: from, to: to, flow: flow))
                }
            }
        }

        return MaxFlowSolution(source: source, sink: sink, maxFlow: maxFlow, arcFlows: arcFlows)
    }

    private struct ResidualEdge {
        let from: String
        let to: String
    }

    private static func augmentingPath(
        in residual: [String: [String: Double]],
        nodes: [String],
        source: String,
        sink: String
    ) -> [ResidualEdge]? {
        var queue = [source]
        var visited: Set<String> = [source]
        var predecessor: [String: String] = [:]

        while !queue.isEmpty {
            let current = queue.removeFirst()
            if current == sink {
                break
            }

            for next in nodes where !visited.contains(next) {
                let capacity = residual[current]?[next] ?? 0
                guard capacity > 1e-9 else { continue }
                visited.insert(next)
                predecessor[next] = current
                queue.append(next)
            }
        }

        guard visited.contains(sink) else {
            return nil
        }

        var path: [ResidualEdge] = []
        var current = sink
        while current != source {
            guard let previous = predecessor[current] else {
                return nil
            }
            path.append(ResidualEdge(from: previous, to: current))
            current = previous
        }
        return path.reversed()
    }
}

public enum MinimumSpanningTreeSolver {
    public static func solve(_ network: MinimumSpanningTreeNetwork) throws -> MinimumSpanningTreeSolution {
        guard !network.nodes.isEmpty else {
            throw NetworkModelError.invalidNetwork("nodes must not be empty")
        }

        let nodeSet = Set(network.nodes)
        var bestUndirectedEdges: [String: NetworkArc] = [:]
        for edge in network.edges {
            guard nodeSet.contains(edge.from), nodeSet.contains(edge.to) else {
                throw NetworkModelError.invalidNetwork("edge endpoints must exist in nodes")
            }
            guard edge.from != edge.to else { continue }
            let key = undirectedKey(edge.from, edge.to)
            if let existing = bestUndirectedEdges[key], existing.cost <= edge.cost {
                continue
            }
            bestUndirectedEdges[key] = edge
        }

        let sortedEdges = bestUndirectedEdges.values.sorted {
            if abs($0.cost - $1.cost) > 1e-9 {
                return $0.cost < $1.cost
            }
            if $0.from != $1.from {
                return $0.from < $1.from
            }
            return $0.to < $1.to
        }

        var unionFind = UnionFind(network.nodes)
        var selectedEdges: [NetworkArc] = []
        var totalCost = 0.0

        for edge in sortedEdges where unionFind.union(edge.from, edge.to) {
            selectedEdges.append(edge)
            totalCost += edge.cost
            if selectedEdges.count == network.nodes.count - 1 {
                break
            }
        }

        guard selectedEdges.count == network.nodes.count - 1 else {
            throw NetworkModelError.invalidNetwork("network is disconnected")
        }

        return MinimumSpanningTreeSolution(totalCost: totalCost, edges: selectedEdges)
    }

    private static func undirectedKey(_ first: String, _ second: String) -> String {
        first < second ? "\(first)\u{0}\(second)" : "\(second)\u{0}\(first)"
    }
}

public enum ShortestPathSolver {
    public static func solve(
        _ network: ShortestPathNetwork,
        source: String? = nil,
        sink: String? = nil
    ) throws -> ShortestPathSolution {
        guard !network.nodes.isEmpty else {
            throw NetworkModelError.invalidNetwork("nodes must not be empty")
        }

        let source = source ?? network.nodes[0]
        let sink = sink ?? network.nodes[network.nodes.count - 1]
        let nodeSet = Set(network.nodes)
        guard nodeSet.contains(source), nodeSet.contains(sink) else {
            throw NetworkModelError.invalidNetwork("source and sink must exist in nodes")
        }

        let adjacency = Dictionary(grouping: network.arcs, by: \.from)
        var distances = Dictionary(uniqueKeysWithValues: network.nodes.map { ($0, Double.infinity) })
        var predecessors: [String: String] = [:]
        var unvisited = nodeSet
        distances[source] = 0

        while !unvisited.isEmpty {
            guard let current = unvisited.min(by: { (distances[$0] ?? .infinity) < (distances[$1] ?? .infinity) }) else {
                break
            }
            let currentDistance = distances[current] ?? .infinity
            if currentDistance == .infinity {
                break
            }
            if current == sink {
                break
            }
            unvisited.remove(current)

            for arc in adjacency[current, default: []] where unvisited.contains(arc.to) {
                let candidate = currentDistance + arc.cost
                if candidate < (distances[arc.to] ?? .infinity) {
                    distances[arc.to] = candidate
                    predecessors[arc.to] = current
                }
            }
        }

        guard let totalCost = distances[sink], totalCost.isFinite else {
            throw NetworkModelError.noPath(source: source, sink: sink)
        }

        var path = [sink]
        var current = sink
        while current != source {
            guard let predecessor = predecessors[current] else {
                throw NetworkModelError.noPath(source: source, sink: sink)
            }
            path.append(predecessor)
            current = predecessor
        }

        return ShortestPathSolution(
            source: source,
            sink: sink,
            totalCost: totalCost,
            path: path.reversed()
        )
    }
}

private struct UnionFind {
    private var parent: [String: String]
    private var rank: [String: Int]

    init(_ nodes: [String]) {
        parent = Dictionary(uniqueKeysWithValues: nodes.map { ($0, $0) })
        rank = Dictionary(uniqueKeysWithValues: nodes.map { ($0, 0) })
    }

    mutating func union(_ first: String, _ second: String) -> Bool {
        let firstRoot = find(first)
        let secondRoot = find(second)
        guard firstRoot != secondRoot else {
            return false
        }

        let firstRank = rank[firstRoot, default: 0]
        let secondRank = rank[secondRoot, default: 0]
        if firstRank < secondRank {
            parent[firstRoot] = secondRoot
        } else if firstRank > secondRank {
            parent[secondRoot] = firstRoot
        } else {
            parent[secondRoot] = firstRoot
            rank[firstRoot] = firstRank + 1
        }
        return true
    }

    private mutating func find(_ node: String) -> String {
        let currentParent = parent[node] ?? node
        if currentParent == node {
            return node
        }
        let root = find(currentParent)
        parent[node] = root
        return root
    }
}
