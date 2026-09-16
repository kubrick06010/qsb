import Foundation

/// Routes the LP-backed network variants through the optional HiGHS adapter.
///
/// Minimum-cost flow and transportation retain their family-specific model and
/// solution types. Only the shared LP formulation crosses the external
/// boundary; graph algorithms that do not have an LP translation remain
/// explicitly native-only.
public struct HiGHSNetworkBackend: NetworkBackend {
    public let linearProgrammingBackend: any LinearProgrammingBackend

    public init(linearProgrammingBackend: any LinearProgrammingBackend) {
        self.linearProgrammingBackend = linearProgrammingBackend
    }

    public static func discovered(defaultTimeLimitSeconds: Double? = nil) -> Self? {
        guard let backend = HiGHSLinearProgrammingBackend.discovered(defaultTimeLimitSeconds: defaultTimeLimitSeconds) else {
            return nil
        }
        return Self(linearProgrammingBackend: backend)
    }

    public var capabilities: SolverCapabilities {
        SolverCapabilities(
            backendKind: .externalHighPerformance,
            solves: true,
            validates: true,
            exportsStructuredSolution: true,
            notes: [
                "Uses host-provided HiGHS through the shared linear-programming adapter.",
                "Supports minimum-cost flow (CNF) and balanced transportation (TP).",
                "Shortest path, spanning tree, max flow, TSP, and assignment retain their native algorithms."
            ]
        )
    }

    public func validationReport(for model: NetworkModelEnvelope) -> ValidationReport {
        var diagnostics = NetworkValidator.diagnostics(for: model)
        guard model.kind != .minimumCostFlow, model.kind != .transportation else {
            return ValidationReport(backend: capabilities.backendKind, diagnostics: diagnostics)
        }
        diagnostics.append(ValidationDiagnostic(
            severity: .error,
            code: "network.external.translationUnavailable",
            message: "HiGHS external translation supports only CNF and TP network models.",
            path: "kind"
        ))
        return ValidationReport(backend: capabilities.backendKind, diagnostics: diagnostics)
    }

    public func solve(
        _ model: NetworkModelEnvelope,
        options: SolverOptions = SolverOptions()
    ) throws -> NetworkSolutionEnvelope {
        switch model {
        case .minimumCostFlow(let value):
            return .minimumCostFlow(try MinimumCostNetworkFlowSolver.solve(
                value,
                linearProgrammingBackend: linearProgrammingBackend,
                options: options
            ))
        case .transportation(let value):
            return .transportation(try TransportationSolver.solve(
                value,
                linearProgrammingBackend: linearProgrammingBackend,
                options: options
            ))
        default:
            throw NetworkModelError.externalTranslationUnavailable(
                "HiGHS external backend supports CNF and TP network models; \(model.kind.rawValue) remains native-only"
            )
        }
    }

    public func runMetadata(for model: NetworkModelEnvelope) -> SolverRunMetadata {
        switch model.kind {
        case .minimumCostFlow:
            SolverRunMetadata(
                backendKind: .externalHighPerformance,
                algorithm: "hiGHSMinimumCostFlowLP",
                exactness: .exact,
                notes: [
                    "Normalized transshipment formulation solved by host-provided HiGHS.",
                    "Unbalanced totals use the existing explicit zero-cost dummy adjustment."
                ]
            )
        case .transportation:
            SolverRunMetadata(
                backendKind: .externalHighPerformance,
                algorithm: "hiGHSTransportationLP",
                exactness: .exact,
                notes: ["Normalized balanced transportation formulation solved by host-provided HiGHS."]
            )
        default:
            SolverRunMetadata(
                backendKind: .externalHighPerformance,
                algorithm: "hiGHSNetworkTranslationUnavailable",
                exactness: .exact,
                notes: ["This network variant has no external LP translation and remains native-only."]
            )
        }
    }
}

/// Routes aggregate planning's normalized continuous LP through HiGHS while
/// preserving the typed period solution returned by `AggregatePlanningSolver`.
public struct HiGHSAggregatePlanningBackend: AggregatePlanningBackend {
    public let linearProgrammingBackend: any LinearProgrammingBackend

    public init(linearProgrammingBackend: any LinearProgrammingBackend) {
        self.linearProgrammingBackend = linearProgrammingBackend
    }

    public static func discovered(defaultTimeLimitSeconds: Double? = nil) -> Self? {
        guard let backend = HiGHSLinearProgrammingBackend.discovered(defaultTimeLimitSeconds: defaultTimeLimitSeconds) else {
            return nil
        }
        return Self(linearProgrammingBackend: backend)
    }

    public var capabilities: SolverCapabilities {
        SolverCapabilities(
            backendKind: .externalHighPerformance,
            solves: true,
            validates: true,
            exportsStructuredSolution: true,
            notes: [
                "Uses host-provided HiGHS for the normalized aggregate-planning LP.",
                "Planning quantities and workforce remain continuous, matching the family formulation."
            ]
        )
    }

    public func solve(
        _ model: AggregatePlanningModel,
        options: SolverOptions = SolverOptions()
    ) throws -> AggregatePlanningSolution {
        try AggregatePlanningSolver.solve(
            model,
            linearProgrammingBackend: linearProgrammingBackend,
            options: options
        )
    }

    public func runMetadata(for _: AggregatePlanningModel) -> SolverRunMetadata {
        SolverRunMetadata(
            backendKind: .externalHighPerformance,
            algorithm: "hiGHSAggregatePlanningLP",
            exactness: .exact,
            notes: [
                "Normalized demand, capacity, inventory, backorder, and workforce balances are solved by host-provided HiGHS.",
                "Continuous planning quantities are preserved; integer workforce planning is not inferred."
            ]
        )
    }
}

/// Routes preemptive goal programming through HiGHS one priority at a time.
/// The existing solver owns lexicographic fixing and typed goal outcomes;
/// HiGHS only solves each generated LP or MIP subproblem.
public struct HiGHSGoalProgrammingBackend: GoalProgrammingBackend {
    public let linearProgrammingBackend: any LinearProgrammingBackend

    public init(linearProgrammingBackend: any LinearProgrammingBackend) {
        self.linearProgrammingBackend = linearProgrammingBackend
    }

    public static func discovered(defaultTimeLimitSeconds: Double? = nil) -> Self? {
        guard let backend = HiGHSLinearProgrammingBackend.discovered(defaultTimeLimitSeconds: defaultTimeLimitSeconds) else {
            return nil
        }
        return Self(linearProgrammingBackend: backend)
    }

    public var capabilities: SolverCapabilities {
        SolverCapabilities(
            backendKind: .externalHighPerformance,
            solves: true,
            validates: true,
            exportsStructuredSolution: true,
            notes: [
                "Uses host-provided HiGHS for every lexicographic priority subproblem.",
                "Continuous goals use LP; preserved integer decision variables use MIP while deviation presolve remains in QSBCore."
            ]
        )
    }

    public func solve(
        _ model: GoalProgram,
        options: SolverOptions = SolverOptions()
    ) throws -> GoalProgrammingSolution {
        try GoalProgrammingSolver.solve(
            model,
            linearProgrammingBackend: linearProgrammingBackend,
            options: options
        )
    }

    public func runMetadata(for model: GoalProgram) -> SolverRunMetadata {
        let integer = model.variableTypes.contains { $0 != .continuous }
        return SolverRunMetadata(
            backendKind: .externalHighPerformance,
            algorithm: integer ? "hiGHSLexicographicMIP" : "hiGHSLexicographicLP",
            exactness: .exact,
            notes: [
                "Each priority is optimized and fixed by QSBCore before the next HiGHS subproblem.",
                "Results are subject to the configured HiGHS numerical tolerances; decision-variable integrality is preserved."
            ]
        )
    }
}
