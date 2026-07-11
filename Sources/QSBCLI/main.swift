import Foundation
import QSBCore

#if os(Linux)
import Glibc
#else
import Darwin
#endif

@main
struct QSBCLI {
    static func main() {
        do {
            try run()
        } catch CLIError.usage(let message) {
            if let message {
                printError(message)
            }
            printUsage(to: .standardError)
            exit(message == nil ? EXIT_SUCCESS : EXIT_FAILURE)
        } catch {
            printError(userFacingMessage(for: error))
            exit(EXIT_FAILURE)
        }
    }

    private static func run() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first else {
            printUsage(to: .standardOutput)
            return
        }

        switch command {
        case "inspect":
            guard arguments.count == 2 else {
                throw CLIError.usage("inspect expects exactly one file path")
            }
            try inspect(path: arguments[1])
        case "inventory-fixtures":
            guard arguments.count == 2 else {
                throw CLIError.usage("inventory-fixtures expects exactly one reference directory path")
            }
            try inventoryFixtures(path: arguments[1])
        case "solve-lp":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-lp expects a legacy LP file path and optional --backend native|validate"
            )
            try solveLP(path: options.path, backend: options.backend)
        case "solve-ilp":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-ilp expects a legacy LP file path and optional --backend native|validate"
            )
            try solveILP(path: options.path, backend: options.backend)
        case "validate-lp":
            guard arguments.count == 2 else {
                throw CLIError.usage("validate-lp expects exactly one legacy LP file path")
            }
            try validateLegacyLP(path: arguments[1])
        case "export-json":
            guard arguments.count == 2 else {
                throw CLIError.usage("export-json expects exactly one legacy LP file path")
            }
            try exportJSON(path: arguments[1])
        case "solve-json":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-json expects a model JSON file path and optional --backend native|validate"
            )
            try solveJSON(path: options.path, integer: false, backend: options.backend)
        case "solve-json-ilp":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-json-ilp expects a model JSON file path and optional --backend native|validate"
            )
            try solveJSON(path: options.path, integer: true, backend: options.backend)
        case "validate-json":
            guard arguments.count == 2 else {
                throw CLIError.usage("validate-json expects exactly one normalized LP/ILP model JSON file path")
            }
            try validateJSON(path: arguments[1])
        case "export-network-json":
            guard arguments.count == 2 else {
                throw CLIError.usage("export-network-json expects exactly one legacy network file path")
            }
            try exportNetworkJSON(path: arguments[1])
        case "solve-network-json":
            guard arguments.count == 2 else {
                throw CLIError.usage("solve-network-json expects exactly one network model JSON file path")
            }
            try solveNetworkJSON(path: arguments[1])
        case "solve-timeseries":
            guard arguments.count == 2 || arguments.count == 3 else {
                throw CLIError.usage("solve-timeseries expects a legacy FC time-series file path and optional periods-ahead")
            }
            let periodsAhead: Int
            if arguments.count == 3 {
                guard let parsedPeriodsAhead = Int(arguments[2]), parsedPeriodsAhead > 0 else {
                    throw CLIError.usage("periods-ahead must be a positive integer")
                }
                periodsAhead = parsedPeriodsAhead
            } else {
                periodsAhead = 1
            }
            try solveTimeSeries(path: arguments[1], periodsAhead: periodsAhead)
        case "solve-moving-average":
            guard arguments.count == 3 || arguments.count == 4 else {
                throw CLIError.usage("solve-moving-average expects a legacy FC time-series file path, window size, and optional periods-ahead")
            }
            guard let windowSize = Int(arguments[2]), windowSize > 0 else {
                throw CLIError.usage("window-size must be a positive integer")
            }
            let periodsAhead: Int
            if arguments.count == 4 {
                guard let parsedPeriodsAhead = Int(arguments[3]), parsedPeriodsAhead > 0 else {
                    throw CLIError.usage("periods-ahead must be a positive integer")
                }
                periodsAhead = parsedPeriodsAhead
            } else {
                periodsAhead = 1
            }
            try solveMovingAverage(path: arguments[1], windowSize: windowSize, periodsAhead: periodsAhead)
        case "solve-exp-smoothing":
            guard arguments.count == 3 || arguments.count == 4 else {
                throw CLIError.usage("solve-exp-smoothing expects a legacy FC time-series file path, alpha, and optional periods-ahead")
            }
            guard let alpha = Double(arguments[2]), alpha > 0, alpha <= 1 else {
                throw CLIError.usage("alpha must be in the range (0, 1]")
            }
            let periodsAhead: Int
            if arguments.count == 4 {
                guard let parsedPeriodsAhead = Int(arguments[3]), parsedPeriodsAhead > 0 else {
                    throw CLIError.usage("periods-ahead must be a positive integer")
                }
                periodsAhead = parsedPeriodsAhead
            } else {
                periodsAhead = 1
            }
            try solveExponentialSmoothing(path: arguments[1], alpha: alpha, periodsAhead: periodsAhead)
        case "solve-seasonal":
            guard arguments.count == 3 || arguments.count == 4 else {
                throw CLIError.usage("solve-seasonal expects a legacy FC time-series file path, season length, and optional periods-ahead")
            }
            guard let seasonLength = Int(arguments[2]), seasonLength > 1 else {
                throw CLIError.usage("season-length must be an integer greater than one")
            }
            let periodsAhead: Int
            if arguments.count == 4 {
                guard let parsedPeriodsAhead = Int(arguments[3]), parsedPeriodsAhead > 0 else {
                    throw CLIError.usage("periods-ahead must be a positive integer")
                }
                periodsAhead = parsedPeriodsAhead
            } else {
                periodsAhead = 1
            }
            try solveSeasonal(path: arguments[1], seasonLength: seasonLength, periodsAhead: periodsAhead)
        case "solve-regression":
            guard arguments.count == 2 else {
                throw CLIError.usage("solve-regression expects exactly one legacy FC regression file path")
            }
            try solveRegression(path: arguments[1])
        case "solve-eoq":
            guard arguments.count == 2 else {
                throw CLIError.usage("solve-eoq expects exactly one legacy ITS EOQ file path")
            }
            try solveEOQ(path: arguments[1])
        case "solve-discount-eoq":
            guard arguments.count == 2 else {
                throw CLIError.usage("solve-discount-eoq expects exactly one legacy ITS discount EOQ file path")
            }
            try solveDiscountEOQ(path: arguments[1])
        case "solve-newsboy":
            guard arguments.count == 2 else {
                throw CLIError.usage("solve-newsboy expects exactly one legacy ITS newsboy file path")
            }
            try solveNewsboy(path: arguments[1])
        case "solve-lot-sizing":
            guard arguments.count == 2 else {
                throw CLIError.usage("solve-lot-sizing expects exactly one legacy ITS lot sizing file path")
            }
            try solveLotSizing(path: arguments[1])
        case "solve-flowshop":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-flowshop expects a legacy SCH flow-shop file path and optional --backend native|validate"
            )
            try solveFlowShop(path: options.path, backend: options.backend)
        case "solve-flowshop-json":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-flowshop-json expects a legacy SCH flow-shop file path and optional --backend native|validate"
            )
            try solveFlowShopJSON(path: options.path, backend: options.backend)
        case "solve-jobshop":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-jobshop expects a legacy SCH job-shop file path and optional --backend native|validate"
            )
            try solveJobShop(path: options.path, backend: options.backend)
        case "solve-jobshop-json":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-jobshop-json expects a legacy SCH job-shop file path and optional --backend native|validate"
            )
            try solveJobShopJSON(path: options.path, backend: options.backend)
        case "validate-flowshop":
            guard arguments.count == 2 else {
                throw CLIError.usage("validate-flowshop expects exactly one legacy SCH flow-shop file path")
            }
            try validateFlowShop(path: arguments[1])
        case "validate-jobshop":
            guard arguments.count == 2 else {
                throw CLIError.usage("validate-jobshop expects exactly one legacy SCH job-shop file path")
            }
            try validateJobShop(path: arguments[1])
        case "solve-line-balancing":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-line-balancing expects a legacy FLL line balancing file path and optional --backend native|validate"
            )
            try solveLineBalancing(path: options.path, backend: options.backend)
        case "validate-line-balancing":
            guard arguments.count == 2 else {
                throw CLIError.usage("validate-line-balancing expects exactly one legacy FLL line balancing file path")
            }
            try validateLineBalancing(path: arguments[1])
        case "export-facilities-json":
            guard arguments.count == 2 else {
                throw CLIError.usage("export-facilities-json expects exactly one legacy FLL facilities file path")
            }
            try exportFacilitiesJSON(path: arguments[1])
        case "validate-facilities-json":
            guard arguments.count == 2 else {
                throw CLIError.usage("validate-facilities-json expects exactly one facilities model JSON file path")
            }
            try validateFacilitiesJSON(path: arguments[1])
        case "solve-facilities-json":
            let options = try parseLayoutPathBackendAndStrategy(
                arguments,
                usage: "solve-facilities-json expects a facilities model JSON file path with optional --backend native|validate and --layout-strategy initial|pairwise-swap"
            )
            try solveFacilitiesJSON(path: options.path, backend: options.backend, layoutStrategy: options.strategy)
        case "export-line-balancing-json":
            guard arguments.count == 2 else {
                throw CLIError.usage("export-line-balancing-json expects exactly one legacy FLL line balancing file path")
            }
            try exportLineBalancingJSON(path: arguments[1])
        case "solve-line-balancing-json":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-line-balancing-json expects a line-balancing model JSON file path and optional --backend native|validate"
            )
            try solveLineBalancingJSON(path: options.path, backend: options.backend)
        case "solve-location":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-location expects a legacy FLL location file path and optional --backend native|validate"
            )
            try solveLocation(path: options.path, backend: options.backend)
        case "validate-location":
            guard arguments.count == 2 else {
                throw CLIError.usage("validate-location expects exactly one legacy FLL location file path")
            }
            try validateLocation(path: arguments[1])
        case "export-location-json":
            guard arguments.count == 2 else {
                throw CLIError.usage("export-location-json expects exactly one legacy FLL location file path")
            }
            try exportLocationJSON(path: arguments[1])
        case "solve-location-json":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-location-json expects a facility-location model JSON file path and optional --backend native|validate"
            )
            try solveLocationJSON(path: options.path, backend: options.backend)
        case "solve-layout":
            let options = try parseLayoutPathBackendAndStrategy(
                arguments,
                usage: "solve-layout expects a legacy FLL layout file path with optional --backend native|validate and --layout-strategy initial|pairwise-swap"
            )
            try solveLayout(path: options.path, backend: options.backend, strategy: options.strategy)
        case "validate-layout":
            guard arguments.count == 2 else {
                throw CLIError.usage("validate-layout expects exactly one legacy FLL layout file path")
            }
            try validateLayout(path: arguments[1])
        case "export-layout-json":
            guard arguments.count == 2 else {
                throw CLIError.usage("export-layout-json expects exactly one legacy FLL layout file path")
            }
            try exportLayoutJSON(path: arguments[1])
        case "solve-layout-json":
            let options = try parseLayoutPathBackendAndStrategy(
                arguments,
                usage: "solve-layout-json expects a layout model JSON file path with optional --backend native|validate and --layout-strategy initial|pairwise-swap"
            )
            try solveLayoutJSON(path: options.path, backend: options.backend, strategy: options.strategy)
        case "solve-knapsack":
            guard arguments.count == 2 else {
                throw CLIError.usage("solve-knapsack expects exactly one legacy DP knapsack file path")
            }
            try solveKnapsack(path: arguments[1])
        case "solve-stagecoach":
            guard arguments.count == 2 else {
                throw CLIError.usage("solve-stagecoach expects exactly one legacy DP stagecoach file path")
            }
            try solveStagecoach(path: arguments[1])
        case "solve-prod-inventory":
            guard arguments.count == 2 else {
                throw CLIError.usage("solve-prod-inventory expects exactly one legacy DP production/inventory file path")
            }
            try solveProductionInventory(path: arguments[1])
        case "solve-payoff":
            guard arguments.count == 2 else {
                throw CLIError.usage("solve-payoff expects exactly one legacy DA payoff file path")
            }
            try solvePayoff(path: arguments[1])
        case "solve-bayesian":
            guard arguments.count == 2 else {
                throw CLIError.usage("solve-bayesian expects exactly one legacy DA Bayesian file path")
            }
            try solveBayesian(path: arguments[1])
        case "solve-decision-tree":
            guard arguments.count == 2 else {
                throw CLIError.usage("solve-decision-tree expects exactly one legacy DA decision tree file path")
            }
            try solveDecisionTree(path: arguments[1])
        case "solve-game":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-game expects a legacy DA zero-sum game file path and optional --backend native|validate"
            )
            try solveGame(path: options.path, backend: options.backend)
        case "validate-game":
            guard arguments.count == 2 else {
                throw CLIError.usage("validate-game expects exactly one legacy DA zero-sum game file path")
            }
            try validateGame(path: arguments[1])
        case "solve-mm1":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-mm1 expects a legacy QA M/M/1 file path and optional --backend native|validate"
            )
            try solveMM1(path: options.path, backend: options.backend)
        case "solve-mm1-json":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-mm1-json expects a legacy QA M/M/1 file path and optional --backend native|validate"
            )
            try solveMM1JSON(path: options.path, backend: options.backend)
        case "validate-mm1":
            guard arguments.count == 2 else {
                throw CLIError.usage("validate-mm1 expects exactly one legacy QA M/M/1 file path")
            }
            try validateMM1(path: arguments[1])
        case "solve-finite-queue":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-finite-queue expects a legacy QA finite-capacity file path and optional --backend native|validate"
            )
            try solveFiniteQueue(path: options.path, backend: options.backend)
        case "solve-finite-queue-json":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-finite-queue-json expects a legacy QA finite-capacity file path and optional --backend native|validate"
            )
            try solveFiniteQueueJSON(path: options.path, backend: options.backend)
        case "validate-finite-queue":
            guard arguments.count == 2 else {
                throw CLIError.usage("validate-finite-queue expects exactly one legacy QA finite-capacity file path")
            }
            try validateFiniteQueue(path: arguments[1])
        case "solve-spp":
            guard arguments.count == 2 else {
                throw CLIError.usage("solve-spp expects exactly one legacy SPP network file path")
            }
            try solveShortestPath(path: arguments[1])
        case "solve-mst":
            guard arguments.count == 2 else {
                throw CLIError.usage("solve-mst expects exactly one legacy MST network file path")
            }
            try solveMinimumSpanningTree(path: arguments[1])
        case "solve-maxflow":
            guard arguments.count == 2 else {
                throw CLIError.usage("solve-maxflow expects exactly one legacy MFP network file path")
            }
            try solveMaxFlow(path: arguments[1])
        case "solve-tsp":
            guard arguments.count == 2 else {
                throw CLIError.usage("solve-tsp expects exactly one legacy TSP network file path")
            }
            try solveTravelingSalesperson(path: arguments[1])
        case "solve-assignment":
            guard arguments.count == 2 else {
                throw CLIError.usage("solve-assignment expects exactly one legacy AP network file path")
            }
            try solveAssignment(path: arguments[1])
        case "solve-transport":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-transport expects a legacy TP network file path and optional --backend native|validate"
            )
            try solveTransportation(path: options.path, backend: options.backend)
        case "validate-transport":
            guard arguments.count == 2 else {
                throw CLIError.usage("validate-transport expects exactly one legacy TP network file path")
            }
            try validateTransportation(path: arguments[1])
        default:
            throw CLIError.usage("unknown command: \(command)")
        }
    }

    private struct PathAndBackend {
        let path: String
        let backend: SolverBackendKind
    }

    private struct LayoutPathBackendAndStrategy {
        let path: String
        let backend: SolverBackendKind
        let strategy: FacilityLayoutSolvingStrategy
    }

    private static func parsePathAndBackend(_ arguments: [String], usage: String) throws -> PathAndBackend {
        guard arguments.count == 2 || arguments.count == 4 else {
            throw CLIError.usage(usage)
        }
        guard arguments.count == 2 || arguments[2] == "--backend" else {
            throw CLIError.usage(usage)
        }
        let backend: SolverBackendKind
        if arguments.count == 4 {
            backend = try parseBackend(arguments[3])
        } else {
            backend = .nativeEducational
        }
        return PathAndBackend(path: arguments[1], backend: backend)
    }

    private static func parseLayoutPathBackendAndStrategy(
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

    private static func parseBackend(_ value: String) throws -> SolverBackendKind {
        switch value {
        case "native", "nativeEducational":
            return .nativeEducational
        case "validate", "validateOnly":
            return .validateOnly
        case "external", "externalHighPerformance":
            return .externalHighPerformance
        default:
            throw CLIError.usage("backend must be one of: native, validate, external")
        }
    }

    private static func linearProgrammingBackend(
        for backend: SolverBackendKind,
        command: String
    ) throws -> any LinearProgrammingBackend {
        guard let selectedBackend = LinearProgrammingBackends.backend(for: backend) else {
            throw CLIError.usage("external backend is not available yet for \(command)")
        }
        return selectedBackend
    }

    private static func schedulingBackend(
        for backend: SolverBackendKind,
        command: String
    ) throws -> any SchedulingBackend {
        guard let selectedBackend = SchedulingBackends.backend(for: backend) else {
            throw CLIError.usage("external backend is not available yet for \(command)")
        }
        return selectedBackend
    }

    private static func queuingBackend(
        for backend: SolverBackendKind,
        command: String
    ) throws -> any QueuingBackend {
        guard let selectedBackend = QueuingBackends.backend(for: backend) else {
            throw CLIError.usage("external backend is not available yet for \(command)")
        }
        return selectedBackend
    }

    private static func facilitiesBackend(
        for backend: SolverBackendKind,
        command: String
    ) throws -> any FacilitiesBackend {
        guard let selectedBackend = FacilitiesBackends.backend(for: backend) else {
            throw CLIError.usage("external backend is not available yet for \(command)")
        }
        return selectedBackend
    }

    private static func schedulingBackendMetadata(kind: SchedulingProblemKind) -> SolverRunMetadata {
        switch kind {
        case .flowShop:
            SolverRunMetadata(
                backendKind: .nativeEducational,
                algorithm: "flowShopPermutationSearch",
                exactness: .fixtureScale,
                notes: [
                    "Enumerates all job permutations for supported fixture-scale flow-shop instances."
                ]
            )
        case .jobShop:
            SolverRunMetadata(
                backendKind: .nativeEducational,
                algorithm: "jobShopBranchAndBoundDominancePruning",
                exactness: .fixtureScale,
                notes: [
                    "Uses exact fixture-scale branch and bound with dominance pruning."
                ]
            )
        }
    }

    private static func queuingBackendMetadata(kind: QueuingProblemKind) -> SolverRunMetadata {
        switch kind {
        case .mm1:
            SolverRunMetadata(
                backendKind: .nativeEducational,
                algorithm: "mm1ClosedForm",
                exactness: .closedForm,
                notes: ["Exact steady-state M/M/1 equations for stable models."]
            )
        case .finiteCapacity:
            SolverRunMetadata(
                backendKind: .nativeEducational,
                algorithm: "finiteCapacityBirthDeath",
                exactness: .approximate,
                notes: ["Finite-state birth-death approximation using mean arrival and service rates."]
            )
        }
    }

    private static func parseLayoutStrategy(_ value: String) throws -> FacilityLayoutSolvingStrategy {
        switch value {
        case "initial", "initialLayoutEvaluation":
            return .initial
        case "pairwise-swap", "pairwiseSwap", "pairwiseSameSizeSwap":
            return .pairwiseSwap
        default:
            throw CLIError.usage("layout strategy must be one of: initial, pairwise-swap")
        }
    }

    private static func inspect(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        if LegacyCompressedFile.isCompressed(data) {
            let file = try LegacyCompressedFile(data: data)
            print("format: SZDD")
            print("expanded-size: \(file.expandedSize)")
            print("restored-path: \(LegacyCompressedFile.restoredFilename(for: path, lastCharacter: file.originalLastCharacter))")
            printPreview(file.expandedData)
        } else {
            print("format: plain")
            print("size: \(data.count)")
            printPreview(data)
        }
    }

    private static func inventoryFixtures(path: String) throws {
        let entries = try LegacyFixtureInventory.scanDirectory(at: URL(fileURLWithPath: path))
        let data = try LegacyFixtureInventory.encode(entries)
        FileHandle.standardOutput.write(data)
        print()
    }

    private static func solveLP(path: String, backend: SolverBackendKind) throws {
        let program = try readLegacyProgram(path: path)
        let solver = try linearProgrammingBackend(for: backend, command: "solve-lp")
        if solver.capabilities.solves {
            let solution = try solver.solve(program, mode: .continuous)
            printSolution(program: program, solution: solution, backend: solver.capabilities.backendKind)
        } else {
            printValidationReport(
                program: program,
                report: solver.validationReport(for: program),
                source: path
            )
        }
    }

    private static func solveILP(path: String, backend: SolverBackendKind) throws {
        let program = try readLegacyProgram(path: path)
        let solver = try linearProgrammingBackend(for: backend, command: "solve-ilp")
        if solver.capabilities.solves {
            let solution = try solver.solve(program, mode: .integer)
            printSolution(program: program, solution: solution, backend: solver.capabilities.backendKind)
        } else {
            printValidationReport(
                program: program,
                report: solver.validationReport(for: program),
                source: path
            )
        }
    }

    private static func validateLegacyLP(path: String) throws {
        let program = try readLegacyProgram(path: path)
        printValidationReport(program: program, backend: .validateOnly, source: path)
    }

    private static func validateJSON(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let program = try LinearProgramJSON.decodeProgram(from: data)
        printValidationReport(program: program, backend: .validateOnly, source: path)
    }

    private static func solveJSON(path: String, integer: Bool, backend: SolverBackendKind) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let program = try LinearProgramJSON.decodeProgram(from: data)
        let solver = try linearProgrammingBackend(for: backend, command: "solve-json")
        if solver.capabilities.solves {
            let solution = try solver.solve(
                program,
                mode: integer ? .integer : .continuous
            )
            let output = try LinearProgramJSON.encodeSolution(solution)
            FileHandle.standardOutput.write(output)
            print()
        } else {
            printValidationReport(
                program: program,
                report: solver.validationReport(for: program),
                source: path
            )
        }
    }

    private static func exportJSON(path: String) throws {
        let program = try readLegacyProgram(path: path)
        let data = try LinearProgramJSON.encodeProgram(program)
        FileHandle.standardOutput.write(data)
        print()
    }

    private static func exportNetworkJSON(path: String) throws {
        let model = try readLegacyNetworkModel(path: path)
        let data = try NetworkModelJSON.encodeModel(model)
        FileHandle.standardOutput.write(data)
        print()
    }

    private static func solveNetworkJSON(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let model = try NetworkModelJSON.decodeModel(from: data)
        let solution = try solveNetworkModel(model)
        let output = try NetworkModelJSON.encodeSolution(solution)
        FileHandle.standardOutput.write(output)
        print()
    }

    private static func solveTimeSeries(path: String, periodsAhead: Int) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let model = try WinQSBForecastingParser.parseTimeSeries(from: expanded)
        let solution = try TimeSeriesTrendSolver.solve(model, periodsAhead: periodsAhead)

        printTimeSeriesHeader(model)
        print("method: linearTrend")
        print("intercept: \(format(solution.intercept))")
        print("slope: \(format(solution.slope))")
        print("meanActual: \(format(solution.meanActual))")
        printTimeSeriesAccuracy(
            mad: solution.meanAbsoluteDeviation,
            mse: solution.meanSquaredError,
            mape: solution.meanAbsolutePercentageError
        )
        printTimeSeriesFittedValues(solution.fittedValues)
        printTimeSeriesForecasts(solution.forecasts)
    }

    private static func solveMovingAverage(path: String, windowSize: Int, periodsAhead: Int) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let model = try WinQSBForecastingParser.parseTimeSeries(from: expanded)
        let solution = try TimeSeriesMovingAverageSolver.solve(
            model,
            windowSize: windowSize,
            periodsAhead: periodsAhead
        )

        printTimeSeriesHeader(model)
        print("method: movingAverage")
        print("windowSize: \(solution.windowSize)")
        printTimeSeriesAccuracy(
            mad: solution.meanAbsoluteDeviation,
            mse: solution.meanSquaredError,
            mape: solution.meanAbsolutePercentageError
        )
        printTimeSeriesFittedValues(solution.fittedValues)
        printTimeSeriesForecasts(solution.forecasts)
    }

    private static func solveExponentialSmoothing(path: String, alpha: Double, periodsAhead: Int) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let model = try WinQSBForecastingParser.parseTimeSeries(from: expanded)
        let solution = try TimeSeriesExponentialSmoothingSolver.solve(
            model,
            alpha: alpha,
            periodsAhead: periodsAhead
        )

        printTimeSeriesHeader(model)
        print("method: exponentialSmoothing")
        print("alpha: \(format(solution.alpha))")
        print("initialForecast: \(format(solution.initialForecast))")
        printTimeSeriesAccuracy(
            mad: solution.meanAbsoluteDeviation,
            mse: solution.meanSquaredError,
            mape: solution.meanAbsolutePercentageError
        )
        printTimeSeriesFittedValues(solution.fittedValues)
        printTimeSeriesForecasts(solution.forecasts)
    }

    private static func solveSeasonal(path: String, seasonLength: Int, periodsAhead: Int) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let model = try WinQSBForecastingParser.parseTimeSeries(from: expanded)
        let solution = try TimeSeriesSeasonalDecompositionSolver.solve(
            model,
            seasonLength: seasonLength,
            periodsAhead: periodsAhead
        )

        printTimeSeriesHeader(model)
        print("method: multiplicativeSeasonalDecomposition")
        print("seasonLength: \(solution.seasonLength)")
        print("intercept: \(format(solution.intercept))")
        print("slope: \(format(solution.slope))")
        print("meanActual: \(format(solution.meanActual))")
        print("seasonalFactors:")
        for factor in solution.seasonalFactors {
            print("season \(factor.seasonIndex): \(format(factor.factor))")
        }
        printTimeSeriesAccuracy(
            mad: solution.meanAbsoluteDeviation,
            mse: solution.meanSquaredError,
            mape: solution.meanAbsolutePercentageError
        )
        printTimeSeriesFittedValues(solution.fittedValues)
        printTimeSeriesForecasts(solution.forecasts)
    }

    private static func printTimeSeriesHeader(_ model: TimeSeriesModel) {
        print(model.title)
        print("timeUnit: \(model.timeUnit)")
        print("value: \(model.valueName)")
    }

    private static func printTimeSeriesAccuracy(mad: Double, mse: Double, mape: Double?) {
        print("mad: \(format(mad))")
        print("mse: \(format(mse))")
        if let mape {
            print("mape: \(format(mape))")
        }
    }

    private static func printTimeSeriesFittedValues(_ fittedValues: [TimeSeriesTrendPoint]) {
        for point in fittedValues {
            print("\(point.label): actual \(format(point.actual)), fitted \(format(point.fitted)), residual \(format(point.residual))")
        }
    }

    private static func printTimeSeriesForecasts(_ forecasts: [TimeSeriesForecast]) {
        for forecast in forecasts {
            print("\(forecast.label): forecast \(format(forecast.value))")
        }
    }

    private static func solveRegression(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let model = try WinQSBForecastingParser.parseRegression(from: expanded)
        let solution = try RegressionSolver.solve(model)

        print(model.title)
        print("dependent: \(model.dependentVariable)")
        print("intercept: \(format(solution.intercept))")
        for variable in model.independentVariables {
            print("\(variable): \(format(solution.coefficients[variable] ?? 0))")
        }
        print("sse: \(format(solution.sumSquaredErrors))")
        print("rSquared: \(format(solution.rSquared))")
        for prediction in solution.predictions {
            print("\(prediction.label): actual \(format(prediction.actual)), predicted \(format(prediction.predicted)), residual \(format(prediction.residual))")
        }
    }

    private static func solveEOQ(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let model = try WinQSBInventoryParser.parseEOQ(from: expanded)
        let solution = try EOQSolver.solve(model)

        print(model.title)
        print("timeUnit: \(model.timeUnit)")
        print("economicOrderQuantity: \(format(solution.economicOrderQuantity))")
        print("cycleCount: \(format(solution.cycleCount))")
        print("cycleLength: \(format(solution.cycleLength))")
        if let reorderPoint = solution.reorderPoint {
            print("reorderPoint: \(format(reorderPoint))")
        }
        printEOQCostBreakdown("optimum", solution.optimum)
        if let knownQuantity = solution.knownQuantity {
            printEOQCostBreakdown("knownQuantity", knownQuantity)
        }
    }

    private static func printEOQCostBreakdown(_ label: String, _ breakdown: EOQCostBreakdown) {
        print("\(label).orderQuantity: \(format(breakdown.orderQuantity))")
        print("\(label).setupCost: \(format(breakdown.setupCost))")
        print("\(label).holdingCost: \(format(breakdown.holdingCost))")
        print("\(label).acquisitionCost: \(format(breakdown.acquisitionCost))")
        print("\(label).totalRelevantCost: \(format(breakdown.totalRelevantCost))")
        print("\(label).totalCost: \(format(breakdown.totalCost))")
    }

    private static func solveDiscountEOQ(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let model = try WinQSBInventoryParser.parseQuantityDiscountEOQ(from: expanded)
        let solution = try QuantityDiscountEOQSolver.solve(model)

        print(model.title)
        print("timeUnit: \(model.timeUnit)")
        print("unconstrainedEOQ: \(format(solution.unconstrainedEOQ))")
        printDiscountCandidate("optimum", solution.optimum)
        for candidate in solution.candidates {
            printDiscountCandidate("candidate.minimum\(format(candidate.minimumQuantity))", candidate)
        }
        if let knownQuantity = solution.knownQuantity {
            printDiscountCandidate("knownQuantity", knownQuantity)
        }
    }

    private static func printDiscountCandidate(_ label: String, _ candidate: QuantityDiscountCandidate) {
        print("\(label).minimumQuantity: \(format(candidate.minimumQuantity))")
        print("\(label).discountPercent: \(format(candidate.discountPercent))")
        print("\(label).unitAcquisitionCost: \(format(candidate.unitAcquisitionCost))")
        print("\(label).orderQuantity: \(format(candidate.cost.orderQuantity))")
        print("\(label).setupCost: \(format(candidate.cost.setupCost))")
        print("\(label).holdingCost: \(format(candidate.cost.holdingCost))")
        print("\(label).acquisitionCost: \(format(candidate.cost.acquisitionCost))")
        print("\(label).totalCost: \(format(candidate.cost.totalCost))")
    }

    private static func solveNewsboy(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let model = try WinQSBInventoryParser.parseNewsboy(from: expanded)
        let solution = try NewsboySolver.solve(model)

        print(model.title)
        print("distribution: \(model.demandDistribution)")
        print("criticalRatio: \(format(solution.criticalRatio))")
        printNewsboyEvaluation("optimum", solution.optimum)
        if let knownQuantity = solution.knownQuantity {
            printNewsboyEvaluation("knownQuantity", knownQuantity)
        }
        if let desiredServiceLevelQuantity = solution.desiredServiceLevelQuantity {
            print("desiredServiceLevelQuantity: \(format(desiredServiceLevelQuantity))")
        }
    }

    private static func solveLotSizing(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let model = try WinQSBInventoryParser.parseLotSizing(from: expanded)
        let solution = try LotSizingSolver.solve(model)

        print(model.title)
        print("timeUnit: \(model.timeUnit)")
        print("totalCost: \(format(solution.totalCost))")
        for decision in solution.decisions {
            print("\(decision.period): demand \(decision.demand), produce \(decision.productionQuantity), endingInventory \(decision.endingInventory), setup \(format(decision.setupCost)), variable \(format(decision.variableCost)), holding \(format(decision.holdingCost)), backorder \(format(decision.backorderCost)), cost \(format(decision.totalCost))")
        }
    }

    private static func printNewsboyEvaluation(_ label: String, _ evaluation: NewsboyEvaluation) {
        print("\(label).orderQuantity: \(format(evaluation.orderQuantity))")
        print("\(label).inventoryPosition: \(format(evaluation.inventoryPosition))")
        print("\(label).serviceLevel: \(format(evaluation.serviceLevel))")
        print("\(label).expectedSales: \(format(evaluation.expectedSales))")
        print("\(label).expectedLeftover: \(format(evaluation.expectedLeftover))")
        print("\(label).expectedShortage: \(format(evaluation.expectedShortage))")
        print("\(label).expectedProfit: \(format(evaluation.expectedProfit))")
    }

    private static func solveFlowShop(path: String, backend: SolverBackendKind) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBSchedulingParser.parseFlowShop(from: expanded)
        let solver = try schedulingBackend(for: backend, command: "solve-flowshop")
        if solver.capabilities.solves {
            let solution = try solver.solve(problem)
            print(problem.title)
            print("backend: \(solver.capabilities.backendKind.rawValue)")
            print("timeUnit: \(problem.timeUnit)")
            print("makespan: \(solution.makespan)")
            print("sequence: \(solution.sequence.joined(separator: " -> "))")
            print("machineCompletionTimes: \(solution.machineCompletionTimes.map(String.init).joined(separator: ", "))")
            for schedule in solution.schedules {
                let operations = schedule.operations.map {
                    "M\($0.machineID) \($0.start)-\($0.finish)"
                }.joined(separator: ", ")
                print("\(schedule.jobName): \(operations), complete \(schedule.completionTime)")
            }
        } else {
            let report = solver.validationReport(for: problem)
            printSchedulingValidationReport(
                title: problem.title,
                modelType: "flowShop",
                jobCount: problem.jobs.count,
                machineCount: problem.machines.count,
                backend: report.backend,
                source: path,
                diagnostics: report.diagnostics
            )
        }
    }

    private static func solveFlowShopJSON(path: String, backend: SolverBackendKind) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBSchedulingParser.parseFlowShop(from: expanded)
        let solver = try schedulingBackend(for: backend, command: "solve-flowshop-json")
        if solver.capabilities.solves {
            let solution = try solver.solve(problem)
            let document = SchedulingSolutionJSON.flowShopDocument(
                problem: problem,
                solution: solution,
                backend: schedulingBackendMetadata(kind: .flowShop)
            )
            let output = try SchedulingSolutionJSON.encode(document)
            FileHandle.standardOutput.write(output)
            print()
        } else {
            let report = solver.validationReport(for: problem)
            printSchedulingValidationReport(
                title: problem.title,
                modelType: "flowShop",
                jobCount: problem.jobs.count,
                machineCount: problem.machines.count,
                backend: report.backend,
                source: path,
                diagnostics: report.diagnostics
            )
        }
    }

    private static func validateFlowShop(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBSchedulingParser.parseFlowShop(from: expanded)
        printSchedulingValidationReport(
            title: problem.title,
            modelType: "flowShop",
            jobCount: problem.jobs.count,
            machineCount: problem.machines.count,
            backend: .validateOnly,
            source: path,
            diagnostics: FlowShopValidator.diagnostics(for: problem)
        )
    }

    private static func solveJobShop(path: String, backend: SolverBackendKind) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBSchedulingParser.parseJobShop(from: expanded)
        let solver = try schedulingBackend(for: backend, command: "solve-jobshop")
        if solver.capabilities.solves {
            let solution = try solver.solve(problem)
            print(problem.title)
            print("backend: \(solver.capabilities.backendKind.rawValue)")
            print("timeUnit: \(problem.timeUnit)")
            print("makespan: \(solution.makespan)")
            print("machineCompletionTimes: \(solution.machineCompletionTimes.map(String.init).joined(separator: ", "))")
            print("dispatchOrder:")
            for step in solution.dispatchOrder {
                print("\(step.jobName) op \(step.operationIndex): M\(step.machineID) \(step.start)-\(step.finish)")
            }
            for schedule in solution.schedules {
                let operations = schedule.operations.enumerated().map { offset, operation in
                    "op \(offset + 1) M\(operation.machineID) \(operation.start)-\(operation.finish)"
                }.joined(separator: ", ")
                print("\(schedule.jobName): \(operations), complete \(schedule.completionTime)")
            }
        } else {
            let report = solver.validationReport(for: problem)
            printSchedulingValidationReport(
                title: problem.title,
                modelType: "jobShop",
                jobCount: problem.jobs.count,
                machineCount: problem.machines.count,
                backend: report.backend,
                source: path,
                diagnostics: report.diagnostics
            )
        }
    }

    private static func solveJobShopJSON(path: String, backend: SolverBackendKind) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBSchedulingParser.parseJobShop(from: expanded)
        let solver = try schedulingBackend(for: backend, command: "solve-jobshop-json")
        if solver.capabilities.solves {
            let solution = try solver.solve(problem)
            let document = SchedulingSolutionJSON.jobShopDocument(
                problem: problem,
                solution: solution,
                backend: schedulingBackendMetadata(kind: .jobShop)
            )
            let output = try SchedulingSolutionJSON.encode(document)
            FileHandle.standardOutput.write(output)
            print()
        } else {
            let report = solver.validationReport(for: problem)
            printSchedulingValidationReport(
                title: problem.title,
                modelType: "jobShop",
                jobCount: problem.jobs.count,
                machineCount: problem.machines.count,
                backend: report.backend,
                source: path,
                diagnostics: report.diagnostics
            )
        }
    }

    private static func validateJobShop(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBSchedulingParser.parseJobShop(from: expanded)
        printSchedulingValidationReport(
            title: problem.title,
            modelType: "jobShop",
            jobCount: problem.jobs.count,
            machineCount: problem.machines.count,
            backend: .validateOnly,
            source: path,
            diagnostics: JobShopValidator.diagnostics(for: problem)
        )
    }

    private static func exportFacilitiesJSON(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let envelope = try WinQSBFacilitiesParser.parseModelEnvelope(from: expanded)
        let encoded = try FacilitiesModelJSON.encodeModel(envelope)
        FileHandle.standardOutput.write(encoded)
        print()
    }

    private static func solveFacilitiesJSON(
        path: String,
        backend: SolverBackendKind,
        layoutStrategy: FacilityLayoutSolvingStrategy
    ) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let envelope = try FacilitiesModelJSON.decodeModel(from: data)
        let solver = try facilitiesBackend(for: backend, command: "solve-facilities-json")

        if solver.capabilities.solves {
            let solutionEnvelope = try solver.solve(envelope, layoutStrategy: layoutStrategy)
            let document = FacilitiesSolutionDocument(
                backend: solver.runMetadata(for: envelope, layoutStrategy: layoutStrategy),
                solution: solutionEnvelope
            )
            let encoded = try FacilitiesModelJSON.encodeSolutionDocument(document)
            FileHandle.standardOutput.write(encoded)
            print()
        } else {
            let report = solver.validationReport(for: envelope)
            switch envelope {
            case .lineBalancing(let problem):
                printLineBalancingValidationReport(
                    problem: problem,
                    backend: report.backend,
                    source: path,
                    diagnostics: report.diagnostics
                )
            case .location(let problem):
                printFacilityLocationValidationReport(
                    problem: problem,
                    backend: report.backend,
                    source: path,
                    diagnostics: report.diagnostics
                )
            case .layout(let problem):
                printFacilityLayoutValidationReport(
                    problem: problem,
                    backend: report.backend,
                    source: path,
                    diagnostics: report.diagnostics
                )
            }
        }
    }

    private static func validateFacilitiesJSON(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let envelope = try FacilitiesModelJSON.decodeUncheckedModel(from: data)
        let solver = try facilitiesBackend(for: .validateOnly, command: "validate-facilities-json")
        let report = solver.validationReport(for: envelope)
        let document = FacilitiesValidationDocument(
            kind: envelope.kind,
            backend: report.backend,
            diagnostics: report.diagnostics
        )
        let encoded = try FacilitiesModelJSON.encodeValidation(document)
        FileHandle.standardOutput.write(encoded)
        print()
    }

    private static func solveLineBalancing(path: String, backend: SolverBackendKind) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBFacilitiesParser.parseLineBalancing(from: expanded)
        let solver = try facilitiesBackend(for: backend, command: "solve-line-balancing")

        if solver.capabilities.solves {
            let solution = try solver.solve(problem)
            print(problem.title)
            print("backend: \(backend.rawValue)")
            print("timeUnit: \(problem.timeUnit)")
            print("cycleTime: \(solution.cycleTime)")
            print("totalTaskTime: \(solution.totalTaskTime)")
            print("stationCount: \(solution.stationCount)")
            print("efficiency: \(format(solution.efficiency))")
            print("balanceDelay: \(format(solution.balanceDelay))")
            for station in solution.stations {
                let taskList = station.taskIDs.map(String.init).joined(separator: ", ")
                print("station \(station.index): tasks \(taskList), workload \(station.workload), idle \(station.idleTime)")
            }
        } else {
            let report = solver.validationReport(for: problem)
            printLineBalancingValidationReport(
                problem: problem,
                backend: report.backend,
                source: path,
                diagnostics: report.diagnostics
            )
        }
    }

    private static func validateLineBalancing(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBFacilitiesParser.parseLineBalancing(from: expanded)
        let solver = try facilitiesBackend(for: .validateOnly, command: "validate-line-balancing")
        let report = solver.validationReport(for: problem)
        printLineBalancingValidationReport(
            problem: problem,
            backend: report.backend,
            source: path,
            diagnostics: report.diagnostics
        )
    }

    private static func exportLineBalancingJSON(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBFacilitiesParser.parseLineBalancing(from: expanded)
        let encoded = try LineBalancingJSON.encodeModel(problem)
        FileHandle.standardOutput.write(encoded)
        print()
    }

    private static func solveLineBalancingJSON(path: String, backend: SolverBackendKind) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let problem = try LineBalancingJSON.decodeModel(from: data)
        let solver = try facilitiesBackend(for: backend, command: "solve-line-balancing-json")

        if solver.capabilities.solves {
            let solution = try solver.solve(problem)
            let encoded = try LineBalancingJSON.encodeSolution(solution)
            FileHandle.standardOutput.write(encoded)
            print()
        } else {
            let report = solver.validationReport(for: problem)
            printLineBalancingValidationReport(
                problem: problem,
                backend: report.backend,
                source: path,
                diagnostics: report.diagnostics
            )
        }
    }

    private static func solveLocation(path: String, backend: SolverBackendKind) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBFacilitiesParser.parseLocation(from: expanded)
        let solver = try facilitiesBackend(for: backend, command: "solve-location")

        if solver.capabilities.solves {
            let solution = try solver.solve(problem)
            print(problem.title)
            print("backend: \(backend.rawValue)")
            print("distanceMeasure: \(solution.distanceMeasure.rawValue)")
            print("objective: \(problem.objective)")
            print("objectiveValue: \(format(solution.objectiveValue))")
            for placement in solution.placements {
                print("\(placement.facilityName): x \(format(placement.x)), y \(format(placement.y)), weightedDistance \(format(placement.weightedDistance))")
                for interaction in placement.interactions {
                    print("to \(interaction.existingFacilityName): weight \(format(interaction.weight)), distance \(format(interaction.distance)), weightedDistance \(format(interaction.weightedDistance))")
                }
            }
        } else {
            let report = solver.validationReport(for: problem)
            printFacilityLocationValidationReport(
                problem: problem,
                backend: report.backend,
                source: path,
                diagnostics: report.diagnostics
            )
        }
    }

    private static func validateLocation(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBFacilitiesParser.parseLocation(from: expanded)
        let solver = try facilitiesBackend(for: .validateOnly, command: "validate-location")
        let report = solver.validationReport(for: problem)
        printFacilityLocationValidationReport(
            problem: problem,
            backend: report.backend,
            source: path,
            diagnostics: report.diagnostics
        )
    }

    private static func exportLocationJSON(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBFacilitiesParser.parseLocation(from: expanded)
        let encoded = try FacilityLocationJSON.encodeModel(problem)
        FileHandle.standardOutput.write(encoded)
        print()
    }

    private static func solveLocationJSON(path: String, backend: SolverBackendKind) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let problem = try FacilityLocationJSON.decodeModel(from: data)
        let solver = try facilitiesBackend(for: backend, command: "solve-location-json")

        if solver.capabilities.solves {
            let solution = try solver.solve(problem)
            let encoded = try FacilityLocationJSON.encodeSolution(solution)
            FileHandle.standardOutput.write(encoded)
            print()
        } else {
            let report = solver.validationReport(for: problem)
            printFacilityLocationValidationReport(
                problem: problem,
                backend: report.backend,
                source: path,
                diagnostics: report.diagnostics
            )
        }
    }

    private static func solveLayout(
        path: String,
        backend: SolverBackendKind,
        strategy: FacilityLayoutSolvingStrategy
    ) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBFacilitiesParser.parseLayout(from: expanded)
        let solver = try facilitiesBackend(for: backend, command: "solve-layout")

        if solver.capabilities.solves {
            let solution = try solver.solve(problem, strategy: strategy)
            print(problem.title)
            print("backend: \(backend.rawValue)")
            print("objective: \(solution.objective)")
            print("source: \(solution.source)")
            print("grid: \(problem.rowCount)x\(problem.columnCount)")
            print("objectiveValue: \(format(solution.objectiveValue))")
            if let search = solution.search {
                print("layoutStrategy: \(search.strategy.rawValue)")
                print("initialObjectiveValue: \(format(search.initialObjectiveValue))")
                print("improvement: \(format(search.improvement))")
                print("evaluatedMoves: \(search.evaluatedMoveCount)")
                print("appliedMoves: \(search.appliedMoveCount)")
                for move in solution.moves {
                    print("move: swap \(move.firstDepartmentName) <-> \(move.secondDepartmentName), objective \(format(move.objectiveBefore)) -> \(format(move.objectiveAfter)), improvement \(format(move.improvement))")
                }
            }
            print("departments: \(solution.placements.count)")
            for placement in solution.placements {
                let fixed = placement.fixed ? "yes" : "no"
                print("\(placement.departmentName): cells \(placement.cellCount), centroid (\(format(placement.centroidRow)), \(format(placement.centroidColumn))), fixed \(fixed)")
            }
            print("interactions: \(solution.interactions.count)")
            for interaction in solution.interactions.sorted(by: { $0.weightedDistance > $1.weightedDistance }).prefix(10) {
                print("\(interaction.fromDepartmentName) -> \(interaction.toDepartmentName): weight \(format(interaction.weight)), distance \(format(interaction.distance)), weightedDistance \(format(interaction.weightedDistance))")
            }
        } else {
            let report = solver.validationReport(for: problem)
            printFacilityLayoutValidationReport(
                problem: problem,
                backend: report.backend,
                source: path,
                diagnostics: report.diagnostics
            )
        }
    }

    private static func validateLayout(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBFacilitiesParser.parseLayout(from: expanded)
        let solver = try facilitiesBackend(for: .validateOnly, command: "validate-layout")
        let report = solver.validationReport(for: problem)
        printFacilityLayoutValidationReport(
            problem: problem,
            backend: report.backend,
            source: path,
            diagnostics: report.diagnostics
        )
    }

    private static func exportLayoutJSON(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBFacilitiesParser.parseLayout(from: expanded)
        let encoded = try FacilityLayoutJSON.encodeModel(problem)
        FileHandle.standardOutput.write(encoded)
        print()
    }

    private static func solveLayoutJSON(
        path: String,
        backend: SolverBackendKind,
        strategy: FacilityLayoutSolvingStrategy
    ) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let problem = try FacilityLayoutJSON.decodeModel(from: data)
        let solver = try facilitiesBackend(for: backend, command: "solve-layout-json")

        if solver.capabilities.solves {
            let solution = try solver.solve(problem, strategy: strategy)
            let encoded = try FacilityLayoutJSON.encodeSolution(solution)
            FileHandle.standardOutput.write(encoded)
            print()
        } else {
            let report = solver.validationReport(for: problem)
            printFacilityLayoutValidationReport(
                problem: problem,
                backend: report.backend,
                source: path,
                diagnostics: report.diagnostics
            )
        }
    }

    private static func solveKnapsack(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBDynamicProgrammingParser.parseKnapsack(from: expanded)
        let solution = try KnapsackSolver.solve(problem)

        print(problem.title)
        print("capacity: \(problem.capacity)")
        print("totalReturn: \(format(solution.totalReturn))")
        print("capacityUsed: \(solution.capacityUsed)")
        for selection in solution.selections {
            print("\(selection.item): \(selection.quantity), capacity \(selection.capacityUsed), return \(format(selection.returnValue))")
        }
    }

    private static func solveStagecoach(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBDynamicProgrammingParser.parseStagecoach(from: expanded)
        let solution = try StagecoachSolver.solve(problem)

        print(problem.title)
        print("source: \(solution.source)")
        print("sink: \(solution.sink)")
        print("totalCost: \(format(solution.totalCost))")
        print("path: \(solution.path.joined(separator: " -> "))")
    }

    private static func solveProductionInventory(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBDynamicProgrammingParser.parseProductionInventory(from: expanded)
        let solution = try ProductionInventorySolver.solve(problem)

        print(problem.title)
        print("totalCost: \(format(solution.totalCost))")
        for decision in solution.decisions {
            print("\(decision.period): begin \(decision.beginningInventory), produce \(decision.productionQuantity), demand \(decision.demand), end \(decision.endingInventory), cost \(format(decision.cost))")
        }
    }

    private static func solvePayoff(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBDecisionAnalysisParser.parsePayoff(from: expanded)
        let solution = try DecisionPayoffSolver.solve(problem)

        print(problem.title)
        print("bestPriorDecision: \(solution.bestPriorDecision)")
        print("bestPriorExpectedValue: \(format(solution.bestPriorExpectedValue))")
        for expectedValue in solution.priorExpectedValues {
            print("\(expectedValue.decision): \(format(expectedValue.expectedValue))")
        }
        print("expectedValueWithSampleInformation: \(format(solution.expectedValueWithSampleInformation))")
        print("expectedValueOfSampleInformation: \(format(solution.expectedValueOfSampleInformation))")
        print("expectedValueWithPerfectInformation: \(format(solution.expectedValueWithPerfectInformation))")
        print("expectedValueOfPerfectInformation: \(format(solution.expectedValueOfPerfectInformation))")
        for analysis in solution.indicatorAnalyses {
            print("\(analysis.indicator): probability \(format(analysis.probability)), best \(analysis.bestDecision), value \(format(analysis.bestExpectedValue))")
        }
    }

    private static func solveBayesian(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBDecisionAnalysisParser.parseBayesianAnalysis(from: expanded)
        let solution = try BayesianAnalysisSolver.solve(problem)

        print(problem.title)
        for outcome in solution.outcomes {
            print("\(outcome.outcome): probability \(format(outcome.probability))")
            for index in problem.states.indices {
                print("  \(problem.states[index]): \(format(outcome.posteriorProbabilities[index]))")
            }
        }
    }

    private static func solveDecisionTree(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let tree = try WinQSBDecisionAnalysisParser.parseDecisionTree(from: expanded)
        let solution = try DecisionTreeSolver.solve(tree)

        print(tree.title)
        print("root: \(tree.rootID)")
        print("expectedValue: \(format(solution.expectedValue))")
        for decision in solution.policy {
            print("\(decision.nodeName): choose \(decision.selectedChildName), value \(format(decision.expectedValue))")
        }
    }

    private static func solveGame(path: String, backend: SolverBackendKind) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let game = try WinQSBDecisionAnalysisParser.parseZeroSumGame(from: expanded)

        switch backend {
        case .nativeEducational:
            let solution = try ZeroSumGameSolver.solve(
                game,
                linearProgrammingBackend: try linearProgrammingBackend(
                    for: backend,
                    command: "solve-game"
                )
            )
            print(game.title)
            print("backend: \(backend.rawValue)")
            print("value: \(format(solution.value))")
            print("rowStrategy:")
            for probability in solution.rowStrategy {
                print("\(probability.strategy): \(format(probability.probability))")
            }
            print("columnStrategy:")
            for probability in solution.columnStrategy {
                print("\(probability.strategy): \(format(probability.probability))")
            }
        case .validateOnly:
            printZeroSumGameValidationReport(
                game: game,
                backend: backend,
                source: path,
                diagnostics: ZeroSumGameValidator.diagnostics(for: game)
            )
        case .externalHighPerformance:
            throw CLIError.usage("external backend is not available yet for solve-game")
        }
    }

    private static func validateGame(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let game = try WinQSBDecisionAnalysisParser.parseZeroSumGame(from: expanded)
        printZeroSumGameValidationReport(
            game: game,
            backend: .validateOnly,
            source: path,
            diagnostics: ZeroSumGameValidator.diagnostics(for: game)
        )
    }

    private static func solveMM1(path: String, backend: SolverBackendKind) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let model = try WinQSBQueuingParser.parseMM1(from: expanded)
        let solver = try queuingBackend(for: backend, command: "solve-mm1")

        guard solver.capabilities.solves else {
            printQueuingValidationReport(
                title: model.title,
                modelType: "mm1",
                backend: solver.capabilities.backendKind,
                source: path,
                diagnostics: solver.validationReport(for: model).diagnostics
            )
            return
        }

        let solution = try solver.solve(model)

        print(model.title)
        print("timeUnit: \(model.timeUnit)")
        print("utilization: \(format(solution.utilization))")
        print("probabilitySystemEmpty: \(format(solution.probabilitySystemEmpty))")
        print("averageNumberInSystem: \(format(solution.averageNumberInSystem))")
        print("averageNumberInQueue: \(format(solution.averageNumberInQueue))")
        print("averageTimeInSystem: \(format(solution.averageTimeInSystem))")
        print("averageTimeInQueue: \(format(solution.averageTimeInQueue))")
        if let cost = solution.cost {
            print("cost.busyServer: \(format(cost.busyServerCost))")
            print("cost.idleServer: \(format(cost.idleServerCost))")
            print("cost.customerWaiting: \(format(cost.customerWaitingCost))")
            print("cost.customerBeingServed: \(format(cost.customerBeingServedCost))")
            print("cost.total: \(format(cost.totalCost))")
        }
    }

    private static func solveMM1JSON(path: String, backend: SolverBackendKind) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let model = try WinQSBQueuingParser.parseMM1(from: expanded)
        let solver = try queuingBackend(for: backend, command: "solve-mm1-json")

        guard solver.capabilities.solves else {
            printQueuingValidationReport(
                title: model.title,
                modelType: "mm1",
                backend: solver.capabilities.backendKind,
                source: path,
                diagnostics: solver.validationReport(for: model).diagnostics
            )
            return
        }

        let solution = try solver.solve(model)
        let document = QueuingSolutionJSON.mm1Document(
            model: model,
            solution: solution,
            backend: queuingBackendMetadata(kind: .mm1)
        )
        FileHandle.standardOutput.write(try QueuingSolutionJSON.encode(document))
        print()
    }

    private static func validateMM1(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let model = try WinQSBQueuingParser.parseMM1(from: expanded)
        printQueuingValidationReport(
            title: model.title,
            modelType: "mm1",
            backend: .validateOnly,
            source: path,
            diagnostics: MM1QueueValidator.diagnostics(for: model)
        )
    }

    private static func solveFiniteQueue(path: String, backend: SolverBackendKind) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let model = try WinQSBQueuingParser.parseFiniteCapacity(from: expanded)
        let solver = try queuingBackend(for: backend, command: "solve-finite-queue")

        guard solver.capabilities.solves else {
            printQueuingValidationReport(
                title: model.title,
                modelType: "finiteCapacity",
                backend: solver.capabilities.backendKind,
                source: path,
                diagnostics: solver.validationReport(for: model).diagnostics
            )
            return
        }

        let solution = try solver.solve(model)

        print(model.title)
        print("timeUnit: \(model.timeUnit)")
        print("servers: \(model.servers)")
        print("queueCapacity: \(model.queueCapacity)")
        print("arrivalRate: \(format(solution.arrivalRate))")
        print("serviceRatePerServer: \(format(solution.serviceRatePerServer))")
        print("effectiveArrivalRate: \(format(solution.effectiveArrivalRate))")
        print("utilization: \(format(solution.utilization))")
        print("probabilitySystemEmpty: \(format(solution.probabilitySystemEmpty))")
        print("probabilitySystemFull: \(format(solution.probabilitySystemFull))")
        print("averageNumberInSystem: \(format(solution.averageNumberInSystem))")
        print("averageNumberInQueue: \(format(solution.averageNumberInQueue))")
        print("averageNumberBeingServed: \(format(solution.averageNumberBeingServed))")
        print("averageTimeInSystem: \(format(solution.averageTimeInSystem))")
        print("averageTimeInQueue: \(format(solution.averageTimeInQueue))")
        for index in solution.stateProbabilities.indices {
            print("p\(index): \(format(solution.stateProbabilities[index]))")
        }
        if let cost = solution.cost {
            print("cost.busyServer: \(format(cost.busyServerCost))")
            print("cost.idleServer: \(format(cost.idleServerCost))")
            print("cost.customerWaiting: \(format(cost.customerWaitingCost))")
            print("cost.customerBeingServed: \(format(cost.customerBeingServedCost))")
            print("cost.balkedCustomer: \(format(cost.balkedCustomerCost))")
            print("cost.queueCapacity: \(format(cost.queueCapacityCost))")
            print("cost.total: \(format(cost.totalCost))")
        }
    }

    private static func solveFiniteQueueJSON(path: String, backend: SolverBackendKind) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let model = try WinQSBQueuingParser.parseFiniteCapacity(from: expanded)
        let solver = try queuingBackend(for: backend, command: "solve-finite-queue-json")

        guard solver.capabilities.solves else {
            printQueuingValidationReport(
                title: model.title,
                modelType: "finiteCapacity",
                backend: solver.capabilities.backendKind,
                source: path,
                diagnostics: solver.validationReport(for: model).diagnostics
            )
            return
        }

        let solution = try solver.solve(model)
        let document = QueuingSolutionJSON.finiteCapacityDocument(
            model: model,
            solution: solution,
            backend: queuingBackendMetadata(kind: .finiteCapacity)
        )
        FileHandle.standardOutput.write(try QueuingSolutionJSON.encode(document))
        print()
    }

    private static func validateFiniteQueue(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let model = try WinQSBQueuingParser.parseFiniteCapacity(from: expanded)
        printQueuingValidationReport(
            title: model.title,
            modelType: "finiteCapacity",
            backend: .validateOnly,
            source: path,
            diagnostics: FiniteCapacityQueueValidator.diagnostics(for: model)
        )
    }

    private static func solveShortestPath(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let network = try WinQSBNetworkParser.parseShortestPath(from: expanded)
        let solution = try ShortestPathSolver.solve(network)

        print(network.title)
        print("source: \(solution.source)")
        print("sink: \(solution.sink)")
        print("totalCost: \(format(solution.totalCost))")
        print("path: \(solution.path.joined(separator: " -> "))")
    }

    private static func solveMinimumSpanningTree(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let network = try WinQSBNetworkParser.parseMinimumSpanningTree(from: expanded)
        let solution = try MinimumSpanningTreeSolver.solve(network)

        print(network.title)
        print("totalCost: \(format(solution.totalCost))")
        for edge in solution.edges {
            print("\(edge.from) -- \(edge.to): \(format(edge.cost))")
        }
    }

    private static func solveMaxFlow(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let network = try WinQSBNetworkParser.parseMaxFlow(from: expanded)
        let solution = try MaxFlowSolver.solve(network)

        print(network.title)
        print("source: \(solution.source)")
        print("sink: \(solution.sink)")
        print("maxFlow: \(format(solution.maxFlow))")
        for arc in solution.arcFlows {
            print("\(arc.from) -> \(arc.to): \(format(arc.flow))")
        }
    }

    private static func solveTravelingSalesperson(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBNetworkParser.parseTravelingSalesperson(from: expanded)
        let solution = try TravelingSalespersonSolver.solve(problem)

        print(problem.title)
        print("source: \(solution.source)")
        print("totalCost: \(format(solution.totalCost))")
        print("tour: \(solution.tour.joined(separator: " -> "))")
    }

    private static func solveAssignment(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBNetworkParser.parseAssignment(from: expanded)
        let solution = try AssignmentSolver.solve(problem)

        print(problem.title)
        print("totalCost: \(format(solution.totalCost))")
        for assignment in solution.assignments {
            print("\(assignment.worker) -> \(assignment.task): \(format(assignment.cost))")
        }
    }

    private static func solveTransportation(path: String, backend: SolverBackendKind) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBNetworkParser.parseTransportation(from: expanded)

        switch backend {
        case .nativeEducational:
            let solution = try TransportationSolver.solve(
                problem,
                linearProgrammingBackend: try linearProgrammingBackend(
                    for: backend,
                    command: "solve-transport"
                )
            )
            print(problem.title)
            print("backend: \(backend.rawValue)")
            print("totalCost: \(format(solution.totalCost))")
            for shipment in solution.shipments {
                print("\(shipment.origin) -> \(shipment.destination): \(format(shipment.quantity)) @ \(format(shipment.unitCost))")
            }
        case .validateOnly:
            printTransportationValidationReport(
                problem: problem,
                backend: backend,
                source: path,
                diagnostics: TransportationValidator.diagnostics(for: problem)
            )
        case .externalHighPerformance:
            throw CLIError.usage("external backend is not available yet for solve-transport")
        }
    }

    private static func validateTransportation(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let problem = try WinQSBNetworkParser.parseTransportation(from: expanded)
        printTransportationValidationReport(
            problem: problem,
            backend: .validateOnly,
            source: path,
            diagnostics: TransportationValidator.diagnostics(for: problem)
        )
    }

    private static func readLegacyProgram(path: String) throws -> LinearProgram {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        return try WinQSBMatrixParser.parseLP(from: expanded)
    }

    private static func readLegacyNetworkModel(path: String) throws -> NetworkModelEnvelope {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        return try WinQSBNetworkParser.parseModelEnvelope(from: expanded)
    }

    private static func solveNetworkModel(_ model: NetworkModelEnvelope) throws -> NetworkSolutionEnvelope {
        switch model {
        case .shortestPath(let network):
            return .shortestPath(try ShortestPathSolver.solve(network))
        case .minimumSpanningTree(let network):
            return .minimumSpanningTree(try MinimumSpanningTreeSolver.solve(network))
        case .maxFlow(let network):
            return .maxFlow(try MaxFlowSolver.solve(network))
        case .travelingSalesperson(let problem):
            return .travelingSalesperson(try TravelingSalespersonSolver.solve(problem))
        case .assignment(let problem):
            return .assignment(try AssignmentSolver.solve(problem))
        case .transportation(let problem):
            return .transportation(try TransportationSolver.solve(problem))
        }
    }

    private static func printSolution(
        program: LinearProgram,
        solution: LinearProgramSolution,
        backend: SolverBackendKind
    ) {
        print(program.title)
        print("backend: \(backend.rawValue)")
        print("objective: \(format(solution.objectiveValue))")
        for name in program.variableNames {
            print("\(name): \(format(solution.variableValues[name] ?? 0))")
        }
    }

    private static func printValidationReport(
        program: LinearProgram,
        backend: SolverBackendKind,
        source: String
    ) {
        printValidationReport(
            program: program,
            report: ValidationReport(
                backend: backend,
                diagnostics: LinearProgramValidator.diagnostics(for: program)
            ),
            source: source
        )
    }

    private static func printValidationReport(
        program: LinearProgram,
        report: ValidationReport,
        source: String
    ) {
        let diagnostics = report.diagnostics
        let errors = diagnostics.filter { $0.severity == .error }
        let warnings = diagnostics.filter { $0.severity == .warning }

        print(program.title)
        print("backend: \(report.backend.rawValue)")
        print("source: \(source)")
        print("status: \(errors.isEmpty ? "valid" : "invalid")")
        print("variables: \(program.variableNames.count)")
        print("constraints: \(program.constraints.count)")
        print("errors: \(errors.count)")
        print("warnings: \(warnings.count)")
        for diagnostic in diagnostics {
            let path = diagnostic.path.map { " [\($0)]" } ?? ""
            print("\(diagnostic.severity.rawValue): \(diagnostic.code)\(path) - \(diagnostic.message)")
        }
    }

    private static func printSchedulingValidationReport(
        title: String,
        modelType: String,
        jobCount: Int,
        machineCount: Int,
        backend: SolverBackendKind,
        source: String,
        diagnostics: [ValidationDiagnostic]
    ) {
        let errors = diagnostics.filter { $0.severity == .error }
        let warnings = diagnostics.filter { $0.severity == .warning }

        print(title)
        print("backend: \(backend.rawValue)")
        print("source: \(source)")
        print("modelType: \(modelType)")
        print("status: \(errors.isEmpty ? "valid" : "invalid")")
        print("jobs: \(jobCount)")
        print("machines: \(machineCount)")
        print("errors: \(errors.count)")
        print("warnings: \(warnings.count)")
        for diagnostic in diagnostics {
            let path = diagnostic.path.map { " [\($0)]" } ?? ""
            print("\(diagnostic.severity.rawValue): \(diagnostic.code)\(path) - \(diagnostic.message)")
        }
    }

    private static func printTransportationValidationReport(
        problem: TransportationProblem,
        backend: SolverBackendKind,
        source: String,
        diagnostics: [ValidationDiagnostic]
    ) {
        let errors = diagnostics.filter { $0.severity == .error }
        let warnings = diagnostics.filter { $0.severity == .warning }

        print(problem.title)
        print("backend: \(backend.rawValue)")
        print("source: \(source)")
        print("modelType: transportation")
        print("status: \(errors.isEmpty ? "valid" : "invalid")")
        print("origins: \(problem.origins.count)")
        print("destinations: \(problem.destinations.count)")
        print("totalSupply: \(format(problem.supply.reduce(0, +)))")
        print("totalDemand: \(format(problem.demand.reduce(0, +)))")
        print("errors: \(errors.count)")
        print("warnings: \(warnings.count)")
        for diagnostic in diagnostics {
            let path = diagnostic.path.map { " [\($0)]" } ?? ""
            print("\(diagnostic.severity.rawValue): \(diagnostic.code)\(path) - \(diagnostic.message)")
        }
    }

    private static func printQueuingValidationReport(
        title: String,
        modelType: String,
        backend: SolverBackendKind,
        source: String,
        diagnostics: [ValidationDiagnostic]
    ) {
        let errors = diagnostics.filter { $0.severity == .error }
        let warnings = diagnostics.filter { $0.severity == .warning }

        print(title)
        print("backend: \(backend.rawValue)")
        print("source: \(source)")
        print("modelType: \(modelType)")
        print("status: \(errors.isEmpty ? "valid" : "invalid")")
        print("errors: \(errors.count)")
        print("warnings: \(warnings.count)")
        for diagnostic in diagnostics {
            let path = diagnostic.path.map { " [\($0)]" } ?? ""
            print("\(diagnostic.severity.rawValue): \(diagnostic.code)\(path) - \(diagnostic.message)")
        }
    }

    private static func printZeroSumGameValidationReport(
        game: ZeroSumGame,
        backend: SolverBackendKind,
        source: String,
        diagnostics: [ValidationDiagnostic]
    ) {
        let errors = diagnostics.filter { $0.severity == .error }
        let warnings = diagnostics.filter { $0.severity == .warning }

        print(game.title)
        print("backend: \(backend.rawValue)")
        print("source: \(source)")
        print("modelType: zeroSumGame")
        print("status: \(errors.isEmpty ? "valid" : "invalid")")
        print("rowStrategies: \(game.rowStrategies.count)")
        print("columnStrategies: \(game.columnStrategies.count)")
        print("errors: \(errors.count)")
        print("warnings: \(warnings.count)")
        for diagnostic in diagnostics {
            let path = diagnostic.path.map { " [\($0)]" } ?? ""
            print("\(diagnostic.severity.rawValue): \(diagnostic.code)\(path) - \(diagnostic.message)")
        }
    }

    private static func printLineBalancingValidationReport(
        problem: LineBalancingProblem,
        backend: SolverBackendKind,
        source: String,
        diagnostics: [ValidationDiagnostic]
    ) {
        let errors = diagnostics.filter { $0.severity == .error }
        let warnings = diagnostics.filter { $0.severity == .warning }

        print(problem.title)
        print("backend: \(backend.rawValue)")
        print("source: \(source)")
        print("modelType: lineBalancing")
        print("status: \(errors.isEmpty ? "valid" : "invalid")")
        print("timeUnit: \(problem.timeUnit)")
        print("cycleTime: \(problem.cycleTime)")
        print("tasks: \(problem.tasks.count)")
        print("totalTaskTime: \(problem.tasks.reduce(0) { $0 + $1.time })")
        print("errors: \(errors.count)")
        print("warnings: \(warnings.count)")
        for diagnostic in diagnostics {
            let path = diagnostic.path.map { " [\($0)]" } ?? ""
            print("\(diagnostic.severity.rawValue): \(diagnostic.code)\(path) - \(diagnostic.message)")
        }
    }

    private static func printFacilityLocationValidationReport(
        problem: FacilityLocationProblem,
        backend: SolverBackendKind,
        source: String,
        diagnostics: [ValidationDiagnostic]
    ) {
        let errors = diagnostics.filter { $0.severity == .error }
        let warnings = diagnostics.filter { $0.severity == .warning }

        print(problem.title)
        print("backend: \(backend.rawValue)")
        print("source: \(source)")
        print("modelType: facilityLocation")
        print("status: \(errors.isEmpty ? "valid" : "invalid")")
        print("distanceMeasure: \(problem.distanceMeasure.rawValue)")
        print("objective: \(problem.objective)")
        print("facilities: \(problem.facilities.count)")
        print("existingFacilities: \(problem.existingFacilities.count)")
        print("newFacilities: \(problem.newFacilities.count)")
        print("errors: \(errors.count)")
        print("warnings: \(warnings.count)")
        for diagnostic in diagnostics {
            let path = diagnostic.path.map { " [\($0)]" } ?? ""
            print("\(diagnostic.severity.rawValue): \(diagnostic.code)\(path) - \(diagnostic.message)")
        }
    }

    private static func printFacilityLayoutValidationReport(
        problem: FacilityLayoutProblem,
        backend: SolverBackendKind,
        source: String,
        diagnostics: [ValidationDiagnostic]
    ) {
        let errors = diagnostics.filter { $0.severity == .error }
        let warnings = diagnostics.filter { $0.severity == .warning }

        print(problem.title)
        print("backend: \(backend.rawValue)")
        print("source: \(source)")
        print("modelType: facilityLayout")
        print("status: \(errors.isEmpty ? "valid" : "invalid")")
        print("grid: \(problem.rowCount)x\(problem.columnCount)")
        print("departments: \(problem.departments.count)")
        print("fixedDepartments: \(problem.fixedDepartments.count)")
        print("errors: \(errors.count)")
        print("warnings: \(warnings.count)")
        for diagnostic in diagnostics {
            let path = diagnostic.path.map { " [\($0)]" } ?? ""
            print("\(diagnostic.severity.rawValue): \(diagnostic.code)\(path) - \(diagnostic.message)")
        }
    }

    private static func printPreview(_ data: Data) {
        let prefix = data.prefix(512)
        if let text = String(data: prefix, encoding: .isoLatin1) {
            print("--- preview ---")
            print(text.replacingOccurrences(of: "\r", with: ""))
        }
    }

    private static func format(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 1e-8 {
            return String(Int(rounded))
        }
        return String(format: "%.6f", value)
    }

    private static func printUsage(to handle: FileHandle) {
        write("""
        qsb inspect <legacy-file>
        qsb inventory-fixtures <reference-directory>
        qsb solve-lp <legacy-lp-file> [--backend native|validate]
        qsb solve-ilp <legacy-lp-file> [--backend native|validate]
        qsb validate-lp <legacy-lp-file>
        qsb export-json <legacy-lp-file>
        qsb solve-json <model-json-file> [--backend native|validate]
        qsb solve-json-ilp <model-json-file> [--backend native|validate]
        qsb validate-json <model-json-file>
        qsb export-network-json <legacy-network-file>
        qsb solve-network-json <network-model-json-file>
        qsb solve-timeseries <legacy-fc-time-series-file> [periods-ahead]
        qsb solve-moving-average <legacy-fc-time-series-file> <window-size> [periods-ahead]
        qsb solve-exp-smoothing <legacy-fc-time-series-file> <alpha> [periods-ahead]
        qsb solve-seasonal <legacy-fc-time-series-file> <season-length> [periods-ahead]
        qsb solve-regression <legacy-fc-regression-file>
        qsb solve-eoq <legacy-its-eoq-file>
        qsb solve-discount-eoq <legacy-its-discount-eoq-file>
        qsb solve-newsboy <legacy-its-newsboy-file>
        qsb solve-lot-sizing <legacy-its-lot-sizing-file>
        qsb solve-flowshop <legacy-sch-flow-shop-file> [--backend native|validate]
        qsb solve-flowshop-json <legacy-sch-flow-shop-file> [--backend native|validate]
        qsb solve-jobshop <legacy-sch-job-shop-file> [--backend native|validate]
        qsb solve-jobshop-json <legacy-sch-job-shop-file> [--backend native|validate]
        qsb validate-flowshop <legacy-sch-flow-shop-file>
        qsb validate-jobshop <legacy-sch-job-shop-file>
        qsb export-facilities-json <legacy-fll-file>
        qsb validate-facilities-json <facilities-model-json-file>
        qsb solve-facilities-json <facilities-model-json-file> [--backend native|validate] [--layout-strategy initial|pairwise-swap]
        qsb solve-line-balancing <legacy-fll-line-balancing-file> [--backend native|validate]
        qsb validate-line-balancing <legacy-fll-line-balancing-file>
        qsb export-line-balancing-json <legacy-fll-line-balancing-file>
        qsb solve-line-balancing-json <line-balancing-model-json-file> [--backend native|validate]
        qsb solve-location <legacy-fll-location-file> [--backend native|validate]
        qsb validate-location <legacy-fll-location-file>
        qsb export-location-json <legacy-fll-location-file>
        qsb solve-location-json <facility-location-model-json-file> [--backend native|validate]
        qsb solve-layout <legacy-fll-layout-file> [--backend native|validate] [--layout-strategy initial|pairwise-swap]
        qsb validate-layout <legacy-fll-layout-file>
        qsb export-layout-json <legacy-fll-layout-file>
        qsb solve-layout-json <layout-model-json-file> [--backend native|validate] [--layout-strategy initial|pairwise-swap]
        qsb solve-knapsack <legacy-dp-knapsack-file>
        qsb solve-stagecoach <legacy-dp-stagecoach-file>
        qsb solve-prod-inventory <legacy-dp-production-inventory-file>
        qsb solve-payoff <legacy-da-payoff-file>
        qsb solve-bayesian <legacy-da-bayesian-file>
        qsb solve-decision-tree <legacy-da-decision-tree-file>
        qsb solve-game <legacy-da-zero-sum-game-file> [--backend native|validate]
        qsb validate-game <legacy-da-zero-sum-game-file>
        qsb solve-mm1 <legacy-qa-mm1-file> [--backend native|validate]
        qsb solve-mm1-json <legacy-qa-mm1-file> [--backend native|validate]
        qsb validate-mm1 <legacy-qa-mm1-file>
        qsb solve-finite-queue <legacy-qa-finite-capacity-file> [--backend native|validate]
        qsb solve-finite-queue-json <legacy-qa-finite-capacity-file> [--backend native|validate]
        qsb validate-finite-queue <legacy-qa-finite-capacity-file>
        qsb solve-spp <legacy-network-file>
        qsb solve-mst <legacy-network-file>
        qsb solve-maxflow <legacy-network-file>
        qsb solve-tsp <legacy-network-file>
        qsb solve-assignment <legacy-network-file>
        qsb solve-transport <legacy-network-file> [--backend native|validate]
        qsb validate-transport <legacy-network-file>
        """, to: handle)
    }

    private static func printError(_ message: String) {
        write("qsb: error: \(message)", to: .standardError)
    }

    private static func write(_ message: String, to handle: FileHandle) {
        let data = Data((message + "\n").utf8)
        handle.write(data)
    }

    private static func userFacingMessage(for error: Error) -> String {
        switch error {
        case let error as LinearProgramError:
            return error.description
        case let error as LegacyCompressionError:
            return error.description
        case let error as NetworkModelError:
            return error.description
        case let error as ForecastingModelError:
            return error.description
        case let error as InventoryModelError:
            return error.description
        case let error as DynamicProgrammingModelError:
            return error.description
        case let error as DecisionAnalysisModelError:
            return error.description
        case let error as QueuingModelError:
            return error.description
        case let error as SchedulingModelError:
            return error.description
        case let error as FacilitiesModelError:
            return error.description
        case let error as DecodingError:
            return "Invalid model JSON: \(describe(error))"
        case let error as EncodingError:
            return "Could not encode JSON: \(describe(error))"
        case let error as CocoaError where error.code == .fileReadNoSuchFile:
            return "File not found"
        default:
            return String(describing: error)
        }
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch(let type, let context):
            return "expected \(type) at \(codingPath(context.codingPath))"
        case .valueNotFound(let type, let context):
            return "missing value for \(type) at \(codingPath(context.codingPath))"
        case .keyNotFound(let key, let context):
            return "missing key '\(key.stringValue)' at \(codingPath(context.codingPath))"
        case .dataCorrupted(let context):
            return context.debugDescription
        @unknown default:
            return String(describing: error)
        }
    }

    private static func describe(_ error: EncodingError) -> String {
        switch error {
        case .invalidValue(_, let context):
            return context.debugDescription
        @unknown default:
            return String(describing: error)
        }
    }

    private static func codingPath(_ path: [CodingKey]) -> String {
        guard !path.isEmpty else {
            return "<root>"
        }
        return path.map(\.stringValue).joined(separator: ".")
    }
}

private enum CLIError: Error {
    case usage(String?)
}
