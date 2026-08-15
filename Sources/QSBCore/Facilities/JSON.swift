import Foundation

public enum LineBalancingJSON {
    public static func decodeModel(from data: Data) throws -> LineBalancingProblem {
        let problem = try decoder.decode(LineBalancingProblem.self, from: data)
        try LineBalancingValidator.validate(problem)
        return problem
    }

    public static func encodeModel(_ problem: LineBalancingProblem) throws -> Data {
        try encoder.encode(problem)
    }

    public static func encodeSolution(_ solution: LineBalancingSolution) throws -> Data {
        try encoder.encode(solution)
    }

    private static var encoder: JSONEncoder { NormalizedJSONCoding.encoder() }

    private static var decoder: JSONDecoder {
        JSONDecoder()
    }
}

public enum FacilityLocationJSON {
    public static func decodeModel(from data: Data) throws -> FacilityLocationProblem {
        let problem = try decoder.decode(FacilityLocationProblem.self, from: data)
        try FacilityLocationValidator.validate(problem)
        return problem
    }

    public static func encodeModel(_ problem: FacilityLocationProblem) throws -> Data {
        try encoder.encode(problem)
    }

    public static func encodeSolution(_ solution: FacilityLocationSolution) throws -> Data {
        try encoder.encode(solution)
    }

    private static var encoder: JSONEncoder { NormalizedJSONCoding.encoder() }

    private static var decoder: JSONDecoder {
        JSONDecoder()
    }
}

public enum FacilitiesSolutionEnvelope: Equatable, Sendable {
    case lineBalancing(LineBalancingSolution)
    case location(FacilityLocationSolution)
    case layout(FacilityLayoutSolution)

    public var kind: FacilitiesProblemKind {
        switch self {
        case .lineBalancing:
            .lineBalancing
        case .location:
            .location
        case .layout:
            .layout
        }
    }
}

public struct FacilitiesSolutionDocument: Equatable, Sendable {
    public let backend: SolverRunMetadata
    public let solution: FacilitiesSolutionEnvelope

    public init(backend: SolverRunMetadata, solution: FacilitiesSolutionEnvelope) {
        self.backend = backend
        self.solution = solution
    }

    public var kind: FacilitiesProblemKind {
        solution.kind
    }
}

public struct FacilitiesValidationDocument: Codable, Equatable, Sendable {
    public let kind: FacilitiesProblemKind
    public let backend: SolverBackendKind
    public let isValid: Bool
    public let diagnostics: [ValidationDiagnostic]

    public init(
        kind: FacilitiesProblemKind,
        backend: SolverBackendKind = .validateOnly,
        diagnostics: [ValidationDiagnostic]
    ) {
        self.kind = kind
        self.backend = backend
        self.isValid = !diagnostics.contains { $0.severity == .error }
        self.diagnostics = diagnostics
    }
}

extension FacilitiesModelEnvelope: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case model
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(FacilitiesProblemKind.self, forKey: .kind)
        switch kind {
        case .lineBalancing:
            self = .lineBalancing(try container.decode(LineBalancingProblem.self, forKey: .model))
        case .location:
            self = .location(try container.decode(FacilityLocationProblem.self, forKey: .model))
        case .layout:
            self = .layout(try container.decode(FacilityLayoutProblem.self, forKey: .model))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .lineBalancing(let model):
            try container.encode(model, forKey: .model)
        case .location(let model):
            try container.encode(model, forKey: .model)
        case .layout(let model):
            try container.encode(model, forKey: .model)
        }
    }
}

extension FacilitiesSolutionEnvelope: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case solution
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(FacilitiesProblemKind.self, forKey: .kind)
        switch kind {
        case .lineBalancing:
            self = .lineBalancing(try container.decode(LineBalancingSolution.self, forKey: .solution))
        case .location:
            self = .location(try container.decode(FacilityLocationSolution.self, forKey: .solution))
        case .layout:
            self = .layout(try container.decode(FacilityLayoutSolution.self, forKey: .solution))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .lineBalancing(let solution):
            try container.encode(solution, forKey: .solution)
        case .location(let solution):
            try container.encode(solution, forKey: .solution)
        case .layout(let solution):
            try container.encode(solution, forKey: .solution)
        }
    }
}

extension FacilitiesSolutionDocument: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case backend
        case solution
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(FacilitiesProblemKind.self, forKey: .kind)
        backend = try container.decode(SolverRunMetadata.self, forKey: .backend)
        switch kind {
        case .lineBalancing:
            solution = .lineBalancing(try container.decode(LineBalancingSolution.self, forKey: .solution))
        case .location:
            solution = .location(try container.decode(FacilityLocationSolution.self, forKey: .solution))
        case .layout:
            solution = .layout(try container.decode(FacilityLayoutSolution.self, forKey: .solution))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(backend, forKey: .backend)
        switch solution {
        case .lineBalancing(let solution):
            try container.encode(solution, forKey: .solution)
        case .location(let solution):
            try container.encode(solution, forKey: .solution)
        case .layout(let solution):
            try container.encode(solution, forKey: .solution)
        }
    }
}

public enum FacilitiesModelJSON {
    public static func decodeUncheckedModel(from data: Data) throws -> FacilitiesModelEnvelope {
        try decoder.decode(FacilitiesModelEnvelope.self, from: data)
    }

    public static func decodeModel(from data: Data) throws -> FacilitiesModelEnvelope {
        let envelope = try decodeUncheckedModel(from: data)
        try validate(envelope)
        return envelope
    }

    public static func encodeModel(_ envelope: FacilitiesModelEnvelope) throws -> Data {
        try encoder.encode(envelope)
    }

    public static func encodeSolution(_ envelope: FacilitiesSolutionEnvelope) throws -> Data {
        try encoder.encode(envelope)
    }

    public static func encodeSolutionDocument(_ document: FacilitiesSolutionDocument) throws -> Data {
        try encoder.encode(document)
    }

    public static func decodeSolutionDocument(from data: Data) throws -> FacilitiesSolutionDocument {
        try decoder.decode(FacilitiesSolutionDocument.self, from: data)
    }

    public static func validationDocument(
        for envelope: FacilitiesModelEnvelope,
        backend: SolverBackendKind = .validateOnly
    ) -> FacilitiesValidationDocument {
        FacilitiesValidationDocument(
            kind: envelope.kind,
            backend: backend,
            diagnostics: diagnostics(for: envelope)
        )
    }

    public static func encodeValidation(_ document: FacilitiesValidationDocument) throws -> Data {
        try encoder.encode(document)
    }

    private static func validate(_ envelope: FacilitiesModelEnvelope) throws {
        switch envelope {
        case .lineBalancing(let problem):
            try LineBalancingValidator.validate(problem)
        case .location(let problem):
            try FacilityLocationValidator.validate(problem)
        case .layout(let problem):
            try FacilityLayoutValidator.validate(problem)
        }
    }

    private static func diagnostics(for envelope: FacilitiesModelEnvelope) -> [ValidationDiagnostic] {
        switch envelope {
        case .lineBalancing(let problem):
            LineBalancingValidator.diagnostics(for: problem)
        case .location(let problem):
            FacilityLocationValidator.diagnostics(for: problem)
        case .layout(let problem):
            FacilityLayoutValidator.diagnostics(for: problem)
        }
    }

    private static var encoder: JSONEncoder { NormalizedJSONCoding.encoder() }

    private static var decoder: JSONDecoder {
        JSONDecoder()
    }
}

public enum FacilityLayoutJSON {
    public static func decodeModel(from data: Data) throws -> FacilityLayoutProblem {
        let problem = try decoder.decode(FacilityLayoutProblem.self, from: data)
        try FacilityLayoutValidator.validate(problem)
        return problem
    }

    public static func encodeModel(_ problem: FacilityLayoutProblem) throws -> Data {
        try encoder.encode(problem)
    }

    public static func encodeSolution(_ solution: FacilityLayoutSolution) throws -> Data {
        try encoder.encode(solution)
    }

    private static var encoder: JSONEncoder { NormalizedJSONCoding.encoder() }

    private static var decoder: JSONDecoder {
        JSONDecoder()
    }
}

