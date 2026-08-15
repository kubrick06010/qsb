import Foundation
public enum LinearProgramError: Error, CustomStringConvertible {
    case unsupportedMatrixFormat
    case invalidNumericValue(String)
    case unsupportedRelation(String)
    case unsupportedVariableType(String)
    case invalidModel(String)
    case unsupportedModel(String)
    case infeasible
    case unbounded

    public var description: String {
        switch self {
        case .unsupportedMatrixFormat:
            "Unsupported LP matrix format"
        case .invalidNumericValue(let value):
            "Invalid numeric value: \(value)"
        case .unsupportedRelation(let relation):
            "Unsupported constraint relation: \(relation)"
        case .unsupportedVariableType(let type):
            "Unsupported variable type: \(type)"
        case .invalidModel(let detail):
            "Invalid LP model: \(detail)"
        case .unsupportedModel(let detail):
            "Unsupported LP model: \(detail)"
        case .infeasible:
            "Linear program is infeasible"
        case .unbounded:
            "Linear program is unbounded"
        }
    }
}

