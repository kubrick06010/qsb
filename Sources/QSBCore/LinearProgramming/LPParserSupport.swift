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
    case externalSolverUnavailable(String)
    case externalSolverFailed(String)
    case externalSolverMalformedOutput(String)

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
        case .externalSolverUnavailable(let detail):
            "External linear-programming solver unavailable: \(detail)"
        case .externalSolverFailed(let detail):
            "External linear-programming solver failed: \(detail)"
        case .externalSolverMalformedOutput(let detail):
            "External linear-programming solver returned malformed output: \(detail)"
        }
    }
}
