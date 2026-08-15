import Foundation
import Testing
@testable import QSBCore

@Test func parsesAndSolvesWinQSBFacilityLocationFixture() throws {
    let url = legacyFixtureURL("LOCATION.FL_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBFacilitiesParser.parseLocation(from: expanded)
    let solution = try FacilityLocationSolver.solve(problem)

    #expect(problem.title == "Location Example 1")
    #expect(problem.distanceMeasure == .squaredEuclidean)
    #expect(problem.objective == "MIN")
    #expect(problem.existingFacilities.count == 5)
    #expect(problem.newFacilities.count == 1)
    #expect(problem.facilities[0] == FacilityLocationFacility(
        id: 1,
        name: "F1",
        isNew: false,
        x: 0,
        y: 12,
        interactionCosts: [nil, 5, 18, 2, 25, nil]
    ))
    #expect(problem.newFacilities[0] == FacilityLocationFacility(
        id: 1,
        name: "NF1",
        isNew: true,
        x: nil,
        y: nil,
        interactionCosts: [8, 6, 15, 20, 3, nil]
    ))
    #expect(solution.distanceMeasure == .squaredEuclidean)
    #expect(solution.placements.count == 1)
    let placement = try #require(solution.placements.first)
    #expect(placement.facilityName == "NF1")
    #expect(abs(placement.x - 5.538461538461538) < 1e-8)
    #expect(abs(placement.y - 7.653846153846154) < 1e-8)
    #expect(abs(placement.weightedDistance - 2008.6923076923076) < 1e-8)
    #expect(abs(solution.objectiveValue - 2008.6923076923076) < 1e-8)
    #expect(placement.interactions.map(\.existingFacilityName) == ["F1", "F2", "F3", "F4", "F5"])
    #expect(abs(placement.interactions[0].distance - 49.56360946745561) < 1e-8)
    #expect(abs(placement.interactions[0].weightedDistance - 396.5088757396449) < 1e-8)
    #expect(abs(placement.interactions[4].distance - 214.6405325443787) < 1e-8)
    #expect(abs(placement.interactions[4].weightedDistance - 643.9215976331361) < 1e-8)
}

@Test func validatesWinQSBFacilityLocationFixtureWithBackendDiagnostics() throws {
    let url = legacyFixtureURL("LOCATION.FL_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBFacilitiesParser.parseLocation(from: expanded)
    let diagnostics = FacilityLocationValidator.diagnostics(for: problem)
    let report = ValidationReport(backend: .validateOnly, diagnostics: diagnostics)

    #expect(report.backend == .validateOnly)
    #expect(report.isValid)
    #expect(diagnostics.contains {
        $0.severity == .info && $0.code == "facilities.location.valid"
    })
}

@Test func parsesAndSolvesWinQSBLineBalancingFixture() throws {
    let url = legacyFixtureURL("LINEBAL.FL_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBFacilitiesParser.parseLineBalancing(from: expanded)
    let solution = try LineBalancingSolver.solve(problem)

    #expect(problem.title == "Line Balancing Example")
    #expect(problem.timeUnit == "minute")
    #expect(problem.cycleTime == 30)
    #expect(problem.tasks.count == 21)
    #expect(problem.tasks[0] == LineBalancingTask(
        id: 1,
        name: "Task 1",
        time: 5,
        isolated: false,
        successorIDs: [4, 5, 6]
    ))
    #expect(problem.tasks[20] == LineBalancingTask(
        id: 21,
        name: "Task 21",
        time: 5,
        isolated: false,
        successorIDs: []
    ))
    #expect(solution.stationCount == 5)
    #expect(solution.totalTaskTime == 143)
    #expect(solution.cycleTime == 30)
    #expect(abs(solution.efficiency - 0.9533333333333334) < 1e-8)
    #expect(abs(solution.balanceDelay - 0.046666666666666634) < 1e-8)
    #expect(solution.stations.map(\.taskIDs) == [
        [1, 2, 4, 6, 12],
        [7, 10, 18],
        [5, 11, 13, 14, 15],
        [3, 8, 9, 16],
        [17, 19, 20, 21]
    ])
    #expect(solution.stations.map(\.workload) == [30, 30, 30, 29, 24])
    #expect(solution.stations.map(\.idleTime) == [0, 0, 0, 1, 6])
}

@Test func validatesWinQSBLineBalancingFixtureWithBackendDiagnostics() throws {
    let url = legacyFixtureURL("LINEBAL.FL_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBFacilitiesParser.parseLineBalancing(from: expanded)
    let diagnostics = LineBalancingValidator.diagnostics(for: problem)
    let report = ValidationReport(backend: .validateOnly, diagnostics: diagnostics)

    #expect(report.backend == .validateOnly)
    #expect(report.isValid)
    #expect(diagnostics.contains {
        $0.severity == .info && $0.code == "facilities.lineBalancing.valid"
    })
}

@Test func encodesAndSolvesFacilitiesJSONEnvelopes() throws {
    let locationData = try Data(contentsOf: legacyFixtureURL("LOCATION.FL_"))
    let locationExpanded = try LegacyCompressedFile.expandedData(from: locationData)
    let locationEnvelope = try WinQSBFacilitiesParser.parseModelEnvelope(from: locationExpanded)
    let locationJSON = try FacilitiesModelJSON.encodeModel(locationEnvelope)
    let decodedLocationEnvelope = try FacilitiesModelJSON.decodeModel(from: locationJSON)
    #expect(decodedLocationEnvelope == locationEnvelope)
    #expect(decodedLocationEnvelope.kind == .location)

    guard case .location(let locationProblem) = decodedLocationEnvelope else {
        throw FacilitiesModelError.unsupportedFormat
    }
    let locationSolution = try FacilityLocationSolver.solve(locationProblem)
    let locationSolutionDocument = FacilitiesSolutionDocument(
        backend: SolverRunMetadata(
            backendKind: .nativeEducational,
            algorithm: "weightedCentroid",
            exactness: .closedForm
        ),
        solution: .location(locationSolution)
    )
    let locationSolutionJSON = try FacilitiesModelJSON.encodeSolutionDocument(locationSolutionDocument)
    let locationSolutionText = try #require(String(data: locationSolutionJSON, encoding: .utf8))
    let decodedLocationSolutionDocument = try FacilitiesModelJSON.decodeSolutionDocument(from: locationSolutionJSON)
    #expect(abs(locationSolution.objectiveValue - 2008.6923076923076) < 1e-8)
    #expect(decodedLocationSolutionDocument == locationSolutionDocument)
    #expect(locationSolutionText.contains("\"kind\" : \"location\""))
    #expect(locationSolutionText.contains("\"backend\""))
    #expect(locationSolutionText.contains("\"backendKind\" : \"nativeEducational\""))
    #expect(locationSolutionText.contains("\"algorithm\" : \"weightedCentroid\""))
    #expect(locationSolutionText.contains("\"exactness\" : \"closedForm\""))
    #expect(locationSolutionText.contains("\"solution\""))

    let lineBalancingData = try Data(contentsOf: legacyFixtureURL("LINEBAL.FL_"))
    let lineBalancingExpanded = try LegacyCompressedFile.expandedData(from: lineBalancingData)
    let lineBalancingEnvelope = try WinQSBFacilitiesParser.parseModelEnvelope(from: lineBalancingExpanded)
    let lineBalancingJSON = try FacilitiesModelJSON.encodeModel(lineBalancingEnvelope)
    let decodedLineBalancingEnvelope = try FacilitiesModelJSON.decodeModel(from: lineBalancingJSON)
    #expect(decodedLineBalancingEnvelope == lineBalancingEnvelope)
    #expect(decodedLineBalancingEnvelope.kind == .lineBalancing)

    guard case .lineBalancing(let lineBalancingProblem) = decodedLineBalancingEnvelope else {
        throw FacilitiesModelError.unsupportedFormat
    }
    let lineBalancingSolution = try LineBalancingSolver.solve(lineBalancingProblem)
    let lineBalancingSolutionDocument = FacilitiesSolutionDocument(
        backend: SolverRunMetadata(
            backendKind: .nativeEducational,
            algorithm: "bitmaskDynamicProgramming",
            exactness: .fixtureScale
        ),
        solution: .lineBalancing(lineBalancingSolution)
    )
    let lineBalancingSolutionJSON = try FacilitiesModelJSON.encodeSolutionDocument(lineBalancingSolutionDocument)
    let lineBalancingSolutionText = try #require(String(data: lineBalancingSolutionJSON, encoding: .utf8))
    let decodedLineBalancingSolutionDocument = try FacilitiesModelJSON.decodeSolutionDocument(from: lineBalancingSolutionJSON)
    #expect(lineBalancingSolution.stationCount == 5)
    #expect(decodedLineBalancingSolutionDocument == lineBalancingSolutionDocument)
    #expect(lineBalancingSolutionText.contains("\"kind\" : \"lineBalancing\""))
    #expect(lineBalancingSolutionText.contains("\"algorithm\" : \"bitmaskDynamicProgramming\""))
    #expect(lineBalancingSolutionText.contains("\"exactness\" : \"fixtureScale\""))
    #expect(lineBalancingSolutionText.contains("\"solution\""))

    let layoutData = try Data(contentsOf: legacyFixtureURL("LAYOUT.FL_"))
    let layoutExpanded = try LegacyCompressedFile.expandedData(from: layoutData)
    let layoutEnvelope = try WinQSBFacilitiesParser.parseModelEnvelope(from: layoutExpanded)
    let layoutJSON = try FacilitiesModelJSON.encodeModel(layoutEnvelope)
    let decodedLayoutEnvelope = try FacilitiesModelJSON.decodeModel(from: layoutJSON)
    #expect(decodedLayoutEnvelope == layoutEnvelope)
    #expect(decodedLayoutEnvelope.kind == .layout)

    guard case .layout(let layoutProblem) = decodedLayoutEnvelope else {
        throw FacilitiesModelError.unsupportedFormat
    }
    let layoutSolution = try FacilityLayoutSolver.solve(layoutProblem)
    let layoutSolutionDocument = FacilitiesSolutionDocument(
        backend: SolverRunMetadata(
            backendKind: .nativeEducational,
            algorithm: "initialLayoutEvaluation",
            exactness: .fixtureScale
        ),
        solution: .layout(layoutSolution)
    )
    let layoutSolutionJSON = try FacilitiesModelJSON.encodeSolutionDocument(layoutSolutionDocument)
    let layoutSolutionText = try #require(String(data: layoutSolutionJSON, encoding: .utf8))
    let decodedLayoutSolutionDocument = try FacilitiesModelJSON.decodeSolutionDocument(from: layoutSolutionJSON)
    #expect(abs(layoutSolution.objectiveValue - 53552) < 1e-8)
    #expect(decodedLayoutSolutionDocument == layoutSolutionDocument)
    #expect(layoutSolutionText.contains("\"kind\" : \"layout\""))
    #expect(layoutSolutionText.contains("\"algorithm\" : \"initialLayoutEvaluation\""))
    #expect(layoutSolutionText.contains("\"solution\""))
}

@Test func encodesFacilitiesValidationJSONDocuments() throws {
    let lineBalancingData = try Data(contentsOf: legacyFixtureURL("LINEBAL.FL_"))
    let lineBalancingExpanded = try LegacyCompressedFile.expandedData(from: lineBalancingData)
    let lineBalancingEnvelope = try WinQSBFacilitiesParser.parseModelEnvelope(from: lineBalancingExpanded)
    let validDocument = FacilitiesModelJSON.validationDocument(for: lineBalancingEnvelope)
    let validJSON = try FacilitiesModelJSON.encodeValidation(validDocument)
    let validText = try #require(String(data: validJSON, encoding: .utf8))
    let decodedValidDocument = try JSONDecoder().decode(FacilitiesValidationDocument.self, from: validJSON)

    #expect(decodedValidDocument == validDocument)
    #expect(validDocument.kind == .lineBalancing)
    #expect(validDocument.backend == .validateOnly)
    #expect(validDocument.isValid)
    #expect(validText.contains("\"kind\" : \"lineBalancing\""))
    #expect(validText.contains("\"backend\" : \"validateOnly\""))
    #expect(validText.contains("\"isValid\" : true"))
    #expect(validText.contains("\"facilities.lineBalancing.valid\""))

    let invalidProblem = LineBalancingProblem(
        title: "Invalid Line",
        timeUnit: "minute",
        cycleTime: 0,
        tasks: []
    )
    let invalidEnvelope = FacilitiesModelEnvelope.lineBalancing(invalidProblem)
    let invalidDocument = FacilitiesModelJSON.validationDocument(for: invalidEnvelope)
    let invalidJSON = try FacilitiesModelJSON.encodeValidation(invalidDocument)
    let invalidText = try #require(String(data: invalidJSON, encoding: .utf8))
    let decodedInvalidDocument = try JSONDecoder().decode(FacilitiesValidationDocument.self, from: invalidJSON)

    #expect(decodedInvalidDocument == invalidDocument)
    #expect(!invalidDocument.isValid)
    #expect(invalidText.contains("\"isValid\" : false"))
    #expect(invalidText.contains("\"facilities.lineBalancing.tasks.empty\""))
    #expect(invalidText.contains("\"facilities.lineBalancing.cycleTime.positive\""))
}

@Test func routesFacilitiesModelsThroughNamedBackends() throws {
    let lineData = try Data(contentsOf: legacyFixtureURL("LINEBAL.FL_"))
    let lineExpanded = try LegacyCompressedFile.expandedData(from: lineData)
    let lineProblem = try WinQSBFacilitiesParser.parseLineBalancing(from: lineExpanded)

    let locationData = try Data(contentsOf: legacyFixtureURL("LOCATION.FL_"))
    let locationExpanded = try LegacyCompressedFile.expandedData(from: locationData)
    let locationProblem = try WinQSBFacilitiesParser.parseLocation(from: locationExpanded)

    let layoutData = try Data(contentsOf: legacyFixtureURL("LAYOUT.FL_"))
    let layoutExpanded = try LegacyCompressedFile.expandedData(from: layoutData)
    let layoutProblem = try WinQSBFacilitiesParser.parseLayout(from: layoutExpanded)

    let nativeBackend = NativeEducationalFacilitiesBackend()
    #expect(nativeBackend.capabilities.backendKind == .nativeEducational)
    #expect(nativeBackend.capabilities.solves)
    #expect(nativeBackend.capabilities.validates)
    #expect(nativeBackend.capabilities.exportsStructuredSolution)

    let lineSolution = try nativeBackend.solve(lineProblem)
    let locationSolution = try nativeBackend.solve(locationProblem)
    let initialLayout = try nativeBackend.solve(layoutProblem, strategy: .initial)
    let improvedLayout = try nativeBackend.solve(layoutProblem, strategy: .pairwiseSwap)
    #expect(lineSolution.stationCount == 5)
    #expect(abs(locationSolution.objectiveValue - 2008.6923076923076) < 1e-8)
    #expect(abs(initialLayout.objectiveValue - 53552) < 1e-8)
    #expect(abs(improvedLayout.objectiveValue - 48948) < 1e-8)

    #expect(nativeBackend.runMetadata(for: lineProblem).algorithm == "bitmaskDynamicProgramming")
    #expect(nativeBackend.runMetadata(for: locationProblem).exactness == .closedForm)
    #expect(nativeBackend.runMetadata(for: layoutProblem, strategy: .initial).algorithm == "initialLayoutEvaluation")
    #expect(nativeBackend.runMetadata(for: layoutProblem, strategy: .pairwiseSwap).exactness == .heuristic)

    let genericSolution = try nativeBackend.solve(
        FacilitiesModelEnvelope.layout(layoutProblem),
        layoutStrategy: .pairwiseSwap
    )
    guard case .layout(let genericLayout) = genericSolution else {
        Issue.record("Expected generic facilities backend to return a layout solution")
        return
    }
    #expect(abs(genericLayout.objectiveValue - 48948) < 1e-8)

    let validateBackend = ValidateOnlyFacilitiesBackend()
    #expect(validateBackend.capabilities.backendKind == .validateOnly)
    #expect(!validateBackend.capabilities.solves)
    #expect(validateBackend.validationReport(for: lineProblem).isValid)
    #expect(validateBackend.validationReport(for: locationProblem).isValid)
    #expect(validateBackend.validationReport(for: layoutProblem).isValid)

    do {
        _ = try validateBackend.solve(layoutProblem, strategy: .pairwiseSwap)
        Issue.record("Expected validateOnly backend to reject facility-layout solving")
    } catch FacilitiesModelError.invalidModel(let message) {
        #expect(message.contains("validateOnly"))
    }

    let selectedBackend = try #require(FacilitiesBackends.backend(for: .nativeEducational))
    #expect(selectedBackend.capabilities.backendKind == .nativeEducational)
    #expect(FacilitiesBackends.backend(for: .externalHighPerformance) == nil)
}

@Test func parsesAndEvaluatesWinQSBFacilityLayoutFixture() throws {
    let url = legacyFixtureURL("LAYOUT.FL_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBFacilitiesParser.parseLayout(from: expanded)
    let solution = try FacilityLayoutSolver.solve(problem)

    #expect(problem.title == "Shopping Center Layout")
    #expect(problem.rowCount == 9)
    #expect(problem.columnCount == 13)
    #expect(problem.objective == "MIN")
    #expect(problem.departments.count == 17)
    #expect(problem.fixedDepartments.map(\.name) == ["H"])
    #expect(problem.departments[0].flowUnitCosts[1] == 3)
    #expect(problem.departments[0].flowUnitCosts[16] == nil)
    #expect(problem.departments[0].initialLayout == [
        FacilityLayoutRect(startRow: 1, startColumn: 1, endRow: 2, endColumn: 3)
    ])
    #expect(problem.departments[16].initialLayout == [
        FacilityLayoutRect(startRow: 5, startColumn: 1, endRow: 5, endColumn: 13),
        FacilityLayoutRect(startRow: 1, startColumn: 7, endRow: 9, endColumn: 7)
    ])
    let encoded = try FacilityLayoutJSON.encodeModel(problem)
    let decoded = try FacilityLayoutJSON.decodeModel(from: encoded)
    #expect(decoded == problem)

    #expect(solution.source == "initialLayoutEvaluation")
    #expect(abs(solution.objectiveValue - 53552) < 1e-8)
    #expect(solution.placements.count == 17)
    #expect(solution.interactions.count == 240)

    let department6 = try #require(solution.placements.first { $0.departmentName == "6" })
    #expect(department6.cellCount == 9)
    #expect(abs(department6.centroidRow - 6) < 1e-8)
    #expect(abs(department6.centroidColumn - 5) < 1e-8)

    let fixedDepartment = try #require(solution.placements.first { $0.departmentName == "H" })
    #expect(fixedDepartment.fixed)
    #expect(fixedDepartment.cellCount == 21)
    #expect(abs(fixedDepartment.centroidRow - 5) < 1e-8)
    #expect(abs(fixedDepartment.centroidColumn - 7) < 1e-8)
}

@Test func improvesWinQSBFacilityLayoutWithPairwiseSwaps() throws {
    let url = legacyFixtureURL("LAYOUT.FL_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBFacilitiesParser.parseLayout(from: expanded)
    let initial = try FacilityLayoutSolver.solve(problem)
    let improved = try FacilityLayoutSolver.improve(problem)
    let search = try #require(improved.search)
    let solutionJSON = try FacilityLayoutJSON.encodeSolution(improved)
    let solutionText = try #require(String(data: solutionJSON, encoding: .utf8))

    #expect(initial.source == "initialLayoutEvaluation")
    #expect(abs(initial.objectiveValue - 53552) < 1e-8)
    #expect(improved.source == "pairwiseSwapLocalSearch")
    #expect(abs(improved.objectiveValue - 48948) < 1e-8)
    #expect(search.strategy == .pairwiseSwap)
    #expect(search.evaluatedMoveCount == 735)
    #expect(search.appliedMoveCount == 6)
    #expect(abs(search.initialObjectiveValue - 53552) < 1e-8)
    #expect(abs(search.finalObjectiveValue - 48948) < 1e-8)
    #expect(abs(search.improvement - 4604) < 1e-8)
    #expect(improved.moves.map { "\($0.firstDepartmentName):\($0.secondDepartmentName)" } == [
        "D:G",
        "1:7",
        "3:7",
        "4:G",
        "9:B",
        "2:4"
    ])
    #expect(abs(improved.moves.reduce(0) { $0 + $1.improvement } - search.improvement) < 1e-8)

    let fixedDepartment = try #require(improved.placements.first { $0.departmentName == "H" })
    #expect(fixedDepartment.fixed)
    #expect(abs(fixedDepartment.centroidRow - 5) < 1e-8)
    #expect(abs(fixedDepartment.centroidColumn - 7) < 1e-8)

    #expect(solutionText.contains("\"source\" : \"pairwiseSwapLocalSearch\""))
    #expect(solutionText.contains("\"strategy\" : \"pairwiseSwap\""))
    #expect(solutionText.contains("\"moves\""))
    #expect(solutionText.contains("\"kind\" : \"pairwiseSameSizeSwap\""))
}

@Test func validatesWinQSBFacilityLayoutFixtureWithBackendDiagnostics() throws {
    let url = legacyFixtureURL("LAYOUT.FL_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBFacilitiesParser.parseLayout(from: expanded)
    let diagnostics = FacilityLayoutValidator.diagnostics(for: problem)
    let report = ValidationReport(backend: .validateOnly, diagnostics: diagnostics)

    #expect(report.backend == .validateOnly)
    #expect(report.isValid)
    #expect(diagnostics.filter { $0.code == "facilities.layout.initial.fixedOverlap" }.count == 3)
    #expect(diagnostics.contains {
        $0.severity == .info && $0.code == "facilities.layout.valid"
    })
}

