import Foundation
import Testing
@testable import QSBCore

@Test func parsesAndSolvesWinQSBMatrixQuadraticProgram() throws {
    let model = try legacyQuadraticProgram("QP.QP_")
    #expect(model.variableNames == ["Gid1", "Gid2", "Gid3"])
    #expect(model.linearCoefficients == [3.2, 5, 5])
    #expect(model.quadraticMatrix == [[-1, 0, 0], [0, -2, 0], [0, 0, -5]])
    #expect(model.variableTypes == [.continuous, .continuous, .continuous])
    let solution = try QuadraticProgrammingSolver.solve(model)
    #expect(abs(solution.objectiveValue - -134.20587293112655) < 1e-8)
    #expect(abs((solution.variableValues["Gid1"] ?? 0) - 8.556860651361452) < 1e-8)
    #expect(abs((solution.variableValues["Gid2"] ?? 0) - 8.013614522156969) < 1e-8)
    #expect(abs(solution.variableValues["Gid3"] ?? -1) < 1e-10)
    #expect(Set(solution.activeConstraints) == ["C2", "Gid3 lower"])
}

@Test func parsesAndSolvesWinQSBNormalQuadraticProgram() throws {
    let model = try legacyQuadraticProgram("QPNORMAL.QP_")
    #expect(model.variableNames == ["a", "b", "c"])
    #expect(model.linearCoefficients == [1, 3, -4])
    #expect(model.quadraticMatrix == [[-2, 1, 0], [1, -2, 0], [0, 0, -1]])
    let solution = try NativeEducationalQuadraticProgrammingBackend().solve(model)
    #expect(abs(solution.objectiveValue - -5355.86463963964) < 1e-8)
    #expect(abs((solution.variableValues["a"] ?? 0) - 56.808108108108) < 1e-8)
    #expect(abs((solution.variableValues["b"] ?? 0) - 31.543693693694) < 1e-8)
    #expect(abs((solution.variableValues["c"] ?? 0) - 23.511711711712) < 1e-8)
    #expect(Set(solution.activeConstraints) == ["C2", "C3"])
}

@Test func parsesAndSolvesWinQSBIntegerQuadraticProgram() throws {
    let model = try legacyQuadraticProgram("IQP.QP_")
    #expect(model.variableTypes == [.integer, .integer, .integer])
    let backend = NativeEducationalQuadraticProgrammingBackend()
    let solution = try backend.solve(model)
    #expect(solution.objectiveValue == -303.2)
    #expect(solution.variableValues == ["Gid1": 19, "Gid2": 3, "Gid3": 1])
    #expect(solution.activeConstraints == ["C2"])
    #expect(backend.runMetadata(for: model).exactness == .fixtureScale)
}

@Test func roundTripsAndValidatesQuadraticProgrammingBackends() throws {
    let model = try legacyQuadraticProgram("QP.QP_")
    #expect(try QuadraticProgrammingJSON.decodeModel(from: QuadraticProgrammingJSON.encodeModel(model)) == model)
    let native = NativeEducationalQuadraticProgrammingBackend(), solution = try native.solve(model)
    let document = native.solutionDocument(for: model, solution: solution)
    #expect(try QuadraticProgrammingJSON.decodeSolution(from: QuadraticProgrammingJSON.encodeSolution(document)) == document)
    #expect(ValidateOnlyQuadraticProgrammingBackend().validationReport(for: model).isValid)
    #expect(QuadraticProgrammingBackends.backend(for: .externalHighPerformance) == nil)
    let invalid = QuadraticProgram(title: "Nonconcave", sense: .maximize, variableNames: ["x"], linearCoefficients: [0], quadraticMatrix: [[1]], constraints: [], lowerBounds: [0], upperBounds: [nil], variableTypes: [.continuous])
    let report = ValidateOnlyQuadraticProgrammingBackend().validationReport(for: invalid)
    #expect(!report.isValid)
    #expect(report.diagnostics.contains { $0.code == "qp.curvature" })
    do {
        _ = try ValidateOnlyQuadraticProgrammingBackend().solve(model)
        Issue.record("validateOnly unexpectedly solved a quadratic program")
    } catch {
        #expect(String(describing: error).contains("validateOnly"))
    }
}

private func legacyQuadraticProgram(_ filename: String) throws -> QuadraticProgram {
    try WinQSBQuadraticProgrammingParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL(filename))))
}

