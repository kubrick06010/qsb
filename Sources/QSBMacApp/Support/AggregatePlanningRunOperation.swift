import Foundation
import QSBCore

enum AggregatePlanningRunOutput: Sendable {
    case solved(json: Data, cost: Double)
    case validated(json: Data, report: ValidationReport)
    case unavailable
}

/// Runs a captured model through QSBCore without accessing mutable workspace state.
enum AggregatePlanningRunOperation {
    static func run(_ request: SolverRequest<AggregatePlanningModel>) throws -> AggregatePlanningRunOutput {
        guard let backend = AggregatePlanningBackends.backend(for: request.backend) else { return .unavailable }
        let report = backend.validationReport(for: request.model)
        guard backend.capabilities.solves && report.isValid else {
            return .validated(json: try AggregatePlanningJSON.encodeValidation(
                AggregatePlanningValidationDocument(backend: report.backend, diagnostics: report.diagnostics)), report: report)
        }
        let solution = try backend.solve(request.model, options: request.options)
        return .solved(json: try AggregatePlanningJSON.encodeSolution(
            backend.solutionDocument(for: request.model, solution: solution)), cost: solution.totalCost)
    }
}
