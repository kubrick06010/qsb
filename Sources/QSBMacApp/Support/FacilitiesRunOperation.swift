import Foundation
import QSBCore

enum FacilitiesRunOutput: Sendable {
    case solved(json: Data, solution: FacilitiesSolutionEnvelope)
    case validated(json: Data, report: ValidationReport)
    case unavailable
}

/// Core validation and solving use captured inputs, including the layout strategy.
enum FacilitiesRunOperation {
    static func run(_ request: SolverRequest<FacilitiesModelEnvelope>, strategy: FacilityLayoutSolvingStrategy) throws -> FacilitiesRunOutput {
        guard let backend = FacilitiesBackends.backend(for: request.backend) else { return .unavailable }
        let report = backend.validationReport(for: request.model)
        guard backend.capabilities.solves && report.isValid else {
            return .validated(json: try FacilitiesModelJSON.encodeValidation(FacilitiesValidationDocument(
                kind: request.model.kind, backend: report.backend, diagnostics: report.diagnostics)), report: report)
        }
        let solution = try backend.solve(request.model, layoutStrategy: strategy, options: request.options)
        return .solved(json: try FacilitiesModelJSON.encodeSolutionDocument(FacilitiesSolutionDocument(
            backend: backend.runMetadata(for: request.model, layoutStrategy: strategy), solution: solution)), solution: solution)
    }
}
