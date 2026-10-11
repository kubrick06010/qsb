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
    if let external = GoalProgrammingBackends.backend(for: .externalHighPerformance) {
        #expect(external.capabilities.solves)
        #expect(external.capabilities.backendKind == .externalHighPerformance)
    }

    let invalid = GoalProgram(title: "Invalid", variableNames: ["x"], goals: [], constraints: [], lowerBounds: [0], upperBounds: [nil], variableTypes: [.continuous])
    let report = ValidateOnlyGoalProgrammingBackend().validationReport(for: invalid)
    #expect(!report.isValid)
    #expect(report.diagnostics.contains { $0.code == "goalProgramming.goals.empty" })
    do {
        _ = try ValidateOnlyGoalProgrammingBackend().solve(model)
        Issue.record("validateOnly unexpectedly solved a goal program")
    } catch { #expect(String(describing: error).contains("validateOnly")) }
}

@Test func routesGoalProgrammingThroughExternalBackendSeam() throws {
    let model = try WinQSBGoalProgrammingParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("GP.GP_"))))
    let native = try NativeEducationalGoalProgrammingBackend().solve(model)
    let external = HiGHSGoalProgrammingBackend(linearProgrammingBackend: NativeEducationalLinearProgrammingBackend())
    let solution = try external.solve(model)

    #expect(solution == native)
    #expect(external.runMetadata(for: model).algorithm == "hiGHSLexicographicLP")
}

@Test func preservesEarlierLexicographicPrioritiesInTheFinalSolution() throws {
    let model = GoalProgram(
        title: "Independent priorities",
        variableNames: ["primary", "secondary"],
        goals: [
            GoalObjective(name: "Primary", sense: .maximize, coefficients: [1, 0]),
            GoalObjective(name: "Secondary", sense: .maximize, coefficients: [0, 1])
        ],
        constraints: [LinearConstraint(
            name: "Shared capacity", coefficients: [1, 1], relation: .lessThanOrEqual, rhs: 10
        )],
        lowerBounds: [0, 0],
        upperBounds: [10, 10],
        variableTypes: [.continuous, .continuous]
    )

    let solution = try NativeEducationalGoalProgrammingBackend().solve(model)

    #expect(solution.goalOutcomes.map(\.value) == [10, 0])
    #expect(solution.variableValues["primary"] == 10)
    #expect(solution.variableValues["secondary"] == 0)
}

@Test func solvesIntegerGoalProgrammingWithInstalledHiGHSWhenAvailable() throws {
    guard let backend = HiGHSGoalProgrammingBackend.discovered() else { return }
    let model = try WinQSBGoalProgrammingParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("IGP.GP_"))))
    let solution = try backend.solve(model)
    #expect(solution.goalOutcomes.map(\.value) == [0, 295])
    #expect(solution.variableValues["X1"] == 4)
    #expect(solution.variableValues["X2"] == 3)
}

@Test func solvesLargerLexicographicIntegerGoalsWithInstalledHiGHSWhenAvailable() throws {
    guard let backend = HiGHSGoalProgrammingBackend.discovered() else { return }
    let count = 12
    let names = (1...count).map { "Choice \($0)" }
    let model = GoalProgram(
        title: "Select six integer choices", variableNames: names,
        goals: [
            GoalObjective(name: "First priority", sense: .maximize,
                          coefficients: (1...count).map { Double(count + 1 - $0) }),
            GoalObjective(name: "Second priority", sense: .minimize,
                          coefficients: (1...count).map(Double.init))
        ],
        constraints: [LinearConstraint(
            name: "Select six", coefficients: Array(repeating: 1, count: count),
            relation: .equal, rhs: 6
        )],
        lowerBounds: Array(repeating: 0, count: count),
        upperBounds: Array(repeating: 1, count: count),
        variableTypes: Array(repeating: .binary, count: count)
    )

    let solution = try backend.solve(model)
    #expect(solution.goalOutcomes.map(\.value) == [57, 21])
    for index in 0..<count {
        #expect(abs((solution.variableValues[names[index]] ?? -1) - (index < 6 ? 1 : 0)) < 1e-7)
    }
}
