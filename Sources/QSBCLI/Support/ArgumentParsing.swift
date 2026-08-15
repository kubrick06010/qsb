import QSBCore

extension QSBCLI {
    struct PathAndBackend {
        let path: String
        let backend: SolverBackendKind
    }

    struct LayoutPathBackendAndStrategy {
        let path: String
        let backend: SolverBackendKind
        let strategy: FacilityLayoutSolvingStrategy
    }

    static func parsePathAndBackend(_ arguments: [String], usage: String) throws -> PathAndBackend {
        guard arguments.count == 2 || arguments.count == 4,
              arguments.count == 2 || arguments[2] == "--backend"
        else {
            throw CLIError.usage(usage)
        }
        let backend = arguments.count == 4
            ? try parseBackend(arguments[3])
            : .nativeEducational
        return PathAndBackend(path: arguments[1], backend: backend)
    }

    static func parseLayoutPathBackendAndStrategy(
        _ arguments: [String],
        usage: String
    ) throws -> LayoutPathBackendAndStrategy {
        guard arguments.count >= 2 else {
            throw CLIError.usage(usage)
        }

        var backend: SolverBackendKind = .nativeEducational
        var strategy: FacilityLayoutSolvingStrategy = .initial
        var index = 2
        while index < arguments.count {
            guard index + 1 < arguments.count else {
                throw CLIError.usage(usage)
            }
            switch arguments[index] {
            case "--backend":
                backend = try parseBackend(arguments[index + 1])
            case "--layout-strategy":
                strategy = try parseLayoutStrategy(arguments[index + 1])
            default:
                throw CLIError.usage(usage)
            }
            index += 2
        }

        return LayoutPathBackendAndStrategy(path: arguments[1], backend: backend, strategy: strategy)
    }

    static func parseBackend(_ value: String) throws -> SolverBackendKind {
        switch value {
        case "native", "nativeEducational": .nativeEducational
        case "validate", "validateOnly": .validateOnly
        case "external", "externalHighPerformance": .externalHighPerformance
        default: throw CLIError.usage("backend must be one of: native, validate, external")
        }
    }

    static func parseLayoutStrategy(_ value: String) throws -> FacilityLayoutSolvingStrategy {
        switch value {
        case "initial", "initialLayoutEvaluation": .initial
        case "pairwise-swap", "pairwiseSwap", "pairwiseSameSizeSwap": .pairwiseSwap
        default: throw CLIError.usage("layout strategy must be one of: initial, pairwise-swap")
        }
    }
}
