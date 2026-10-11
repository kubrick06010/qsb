import Foundation
import QSBCore

enum KnapsackRunOutput: Sendable {
    case solved(json: Data)
    case validated(json: Data, report: ValidationReport)
    case unavailable
}

/// Delegates the captured dynamic-programming request to core backends.
enum KnapsackRunOperation {
    static func run(_ request: SolverRequest<DynamicProgrammingModelEnvelope>) throws -> KnapsackRunOutput {
        guard let backend = DynamicProgrammingBackends.backend(for: request.backend) else { return .unavailable }
        let report = backend.validationReport(for: request.model)
        guard backend.capabilities.solves && report.isValid else {
            return .validated(json: try DynamicProgrammingModelJSON.encodeValidation(DynamicProgrammingValidationDocument(
                kind: request.model.kind, backend: report.backend, diagnostics: report.diagnostics)), report: report)
        }
        let solution = try backend.solve(request.model, options: request.options)
        return .solved(json: try DynamicProgrammingModelJSON.encodeSolutionDocument(
            backend.solutionDocument(for: request.model, solution: solution)))
    }
}
