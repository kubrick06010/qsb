import Foundation
extension InventoryModelEnvelope: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case model
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(InventoryProblemKind.self, forKey: .kind) {
        case .eoq:
            self = .eoq(try container.decode(EOQModel.self, forKey: .model))
        case .quantityDiscountEOQ:
            self = .quantityDiscountEOQ(try container.decode(QuantityDiscountEOQModel.self, forKey: .model))
        case .newsboy:
            self = .newsboy(try container.decode(NewsboyModel.self, forKey: .model))
        case .lotSizing:
            self = .lotSizing(try container.decode(LotSizingModel.self, forKey: .model))
        case .stochasticReview:
            self = .stochasticReview(try container.decode(StochasticInventoryModel.self, forKey: .model))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .eoq(let model):
            try container.encode(model, forKey: .model)
        case .quantityDiscountEOQ(let model):
            try container.encode(model, forKey: .model)
        case .newsboy(let model):
            try container.encode(model, forKey: .model)
        case .lotSizing(let model):
            try container.encode(model, forKey: .model)
        case .stochasticReview(let model):
            try container.encode(model, forKey: .model)
        }
    }
}

extension InventorySolutionEnvelope: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case solution
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(InventoryProblemKind.self, forKey: .kind) {
        case .eoq:
            self = .eoq(try container.decode(EOQSolution.self, forKey: .solution))
        case .quantityDiscountEOQ:
            self = .quantityDiscountEOQ(try container.decode(QuantityDiscountEOQSolution.self, forKey: .solution))
        case .newsboy:
            self = .newsboy(try container.decode(NewsboySolution.self, forKey: .solution))
        case .lotSizing:
            self = .lotSizing(try container.decode(LotSizingSolution.self, forKey: .solution))
        case .stochasticReview:
            self = .stochasticReview(try container.decode(StochasticInventorySolution.self, forKey: .solution))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .eoq(let solution):
            try container.encode(solution, forKey: .solution)
        case .quantityDiscountEOQ(let solution):
            try container.encode(solution, forKey: .solution)
        case .newsboy(let solution):
            try container.encode(solution, forKey: .solution)
        case .lotSizing(let solution):
            try container.encode(solution, forKey: .solution)
        case .stochasticReview(let solution):
            try container.encode(solution, forKey: .solution)
        }
    }
}

extension InventorySolutionDocument: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case backend
        case title
        case timeUnit
        case assumptions
        case solution
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(InventoryProblemKind.self, forKey: .kind)
        backend = try container.decode(SolverRunMetadata.self, forKey: .backend)
        title = try container.decode(String.self, forKey: .title)
        timeUnit = try container.decode(String.self, forKey: .timeUnit)
        assumptions = try container.decode([String].self, forKey: .assumptions)
        switch kind {
        case .eoq:
            solution = .eoq(try container.decode(EOQSolution.self, forKey: .solution))
        case .quantityDiscountEOQ:
            solution = .quantityDiscountEOQ(try container.decode(QuantityDiscountEOQSolution.self, forKey: .solution))
        case .newsboy:
            solution = .newsboy(try container.decode(NewsboySolution.self, forKey: .solution))
        case .lotSizing:
            solution = .lotSizing(try container.decode(LotSizingSolution.self, forKey: .solution))
        case .stochasticReview:
            solution = .stochasticReview(try container.decode(StochasticInventorySolution.self, forKey: .solution))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(backend, forKey: .backend)
        try container.encode(title, forKey: .title)
        try container.encode(timeUnit, forKey: .timeUnit)
        try container.encode(assumptions, forKey: .assumptions)
        switch solution {
        case .eoq(let solution):
            try container.encode(solution, forKey: .solution)
        case .quantityDiscountEOQ(let solution):
            try container.encode(solution, forKey: .solution)
        case .newsboy(let solution):
            try container.encode(solution, forKey: .solution)
        case .lotSizing(let solution):
            try container.encode(solution, forKey: .solution)
        case .stochasticReview(let solution):
            try container.encode(solution, forKey: .solution)
        }
    }
}

public enum InventoryModelJSON {
    public static func decodeUncheckedModel(from data: Data) throws -> InventoryModelEnvelope {
        try decoder.decode(InventoryModelEnvelope.self, from: data)
    }

    public static func decodeModel(from data: Data) throws -> InventoryModelEnvelope {
        let envelope = try decodeUncheckedModel(from: data)
        try InventoryValidator.validate(envelope)
        return envelope
    }

    public static func encodeModel(_ envelope: InventoryModelEnvelope) throws -> Data {
        try encoder.encode(envelope)
    }

    public static func encodeSolutionDocument(_ document: InventorySolutionDocument) throws -> Data {
        try encoder.encode(document)
    }

    public static func decodeSolutionDocument(from data: Data) throws -> InventorySolutionDocument {
        try decoder.decode(InventorySolutionDocument.self, from: data)
    }

    public static func validationDocument(
        for envelope: InventoryModelEnvelope,
        backend: SolverBackendKind = .validateOnly
    ) -> InventoryValidationDocument {
        InventoryValidationDocument(
            kind: envelope.kind,
            backend: backend,
            diagnostics: InventoryValidator.diagnostics(for: envelope)
        )
    }

    public static func encodeValidation(_ document: InventoryValidationDocument) throws -> Data {
        try encoder.encode(document)
    }

    private static var encoder: JSONEncoder { NormalizedJSONCoding.encoder() }

    private static var decoder: JSONDecoder { JSONDecoder() }
}
