import Foundation
import QSBCore

enum SimulationRunOutput: Sendable {
    case solved(json: Data, completedEntities: Int, replications: Int)
    case validated(json: Data, report: ValidationReport)
    case unavailable
}

/// Executes an immutable core request; no workspace or UI state crosses into the worker.
enum SimulationRunOperation {
    static func run(_ request: SolverRequest<SimulationModel>) throws -> SimulationRunOutput {
        guard let backend = SimulationBackends.backend(for: request.backend) else { return .unavailable }
        guard backend.capabilities.solves else {
            let report = backend.validationReport(for: request.model)
            return .validated(json: try SimulationJSON.encodeValidation(
                SimulationValidationDocument(model: request.model, report: report)), report: report)
        }
        let solution = try backend.solve(request.model, options: request.options)
        return .solved(json: try SimulationJSON.encodeSolution(
            backend.solutionDocument(for: request.model, solution: solution)),
            completedEntities: solution.completedEntities, replications: solution.replications)
    }
}
