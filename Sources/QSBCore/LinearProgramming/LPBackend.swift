import Foundation
public protocol LinearProgrammingBackend: Sendable {
    var capabilities: SolverCapabilities { get }

    func validationReport(for program: LinearProgram) -> ValidationReport
    func solve(
        _ program: LinearProgram,
        mode: LinearProgramSolveMode,
        options: SolverOptions
    ) throws -> LinearProgramSolution
}

public extension LinearProgrammingBackend {
    func validationReport(for program: LinearProgram) -> ValidationReport {
        ValidationReport(
            backend: capabilities.backendKind,
            diagnostics: LinearProgramValidator.diagnostics(for: program)
        )
    }

    func solve(
        _ program: LinearProgram,
        mode: LinearProgramSolveMode
    ) throws -> LinearProgramSolution {
        try solve(program, mode: mode, options: SolverOptions())
    }
}

public struct NativeEducationalLinearProgrammingBackend: LinearProgrammingBackend {
    public init() {}

    public var capabilities: SolverCapabilities {
        SolverCapabilities(
            backendKind: .nativeEducational,
            solves: true,
            validates: true,
            exportsStructuredSolution: true,
            notes: [
                "Uses the bundled two-phase simplex solver for continuous LP models.",
                "Uses fixture-scale branch-and-bound for integer and binary variables."
            ]
        )
    }

    public func solve(
        _ program: LinearProgram,
        mode: LinearProgramSolveMode,
        options: SolverOptions = SolverOptions()
    ) throws -> LinearProgramSolution {
        try LinearProgramValidator.validate(program)
        switch mode {
        case .continuous:
            return try SimplexSolver.solve(program)
        case .integer:
            return try IntegerLinearProgramSolver.solve(
                program,
                maxNodes: options.nodeLimit ?? 10_000
            )
        }
    }
}

public struct ValidateOnlyLinearProgrammingBackend: LinearProgrammingBackend {
    public init() {}

    public var capabilities: SolverCapabilities {
        SolverCapabilities(
            backendKind: .validateOnly,
            solves: false,
            validates: true,
            exportsStructuredSolution: false,
            notes: [
                "Runs structural and semantic validation without solving the model."
            ]
        )
    }

    public func solve(
        _ program: LinearProgram,
        mode: LinearProgramSolveMode,
        options: SolverOptions = SolverOptions()
    ) throws -> LinearProgramSolution {
        throw LinearProgramError.unsupportedModel(
            "validateOnly backend does not solve \(mode.rawValue) LP models"
        )
    }
}

public enum LinearProgrammingBackends {
    public static func backend(for kind: SolverBackendKind) -> (any LinearProgrammingBackend)? {
        switch kind {
        case .nativeEducational:
            NativeEducationalLinearProgrammingBackend()
        case .validateOnly:
            ValidateOnlyLinearProgrammingBackend()
        case .externalHighPerformance:
            nil
        }
    }
}

