import Foundation
public protocol InventoryBackend: Sendable {
    var capabilities: SolverCapabilities { get }

    func validationReport(for model: EOQModel) -> ValidationReport
    func validationReport(for model: QuantityDiscountEOQModel) -> ValidationReport
    func validationReport(for model: NewsboyModel) -> ValidationReport
    func validationReport(for model: LotSizingModel) -> ValidationReport
    func validationReport(for model: StochasticInventoryModel) -> ValidationReport

    func solve(_ model: EOQModel, options: SolverOptions) throws -> EOQSolution
    func solve(_ model: QuantityDiscountEOQModel, options: SolverOptions) throws -> QuantityDiscountEOQSolution
    func solve(_ model: NewsboyModel, options: SolverOptions) throws -> NewsboySolution
    func solve(_ model: LotSizingModel, options: SolverOptions) throws -> LotSizingSolution
    func solve(_ model: StochasticInventoryModel, options: SolverOptions) throws -> StochasticInventorySolution

    func runMetadata(for model: EOQModel) -> SolverRunMetadata
    func runMetadata(for model: QuantityDiscountEOQModel) -> SolverRunMetadata
    func runMetadata(for model: NewsboyModel) -> SolverRunMetadata
    func runMetadata(for model: LotSizingModel) -> SolverRunMetadata
    func runMetadata(for model: StochasticInventoryModel) -> SolverRunMetadata
}

public extension InventoryBackend {
    func validationReport(for model: EOQModel) -> ValidationReport {
        ValidationReport(backend: capabilities.backendKind, diagnostics: EOQValidator.diagnostics(for: model))
    }

    func validationReport(for model: QuantityDiscountEOQModel) -> ValidationReport {
        ValidationReport(backend: capabilities.backendKind, diagnostics: QuantityDiscountEOQValidator.diagnostics(for: model))
    }

    func validationReport(for model: NewsboyModel) -> ValidationReport {
        ValidationReport(backend: capabilities.backendKind, diagnostics: NewsboyValidator.diagnostics(for: model))
    }

    func validationReport(for model: LotSizingModel) -> ValidationReport {
        ValidationReport(backend: capabilities.backendKind, diagnostics: LotSizingValidator.diagnostics(for: model))
    }

    func validationReport(for model: StochasticInventoryModel) -> ValidationReport {
        ValidationReport(backend: capabilities.backendKind, diagnostics: StochasticInventoryValidator.diagnostics(for: model))
    }

    func validationReport(for envelope: InventoryModelEnvelope) -> ValidationReport {
        switch envelope {
        case .eoq(let model): validationReport(for: model)
        case .quantityDiscountEOQ(let model): validationReport(for: model)
        case .newsboy(let model): validationReport(for: model)
        case .lotSizing(let model): validationReport(for: model)
        case .stochasticReview(let model): validationReport(for: model)
        }
    }

    func solve(_ model: EOQModel) throws -> EOQSolution { try solve(model, options: SolverOptions()) }
    func solve(_ model: QuantityDiscountEOQModel) throws -> QuantityDiscountEOQSolution { try solve(model, options: SolverOptions()) }
    func solve(_ model: NewsboyModel) throws -> NewsboySolution { try solve(model, options: SolverOptions()) }
    func solve(_ model: LotSizingModel) throws -> LotSizingSolution { try solve(model, options: SolverOptions()) }
    func solve(_ model: StochasticInventoryModel) throws -> StochasticInventorySolution { try solve(model, options: SolverOptions()) }

    func solve(
        _ envelope: InventoryModelEnvelope,
        options: SolverOptions = SolverOptions()
    ) throws -> InventorySolutionEnvelope {
        switch envelope {
        case .eoq(let model): .eoq(try solve(model, options: options))
        case .quantityDiscountEOQ(let model): .quantityDiscountEOQ(try solve(model, options: options))
        case .newsboy(let model): .newsboy(try solve(model, options: options))
        case .lotSizing(let model): .lotSizing(try solve(model, options: options))
        case .stochasticReview(let model): .stochasticReview(try solve(model, options: options))
        }
    }

    func runMetadata(for envelope: InventoryModelEnvelope) -> SolverRunMetadata {
        switch envelope {
        case .eoq(let model): runMetadata(for: model)
        case .quantityDiscountEOQ(let model): runMetadata(for: model)
        case .newsboy(let model): runMetadata(for: model)
        case .lotSizing(let model): runMetadata(for: model)
        case .stochasticReview(let model): runMetadata(for: model)
        }
    }

    func solutionDocument(
        for model: InventoryModelEnvelope,
        solution: InventorySolutionEnvelope
    ) -> InventorySolutionDocument {
        InventorySolutionDocument(
            backend: runMetadata(for: model),
            title: model.title,
            timeUnit: model.timeUnit,
            assumptions: inventoryAssumptions(for: model.kind),
            solution: solution
        )
    }
}

public struct NativeEducationalInventoryBackend: InventoryBackend {
    public init() {}

    public var capabilities: SolverCapabilities {
        SolverCapabilities(
            backendKind: .nativeEducational,
            solves: true,
            validates: true,
            exportsStructuredSolution: true,
            notes: [
                "Uses closed-form EOQ and normal-demand newsvendor methods.",
                "Uses exact tier enumeration for all-units discounts.",
                "Uses fixture-scale dynamic programming for finite-horizon lot sizing."
            ]
        )
    }

    public func solve(_ model: EOQModel, options _: SolverOptions = SolverOptions()) throws -> EOQSolution {
        try EOQSolver.solve(model)
    }

    public func solve(_ model: QuantityDiscountEOQModel, options _: SolverOptions = SolverOptions()) throws -> QuantityDiscountEOQSolution {
        try QuantityDiscountEOQSolver.solve(model)
    }

    public func solve(_ model: NewsboyModel, options _: SolverOptions = SolverOptions()) throws -> NewsboySolution {
        try NewsboySolver.solve(model)
    }

    public func solve(_ model: LotSizingModel, options _: SolverOptions = SolverOptions()) throws -> LotSizingSolution {
        try LotSizingSolver.solve(model)
    }

    public func solve(_ model: StochasticInventoryModel, options _: SolverOptions = SolverOptions()) throws -> StochasticInventorySolution {
        try StochasticInventorySolver.solve(model)
    }

    public func runMetadata(for model: EOQModel) -> SolverRunMetadata {
        SolverRunMetadata(
            backendKind: .nativeEducational,
            algorithm: model.replenishmentRate == nil ? "economicOrderQuantityClosedForm" : "economicProductionQuantityClosedForm",
            exactness: .closedForm,
            notes: inventoryAssumptions(for: .eoq)
        )
    }

    public func runMetadata(for model: QuantityDiscountEOQModel) -> SolverRunMetadata {
        SolverRunMetadata(
            backendKind: .nativeEducational,
            algorithm: "allUnitsDiscountTierEnumeration",
            exactness: .exact,
            notes: inventoryAssumptions(for: .quantityDiscountEOQ)
        )
    }

    public func runMetadata(for model: NewsboyModel) -> SolverRunMetadata {
        SolverRunMetadata(
            backendKind: .nativeEducational,
            algorithm: "normalDemandCriticalFractile",
            exactness: .closedForm,
            notes: inventoryAssumptions(for: .newsboy)
        )
    }

    public func runMetadata(for model: LotSizingModel) -> SolverRunMetadata {
        SolverRunMetadata(
            backendKind: .nativeEducational,
            algorithm: "finiteHorizonInventoryDynamicProgramming",
            exactness: .fixtureScale,
            notes: inventoryAssumptions(for: .lotSizing)
        )
    }

    public func runMetadata(for model: StochasticInventoryModel) -> SolverRunMetadata {
        SolverRunMetadata(
            backendKind: .nativeEducational,
            algorithm: "normalDemand\(model.policy.rawValue.prefix(1).uppercased())\(model.policy.rawValue.dropFirst())Approximation",
            exactness: .approximate,
            notes: inventoryAssumptions(for: .stochasticReview)
        )
    }
}

public struct ValidateOnlyInventoryBackend: InventoryBackend {
    public init() {}

    public var capabilities: SolverCapabilities {
        SolverCapabilities(
            backendKind: .validateOnly,
            solves: false,
            validates: true,
            exportsStructuredSolution: false,
            notes: ["Runs inventory validation without solving the model."]
        )
    }

    public func solve(_ model: EOQModel, options _: SolverOptions = SolverOptions()) throws -> EOQSolution {
        throw validationOnlyInventoryError(for: .eoq)
    }

    public func solve(_ model: QuantityDiscountEOQModel, options _: SolverOptions = SolverOptions()) throws -> QuantityDiscountEOQSolution {
        throw validationOnlyInventoryError(for: .quantityDiscountEOQ)
    }

    public func solve(_ model: NewsboyModel, options _: SolverOptions = SolverOptions()) throws -> NewsboySolution {
        throw validationOnlyInventoryError(for: .newsboy)
    }

    public func solve(_ model: LotSizingModel, options _: SolverOptions = SolverOptions()) throws -> LotSizingSolution {
        throw validationOnlyInventoryError(for: .lotSizing)
    }

    public func solve(_ model: StochasticInventoryModel, options _: SolverOptions = SolverOptions()) throws -> StochasticInventorySolution {
        throw validationOnlyInventoryError(for: .stochasticReview)
    }

    public func runMetadata(for model: EOQModel) -> SolverRunMetadata { validationMetadata(for: .eoq) }
    public func runMetadata(for model: QuantityDiscountEOQModel) -> SolverRunMetadata { validationMetadata(for: .quantityDiscountEOQ) }
    public func runMetadata(for model: NewsboyModel) -> SolverRunMetadata { validationMetadata(for: .newsboy) }
    public func runMetadata(for model: LotSizingModel) -> SolverRunMetadata { validationMetadata(for: .lotSizing) }
    public func runMetadata(for model: StochasticInventoryModel) -> SolverRunMetadata { validationMetadata(for: .stochasticReview) }

    private func validationMetadata(for kind: InventoryProblemKind) -> SolverRunMetadata {
        SolverRunMetadata(
            backendKind: .validateOnly,
            algorithm: "validationOnly",
            exactness: .exact,
            notes: ["Validates the \(kind.rawValue) model without solving it."]
        )
    }
}

public enum InventoryBackends {
    public static func backend(for kind: SolverBackendKind) -> (any InventoryBackend)? {
        switch kind {
        case .nativeEducational: NativeEducationalInventoryBackend()
        case .validateOnly: ValidateOnlyInventoryBackend()
        case .externalHighPerformance: nil
        }
    }
}

private func inventoryAssumptions(for kind: InventoryProblemKind) -> [String] {
    switch kind {
    case .eoq:
        ["Constant deterministic demand and instantaneous replenishment unless a production rate is supplied."]
    case .quantityDiscountEOQ:
        ["All-units percentage discounts with constant deterministic demand and holding cost independent of unit price."]
    case .newsboy:
        ["Single-period normal demand with linear underage and overage economics."]
    case .lotSizing:
        ["Integer production, zero initial inventory, and a balanced zero-inventory final state."]
    case .stochasticReview:
        ["Normal independent demand, constant lead time, expected-shortage loss functions, and continuous decision quantities.", "Periodic capacity constraints and empirical demand distributions are not modeled."]
    }
}

private func validationOnlyInventoryError(for kind: InventoryProblemKind) -> InventoryModelError {
    .invalidModel("validateOnly backend does not solve \(kind.rawValue) models")
}

