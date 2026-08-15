import Foundation

public struct NetworkSolutionDocument: Codable, Equatable, Sendable {
    public let backend: SolverRunMetadata
    public let model: NetworkModelEnvelope
    public let solution: NetworkSolutionEnvelope
}

public struct NetworkValidationDocument: Codable, Equatable, Sendable {
    public let kind: NetworkProblemKind
    public let backend: SolverBackendKind
    public let isValid: Bool
    public let diagnostics: [ValidationDiagnostic]

    public init(kind: NetworkProblemKind, backend: SolverBackendKind, diagnostics: [ValidationDiagnostic]) {
        self.kind = kind
        self.backend = backend
        self.isValid = !diagnostics.contains { $0.severity == .error }
        self.diagnostics = diagnostics
    }
}

public extension NetworkModelEnvelope {
    var title: String {
        switch self {
        case .minimumCostFlow(let value): value.title
        case .shortestPath(let value): value.title
        case .minimumSpanningTree(let value): value.title
        case .maxFlow(let value): value.title
        case .travelingSalesperson(let value): value.title
        case .assignment(let value): value.title
        case .transportation(let value): value.title
        }
    }
}

public enum NetworkValidator {
    public static func diagnostics(for model: NetworkModelEnvelope) -> [ValidationDiagnostic] {
        switch model {
        case .minimumCostFlow(let value): minimumCostFlowDiagnostics(value)
        case .shortestPath(let value): graphDiagnostics(nodes: value.nodes, arcs: value.arcs, kind: .shortestPath, noun: "arc")
        case .minimumSpanningTree(let value): graphDiagnostics(nodes: value.nodes, arcs: value.edges, kind: .minimumSpanningTree, noun: "edge")
        case .maxFlow(let value): graphDiagnostics(nodes: value.nodes, arcs: value.arcs, kind: .maxFlow, noun: "arc")
        case .travelingSalesperson(let value): tspDiagnostics(value)
        case .assignment(let value): assignmentDiagnostics(value)
        case .transportation(let value): TransportationValidator.diagnostics(for: value)
        }
    }

    public static func validate(_ model: NetworkModelEnvelope) throws {
        if let item = diagnostics(for: model).first(where: { $0.severity == .error }) { throw NetworkModelError.invalidNetwork(item.message) }
    }

    private static func graphDiagnostics(nodes: [String], arcs: [NetworkArc], kind: NetworkProblemKind, noun: String) -> [ValidationDiagnostic] {
        var result = nodeDiagnostics(nodes, kind: kind)
        if nodes.count < 2 { result.append(error(kind, "nodes.insufficient", "Network requires at least two nodes.", "model.nodes")) }
        if arcs.isEmpty { result.append(error(kind, "\(noun)s.empty", "Network must contain at least one \(noun).", "model.\(noun)s")) }
        validateArcs(arcs, nodes: nodes, kind: kind, noun: noun, result: &result)
        return completed(result, kind: kind)
    }

    private static func tspDiagnostics(_ value: TravelingSalespersonProblem) -> [ValidationDiagnostic] {
        var result = graphDiagnostics(nodes: value.nodes, arcs: value.arcs, kind: .travelingSalesperson, noun: "arc").filter { $0.severity != .info }
        if value.nodes.count > 20 { result.append(error(.travelingSalesperson, "nodes.limit", "Native exact TSP supports at most 20 nodes.", "model.nodes")) }
        return completed(result, kind: .travelingSalesperson)
    }

    private static func assignmentDiagnostics(_ value: AssignmentProblem) -> [ValidationDiagnostic] {
        var result: [ValidationDiagnostic] = []
        if value.workers.isEmpty { result.append(error(.assignment, "workers.empty", "Workers must not be empty.", "model.workers")) }
        if value.tasks.isEmpty { result.append(error(.assignment, "tasks.empty", "Tasks must not be empty.", "model.tasks")) }
        if Set(value.workers).count != value.workers.count { result.append(error(.assignment, "workers.duplicate", "Worker names must be unique.", "model.workers")) }
        if Set(value.tasks).count != value.tasks.count { result.append(error(.assignment, "tasks.duplicate", "Task names must be unique.", "model.tasks")) }
        if value.tasks.count < value.workers.count { result.append(error(.assignment, "tasks.insufficient", "Assignment requires at least as many tasks as workers.", "model.tasks")) }
        if value.costs.count != value.workers.count || value.costs.contains(where: { $0.count != value.tasks.count }) { result.append(error(.assignment, "costs.dimensions", "Cost dimensions must match workers and tasks.", "model.costs")) }
        if value.costs.flatMap({ $0 }).contains(where: { !$0.isFinite }) { result.append(error(.assignment, "costs.finite", "Assignment costs must be finite.", "model.costs")) }
        return completed(result, kind: .assignment)
    }

    private static func minimumCostFlowDiagnostics(_ value: MinimumCostNetworkFlowProblem) -> [ValidationDiagnostic] {
        var result = nodeDiagnostics(value.nodes, kind: .minimumCostFlow)
        if value.nodes.count < 2 { result.append(error(.minimumCostFlow, "nodes.insufficient", "Network requires at least two nodes.", "model.nodes")) }
        if value.arcs.isEmpty { result.append(error(.minimumCostFlow, "arcs.empty", "Network must contain at least one arc.", "model.arcs")) }
        validateArcs(value.arcs, nodes: value.nodes, kind: .minimumCostFlow, noun: "arc", result: &result)
        if value.supply.count != value.nodes.count { result.append(error(.minimumCostFlow, "supply.dimension", "Supply count must match node count.", "model.supply")) }
        if value.demand.count != value.nodes.count { result.append(error(.minimumCostFlow, "demand.dimension", "Demand count must match node count.", "model.demand")) }
        if value.supply.contains(where: { !$0.isFinite || $0 < 0 }) { result.append(error(.minimumCostFlow, "supply.value", "Supply values must be finite and nonnegative.", "model.supply")) }
        if value.demand.contains(where: { !$0.isFinite || $0 < 0 }) { result.append(error(.minimumCostFlow, "demand.value", "Demand values must be finite and nonnegative.", "model.demand")) }
        if result.contains(where: { $0.severity == .error }) { return result }
        let difference = value.supply.reduce(0, +) - value.demand.reduce(0, +)
        if abs(difference) > 1e-8 {
            result.append(ValidationDiagnostic(
                severity: .warning,
                code: "network.CNF.balance.automatic",
                message: "Supply and demand differ by \(abs(difference)); the native solver adds a zero-cost dummy balance node.",
                path: "model.supply,model.demand"
            ))
        }
        return completed(result, kind: .minimumCostFlow)
    }

    private static func nodeDiagnostics(_ nodes: [String], kind: NetworkProblemKind) -> [ValidationDiagnostic] {
        var result: [ValidationDiagnostic] = []
        if nodes.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { result.append(error(kind, "nodes.emptyName", "Node names must not be empty.", "model.nodes")) }
        if Set(nodes).count != nodes.count { result.append(error(kind, "nodes.duplicate", "Node names must be unique.", "model.nodes")) }
        return result
    }

    private static func validateArcs(_ arcs: [NetworkArc], nodes: [String], kind: NetworkProblemKind, noun: String, result: inout [ValidationDiagnostic]) {
        let set = Set(nodes)
        for (index, arc) in arcs.enumerated() {
            if !set.contains(arc.from) || !set.contains(arc.to) { result.append(error(kind, "\(noun).endpoint", "Every \(noun) endpoint must name a node.", "model.\(noun)s.\(index)")) }
            if !arc.cost.isFinite || arc.cost < 0 { result.append(error(kind, "\(noun).value", "\(noun.capitalized) values must be finite and nonnegative.", "model.\(noun)s.\(index).cost")) }
        }
    }

    private static func completed(_ result: [ValidationDiagnostic], kind: NetworkProblemKind) -> [ValidationDiagnostic] {
        guard !result.contains(where: { $0.severity == .error }) else { return result }
        return result + [ValidationDiagnostic(severity: .info, code: "network.\(kind.rawValue).valid", message: "Network model is valid")]
    }

    private static func error(_ kind: NetworkProblemKind, _ suffix: String, _ message: String, _ path: String) -> ValidationDiagnostic { ValidationDiagnostic(severity: .error, code: "network.\(kind.rawValue).\(suffix)", message: message, path: path) }
}

public protocol NetworkBackend: Sendable {
    var capabilities: SolverCapabilities { get }
    func validationReport(for model: NetworkModelEnvelope) -> ValidationReport
    func solve(_ model: NetworkModelEnvelope, options: SolverOptions) throws -> NetworkSolutionEnvelope
    func runMetadata(for model: NetworkModelEnvelope) -> SolverRunMetadata
}

public extension NetworkBackend {
    func validationReport(for model: NetworkModelEnvelope) -> ValidationReport { ValidationReport(backend: capabilities.backendKind, diagnostics: NetworkValidator.diagnostics(for: model)) }
    func solve(_ model: NetworkModelEnvelope) throws -> NetworkSolutionEnvelope { try solve(model, options: SolverOptions()) }
    func solutionDocument(for model: NetworkModelEnvelope, solution: NetworkSolutionEnvelope) -> NetworkSolutionDocument { NetworkSolutionDocument(backend: runMetadata(for: model), model: model, solution: solution) }
}

public struct NativeEducationalNetworkBackend: NetworkBackend {
    public init() {}
    public var capabilities: SolverCapabilities { SolverCapabilities(backendKind: .nativeEducational, solves: true, validates: true, exportsStructuredSolution: true, notes: ["Deterministic educational network algorithms."]) }
    public func solve(_ model: NetworkModelEnvelope, options _: SolverOptions = SolverOptions()) throws -> NetworkSolutionEnvelope {
        try NetworkValidator.validate(model)
        switch model {
        case .minimumCostFlow(let value): return .minimumCostFlow(try MinimumCostNetworkFlowSolver.solve(value, linearProgrammingBackend: NativeEducationalLinearProgrammingBackend()))
        case .shortestPath(let value): return .shortestPath(try ShortestPathSolver.solve(value))
        case .minimumSpanningTree(let value): return .minimumSpanningTree(try MinimumSpanningTreeSolver.solve(value))
        case .maxFlow(let value): return .maxFlow(try MaxFlowSolver.solve(value))
        case .travelingSalesperson(let value): return .travelingSalesperson(try TravelingSalespersonSolver.solve(value))
        case .assignment(let value): return .assignment(try AssignmentSolver.solve(value))
        case .transportation(let value): return .transportation(try TransportationSolver.solve(value, linearProgrammingBackend: NativeEducationalLinearProgrammingBackend()))
        }
    }
    public func runMetadata(for model: NetworkModelEnvelope) -> SolverRunMetadata {
        switch model.kind {
        case .minimumCostFlow: SolverRunMetadata(backendKind: .nativeEducational, algorithm: "continuousLinearProgramming", exactness: .exact, notes: ["Minimum-cost transshipment solved through LinearProgrammingBackend; unbalanced totals use an explicit zero-cost dummy adjustment."])
        case .shortestPath: SolverRunMetadata(backendKind: .nativeEducational, algorithm: "dijkstra", exactness: .exact, notes: ["Directed nonnegative arcs; first and last nodes are default endpoints."])
        case .minimumSpanningTree: SolverRunMetadata(backendKind: .nativeEducational, algorithm: "kruskal", exactness: .exact, notes: ["Asymmetric entries are folded to the least-cost undirected edge."])
        case .maxFlow: SolverRunMetadata(backendKind: .nativeEducational, algorithm: "edmondsKarp", exactness: .exact, notes: ["Directed nonnegative capacities; first and last nodes are default endpoints."])
        case .travelingSalesperson: SolverRunMetadata(backendKind: .nativeEducational, algorithm: "heldKarpDynamicProgramming", exactness: .fixtureScale, notes: ["Exact for at most 20 nodes; directed and asymmetric arcs are supported."])
        case .assignment: SolverRunMetadata(backendKind: .nativeEducational, algorithm: "hungarianRectangular", exactness: .exact, notes: ["Requires at least as many tasks as workers."])
        case .transportation: SolverRunMetadata(backendKind: .nativeEducational, algorithm: "continuousLinearProgramming", exactness: .exact, notes: ["Balanced transportation model solved through LinearProgrammingBackend."])
        }
    }
}

public struct ValidateOnlyNetworkBackend: NetworkBackend {
    public init() {}
    public var capabilities: SolverCapabilities { SolverCapabilities(backendKind: .validateOnly, solves: false, validates: true, exportsStructuredSolution: false) }
    public func solve(_ model: NetworkModelEnvelope, options _: SolverOptions = SolverOptions()) throws -> NetworkSolutionEnvelope { throw NetworkModelError.invalidNetwork("validateOnly backend does not solve \(model.kind.rawValue)") }
    public func runMetadata(for model: NetworkModelEnvelope) -> SolverRunMetadata { SolverRunMetadata(backendKind: .validateOnly, algorithm: "validationOnly", exactness: .exact, notes: ["Validates \(model.kind.rawValue) without solving."]) }
}

public enum NetworkBackends {
    public static func backend(for kind: SolverBackendKind) -> (any NetworkBackend)? { switch kind { case .nativeEducational: NativeEducationalNetworkBackend(); case .validateOnly: ValidateOnlyNetworkBackend(); case .externalHighPerformance: nil } }
}

public extension NetworkModelJSON {
    static func encodeSolutionDocument(_ value: NetworkSolutionDocument) throws -> Data { try networkEncoder.encode(value) }
    static func decodeSolutionDocument(from data: Data) throws -> NetworkSolutionDocument { try JSONDecoder().decode(NetworkSolutionDocument.self, from: data) }
    static func encodeValidation(_ value: NetworkValidationDocument) throws -> Data { try networkEncoder.encode(value) }
    private static var networkEncoder: JSONEncoder { NormalizedJSONCoding.encoder() }
}
