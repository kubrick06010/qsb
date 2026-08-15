import Foundation
import Testing
@testable import QSBCore

@Test func parsesAndSolvesWinQSBOneVariableNonlinearProgram() throws {
    let model = try legacyNonlinearProgram("NLP1.NL_")
    #expect(model.sense == .minimize)
    #expect(model.objectiveExpression == "2(Workforce-1000)^2+500Workforce+460000")
    #expect(model.lowerBounds == [10])
    #expect(model.upperBounds == [10_000])
    let solution = try NonlinearProgrammingSolver.solve(model)
    #expect(abs(solution.objectiveValue - 928_750) < 1e-6)
    #expect(abs((solution.variableValues["Workforce"] ?? 0) - 875) < 1e-8)
    #expect(solution.maximumViolation == 0)
}

@Test func parsesAndSolvesWinQSBMultivariableNonlinearProgram() throws {
    let model = try legacyNonlinearProgram("NLP2.NL_")
    let solution = try NativeEducationalNonlinearProgrammingBackend().solve(model)
    #expect(abs(solution.objectiveValue - -0.25) < 2e-6)
    #expect(abs(solution.variableValues["X1"] ?? -1) < 1e-8)
    #expect(abs(solution.variableValues["X2"] ?? -1) < 1e-8)
    #expect(abs((solution.variableValues["X3"] ?? 0) - 0.5) < 0.002)
}

@Test func solvesWinQSBConstrainedExponentialNonlinearProgram() throws {
    let model = try legacyNonlinearProgram("NLP3.NL_")
    #expect(model.normalizedStrictInequalities)
    #expect(model.constraints.map(\.relation) == [.equal, .lessThanOrEqual])
    let report = ValidateOnlyNonlinearProgrammingBackend().validationReport(for: model)
    #expect(report.isValid)
    #expect(report.diagnostics.contains { $0.code == "nlp.strict.normalized" && $0.severity == .warning })
    let solution = try NonlinearProgrammingSolver.solve(model)
    #expect(abs(solution.objectiveValue - -0.7221281301068521) < 2e-6)
    #expect(abs((solution.variableValues["X1"] ?? 0) - -0.8228756555322954) < 2e-6)
    #expect(abs((solution.variableValues["X2"] ?? 0) - 1.8228756555322954) < 2e-6)
    #expect(solution.maximumViolation < 2e-7)
}

@Test func roundTripsAndValidatesNonlinearProgrammingBackends() throws {
    let model = try legacyNonlinearProgram("NLP3.NL_")
    #expect(try NonlinearProgrammingJSON.decodeModel(from: NonlinearProgrammingJSON.encodeModel(model)) == model)
    let native = NativeEducationalNonlinearProgrammingBackend(), solution = try native.solve(model)
    let document = native.solutionDocument(for: model, solution: solution)
    #expect(try NonlinearProgrammingJSON.decodeSolution(from: NonlinearProgrammingJSON.encodeSolution(document)) == document)
    #expect(native.runMetadata(for: model).exactness == .approximate)
    #expect(NonlinearProgrammingBackends.backend(for: .externalHighPerformance) == nil)
    let invalid = NonlinearProgram(title: "Invalid", sense: .minimize, objectiveExpression: "mystery(x)", variableNames: ["x"], lowerBounds: [0], upperBounds: [1], constraints: [])
    let report = ValidateOnlyNonlinearProgrammingBackend().validationReport(for: invalid)
    #expect(!report.isValid)
    #expect(report.diagnostics.contains { $0.code == "nlp.expression" })
    do {
        _ = try ValidateOnlyNonlinearProgrammingBackend().solve(model)
        Issue.record("validateOnly unexpectedly solved a nonlinear program")
    } catch {
        #expect(String(describing: error).contains("validateOnly"))
    }
}

private func legacyNonlinearProgram(_ filename: String) throws -> NonlinearProgram {
    try WinQSBNonlinearProgrammingParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL(filename))))
}

