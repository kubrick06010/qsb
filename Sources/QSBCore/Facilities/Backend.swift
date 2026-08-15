import Foundation

public enum FacilitiesModelError: Error, CustomStringConvertible {
    case unsupportedFormat
    case invalidNumericValue(String)
    case invalidModel(String)

    public var description: String {
        switch self {
        case .unsupportedFormat:
            "Unsupported facilities model format"
        case .invalidNumericValue(let value):
            "Invalid numeric value: \(value)"
        case .invalidModel(let detail):
            "Invalid facilities model: \(detail)"
        }
    }
}

public protocol FacilitiesBackend: Sendable {
    var capabilities: SolverCapabilities { get }

    func validationReport(for problem: LineBalancingProblem) -> ValidationReport
    func validationReport(for problem: FacilityLocationProblem) -> ValidationReport
    func validationReport(for problem: FacilityLayoutProblem) -> ValidationReport

    func solve(_ problem: LineBalancingProblem, options: SolverOptions) throws -> LineBalancingSolution
    func solve(_ problem: FacilityLocationProblem, options: SolverOptions) throws -> FacilityLocationSolution
    func solve(
        _ problem: FacilityLayoutProblem,
        strategy: FacilityLayoutSolvingStrategy,
        options: SolverOptions
    ) throws -> FacilityLayoutSolution

    func runMetadata(for problem: LineBalancingProblem) -> SolverRunMetadata
    func runMetadata(for problem: FacilityLocationProblem) -> SolverRunMetadata
    func runMetadata(
        for problem: FacilityLayoutProblem,
        strategy: FacilityLayoutSolvingStrategy
    ) -> SolverRunMetadata
}

public extension FacilitiesBackend {
    func validationReport(for problem: LineBalancingProblem) -> ValidationReport {
        ValidationReport(
            backend: capabilities.backendKind,
            diagnostics: LineBalancingValidator.diagnostics(for: problem)
        )
    }

    func validationReport(for problem: FacilityLocationProblem) -> ValidationReport {
        ValidationReport(
            backend: capabilities.backendKind,
            diagnostics: FacilityLocationValidator.diagnostics(for: problem)
        )
    }

    func validationReport(for problem: FacilityLayoutProblem) -> ValidationReport {
        ValidationReport(
            backend: capabilities.backendKind,
            diagnostics: FacilityLayoutValidator.diagnostics(for: problem)
        )
    }

    func validationReport(for envelope: FacilitiesModelEnvelope) -> ValidationReport {
        switch envelope {
        case .lineBalancing(let problem):
            validationReport(for: problem)
        case .location(let problem):
            validationReport(for: problem)
        case .layout(let problem):
            validationReport(for: problem)
        }
    }

    func solve(_ problem: LineBalancingProblem) throws -> LineBalancingSolution {
        try solve(problem, options: SolverOptions())
    }

    func solve(_ problem: FacilityLocationProblem) throws -> FacilityLocationSolution {
        try solve(problem, options: SolverOptions())
    }

    func solve(
        _ problem: FacilityLayoutProblem,
        strategy: FacilityLayoutSolvingStrategy = .initial
    ) throws -> FacilityLayoutSolution {
        try solve(problem, strategy: strategy, options: SolverOptions())
    }

    func solve(
        _ envelope: FacilitiesModelEnvelope,
        layoutStrategy: FacilityLayoutSolvingStrategy = .initial,
        options: SolverOptions = SolverOptions()
    ) throws -> FacilitiesSolutionEnvelope {
        switch envelope {
        case .lineBalancing(let problem):
            .lineBalancing(try solve(problem, options: options))
        case .location(let problem):
            .location(try solve(problem, options: options))
        case .layout(let problem):
            .layout(try solve(problem, strategy: layoutStrategy, options: options))
        }
    }

    func runMetadata(
        for envelope: FacilitiesModelEnvelope,
        layoutStrategy: FacilityLayoutSolvingStrategy = .initial
    ) -> SolverRunMetadata {
        switch envelope {
        case .lineBalancing(let problem):
            runMetadata(for: problem)
        case .location(let problem):
            runMetadata(for: problem)
        case .layout(let problem):
            runMetadata(for: problem, strategy: layoutStrategy)
        }
    }
}

public struct NativeEducationalFacilitiesBackend: FacilitiesBackend {
    public init() {}

    public var capabilities: SolverCapabilities {
        SolverCapabilities(
            backendKind: .nativeEducational,
            solves: true,
            validates: true,
            exportsStructuredSolution: true,
            notes: [
                "Uses fixture-scale exact line-balancing search.",
                "Uses closed-form or iterative single-facility location methods.",
                "Uses initial evaluation or pairwise-swap local search for layouts."
            ]
        )
    }

    public func solve(
        _ problem: LineBalancingProblem,
        options _: SolverOptions = SolverOptions()
    ) throws -> LineBalancingSolution {
        try LineBalancingSolver.solve(problem)
    }

    public func solve(
        _ problem: FacilityLocationProblem,
        options _: SolverOptions = SolverOptions()
    ) throws -> FacilityLocationSolution {
        try FacilityLocationSolver.solve(problem)
    }

    public func solve(
        _ problem: FacilityLayoutProblem,
        strategy: FacilityLayoutSolvingStrategy = .initial,
        options _: SolverOptions = SolverOptions()
    ) throws -> FacilityLayoutSolution {
        switch strategy {
        case .initial:
            try FacilityLayoutSolver.solve(problem)
        case .pairwiseSwap:
            try FacilityLayoutSolver.improve(problem)
        }
    }

    public func runMetadata(for problem: LineBalancingProblem) -> SolverRunMetadata {
        SolverRunMetadata(
            backendKind: .nativeEducational,
            algorithm: "bitmaskDynamicProgramming",
            exactness: .fixtureScale,
            notes: [
                "Exact station minimization for supported fixture-scale instances.",
                "Current native solver rejects instances with more than 24 tasks."
            ]
        )
    }

    public func runMetadata(for problem: FacilityLocationProblem) -> SolverRunMetadata {
        switch problem.distanceMeasure {
        case .rectilinear:
            SolverRunMetadata(
                backendKind: .nativeEducational,
                algorithm: "weightedMedian",
                exactness: .closedForm,
                notes: ["Single-new-facility rectilinear distance model."]
            )
        case .squaredEuclidean:
            SolverRunMetadata(
                backendKind: .nativeEducational,
                algorithm: "weightedCentroid",
                exactness: .closedForm,
                notes: ["Single-new-facility squared Euclidean distance model."]
            )
        case .euclidean:
            SolverRunMetadata(
                backendKind: .nativeEducational,
                algorithm: "weiszfeldIteration",
                exactness: .approximate,
                notes: ["Single-new-facility Euclidean distance model solved by iterative Weiszfeld updates."]
            )
        }
    }

    public func runMetadata(
        for problem: FacilityLayoutProblem,
        strategy: FacilityLayoutSolvingStrategy
    ) -> SolverRunMetadata {
        switch strategy {
        case .initial:
            SolverRunMetadata(
                backendKind: .nativeEducational,
                algorithm: "initialLayoutEvaluation",
                exactness: .fixtureScale,
                notes: ["Evaluates centroid-based rectilinear load-distance for the provided initial layout."]
            )
        case .pairwiseSwap:
            SolverRunMetadata(
                backendKind: .nativeEducational,
                algorithm: "pairwiseSameSizeSwapLocalSearch",
                exactness: .heuristic,
                notes: ["Repeatedly swaps non-fixed departments with equal cell counts when the swap improves load-distance."]
            )
        }
    }
}

public struct ValidateOnlyFacilitiesBackend: FacilitiesBackend {
    public init() {}

    public var capabilities: SolverCapabilities {
        SolverCapabilities(
            backendKind: .validateOnly,
            solves: false,
            validates: true,
            exportsStructuredSolution: false,
            notes: ["Runs facilities validation without solving the model."]
        )
    }

    public func solve(
        _ problem: LineBalancingProblem,
        options _: SolverOptions = SolverOptions()
    ) throws -> LineBalancingSolution {
        throw FacilitiesModelError.invalidModel("validateOnly backend does not solve line-balancing models")
    }

    public func solve(
        _ problem: FacilityLocationProblem,
        options _: SolverOptions = SolverOptions()
    ) throws -> FacilityLocationSolution {
        throw FacilitiesModelError.invalidModel("validateOnly backend does not solve facility-location models")
    }

    public func solve(
        _ problem: FacilityLayoutProblem,
        strategy: FacilityLayoutSolvingStrategy = .initial,
        options _: SolverOptions = SolverOptions()
    ) throws -> FacilityLayoutSolution {
        throw FacilitiesModelError.invalidModel("validateOnly backend does not solve facility-layout models")
    }

    public func runMetadata(for problem: LineBalancingProblem) -> SolverRunMetadata {
        validationMetadata(for: .lineBalancing)
    }

    public func runMetadata(for problem: FacilityLocationProblem) -> SolverRunMetadata {
        validationMetadata(for: .location)
    }

    public func runMetadata(
        for problem: FacilityLayoutProblem,
        strategy: FacilityLayoutSolvingStrategy
    ) -> SolverRunMetadata {
        validationMetadata(for: .layout)
    }

    private func validationMetadata(for kind: FacilitiesProblemKind) -> SolverRunMetadata {
        SolverRunMetadata(
            backendKind: .validateOnly,
            algorithm: "validationOnly",
            exactness: .exact,
            notes: ["Validates the \(kind.rawValue) model without solving it."]
        )
    }
}

public enum FacilitiesBackends {
    public static func backend(for kind: SolverBackendKind) -> (any FacilitiesBackend)? {
        switch kind {
        case .nativeEducational:
            NativeEducationalFacilitiesBackend()
        case .validateOnly:
            ValidateOnlyFacilitiesBackend()
        case .externalHighPerformance:
            nil
        }
    }
}


