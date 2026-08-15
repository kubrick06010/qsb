import Foundation

public struct LineBalancingTask: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let time: Int
    public let isolated: Bool
    public let successorIDs: [Int]

    public init(id: Int, name: String, time: Int, isolated: Bool, successorIDs: [Int]) {
        self.id = id
        self.name = name
        self.time = time
        self.isolated = isolated
        self.successorIDs = successorIDs
    }
}

public struct LineBalancingProblem: Codable, Equatable, Sendable {
    public let title: String
    public let timeUnit: String
    public let cycleTime: Int
    public let tasks: [LineBalancingTask]

    public init(title: String, timeUnit: String, cycleTime: Int, tasks: [LineBalancingTask]) {
        self.title = title
        self.timeUnit = timeUnit
        self.cycleTime = cycleTime
        self.tasks = tasks
    }
}

public struct LineBalancingStation: Codable, Equatable, Sendable {
    public let index: Int
    public let taskIDs: [Int]
    public let taskNames: [String]
    public let workload: Int
    public let idleTime: Int
}

public struct LineBalancingSolution: Codable, Equatable, Sendable {
    public let stationCount: Int
    public let totalTaskTime: Int
    public let cycleTime: Int
    public let efficiency: Double
    public let balanceDelay: Double
    public let stations: [LineBalancingStation]
}

public enum FacilityLocationDistanceMeasure: String, Codable, Equatable, Sendable {
    case rectilinear
    case squaredEuclidean
    case euclidean
}

public struct FacilityLocationFacility: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let isNew: Bool
    public let x: Double?
    public let y: Double?
    public let interactionCosts: [Double?]

    public init(id: Int, name: String, isNew: Bool, x: Double?, y: Double?, interactionCosts: [Double?]) {
        self.id = id
        self.name = name
        self.isNew = isNew
        self.x = x
        self.y = y
        self.interactionCosts = interactionCosts
    }
}

public struct FacilityLocationProblem: Codable, Equatable, Sendable {
    public let title: String
    public let distanceMeasure: FacilityLocationDistanceMeasure
    public let objective: String
    public let facilities: [FacilityLocationFacility]

    public init(title: String, distanceMeasure: FacilityLocationDistanceMeasure, objective: String, facilities: [FacilityLocationFacility]) {
        self.title = title
        self.distanceMeasure = distanceMeasure
        self.objective = objective
        self.facilities = facilities
    }

    public var existingFacilities: [FacilityLocationFacility] { facilities.filter { !$0.isNew } }
    public var newFacilities: [FacilityLocationFacility] { facilities.filter(\.isNew) }
}

public struct FacilityLocationInteraction: Codable, Equatable, Sendable {
    public let existingFacilityID: Int
    public let existingFacilityName: String
    public let weight: Double
    public let distance: Double
    public let weightedDistance: Double
}

public struct FacilityLocationPlacement: Codable, Equatable, Sendable {
    public let facilityID: Int
    public let facilityName: String
    public let x: Double
    public let y: Double
    public let weightedDistance: Double
    public let interactions: [FacilityLocationInteraction]
}

public struct FacilityLocationSolution: Codable, Equatable, Sendable {
    public let distanceMeasure: FacilityLocationDistanceMeasure
    public let objectiveValue: Double
    public let placements: [FacilityLocationPlacement]
}

public struct FacilityLayoutRect: Codable, Equatable, Sendable {
    public let startRow: Int
    public let startColumn: Int
    public let endRow: Int
    public let endColumn: Int

    public init(startRow: Int, startColumn: Int, endRow: Int, endColumn: Int) {
        self.startRow = startRow
        self.startColumn = startColumn
        self.endRow = endRow
        self.endColumn = endColumn
    }

    public var cellCount: Int { max(0, endRow - startRow + 1) * max(0, endColumn - startColumn + 1) }
}

public struct FacilityLayoutDepartment: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let fixed: Bool
    public let flowUnitCosts: [Double?]
    public let initialLayout: [FacilityLayoutRect]

    public init(id: Int, name: String, fixed: Bool, flowUnitCosts: [Double?], initialLayout: [FacilityLayoutRect]) {
        self.id = id
        self.name = name
        self.fixed = fixed
        self.flowUnitCosts = flowUnitCosts
        self.initialLayout = initialLayout
    }
}

public struct FacilityLayoutProblem: Codable, Equatable, Sendable {
    public let title: String
    public let rowCount: Int
    public let columnCount: Int
    public let objective: String
    public let departments: [FacilityLayoutDepartment]

    public init(title: String, rowCount: Int, columnCount: Int, objective: String, departments: [FacilityLayoutDepartment]) {
        self.title = title
        self.rowCount = rowCount
        self.columnCount = columnCount
        self.objective = objective
        self.departments = departments
    }

    public var fixedDepartments: [FacilityLayoutDepartment] { departments.filter(\.fixed) }
}

public enum FacilityLayoutSolvingStrategy: String, Codable, Sendable {
    case initial
    case pairwiseSwap
}

public struct FacilityLayoutPlacement: Codable, Equatable, Sendable {
    public let departmentID: Int
    public let departmentName: String
    public let fixed: Bool
    public let rectangles: [FacilityLayoutRect]
    public let cellCount: Int
    public let centroidRow: Double
    public let centroidColumn: Double
}

public struct FacilityLayoutInteraction: Codable, Equatable, Sendable {
    public let fromDepartmentID: Int
    public let fromDepartmentName: String
    public let toDepartmentID: Int
    public let toDepartmentName: String
    public let weight: Double
    public let distance: Double
    public let weightedDistance: Double
}

public struct FacilityLayoutMove: Codable, Equatable, Sendable {
    public let kind: String
    public let firstDepartmentID: Int
    public let firstDepartmentName: String
    public let secondDepartmentID: Int
    public let secondDepartmentName: String
    public let firstBeforeRectangles: [FacilityLayoutRect]
    public let firstAfterRectangles: [FacilityLayoutRect]
    public let secondBeforeRectangles: [FacilityLayoutRect]
    public let secondAfterRectangles: [FacilityLayoutRect]
    public let objectiveBefore: Double
    public let objectiveAfter: Double
    public let improvement: Double
}

public struct FacilityLayoutSearchSummary: Codable, Equatable, Sendable {
    public let strategy: FacilityLayoutSolvingStrategy
    public let evaluatedMoveCount: Int
    public let appliedMoveCount: Int
    public let initialObjectiveValue: Double
    public let finalObjectiveValue: Double
    public let improvement: Double
}

public struct FacilityLayoutSolution: Codable, Equatable, Sendable {
    public let objective: String
    public let objectiveValue: Double
    public let source: String
    public let search: FacilityLayoutSearchSummary?
    public let moves: [FacilityLayoutMove]
    public let placements: [FacilityLayoutPlacement]
    public let interactions: [FacilityLayoutInteraction]
}

public enum FacilitiesProblemKind: String, Codable, Sendable {
    case lineBalancing
    case location
    case layout
}

public enum FacilitiesModelEnvelope: Equatable, Sendable {
    case lineBalancing(LineBalancingProblem)
    case location(FacilityLocationProblem)
    case layout(FacilityLayoutProblem)

    public var kind: FacilitiesProblemKind {
        switch self {
        case .lineBalancing: .lineBalancing
        case .location: .location
        case .layout: .layout
        }
    }
}
