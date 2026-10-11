import QSBCore

extension SolverRunMetadata {
    var backendDisplayName: String {
        switch backendKind {
        case .nativeEducational: "QSB Native"
        case .validateOnly: "Validate only"
        case .externalHighPerformance: "External solver"
        }
    }

    var exactnessDisplayName: String {
        switch exactness {
        case .exact: "Exact"
        case .closedForm: "Closed form"
        case .fixtureScale: "Limited scale"
        case .heuristic: "Heuristic"
        case .approximate: "Approximate"
        }
    }

    // Explicit names preserve mathematical meaning; identifiers remain in JSON.
    var algorithmDisplayName: String {
        switch algorithm {
        case "validationOnly": "Validation only"
        case "activeSetKKTEnumeration": "Active-set KKT enumeration"
        case "diagonalIntegerQuadraticEnumeration": "Separable integer quadratic enumeration"
        case "highsQuadraticProgramming": "HiGHS quadratic optimization"
        case "automaticDifferentiationMultistartPenalty": "Multistart optimization with constraint penalties"
        case "lexicographicContinuousLinearProgramming": "Lexicographic linear optimization"
        case "lexicographicIntegerLinearProgramming": "Lexicographic integer optimization"
        case "hiGHSLexicographicLP": "HiGHS lexicographic linear optimization"
        case "hiGHSLexicographicMIP": "HiGHS lexicographic mixed-integer optimization"
        case "boundedKnapsackDynamicProgramming": "Bounded knapsack dynamic programming"
        case "orderedAcyclicShortestPathDynamicProgramming": "Acyclic shortest-path dynamic programming"
        case "finiteHorizonProductionInventoryDynamicProgramming": "Production and inventory dynamic programming"
        case "continuousAggregatePlanningLP": "Continuous linear planning"
        case "hiGHSAggregatePlanningLP": "HiGHS linear planning"
        case "multiLevelMRPExplosion": "Multilevel material requirements planning"
        case "criticalPathMethod": "Critical path method"
        case "pertExpectedTimeCriticalPath": "PERT expected-time critical path"
        case "initialLayoutEvaluation": "Initial layout evaluation"
        case "pairwiseSameSizeSwapLocalSearch": "Local search with equal-size department swaps"
        case "weightedMedian": "Weighted median"
        case "weightedCentroid": "Weighted centroid"
        case "weiszfeldIteration": "Weiszfeld location search"
        case "bitmaskDynamicProgramming": "Station assignment dynamic programming"
        case "binomialSingleSamplingEvaluation": "Binomial single-sample evaluation"
        case "binomialDoubleSamplingEvaluation": "Binomial double-sample evaluation"
        case "threeSigmaCChart": "Three-sigma c chart"
        case "threeSigmaPChart": "Three-sigma p chart"
        case "xbarRControlChart": "X-bar and R control charts"
        case "descendingParetoAggregation": "Pareto count aggregation"
        case "normalScoreLeastSquares": "Normal-score least-squares fit"
        case "seededDiscreteEventSimulation": "Reproducible discrete-event simulation"
        default: "Custom algorithm"
        }
    }
}
