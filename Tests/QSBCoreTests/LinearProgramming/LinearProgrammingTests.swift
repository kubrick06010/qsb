import Foundation
import Testing
@testable import QSBCore

@Test func parsesAndSolvesWinQSBMaxLPFixture() throws {
    let url = legacyFixtureURL("LP.LP_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let program = try WinQSBMatrixParser.parseLP(from: expanded)
    let solution = try SimplexSolver.solve(program)

    #expect(program.title == "LP Sample Problem")
    #expect(program.variableNames == ["X1", "X2"])
    #expect(abs(solution.objectiveValue - 3780) < 1e-8)
    #expect(abs((solution.variableValues["X1"] ?? -1) - 18) < 1e-8)
    #expect(abs((solution.variableValues["X2"] ?? -1) - 48) < 1e-8)
}

@Test func parsesAndSolvesWinQSBIntegerLPFixture() throws {
    let url = legacyFixtureURL("ILP.LP_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let program = try WinQSBMatrixParser.parseLP(from: expanded)
    let relaxation = try SimplexSolver.solve(program)
    let integerSolution = try IntegerLinearProgramSolver.solve(program)

    #expect(program.title == "ILP Sample Problem")
    #expect(program.sense == .minimize)
    #expect(program.variableTypes == [.integer, .integer])
    #expect(program.lowerBounds == [0, 0])
    #expect(program.upperBounds == [nil, nil])
    #expect(abs(relaxation.objectiveValue - 100.47619047619048) < 1e-8)
    #expect(abs((relaxation.variableValues["X1"] ?? -1) - 21.904761904761905) < 1e-8)
    #expect(abs((relaxation.variableValues["X2"] ?? -1) - 22.857142857142858) < 1e-8)
    #expect(abs(integerSolution.objectiveValue - 101) < 1e-8)
    #expect(abs((integerSolution.variableValues["X1"] ?? -1) - 22) < 1e-8)
    #expect(abs((integerSolution.variableValues["X2"] ?? -1) - 23) < 1e-8)
}

@Test func extractsOnlyTheRecordedSimplexBasisValues() throws {
    let program = LinearProgram(
        title: "Degenerate unit columns",
        sense: .minimize,
        variableNames: ["expensive", "cheap"],
        objectiveCoefficients: [10, 1],
        constraints: [LinearConstraint(name: "shared", coefficients: [1, 1], relation: .equal, rhs: 1)]
    )
    let solution = try SimplexSolver.solve(program)
    #expect(abs(solution.objectiveValue - 1) < 1e-10)
    #expect(abs((solution.variableValues["expensive"] ?? -1)) < 1e-10)
    #expect(abs((solution.variableValues["cheap"] ?? -1) - 1) < 1e-10)
}

@Test func solvesDecodedFacilityLocationJSONModel() throws {
    let url = legacyFixtureURL("LOCATION.FL_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBFacilitiesParser.parseLocation(from: expanded)
    let json = try FacilityLocationJSON.encodeModel(problem)
    let decoded = try FacilityLocationJSON.decodeModel(from: json)
    let solution = try FacilityLocationSolver.solve(decoded)
    let solutionJSON = try FacilityLocationJSON.encodeSolution(solution)
    let solutionText = try #require(String(data: solutionJSON, encoding: .utf8))

    #expect(decoded == problem)
    #expect(abs(solution.objectiveValue - 2008.6923076923076) < 1e-8)
    #expect(solution.placements.map(\.facilityName) == ["NF1"])
    #expect(solutionText.contains("\"distanceMeasure\" : \"squaredEuclidean\""))
    #expect(solutionText.contains("\"facilityName\" : \"NF1\""))
    #expect(solutionText.contains("\"objectiveValue\""))
    #expect(solutionText.contains("\"interactions\""))
}

@Test func solvesDecodedLineBalancingJSONModel() throws {
    let url = legacyFixtureURL("LINEBAL.FL_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBFacilitiesParser.parseLineBalancing(from: expanded)
    let json = try LineBalancingJSON.encodeModel(problem)
    let decoded = try LineBalancingJSON.decodeModel(from: json)
    let solution = try LineBalancingSolver.solve(decoded)
    let solutionJSON = try LineBalancingJSON.encodeSolution(solution)
    let solutionText = try #require(String(data: solutionJSON, encoding: .utf8))

    #expect(decoded == problem)
    #expect(solution.stationCount == 5)
    #expect(solution.totalTaskTime == 143)
    #expect(solution.stations.map(\.taskIDs) == [
        [1, 2, 4, 6, 12],
        [7, 10, 18],
        [5, 11, 13, 14, 15],
        [3, 8, 9, 16],
        [17, 19, 20, 21]
    ])
    #expect(solutionText.contains("\"stationCount\" : 5"))
    #expect(solutionText.contains("\"efficiency\""))
    #expect(solutionText.contains("\"stations\""))
    #expect(solutionText.contains("\"taskIDs\""))
}

@Test func solvesDecodedFacilityLayoutJSONModel() throws {
    let url = legacyFixtureURL("LAYOUT.FL_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBFacilitiesParser.parseLayout(from: expanded)
    let json = try FacilityLayoutJSON.encodeModel(problem)
    let decoded = try FacilityLayoutJSON.decodeModel(from: json)
    let solution = try FacilityLayoutSolver.solve(decoded)
    let solutionJSON = try FacilityLayoutJSON.encodeSolution(solution)
    let solutionText = try #require(String(data: solutionJSON, encoding: .utf8))

    #expect(decoded == problem)
    #expect(abs(solution.objectiveValue - 53552) < 1e-8)
    #expect(solutionText.contains("\"source\" : \"initialLayoutEvaluation\""))
    #expect(solutionText.contains("\"objectiveValue\" : 53552"))
    #expect(solutionText.contains("\"placements\""))
    #expect(solutionText.contains("\"interactions\""))
}

@Test func routesLPBackedModelsThroughNamedBackend() throws {
    let backend = NativeEducationalLinearProgrammingBackend()

    let transportationData = try Data(contentsOf: legacyFixtureURL("TRNSPORT.NE_"))
    let transportationExpanded = try LegacyCompressedFile.expandedData(from: transportationData)
    let transportation = try WinQSBNetworkParser.parseTransportation(from: transportationExpanded)
    let transportationSolution = try TransportationSolver.solve(
        transportation,
        linearProgrammingBackend: backend
    )
    #expect(abs(transportationSolution.totalCost - 3350) < 1e-8)

    let gameData = try Data(contentsOf: legacyFixtureURL("GAME.DA_"))
    let gameExpanded = try LegacyCompressedFile.expandedData(from: gameData)
    let game = try WinQSBDecisionAnalysisParser.parseZeroSumGame(from: gameExpanded)
    let gameSolution = try ZeroSumGameSolver.solve(
        game,
        linearProgrammingBackend: backend
    )
    #expect(abs(gameSolution.value - 10.265525246662797) < 1e-8)
}

@Test func encodesAndDecodesNormalizedJSONModel() throws {
    let url = legacyFixtureURL("ILP.LP_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)
    let program = try WinQSBMatrixParser.parseLP(from: expanded)

    let json = try LinearProgramJSON.encodeProgram(program)
    let decoded = try LinearProgramJSON.decodeProgram(from: json)
    let solution = try IntegerLinearProgramSolver.solve(decoded)

    #expect(decoded == program)
    #expect(String(data: json, encoding: .utf8)?.contains("\"variableTypes\"") == true)
    #expect(abs(solution.objectiveValue - 101) < 1e-8)
    #expect(abs((solution.variableValues["X1"] ?? -1) - 22) < 1e-8)
    #expect(abs((solution.variableValues["X2"] ?? -1) - 23) < 1e-8)
}

@Test func validatesLinearProgramWithBackendDiagnostics() throws {
    let program = LinearProgram(
        title: "Validation Sample",
        sense: .maximize,
        variableNames: ["X1"],
        objectiveCoefficients: [1],
        constraints: [
            LinearConstraint(
                name: "Capacity",
                coefficients: [1],
                relation: .lessThanOrEqual,
                rhs: 10
            )
        ]
    )

    let diagnostics = LinearProgramValidator.diagnostics(for: program)
    let report = ValidationReport(backend: .validateOnly, diagnostics: diagnostics)

    #expect(report.backend == .validateOnly)
    #expect(report.isValid)
    #expect(diagnostics == [
        ValidationDiagnostic(
            severity: .info,
            code: "lp.valid",
            message: "Linear program is valid"
        )
    ])
}

@Test func routesLinearProgramsThroughNamedBackends() throws {
    let continuousProgram = LinearProgram(
        title: "Backend Continuous Sample",
        sense: .maximize,
        variableNames: ["X1"],
        objectiveCoefficients: [1],
        constraints: [
            LinearConstraint(
                name: "Capacity",
                coefficients: [1],
                relation: .lessThanOrEqual,
                rhs: 10
            )
        ]
    )
    let integerProgram = LinearProgram(
        title: "Backend Integer Sample",
        sense: .maximize,
        variableNames: ["X1"],
        objectiveCoefficients: [1],
        constraints: [
            LinearConstraint(
                name: "Capacity",
                coefficients: [1],
                relation: .lessThanOrEqual,
                rhs: 1.8
            )
        ],
        variableTypes: [.integer]
    )

    let nativeBackend = NativeEducationalLinearProgrammingBackend()
    #expect(nativeBackend.capabilities.backendKind == .nativeEducational)
    #expect(nativeBackend.capabilities.solves)
    #expect(nativeBackend.capabilities.validates)

    let continuousSolution = try nativeBackend.solve(continuousProgram, mode: .continuous)
    #expect(abs(continuousSolution.objectiveValue - 10) < 1e-8)

    let integerSolution = try nativeBackend.solve(integerProgram, mode: .integer)
    #expect(abs(integerSolution.objectiveValue - 1) < 1e-8)

    let validateBackend = ValidateOnlyLinearProgrammingBackend()
    let validationReport = validateBackend.validationReport(for: continuousProgram)
    #expect(validateBackend.capabilities.backendKind == .validateOnly)
    #expect(!validateBackend.capabilities.solves)
    #expect(validationReport.backend == .validateOnly)
    #expect(validationReport.isValid)

    do {
        _ = try validateBackend.solve(continuousProgram, mode: .continuous)
        Issue.record("Expected validateOnly backend to reject solving")
    } catch LinearProgramError.unsupportedModel(let message) {
        #expect(message.contains("validateOnly"))
    }

    let selectedBackend = try #require(LinearProgrammingBackends.backend(for: .nativeEducational))
    #expect(selectedBackend.capabilities.backendKind == .nativeEducational)
    #expect(LinearProgrammingBackends.backend(for: .externalHighPerformance) == nil)
}

@Test func encodesJSONSolution() throws {
    let solution = LinearProgramSolution(
        objectiveValue: 101,
        variableValues: ["X1": 22, "X2": 23]
    )

    let json = try LinearProgramJSON.encodeSolution(solution)
    let text = try #require(String(data: json, encoding: .utf8))

    #expect(text.contains("\"objectiveValue\""))
    #expect(text.contains("\"variableValues\""))
}

@Test func rejectsJSONModelWithMismatchedDimensions() throws {
    let json = Data("""
    {
      "title": "Bad Model",
      "sense": "maximize",
      "variableNames": ["X1", "X2"],
      "objectiveCoefficients": [1],
      "constraints": [],
      "lowerBounds": [0, 0],
      "upperBounds": [null, null],
      "variableTypes": ["continuous", "continuous"]
    }
    """.utf8)

    do {
        _ = try LinearProgramJSON.decodeProgram(from: json)
        Issue.record("Expected mismatched JSON dimensions to be rejected")
    } catch LinearProgramError.invalidModel(let message) {
        #expect(message.contains("objectiveCoefficients"))
    }
}

@Test func rejectsJSONModelWithDuplicateVariableNames() throws {
    try expectInvalidModel(
        """
        {
          "title": "Bad Model",
          "sense": "maximize",
          "variableNames": ["X1", "X1"],
          "objectiveCoefficients": [1, 2],
          "constraints": [],
          "lowerBounds": [0, 0],
          "upperBounds": [null, null],
          "variableTypes": ["continuous", "continuous"]
        }
        """,
        containing: "unique"
    )
}

@Test func rejectsJSONModelWithInvertedBounds() throws {
    try expectInvalidModel(
        """
        {
          "title": "Bad Model",
          "sense": "maximize",
          "variableNames": ["X1"],
          "objectiveCoefficients": [1],
          "constraints": [],
          "lowerBounds": [5],
          "upperBounds": [4],
          "variableTypes": ["continuous"]
        }
        """,
        containing: "upper bound"
    )
}

@Test func rejectsJSONModelWithInvalidBinaryBounds() throws {
    try expectInvalidModel(
        """
        {
          "title": "Bad Model",
          "sense": "maximize",
          "variableNames": ["X1"],
          "objectiveCoefficients": [1],
          "constraints": [],
          "lowerBounds": [0],
          "upperBounds": [2],
          "variableTypes": ["binary"]
        }
        """,
        containing: "binary variable"
    )
}
@Test func parsesAndSolvesWinQSBNormalModelFixture() throws {
    let url = legacyFixtureURL("LPNORMAL.LP_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let program = try WinQSBMatrixParser.parseLP(from: expanded)
    let solution = try SimplexSolver.solve(program)

    #expect(program.title == "LP Sample Problem")
    #expect(program.sense == .maximize)
    #expect(program.variableNames == ["X1", "X2"])
    #expect(program.objectiveCoefficients == [50, 60])
    #expect(program.lowerBounds == [0, 0])
    #expect(program.upperBounds == [nil, nil])
    #expect(program.variableTypes == [.continuous, .continuous])
    #expect(abs(solution.objectiveValue - 3780) < 1e-8)
    #expect(abs((solution.variableValues["X1"] ?? -1) - 18) < 1e-8)
    #expect(abs((solution.variableValues["X2"] ?? -1) - 48) < 1e-8)
}

@Test func parsesAndSolvesNormalModelUnrestrictedVariableWithNegativeOptimum() throws {
    let data = Data("LP\tNormalModel\tNegative optimum\t1\t1\nHeader\t\nMinimize\tX\nConstraint\tX>=-5\nUnrestricted:\tX\n".utf8)
    let program = try WinQSBMatrixParser.parseLP(from: data)
    let solution = try SimplexSolver.solve(program)

    #expect(program.unrestrictedVariables == [true])
    #expect(abs((solution.variableValues["X"] ?? 0) + 5) < 1e-8)
}
