import SwiftUI
import QSBCore

enum WorkspacePane: String, CaseIterable, Identifiable {
    case model
    case solution

    var id: String { rawValue }

    var title: String {
        switch self {
        case .model:
            "Model"
        case .solution:
            "Solution"
        }
    }

    var systemImage: String {
        switch self {
        case .model:
            "doc.text"
        case .solution:
            "function"
        }
    }
}

enum SolveMode {
    case relaxation
    case integer

    var label: String {
        switch self {
        case .relaxation:
            "LP Relaxation"
        case .integer:
            "ILP"
        }
    }
}

enum WorkspaceModelFamily {
    case linearProgramming
    case network
    case facilities(FacilitiesProblemKind)
    case inventory(InventoryProblemKind)
    case dynamicProgramming(DynamicProgrammingProblemKind)
    case forecasting(ForecastingMethod)
    case decisionAnalysis(DecisionAnalysisProblemKind)
    case simulation(SimulationRepresentation)
    case quadraticProgramming
    case nonlinearProgramming
    case markov
    case goalProgramming
    case projectScheduling(ProjectSchedulingProblemKind)
    case acceptanceSampling(AcceptanceSamplingPlanKind)
    case qualityControl(QualityControlProblemKind)
    case aggregatePlanning
    case materialRequirementsPlanning
    case scheduling(SchedulingProblemKind)
    case queuing(QueuingProblemKind)
    case unknown

    var editorSubtitle: String {
        switch self {
        case .linearProgramming:
            "Normalized LP/ILP JSON"
        case .network:
            "Normalized network JSON"
        case .facilities(let kind):
            "Normalized facilities JSON · \(kind.displayName)"
        case .inventory(let kind):
            "Normalized inventory JSON · \(kind.displayName)"
        case .dynamicProgramming(let kind):
            "Normalized dynamic programming JSON · \(kind.displayName)"
        case .forecasting(let method):
            "Normalized forecasting request · \(method.displayName)"
        case .decisionAnalysis(let kind):
            "Normalized decision analysis JSON · \(kind.displayName)"
        case .simulation(let representation):
            "Normalized simulation JSON · \(representation.rawValue.capitalized)"
        case .quadraticProgramming:
            "Normalized quadratic programming JSON"
        case .nonlinearProgramming:
            "Normalized nonlinear programming JSON"
        case .markov:
            "Normalized Markov analysis JSON"
        case .goalProgramming:
            "Normalized goal programming JSON"
        case .projectScheduling(let kind):
            "Normalized project scheduling JSON · \(kind.rawValue)"
        case .acceptanceSampling(let kind):
            "Normalized acceptance sampling JSON · \(kind.rawValue.capitalized)"
        case .qualityControl(let kind):
            "Normalized quality control JSON · \(kind.rawValue)"
        case .aggregatePlanning:
            "Normalized aggregate planning JSON"
        case .materialRequirementsPlanning:
            "Normalized material requirements planning JSON"
        case .scheduling(let kind):
            "Normalized scheduling JSON · \(kind.rawValue)"
        case .queuing(let kind):
            "Normalized queuing JSON · \(kind.rawValue)"
        case .unknown:
            "Normalized model JSON"
        }
    }

}

extension InventoryProblemKind {
    var displayName: String {
        switch self {
        case .eoq: "EOQ"
        case .quantityDiscountEOQ: "Quantity Discount EOQ"
        case .newsboy: "Newsvendor"
        case .lotSizing: "Lot Sizing"
        case .stochasticReview: "Stochastic Review"
        }
    }
}

extension DynamicProgrammingProblemKind {
    var displayName: String {
        switch self {
        case .boundedKnapsack: "Bounded Knapsack"
        case .stagecoach: "Stagecoach"
        case .productionInventory: "Production / Inventory"
        }
    }
}

extension ForecastingMethod {
    var displayName: String {
        switch self {
        case .linearTrend: "Linear Trend"
        case .movingAverage: "Moving Average"
        case .exponentialSmoothing: "Exponential Smoothing"
        case .multiplicativeSeasonalDecomposition: "Seasonal Decomposition"
        case .ordinaryLeastSquares: "Ordinary Least Squares"
        }
    }
}

extension DecisionAnalysisProblemKind {
    var displayName: String {
        switch self {
        case .payoff: "Payoff Analysis"
        case .bayesian: "Bayesian Analysis"
        case .decisionTree: "Decision Tree"
        case .zeroSumGame: "Zero-Sum Game"
        }
    }
}

private extension FacilitiesProblemKind {
    var displayName: String {
        switch self {
        case .lineBalancing:
            "Line Balancing"
        case .location:
            "Facility Location"
        case .layout:
            "Facility Layout"
        }
    }
}

enum SampleModel {
    case linearProgram
    case integerProgram
    case travelingSalesperson
    case facilityLayout
    case economicOrderQuantity
    case boundedKnapsack
    case linearTrendForecast
    case payoffAnalysis
    case decisionTree
    case simulation
    case quadraticProgramming
    case nonlinearProgramming
    case markov
    case goalProgramming
}
