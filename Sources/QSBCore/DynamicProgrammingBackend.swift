import Foundation

public enum DynamicProgrammingProblemKind: String, Codable, CaseIterable, Sendable {
    case boundedKnapsack
    case stagecoach
    case productionInventory
}

public enum DynamicProgrammingModelEnvelope: Equatable, Sendable {
    case boundedKnapsack(KnapsackProblem)
    case stagecoach(StagecoachProblem)
    case productionInventory(ProductionInventoryProblem)

    public var kind: DynamicProgrammingProblemKind {
        switch self {
        case .boundedKnapsack: .boundedKnapsack
        case .stagecoach: .stagecoach
        case .productionInventory: .productionInventory
        }
    }

    public var title: String {
        switch self {
        case .boundedKnapsack(let model): model.title
        case .stagecoach(let model): model.title
        case .productionInventory(let model): model.title
        }
    }
}

public struct DynamicProgrammingTraceStep: Codable, Equatable, Sendable {
    public let stage: String
    public let state: String
    public let action: String
    public let nextState: String?
    public let value: Double

    public init(stage: String, state: String, action: String, nextState: String?, value: Double) {
        self.stage = stage
        self.state = state
        self.action = action
        self.nextState = nextState
        self.value = value
    }
}

public enum DynamicProgrammingSolutionEnvelope: Equatable, Sendable {
    case boundedKnapsack(KnapsackSolution, trace: [DynamicProgrammingTraceStep])
    case stagecoach(StagecoachSolution, trace: [DynamicProgrammingTraceStep])
    case productionInventory(ProductionInventorySolution, trace: [DynamicProgrammingTraceStep])

    public var kind: DynamicProgrammingProblemKind {
        switch self {
        case .boundedKnapsack: .boundedKnapsack
        case .stagecoach: .stagecoach
        case .productionInventory: .productionInventory
        }
    }

    public var trace: [DynamicProgrammingTraceStep] {
        switch self {
        case .boundedKnapsack(_, let trace), .stagecoach(_, let trace), .productionInventory(_, let trace): trace
        }
    }
}

public struct DynamicProgrammingSolutionDocument: Codable, Equatable, Sendable {
    public let backend: SolverRunMetadata
    public let title: String
    public let assumptions: [String]
    public let solution: DynamicProgrammingSolutionEnvelope
}

public struct DynamicProgrammingValidationDocument: Codable, Equatable, Sendable {
    public let kind: DynamicProgrammingProblemKind
    public let backend: SolverBackendKind
    public let isValid: Bool
    public let diagnostics: [ValidationDiagnostic]

    public init(
        kind: DynamicProgrammingProblemKind,
        backend: SolverBackendKind,
        diagnostics: [ValidationDiagnostic]
    ) {
        self.kind = kind
        self.backend = backend
        self.isValid = !diagnostics.contains { $0.severity == .error }
        self.diagnostics = diagnostics
    }
}

extension DynamicProgrammingModelEnvelope: Codable {
    private enum CodingKeys: String, CodingKey { case kind, model }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(DynamicProgrammingProblemKind.self, forKey: .kind) {
        case .boundedKnapsack: self = .boundedKnapsack(try container.decode(KnapsackProblem.self, forKey: .model))
        case .stagecoach: self = .stagecoach(try container.decode(StagecoachProblem.self, forKey: .model))
        case .productionInventory: self = .productionInventory(try container.decode(ProductionInventoryProblem.self, forKey: .model))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .boundedKnapsack(let model): try container.encode(model, forKey: .model)
        case .stagecoach(let model): try container.encode(model, forKey: .model)
        case .productionInventory(let model): try container.encode(model, forKey: .model)
        }
    }
}

extension DynamicProgrammingSolutionEnvelope: Codable {
    private enum CodingKeys: String, CodingKey { case kind, result, trace }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let trace = try container.decode([DynamicProgrammingTraceStep].self, forKey: .trace)
        switch try container.decode(DynamicProgrammingProblemKind.self, forKey: .kind) {
        case .boundedKnapsack: self = .boundedKnapsack(try container.decode(KnapsackSolution.self, forKey: .result), trace: trace)
        case .stagecoach: self = .stagecoach(try container.decode(StagecoachSolution.self, forKey: .result), trace: trace)
        case .productionInventory: self = .productionInventory(try container.decode(ProductionInventorySolution.self, forKey: .result), trace: trace)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(trace, forKey: .trace)
        switch self {
        case .boundedKnapsack(let result, _): try container.encode(result, forKey: .result)
        case .stagecoach(let result, _): try container.encode(result, forKey: .result)
        case .productionInventory(let result, _): try container.encode(result, forKey: .result)
        }
    }
}

public enum DynamicProgrammingModelJSON {
    public static func decodeUncheckedModel(from data: Data) throws -> DynamicProgrammingModelEnvelope {
        try JSONDecoder().decode(DynamicProgrammingModelEnvelope.self, from: data)
    }

    public static func decodeModel(from data: Data) throws -> DynamicProgrammingModelEnvelope {
        let model = try decodeUncheckedModel(from: data)
        try DynamicProgrammingValidator.validate(model)
        return model
    }

    public static func encodeModel(_ model: DynamicProgrammingModelEnvelope) throws -> Data { try encoder.encode(model) }
    public static func encodeSolutionDocument(_ document: DynamicProgrammingSolutionDocument) throws -> Data { try encoder.encode(document) }
    public static func decodeSolutionDocument(from data: Data) throws -> DynamicProgrammingSolutionDocument { try JSONDecoder().decode(DynamicProgrammingSolutionDocument.self, from: data) }
    public static func encodeValidation(_ document: DynamicProgrammingValidationDocument) throws -> Data { try encoder.encode(document) }

    public static func validationDocument(
        for model: DynamicProgrammingModelEnvelope,
        backend: SolverBackendKind = .validateOnly
    ) -> DynamicProgrammingValidationDocument {
        DynamicProgrammingValidationDocument(kind: model.kind, backend: backend, diagnostics: DynamicProgrammingValidator.diagnostics(for: model))
    }

    private static var encoder: JSONEncoder { NormalizedJSONCoding.encoder() }
}

public enum KnapsackValidator {
    public static func diagnostics(for model: KnapsackProblem) -> [ValidationDiagnostic] {
        var result = titleDiagnostics(model.title, prefix: "dynamicProgramming.boundedKnapsack")
        if model.capacity <= 0 { result.append(dpError("dynamicProgramming.boundedKnapsack.capacity.nonpositive", "Capacity must be positive.", "model.capacity")) }
        if model.items.isEmpty { result.append(dpError("dynamicProgramming.boundedKnapsack.items.empty", "At least one item is required.", "model.items")) }
        var names: Set<String> = []
        for (index, item) in model.items.enumerated() {
            let path = "model.items[\(index)]"
            if item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result.append(dpError("dynamicProgramming.boundedKnapsack.item.name.empty", "Item names must not be empty.", "\(path).name")) }
            else if !names.insert(item.name).inserted { result.append(dpError("dynamicProgramming.boundedKnapsack.item.name.duplicate", "Item names must be unique.", "\(path).name")) }
            if item.available < 0 { result.append(dpError("dynamicProgramming.boundedKnapsack.item.available.negative", "Item availability must be nonnegative.", "\(path).available")) }
            if item.capacityRequired <= 0 { result.append(dpError("dynamicProgramming.boundedKnapsack.item.capacity.nonpositive", "Item capacity requirement must be positive.", "\(path).capacityRequired")) }
            if !item.returnPerUnit.isFinite { result.append(dpError("dynamicProgramming.boundedKnapsack.item.return.nonfinite", "Item return must be finite.", "\(path).returnPerUnit")) }
        }
        return result
    }
    public static func validate(_ model: KnapsackProblem) throws { try throwFirstDPError(diagnostics(for: model)) }
}

public enum StagecoachValidator {
    public static func diagnostics(for model: StagecoachProblem) -> [ValidationDiagnostic] {
        var result = titleDiagnostics(model.title, prefix: "dynamicProgramming.stagecoach")
        if model.nodes.count < 2 { result.append(dpError("dynamicProgramming.stagecoach.nodes.insufficient", "At least two nodes are required.", "model.nodes")) }
        if Set(model.nodes).count != model.nodes.count { result.append(dpError("dynamicProgramming.stagecoach.nodes.duplicate", "Node names must be unique.", "model.nodes")) }
        if model.nodes.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { result.append(dpError("dynamicProgramming.stagecoach.node.name.empty", "Node names must not be empty.", "model.nodes")) }
        let nodeSet = Set(model.nodes)
        for (index, arc) in model.arcs.enumerated() {
            let path = "model.arcs[\(index)]"
            if !nodeSet.contains(arc.from) || !nodeSet.contains(arc.to) { result.append(dpError("dynamicProgramming.stagecoach.arc.node.unknown", "Arcs must reference declared nodes.", path)) }
            if !arc.cost.isFinite || arc.cost < 0 { result.append(dpError("dynamicProgramming.stagecoach.arc.cost.invalid", "Arc costs must be finite and nonnegative.", "\(path).cost")) }
            if let from = model.nodes.firstIndex(of: arc.from), let to = model.nodes.firstIndex(of: arc.to), to <= from { result.append(dpError("dynamicProgramming.stagecoach.arc.order.invalid", "Arcs must advance through the declared stage order.", path)) }
        }
        return result
    }
    public static func validate(_ model: StagecoachProblem) throws { try throwFirstDPError(diagnostics(for: model)) }
}

public enum ProductionInventoryValidator {
    public static func diagnostics(for model: ProductionInventoryProblem) -> [ValidationDiagnostic] {
        var result = titleDiagnostics(model.title, prefix: "dynamicProgramming.productionInventory")
        if model.periods.isEmpty { result.append(dpError("dynamicProgramming.productionInventory.periods.empty", "At least one period is required.", "model.periods")) }
        var names: Set<String> = []
        for (index, period) in model.periods.enumerated() {
            let path = "model.periods[\(index)]"
            if period.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result.append(dpError("dynamicProgramming.productionInventory.period.name.empty", "Period names must not be empty.", "\(path).name")) }
            else if !names.insert(period.name).inserted { result.append(ValidationDiagnostic(severity: .warning, code: "dynamicProgramming.productionInventory.period.name.duplicate", message: "Period names should be unique.", path: "\(path).name")) }
            if period.demand < 0 { result.append(dpError("dynamicProgramming.productionInventory.period.demand.negative", "Demand must be nonnegative.", "\(path).demand")) }
            if period.productionCapacity < 0 { result.append(dpError("dynamicProgramming.productionInventory.period.productionCapacity.negative", "Production capacity must be nonnegative.", "\(path).productionCapacity")) }
            if period.storageCapacity < 0 { result.append(dpError("dynamicProgramming.productionInventory.period.storageCapacity.negative", "Storage capacity must be nonnegative.", "\(path).storageCapacity")) }
            for (name, value) in [("setupCost", period.setupCost), ("productionUnitCost", period.productionUnitCost), ("holdingUnitCost", period.holdingUnitCost)] where !value.isFinite || value < 0 {
                result.append(dpError("dynamicProgramming.productionInventory.period.\(name).invalid", "Costs must be finite and nonnegative.", "\(path).\(name)"))
            }
        }
        return result
    }
    public static func validate(_ model: ProductionInventoryProblem) throws { try throwFirstDPError(diagnostics(for: model)) }
}

public enum DynamicProgrammingValidator {
    public static func diagnostics(for model: DynamicProgrammingModelEnvelope) -> [ValidationDiagnostic] {
        switch model {
        case .boundedKnapsack(let value): KnapsackValidator.diagnostics(for: value)
        case .stagecoach(let value): StagecoachValidator.diagnostics(for: value)
        case .productionInventory(let value): ProductionInventoryValidator.diagnostics(for: value)
        }
    }
    public static func validate(_ model: DynamicProgrammingModelEnvelope) throws { try throwFirstDPError(diagnostics(for: model)) }
}

public protocol DynamicProgrammingBackend: Sendable {
    var capabilities: SolverCapabilities { get }
    func validationReport(for model: DynamicProgrammingModelEnvelope) -> ValidationReport
    func solve(_ model: DynamicProgrammingModelEnvelope, options: SolverOptions) throws -> DynamicProgrammingSolutionEnvelope
    func runMetadata(for model: DynamicProgrammingModelEnvelope) -> SolverRunMetadata
}

public extension DynamicProgrammingBackend {
    func validationReport(for model: DynamicProgrammingModelEnvelope) -> ValidationReport {
        ValidationReport(backend: capabilities.backendKind, diagnostics: DynamicProgrammingValidator.diagnostics(for: model))
    }
    func solve(_ model: DynamicProgrammingModelEnvelope) throws -> DynamicProgrammingSolutionEnvelope { try solve(model, options: SolverOptions()) }
    func solutionDocument(for model: DynamicProgrammingModelEnvelope, solution: DynamicProgrammingSolutionEnvelope) -> DynamicProgrammingSolutionDocument {
        DynamicProgrammingSolutionDocument(backend: runMetadata(for: model), title: model.title, assumptions: dpAssumptions(for: model.kind), solution: solution)
    }
}

public struct NativeEducationalDynamicProgrammingBackend: DynamicProgrammingBackend {
    public init() {}
    public var capabilities: SolverCapabilities { SolverCapabilities(backendKind: .nativeEducational, solves: true, validates: true, exportsStructuredSolution: true, notes: ["Uses deterministic fixture-scale dynamic programming with policy reconstruction."]) }

    public func solve(_ model: DynamicProgrammingModelEnvelope, options _: SolverOptions = SolverOptions()) throws -> DynamicProgrammingSolutionEnvelope {
        try DynamicProgrammingValidator.validate(model)
        switch model {
        case .boundedKnapsack(let problem):
            let solution = try KnapsackSolver.solve(problem)
            return .boundedKnapsack(solution, trace: knapsackTrace(problem: problem, solution: solution))
        case .stagecoach(let problem):
            let solution = try StagecoachSolver.solve(problem)
            return .stagecoach(solution, trace: stagecoachTrace(problem: problem, solution: solution))
        case .productionInventory(let problem):
            let solution = try ProductionInventorySolver.solve(problem)
            return .productionInventory(solution, trace: productionInventoryTrace(solution))
        }
    }

    public func runMetadata(for model: DynamicProgrammingModelEnvelope) -> SolverRunMetadata {
        let algorithm: String
        switch model.kind {
        case .boundedKnapsack: algorithm = "boundedKnapsackDynamicProgramming"
        case .stagecoach: algorithm = "orderedAcyclicShortestPathDynamicProgramming"
        case .productionInventory: algorithm = "finiteHorizonProductionInventoryDynamicProgramming"
        }
        return SolverRunMetadata(backendKind: .nativeEducational, algorithm: algorithm, exactness: .fixtureScale, notes: dpAssumptions(for: model.kind))
    }
}

public struct ValidateOnlyDynamicProgrammingBackend: DynamicProgrammingBackend {
    public init() {}
    public var capabilities: SolverCapabilities { SolverCapabilities(backendKind: .validateOnly, solves: false, validates: true, exportsStructuredSolution: false, notes: ["Validates dynamic-programming models without solving them."]) }
    public func solve(_ model: DynamicProgrammingModelEnvelope, options _: SolverOptions = SolverOptions()) throws -> DynamicProgrammingSolutionEnvelope { throw DynamicProgrammingModelError.invalidModel("validateOnly backend does not solve \(model.kind.rawValue) models") }
    public func runMetadata(for model: DynamicProgrammingModelEnvelope) -> SolverRunMetadata { SolverRunMetadata(backendKind: .validateOnly, algorithm: "validationOnly", exactness: .exact, notes: ["Validates the \(model.kind.rawValue) model without solving it."]) }
}

public enum DynamicProgrammingBackends {
    public static func backend(for kind: SolverBackendKind) -> (any DynamicProgrammingBackend)? {
        switch kind {
        case .nativeEducational: NativeEducationalDynamicProgrammingBackend()
        case .validateOnly: ValidateOnlyDynamicProgrammingBackend()
        case .externalHighPerformance: nil
        }
    }
}

public extension WinQSBDynamicProgrammingParser {
    static func parseModelEnvelope(from data: Data) throws -> DynamicProgrammingModelEnvelope {
        guard let text = data.legacyLatin1String, let first = text.split(whereSeparator: { $0.isNewline }).first else { throw DynamicProgrammingModelError.unsupportedFormat }
        let fields = first.split(separator: "\t", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        guard fields.count >= 3, fields[0] == "DP" else { throw DynamicProgrammingModelError.unsupportedFormat }
        switch fields[2] {
        case "KS": return .boundedKnapsack(try parseKnapsack(from: data))
        case "SC": return .stagecoach(try parseStagecoach(from: data))
        case "PIS": return .productionInventory(try parseProductionInventory(from: data))
        default: throw DynamicProgrammingModelError.unsupportedFormat
        }
    }
}

private func titleDiagnostics(_ title: String, prefix: String) -> [ValidationDiagnostic] {
    title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [ValidationDiagnostic(severity: .warning, code: "\(prefix).title.empty", message: "Model title is empty.", path: "model.title")] : []
}
private func dpError(_ code: String, _ message: String, _ path: String) -> ValidationDiagnostic { ValidationDiagnostic(severity: .error, code: code, message: message, path: path) }
private func throwFirstDPError(_ diagnostics: [ValidationDiagnostic]) throws {
    if let diagnostic = diagnostics.first(where: { $0.severity == .error }) { throw DynamicProgrammingModelError.invalidModel(diagnostic.message) }
}
private func dpAssumptions(for kind: DynamicProgrammingProblemKind) -> [String] {
    switch kind {
    case .boundedKnapsack: ["Integer bounded item quantities and integer capacity at fixture scale."]
    case .stagecoach: ["Directed acyclic arcs advance through the declared node order; first and last nodes are source and sink."]
    case .productionInventory: ["Integer production and inventory, zero initial inventory, and zero terminal inventory."]
    }
}
private func knapsackTrace(problem: KnapsackProblem, solution: KnapsackSolution) -> [DynamicProgrammingTraceStep] {
    var remaining = problem.capacity
    let quantities = Dictionary(uniqueKeysWithValues: solution.selections.map { ($0.item, $0.quantity) })
    return problem.items.enumerated().map { index, item in
        let quantity = quantities[item.name, default: 0]
        let next = remaining - quantity * item.capacityRequired
        defer { remaining = next }
        return DynamicProgrammingTraceStep(stage: "item[\(index)] \(item.name)", state: "remainingCapacity=\(remaining)", action: "select=\(quantity)", nextState: "remainingCapacity=\(next)", value: Double(quantity) * item.returnPerUnit)
    }
}
private func stagecoachTrace(problem: StagecoachProblem, solution: StagecoachSolution) -> [DynamicProgrammingTraceStep] {
    zip(solution.path, solution.path.dropFirst()).enumerated().map { index, pair in
        let cost = problem.arcs.first { $0.from == pair.0 && $0.to == pair.1 }?.cost ?? 0
        return DynamicProgrammingTraceStep(stage: "arc[\(index)]", state: pair.0, action: "travelTo=\(pair.1)", nextState: pair.1, value: cost)
    }
}
private func productionInventoryTrace(_ solution: ProductionInventorySolution) -> [DynamicProgrammingTraceStep] {
    solution.decisions.map { decision in DynamicProgrammingTraceStep(stage: decision.period, state: "inventory=\(decision.beginningInventory)", action: "produce=\(decision.productionQuantity)", nextState: "inventory=\(decision.endingInventory)", value: decision.cost) }
}
