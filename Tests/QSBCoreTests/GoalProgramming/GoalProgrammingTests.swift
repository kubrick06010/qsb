import Foundation
import Testing
@testable import QSBCore

@Test func parsesEquivalentWinQSBGoalProgrammingFormats() throws {
    let matrix = try WinQSBGoalProgrammingParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("GP.GP_"))))
    let normal = try WinQSBGoalProgrammingParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("GPNORMAL.GP_"))))
    let backend = NativeEducationalGoalProgrammingBackend()
    let matrixSolution = try backend.solve(matrix)
    let normalSolution = try backend.solve(normal)

    #expect(matrix == normal)
    #expect(matrix.goals.map(\.name) == ["G1", "G2"])
    #expect(matrixSolution == normalSolution)
    #expect(matrixSolution.goalOutcomes.map(\.value) == [114, 574])
    #expect(matrixSolution.variableValues == ["A": 16, "B": 14, "C": 36])
}

@Test func parsesAndSolvesWinQSBIntegerGoalProgrammingFixture() throws {
    let model = try WinQSBGoalProgrammingParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("IGP.GP_"))))
    let backend = NativeEducationalGoalProgrammingBackend()
    let solution = try backend.solve(model)

    #expect(model.variableTypes.allSatisfy { $0 == .integer })
    #expect(backend.runMetadata(for: model).exactness == .fixtureScale)
    #expect(solution.goalOutcomes.map(\.value) == [0, 295])
    #expect(solution.variableValues["X1"] == 4)
    #expect(solution.variableValues["X2"] == 3)
    #expect(solution.variableValues["n3"] == 295)
}

@Test func roundTripsAndValidatesGoalProgrammingBackends() throws {
    let model = try WinQSBGoalProgrammingParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("GP.GP_"))))
    let encoded = try GoalProgrammingJSON.encodeModel(model)
    #expect(try GoalProgrammingJSON.decodeModel(from: encoded) == model)
    let native = NativeEducationalGoalProgrammingBackend()
    let document = native.solutionDocument(for: model, solution: try native.solve(model))
    #expect(try GoalProgrammingJSON.decodeSolution(from: GoalProgrammingJSON.encodeSolution(document)) == document)
    #expect(ValidateOnlyGoalProgrammingBackend().validationReport(for: model).isValid)
    #expect(GoalProgrammingBackends.backend(for: .externalHighPerformance) == nil)

    let invalid = GoalProgram(title: "Invalid", variableNames: ["x"], goals: [], constraints: [], lowerBounds: [0], upperBounds: [nil], variableTypes: [.continuous])
    let report = ValidateOnlyGoalProgrammingBackend().validationReport(for: invalid)
    #expect(!report.isValid)
    #expect(report.diagnostics.contains { $0.code == "goalProgramming.goals.empty" })
    do {
        _ = try ValidateOnlyGoalProgrammingBackend().solve(model)
        Issue.record("validateOnly unexpectedly solved a goal program")
    } catch { #expect(String(describing: error).contains("validateOnly")) }
}

