import Foundation

public enum SchedulingModelEnvelope: Codable, Equatable, Sendable {
    case flowShop(FlowShopProblem)
    case jobShop(JobShopProblem)

    private enum CodingKeys: String, CodingKey { case kind, model }
    public var kind: SchedulingProblemKind { switch self { case .flowShop: .flowShop; case .jobShop: .jobShop } }
    public var title: String { switch self { case .flowShop(let model): model.title; case .jobShop(let model): model.title } }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(SchedulingProblemKind.self, forKey: .kind) {
        case .flowShop: self = .flowShop(try container.decode(FlowShopProblem.self, forKey: .model))
        case .jobShop: self = .jobShop(try container.decode(JobShopProblem.self, forKey: .model))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self { case .flowShop(let model): try container.encode(model, forKey: .model); case .jobShop(let model): try container.encode(model, forKey: .model) }
    }
}

public struct SchedulingValidationDocument: Codable, Equatable, Sendable {
    public let kind: SchedulingProblemKind
    public let backend: SolverBackendKind
    public let isValid: Bool
    public let diagnostics: [ValidationDiagnostic]
    public init(kind: SchedulingProblemKind, backend: SolverBackendKind, diagnostics: [ValidationDiagnostic]) { self.kind = kind; self.backend = backend; self.isValid = !diagnostics.contains { $0.severity == .error }; self.diagnostics = diagnostics }
}

public extension SchedulingBackend {
    func validationReport(for model: SchedulingModelEnvelope) -> ValidationReport { switch model { case .flowShop(let problem): validationReport(for: problem); case .jobShop(let problem): validationReport(for: problem) } }
    func solve(_ model: SchedulingModelEnvelope, options: SolverOptions = SolverOptions()) throws -> SchedulingSolutionDocument {
        switch model {
        case .flowShop(let problem):
            let solution = try solve(problem, options: options)
            return SchedulingSolutionJSON.flowShopDocument(problem: problem, solution: solution, backend: schedulingMetadata(kind: .flowShop))
        case .jobShop(let problem):
            let solution = try solve(problem, options: options)
            return SchedulingSolutionJSON.jobShopDocument(problem: problem, solution: solution, backend: schedulingMetadata(kind: .jobShop))
        }
    }
    private func schedulingMetadata(kind: SchedulingProblemKind) -> SolverRunMetadata {
        SolverRunMetadata(backendKind: capabilities.backendKind, algorithm: kind == .flowShop ? "flowShopPermutationSearch" : "jobShopBranchAndBoundDominancePruning", exactness: .fixtureScale, notes: ["Exact educational search for preserved fixture-scale scheduling models."])
    }
}

public enum SchedulingModelJSON {
    public static func encodeModel(_ value: SchedulingModelEnvelope) throws -> Data { try encoder.encode(value) }
    public static func decodeModel(from data: Data) throws -> SchedulingModelEnvelope { try JSONDecoder().decode(SchedulingModelEnvelope.self, from: data) }
    public static func encodeSolution(_ value: SchedulingSolutionDocument) throws -> Data { try SchedulingSolutionJSON.encode(value) }
    public static func decodeSolution(from data: Data) throws -> SchedulingSolutionDocument { try JSONDecoder().decode(SchedulingSolutionDocument.self, from: data) }
    public static func encodeValidation(_ value: SchedulingValidationDocument) throws -> Data { try encoder.encode(value) }
    private static var encoder: JSONEncoder { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; return encoder }
}

public extension WinQSBSchedulingParser {
    static func parseModelEnvelope(from data: Data) throws -> SchedulingModelEnvelope {
        if let model = try? parseFlowShop(from: data) { return .flowShop(model) }
        return .jobShop(try parseJobShop(from: data))
    }
}

public enum QueuingModelEnvelope: Codable, Equatable, Sendable {
    case mm1(MM1QueueModel)
    case finiteCapacity(FiniteCapacityQueueModel)

    private enum CodingKeys: String, CodingKey { case kind, model }
    public var kind: QueuingProblemKind { switch self { case .mm1: .mm1; case .finiteCapacity: .finiteCapacity } }
    public var title: String { switch self { case .mm1(let model): model.title; case .finiteCapacity(let model): model.title } }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(QueuingProblemKind.self, forKey: .kind) {
        case .mm1: self = .mm1(try container.decode(MM1QueueModel.self, forKey: .model))
        case .finiteCapacity: self = .finiteCapacity(try container.decode(FiniteCapacityQueueModel.self, forKey: .model))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self { case .mm1(let model): try container.encode(model, forKey: .model); case .finiteCapacity(let model): try container.encode(model, forKey: .model) }
    }
}

public struct QueuingValidationDocument: Codable, Equatable, Sendable {
    public let kind: QueuingProblemKind
    public let backend: SolverBackendKind
    public let isValid: Bool
    public let diagnostics: [ValidationDiagnostic]
    public init(kind: QueuingProblemKind, backend: SolverBackendKind, diagnostics: [ValidationDiagnostic]) { self.kind = kind; self.backend = backend; self.isValid = !diagnostics.contains { $0.severity == .error }; self.diagnostics = diagnostics }
}

public extension QueuingBackend {
    func validationReport(for model: QueuingModelEnvelope) -> ValidationReport { switch model { case .mm1(let queue): validationReport(for: queue); case .finiteCapacity(let queue): validationReport(for: queue) } }
    func solve(_ model: QueuingModelEnvelope, options: SolverOptions = SolverOptions()) throws -> QueuingSolutionDocument {
        switch model {
        case .mm1(let queue):
            let solution = try solve(queue, options: options)
            return QueuingSolutionJSON.mm1Document(model: queue, solution: solution, backend: queuingMetadata(kind: .mm1))
        case .finiteCapacity(let queue):
            let solution = try solve(queue, options: options)
            return QueuingSolutionJSON.finiteCapacityDocument(model: queue, solution: solution, backend: queuingMetadata(kind: .finiteCapacity))
        }
    }
    private func queuingMetadata(kind: QueuingProblemKind) -> SolverRunMetadata {
        SolverRunMetadata(backendKind: capabilities.backendKind, algorithm: kind == .mm1 ? "mm1ClosedForm" : "finiteStateBirthDeathApproximation", exactness: kind == .mm1 ? .closedForm : .approximate, notes: [kind == .mm1 ? "Exact steady-state M/M/1 equations." : "Finite-state approximation using mean arrival and service rates."])
    }
}

public enum QueuingModelJSON {
    public static func encodeModel(_ value: QueuingModelEnvelope) throws -> Data { try encoder.encode(value) }
    public static func decodeModel(from data: Data) throws -> QueuingModelEnvelope { try JSONDecoder().decode(QueuingModelEnvelope.self, from: data) }
    public static func encodeSolution(_ value: QueuingSolutionDocument) throws -> Data { try QueuingSolutionJSON.encode(value) }
    public static func encodeValidation(_ value: QueuingValidationDocument) throws -> Data { try encoder.encode(value) }
    private static var encoder: JSONEncoder { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; return encoder }
}

public extension WinQSBQueuingParser {
    static func parseModelEnvelope(from data: Data) throws -> QueuingModelEnvelope {
        if let model = try? parseMM1(from: data) { return .mm1(model) }
        return .finiteCapacity(try parseFiniteCapacity(from: data))
    }
}
