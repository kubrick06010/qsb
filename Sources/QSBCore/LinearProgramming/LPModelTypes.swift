import Foundation
public enum ObjectiveSense: String, Codable, Sendable {
    case maximize
    case minimize
}

public enum ConstraintRelation: String, Codable, Sendable {
    case lessThanOrEqual = "<="
    case greaterThanOrEqual = ">="
    case equal = "="
}

public enum VariableType: String, Codable, Sendable {
    case continuous
    case integer
    case binary
}

public struct LinearConstraint: Codable, Equatable, Sendable {
    public let name: String
    public let coefficients: [Double]
    public let relation: ConstraintRelation
    public let rhs: Double

    public init(
        name: String,
        coefficients: [Double],
        relation: ConstraintRelation,
        rhs: Double
    ) {
        self.name = name
        self.coefficients = coefficients
        self.relation = relation
        self.rhs = rhs
    }
}

public struct LinearProgram: Codable, Equatable, Sendable {
    public let title: String
    public let sense: ObjectiveSense
    public let variableNames: [String]
    public let objectiveCoefficients: [Double]
    public let constraints: [LinearConstraint]
    public let lowerBounds: [Double]
    public let upperBounds: [Double?]
    public let variableTypes: [VariableType]
    public let unrestrictedVariables: [Bool]

    private enum CodingKeys: String, CodingKey {
        case title, sense, variableNames, objectiveCoefficients, constraints
        case lowerBounds, upperBounds, variableTypes, unrestrictedVariables
    }

    public init(
        title: String,
        sense: ObjectiveSense,
        variableNames: [String],
        objectiveCoefficients: [Double],
        constraints: [LinearConstraint],
        lowerBounds: [Double]? = nil,
        upperBounds: [Double?]? = nil,
        variableTypes: [VariableType]? = nil,
        unrestrictedVariables: [Bool]? = nil
    ) {
        self.title = title
        self.sense = sense
        self.variableNames = variableNames
        self.objectiveCoefficients = objectiveCoefficients
        self.constraints = constraints
        self.lowerBounds = lowerBounds ?? Array(repeating: 0, count: variableNames.count)
        self.upperBounds = upperBounds ?? Array(repeating: nil, count: variableNames.count)
        self.variableTypes = variableTypes ?? Array(repeating: .continuous, count: variableNames.count)
        self.unrestrictedVariables = unrestrictedVariables ?? Array(repeating: false, count: variableNames.count)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decode(String.self, forKey: .title)
        self.sense = try container.decode(ObjectiveSense.self, forKey: .sense)
        self.variableNames = try container.decode([String].self, forKey: .variableNames)
        self.objectiveCoefficients = try container.decode([Double].self, forKey: .objectiveCoefficients)
        self.constraints = try container.decode([LinearConstraint].self, forKey: .constraints)
        self.lowerBounds = try container.decodeIfPresent([Double].self, forKey: .lowerBounds)
            ?? Array(repeating: 0, count: variableNames.count)
        self.upperBounds = try container.decodeIfPresent([Double?].self, forKey: .upperBounds)
            ?? Array(repeating: nil, count: variableNames.count)
        self.variableTypes = try container.decodeIfPresent([VariableType].self, forKey: .variableTypes)
            ?? Array(repeating: .continuous, count: variableNames.count)
        self.unrestrictedVariables = try container.decodeIfPresent([Bool].self, forKey: .unrestrictedVariables)
            ?? Array(repeating: false, count: variableNames.count)
    }
}

public struct LinearProgramSolution: Codable, Equatable, Sendable {
    public let objectiveValue: Double
    public let variableValues: [String: Double]
}

public enum LinearProgramSolveMode: String, Codable, Sendable {
    case continuous
    case integer
}
