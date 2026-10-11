import Foundation
import QSBCore

enum MaterialRequirementsPlanningRunOutput: Sendable {
    case solved(json: Data, schedules: Int)
    case validated(json: Data, report: ValidationReport)
    case unavailable
}

/// Runs a captured model through QSBCore without accessing mutable workspace state.
enum MaterialRequirementsPlanningRunOperation {
    static func run(_ request: SolverRequest<MaterialRequirementsPlanningModel>) throws -> MaterialRequirementsPlanningRunOutput {
        guard let backend = MaterialRequirementsPlanningBackends.backend(for: request.backend) else { return .unavailable }
        let report = backend.validationReport(for: request.model)
        guard backend.capabilities.solves && report.isValid else {
            return .validated(json: try MaterialRequirementsPlanningJSON.encodeValidation(
                MaterialRequirementsPlanningValidationDocument(backend: report.backend, diagnostics: report.diagnostics)), report: report)
        }
        let solution = try backend.solve(request.model, options: request.options)
        return .solved(json: try MaterialRequirementsPlanningJSON.encodeSolution(
            backend.solutionDocument(for: request.model, solution: solution)), schedules: solution.schedules.count)
    }
}
