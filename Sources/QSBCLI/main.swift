import Foundation
import QSBCore

#if os(Linux)
import Glibc
#else
import Darwin
#endif

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
            try genericInspect(path: arguments[1])
        case "expand":
            guard arguments.count == 2 else { throw CLIError.usage("expand expects exactly one legacy file path") }
            let data = try Data(contentsOf: URL(fileURLWithPath: arguments[1]))
            FileHandle.standardOutput.write(try LegacyCompressedFile.expandedData(from: data))
        case "import-legacy-json":
            guard arguments.count == 2 else {
                throw CLIError.usage("import-legacy-json expects exactly one legacy model file path")
            }
            try importLegacyJSON(path: arguments[1])
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
                throw CLIError.usage("export-json expects exactly one legacy model file path")
            }
            try exportJSON(path: arguments[1])
        case "validate":
            guard arguments.count == 2 else {
                throw CLIError.usage("validate expects exactly one legacy or normalized model file path")
            }
            try genericValidate(path: arguments[1])
        case "solve":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve expects a legacy model file path and optional --backend native|validate|external"
            )
            try genericSolve(path: options.path, backend: options.backend)
        case "solve-json":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-json expects a model JSON file path and optional --backend native|validate"
            )
            try genericSolveJSON(path: options.path, backend: options.backend)
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
            let options = try parsePathAndBackend(arguments, usage: "solve-network-json expects a network model JSON file path with optional --backend native|validate")
            try solveNetworkJSON(path: options.path, backend: options.backend)
        case "validate-network-json":
            guard arguments.count == 2 else { throw CLIError.usage("validate-network-json expects exactly one network model JSON file path") }
            try validateNetworkJSON(path: arguments[1])
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
        case "export-forecast-json":
            try exportForecastingJSON(arguments: arguments)
        case "solve-forecast-json":
            let options = try parsePathAndBackend(arguments, usage: "solve-forecast-json expects a forecasting request JSON file path with optional --backend native|validate")
            try solveForecastingJSON(path: options.path, backend: options.backend)
        case "validate-forecast-json":
            guard arguments.count == 2 else { throw CLIError.usage("validate-forecast-json expects exactly one forecasting request JSON file path") }
            try validateForecastingJSON(path: arguments[1])
        case "solve-eoq":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-eoq expects a legacy ITS EOQ file path and optional --backend native|validate"
            )
            try solveEOQ(path: options.path, backend: options.backend)
        case "solve-discount-eoq":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-discount-eoq expects a legacy ITS discount EOQ file path and optional --backend native|validate"
            )
            try solveDiscountEOQ(path: options.path, backend: options.backend)
        case "solve-newsboy":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-newsboy expects a legacy ITS newsboy file path and optional --backend native|validate"
            )
            try solveNewsboy(path: options.path, backend: options.backend)
        case "solve-lot-sizing":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-lot-sizing expects a legacy ITS lot-sizing file path and optional --backend native|validate"
            )
            try solveLotSizing(path: options.path, backend: options.backend)
        case "solve-stochastic-inventory":
            let options = try parsePathAndBackend(arguments, usage: "solve-stochastic-inventory expects a legacy ITS stochastic-review file path and optional --backend native|validate")
            try solveStochasticInventory(path: options.path, backend: options.backend)
        case "validate-eoq":
            guard arguments.count == 2 else {
                throw CLIError.usage("validate-eoq expects exactly one legacy ITS EOQ file path")
            }
            try validateEOQ(path: arguments[1])
        case "validate-discount-eoq":
            guard arguments.count == 2 else {
                throw CLIError.usage("validate-discount-eoq expects exactly one legacy ITS discount EOQ file path")
            }
            try validateDiscountEOQ(path: arguments[1])
        case "validate-newsboy":
            guard arguments.count == 2 else {
                throw CLIError.usage("validate-newsboy expects exactly one legacy ITS newsboy file path")
            }
            try validateNewsboy(path: arguments[1])
        case "validate-lot-sizing":
            guard arguments.count == 2 else {
                throw CLIError.usage("validate-lot-sizing expects exactly one legacy ITS lot-sizing file path")
            }
            try validateLotSizing(path: arguments[1])
        case "validate-stochastic-inventory":
            guard arguments.count == 2 else { throw CLIError.usage("validate-stochastic-inventory expects exactly one legacy ITS stochastic-review file path") }
            try validateStochasticInventory(path: arguments[1])
        case "export-inventory-json":
            guard arguments.count == 2 else {
                throw CLIError.usage("export-inventory-json expects exactly one legacy ITS inventory file path")
            }
            try exportInventoryJSON(path: arguments[1])
        case "solve-inventory-json":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-inventory-json expects an inventory model JSON file path and optional --backend native|validate"
            )
            try solveInventoryJSON(path: options.path, backend: options.backend)
        case "validate-inventory-json":
            guard arguments.count == 2 else {
                throw CLIError.usage("validate-inventory-json expects exactly one inventory model JSON file path")
            }
            try validateInventoryJSON(path: arguments[1])
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
        case "export-scheduling-json":
            guard arguments.count == 2 else { throw CLIError.usage("export-scheduling-json expects exactly one legacy scheduling file path") }
            try exportSchedulingModelJSON(path: arguments[1])
        case "solve-scheduling-json":
            let options = try parsePathAndBackend(arguments, usage: "solve-scheduling-json expects a scheduling model JSON file path with optional --backend native|validate")
            try solveSchedulingModelJSON(path: options.path, backend: options.backend)
        case "validate-scheduling-json":
            guard arguments.count == 2 else { throw CLIError.usage("validate-scheduling-json expects exactly one scheduling model JSON file path") }
            try validateSchedulingModelJSON(path: arguments[1])
        case "solve-cpm":
            let options = try parsePathAndBackend(arguments, usage: "solve-cpm expects a legacy CPM file path with optional --backend native|validate")
            try solveProjectSchedulingLegacy(path: options.path, expectedKind: .deterministicCPM, backend: options.backend)
        case "solve-pert":
            let options = try parsePathAndBackend(arguments, usage: "solve-pert expects a legacy PERT file path with optional --backend native|validate")
            try solveProjectSchedulingLegacy(path: options.path, expectedKind: .probabilisticPERT, backend: options.backend)
        case "validate-cpm", "validate-pert":
            guard arguments.count == 2 else { throw CLIError.usage("\(command) expects exactly one legacy PERT/CPM file path") }
            try validateProjectSchedulingLegacy(path: arguments[1])
        case "export-project-json":
            guard arguments.count == 2 else { throw CLIError.usage("export-project-json expects exactly one legacy PERT/CPM file path") }
            try exportProjectSchedulingJSON(path: arguments[1])
        case "solve-project-json":
            let options = try parsePathAndBackend(arguments, usage: "solve-project-json expects a PERT/CPM model JSON file path with optional --backend native|validate")
            try solveProjectSchedulingJSON(path: options.path, backend: options.backend)
        case "validate-project-json":
            guard arguments.count == 2 else { throw CLIError.usage("validate-project-json expects exactly one PERT/CPM model JSON file path") }
            try validateProjectSchedulingJSON(path: arguments[1])
        case "solve-markov":
            let options = try parsePathAndBackend(arguments, usage: "solve-markov expects a legacy Markov file path with optional --backend native|validate")
            try solveMarkovLegacy(path: options.path, backend: options.backend)
        case "validate-markov":
            guard arguments.count == 2 else { throw CLIError.usage("validate-markov expects exactly one legacy Markov file path") }
            try validateMarkovLegacy(path: arguments[1])
        case "export-markov-json":
            guard arguments.count == 2 else { throw CLIError.usage("export-markov-json expects exactly one legacy Markov file path") }
            try exportMarkovJSON(path: arguments[1])
        case "solve-markov-json":
            let options = try parsePathAndBackend(arguments, usage: "solve-markov-json expects a Markov request JSON file path with optional --backend native|validate")
            try solveMarkovJSON(path: options.path, backend: options.backend)
        case "validate-markov-json":
            guard arguments.count == 2 else { throw CLIError.usage("validate-markov-json expects exactly one Markov request JSON file path") }
            try validateMarkovJSON(path: arguments[1])
        case "solve-goal":
            let options = try parsePathAndBackend(arguments, usage: "solve-goal expects a legacy goal-programming file path with optional --backend native|validate")
            try solveGoalProgrammingLegacy(path: options.path, backend: options.backend)
        case "validate-goal":
            guard arguments.count == 2 else { throw CLIError.usage("validate-goal expects exactly one legacy goal-programming file path") }
            try validateGoalProgrammingLegacy(path: arguments[1])
        case "export-goal-json":
            guard arguments.count == 2 else { throw CLIError.usage("export-goal-json expects exactly one legacy goal-programming file path") }
            try exportGoalProgrammingJSON(path: arguments[1])
        case "solve-goal-json":
            let options = try parsePathAndBackend(arguments, usage: "solve-goal-json expects a goal-programming model JSON file path with optional --backend native|validate")
            try solveGoalProgrammingJSON(path: options.path, backend: options.backend)
        case "validate-goal-json":
            guard arguments.count == 2 else { throw CLIError.usage("validate-goal-json expects exactly one goal-programming model JSON file path") }
            try validateGoalProgrammingJSON(path: arguments[1])
        case "solve-acceptance":
            let options = try parsePathAndBackend(arguments, usage: "solve-acceptance expects a legacy acceptance-sampling file path with optional --backend native|validate")
            try solveAcceptanceSamplingLegacy(path: options.path, backend: options.backend)
        case "validate-acceptance":
            guard arguments.count == 2 else { throw CLIError.usage("validate-acceptance expects exactly one legacy acceptance-sampling file path") }
            try validateAcceptanceSamplingLegacy(path: arguments[1])
        case "export-acceptance-json":
            guard arguments.count == 2 else { throw CLIError.usage("export-acceptance-json expects exactly one legacy acceptance-sampling file path") }
            try exportAcceptanceSamplingJSON(path: arguments[1])
        case "solve-acceptance-json":
            let options = try parsePathAndBackend(arguments, usage: "solve-acceptance-json expects an acceptance-sampling model JSON file path with optional --backend native|validate")
            try solveAcceptanceSamplingJSON(path: options.path, backend: options.backend)
        case "validate-acceptance-json":
            guard arguments.count == 2 else { throw CLIError.usage("validate-acceptance-json expects exactly one acceptance-sampling model JSON file path") }
            try validateAcceptanceSamplingJSON(path: arguments[1])
        case "solve-quality":
            let options = try parsePathAndBackend(arguments, usage: "solve-quality expects a legacy quality-control file path with optional --backend native|validate")
            try solveQualityControlLegacy(path: options.path, backend: options.backend)
        case "validate-quality":
            guard arguments.count == 2 else { throw CLIError.usage("validate-quality expects exactly one legacy quality-control file path") }
            try validateQualityControlLegacy(path: arguments[1])
        case "export-quality-json":
            guard arguments.count == 2 else { throw CLIError.usage("export-quality-json expects exactly one legacy quality-control file path") }
            try exportQualityControlJSON(path: arguments[1])
        case "solve-quality-json":
            let options = try parsePathAndBackend(arguments, usage: "solve-quality-json expects a quality-control model JSON file path with optional --backend native|validate")
            try solveQualityControlJSON(path: options.path, backend: options.backend)
        case "validate-quality-json":
            guard arguments.count == 2 else { throw CLIError.usage("validate-quality-json expects exactly one quality-control model JSON file path") }
            try validateQualityControlJSON(path: arguments[1])
        case "solve-aggregate":
            let options = try parsePathAndBackend(arguments, usage: "solve-aggregate expects a legacy aggregate-planning file path with optional --backend native|validate")
            try solveAggregatePlanningLegacy(path: options.path, backend: options.backend)
        case "validate-aggregate":
            guard arguments.count == 2 else { throw CLIError.usage("validate-aggregate expects exactly one legacy aggregate-planning file path") }
            try validateAggregatePlanningLegacy(path: arguments[1])
        case "export-aggregate-json":
            guard arguments.count == 2 else { throw CLIError.usage("export-aggregate-json expects exactly one legacy aggregate-planning file path") }
            try exportAggregatePlanningJSON(path: arguments[1])
        case "solve-aggregate-json":
            let options = try parsePathAndBackend(arguments, usage: "solve-aggregate-json expects an aggregate-planning model JSON file path with optional --backend native|validate")
            try solveAggregatePlanningJSON(path: options.path, backend: options.backend)
        case "validate-aggregate-json":
            guard arguments.count == 2 else { throw CLIError.usage("validate-aggregate-json expects exactly one aggregate-planning model JSON file path") }
            try validateAggregatePlanningJSON(path: arguments[1])
        case "solve-mrp":
            let options = try parsePathAndBackend(arguments, usage: "solve-mrp expects a legacy MRP file path with optional --backend native|validate")
            try solveMRPLegacy(path: options.path, backend: options.backend)
        case "validate-mrp":
            guard arguments.count == 2 else { throw CLIError.usage("validate-mrp expects exactly one legacy MRP file path") }
            try validateMRPLegacy(path: arguments[1])
        case "export-mrp-json":
            guard arguments.count == 2 else { throw CLIError.usage("export-mrp-json expects exactly one legacy MRP file path") }
            try exportMRPJSON(path: arguments[1])
        case "solve-mrp-json":
            let options = try parsePathAndBackend(arguments, usage: "solve-mrp-json expects an MRP model JSON file path with optional --backend native|validate")
            try solveMRPJSON(path: options.path, backend: options.backend)
        case "validate-mrp-json":
            guard arguments.count == 2 else { throw CLIError.usage("validate-mrp-json expects exactly one MRP model JSON file path") }
            try validateMRPJSON(path: arguments[1])
        case "solve-qp":
            let options = try parsePathAndBackend(arguments, usage: "solve-qp expects a legacy quadratic-programming file path with optional --backend native|validate")
            try solveQuadraticProgrammingLegacy(path: options.path, backend: options.backend)
        case "validate-qp":
            guard arguments.count == 2 else { throw CLIError.usage("validate-qp expects exactly one legacy quadratic-programming file path") }
            try validateQuadraticProgrammingLegacy(path: arguments[1])
        case "export-qp-json":
            guard arguments.count == 2 else { throw CLIError.usage("export-qp-json expects exactly one legacy quadratic-programming file path") }
            try exportQuadraticProgrammingJSON(path: arguments[1])
        case "solve-qp-json":
            let options = try parsePathAndBackend(arguments, usage: "solve-qp-json expects a quadratic-programming model JSON file path with optional --backend native|validate")
            try solveQuadraticProgrammingJSON(path: options.path, backend: options.backend)
        case "validate-qp-json":
            guard arguments.count == 2 else { throw CLIError.usage("validate-qp-json expects exactly one quadratic-programming model JSON file path") }
            try validateQuadraticProgrammingJSON(path: arguments[1])
        case "solve-nlp":
            let options = try parsePathAndBackend(arguments, usage: "solve-nlp expects a legacy nonlinear-programming file path with optional --backend native|validate")
            try solveNonlinearProgrammingLegacy(path: options.path, backend: options.backend)
        case "validate-nlp":
            guard arguments.count == 2 else { throw CLIError.usage("validate-nlp expects exactly one legacy nonlinear-programming file path") }
            try validateNonlinearProgrammingLegacy(path: arguments[1])
        case "export-nlp-json":
            guard arguments.count == 2 else { throw CLIError.usage("export-nlp-json expects exactly one legacy nonlinear-programming file path") }
            try exportNonlinearProgrammingJSON(path: arguments[1])
        case "solve-nlp-json":
            let options = try parsePathAndBackend(arguments, usage: "solve-nlp-json expects a nonlinear-programming model JSON file path with optional --backend native|validate")
            try solveNonlinearProgrammingJSON(path: options.path, backend: options.backend)
        case "validate-nlp-json":
            guard arguments.count == 2 else { throw CLIError.usage("validate-nlp-json expects exactly one nonlinear-programming model JSON file path") }
            try validateNonlinearProgrammingJSON(path: arguments[1])
        case "solve-simulation":
            let options = try parsePathAndBackend(arguments, usage: "solve-simulation expects a legacy simulation file path with optional --backend native|validate")
            try solveSimulationLegacy(path: options.path, backend: options.backend)
        case "validate-simulation":
            guard arguments.count == 2 else { throw CLIError.usage("validate-simulation expects exactly one legacy simulation file path") }
            try validateSimulationLegacy(path: arguments[1])
        case "export-simulation-json":
            guard arguments.count == 2 else { throw CLIError.usage("export-simulation-json expects exactly one legacy simulation file path") }
            try exportSimulationJSON(path: arguments[1])
        case "solve-simulation-json":
            let options = try parsePathAndBackend(arguments, usage: "solve-simulation-json expects a simulation model JSON file path with optional --backend native|validate")
            try solveSimulationJSON(path: options.path, backend: options.backend)
        case "validate-simulation-json":
            guard arguments.count == 2 else { throw CLIError.usage("validate-simulation-json expects exactly one simulation model JSON file path") }
            try validateSimulationJSON(path: arguments[1])
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
            let options = try parsePathAndBackend(arguments, usage: "solve-knapsack expects a legacy DP knapsack file path with optional --backend native|validate")
            try solveDynamicProgrammingLegacy(path: options.path, expectedKind: .boundedKnapsack, backend: options.backend)
        case "solve-stagecoach":
            let options = try parsePathAndBackend(arguments, usage: "solve-stagecoach expects a legacy DP stagecoach file path with optional --backend native|validate")
            try solveDynamicProgrammingLegacy(path: options.path, expectedKind: .stagecoach, backend: options.backend)
        case "solve-prod-inventory":
            let options = try parsePathAndBackend(arguments, usage: "solve-prod-inventory expects a legacy DP production/inventory file path with optional --backend native|validate")
            try solveDynamicProgrammingLegacy(path: options.path, expectedKind: .productionInventory, backend: options.backend)
        case "validate-knapsack", "validate-stagecoach", "validate-prod-inventory":
            guard arguments.count == 2 else { throw CLIError.usage("\(command) expects exactly one legacy DP file path") }
            try validateDynamicProgrammingLegacy(path: arguments[1])
        case "export-dp-json":
            guard arguments.count == 2 else { throw CLIError.usage("export-dp-json expects exactly one legacy DP file path") }
            try exportDynamicProgrammingJSON(path: arguments[1])
        case "solve-dp-json":
            let options = try parsePathAndBackend(arguments, usage: "solve-dp-json expects a dynamic-programming model JSON file path with optional --backend native|validate")
            try solveDynamicProgrammingJSON(path: options.path, backend: options.backend)
        case "validate-dp-json":
            guard arguments.count == 2 else { throw CLIError.usage("validate-dp-json expects exactly one dynamic-programming model JSON file path") }
            try validateDynamicProgrammingJSON(path: arguments[1])
        case "solve-payoff":
            let options = try parsePathAndBackend(arguments, usage: "solve-payoff expects a legacy DA payoff file path with optional --backend native|validate")
            try solveDecisionAnalysisLegacy(path: options.path, expectedKind: .payoff, backend: options.backend)
        case "solve-bayesian":
            let options = try parsePathAndBackend(arguments, usage: "solve-bayesian expects a legacy DA Bayesian file path with optional --backend native|validate")
            try solveDecisionAnalysisLegacy(path: options.path, expectedKind: .bayesian, backend: options.backend)
        case "solve-decision-tree":
            let options = try parsePathAndBackend(arguments, usage: "solve-decision-tree expects a legacy DA decision tree file path with optional --backend native|validate")
            try solveDecisionAnalysisLegacy(path: options.path, expectedKind: .decisionTree, backend: options.backend)
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
        case "validate-payoff", "validate-bayesian", "validate-decision-tree":
            guard arguments.count == 2 else { throw CLIError.usage("\(command) expects exactly one legacy DA file path") }
            try validateDecisionAnalysisLegacy(path: arguments[1])
        case "export-decision-json":
            guard arguments.count == 2 else { throw CLIError.usage("export-decision-json expects exactly one legacy DA file path") }
            try exportDecisionAnalysisJSON(path: arguments[1])
        case "solve-decision-json":
            let options = try parsePathAndBackend(arguments, usage: "solve-decision-json expects a decision-analysis model JSON file path with optional --backend native|validate")
            try solveDecisionAnalysisJSON(path: options.path, backend: options.backend)
        case "validate-decision-json":
            guard arguments.count == 2 else { throw CLIError.usage("validate-decision-json expects exactly one decision-analysis model JSON file path") }
            try validateDecisionAnalysisJSON(path: arguments[1])
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
        case "export-queuing-json":
            guard arguments.count == 2 else { throw CLIError.usage("export-queuing-json expects exactly one legacy queuing file path") }
            try exportQueuingModelJSON(path: arguments[1])
        case "solve-queuing-json":
            let options = try parsePathAndBackend(arguments, usage: "solve-queuing-json expects a queuing model JSON file path with optional --backend native|validate")
            try solveQueuingModelJSON(path: options.path, backend: options.backend)
        case "validate-queuing-json":
            guard arguments.count == 2 else { throw CLIError.usage("validate-queuing-json expects exactly one queuing model JSON file path") }
            try validateQueuingModelJSON(path: arguments[1])
        case "solve-spp":
            let options = try parsePathAndBackend(arguments, usage: "solve-spp expects a legacy SPP network file path with optional --backend native|validate")
            try solveNetworkLegacy(path: options.path, expectedKind: .shortestPath, backend: options.backend)
        case "solve-netflow":
            let options = try parsePathAndBackend(arguments, usage: "solve-netflow expects a legacy CNF network file path with optional --backend native|validate")
            try solveNetworkLegacy(path: options.path, expectedKind: .minimumCostFlow, backend: options.backend)
        case "solve-mst":
            let options = try parsePathAndBackend(arguments, usage: "solve-mst expects a legacy MST network file path with optional --backend native|validate")
            try solveNetworkLegacy(path: options.path, expectedKind: .minimumSpanningTree, backend: options.backend)
        case "solve-maxflow":
            let options = try parsePathAndBackend(arguments, usage: "solve-maxflow expects a legacy MFP network file path with optional --backend native|validate")
            try solveNetworkLegacy(path: options.path, expectedKind: .maxFlow, backend: options.backend)
        case "solve-tsp":
            let options = try parsePathAndBackend(arguments, usage: "solve-tsp expects a legacy TSP network file path with optional --backend native|validate")
            try solveNetworkLegacy(path: options.path, expectedKind: .travelingSalesperson, backend: options.backend)
        case "solve-assignment":
            let options = try parsePathAndBackend(arguments, usage: "solve-assignment expects a legacy AP network file path with optional --backend native|validate")
            try solveNetworkLegacy(path: options.path, expectedKind: .assignment, backend: options.backend)
        case "solve-transport":
            let options = try parsePathAndBackend(
                arguments,
                usage: "solve-transport expects a legacy TP network file path and optional --backend native|validate"
            )
            try solveNetworkLegacy(path: options.path, expectedKind: .transportation, backend: options.backend)
        case "validate-transport":
            guard arguments.count == 2 else {
                throw CLIError.usage("validate-transport expects exactly one legacy TP network file path")
            }
            try validateNetworkLegacy(path: arguments[1])
        case "validate-netflow", "validate-spp", "validate-mst", "validate-maxflow", "validate-tsp", "validate-assignment":
            guard arguments.count == 2 else { throw CLIError.usage("\(command) expects exactly one legacy network file path") }
            try validateNetworkLegacy(path: arguments[1])
        default:
            throw CLIError.usage("unknown command: \(command)")
        }
    }

    private static func exportSchedulingModelJSON(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let model = try WinQSBSchedulingParser.parseModelEnvelope(from: LegacyCompressedFile.expandedData(from: data))
        FileHandle.standardOutput.write(try SchedulingModelJSON.encodeModel(model)); print()
    }

    private static func solveSchedulingModelJSON(path: String, backend: SolverBackendKind) throws {
        let model = try SchedulingModelJSON.decodeModel(from: Data(contentsOf: URL(fileURLWithPath: path)))
        let solver = try schedulingBackend(for: backend, command: "solve-scheduling-json")
        guard solver.capabilities.solves else { try writeSchedulingValidation(model: model, report: solver.validationReport(for: model)); return }
        FileHandle.standardOutput.write(try SchedulingModelJSON.encodeSolution(try solver.solve(model))); print()
    }

    private static func validateSchedulingModelJSON(path: String) throws {
        let model = try SchedulingModelJSON.decodeModel(from: Data(contentsOf: URL(fileURLWithPath: path)))
        let solver = ValidateOnlySchedulingBackend()
        try writeSchedulingValidation(model: model, report: solver.validationReport(for: model))
    }

    private static func writeSchedulingValidation(model: SchedulingModelEnvelope, report: ValidationReport) throws {
        FileHandle.standardOutput.write(try SchedulingModelJSON.encodeValidation(SchedulingValidationDocument(kind: model.kind, backend: report.backend, diagnostics: report.diagnostics))); print()
    }

    private static func exportQueuingModelJSON(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let model = try WinQSBQueuingParser.parseModelEnvelope(from: LegacyCompressedFile.expandedData(from: data))
        FileHandle.standardOutput.write(try QueuingModelJSON.encodeModel(model)); print()
    }

    private static func solveQueuingModelJSON(path: String, backend: SolverBackendKind) throws {
        let model = try QueuingModelJSON.decodeModel(from: Data(contentsOf: URL(fileURLWithPath: path)))
        let solver = try queuingBackend(for: backend, command: "solve-queuing-json")
        guard solver.capabilities.solves else { try writeQueuingValidation(model: model, report: solver.validationReport(for: model)); return }
        FileHandle.standardOutput.write(try QueuingModelJSON.encodeSolution(try solver.solve(model))); print()
    }

    private static func validateQueuingModelJSON(path: String) throws {
        let model = try QueuingModelJSON.decodeModel(from: Data(contentsOf: URL(fileURLWithPath: path)))
        let solver = ValidateOnlyQueuingBackend()
        try writeQueuingValidation(model: model, report: solver.validationReport(for: model))
    }

    private static func writeQueuingValidation(model: QueuingModelEnvelope, report: ValidationReport) throws {
        FileHandle.standardOutput.write(try QueuingModelJSON.encodeValidation(QueuingValidationDocument(kind: model.kind, backend: report.backend, diagnostics: report.diagnostics))); print()
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

    private static func inventoryBackend(
        for backend: SolverBackendKind,
        command: String
    ) throws -> any InventoryBackend {
        guard let selectedBackend = InventoryBackends.backend(for: backend) else {
            throw CLIError.usage("external backend is not available yet for \(command)")
        }
        return selectedBackend
    }

    private static func dynamicProgrammingBackend(
        for backend: SolverBackendKind,
        command: String
    ) throws -> any DynamicProgrammingBackend {
        guard let selectedBackend = DynamicProgrammingBackends.backend(for: backend) else {
            throw CLIError.usage("external backend is not available yet for \(command)")
        }
        return selectedBackend
    }

    private static func forecastingBackend(for backend: SolverBackendKind, command: String) throws -> any ForecastingBackend {
        guard let selectedBackend = ForecastingBackends.backend(for: backend) else {
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
        let result = try LegacyModelImporter.importModel(at: URL(fileURLWithPath: path))
        FileHandle.standardOutput.write(result.normalizedJSON)
        print()
    }

    private static func importLegacyJSON(path: String) throws {
        let result = try LegacyModelImporter.importModel(
            at: URL(fileURLWithPath: path)
        )
        FileHandle.standardOutput.write(result.normalizedJSON)
        print()
    }

    private static func exportNetworkJSON(path: String) throws {
        let model = try readLegacyNetworkModel(path: path)
        let data = try NetworkModelJSON.encodeModel(model)
        FileHandle.standardOutput.write(data)
        print()
    }

    private static func solveNetworkJSON(path: String, backend: SolverBackendKind) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let model = try NetworkModelJSON.decodeModel(from: data)
        guard let solver = NetworkBackends.backend(for: backend) else { throw CLIError.usage("external backend is not available yet for solve-network-json") }
        if solver.capabilities.solves {
            let solution = try solver.solve(model)
            FileHandle.standardOutput.write(try NetworkModelJSON.encodeSolutionDocument(solver.solutionDocument(for: model, solution: solution))); print()
        } else {
            try writeNetworkValidation(model: model, report: solver.validationReport(for: model))
        }
    }

    private static func validateNetworkJSON(path: String) throws {
        let model = try NetworkModelJSON.decodeModel(from: Data(contentsOf: URL(fileURLWithPath: path)))
        try writeNetworkValidation(model: model, report: ValidateOnlyNetworkBackend().validationReport(for: model))
    }

    private static func writeNetworkValidation(model: NetworkModelEnvelope, report: ValidationReport) throws {
        let document = NetworkValidationDocument(kind: model.kind, backend: report.backend, diagnostics: report.diagnostics)
        FileHandle.standardOutput.write(try NetworkModelJSON.encodeValidation(document)); print()
    }

    private static func readLegacyProjectSchedulingModel(path: String) throws -> ProjectSchedulingModelEnvelope {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try WinQSBProjectSchedulingParser.parseModelEnvelope(from: LegacyCompressedFile.expandedData(from: data))
    }

    private static func projectSchedulingBackend(for kind: SolverBackendKind, command: String) throws -> any ProjectSchedulingBackend {
        guard let backend = ProjectSchedulingBackends.backend(for: kind) else { throw CLIError.usage("external backend is not available yet for \(command)") }
        return backend
    }

    private static func solveProjectSchedulingLegacy(path: String, expectedKind: ProjectSchedulingProblemKind, backend: SolverBackendKind) throws {
        let model = try readLegacyProjectSchedulingModel(path: path)
        guard model.kind == expectedKind else { throw ProjectSchedulingError.invalidModel("Expected \(expectedKind.rawValue), found \(model.kind.rawValue)") }
        let solver = try projectSchedulingBackend(for: backend, command: "solve-\(expectedKind.rawValue.lowercased())")
        if solver.capabilities.solves {
            printProjectSchedulingSolution(model: model, solution: try solver.solve(model), metadata: solver.runMetadata(for: model))
        } else {
            printProjectSchedulingValidation(model: model, report: solver.validationReport(for: model), source: path)
        }
    }

    private static func validateProjectSchedulingLegacy(path: String) throws {
        let model = try readLegacyProjectSchedulingModel(path: path)
        printProjectSchedulingValidation(model: model, report: ValidateOnlyProjectSchedulingBackend().validationReport(for: model), source: path)
    }

    private static func exportProjectSchedulingJSON(path: String) throws {
        FileHandle.standardOutput.write(try ProjectSchedulingJSON.encodeModel(readLegacyProjectSchedulingModel(path: path))); print()
    }

    private static func solveProjectSchedulingJSON(path: String, backend: SolverBackendKind) throws {
        let model = try ProjectSchedulingJSON.decodeModel(from: Data(contentsOf: URL(fileURLWithPath: path)))
        let solver = try projectSchedulingBackend(for: backend, command: "solve-project-json")
        if solver.capabilities.solves {
            let solution = try solver.solve(model)
            FileHandle.standardOutput.write(try ProjectSchedulingJSON.encodeSolution(solver.solutionDocument(for: model, solution: solution))); print()
        } else {
            try writeProjectSchedulingValidation(model: model, report: solver.validationReport(for: model))
        }
    }

    private static func validateProjectSchedulingJSON(path: String) throws {
        let model = try ProjectSchedulingJSON.decodeModel(from: Data(contentsOf: URL(fileURLWithPath: path)))
        try writeProjectSchedulingValidation(model: model, report: ValidateOnlyProjectSchedulingBackend().validationReport(for: model))
    }

    private static func writeProjectSchedulingValidation(model: ProjectSchedulingModelEnvelope, report: ValidationReport) throws {
        let document = ProjectSchedulingValidationDocument(kind: model.kind, backend: report.backend, diagnostics: report.diagnostics)
        FileHandle.standardOutput.write(try ProjectSchedulingJSON.encodeValidation(document)); print()
    }

    private static func printProjectSchedulingSolution(model: ProjectSchedulingModelEnvelope, solution: ProjectSchedulingSolution, metadata: SolverRunMetadata) {
        print(model.title); print("backend: \(metadata.backendKind.rawValue)"); print("algorithm: \(metadata.algorithm)"); print("exactness: \(metadata.exactness.rawValue)")
        print("modelType: \(model.kind.rawValue)"); print("projectDuration: \(format(solution.projectDuration))"); print("criticalActivities: \(solution.criticalActivities.joined(separator: ","))")
        if let variance = solution.projectVariance { print("projectVariance: \(format(variance))") }
        if let deviation = solution.projectStandardDeviation { print("projectStandardDeviation: \(format(deviation))") }
        if let cost = solution.totalNormalCost { print("totalNormalCost: \(format(cost))") }
        for item in solution.activityTimings { print("\(item.name): ES=\(format(item.earliestStart)) EF=\(format(item.earliestFinish)) LS=\(format(item.latestStart)) LF=\(format(item.latestFinish)) slack=\(format(item.slack)) critical=\(item.isCritical)") }
    }

    private static func printProjectSchedulingValidation(model: ProjectSchedulingModelEnvelope, report: ValidationReport, source: String) {
        let errors = report.diagnostics.filter { $0.severity == .error }; let warnings = report.diagnostics.filter { $0.severity == .warning }
        print(model.title); print("backend: \(report.backend.rawValue)"); print("source: \(source)"); print("modelType: \(model.kind.rawValue)"); print("status: \(errors.isEmpty ? "valid" : "invalid")"); print("errors: \(errors.count)"); print("warnings: \(warnings.count)")
        for item in report.diagnostics { print("\(item.severity.rawValue): \(item.code)\(item.path.map { " [\($0)]" } ?? "") - \(item.message)") }
    }

    private static func readLegacyMarkovRequest(path: String) throws -> MarkovAnalysisRequest {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return MarkovAnalysisRequest(model: try WinQSBMarkovParser.parse(from: LegacyCompressedFile.expandedData(from: data)))
    }

    private static func markovBackend(for kind: SolverBackendKind, command: String) throws -> any MarkovBackend {
        guard let backend = MarkovBackends.backend(for: kind) else { throw CLIError.usage("external backend is not available yet for \(command)") }
        return backend
    }

    private static func solveMarkovLegacy(path: String, backend: SolverBackendKind) throws {
        let request = try readLegacyMarkovRequest(path: path)
        let solver = try markovBackend(for: backend, command: "solve-markov")
        if solver.capabilities.solves {
            printMarkovSolution(request: request, solution: try solver.solve(request), metadata: solver.runMetadata(for: request))
        } else {
            printMarkovValidation(request: request, report: solver.validationReport(for: request), source: path)
        }
    }

    private static func validateMarkovLegacy(path: String) throws {
        let request = try readLegacyMarkovRequest(path: path)
        printMarkovValidation(request: request, report: ValidateOnlyMarkovBackend().validationReport(for: request), source: path)
    }

    private static func exportMarkovJSON(path: String) throws {
        FileHandle.standardOutput.write(try MarkovJSON.encodeRequest(readLegacyMarkovRequest(path: path))); print()
    }

    private static func solveMarkovJSON(path: String, backend: SolverBackendKind) throws {
        let request = try MarkovJSON.decodeRequest(from: Data(contentsOf: URL(fileURLWithPath: path)))
        let solver = try markovBackend(for: backend, command: "solve-markov-json")
        if solver.capabilities.solves {
            let solution = try solver.solve(request)
            FileHandle.standardOutput.write(try MarkovJSON.encodeSolution(solver.solutionDocument(for: request, solution: solution))); print()
        } else {
            try writeMarkovValidation(request: request, report: solver.validationReport(for: request))
        }
    }

    private static func validateMarkovJSON(path: String) throws {
        let request = try MarkovJSON.decodeRequest(from: Data(contentsOf: URL(fileURLWithPath: path)))
        try writeMarkovValidation(request: request, report: ValidateOnlyMarkovBackend().validationReport(for: request))
    }

    private static func writeMarkovValidation(request: MarkovAnalysisRequest, report: ValidationReport) throws {
        FileHandle.standardOutput.write(try MarkovJSON.encodeValidation(MarkovValidationDocument(backend: report.backend, diagnostics: report.diagnostics))); print()
    }

    private static func printMarkovSolution(request: MarkovAnalysisRequest, solution: MarkovAnalysisSolution, metadata: SolverRunMetadata) {
        print(request.model.title); print("backend: \(metadata.backendKind.rawValue)"); print("algorithm: \(metadata.algorithm)"); print("exactness: \(metadata.exactness.rawValue)")
        for (state, probability) in zip(request.model.states, solution.stationaryProbabilities) { print("stationary.\(state): \(format(probability))") }
        print("stationaryExpectedCost: \(format(solution.stationaryExpectedCost))")
        for period in solution.transientResults { print("period \(period.period): probabilities=\(period.probabilities.map(format).joined(separator: ",")) expectedCost=\(format(period.expectedCost))") }
    }

    private static func printMarkovValidation(request: MarkovAnalysisRequest, report: ValidationReport, source: String) {
        let errors = report.diagnostics.filter { $0.severity == .error }; let warnings = report.diagnostics.filter { $0.severity == .warning }
        print(request.model.title); print("backend: \(report.backend.rawValue)"); print("source: \(source)"); print("status: \(errors.isEmpty ? "valid" : "invalid")"); print("errors: \(errors.count)"); print("warnings: \(warnings.count)")
        for item in report.diagnostics { print("\(item.severity.rawValue): \(item.code)\(item.path.map { " [\($0)]" } ?? "") - \(item.message)") }
    }

    private static func readLegacyGoalProgram(path: String) throws -> GoalProgram {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try WinQSBGoalProgrammingParser.parse(from: LegacyCompressedFile.expandedData(from: data))
    }

    private static func goalProgrammingBackend(for kind: SolverBackendKind, command: String) throws -> any GoalProgrammingBackend {
        guard let backend = GoalProgrammingBackends.backend(for: kind) else { throw CLIError.usage("external backend is not available yet for \(command)") }
        return backend
    }

    private static func solveGoalProgrammingLegacy(path: String, backend: SolverBackendKind) throws {
        let model = try readLegacyGoalProgram(path: path)
        let solver = try goalProgrammingBackend(for: backend, command: "solve-goal")
        if solver.capabilities.solves { printGoalProgrammingSolution(model: model, solution: try solver.solve(model), metadata: solver.runMetadata(for: model)) }
        else { printGoalProgrammingValidation(model: model, report: solver.validationReport(for: model), source: path) }
    }

    private static func validateGoalProgrammingLegacy(path: String) throws {
        let model = try readLegacyGoalProgram(path: path)
        printGoalProgrammingValidation(model: model, report: ValidateOnlyGoalProgrammingBackend().validationReport(for: model), source: path)
    }

    private static func exportGoalProgrammingJSON(path: String) throws {
        FileHandle.standardOutput.write(try GoalProgrammingJSON.encodeModel(readLegacyGoalProgram(path: path))); print()
    }

    private static func solveGoalProgrammingJSON(path: String, backend: SolverBackendKind) throws {
        let model = try GoalProgrammingJSON.decodeModel(from: Data(contentsOf: URL(fileURLWithPath: path)))
        let solver = try goalProgrammingBackend(for: backend, command: "solve-goal-json")
        if solver.capabilities.solves {
            let solution = try solver.solve(model)
            FileHandle.standardOutput.write(try GoalProgrammingJSON.encodeSolution(solver.solutionDocument(for: model, solution: solution))); print()
        } else { try writeGoalProgrammingValidation(model: model, report: solver.validationReport(for: model)) }
    }

    private static func validateGoalProgrammingJSON(path: String) throws {
        let model = try GoalProgrammingJSON.decodeModel(from: Data(contentsOf: URL(fileURLWithPath: path)))
        try writeGoalProgrammingValidation(model: model, report: ValidateOnlyGoalProgrammingBackend().validationReport(for: model))
    }

    private static func writeGoalProgrammingValidation(model: GoalProgram, report: ValidationReport) throws {
        FileHandle.standardOutput.write(try GoalProgrammingJSON.encodeValidation(GoalProgrammingValidationDocument(backend: report.backend, diagnostics: report.diagnostics))); print()
    }

    private static func printGoalProgrammingSolution(model: GoalProgram, solution: GoalProgrammingSolution, metadata: SolverRunMetadata) {
        print(model.title); print("backend: \(metadata.backendKind.rawValue)"); print("algorithm: \(metadata.algorithm)"); print("exactness: \(metadata.exactness.rawValue)")
        for outcome in solution.goalOutcomes { print("priority \(outcome.priority) \(outcome.name) [\(outcome.sense.rawValue)]: \(format(outcome.value))") }
        for name in model.variableNames { print("\(name): \(format(solution.variableValues[name] ?? 0))") }
    }

    private static func printGoalProgrammingValidation(model: GoalProgram, report: ValidationReport, source: String) {
        let errors = report.diagnostics.filter { $0.severity == .error }; let warnings = report.diagnostics.filter { $0.severity == .warning }
        print(model.title); print("backend: \(report.backend.rawValue)"); print("source: \(source)"); print("status: \(errors.isEmpty ? "valid" : "invalid")"); print("errors: \(errors.count)"); print("warnings: \(warnings.count)")
        for item in report.diagnostics { print("\(item.severity.rawValue): \(item.code)\(item.path.map { " [\($0)]" } ?? "") - \(item.message)") }
    }

    private static func readLegacyAcceptanceSamplingModel(path: String) throws -> AcceptanceSamplingModelEnvelope {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try WinQSBAcceptanceSamplingParser.parse(from: LegacyCompressedFile.expandedData(from: data))
    }

    private static func acceptanceSamplingBackend(for kind: SolverBackendKind, command: String) throws -> any AcceptanceSamplingBackend {
        guard let backend = AcceptanceSamplingBackends.backend(for: kind) else { throw CLIError.usage("external backend is not available yet for \(command)") }
        return backend
    }

    private static func solveAcceptanceSamplingLegacy(path: String, backend: SolverBackendKind) throws {
        let model = try readLegacyAcceptanceSamplingModel(path: path)
        let solver = try acceptanceSamplingBackend(for: backend, command: "solve-acceptance")
        if solver.capabilities.solves { printAcceptanceSamplingSolution(model: model, solution: try solver.solve(model), metadata: solver.runMetadata(for: model)) }
        else { printAcceptanceSamplingValidation(model: model, report: solver.validationReport(for: model), source: path) }
    }

    private static func validateAcceptanceSamplingLegacy(path: String) throws {
        let model = try readLegacyAcceptanceSamplingModel(path: path)
        printAcceptanceSamplingValidation(model: model, report: ValidateOnlyAcceptanceSamplingBackend().validationReport(for: model), source: path)
    }

    private static func exportAcceptanceSamplingJSON(path: String) throws {
        FileHandle.standardOutput.write(try AcceptanceSamplingJSON.encodeModel(readLegacyAcceptanceSamplingModel(path: path))); print()
    }

    private static func solveAcceptanceSamplingJSON(path: String, backend: SolverBackendKind) throws {
        let model = try AcceptanceSamplingJSON.decodeModel(from: Data(contentsOf: URL(fileURLWithPath: path)))
        let solver = try acceptanceSamplingBackend(for: backend, command: "solve-acceptance-json")
        if solver.capabilities.solves {
            let solution = try solver.solve(model)
            FileHandle.standardOutput.write(try AcceptanceSamplingJSON.encodeSolution(solver.solutionDocument(for: model, solution: solution))); print()
        } else { try writeAcceptanceSamplingValidation(model: model, report: solver.validationReport(for: model)) }
    }

    private static func validateAcceptanceSamplingJSON(path: String) throws {
        let model = try AcceptanceSamplingJSON.decodeModel(from: Data(contentsOf: URL(fileURLWithPath: path)))
        try writeAcceptanceSamplingValidation(model: model, report: ValidateOnlyAcceptanceSamplingBackend().validationReport(for: model))
    }

    private static func writeAcceptanceSamplingValidation(model: AcceptanceSamplingModelEnvelope, report: ValidationReport) throws {
        FileHandle.standardOutput.write(try AcceptanceSamplingJSON.encodeValidation(AcceptanceSamplingValidationDocument(kind: model.kind, backend: report.backend, diagnostics: report.diagnostics))); print()
    }

    private static func printAcceptanceSamplingSolution(model: AcceptanceSamplingModelEnvelope, solution: AcceptanceSamplingSolution, metadata: SolverRunMetadata) {
        print(model.title); print("backend: \(metadata.backendKind.rawValue)"); print("algorithm: \(metadata.algorithm)"); print("exactness: \(metadata.exactness.rawValue)"); print("planType: \(model.kind.rawValue)")
        print("producerRiskAtAQL: \(format(solution.producerRiskAtAQL))"); print("consumerRiskAtRQL: \(format(solution.consumerRiskAtRQL))")
        print("acceptanceAtAQL: \(format(solution.atAQL.acceptanceProbability))"); print("acceptanceAtRQL: \(format(solution.atRQL.acceptanceProbability))")
        print("ASNAtAQL: \(format(solution.atAQL.averageSampleNumber))"); print("ASNAtRQL: \(format(solution.atRQL.averageSampleNumber))")
    }

    private static func printAcceptanceSamplingValidation(model: AcceptanceSamplingModelEnvelope, report: ValidationReport, source: String) {
        let errors = report.diagnostics.filter { $0.severity == .error }; let warnings = report.diagnostics.filter { $0.severity == .warning }
        print(model.title); print("backend: \(report.backend.rawValue)"); print("source: \(source)"); print("planType: \(model.kind.rawValue)"); print("status: \(errors.isEmpty ? "valid" : "invalid")"); print("errors: \(errors.count)"); print("warnings: \(warnings.count)")
        for item in report.diagnostics { print("\(item.severity.rawValue): \(item.code)\(item.path.map { " [\($0)]" } ?? "") - \(item.message)") }
    }

    private static func readLegacyQualityControlModel(path: String) throws -> QualityControlModelEnvelope {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try WinQSBQualityControlParser.parse(from: LegacyCompressedFile.expandedData(from: data))
    }

    private static func qualityControlBackend(for kind: SolverBackendKind, command: String) throws -> any QualityControlBackend {
        guard let backend = QualityControlBackends.backend(for: kind) else { throw CLIError.usage("external backend is not available yet for \(command)") }
        return backend
    }

    private static func solveQualityControlLegacy(path: String, backend: SolverBackendKind) throws {
        let model = try readLegacyQualityControlModel(path: path); let solver = try qualityControlBackend(for: backend, command: "solve-quality")
        if solver.capabilities.solves { printQualityControlSolution(model: model, solution: try solver.solve(model), metadata: solver.runMetadata(for: model)) }
        else { printQualityControlValidation(model: model, report: solver.validationReport(for: model), source: path) }
    }
    private static func validateQualityControlLegacy(path: String) throws { let model = try readLegacyQualityControlModel(path: path); printQualityControlValidation(model: model, report: ValidateOnlyQualityControlBackend().validationReport(for: model), source: path) }
    private static func exportQualityControlJSON(path: String) throws { FileHandle.standardOutput.write(try QualityControlJSON.encodeModel(readLegacyQualityControlModel(path: path))); print() }
    private static func solveQualityControlJSON(path: String, backend: SolverBackendKind) throws {
        let model = try QualityControlJSON.decodeModel(from: Data(contentsOf: URL(fileURLWithPath: path))); let solver = try qualityControlBackend(for: backend, command: "solve-quality-json")
        if solver.capabilities.solves { let solution = try solver.solve(model); FileHandle.standardOutput.write(try QualityControlJSON.encodeSolution(solver.solutionDocument(for: model, solution: solution))); print() }
        else { try writeQualityControlValidation(model: model, report: solver.validationReport(for: model)) }
    }
    private static func validateQualityControlJSON(path: String) throws { let model = try QualityControlJSON.decodeModel(from: Data(contentsOf: URL(fileURLWithPath: path))); try writeQualityControlValidation(model: model, report: ValidateOnlyQualityControlBackend().validationReport(for: model)) }
    private static func writeQualityControlValidation(model: QualityControlModelEnvelope, report: ValidationReport) throws { FileHandle.standardOutput.write(try QualityControlJSON.encodeValidation(QualityControlValidationDocument(kind: model.kind, backend: report.backend, diagnostics: report.diagnostics))); print() }
    private static func printQualityControlSolution(model: QualityControlModelEnvelope, solution: QualityControlSolutionEnvelope, metadata: SolverRunMetadata) {
        print(model.title); print("backend: \(metadata.backendKind.rawValue)"); print("algorithm: \(metadata.algorithm)"); print("exactness: \(metadata.exactness.rawValue)"); print("modelType: \(model.kind.rawValue)")
        switch solution {
        case .cChart(let x), .pChart(let x): print("points: \(x.points.count)"); print("outsideLimits: \(x.outsideLimitIndexes.map(String.init).joined(separator: ","))"); if let first = x.points.first { print("centerLine: \(format(first.centerLine))") }
        case .xbarRChart(let x): print("subgroups: \(x.meanChart.points.count)"); print("grandMean: \(format(x.grandMean))"); print("averageRange: \(format(x.averageRange))"); print("meanOutsideLimits: \(x.meanChart.outsideLimitIndexes.map(String.init).joined(separator: ","))"); print("rangeOutsideLimits: \(x.rangeChart.outsideLimitIndexes.map(String.init).joined(separator: ","))")
        case .pareto(let x): print("totalCount: \(format(x.totalCount))"); for item in x.categories { print("\(item.name): \(format(item.count)) cumulative=\(format(item.cumulativePercentage))") }
        case .normalProbabilityPlot(let x): print("observations: \(x.points.count)"); print("mean: \(format(x.mean))"); print("sampleStandardDeviation: \(format(x.sampleStandardDeviation))"); print("correlation: \(format(x.correlation))")
        }
    }
    private static func printQualityControlValidation(model: QualityControlModelEnvelope, report: ValidationReport, source: String) { let errors=report.diagnostics.filter{$0.severity == .error}, warnings=report.diagnostics.filter{$0.severity == .warning}; print(model.title); print("backend: \(report.backend.rawValue)"); print("source: \(source)"); print("modelType: \(model.kind.rawValue)"); print("status: \(errors.isEmpty ? "valid" : "invalid")"); print("errors: \(errors.count)"); print("warnings: \(warnings.count)"); for item in report.diagnostics { print("\(item.severity.rawValue): \(item.code)\(item.path.map { " [\($0)]" } ?? "") - \(item.message)") } }

    private static func readLegacyAggregatePlanningModel(path: String) throws -> AggregatePlanningModel {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try WinQSBAggregatePlanningParser.parse(from: LegacyCompressedFile.expandedData(from: data))
    }

    private static func aggregatePlanningBackend(for kind: SolverBackendKind, command: String) throws -> any AggregatePlanningBackend {
        guard let backend = AggregatePlanningBackends.backend(for: kind) else { throw CLIError.usage("external backend is not available yet for \(command)") }
        return backend
    }

    private static func solveAggregatePlanningLegacy(path: String, backend: SolverBackendKind) throws {
        let model = try readLegacyAggregatePlanningModel(path: path)
        let solver = try aggregatePlanningBackend(for: backend, command: "solve-aggregate")
        if solver.capabilities.solves {
            printAggregatePlanningSolution(model: model, solution: try solver.solve(model), metadata: solver.runMetadata(for: model))
        } else {
            printAggregatePlanningValidation(model: model, report: solver.validationReport(for: model), source: path)
        }
    }

    private static func validateAggregatePlanningLegacy(path: String) throws {
        let model = try readLegacyAggregatePlanningModel(path: path)
        printAggregatePlanningValidation(model: model, report: ValidateOnlyAggregatePlanningBackend().validationReport(for: model), source: path)
    }

    private static func exportAggregatePlanningJSON(path: String) throws {
        FileHandle.standardOutput.write(try AggregatePlanningJSON.encodeModel(readLegacyAggregatePlanningModel(path: path)))
        print()
    }

    private static func solveAggregatePlanningJSON(path: String, backend: SolverBackendKind) throws {
        let model = try AggregatePlanningJSON.decodeModel(from: Data(contentsOf: URL(fileURLWithPath: path)))
        let solver = try aggregatePlanningBackend(for: backend, command: "solve-aggregate-json")
        if solver.capabilities.solves {
            let solution = try solver.solve(model)
            FileHandle.standardOutput.write(try AggregatePlanningJSON.encodeSolution(solver.solutionDocument(for: model, solution: solution)))
            print()
        } else {
            try writeAggregatePlanningValidation(model: model, report: solver.validationReport(for: model))
        }
    }

    private static func validateAggregatePlanningJSON(path: String) throws {
        let model = try AggregatePlanningJSON.decodeModel(from: Data(contentsOf: URL(fileURLWithPath: path)))
        try writeAggregatePlanningValidation(model: model, report: ValidateOnlyAggregatePlanningBackend().validationReport(for: model))
    }

    private static func writeAggregatePlanningValidation(model _: AggregatePlanningModel, report: ValidationReport) throws {
        FileHandle.standardOutput.write(try AggregatePlanningJSON.encodeValidation(AggregatePlanningValidationDocument(backend: report.backend, diagnostics: report.diagnostics)))
        print()
    }

    private static func printAggregatePlanningSolution(model: AggregatePlanningModel, solution: AggregatePlanningSolution, metadata: SolverRunMetadata) {
        print(model.title)
        print("backend: \(metadata.backendKind.rawValue)")
        print("algorithm: \(metadata.algorithm)")
        print("exactness: \(metadata.exactness.rawValue)")
        print("legacyMethod: \(model.method.rawValue)")
        print("totalCost: \(format(solution.totalCost))")
        for period in solution.periods {
            let workforce = period.workforce.map(format) ?? "n/a"
            print("\(period.period): workforce=\(workforce) hired=\(format(period.hired)) dismissed=\(format(period.dismissed)) regular=\(format(period.regularProduction)) overtime=\(format(period.overtimeProduction)) subcontract=\(format(period.subcontracted)) inventory=\(format(period.endingInventory)) backorder=\(format(period.endingBackorder))")
        }
    }

    private static func printAggregatePlanningValidation(model: AggregatePlanningModel, report: ValidationReport, source: String) {
        let errors = report.diagnostics.filter { $0.severity == .error }
        let warnings = report.diagnostics.filter { $0.severity == .warning }
        print(model.title)
        print("backend: \(report.backend.rawValue)")
        print("source: \(source)")
        print("legacyMethod: \(model.method.rawValue)")
        print("status: \(errors.isEmpty ? "valid" : "invalid")")
        print("errors: \(errors.count)")
        print("warnings: \(warnings.count)")
        for item in report.diagnostics { print("\(item.severity.rawValue): \(item.code)\(item.path.map { " [\($0)]" } ?? "") - \(item.message)") }
    }

    private static func readLegacyMRPModel(path: String) throws -> MaterialRequirementsPlanningModel {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try WinQSBMaterialRequirementsPlanningParser.parse(from: LegacyCompressedFile.expandedData(from: data))
    }

    private static func mrpBackend(for kind: SolverBackendKind, command: String) throws -> any MaterialRequirementsPlanningBackend {
        guard let backend = MaterialRequirementsPlanningBackends.backend(for: kind) else { throw CLIError.usage("external backend is not available yet for \(command)") }
        return backend
    }

    private static func solveMRPLegacy(path: String, backend: SolverBackendKind) throws {
        let model = try readLegacyMRPModel(path: path)
        let solver = try mrpBackend(for: backend, command: "solve-mrp")
        if solver.capabilities.solves {
            printMRPSolution(model: model, solution: try solver.solve(model), metadata: solver.runMetadata(for: model))
        } else {
            printMRPValidation(model: model, report: solver.validationReport(for: model), source: path)
        }
    }

    private static func validateMRPLegacy(path: String) throws {
        let model = try readLegacyMRPModel(path: path)
        printMRPValidation(model: model, report: ValidateOnlyMaterialRequirementsPlanningBackend().validationReport(for: model), source: path)
    }

    private static func exportMRPJSON(path: String) throws {
        FileHandle.standardOutput.write(try MaterialRequirementsPlanningJSON.encodeModel(readLegacyMRPModel(path: path)))
        print()
    }

    private static func solveMRPJSON(path: String, backend: SolverBackendKind) throws {
        let model = try MaterialRequirementsPlanningJSON.decodeModel(from: Data(contentsOf: URL(fileURLWithPath: path)))
        let solver = try mrpBackend(for: backend, command: "solve-mrp-json")
        if solver.capabilities.solves {
            let solution = try solver.solve(model)
            FileHandle.standardOutput.write(try MaterialRequirementsPlanningJSON.encodeSolution(solver.solutionDocument(for: model, solution: solution)))
            print()
        } else {
            try writeMRPValidation(report: solver.validationReport(for: model))
        }
    }

    private static func validateMRPJSON(path: String) throws {
        let model = try MaterialRequirementsPlanningJSON.decodeModel(from: Data(contentsOf: URL(fileURLWithPath: path)))
        try writeMRPValidation(report: ValidateOnlyMaterialRequirementsPlanningBackend().validationReport(for: model))
    }

    private static func writeMRPValidation(report: ValidationReport) throws {
        FileHandle.standardOutput.write(try MaterialRequirementsPlanningJSON.encodeValidation(MaterialRequirementsPlanningValidationDocument(backend: report.backend, diagnostics: report.diagnostics)))
        print()
    }

    private static func printMRPSolution(model: MaterialRequirementsPlanningModel, solution: MaterialRequirementsPlanningSolution, metadata: SolverRunMetadata) {
        print(model.title)
        print("backend: \(metadata.backendKind.rawValue)")
        print("algorithm: \(metadata.algorithm)")
        print("exactness: \(metadata.exactness.rawValue)")
        print("buckets: \(solution.bucketNames.count)")
        for schedule in solution.schedules {
            print("\(schedule.itemIdentifier): gross=\(format(schedule.grossRequirements.reduce(0, +))) plannedReceipts=\(format(schedule.plannedOrderReceipts.reduce(0, +))) plannedReleases=\(format(schedule.plannedOrderReleases.reduce(0, +))) endingOnHand=\(format(schedule.projectedOnHand.last ?? 0)) capacityExcess=\(format(schedule.capacityExcess.reduce(0, +)))")
        }
    }

    private static func printMRPValidation(model: MaterialRequirementsPlanningModel, report: ValidationReport, source: String) {
        let errors = report.diagnostics.filter { $0.severity == .error }
        let warnings = report.diagnostics.filter { $0.severity == .warning }
        print(model.title)
        print("backend: \(report.backend.rawValue)")
        print("source: \(source)")
        print("items: \(model.items.count)")
        print("status: \(errors.isEmpty ? "valid" : "invalid")")
        print("errors: \(errors.count)")
        print("warnings: \(warnings.count)")
        for item in report.diagnostics { print("\(item.severity.rawValue): \(item.code)\(item.path.map { " [\($0)]" } ?? "") - \(item.message)") }
    }

    private static func readLegacyQuadraticProgram(path: String) throws -> QuadraticProgram {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try WinQSBQuadraticProgrammingParser.parse(from: LegacyCompressedFile.expandedData(from: data))
    }
    private static func quadraticProgrammingBackend(for kind: SolverBackendKind, command: String) throws -> any QuadraticProgrammingBackend {
        guard let backend = QuadraticProgrammingBackends.backend(for: kind) else { throw CLIError.usage("external backend is not available yet for \(command)") }
        return backend
    }
    private static func solveQuadraticProgrammingLegacy(path: String, backend: SolverBackendKind) throws {
        let model = try readLegacyQuadraticProgram(path: path), solver = try quadraticProgrammingBackend(for: backend, command: "solve-qp")
        if solver.capabilities.solves { printQuadraticProgrammingSolution(model: model, solution: try solver.solve(model), metadata: solver.runMetadata(for: model)) }
        else { printQuadraticProgrammingValidation(model: model, report: solver.validationReport(for: model), source: path) }
    }
    private static func validateQuadraticProgrammingLegacy(path: String) throws { let model = try readLegacyQuadraticProgram(path: path); printQuadraticProgrammingValidation(model: model, report: ValidateOnlyQuadraticProgrammingBackend().validationReport(for: model), source: path) }
    private static func exportQuadraticProgrammingJSON(path: String) throws { FileHandle.standardOutput.write(try QuadraticProgrammingJSON.encodeModel(readLegacyQuadraticProgram(path: path))); print() }
    private static func solveQuadraticProgrammingJSON(path: String, backend: SolverBackendKind) throws {
        let model = try QuadraticProgrammingJSON.decodeUncheckedModel(from: Data(contentsOf: URL(fileURLWithPath: path))), solver = try quadraticProgrammingBackend(for: backend, command: "solve-qp-json")
        if solver.capabilities.solves { let solution = try solver.solve(model); FileHandle.standardOutput.write(try QuadraticProgrammingJSON.encodeSolution(solver.solutionDocument(for: model, solution: solution))); print() }
        else { try writeQuadraticProgrammingValidation(report: solver.validationReport(for: model)) }
    }
    private static func validateQuadraticProgrammingJSON(path: String) throws { let model = try QuadraticProgrammingJSON.decodeUncheckedModel(from: Data(contentsOf: URL(fileURLWithPath: path))); try writeQuadraticProgrammingValidation(report: ValidateOnlyQuadraticProgrammingBackend().validationReport(for: model)) }
    private static func writeQuadraticProgrammingValidation(report: ValidationReport) throws { FileHandle.standardOutput.write(try QuadraticProgrammingJSON.encodeValidation(QuadraticProgramValidationDocument(backend: report.backend, diagnostics: report.diagnostics))); print() }
    private static func printQuadraticProgrammingSolution(model: QuadraticProgram, solution: QuadraticProgramSolution, metadata: SolverRunMetadata) {
        print(model.title); print("backend: \(metadata.backendKind.rawValue)"); print("algorithm: \(metadata.algorithm)"); print("exactness: \(metadata.exactness.rawValue)"); print("objectiveValue: \(format(solution.objectiveValue))")
        for name in model.variableNames { print("\(name): \(format(solution.variableValues[name] ?? 0))") }
        print("activeConstraints: \(solution.activeConstraints.joined(separator: ","))")
    }
    private static func printQuadraticProgrammingValidation(model: QuadraticProgram, report: ValidationReport, source: String) {
        let errors=report.diagnostics.filter{$0.severity == .error},warnings=report.diagnostics.filter{$0.severity == .warning};print(model.title);print("backend: \(report.backend.rawValue)");print("source: \(source)");print("variables: \(model.variableNames.count)");print("status: \(errors.isEmpty ? "valid":"invalid")");print("errors: \(errors.count)");print("warnings: \(warnings.count)");for item in report.diagnostics{print("\(item.severity.rawValue): \(item.code)\(item.path.map { " [\($0)]" } ?? "") - \(item.message)")}
    }

    private static func readLegacyNonlinearProgram(path:String)throws->NonlinearProgram{let data=try Data(contentsOf:URL(fileURLWithPath:path));return try WinQSBNonlinearProgrammingParser.parse(from:LegacyCompressedFile.expandedData(from:data))}
    private static func nonlinearProgrammingBackend(for kind:SolverBackendKind,command:String)throws->any NonlinearProgrammingBackend{guard let backend=NonlinearProgrammingBackends.backend(for:kind)else{throw CLIError.usage("external backend is not available yet for \(command)")};return backend}
    private static func solveNonlinearProgrammingLegacy(path:String,backend:SolverBackendKind)throws{let model=try readLegacyNonlinearProgram(path:path),solver=try nonlinearProgrammingBackend(for:backend,command:"solve-nlp");if solver.capabilities.solves{printNonlinearProgrammingSolution(model:model,solution:try solver.solve(model),metadata:solver.runMetadata(for:model))}else{printNonlinearProgrammingValidation(model:model,report:solver.validationReport(for:model),source:path)}}
    private static func validateNonlinearProgrammingLegacy(path:String)throws{let model=try readLegacyNonlinearProgram(path:path);printNonlinearProgrammingValidation(model:model,report:ValidateOnlyNonlinearProgrammingBackend().validationReport(for:model),source:path)}
    private static func exportNonlinearProgrammingJSON(path:String)throws{FileHandle.standardOutput.write(try NonlinearProgrammingJSON.encodeModel(readLegacyNonlinearProgram(path:path)));print()}
    private static func solveNonlinearProgrammingJSON(path:String,backend:SolverBackendKind)throws{let model=try NonlinearProgrammingJSON.decodeUncheckedModel(from:Data(contentsOf:URL(fileURLWithPath:path))),solver=try nonlinearProgrammingBackend(for:backend,command:"solve-nlp-json");if solver.capabilities.solves{let solution=try solver.solve(model);FileHandle.standardOutput.write(try NonlinearProgrammingJSON.encodeSolution(solver.solutionDocument(for:model,solution:solution)));print()}else{try writeNonlinearProgrammingValidation(report:solver.validationReport(for:model))}}
    private static func validateNonlinearProgrammingJSON(path:String)throws{let model=try NonlinearProgrammingJSON.decodeUncheckedModel(from:Data(contentsOf:URL(fileURLWithPath:path)));try writeNonlinearProgrammingValidation(report:ValidateOnlyNonlinearProgrammingBackend().validationReport(for:model))}
    private static func writeNonlinearProgrammingValidation(report:ValidationReport)throws{FileHandle.standardOutput.write(try NonlinearProgrammingJSON.encodeValidation(NonlinearProgramValidationDocument(backend:report.backend,diagnostics:report.diagnostics)));print()}
    private static func printNonlinearProgrammingSolution(model:NonlinearProgram,solution:NonlinearProgramSolution,metadata:SolverRunMetadata){print(model.title);print("backend: \(metadata.backendKind.rawValue)");print("algorithm: \(metadata.algorithm)");print("exactness: \(metadata.exactness.rawValue)");print("objectiveValue: \(format(solution.objectiveValue))");for name in model.variableNames{print("\(name): \(format(solution.variableValues[name] ?? 0))")};print("maximumViolation: \(format(solution.maximumViolation))");print("iterations: \(solution.iterations)");for item in solution.constraintEvaluations{print("\(item.name): value=\(format(item.value)) \(item.relation.rawValue) \(format(item.rhs)) violation=\(format(item.violation))")}}
    private static func printNonlinearProgrammingValidation(model:NonlinearProgram,report:ValidationReport,source:String){let errors=report.diagnostics.filter{$0.severity == .error},warnings=report.diagnostics.filter{$0.severity == .warning};print(model.title);print("backend: \(report.backend.rawValue)");print("source: \(source)");print("variables: \(model.variableNames.count)");print("status: \(errors.isEmpty ? "valid":"invalid")");print("errors: \(errors.count)");print("warnings: \(warnings.count)");for item in report.diagnostics{print("\(item.severity.rawValue): \(item.code)\(item.path.map { " [\($0)]" } ?? "") - \(item.message)")}}

    private static func readLegacySimulation(path: String) throws -> SimulationModel { let data = try Data(contentsOf: URL(fileURLWithPath: path)); return try WinQSBSimulationParser.parse(from: LegacyCompressedFile.expandedData(from: data)) }
    private static func simulationBackend(for kind: SolverBackendKind, command: String) throws -> any SimulationBackend { guard let backend = SimulationBackends.backend(for: kind) else { throw CLIError.usage("external backend is not available yet for \(command)") }; return backend }
    private static func solveSimulationLegacy(path: String, backend: SolverBackendKind) throws { let model = try readLegacySimulation(path: path), solver = try simulationBackend(for: backend, command: "solve-simulation"); if solver.capabilities.solves { printSimulationSolution(model: model, solution: try solver.solve(model), metadata: solver.runMetadata(for: model)) } else { printSimulationValidation(model: model, report: solver.validationReport(for: model), source: path) } }
    private static func validateSimulationLegacy(path: String) throws { let model = try readLegacySimulation(path: path); printSimulationValidation(model: model, report: ValidateOnlySimulationBackend().validationReport(for: model), source: path) }
    private static func exportSimulationJSON(path: String) throws { FileHandle.standardOutput.write(try SimulationJSON.encodeModel(readLegacySimulation(path: path))); print() }
    private static func solveSimulationJSON(path: String, backend: SolverBackendKind) throws { let model = try SimulationJSON.decodeUncheckedModel(from: Data(contentsOf: URL(fileURLWithPath: path))), solver = try simulationBackend(for: backend, command: "solve-simulation-json"); if solver.capabilities.solves { FileHandle.standardOutput.write(try SimulationJSON.encodeSolution(solver.solutionDocument(for: model, solution: try solver.solve(model)))); print() } else { try writeSimulationValidation(model: model, report: solver.validationReport(for: model)) } }
    private static func validateSimulationJSON(path: String) throws { let model = try SimulationJSON.decodeUncheckedModel(from: Data(contentsOf: URL(fileURLWithPath: path))); try writeSimulationValidation(model: model, report: ValidateOnlySimulationBackend().validationReport(for: model)) }
    private static func writeSimulationValidation(model: SimulationModel, report: ValidationReport) throws { FileHandle.standardOutput.write(try SimulationJSON.encodeValidation(SimulationValidationDocument(model: model, report: report))); print() }
    private static func printSimulationSolution(model: SimulationModel, solution: SimulationSolution, metadata: SolverRunMetadata) { print(model.title); print("backend: \(metadata.backendKind.rawValue)"); print("algorithm: \(metadata.algorithm)"); print("exactness: \(metadata.exactness.rawValue)"); print("representation: \(model.representation.rawValue)"); print("horizon: \(format(solution.horizon))"); print("seed: \(solution.seed)"); print("generatedEntities: \(solution.generatedEntities)"); print("completedEntities: \(solution.completedEntities)"); for queue in solution.queueMetrics { print("\(queue.name): averageLength=\(format(queue.averageLength)) maximumLength=\(queue.maximumLength) entered=\(queue.entered) rejected=\(queue.rejected)") }; for server in solution.serverMetrics { print("\(server.name): completed=\(server.completed) utilization=\(format(server.utilization))") } }
    private static func printSimulationValidation(model: SimulationModel, report: ValidationReport, source: String) { let errors = report.diagnostics.filter { $0.severity == .error }, warnings = report.diagnostics.filter { $0.severity == .warning }; print(model.title); print("backend: \(report.backend.rawValue)"); print("source: \(source)"); print("components: \(model.components.count)"); print("status: \(errors.isEmpty ? "valid" : "invalid")"); print("errors: \(errors.count)"); print("warnings: \(warnings.count)"); for item in report.diagnostics { print("\(item.severity.rawValue): \(item.code)\(item.path.map { " [\($0)]" } ?? "") - \(item.message)") } }

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

    private static func exportForecastingJSON(arguments: [String]) throws {
        guard arguments.count >= 3, arguments.count <= 5 else {
            throw CLIError.usage("export-forecast-json expects <legacy-fc-file> <trend|moving-average|exp-smoothing|seasonal|regression> [parameter] [periods-ahead]")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: arguments[1]))
        let model = try WinQSBForecastingParser.parseModelEnvelope(from: LegacyCompressedFile.expandedData(from: data))
        let method: ForecastingMethod
        var windowSize: Int?; var alpha: Double?; var seasonLength: Int?
        var periodsAhead = 1
        switch arguments[2] {
        case "trend": method = .linearTrend
        case "regression": method = .ordinaryLeastSquares
        case "moving-average":
            method = .movingAverage
            guard arguments.count >= 4, let value = Int(arguments[3]) else { throw CLIError.usage("moving-average requires an integer window size") }
            windowSize = value
        case "exp-smoothing":
            method = .exponentialSmoothing
            guard arguments.count >= 4, let value = Double(arguments[3]) else { throw CLIError.usage("exp-smoothing requires alpha") }
            alpha = value
        case "seasonal":
            method = .multiplicativeSeasonalDecomposition
            guard arguments.count >= 4, let value = Int(arguments[3]) else { throw CLIError.usage("seasonal requires an integer season length") }
            seasonLength = value
        default: throw CLIError.usage("forecast method must be trend, moving-average, exp-smoothing, seasonal, or regression")
        }
        if arguments.count == 5 {
            guard let value = Int(arguments[4]) else { throw CLIError.usage("periods-ahead must be an integer") }
            periodsAhead = value
        } else if arguments.count == 4, method == .linearTrend || method == .ordinaryLeastSquares {
            guard let value = Int(arguments[3]) else { throw CLIError.usage("periods-ahead must be an integer") }
            periodsAhead = value
        }
        let request = ForecastingRequest(model: model, method: method, periodsAhead: periodsAhead, windowSize: windowSize, alpha: alpha, seasonLength: seasonLength)
        try ForecastingValidator.validate(request)
        FileHandle.standardOutput.write(try ForecastingModelJSON.encodeRequest(request)); print()
    }

    private static func solveForecastingJSON(path: String, backend: SolverBackendKind) throws {
        let request = try ForecastingModelJSON.decodeRequest(from: Data(contentsOf: URL(fileURLWithPath: path)))
        let solver = try forecastingBackend(for: backend, command: "solve-forecast-json")
        if solver.capabilities.solves {
            let solution = try solver.solve(request)
            FileHandle.standardOutput.write(try ForecastingModelJSON.encodeSolutionDocument(solver.solutionDocument(for: request, solution: solution))); print()
        } else {
            let report = solver.validationReport(for: request)
            FileHandle.standardOutput.write(try ForecastingModelJSON.encodeValidation(ForecastingValidationDocument(method: request.method, backend: report.backend, diagnostics: report.diagnostics))); print()
        }
    }

    private static func validateForecastingJSON(path: String) throws {
        let request = try ForecastingModelJSON.decodeRequest(from: Data(contentsOf: URL(fileURLWithPath: path)))
        let report = ValidateOnlyForecastingBackend().validationReport(for: request)
        FileHandle.standardOutput.write(try ForecastingModelJSON.encodeValidation(ForecastingValidationDocument(method: request.method, backend: report.backend, diagnostics: report.diagnostics))); print()
    }

    private static func solveEOQ(path: String, backend: SolverBackendKind) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let model = try WinQSBInventoryParser.parseEOQ(from: expanded)
        let solver = try inventoryBackend(for: backend, command: "solve-eoq")
        guard solver.capabilities.solves else {
            printInventoryValidationReport(
                title: model.title,
                modelType: InventoryProblemKind.eoq.rawValue,
                source: path,
                report: solver.validationReport(for: model)
            )
            return
        }
        let solution = try solver.solve(model)
        let metadata = solver.runMetadata(for: model)

        print(model.title)
        print("timeUnit: \(model.timeUnit)")
        print("backend: \(metadata.backendKind.rawValue)")
        print("algorithm: \(metadata.algorithm)")
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

    private static func solveDiscountEOQ(path: String, backend: SolverBackendKind) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let model = try WinQSBInventoryParser.parseQuantityDiscountEOQ(from: expanded)
        let solver = try inventoryBackend(for: backend, command: "solve-discount-eoq")
        guard solver.capabilities.solves else {
            printInventoryValidationReport(
                title: model.title,
                modelType: InventoryProblemKind.quantityDiscountEOQ.rawValue,
                source: path,
                report: solver.validationReport(for: model)
            )
            return
        }
        let solution = try solver.solve(model)
        let metadata = solver.runMetadata(for: model)

        print(model.title)
        print("timeUnit: \(model.timeUnit)")
        print("backend: \(metadata.backendKind.rawValue)")
        print("algorithm: \(metadata.algorithm)")
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

    private static func solveNewsboy(path: String, backend: SolverBackendKind) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let model = try WinQSBInventoryParser.parseNewsboy(from: expanded)
        let solver = try inventoryBackend(for: backend, command: "solve-newsboy")
        guard solver.capabilities.solves else {
            printInventoryValidationReport(
                title: model.title,
                modelType: InventoryProblemKind.newsboy.rawValue,
                source: path,
                report: solver.validationReport(for: model)
            )
            return
        }
        let solution = try solver.solve(model)
        let metadata = solver.runMetadata(for: model)

        print(model.title)
        print("distribution: \(model.demandDistribution)")
        print("backend: \(metadata.backendKind.rawValue)")
        print("algorithm: \(metadata.algorithm)")
        print("criticalRatio: \(format(solution.criticalRatio))")
        printNewsboyEvaluation("optimum", solution.optimum)
        if let knownQuantity = solution.knownQuantity {
            printNewsboyEvaluation("knownQuantity", knownQuantity)
        }
        if let desiredServiceLevelQuantity = solution.desiredServiceLevelQuantity {
            print("desiredServiceLevelQuantity: \(format(desiredServiceLevelQuantity))")
        }
    }

    private static func solveLotSizing(path: String, backend: SolverBackendKind) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let model = try WinQSBInventoryParser.parseLotSizing(from: expanded)
        let solver = try inventoryBackend(for: backend, command: "solve-lot-sizing")
        guard solver.capabilities.solves else {
            printInventoryValidationReport(
                title: model.title,
                modelType: InventoryProblemKind.lotSizing.rawValue,
                source: path,
                report: solver.validationReport(for: model)
            )
            return
        }
        let solution = try solver.solve(model)
        let metadata = solver.runMetadata(for: model)

        print(model.title)
        print("timeUnit: \(model.timeUnit)")
        print("backend: \(metadata.backendKind.rawValue)")
        print("algorithm: \(metadata.algorithm)")
        print("totalCost: \(format(solution.totalCost))")
        for decision in solution.decisions {
            print("\(decision.period): demand \(decision.demand), produce \(decision.productionQuantity), endingInventory \(decision.endingInventory), setup \(format(decision.setupCost)), variable \(format(decision.variableCost)), holding \(format(decision.holdingCost)), backorder \(format(decision.backorderCost)), cost \(format(decision.totalCost))")
        }
    }

    private static func solveStochasticInventory(path: String, backend: SolverBackendKind) throws {
        let model = try loadLegacyInventoryModel(path: path) { try WinQSBInventoryParser.parseStochasticInventory(from: $0) }
        let solver = try inventoryBackend(for: backend, command: "solve-stochastic-inventory")
        guard solver.capabilities.solves else {
            printInventoryValidationReport(title: model.title, modelType: InventoryProblemKind.stochasticReview.rawValue, source: path, report: solver.validationReport(for: model))
            return
        }
        let solution = try solver.solve(model)
        let metadata = solver.runMetadata(for: model)
        print(model.title)
        print("policy: \(model.policy.rawValue)")
        print("backend: \(metadata.backendKind.rawValue)")
        print("algorithm: \(metadata.algorithm)")
        print("exactness: \(metadata.exactness.rawValue)")
        print("orderQuantity: \(format(solution.orderQuantity))")
        if let value = solution.reorderPoint { print("reorderPoint: \(format(value))") }
        if let value = solution.orderUpToLevel { print("orderUpToLevel: \(format(value))") }
        if let value = solution.reviewInterval { print("reviewInterval: \(format(value))") }
        print("safetyStock: \(format(solution.safetyStock))")
        print("serviceLevel: \(format(solution.serviceLevel))")
        print("expectedShortagePerCycle: \(format(solution.expectedShortagePerCycle))")
        print("totalRelevantCost: \(format(solution.costs.totalRelevantCost))")
        print("totalCost: \(format(solution.costs.totalCost))")
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

    private static func validateEOQ(path: String) throws {
        let model = try loadLegacyInventoryModel(path: path) { try WinQSBInventoryParser.parseEOQ(from: $0) }
        let solver = try inventoryBackend(for: .validateOnly, command: "validate-eoq")
        printInventoryValidationReport(
            title: model.title,
            modelType: InventoryProblemKind.eoq.rawValue,
            source: path,
            report: solver.validationReport(for: model)
        )
    }

    private static func validateDiscountEOQ(path: String) throws {
        let model = try loadLegacyInventoryModel(path: path) { try WinQSBInventoryParser.parseQuantityDiscountEOQ(from: $0) }
        let solver = try inventoryBackend(for: .validateOnly, command: "validate-discount-eoq")
        printInventoryValidationReport(
            title: model.title,
            modelType: InventoryProblemKind.quantityDiscountEOQ.rawValue,
            source: path,
            report: solver.validationReport(for: model)
        )
    }

    private static func validateNewsboy(path: String) throws {
        let model = try loadLegacyInventoryModel(path: path) { try WinQSBInventoryParser.parseNewsboy(from: $0) }
        let solver = try inventoryBackend(for: .validateOnly, command: "validate-newsboy")
        printInventoryValidationReport(
            title: model.title,
            modelType: InventoryProblemKind.newsboy.rawValue,
            source: path,
            report: solver.validationReport(for: model)
        )
    }

    private static func validateLotSizing(path: String) throws {
        let model = try loadLegacyInventoryModel(path: path) { try WinQSBInventoryParser.parseLotSizing(from: $0) }
        let solver = try inventoryBackend(for: .validateOnly, command: "validate-lot-sizing")
        printInventoryValidationReport(
            title: model.title,
            modelType: InventoryProblemKind.lotSizing.rawValue,
            source: path,
            report: solver.validationReport(for: model)
        )
    }

    private static func validateStochasticInventory(path: String) throws {
        let model = try loadLegacyInventoryModel(path: path) { try WinQSBInventoryParser.parseStochasticInventory(from: $0) }
        let solver = try inventoryBackend(for: .validateOnly, command: "validate-stochastic-inventory")
        printInventoryValidationReport(title: model.title, modelType: InventoryProblemKind.stochasticReview.rawValue, source: path, report: solver.validationReport(for: model))
    }

    private static func exportInventoryJSON(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let envelope = try WinQSBInventoryParser.parseModelEnvelope(from: expanded)
        FileHandle.standardOutput.write(try InventoryModelJSON.encodeModel(envelope))
        print()
    }

    private static func solveInventoryJSON(path: String, backend: SolverBackendKind) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let envelope = try InventoryModelJSON.decodeUncheckedModel(from: data)
        let solver = try inventoryBackend(for: backend, command: "solve-inventory-json")
        guard solver.capabilities.solves else {
            let report = solver.validationReport(for: envelope)
            let document = InventoryValidationDocument(
                kind: envelope.kind,
                backend: report.backend,
                diagnostics: report.diagnostics
            )
            FileHandle.standardOutput.write(try InventoryModelJSON.encodeValidation(document))
            print()
            return
        }

        let solution = try solver.solve(envelope)
        let document = solver.solutionDocument(for: envelope, solution: solution)
        FileHandle.standardOutput.write(try InventoryModelJSON.encodeSolutionDocument(document))
        print()
    }

    private static func validateInventoryJSON(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let envelope = try InventoryModelJSON.decodeUncheckedModel(from: data)
        let solver = try inventoryBackend(for: .validateOnly, command: "validate-inventory-json")
        let report = solver.validationReport(for: envelope)
        let document = InventoryValidationDocument(
            kind: envelope.kind,
            backend: report.backend,
            diagnostics: report.diagnostics
        )
        FileHandle.standardOutput.write(try InventoryModelJSON.encodeValidation(document))
        print()
    }

    private static func loadLegacyInventoryModel<Model>(
        path: String,
        parser: (Data) throws -> Model
    ) throws -> Model {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        return try parser(expanded)
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

    private static func solveDynamicProgrammingLegacy(
        path: String,
        expectedKind: DynamicProgrammingProblemKind,
        backend: SolverBackendKind
    ) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let model = try WinQSBDynamicProgrammingParser.parseModelEnvelope(from: expanded)
        guard model.kind == expectedKind else { throw DynamicProgrammingModelError.invalidModel("expected \(expectedKind.rawValue), found \(model.kind.rawValue)") }
        let solver = try dynamicProgrammingBackend(for: backend, command: "solve-\(expectedKind.rawValue)")
        guard backend != .validateOnly else {
            printDynamicProgrammingValidation(model: model, report: solver.validationReport(for: model), source: path)
            return
        }
        let solution = try solver.solve(model)
        let metadata = solver.runMetadata(for: model)
        print(model.title)
        print("backend: \(metadata.backendKind.rawValue)")
        print("algorithm: \(metadata.algorithm)")
        switch (model, solution) {
        case (.boundedKnapsack(let problem), .boundedKnapsack(let result, _)):
            print("capacity: \(problem.capacity)")
            print("totalReturn: \(format(result.totalReturn))")
            print("capacityUsed: \(result.capacityUsed)")
            for selection in result.selections { print("\(selection.item): \(selection.quantity), capacity \(selection.capacityUsed), return \(format(selection.returnValue))") }
        case (.stagecoach, .stagecoach(let result, _)):
            print("source: \(result.source)")
            print("sink: \(result.sink)")
            print("totalCost: \(format(result.totalCost))")
            print("path: \(result.path.joined(separator: " -> "))")
        case (.productionInventory, .productionInventory(let result, _)):
            print("totalCost: \(format(result.totalCost))")
            for decision in result.decisions { print("\(decision.period): begin \(decision.beginningInventory), produce \(decision.productionQuantity), demand \(decision.demand), end \(decision.endingInventory), cost \(format(decision.cost))") }
        default: throw DynamicProgrammingModelError.invalidModel("backend returned a mismatched solution kind")
        }
    }

    private static func validateDynamicProgrammingLegacy(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let model = try WinQSBDynamicProgrammingParser.parseModelEnvelope(from: LegacyCompressedFile.expandedData(from: data))
        let solver = try dynamicProgrammingBackend(for: .validateOnly, command: "validate-dp")
        printDynamicProgrammingValidation(model: model, report: solver.validationReport(for: model), source: path)
    }

    private static func exportDynamicProgrammingJSON(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let model = try WinQSBDynamicProgrammingParser.parseModelEnvelope(from: LegacyCompressedFile.expandedData(from: data))
        FileHandle.standardOutput.write(try DynamicProgrammingModelJSON.encodeModel(model)); print()
    }

    private static func solveDynamicProgrammingJSON(path: String, backend: SolverBackendKind) throws {
        let model = try DynamicProgrammingModelJSON.decodeUncheckedModel(from: Data(contentsOf: URL(fileURLWithPath: path)))
        let solver = try dynamicProgrammingBackend(for: backend, command: "solve-dp-json")
        if backend == .validateOnly {
            FileHandle.standardOutput.write(try DynamicProgrammingModelJSON.encodeValidation(DynamicProgrammingModelJSON.validationDocument(for: model))); print()
        } else {
            let solution = try solver.solve(model)
            FileHandle.standardOutput.write(try DynamicProgrammingModelJSON.encodeSolutionDocument(solver.solutionDocument(for: model, solution: solution))); print()
        }
    }

    private static func validateDynamicProgrammingJSON(path: String) throws {
        let model = try DynamicProgrammingModelJSON.decodeUncheckedModel(from: Data(contentsOf: URL(fileURLWithPath: path)))
        FileHandle.standardOutput.write(try DynamicProgrammingModelJSON.encodeValidation(DynamicProgrammingModelJSON.validationDocument(for: model))); print()
    }

    private static func printDynamicProgrammingValidation(model: DynamicProgrammingModelEnvelope, report: ValidationReport, source: String) {
        let errors = report.diagnostics.filter { $0.severity == .error }
        let warnings = report.diagnostics.filter { $0.severity == .warning }
        print(model.title); print("backend: \(report.backend.rawValue)"); print("source: \(source)"); print("modelType: \(model.kind.rawValue)")
        print("status: \(errors.isEmpty ? "valid" : "invalid")"); print("errors: \(errors.count)"); print("warnings: \(warnings.count)")
        for diagnostic in report.diagnostics { print("\(diagnostic.severity.rawValue): \(diagnostic.code)\(diagnostic.path.map { " [\($0)]" } ?? "") - \(diagnostic.message)") }
    }

    private static func solveDecisionAnalysisLegacy(path: String, expectedKind: DecisionAnalysisProblemKind, backend: SolverBackendKind) throws {
        let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: URL(fileURLWithPath: path)))
        let model = try WinQSBDecisionAnalysisParser.parseModelEnvelope(from: expanded)
        guard model.kind == expectedKind else { throw CLIError.usage("Expected \(expectedKind.rawValue), found \(model.kind.rawValue)") }
        guard let solver = DecisionAnalysisBackends.backend(for: backend) else { throw CLIError.usage("external backend is not available yet for decision analysis") }
        guard solver.capabilities.solves else { printDecisionAnalysisValidation(model: model, report: solver.validationReport(for: model), source: path); return }
        let solution = try solver.solve(model)
        printDecisionAnalysisSolution(model: model, solution: solution, backend: backend)
    }

    private static func validateDecisionAnalysisLegacy(path: String) throws {
        let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: URL(fileURLWithPath: path)))
        let model = try WinQSBDecisionAnalysisParser.parseModelEnvelope(from: expanded)
        let solver = ValidateOnlyDecisionAnalysisBackend()
        printDecisionAnalysisValidation(model: model, report: solver.validationReport(for: model), source: path)
    }

    private static func exportDecisionAnalysisJSON(path: String) throws {
        let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: URL(fileURLWithPath: path)))
        FileHandle.standardOutput.write(try DecisionAnalysisModelJSON.encodeModel(WinQSBDecisionAnalysisParser.parseModelEnvelope(from: expanded))); print()
    }

    private static func solveDecisionAnalysisJSON(path: String, backend: SolverBackendKind) throws {
        let model = try DecisionAnalysisModelJSON.decodeModel(from: Data(contentsOf: URL(fileURLWithPath: path)))
        guard let solver = DecisionAnalysisBackends.backend(for: backend) else { throw CLIError.usage("external backend is not available yet for solve-decision-json") }
        if solver.capabilities.solves {
            let solution = try solver.solve(model)
            FileHandle.standardOutput.write(try DecisionAnalysisModelJSON.encodeSolutionDocument(solver.solutionDocument(for: model, solution: solution))); print()
        } else {
            let report = solver.validationReport(for: model)
            let document = DecisionAnalysisValidationDocument(kind: model.kind, backend: report.backend, diagnostics: report.diagnostics)
            FileHandle.standardOutput.write(try DecisionAnalysisModelJSON.encodeValidation(document)); print()
        }
    }

    private static func validateDecisionAnalysisJSON(path: String) throws {
        let model = try DecisionAnalysisModelJSON.decodeModel(from: Data(contentsOf: URL(fileURLWithPath: path)))
        let report = ValidateOnlyDecisionAnalysisBackend().validationReport(for: model)
        FileHandle.standardOutput.write(try DecisionAnalysisModelJSON.encodeValidation(DecisionAnalysisValidationDocument(kind: model.kind, backend: report.backend, diagnostics: report.diagnostics))); print()
    }

    private static func printDecisionAnalysisSolution(model: DecisionAnalysisModelEnvelope, solution: DecisionAnalysisSolutionEnvelope, backend: SolverBackendKind) {
        print(model.title)
        print("backend: \(backend.rawValue)")
        switch solution {
        case .payoff(let value):
            print("bestPriorDecision: \(value.bestPriorDecision)"); print("bestPriorExpectedValue: \(format(value.bestPriorExpectedValue))")
            for item in value.priorExpectedValues { print("\(item.decision): \(format(item.expectedValue))") }
            print("expectedValueWithSampleInformation: \(format(value.expectedValueWithSampleInformation))"); print("expectedValueOfSampleInformation: \(format(value.expectedValueOfSampleInformation))")
            print("expectedValueWithPerfectInformation: \(format(value.expectedValueWithPerfectInformation))"); print("expectedValueOfPerfectInformation: \(format(value.expectedValueOfPerfectInformation))")
            for item in value.indicatorAnalyses { print("\(item.indicator): probability \(format(item.probability)), best \(item.bestDecision), value \(format(item.bestExpectedValue))") }
        case .bayesian(let value):
            guard case .bayesian(let problem) = model else { return }
            for outcome in value.outcomes { print("\(outcome.outcome): probability \(format(outcome.probability))"); for index in problem.states.indices { print("  \(problem.states[index]): \(format(outcome.posteriorProbabilities[index]))") } }
        case .decisionTree(let value):
            guard case .decisionTree(let tree) = model else { return }
            print("root: \(tree.rootID)"); print("expectedValue: \(format(value.expectedValue))")
            for item in value.policy { print("\(item.nodeName): choose \(item.selectedChildName), value \(format(item.expectedValue))") }
        case .zeroSumGame(let value):
            print("value: \(format(value.value))"); print("rowStrategy:"); for item in value.rowStrategy { print("\(item.strategy): \(format(item.probability))") }; print("columnStrategy:"); for item in value.columnStrategy { print("\(item.strategy): \(format(item.probability))") }
        }
    }

    private static func printDecisionAnalysisValidation(model: DecisionAnalysisModelEnvelope, report: ValidationReport, source: String) {
        let errors = report.diagnostics.filter { $0.severity == .error }; let warnings = report.diagnostics.filter { $0.severity == .warning }
        print(model.title); print("backend: \(report.backend.rawValue)"); print("source: \(source)"); print("modelType: \(model.kind.rawValue)"); print("status: \(errors.isEmpty ? "valid" : "invalid")"); print("errors: \(errors.count)"); print("warnings: \(warnings.count)")
        for item in report.diagnostics { print("\(item.severity.rawValue): \(item.code)\(item.path.map { " [\($0)]" } ?? "") - \(item.message)") }
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

    private static func solveNetworkLegacy(path: String, expectedKind: NetworkProblemKind, backend: SolverBackendKind) throws {
        let model = try readLegacyNetworkModel(path: path)
        guard model.kind == expectedKind else { throw CLIError.usage("Expected \(expectedKind.rawValue), found \(model.kind.rawValue)") }
        guard let solver = NetworkBackends.backend(for: backend) else { throw CLIError.usage("external backend is not available yet for network models") }
        guard solver.capabilities.solves else { printNetworkValidation(model: model, report: solver.validationReport(for: model), source: path); return }
        printNetworkSolution(model: model, solution: try solver.solve(model), metadata: solver.runMetadata(for: model))
    }

    private static func validateNetworkLegacy(path: String) throws {
        let model = try readLegacyNetworkModel(path: path)
        printNetworkValidation(model: model, report: ValidateOnlyNetworkBackend().validationReport(for: model), source: path)
    }

    private static func printNetworkSolution(model: NetworkModelEnvelope, solution: NetworkSolutionEnvelope, metadata: SolverRunMetadata) {
        print(model.title); print("backend: \(metadata.backendKind.rawValue)"); print("algorithm: \(metadata.algorithm)"); print("exactness: \(metadata.exactness.rawValue)")
        switch solution {
        case .minimumCostFlow(let value): print("totalCost: \(format(value.totalCost))"); for item in value.arcFlows { print("\(item.from) -> \(item.to): \(format(item.quantity)) @ \(format(item.unitCost))") }; for item in value.balanceAdjustments { print("\(item.kind) -> \(item.node): \(format(item.quantity))") }
        case .shortestPath(let value): print("source: \(value.source)"); print("sink: \(value.sink)"); print("totalCost: \(format(value.totalCost))"); print("path: \(value.path.joined(separator: " -> "))")
        case .minimumSpanningTree(let value): print("totalCost: \(format(value.totalCost))"); for edge in value.edges { print("\(edge.from) -- \(edge.to): \(format(edge.cost))") }
        case .maxFlow(let value): print("source: \(value.source)"); print("sink: \(value.sink)"); print("maxFlow: \(format(value.maxFlow))"); for arc in value.arcFlows { print("\(arc.from) -> \(arc.to): \(format(arc.flow))") }
        case .travelingSalesperson(let value): print("source: \(value.source)"); print("totalCost: \(format(value.totalCost))"); print("tour: \(value.tour.joined(separator: " -> "))")
        case .assignment(let value): print("totalCost: \(format(value.totalCost))"); for item in value.assignments { print("\(item.worker) -> \(item.task): \(format(item.cost))") }
        case .transportation(let value): print("totalCost: \(format(value.totalCost))"); for item in value.shipments { print("\(item.origin) -> \(item.destination): \(format(item.quantity)) @ \(format(item.unitCost))") }
        }
    }

    private static func printNetworkValidation(model: NetworkModelEnvelope, report: ValidationReport, source: String) {
        let errors = report.diagnostics.filter { $0.severity == .error }; let warnings = report.diagnostics.filter { $0.severity == .warning }
        print(model.title); print("backend: \(report.backend.rawValue)"); print("source: \(source)"); print("modelType: \(model.kind.rawValue)"); print("status: \(errors.isEmpty ? "valid" : "invalid")"); print("errors: \(errors.count)"); print("warnings: \(warnings.count)")
        for item in report.diagnostics { print("\(item.severity.rawValue): \(item.code)\(item.path.map { " [\($0)]" } ?? "") - \(item.message)") }
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
        case .minimumCostFlow(let problem):
            return .minimumCostFlow(try MinimumCostNetworkFlowSolver.solve(problem))
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

    private static func printInventoryValidationReport(
        title: String,
        modelType: String,
        source: String,
        report: ValidationReport
    ) {
        let errors = report.diagnostics.filter { $0.severity == .error }
        let warnings = report.diagnostics.filter { $0.severity == .warning }

        print(title)
        print("backend: \(report.backend.rawValue)")
        print("source: \(source)")
        print("modelType: \(modelType)")
        print("status: \(errors.isEmpty ? "valid" : "invalid")")
        print("errors: \(errors.count)")
        print("warnings: \(warnings.count)")
        for diagnostic in report.diagnostics {
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
        qsb expand <legacy-file>
        qsb import-legacy-json <legacy-model-file>
        qsb inventory-fixtures <reference-directory>
        qsb solve-lp <legacy-lp-file> [--backend native|validate]
        qsb solve-ilp <legacy-lp-file> [--backend native|validate]
        qsb validate-lp <legacy-lp-file>
        qsb export-json <legacy-lp-file>
        qsb solve-json <model-json-file> [--backend native|validate]
        qsb solve-json-ilp <model-json-file> [--backend native|validate]
        qsb validate-json <model-json-file>
        qsb export-network-json <legacy-network-file>
        qsb solve-network-json <network-model-json-file> [--backend native|validate]
        qsb validate-network-json <network-model-json-file>
        qsb solve-timeseries <legacy-fc-time-series-file> [periods-ahead]
        qsb solve-moving-average <legacy-fc-time-series-file> <window-size> [periods-ahead]
        qsb solve-exp-smoothing <legacy-fc-time-series-file> <alpha> [periods-ahead]
        qsb solve-seasonal <legacy-fc-time-series-file> <season-length> [periods-ahead]
        qsb solve-regression <legacy-fc-regression-file>
        qsb export-forecast-json <legacy-fc-file> <trend|moving-average|exp-smoothing|seasonal|regression> [parameter] [periods-ahead]
        qsb solve-forecast-json <forecasting-request-json-file> [--backend native|validate]
        qsb validate-forecast-json <forecasting-request-json-file>
        qsb solve-eoq <legacy-its-eoq-file> [--backend native|validate]
        qsb solve-discount-eoq <legacy-its-discount-eoq-file> [--backend native|validate]
        qsb solve-newsboy <legacy-its-newsboy-file> [--backend native|validate]
        qsb solve-lot-sizing <legacy-its-lot-sizing-file> [--backend native|validate]
        qsb validate-eoq <legacy-its-eoq-file>
        qsb validate-discount-eoq <legacy-its-discount-eoq-file>
        qsb validate-newsboy <legacy-its-newsboy-file>
        qsb validate-lot-sizing <legacy-its-lot-sizing-file>
        qsb solve-stochastic-inventory <legacy-its-stochastic-review-file> [--backend native|validate]
        qsb validate-stochastic-inventory <legacy-its-stochastic-review-file>
        qsb export-inventory-json <legacy-its-inventory-file>
        qsb solve-inventory-json <inventory-model-json-file> [--backend native|validate]
        qsb validate-inventory-json <inventory-model-json-file>
        qsb solve-flowshop <legacy-sch-flow-shop-file> [--backend native|validate]
        qsb solve-flowshop-json <legacy-sch-flow-shop-file> [--backend native|validate]
        qsb solve-jobshop <legacy-sch-job-shop-file> [--backend native|validate]
        qsb solve-jobshop-json <legacy-sch-job-shop-file> [--backend native|validate]
        qsb validate-flowshop <legacy-sch-flow-shop-file>
        qsb validate-jobshop <legacy-sch-job-shop-file>
        qsb export-scheduling-json <legacy-scheduling-file>
        qsb solve-scheduling-json <scheduling-model-json-file> [--backend native|validate]
        qsb validate-scheduling-json <scheduling-model-json-file>
        qsb solve-cpm <legacy-cpm-file> [--backend native|validate]
        qsb validate-cpm <legacy-cpm-file>
        qsb solve-pert <legacy-pert-file> [--backend native|validate]
        qsb validate-pert <legacy-pert-file>
        qsb export-project-json <legacy-pert-cpm-file>
        qsb solve-project-json <project-model-json-file> [--backend native|validate]
        qsb validate-project-json <project-model-json-file>
        qsb solve-markov <legacy-markov-file> [--backend native|validate]
        qsb validate-markov <legacy-markov-file>
        qsb export-markov-json <legacy-markov-file>
        qsb solve-markov-json <markov-request-json-file> [--backend native|validate]
        qsb validate-markov-json <markov-request-json-file>
        qsb solve-goal <legacy-goal-programming-file> [--backend native|validate]
        qsb validate-goal <legacy-goal-programming-file>
        qsb export-goal-json <legacy-goal-programming-file>
        qsb solve-goal-json <goal-programming-model-json-file> [--backend native|validate]
        qsb validate-goal-json <goal-programming-model-json-file>
        qsb solve-acceptance <legacy-acceptance-sampling-file> [--backend native|validate]
        qsb validate-acceptance <legacy-acceptance-sampling-file>
        qsb export-acceptance-json <legacy-acceptance-sampling-file>
        qsb solve-acceptance-json <acceptance-sampling-model-json-file> [--backend native|validate]
        qsb validate-acceptance-json <acceptance-sampling-model-json-file>
        qsb solve-quality <legacy-quality-control-file> [--backend native|validate]
        qsb validate-quality <legacy-quality-control-file>
        qsb export-quality-json <legacy-quality-control-file>
        qsb solve-quality-json <quality-control-model-json-file> [--backend native|validate]
        qsb validate-quality-json <quality-control-model-json-file>
        qsb solve-aggregate <legacy-aggregate-planning-file> [--backend native|validate]
        qsb validate-aggregate <legacy-aggregate-planning-file>
        qsb export-aggregate-json <legacy-aggregate-planning-file>
        qsb solve-aggregate-json <aggregate-planning-model-json-file> [--backend native|validate]
        qsb validate-aggregate-json <aggregate-planning-model-json-file>
        qsb solve-mrp <legacy-mrp-file> [--backend native|validate]
        qsb validate-mrp <legacy-mrp-file>
        qsb export-mrp-json <legacy-mrp-file>
        qsb solve-mrp-json <mrp-model-json-file> [--backend native|validate]
        qsb validate-mrp-json <mrp-model-json-file>
        qsb solve-qp <legacy-quadratic-programming-file> [--backend native|validate]
        qsb validate-qp <legacy-quadratic-programming-file>
        qsb export-qp-json <legacy-quadratic-programming-file>
        qsb solve-qp-json <quadratic-programming-model-json-file> [--backend native|validate]
        qsb validate-qp-json <quadratic-programming-model-json-file>
        qsb solve-nlp <legacy-nonlinear-programming-file> [--backend native|validate]
        qsb validate-nlp <legacy-nonlinear-programming-file>
        qsb export-nlp-json <legacy-nonlinear-programming-file>
        qsb solve-nlp-json <nonlinear-programming-model-json-file> [--backend native|validate]
        qsb validate-nlp-json <nonlinear-programming-model-json-file>
        qsb solve-simulation <legacy-simulation-file> [--backend native|validate]
        qsb validate-simulation <legacy-simulation-file>
        qsb export-simulation-json <legacy-simulation-file>
        qsb solve-simulation-json <simulation-model-json-file> [--backend native|validate]
        qsb validate-simulation-json <simulation-model-json-file>
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
        qsb solve-knapsack <legacy-dp-knapsack-file> [--backend native|validate]
        qsb solve-stagecoach <legacy-dp-stagecoach-file> [--backend native|validate]
        qsb solve-prod-inventory <legacy-dp-production-inventory-file> [--backend native|validate]
        qsb validate-knapsack <legacy-dp-knapsack-file>
        qsb validate-stagecoach <legacy-dp-stagecoach-file>
        qsb validate-prod-inventory <legacy-dp-production-inventory-file>
        qsb export-dp-json <legacy-dp-file>
        qsb solve-dp-json <dynamic-programming-model-json-file> [--backend native|validate]
        qsb validate-dp-json <dynamic-programming-model-json-file>
        qsb solve-payoff <legacy-da-payoff-file> [--backend native|validate]
        qsb validate-payoff <legacy-da-payoff-file>
        qsb solve-bayesian <legacy-da-bayesian-file> [--backend native|validate]
        qsb validate-bayesian <legacy-da-bayesian-file>
        qsb solve-decision-tree <legacy-da-decision-tree-file> [--backend native|validate]
        qsb validate-decision-tree <legacy-da-decision-tree-file>
        qsb solve-game <legacy-da-zero-sum-game-file> [--backend native|validate]
        qsb validate-game <legacy-da-zero-sum-game-file>
        qsb export-decision-json <legacy-da-file>
        qsb solve-decision-json <decision-analysis-model-json-file> [--backend native|validate]
        qsb validate-decision-json <decision-analysis-model-json-file>
        qsb solve-mm1 <legacy-qa-mm1-file> [--backend native|validate]
        qsb solve-mm1-json <legacy-qa-mm1-file> [--backend native|validate]
        qsb validate-mm1 <legacy-qa-mm1-file>
        qsb solve-finite-queue <legacy-qa-finite-capacity-file> [--backend native|validate]
        qsb solve-finite-queue-json <legacy-qa-finite-capacity-file> [--backend native|validate]
        qsb validate-finite-queue <legacy-qa-finite-capacity-file>
        qsb export-queuing-json <legacy-queuing-file>
        qsb solve-queuing-json <queuing-model-json-file> [--backend native|validate]
        qsb validate-queuing-json <queuing-model-json-file>
        qsb solve-spp <legacy-network-file> [--backend native|validate]
        qsb validate-spp <legacy-network-file>
        qsb solve-netflow <legacy-network-file> [--backend native|validate]
        qsb validate-netflow <legacy-network-file>
        qsb solve-mst <legacy-network-file> [--backend native|validate]
        qsb validate-mst <legacy-network-file>
        qsb solve-maxflow <legacy-network-file> [--backend native|validate]
        qsb validate-maxflow <legacy-network-file>
        qsb solve-tsp <legacy-network-file> [--backend native|validate]
        qsb validate-tsp <legacy-network-file>
        qsb solve-assignment <legacy-network-file> [--backend native|validate]
        qsb validate-assignment <legacy-network-file>
        qsb solve-transport <legacy-network-file> [--backend native|validate]
        qsb validate-transport <legacy-network-file>
        """, to: handle)
    }

}

enum CLIError: Error {
    case usage(String?)
}

QSBCLI.main()
