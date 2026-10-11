import Foundation
import QSBCore

enum TypedModelRunRequest: Sendable {
    case quadratic(SolverRequest<QuadraticProgram>)
    case nonlinear(SolverRequest<NonlinearProgram>)
    case goal(SolverRequest<GoalProgram>)
    case acceptance(SolverRequest<AcceptanceSamplingModelEnvelope>)
    case quality(SolverRequest<QualityControlModelEnvelope>)

    var name: String {
        switch self {
        case .quadratic: "Quadratic Programming"
        case .nonlinear: "Nonlinear Programming"
        case .goal: "Goal Programming"
        case .acceptance: "Acceptance Sampling"
        case .quality: "Quality Control"
        }
    }
}

enum TypedModelRunSummary: Sendable {
    case objective(Double), priorities(Int), producerRisk(Double), qualityKind(String)
}

enum TypedModelRunOutput: Sendable {
    case solved(json: Data, summary: TypedModelRunSummary)
    case validated(json: Data, report: ValidationReport)
    case unavailable
}

/// Worker orchestration keeps core models and backend selection away from UI state.
enum TypedModelRunOperation {
    static func run(_ input: TypedModelRunRequest) throws -> TypedModelRunOutput {
        switch input {
        case .quadratic(let request):
            guard let backend = QuadraticProgrammingBackends.backend(for: request.backend) else { return .unavailable }
            let report = backend.validationReport(for: request.model)
            guard backend.capabilities.solves && report.isValid else {
                return .validated(json: try QuadraticProgrammingJSON.encodeValidation(QuadraticProgramValidationDocument(
                    backend: report.backend, diagnostics: report.diagnostics)), report: report)
            }
            let solution = try backend.solve(request.model, options: request.options)
            return .solved(json: try QuadraticProgrammingJSON.encodeSolution(
                backend.solutionDocument(for: request.model, solution: solution)), summary: .objective(solution.objectiveValue))
        case .nonlinear(let request):
            guard let backend = NonlinearProgrammingBackends.backend(for: request.backend) else { return .unavailable }
            let report = backend.validationReport(for: request.model)
            guard backend.capabilities.solves && report.isValid else {
                return .validated(json: try NonlinearProgrammingJSON.encodeValidation(NonlinearProgramValidationDocument(
                    backend: report.backend, diagnostics: report.diagnostics)), report: report)
            }
            let solution = try backend.solve(request.model, options: request.options)
            return .solved(json: try NonlinearProgrammingJSON.encodeSolution(
                backend.solutionDocument(for: request.model, solution: solution)), summary: .objective(solution.objectiveValue))
        case .goal(let request):
            guard let backend = GoalProgrammingBackends.backend(for: request.backend) else { return .unavailable }
            let report = backend.validationReport(for: request.model)
            guard backend.capabilities.solves && report.isValid else {
                return .validated(json: try GoalProgrammingJSON.encodeValidation(GoalProgrammingValidationDocument(
                    backend: report.backend, diagnostics: report.diagnostics)), report: report)
            }
            let solution = try backend.solve(request.model, options: request.options)
            return .solved(json: try GoalProgrammingJSON.encodeSolution(
                backend.solutionDocument(for: request.model, solution: solution)), summary: .priorities(solution.goalOutcomes.count))
        case .acceptance(let request):
            guard let backend = AcceptanceSamplingBackends.backend(for: request.backend) else { return .unavailable }
            let report = backend.validationReport(for: request.model)
            guard backend.capabilities.solves && report.isValid else {
                return .validated(json: try AcceptanceSamplingJSON.encodeValidation(AcceptanceSamplingValidationDocument(
                    kind: request.model.kind, backend: report.backend, diagnostics: report.diagnostics)), report: report)
            }
            let solution = try backend.solve(request.model, options: request.options)
            return .solved(json: try AcceptanceSamplingJSON.encodeSolution(
                backend.solutionDocument(for: request.model, solution: solution)), summary: .producerRisk(solution.producerRiskAtAQL))
        case .quality(let request):
            guard let backend = QualityControlBackends.backend(for: request.backend) else { return .unavailable }
            let report = backend.validationReport(for: request.model)
            guard backend.capabilities.solves && report.isValid else {
                return .validated(json: try QualityControlJSON.encodeValidation(QualityControlValidationDocument(
                    kind: request.model.kind, backend: report.backend, diagnostics: report.diagnostics)), report: report)
            }
            let solution = try backend.solve(request.model, options: request.options)
            return .solved(json: try QualityControlJSON.encodeSolution(
                backend.solutionDocument(for: request.model, solution: solution)), summary: .qualityKind(request.model.kind.rawValue))
        }
    }
}
