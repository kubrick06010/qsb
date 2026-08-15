import SwiftUI
import QSBCore

enum WorkspacePane: String, CaseIterable, Identifiable {
    case overview
    case model
    case validation
    case run
    case solution
    case json
    case runDetails

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            "Overview"
        case .model:
            "Definition"
        case .validation:
            "Validation"
        case .run:
            "Run"
        case .solution:
            "Summary"
        case .json:
            "JSON"
        case .runDetails:
            "Run Details"
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            "rectangle.grid.1x2"
        case .model:
            "doc.text"
        case .validation:
            "checkmark.seal"
        case .run:
            "play.circle"
        case .solution:
            "function"
        case .json:
            "curlybraces"
        case .runDetails:
            "info.circle"
        }
    }
}

enum ModelLifecycleState: String, CaseIterable, Sendable {
    case empty = "Empty"
    case editing = "Editing"
    case validating = "Validating"
    case invalid = "Invalid"
    case valid = "Valid"
}

enum RunLifecycleState: String, CaseIterable, Sendable {
    case notRun = "Not run"
    case validating = "Validating"
    case solving = "Solving"
    case solved = "Solved"
    case failed = "Failed"
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

    var displayName: String {
        switch self {
        case .linearProgramming: "Linear / Integer Programming"
        case .network: "Network"
        case .facilities(let kind): kind.displayName
        case .inventory(let kind): kind.displayName
        case .dynamicProgramming(let kind): kind.displayName
        case .forecasting(let method): method.displayName
        case .decisionAnalysis(let kind): kind.displayName
        case .simulation: "Simulation"
        case .quadraticProgramming: "Quadratic Programming"
        case .nonlinearProgramming: "Nonlinear Programming"
        case .markov: "Markov Analysis"
        case .goalProgramming: "Goal Programming"
        case .projectScheduling(let kind): kind.rawValue
        case .acceptanceSampling(let kind): kind.rawValue.capitalized
        case .qualityControl(let kind): kind.rawValue
        case .aggregatePlanning: "Aggregate Planning"
        case .materialRequirementsPlanning: "Material Requirements Planning"
        case .scheduling(let kind): kind.rawValue
        case .queuing(let kind): kind.rawValue
        case .unknown: "No model"
        }
    }

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

    var label: String {
        switch self {
        case .linearProgram: "Linear Programming"
        case .integerProgram: "Integer Programming"
        case .travelingSalesperson: "Traveling Salesperson"
        case .facilityLayout: "Facility Layout"
        case .economicOrderQuantity: "Economic Order Quantity"
        case .boundedKnapsack: "Bounded Knapsack"
        case .linearTrendForecast: "Linear Trend Forecast"
        case .payoffAnalysis: "Payoff Analysis"
        case .decisionTree: "Decision Tree"
        case .simulation: "Simulation"
        case .quadraticProgramming: "Quadratic Programming"
        case .nonlinearProgramming: "Nonlinear Programming"
        case .markov: "Markov Analysis"
        case .goalProgramming: "Goal Programming"
        }
    }
}
