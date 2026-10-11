import Foundation
import QSBCore

enum ProjectSchedulingRunOutput: Sendable {
    case solved(json: Data, duration: Double)
    case validated(json: Data, report: ValidationReport)
    case unavailable
}

/// Runs a captured model through QSBCore without accessing mutable workspace state.
enum ProjectSchedulingRunOperation {
    static func run(_ request: SolverRequest<ProjectSchedulingModelEnvelope>) throws -> ProjectSchedulingRunOutput {
        guard let backend = ProjectSchedulingBackends.backend(for: request.backend) else { return .unavailable }
        let report = backend.validationReport(for: request.model)
        guard backend.capabilities.solves && report.isValid else {
            return .validated(json: try ProjectSchedulingJSON.encodeValidation(
                ProjectSchedulingValidationDocument(kind: request.model.kind,
                    backend: report.backend, diagnostics: report.diagnostics)), report: report)
        }
        let solution = try backend.solve(request.model, options: request.options)
        return .solved(json: try ProjectSchedulingJSON.encodeSolution(
            backend.solutionDocument(for: request.model, solution: solution)), duration: solution.projectDuration)
    }
}
