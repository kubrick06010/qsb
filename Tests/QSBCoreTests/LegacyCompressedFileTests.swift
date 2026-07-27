import Foundation
import Testing
@testable import QSBCore

private func legacyFixtureURL(_ filename: String) -> URL {
    legacyReferenceURL()
        .appendingPathComponent(filename)
}

private func legacyReferenceURL() -> URL {
    URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("reference")
        .appendingPathComponent("winqsb")
}

@Test func expandsSZDDLPFixture() throws {
    let url = legacyFixtureURL("LP.LP_")
    let data = try Data(contentsOf: url)

    let file = try LegacyCompressedFile(data: data)
    let text = try #require(file.expandedData.legacyLatin1String)

    #expect(file.expandedSize == 200)
    #expect(text.contains("LP\tMatrixFormat"))
    #expect(text.contains("LP Sample Problem"))
    #expect(text.contains("Maximize"))
}

@Test func inventoriesWinQSBReferenceFixtures() throws {
    let entries = try LegacyFixtureInventory.scanDirectory(at: legacyReferenceURL())
    let entriesByName = Dictionary(uniqueKeysWithValues: entries.map { ($0.fileName, $0) })

    #expect(entries.count > 100)
    #expect(!entries.contains { $0.supportStatus == .unknown })

    let lp = try #require(entriesByName["LP.LP_"])
    #expect(lp.restoredFileName == "LP.LP")
    #expect(lp.compressionFormat == .legacySZDD)
    #expect(lp.extensionCode == "LP")
    #expect(lp.family == "Linear/integer programming")
    #expect(lp.supportStatus == .verified)
    #expect(lp.supportedCommands.contains("qsb solve-lp"))

    let layout = try #require(entriesByName["LAYOUT.FL_"])
    #expect(layout.family == "Facilities and workflow")
    #expect(layout.supportStatus == .verified)
    #expect(layout.supportedCommands.contains("qsb solve-layout"))
    #expect(layout.supportedCommands.contains("qsb solve-facilities-json"))

    let assignment = try #require(entriesByName["ASSIMENT.NE_"])
    #expect(assignment.restoredFileName == "ASSIMENT.NET")
    #expect(assignment.family == "Network models")
    #expect(assignment.supportStatus == .verified)
    #expect(assignment.supportedCommands.contains("qsb solve-assignment"))

    let mm1Queue = try #require(entriesByName["QUEUE1.QA_"])
    #expect(mm1Queue.supportStatus == .verified)
    #expect(mm1Queue.supportedCommands.contains("qsb solve-mm1-json"))
    #expect(mm1Queue.supportedCommands.contains("qsb validate-mm1"))

    let finiteQueue = try #require(entriesByName["QUEUE2.QA_"])
    #expect(finiteQueue.supportStatus == .verified)
    #expect(finiteQueue.supportedCommands.contains("qsb solve-finite-queue-json"))
    #expect(finiteQueue.supportedCommands.contains("qsb validate-finite-queue"))

    for fileName in ["C_CHART.QC_", "P_CHART.QC_", "VARIABLE.QC_", "PARETO.QC_", "PROBPLOT.QC_"] {
        let qualityControl = try #require(entriesByName[fileName])
        #expect(qualityControl.family == "Quality control")
        #expect(qualityControl.supportStatus == .verified)
        #expect(qualityControl.supportedCommands.contains("qsb solve-quality-json"))
    }

    for fileName in ["APLP.AP_", "APSIMPLE.AP_", "APTRP.AP_"] {
        let aggregatePlanning = try #require(entriesByName[fileName])
        #expect(aggregatePlanning.family == "Aggregate planning")
        #expect(aggregatePlanning.supportStatus == .verified)
        #expect(aggregatePlanning.supportedCommands.contains("qsb solve-aggregate-json"))
    }

    let mrp = try #require(entriesByName["QSB.MR_"])
    #expect(mrp.restoredFileName == "QSB.MRP")
    #expect(mrp.family == "Material requirements planning")
    #expect(mrp.supportStatus == .verified)
    #expect(mrp.supportedCommands.contains("qsb solve-mrp-json"))

    for fileName in ["CRSQ.IT_", "CRSS.IT_", "PRRS.IT_", "PRRSS.IT_"] {
        let stochasticInventory = try #require(entriesByName[fileName])
        #expect(stochasticInventory.family == "Inventory theory")
        #expect(stochasticInventory.supportStatus == .verified)
        #expect(stochasticInventory.supportedCommands.contains("qsb solve-stochastic-inventory"))
    }

    for fileName in ["QP.QP_", "QPNORMAL.QP_", "IQP.QP_"] {
        let quadratic = try #require(entriesByName[fileName])
        #expect(quadratic.family == "Quadratic/integer quadratic programming")
        #expect(quadratic.supportStatus == .verified)
        #expect(quadratic.supportedCommands.contains("qsb solve-qp-json"))
    }

    for fileName in ["NLP1.NL_", "NLP2.NL_", "NLP3.NL_"] {
        let nonlinear = try #require(entriesByName[fileName])
        #expect(nonlinear.family == "Nonlinear programming")
        #expect(nonlinear.supportStatus == .verified)
        #expect(nonlinear.supportedCommands.contains("qsb solve-nlp-json"))
    }

    for fileName in ["QSS1.QS_", "QSS2.QS_", "QSS3.QS_", "QSSGRAPH.QS_"] {
        let simulation = try #require(entriesByName[fileName])
        #expect(simulation.family == "Simulation")
        #expect(simulation.supportStatus == .verified)
        #expect(simulation.supportedCommands.contains("qsb solve-simulation-json"))
    }

    let executable = try #require(entriesByName["FLL.EX_"])
    #expect(executable.family == "WinQSB application")
    #expect(executable.role == "application executable")
    #expect(executable.supportStatus == .referenceOnly)

    let json = try LegacyFixtureInventory.encode(entries)
    let text = try #require(String(data: json, encoding: .utf8))
    #expect(text.contains("\"fileName\" : \"LP.LP_\""))
    #expect(text.contains("\"supportStatus\" : \"verified\""))
}

@Test func importsEveryVerifiedLegacyFixtureAsNormalizedJSON() throws {
    let entries = try LegacyFixtureInventory.scanDirectory(at: legacyReferenceURL())
    let verified = entries.filter { $0.supportStatus == .verified }

    #expect(verified.count == 64)
    for entry in verified {
        let result = try LegacyModelImporter.importModel(
            at: legacyFixtureURL(entry.fileName)
        )

        #expect(result.sourceFileName == entry.fileName)
        #expect(result.restoredFileName == entry.restoredFileName)
        try decodeImportedModel(result)
    }
}

@Test func rejectsEveryReferenceOnlyLegacyArtifactAsNonModel() throws {
    let entries = try LegacyFixtureInventory.scanDirectory(at: legacyReferenceURL())
    let referenceOnly = entries.filter { $0.supportStatus == .referenceOnly }

    #expect(referenceOnly.count == 53)
    for entry in referenceOnly {
        do {
            _ = try LegacyModelImporter.importModel(
                at: legacyFixtureURL(entry.fileName)
            )
            Issue.record("Expected \(entry.fileName) to remain reference-only")
        } catch LegacyModelImportError.referenceOnly(let fileName, _) {
            #expect(fileName == entry.fileName)
        } catch {
            Issue.record("Unexpected import error for \(entry.fileName): \(error)")
        }
    }
}

private func decodeImportedModel(_ result: LegacyModelImportResult) throws {
    let data = result.normalizedJSON
    switch result.family {
    case .acceptanceSampling:
        _ = try AcceptanceSamplingJSON.decodeModel(from: data)
    case .aggregatePlanning:
        _ = try AggregatePlanningJSON.decodeModel(from: data)
    case .decisionAnalysis:
        _ = try DecisionAnalysisModelJSON.decodeModel(from: data)
    case .dynamicProgramming:
        _ = try DynamicProgrammingModelJSON.decodeModel(from: data)
    case .facilities:
        _ = try FacilitiesModelJSON.decodeModel(from: data)
    case .forecasting:
        _ = try ForecastingModelJSON.decodeRequest(from: data)
    case .goalProgramming:
        _ = try GoalProgrammingJSON.decodeModel(from: data)
    case .inventory:
        _ = try InventoryModelJSON.decodeModel(from: data)
    case .linearProgramming:
        _ = try LinearProgramJSON.decodeProgram(from: data)
    case .markov:
        _ = try MarkovJSON.decodeRequest(from: data)
    case .materialRequirementsPlanning:
        _ = try MaterialRequirementsPlanningJSON.decodeModel(from: data)
    case .network:
        _ = try NetworkModelJSON.decodeModel(from: data)
    case .nonlinearProgramming:
        _ = try NonlinearProgrammingJSON.decodeModel(from: data)
    case .projectScheduling:
        _ = try ProjectSchedulingJSON.decodeModel(from: data)
    case .quadraticProgramming:
        _ = try QuadraticProgrammingJSON.decodeModel(from: data)
    case .qualityControl:
        _ = try QualityControlJSON.decodeModel(from: data)
    case .queuing:
        _ = try QueuingModelJSON.decodeModel(from: data)
    case .scheduling:
        _ = try SchedulingModelJSON.decodeModel(from: data)
    case .simulation:
        _ = try SimulationJSON.decodeModel(from: data)
    }
}

@Test func exhaustivelyClassifiesCurrentFacilitiesPayload() throws {
    let entries = try LegacyFixtureInventory.scanDirectory(at: legacyReferenceURL())
    let facilitiesPayload = entries.filter {
        $0.fileName.hasPrefix("FLL") || $0.fileName.hasSuffix(".FL_")
    }
    let byName = Dictionary(uniqueKeysWithValues: facilitiesPayload.map { ($0.fileName, $0) })

    #expect(Set(byName.keys) == [
        "FLL.EX_",
        "FLLHELP.HL_",
        "LAYOUT.FL_",
        "LINEBAL.FL_",
        "LOCATION.FL_"
    ])

    for fileName in ["LAYOUT.FL_", "LINEBAL.FL_", "LOCATION.FL_"] {
        let fixture = try #require(byName[fileName])
        #expect(fixture.family == "Facilities and workflow")
        #expect(fixture.role == "verified legacy model fixture")
        #expect(fixture.supportStatus == .verified)
        #expect(fixture.supportedCommands.contains("qsb export-facilities-json"))
        #expect(fixture.supportedCommands.contains("qsb solve-facilities-json"))
    }

    for fileName in ["FLL.EX_", "FLLHELP.HL_"] {
        let artifact = try #require(byName[fileName])
        #expect(artifact.supportStatus == .referenceOnly)
        #expect(artifact.supportedCommands.isEmpty)
    }
}

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

@Test func parsesAndSolvesWinQSBShortestPathFixture() throws {
    let url = legacyFixtureURL("SHTPATH.NE_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let network = try WinQSBNetworkParser.parseShortestPath(from: expanded)
    let solution = try ShortestPathSolver.solve(network)

    #expect(network.nodes.count == 10)
    #expect(network.arcs.count == 20)
    #expect(solution.source == "Node1")
    #expect(solution.sink == "Node10")
    #expect(abs(solution.totalCost - 29) < 1e-8)
    #expect(solution.path == ["Node1", "Node2", "Node5", "Node9", "Node10"])
}

@Test func parsesAndSolvesWinQSBMinimumCostNetworkFlowFixture() throws {
    let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("NETFLOW.NE_")))
    let problem = try WinQSBNetworkParser.parseMinimumCostFlow(from: expanded)
    let model = try WinQSBNetworkParser.parseModelEnvelope(from: expanded)
    let report = ValidateOnlyNetworkBackend().validationReport(for: model)
    let solution = try MinimumCostNetworkFlowSolver.solve(problem)

    #expect(problem.nodes == ["S1", "S2", "T1", "T2", "T3", "T4", "D1", "D2", "D3"])
    #expect(problem.arcs.count == 17)
    #expect(problem.supply.reduce(0, +) == 1950)
    #expect(problem.demand.reduce(0, +) == 2050)
    #expect(report.isValid)
    #expect(report.diagnostics.contains { $0.code == "network.CNF.balance.automatic" && $0.severity == .warning })
    #expect(abs(solution.totalCost - 7900) < 1e-8)
    #expect(solution.balanceAdjustments == [NetworkBalanceAdjustment(node: "D2", quantity: 100, kind: "dummySupply")])
}

@Test func parsesAndSolvesWinQSBCPMMatrixAndGraphicFixtures() throws {
    for fixture in ["CPM.CP_", "CPMGRAPH.CP_"] {
        let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL(fixture)))
        let model = try WinQSBProjectSchedulingParser.parseModelEnvelope(from: expanded)
        let solution = try NativeEducationalProjectSchedulingBackend().solve(model)
        guard case .cpm(let project) = model else { Issue.record("Expected CPM model"); return }

        #expect(project.activities.count == 12)
        #expect(project.activities[0].normalCost == 2000)
        #expect(abs(solution.projectDuration - 34) < 1e-8)
        #expect(solution.criticalActivities == ["C", "F", "J", "L"])
        #expect(solution.totalNormalCost == 30000)
    }
}

@Test func parsesAndSolvesWinQSBPERTMatrixAndGraphicFixtures() throws {
    for fixture in ["PERT.CP_", "PERTGRPH.CP_"] {
        let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL(fixture)))
        let model = try WinQSBProjectSchedulingParser.parseModelEnvelope(from: expanded)
        let solution = try NativeEducationalProjectSchedulingBackend().solve(model)
        guard case .pert(let project) = model else { Issue.record("Expected PERT model"); return }

        #expect(project.activities.count == 12)
        #expect(abs(project.activities[2].expectedTime - 7.833333333333333) < 1e-8)
        #expect(abs(solution.projectDuration - 33.833333333333336) < 1e-8)
        #expect(solution.criticalActivities == ["C", "F", "J", "L"])
        #expect(abs((solution.projectVariance ?? -1) - 1.3611111111111112) < 1e-8)
    }
}

@Test func roundTripsAndValidatesProjectSchedulingBackends() throws {
    for fixture in ["CPM.CP_", "PERT.CP_"] {
        let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL(fixture)))
        let model = try WinQSBProjectSchedulingParser.parseModelEnvelope(from: expanded)
        let encoded = try ProjectSchedulingJSON.encodeModel(model)
        #expect(try ProjectSchedulingJSON.decodeModel(from: encoded) == model)
        let native = NativeEducationalProjectSchedulingBackend()
        let document = native.solutionDocument(for: model, solution: try native.solve(model))
        #expect(try ProjectSchedulingJSON.decodeSolution(from: ProjectSchedulingJSON.encodeSolution(document)) == document)
        #expect(ValidateOnlyProjectSchedulingBackend().validationReport(for: model).isValid)
    }

    let invalid = ProjectSchedulingModelEnvelope.cpm(CPMProject(title: "Cycle", timeUnit: "day", activities: [
        CPMActivity(name: "A", predecessors: ["B"], normalTime: 1, crashTime: 1, normalCost: 0, crashCost: 0),
        CPMActivity(name: "B", predecessors: ["A"], normalTime: 1, crashTime: 1, normalCost: 0, crashCost: 0)
    ]))
    let report = ValidateOnlyProjectSchedulingBackend().validationReport(for: invalid)
    #expect(!report.isValid)
    #expect(report.diagnostics.contains { $0.code == "project.precedence.cycle" })
    #expect(ProjectSchedulingBackends.backend(for: .externalHighPerformance) == nil)
    do {
        _ = try ValidateOnlyProjectSchedulingBackend().solve(invalid)
        Issue.record("validateOnly unexpectedly solved a project model")
    } catch { #expect(String(describing: error).contains("validateOnly")) }
}

@Test func parsesAndSolvesWinQSBMarkovFixtureWithInitialState() throws {
    let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("MKP1.MK_")))
    let model = try WinQSBMarkovParser.parse(from: expanded)
    let request = MarkovAnalysisRequest(model: model, periods: 10)
    let solution = try NativeEducationalMarkovBackend().solve(request)

    #expect(model.states == ["A", "B", "C"])
    #expect(model.initialProbabilities == [0, 1, 0])
    #expect(solution.transientResults.count == 11)
    #expect(solution.transientResults[1].probabilities == [0.4, 0.3, 0.3])
    #expect(abs(solution.stationaryProbabilities[0] - 0.26785714285714285) < 1e-8)
    #expect(abs(solution.stationaryExpectedCost - 3.8464285714285715) < 1e-8)
}

@Test func parsesAndSolvesWinQSBMarkovFixtureWithoutInitialState() throws {
    let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("MKP2.MK_")))
    let model = try WinQSBMarkovParser.parse(from: expanded)
    let solution = try MarkovSolver.solve(MarkovAnalysisRequest(model: model))

    #expect(model.states.count == 4)
    #expect(model.initialProbabilities == nil)
    #expect(solution.transientResults.isEmpty)
    #expect(abs(solution.stationaryProbabilities.reduce(0, +) - 1) < 1e-8)
    #expect(abs(solution.stationaryExpectedCost - 31.432482618771726) < 1e-8)
}

@Test func roundTripsAndValidatesMarkovBackends() throws {
    let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("MKP1.MK_")))
    let request = MarkovAnalysisRequest(model: try WinQSBMarkovParser.parse(from: expanded), periods: 3)
    let encoded = try MarkovJSON.encodeRequest(request)
    #expect(try MarkovJSON.decodeRequest(from: encoded) == request)
    let native = NativeEducationalMarkovBackend()
    let document = native.solutionDocument(for: request, solution: try native.solve(request))
    #expect(try MarkovJSON.decodeSolution(from: MarkovJSON.encodeSolution(document)) == document)
    #expect(ValidateOnlyMarkovBackend().validationReport(for: request).isValid)
    #expect(MarkovBackends.backend(for: .externalHighPerformance) == nil)

    let invalid = MarkovAnalysisRequest(model: MarkovChainModel(
        title: "Invalid", states: ["A", "B"], transitionMatrix: [[0.5, 0.4], [0.2, 0.8]],
        initialProbabilities: [1.2, -0.2], stateCosts: [1, 2]
    ))
    let report = ValidateOnlyMarkovBackend().validationReport(for: invalid)
    #expect(!report.isValid)
    #expect(report.diagnostics.contains { $0.code == "markov.transition.rowSum" })
    #expect(report.diagnostics.contains { $0.code == "markov.initial.probability" })
    do {
        _ = try ValidateOnlyMarkovBackend().solve(request)
        Issue.record("validateOnly unexpectedly solved a Markov request")
    } catch { #expect(String(describing: error).contains("validateOnly")) }
}

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

@Test func parsesAndEvaluatesWinQSBSingleAcceptanceSamplingFixture() throws {
    let model = try WinQSBAcceptanceSamplingParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("ASA1.AS_"))))
    let solution = try NativeEducationalAcceptanceSamplingBackend().solve(model)
    guard case .single(let plan) = model else { Issue.record("Expected single sampling plan"); return }

    #expect(plan.sampleSize == 89)
    #expect(plan.acceptanceNumber == 2)
    #expect(solution.operatingCharacteristic.count == 101)
    #expect(abs(solution.producerRiskAtAQL - 0.06031008168644125) < 1e-8)
    #expect(abs(solution.consumerRiskAtRQL - 0.09186934717218487) < 1e-8)
    #expect(solution.atAQL.averageSampleNumber == 89)
}

@Test func parsesAndEvaluatesWinQSBDoubleAcceptanceSamplingFixture() throws {
    let model = try WinQSBAcceptanceSamplingParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("ASA2.AS_"))))
    let solution = try AcceptanceSamplingSolver.solve(model)
    guard case .double(let plan) = model else { Issue.record("Expected double sampling plan"); return }

    #expect(plan.firstSampleSize == 40)
    #expect(plan.secondSampleSize == 80)
    #expect(plan.cumulativeSecondAcceptanceNumber == 5)
    #expect(abs(solution.producerRiskAtAQL - 0.0009487338644097454) < 1e-8)
    #expect(abs(solution.consumerRiskAtRQL - 0.41007373405511627) < 1e-8)
    #expect(abs(solution.atRQL.averageSampleNumber - 88.91005913444376) < 1e-8)
}

@Test func roundTripsAndValidatesAcceptanceSamplingBackends() throws {
    let model = try WinQSBAcceptanceSamplingParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("ASA1.AS_"))))
    let encoded = try AcceptanceSamplingJSON.encodeModel(model)
    #expect(try AcceptanceSamplingJSON.decodeModel(from: encoded) == model)
    let native = NativeEducationalAcceptanceSamplingBackend()
    let document = native.solutionDocument(for: model, solution: try native.solve(model))
    #expect(try AcceptanceSamplingJSON.decodeSolution(from: AcceptanceSamplingJSON.encodeSolution(document)) == document)
    #expect(ValidateOnlyAcceptanceSamplingBackend().validationReport(for: model).isValid)
    #expect(AcceptanceSamplingBackends.backend(for: .externalHighPerformance) == nil)

    let invalid = AcceptanceSamplingModelEnvelope.single(SingleSamplingPlan(
        title: "Invalid", sampleSize: 10, acceptanceNumber: 10,
        acceptableQualityLevel: 0.1, rejectableQualityLevel: 0.05,
        nominalProducerRisk: 0.05, nominalConsumerRisk: 0.1,
        economics: AcceptanceSamplingEconomics(lotSize: 5, unitSamplingCost: 1, unitInspectionCost: 1, producerDefectiveCost: 1, consumerDefectiveCost: 1)
    ))
    let report = ValidateOnlyAcceptanceSamplingBackend().validationReport(for: invalid)
    #expect(!report.isValid)
    #expect(report.diagnostics.contains { $0.code == "acceptanceSampling.single.acceptanceNumber" })
    #expect(report.diagnostics.contains { $0.code == "acceptanceSampling.qualityLevels" })
    do {
        _ = try ValidateOnlyAcceptanceSamplingBackend().solve(model)
        Issue.record("validateOnly unexpectedly evaluated a sampling plan")
    } catch { #expect(String(describing: error).contains("validateOnly")) }
}

@Test func parsesAndSolvesWinQSBCAndPChartFixtures() throws {
    let cModel = try WinQSBQualityControlParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("C_CHART.QC_"))))
    let pModel = try WinQSBQualityControlParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("P_CHART.QC_"))))

    guard case .cChart(let cChart) = try QualityControlSolver.solve(cModel),
          case .pChart(let pChart) = try QualityControlSolver.solve(pModel) else {
        Issue.record("Expected c-chart and p-chart solutions")
        return
    }
    #expect(cChart.points.count == 26)
    #expect(cChart.outsideLimitIndexes == [6, 20])
    #expect(abs(cChart.points[0].centerLine - 19.846153846153847) < 1e-10)
    #expect(pChart.points.count == 30)
    #expect(pChart.outsideLimitIndexes == [15, 23])
    #expect(abs(pChart.points[0].centerLine - 0.23133333333333334) < 1e-10)
}

@Test func parsesAndSolvesWinQSBXbarRFixture() throws {
    let model = try WinQSBQualityControlParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("VARIABLE.QC_"))))
    guard case .xbarRChart(let solution) = try NativeEducationalQualityControlBackend().solve(model) else {
        Issue.record("Expected an Xbar-R solution")
        return
    }
    #expect(solution.meanChart.points.count == 50)
    #expect(abs(solution.grandMean - 74.001524) < 1e-9)
    #expect(abs(solution.averageRange - 0.02758) < 1e-9)
    #expect(solution.meanChart.outsideLimitIndexes == [28, 29, 36, 48])
    #expect(solution.rangeChart.outsideLimitIndexes == [28, 29, 36, 48])
}

@Test func parsesAndSolvesWinQSBParetoFixture() throws {
    let model = try WinQSBQualityControlParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("PARETO.QC_"))))
    guard case .pareto(let solution) = try QualityControlSolver.solve(model) else {
        Issue.record("Expected a Pareto solution")
        return
    }
    #expect(solution.totalCount == 152)
    #expect(solution.categories.map(\.name) == ["Bent Pins", "Misaligned", "Broken", "Miscellaneous", "Missing"])
    #expect(solution.categories.map(\.count) == [77, 28, 18, 16, 13])
    #expect(abs(solution.categories.last!.cumulativePercentage - 1) < 1e-12)
}

@Test func parsesAndSolvesWinQSBNormalProbabilityPlotFixture() throws {
    let model = try WinQSBQualityControlParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("PROBPLOT.QC_"))))
    guard case .normalProbabilityPlot(let solution) = try QualityControlSolver.solve(model) else {
        Issue.record("Expected a normal probability plot solution")
        return
    }
    #expect(solution.points.count == 20)
    #expect(abs(solution.mean - 10.0065) < 1e-10)
    #expect(abs(solution.sampleStandardDeviation - 0.33427494198953245) < 1e-10)
    #expect(abs(solution.correlation - 0.9994166884040918) < 1e-10)
}

@Test func roundTripsAndValidatesQualityControlBackends() throws {
    let model = try WinQSBQualityControlParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("C_CHART.QC_"))))
    #expect(try QualityControlJSON.decodeModel(from: QualityControlJSON.encodeModel(model)) == model)
    let native = NativeEducationalQualityControlBackend()
    let solution = try native.solve(model)
    let document = native.solutionDocument(for: model, solution: solution)
    #expect(try QualityControlJSON.decodeSolution(from: QualityControlJSON.encodeSolution(document)) == document)
    #expect(ValidateOnlyQualityControlBackend().validationReport(for: model).isValid)
    #expect(QualityControlBackends.backend(for: .externalHighPerformance) == nil)

    let invalid = QualityControlModelEnvelope.pChart(PChartModel(title: "Invalid", characteristic: "Defects", sampleSizes: [0], proportions: [1.2]))
    let report = ValidateOnlyQualityControlBackend().validationReport(for: invalid)
    #expect(!report.isValid)
    #expect(report.diagnostics.contains { $0.code == "qualityControl.pChart.values" })
    do {
        _ = try ValidateOnlyQualityControlBackend().solve(model)
        Issue.record("validateOnly unexpectedly solved a quality-control model")
    } catch {
        #expect(String(describing: error).contains("validateOnly"))
    }
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

@Test func parsesAndSolvesWinQSBAggregatePlanningWorkforceFixtures() throws {
    let lpModel = try WinQSBAggregatePlanningParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("APLP.AP_"))))
    let simpleModel = try WinQSBAggregatePlanningParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("APSIMPLE.AP_"))))
    let backend = NativeEducationalAggregatePlanningBackend()
    let lpSolution = try backend.solve(lpModel)
    let simpleSolution = try backend.solve(simpleModel)

    #expect(lpModel.method == .linearProgramming)
    #expect(simpleModel.method == .simple)
    #expect(lpModel.demand == simpleModel.demand)
    #expect(lpModel.capacityRequirementPerUnit == Array(repeating: 5, count: 6))
    #expect(simpleModel.capacityRequirementPerUnit == Array(repeating: 5, count: 6))
    #expect(abs(lpSolution.totalCost - 165_355.95238095237) < 1e-7)
    #expect(abs(simpleSolution.totalCost - lpSolution.totalCost) < 1e-7)
    #expect(abs((lpSolution.periods[2].workforce ?? -1) - 29.761904761904763) < 1e-9)
    #expect(abs(lpSolution.periods[5].subcontracted - 725) < 1e-9)
    #expect(lpSolution.periods.allSatisfy { abs($0.endingBackorder) < 1e-9 })
    try expectAggregatePlanningBalances(model: lpModel, solution: lpSolution)
}

@Test func parsesAndSolvesWinQSBAggregatePlanningTransportationFixture() throws {
    let model = try WinQSBAggregatePlanningParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("APTRP.AP_"))))
    let solution = try AggregatePlanningSolver.solve(model)
    #expect(model.method == .transportation)
    #expect(!model.capacityIsPerWorker)
    #expect(abs(solution.totalCost - 4_100) < 1e-9)
    #expect(solution.periods.map(\.regularProduction) == [450, 450, 750, 450])
    #expect(solution.periods.map(\.overtimeProduction) == [90, 90, 150, 90])
    #expect(solution.periods.map(\.subcontracted) == [20, 200, 200, 110])
    #expect(solution.periods.map(\.endingInventory) == [510, 400, 0, 300])
    try expectAggregatePlanningBalances(model: model, solution: solution)
}

@Test func roundTripsAndValidatesAggregatePlanningBackends() throws {
    let model = try WinQSBAggregatePlanningParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("APTRP.AP_"))))
    #expect(try AggregatePlanningJSON.decodeModel(from: AggregatePlanningJSON.encodeModel(model)) == model)
    let native = NativeEducationalAggregatePlanningBackend()
    let solution = try native.solve(model)
    let document = native.solutionDocument(for: model, solution: solution)
    #expect(try AggregatePlanningJSON.decodeSolution(from: AggregatePlanningJSON.encodeSolution(document)) == document)
    #expect(ValidateOnlyAggregatePlanningBackend().validationReport(for: model).isValid)
    #expect(AggregatePlanningBackends.backend(for: .externalHighPerformance) == nil)

    let invalid = AggregatePlanningModel(
        title: model.title, method: model.method, periodNames: model.periodNames,
        workforceUnit: model.workforceUnit, capacityUnit: model.capacityUnit,
        demand: model.demand, initialWorkforce: model.initialWorkforce, initialInventory: model.initialInventory,
        regularCapacity: model.regularCapacity, regularCost: model.regularCost,
        undertimeCost: model.undertimeCost, overtimeCapacity: model.overtimeCapacity,
        overtimeCost: model.overtimeCost, hiringCost: model.hiringCost,
        dismissalCost: model.dismissalCost, maximumWorkforce: model.maximumWorkforce,
        minimumWorkforce: model.minimumWorkforce, maximumInventory: model.maximumInventory,
        minimumInventory: model.minimumInventory, inventoryHoldingCost: model.inventoryHoldingCost,
        maximumSubcontracting: model.maximumSubcontracting, subcontractingCost: model.subcontractingCost,
        maximumBackorder: model.maximumBackorder, backorderCost: model.backorderCost,
        otherUnitProductionCost: model.otherUnitProductionCost,
        capacityRequirementPerUnit: [0, 1, 1, 1], capacityIsPerWorker: model.capacityIsPerWorker
    )
    let report = ValidateOnlyAggregatePlanningBackend().validationReport(for: invalid)
    #expect(!report.isValid)
    #expect(report.diagnostics.contains { $0.code == "aggregatePlanning.capacityRequirement" })
    do {
        _ = try ValidateOnlyAggregatePlanningBackend().solve(model)
        Issue.record("validateOnly unexpectedly solved an aggregate-planning model")
    } catch {
        #expect(String(describing: error).contains("validateOnly"))
    }
}

private func expectAggregatePlanningBalances(model: AggregatePlanningModel, solution: AggregatePlanningSolution) throws {
    var priorNetInventory = model.initialInventory
    for index in model.periodNames.indices {
        let period = solution.periods[index]
        let available = priorNetInventory + period.regularProduction + period.overtimeProduction + period.subcontracted
        let endingNetInventory = period.endingInventory - period.endingBackorder
        #expect(abs(available - model.demand[index] - endingNetInventory) < 1e-7)
        priorNetInventory = endingNetInventory
    }
}

@Test func parsesWinQSBMaterialRequirementsPlanningFixture() throws {
    let model = try legacyMRPModel()
    #expect(model.title == "MRP Example Problem")
    #expect(model.bucketNames == ["Overdue"] + (1...12).map { "Week \($0)" })
    #expect(model.items.count == 7)
    #expect(Set(model.items.map(\.lotSizingRule)) == [.lotForLot, .economicOrderQuantity, .leastUnitCost, .leastTotalCost, .partPeriodBalancing])

    let a100 = try #require(model.items.first { $0.identifier == "A100" })
    #expect(a100.safetyStock == 50)
    #expect(a100.initialOnHand == 75)
    #expect(a100.scheduledReceipts == [0, 0, 50, 0, 70, 0, 0, 0, 0, 0, 0, 0, 0])
    #expect(a100.capacity == [nil, 120, 120, 120, 120, 120, 150, 150, 150, 150, 100, 100, 100])

    let aBill = try #require(model.billsOfMaterial.first { $0.parentIdentifier == "A100" })
    #expect(aBill.components == [MRPComponent(itemIdentifier: "C200", quantityPerParent: 1), MRPComponent(itemIdentifier: "D200", quantityPerParent: 1), MRPComponent(itemIdentifier: "F300", quantityPerParent: 3)])
}

@Test func explodesWinQSBMaterialRequirementsAcrossAllLevels() throws {
    let model = try legacyMRPModel()
    let solution = try NativeEducationalMaterialRequirementsPlanningBackend().solve(model)
    #expect(solution.schedules.count == 7)
    let schedules = Dictionary(uniqueKeysWithValues: solution.schedules.map { ($0.itemIdentifier, $0) })
    let a = try #require(schedules["A100"]), b = try #require(schedules["B100"])
    let c = try #require(schedules["C200"]), d = try #require(schedules["D200"])
    let e = try #require(schedules["E200"]), f = try #require(schedules["F300"]), g = try #require(schedules["G300"])

    #expect(a.grossRequirements.reduce(0, +) == 1_030)
    #expect(a.plannedOrderReceipts.reduce(0, +) == 885)
    #expect(a.plannedOrderReleases == [0, 0, 0, 0, 0, 0, 275, 0, 300, 0, 240, 70, 0])
    #expect(b.plannedOrderReleases.reduce(0, +) == 615)
    #expect(c.grossRequirements.reduce(0, +) == 2_205)
    #expect(d.grossRequirements.reduce(0, +) == 1_570)
    #expect(e.grossRequirements.reduce(0, +) == 660)
    #expect(f.grossRequirements.reduce(0, +) == 5_844)
    #expect(g.grossRequirements.reduce(0, +) == 4_978)
    #expect(c.plannedOrderReceipts.reduce(0, +) == 1_885)
    #expect(f.plannedOrderReceipts.reduce(0, +) == 5_995)
    #expect(g.plannedOrderReceipts.reduce(0, +) == 5_527)
    #expect(a.capacityExcess.reduce(0, +) == 415)
    #expect(solution.schedules.allSatisfy { schedule in schedule.projectedOnHand.allSatisfy { $0 >= -1e-9 } })
}

@Test func roundTripsAndValidatesMaterialRequirementsPlanningBackends() throws {
    let model = try legacyMRPModel()
    #expect(try MaterialRequirementsPlanningJSON.decodeModel(from: MaterialRequirementsPlanningJSON.encodeModel(model)) == model)
    let native = NativeEducationalMaterialRequirementsPlanningBackend()
    let solution = try native.solve(model)
    let document = native.solutionDocument(for: model, solution: solution)
    #expect(try MaterialRequirementsPlanningJSON.decodeSolution(from: MaterialRequirementsPlanningJSON.encodeSolution(document)) == document)
    #expect(native.runMetadata(for: model).exactness == .heuristic)
    #expect(ValidateOnlyMaterialRequirementsPlanningBackend().validationReport(for: model).isValid)
    #expect(MaterialRequirementsPlanningBackends.backend(for: .externalHighPerformance) == nil)

    let cycle = MaterialRequirementsPlanningModel(title: model.title, timeUnit: model.timeUnit, periodsPerYear: model.periodsPerYear, bucketNames: model.bucketNames, items: model.items, billsOfMaterial: model.billsOfMaterial + [MRPBillOfMaterial(parentIdentifier: "G300", components: [MRPComponent(itemIdentifier: "A100", quantityPerParent: 1)])], masterProductionSchedule: model.masterProductionSchedule)
    let report = ValidateOnlyMaterialRequirementsPlanningBackend().validationReport(for: cycle)
    #expect(!report.isValid)
    #expect(report.diagnostics.contains { $0.code == "mrp.bomCycle" })
    let duplicateParent = MaterialRequirementsPlanningModel(title: model.title, timeUnit: model.timeUnit, periodsPerYear: model.periodsPerYear, bucketNames: model.bucketNames, items: model.items, billsOfMaterial: model.billsOfMaterial + [model.billsOfMaterial[0]], masterProductionSchedule: model.masterProductionSchedule)
    #expect(ValidateOnlyMaterialRequirementsPlanningBackend().validationReport(for: duplicateParent).diagnostics.contains { $0.code == "mrp.bomParent" })
    do {
        _ = try ValidateOnlyMaterialRequirementsPlanningBackend().solve(model)
        Issue.record("validateOnly unexpectedly exploded an MRP model")
    } catch {
        #expect(String(describing: error).contains("validateOnly"))
    }
}

private func legacyMRPModel() throws -> MaterialRequirementsPlanningModel {
    try WinQSBMaterialRequirementsPlanningParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("QSB.MR_"))))
}

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

@Test func parsesAndSimulatesWinQSSTwoServerQueueFixtures() throws {
    let exponential = try legacySimulation("QSS1.QS_")
    let constant = try legacySimulation("QSS2.QS_")
    #expect(exponential.representation == .matrix)
    #expect(exponential.components.count == 4)
    #expect(constant.components.count == 4)
    #expect(exponential.components.filter { $0.kind == .server }.count == 2)
    let first = try DiscreteEventSimulationSolver.solve(exponential, horizon: 100, seed: 7)
    let repeatRun = try DiscreteEventSimulationSolver.solve(exponential, horizon: 100, seed: 7)
    let second = try DiscreteEventSimulationSolver.solve(constant, horizon: 100, seed: 7)
    #expect(first == repeatRun)
    #expect(first.generatedEntities > 50)
    #expect(first.completedEntities > 0)
    #expect(second.serverMetrics.reduce(0) { $0 + $1.completed } > 0)
}

@Test func parsesAndSimulatesEquivalentWinQSSAssemblyRepresentations() throws {
    let matrix = try legacySimulation("QSS3.QS_")
    let graphic = try legacySimulation("QSSGRAPH.QS_")
    #expect(matrix.representation == .matrix)
    #expect(graphic.representation == .graphic)
    #expect(matrix.components.count == 13)
    #expect(graphic.components.count == 13)
    #expect(Set(matrix.components.map { $0.name.lowercased() }) == Set(graphic.components.map { $0.name.lowercased() }))
    let matrixSolution = try DiscreteEventSimulationSolver.solve(matrix, horizon: 200, seed: 11)
    let graphicSolution = try DiscreteEventSimulationSolver.solve(graphic, horizon: 200, seed: 11)
    #expect(matrixSolution.serverMetrics.first { $0.name == "Station 5" }?.completed ?? 0 > 0)
    #expect(graphicSolution.serverMetrics.first { $0.name == "Station 5" }?.completed ?? 0 > 0)
}

@Test func roundTripsAndValidatesSimulationBackends() throws {
    let model = try legacySimulation("QSS3.QS_")
    #expect(try SimulationJSON.decodeModel(from: SimulationJSON.encodeModel(model)) == model)
    let native = NativeEducationalSimulationBackend()
    let solution = try native.solve(model, options: SolverOptions(timeLimitSeconds: 100, randomSeed: 3))
    let solutionJSON = try SimulationJSON.encodeSolution(native.solutionDocument(for: model, solution: solution))
    #expect(String(decoding: solutionJSON, as: UTF8.self).contains("seededDiscreteEventSimulation"))
    #expect(ValidateOnlySimulationBackend().validationReport(for: model).isValid)
    #expect(SimulationBackends.backend(for: .externalHighPerformance) == nil)
    #expect(throws: SimulationError.self) { _ = try ValidateOnlySimulationBackend().solve(model) }
}

private func legacySimulation(_ filename: String) throws -> SimulationModel {
    try WinQSBSimulationParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL(filename))))
}

@Test func roundTripsNormalizedSchedulingModelsAndBackends() throws {
    let fixtures = ["FLOWSHOP.JO_", "JOBSHOP.JO_"]
    let native = NativeEducationalSchedulingBackend()
    let validate = ValidateOnlySchedulingBackend()
    for fixture in fixtures {
        let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL(fixture)))
        let model = try WinQSBSchedulingParser.parseModelEnvelope(from: expanded)
        let decoded = try SchedulingModelJSON.decodeModel(from: SchedulingModelJSON.encodeModel(model))
        #expect(decoded == model)
        #expect(validate.validationReport(for: model).isValid)
        let document = try native.solve(model)
        #expect(document.makespan > 0)
        #expect(String(decoding: try SchedulingModelJSON.encodeSolution(document), as: UTF8.self).contains("machineTimelines"))
    }
    #expect(SchedulingBackends.backend(for: .externalHighPerformance) == nil)
}

@Test func roundTripsNormalizedQueuingModelsAndBackends() throws {
    let fixtures = ["QUEUE1.QA_", "QUEUE2.QA_"]
    let native = NativeEducationalQueuingBackend()
    let validate = ValidateOnlyQueuingBackend()
    for fixture in fixtures {
        let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL(fixture)))
        let model = try WinQSBQueuingParser.parseModelEnvelope(from: expanded)
        let decoded = try QueuingModelJSON.decodeModel(from: QueuingModelJSON.encodeModel(model))
        #expect(decoded == model)
        #expect(validate.validationReport(for: model).isValid)
        let document = try native.solve(model)
        #expect(document.metrics.utilization > 0)
        #expect(String(decoding: try QueuingModelJSON.encodeSolution(document), as: UTF8.self).contains("metrics"))
    }
    #expect(QueuingBackends.backend(for: .externalHighPerformance) == nil)
}

@Test func parsesAndSolvesWinQSBMinimumSpanningTreeFixture() throws {
    let url = legacyFixtureURL("SPANTREE.NE_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let network = try WinQSBNetworkParser.parseMinimumSpanningTree(from: expanded)
    let solution = try MinimumSpanningTreeSolver.solve(network)

    #expect(network.nodes.count == 10)
    #expect(network.edges.count == 20)
    #expect(abs(solution.totalCost - 68) < 1e-8)
    #expect(solution.edges.count == 9)
    #expect(Set(solution.edges.map { "\($0.from)-\($0.to)" }).isSuperset(of: [
        "Node1-Node2",
        "Node1-Node4",
        "Node2-Node5",
        "Node4-Node6",
        "Node7-Node8",
        "Node1-Node3",
        "Node4-Node7",
        "Node9-Node10",
        "Node5-Node9"
    ]))
}

@Test func parsesAndSolvesWinQSBMaxFlowFixture() throws {
    let url = legacyFixtureURL("MAXFLOW.NE_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let network = try WinQSBNetworkParser.parseMaxFlow(from: expanded)
    let solution = try MaxFlowSolver.solve(network)

    #expect(network.nodes.count == 7)
    #expect(network.arcs.count == 23)
    #expect(solution.source == "Node1")
    #expect(solution.sink == "Node7")
    #expect(abs(solution.maxFlow - 30) < 1e-8)
}

@Test func parsesAndSolvesWinQSBTravelingSalespersonFixture() throws {
    let url = legacyFixtureURL("TSP.NE_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBNetworkParser.parseTravelingSalesperson(from: expanded)
    let solution = try TravelingSalespersonSolver.solve(problem)

    #expect(problem.nodes == ["LA", "DEV", "HOU", "DAL", "CMH", "NY"])
    #expect(problem.arcs.count == 26)
    #expect(solution.source == "LA")
    #expect(abs(solution.totalCost - 1130) < 1e-8)
    #expect(solution.tour == ["LA", "HOU", "NY", "CMH", "DAL", "DEV", "LA"])
}

@Test func parsesAndSolvesWinQSBAssignmentFixture() throws {
    let url = legacyFixtureURL("ASSIMENT.NE_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBNetworkParser.parseAssignment(from: expanded)
    let solution = try AssignmentSolver.solve(problem)

    #expect(problem.workers == ["John", "Peter", "Toshi", "Rudy"])
    #expect(problem.tasks == ["A", "B", "C", "D"])
    #expect(abs(solution.totalCost - 20) < 1e-8)
    #expect(solution.assignments == [
        AssignmentPair(worker: "John", task: "B", cost: 6),
        AssignmentPair(worker: "Peter", task: "C", cost: 3),
        AssignmentPair(worker: "Toshi", task: "A", cost: 2),
        AssignmentPair(worker: "Rudy", task: "D", cost: 9)
    ])
}

@Test func solvesRectangularAssignmentProblem() throws {
    let problem = AssignmentProblem(
        title: "Rectangular Assignment",
        workers: ["W1", "W2", "W3"],
        tasks: ["A", "B", "C", "D", "E"],
        costs: [
            [9, 2, 7, 8, 6],
            [6, 4, 3, 7, 5],
            [5, 8, 1, 8, 3]
        ]
    )

    let solution = try AssignmentSolver.solve(problem)

    #expect(abs(solution.totalCost - 8) < 1e-8)
    #expect(solution.assignments == [
        AssignmentPair(worker: "W1", task: "B", cost: 2),
        AssignmentPair(worker: "W2", task: "C", cost: 3),
        AssignmentPair(worker: "W3", task: "E", cost: 3)
    ])
}

@Test func parsesAndSolvesWinQSBTransportationFixture() throws {
    let url = legacyFixtureURL("TRNSPORT.NE_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBNetworkParser.parseTransportation(from: expanded)
    let solution = try TransportationSolver.solve(problem)

    #expect(problem.origins == ["Boston", "Denver", "Austin"])
    #expect(problem.destinations == ["Dallas", "Kansas", "Tampa", "Miami"])
    #expect(problem.supply == [100, 200, 400])
    #expect(problem.demand == [200, 100, 150, 250])
    #expect(abs(solution.totalCost - 3350) < 1e-8)
    #expect(solution.shipments == [
        TransportationShipment(origin: "Boston", destination: "Tampa", quantity: 50, unitCost: 5),
        TransportationShipment(origin: "Boston", destination: "Miami", quantity: 50, unitCost: 6),
        TransportationShipment(origin: "Denver", destination: "Miami", quantity: 200, unitCost: 6),
        TransportationShipment(origin: "Austin", destination: "Dallas", quantity: 200, unitCost: 2),
        TransportationShipment(origin: "Austin", destination: "Kansas", quantity: 100, unitCost: 5),
        TransportationShipment(origin: "Austin", destination: "Tampa", quantity: 100, unitCost: 7)
    ])
}

@Test func validatesWinQSBTransportationFixtureWithBackendDiagnostics() throws {
    let url = legacyFixtureURL("TRNSPORT.NE_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBNetworkParser.parseTransportation(from: expanded)
    let diagnostics = TransportationValidator.diagnostics(for: problem)
    let report = ValidationReport(backend: .validateOnly, diagnostics: diagnostics)

    #expect(report.backend == .validateOnly)
    #expect(report.isValid)
    #expect(diagnostics.contains {
        $0.severity == .info && $0.code == "network.transportation.valid"
    })
}

@Test func parsesAndSolvesWinQSBRegressionFixture() throws {
    let url = legacyFixtureURL("LINEREG.FC_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let model = try WinQSBForecastingParser.parseRegression(from: expanded)
    let solution = try RegressionSolver.solve(model)

    #expect(model.title == "QSB P.320")
    #expect(model.dependentVariable == "Utility")
    #expect(model.independentVariables == ["Temperature", "Insulation"])
    #expect(model.observations.count == 15)
    #expect(abs(solution.intercept - -79.74016339) < 1e-6)
    #expect(abs((solution.coefficients["Temperature"] ?? 0) - 3.12107883) < 1e-6)
    #expect(abs((solution.coefficients["Insulation"] ?? 0) - -1.16911892) < 1e-6)
    #expect(abs(solution.sumSquaredErrors - 945.0928939790944) < 1e-6)
    #expect(abs(solution.rSquared - 0.9036199052397135) < 1e-8)
}

@Test func parsesAndSolvesWinQSBTimeSeriesFixture() throws {
    let url = legacyFixtureURL("SALES.FC_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let model = try WinQSBForecastingParser.parseTimeSeries(from: expanded)
    let solution = try TimeSeriesTrendSolver.solve(model, periodsAhead: 2)

    #expect(model.title == "Sales")
    #expect(model.timeUnit == "month")
    #expect(model.valueName == "Historical Data")
    #expect(model.observations.count == 24)
    #expect(model.observations[0] == TimeSeriesObservation(label: "1", value: 398))
    #expect(model.observations[23] == TimeSeriesObservation(label: "24", value: 580))
    #expect(abs(solution.intercept - 364.00724637681157) < 1e-8)
    #expect(abs(solution.slope - 7.8560869565217395) < 1e-8)
    #expect(abs(solution.meanActual - 462.2083333333333) < 1e-8)
    #expect(abs(solution.meanAbsoluteDeviation - 19.660398550724647) < 1e-8)
    #expect(abs(solution.meanSquaredError - 763.5058635265701) < 1e-8)
    #expect(abs((solution.meanAbsolutePercentageError ?? 0) - 4.756017322660986) < 1e-8)
    #expect(abs(solution.fittedValues[0].fitted - 371.8633333333333) < 1e-8)
    #expect(abs(solution.fittedValues[23].residual - 27.446666666666715) < 1e-8)
    #expect(solution.forecasts[0].label == "month 25")
    #expect(abs(solution.forecasts[0].value - 560.409420289855) < 1e-8)
    #expect(solution.forecasts[1].label == "month 26")
    #expect(abs(solution.forecasts[1].value - 568.2655072463767) < 1e-8)
}

@Test func solvesWinQSBTimeSeriesMovingAverageFixture() throws {
    let url = legacyFixtureURL("SALES.FC_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let model = try WinQSBForecastingParser.parseTimeSeries(from: expanded)
    let solution = try TimeSeriesMovingAverageSolver.solve(model, windowSize: 3, periodsAhead: 2)

    #expect(solution.windowSize == 3)
    #expect(solution.fittedValues.count == 21)
    #expect(solution.fittedValues[0].label == "4")
    #expect(abs(solution.fittedValues[0].fitted - 361) < 1e-8)
    #expect(abs(solution.fittedValues[0].residual - 39) < 1e-8)
    #expect(abs(solution.fittedValues[20].fitted - 536.6666666666666) < 1e-8)
    #expect(abs(solution.fittedValues[20].residual - 43.33333333333337) < 1e-8)
    #expect(abs(solution.meanAbsoluteDeviation - 27.333333333333332) < 1e-8)
    #expect(abs(solution.meanSquaredError - 1038.1269841269839) < 1e-8)
    #expect(abs((solution.meanAbsolutePercentageError ?? 0) - 5.787621607603826) < 1e-8)
    #expect(solution.forecasts[0].label == "month 25")
    #expect(abs(solution.forecasts[0].value - 561.6666666666666) < 1e-8)
    #expect(solution.forecasts[1].label == "month 26")
    #expect(abs(solution.forecasts[1].value - 565.5555555555555) < 1e-8)
}

@Test func solvesWinQSBTimeSeriesExponentialSmoothingFixture() throws {
    let url = legacyFixtureURL("SALES.FC_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let model = try WinQSBForecastingParser.parseTimeSeries(from: expanded)
    let solution = try TimeSeriesExponentialSmoothingSolver.solve(model, alpha: 0.3, periodsAhead: 2)

    #expect(abs(solution.alpha - 0.3) < 1e-8)
    #expect(solution.initialForecast == 398)
    #expect(solution.fittedValues.count == 23)
    #expect(solution.fittedValues[0].label == "2")
    #expect(abs(solution.fittedValues[0].fitted - 398) < 1e-8)
    #expect(abs(solution.fittedValues[0].residual - -3) < 1e-8)
    #expect(abs(solution.fittedValues[22].fitted - 525.8154718472708) < 1e-8)
    #expect(abs(solution.fittedValues[22].residual - 54.18452815272917) < 1e-8)
    #expect(abs(solution.meanAbsoluteDeviation - 33.06544413695933) < 1e-8)
    #expect(abs(solution.meanSquaredError - 1584.054281714657) < 1e-8)
    #expect(abs((solution.meanAbsolutePercentageError ?? 0) - 7.548062767326426) < 1e-8)
    #expect(solution.forecasts[0].label == "month 25")
    #expect(abs(solution.forecasts[0].value - 542.0708302930896) < 1e-8)
    #expect(solution.forecasts[1].label == "month 26")
    #expect(abs(solution.forecasts[1].value - 542.0708302930896) < 1e-8)
}

@Test func solvesWinQSBTimeSeriesSeasonalFixture() throws {
    let url = legacyFixtureURL("SALES.FC_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let model = try WinQSBForecastingParser.parseTimeSeries(from: expanded)
    let solution = try TimeSeriesSeasonalDecompositionSolver.solve(model, seasonLength: 12, periodsAhead: 2)

    #expect(solution.seasonLength == 12)
    #expect(abs(solution.intercept - 364.00724637681157) < 1e-8)
    #expect(abs(solution.slope - 7.8560869565217395) < 1e-8)
    #expect(abs(solution.meanActual - 462.2083333333333) < 1e-8)
    #expect(solution.seasonalFactors.count == 12)
    #expect(abs(solution.seasonalFactors[0].factor - 1.0499924580475422) < 1e-8)
    #expect(abs(solution.seasonalFactors[2].factor - 0.864921337178654) < 1e-8)
    #expect(abs(solution.seasonalFactors[11].factor - 1.0376019214236234) < 1e-8)
    #expect(abs(solution.fittedValues[0].fitted - 390.45369542441915) < 1e-8)
    #expect(abs(solution.fittedValues[0].residual - 7.546304575580848) < 1e-8)
    #expect(abs(solution.fittedValues[23].fitted - 573.3304003556945) < 1e-8)
    #expect(abs(solution.fittedValues[23].residual - 6.669599644305549) < 1e-8)
    #expect(abs(solution.meanAbsoluteDeviation - 13.815133582745851) < 1e-8)
    #expect(abs(solution.meanSquaredError - 356.955914221362) < 1e-8)
    #expect(abs((solution.meanAbsolutePercentageError ?? 0) - 3.256967972141938) < 1e-8)
    #expect(solution.forecasts[0].label == "month 25")
    #expect(abs(solution.forecasts[0].value - 588.425664723143) < 1e-8)
    #expect(solution.forecasts[1].label == "month 26")
    #expect(abs(solution.forecasts[1].value - 574.2974425729508) < 1e-8)
}

@Test func roundTripsNormalizedForecastingRequestsAndSolutions() throws {
    let sales = try WinQSBForecastingParser.parseModelEnvelope(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("SALES.FC_"))))
    let regression = try WinQSBForecastingParser.parseModelEnvelope(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("LINEREG.FC_"))))
    let requests = [
        ForecastingRequest(model: sales, method: .linearTrend, periodsAhead: 2),
        ForecastingRequest(model: sales, method: .movingAverage, periodsAhead: 2, windowSize: 3),
        ForecastingRequest(model: sales, method: .exponentialSmoothing, periodsAhead: 2, alpha: 0.3),
        ForecastingRequest(model: sales, method: .multiplicativeSeasonalDecomposition, periodsAhead: 2, seasonLength: 12),
        ForecastingRequest(model: regression, method: .ordinaryLeastSquares)
    ]
    let backend = NativeEducationalForecastingBackend()
    for request in requests {
        let encodedRequest = try ForecastingModelJSON.encodeRequest(request)
        #expect(try ForecastingModelJSON.decodeRequest(from: encodedRequest) == request)
        let solution = try backend.solve(request)
        #expect(solution.method == request.method)
        let document = backend.solutionDocument(for: request, solution: solution)
        let encodedSolution = try ForecastingModelJSON.encodeSolutionDocument(document)
        #expect(try ForecastingModelJSON.decodeSolutionDocument(from: encodedSolution) == document)
    }
}

@Test func routesForecastingThroughNamedBackendsAndStructuredValidation() throws {
    let model = try WinQSBForecastingParser.parseModelEnvelope(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("SALES.FC_"))))
    let valid = ForecastingRequest(model: model, method: .movingAverage, windowSize: 3)
    let invalid = ForecastingRequest(model: model, method: .movingAverage, windowSize: 24)
    let native = NativeEducationalForecastingBackend()
    let validateOnly = ValidateOnlyForecastingBackend()

    #expect(native.runMetadata(for: valid).algorithm == "movingAverage")
    #expect(native.runMetadata(for: valid).exactness == .approximate)
    #expect(validateOnly.validationReport(for: valid).isValid)
    #expect(!validateOnly.validationReport(for: invalid).isValid)
    #expect(validateOnly.validationReport(for: invalid).diagnostics.contains { $0.code == "forecasting.movingAverage.window.invalid" })
    #expect(ForecastingBackends.backend(for: .externalHighPerformance) == nil)
    do {
        _ = try validateOnly.solve(valid)
        Issue.record("validateOnly unexpectedly solved a forecasting request")
    } catch {
        #expect(String(describing: error).contains("validateOnly"))
    }
}

@Test func parsesAndSolvesWinQSBEOQFixture() throws {
    let url = legacyFixtureURL("EOQ.IT_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let model = try WinQSBInventoryParser.parseEOQ(from: expanded)
    let solution = try EOQSolver.solve(model)

    #expect(model.title == "QSB209")
    #expect(model.timeUnit == "year")
    #expect(model.demand == 600)
    #expect(model.setupCost == 50)
    #expect(model.holdingCost == 60)
    #expect(model.acquisitionCost == 300)
    #expect(model.knownOrderQuantity == 60)
    #expect(abs(solution.economicOrderQuantity - 31.622776601683793) < 1e-8)
    #expect(abs(solution.optimum.setupCost - 948.6832980505138) < 1e-8)
    #expect(abs(solution.optimum.holdingCost - 948.6832980505138) < 1e-8)
    #expect(abs(solution.optimum.totalRelevantCost - 1897.3665961010277) < 1e-8)
    #expect(abs(solution.optimum.totalCost - 181897.366596101) < 1e-6)
    #expect(abs((solution.knownQuantity?.totalRelevantCost ?? 0) - 2300) < 1e-8)
    #expect(abs((solution.knownQuantity?.totalCost ?? 0) - 182300) < 1e-8)
}

@Test func parsesAndSolvesWinQSBQuantityDiscountEOQFixture() throws {
    let url = legacyFixtureURL("DISCOUNT.IT_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let model = try WinQSBInventoryParser.parseQuantityDiscountEOQ(from: expanded)
    let solution = try QuantityDiscountEOQSolver.solve(model)

    #expect(model.title == "Inventory Problem")
    #expect(model.demand == 600)
    #expect(model.setupCost == 50)
    #expect(model.holdingCost == 60)
    #expect(model.acquisitionCost == 300)
    #expect(model.discountBreaks == [
        QuantityDiscountBreak(minimumQuantity: 50, discountPercent: 2),
        QuantityDiscountBreak(minimumQuantity: 80, discountPercent: 5)
    ])
    #expect(abs(solution.unconstrainedEOQ - 31.622776601683793) < 1e-8)
    #expect(solution.candidates.count == 3)
    #expect(abs(solution.candidates[0].cost.totalCost - 181897.36659610103) < 1e-6)
    #expect(abs(solution.candidates[1].cost.totalCost - 178500) < 1e-8)
    #expect(abs(solution.candidates[2].cost.totalCost - 173775) < 1e-8)
    #expect(solution.optimum.minimumQuantity == 80)
    #expect(solution.optimum.discountPercent == 5)
    #expect(solution.optimum.unitAcquisitionCost == 285)
    #expect(solution.optimum.cost.orderQuantity == 80)
    #expect(abs(solution.optimum.cost.totalRelevantCost - 2775) < 1e-8)
    #expect(abs(solution.optimum.cost.totalCost - 173775) < 1e-8)
}

@Test func parsesAndSolvesWinQSBNewsboyFixture() throws {
    let url = legacyFixtureURL("NEWSBOY.IT_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let model = try WinQSBInventoryParser.parseNewsboy(from: expanded)
    let solution = try NewsboySolver.solve(model)

    #expect(model.title == "Inventory Problem")
    #expect(model.timeUnit == "year")
    #expect(model.demandDistribution == "Normal")
    #expect(model.meanDemand == 1000)
    #expect(model.standardDeviation == 100)
    #expect(model.setupCost == 300)
    #expect(model.acquisitionCost == 20)
    #expect(model.sellingPrice == 30)
    #expect(model.shortageCost == 10)
    #expect(model.salvageValue == 15)
    #expect(abs(solution.criticalRatio - 0.8) < 1e-8)
    #expect(abs(solution.optimum.orderQuantity - 1084.1621233572914) < 1e-5)
    #expect(abs(solution.optimum.serviceLevel - 0.8) < 1e-7)
    #expect(abs(solution.optimum.expectedSales - 988.8362326306775) < 1e-5)
    #expect(abs(solution.optimum.expectedLeftover - 95.32589072661399) < 1e-5)
    #expect(abs(solution.optimum.expectedShortage - 11.163767369322542) < 1e-5)
    #expect(abs(solution.optimum.expectedProfit - 9000.095198980482) < 1e-5)
}

@Test func parsesAndSolvesWinQSBLotSizingFixture() throws {
    let url = legacyFixtureURL("LOTSIZE.IT_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let model = try WinQSBInventoryParser.parseLotSizing(from: expanded)
    let solution = try LotSizingSolver.solve(model)

    #expect(model.title == "Inventory Problem")
    #expect(model.timeUnit == "month")
    #expect(model.periods == [
        LotSizingPeriod(name: "1", demand: 20, setupCost: 30, unitVariableCost: 3, unitHoldingCost: 5, unitBackorderCost: 1),
        LotSizingPeriod(name: "2", demand: 30, setupCost: 40, unitVariableCost: 3, unitHoldingCost: 2, unitBackorderCost: 1),
        LotSizingPeriod(name: "3", demand: 40, setupCost: 30, unitVariableCost: 4, unitHoldingCost: 2, unitBackorderCost: 1),
        LotSizingPeriod(name: "4", demand: 30, setupCost: 50, unitVariableCost: 4, unitHoldingCost: 1, unitBackorderCost: 1),
        LotSizingPeriod(name: "5", demand: 30, setupCost: 40, unitVariableCost: 4.5, unitHoldingCost: 2, unitBackorderCost: 1),
        LotSizingPeriod(name: "6", demand: 35, setupCost: 30, unitVariableCost: 4.5, unitHoldingCost: 1, unitBackorderCost: 1)
    ])
    #expect(abs(solution.totalCost - 907.5) < 1e-8)
    #expect(solution.decisions == [
        LotSizingDecision(period: "1", demand: 20, productionQuantity: 0, endingInventory: -20, setupCost: 0, variableCost: 0, holdingCost: 0, backorderCost: 20, totalCost: 20),
        LotSizingDecision(period: "2", demand: 30, productionQuantity: 50, endingInventory: 0, setupCost: 40, variableCost: 150, holdingCost: 0, backorderCost: 0, totalCost: 190),
        LotSizingDecision(period: "3", demand: 40, productionQuantity: 40, endingInventory: 0, setupCost: 30, variableCost: 160, holdingCost: 0, backorderCost: 0, totalCost: 190),
        LotSizingDecision(period: "4", demand: 30, productionQuantity: 60, endingInventory: 30, setupCost: 50, variableCost: 240, holdingCost: 30, backorderCost: 0, totalCost: 320),
        LotSizingDecision(period: "5", demand: 30, productionQuantity: 0, endingInventory: 0, setupCost: 0, variableCost: 0, holdingCost: 0, backorderCost: 0, totalCost: 0),
        LotSizingDecision(period: "6", demand: 35, productionQuantity: 35, endingInventory: 0, setupCost: 30, variableCost: 157.5, holdingCost: 0, backorderCost: 0, totalCost: 187.5)
    ])
}

@Test func roundTripsNormalizedInventoryModelsAndSolutions() throws {
    let fixtureNames = ["EOQ.IT_", "DISCOUNT.IT_", "NEWSBOY.IT_", "LOTSIZE.IT_", "CRSQ.IT_", "CRSS.IT_", "PRRS.IT_", "PRRSS.IT_"]
    let expectedKinds: [InventoryProblemKind] = [.eoq, .quantityDiscountEOQ, .newsboy, .lotSizing, .stochasticReview, .stochasticReview, .stochasticReview, .stochasticReview]
    let nativeBackend = NativeEducationalInventoryBackend()

    for (fixtureName, expectedKind) in zip(fixtureNames, expectedKinds) {
        let data = try Data(contentsOf: legacyFixtureURL(fixtureName))
        let expanded = try LegacyCompressedFile.expandedData(from: data)
        let model = try WinQSBInventoryParser.parseModelEnvelope(from: expanded)
        #expect(model.kind == expectedKind)

        let encodedModel = try InventoryModelJSON.encodeModel(model)
        #expect(try InventoryModelJSON.decodeModel(from: encodedModel) == model)

        let solution = try nativeBackend.solve(model)
        #expect(solution.kind == expectedKind)
        let document = nativeBackend.solutionDocument(for: model, solution: solution)
        #expect(document.kind == expectedKind)
        #expect(document.backend.backendKind == .nativeEducational)
        #expect(!document.assumptions.isEmpty)

        let encodedSolution = try InventoryModelJSON.encodeSolutionDocument(document)
        #expect(try InventoryModelJSON.decodeSolutionDocument(from: encodedSolution) == document)
    }
}

@Test func parsesAndSolvesAllWinQSBStochasticInventoryPolicies() throws {
    let fixtures: [(String, StochasticInventoryPolicy)] = [
        ("CRSQ.IT_", .continuousFixedOrderQuantity),
        ("CRSS.IT_", .continuousOrderUpTo),
        ("PRRS.IT_", .periodicFixedOrderInterval),
        ("PRRSS.IT_", .periodicOptionalReplenishment)
    ]
    var solutions: [StochasticInventoryPolicy: StochasticInventorySolution] = [:]
    for (fixture, policy) in fixtures {
        let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL(fixture)))
        let model = try WinQSBInventoryParser.parseStochasticInventory(from: expanded)
        #expect(model.policy == policy)
        #expect(model.meanDemand == 1_000)
        #expect(model.demandStandardDeviation == 100)
        #expect(model.leadTime > 0.08332 && model.leadTime < 0.08334)
        #expect(model.backorderFraction == 1)
        #expect(model.backorderCost == 20)
        solutions[policy] = try StochasticInventorySolver.solve(model)
    }
    let q = try #require(solutions[.continuousFixedOrderQuantity])
    #expect(abs(q.orderQuantity - 155.025984159998) < 1e-6)
    #expect(abs((q.reorderPoint ?? 0) - 124.382959946781) < 1e-6)
    #expect(abs(q.serviceLevel - 0.922487007920001) < 1e-8)
    let s = try #require(solutions[.continuousOrderUpTo])
    #expect(s.orderQuantity == 50)
    #expect(abs((s.orderUpToLevel ?? 0) - 189.912173835284) < 1e-6)
    let periodic = try #require(solutions[.periodicFixedOrderInterval])
    #expect(abs((periodic.reviewInterval ?? 0) - 0.173205080756888) < 1e-8)
    #expect(abs(periodic.orderQuantity - 173.205080756888) < 1e-8)
    let optional = try #require(solutions[.periodicOptionalReplenishment])
    #expect(abs((optional.reviewInterval ?? 0) - 0.1) < 1e-10)
    #expect(abs(optional.orderQuantity - 141.42135623731) < 1e-8)
    #expect(solutions.values.allSatisfy { $0.costs.totalCost > 50_000 && $0.serviceLevel > 0 && $0.serviceLevel < 1 })
}

@Test func validatesStochasticInventoryAssumptionsAndBackendRouting() throws {
    let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("CRSQ.IT_")))
    let model = try WinQSBInventoryParser.parseStochasticInventory(from: expanded)
    let invalid = StochasticInventoryModel(title: model.title, timeUnit: model.timeUnit, policy: model.policy, demandDistribution: "Poisson", meanDemand: model.meanDemand, demandStandardDeviation: model.demandStandardDeviation, setupCost: model.setupCost, acquisitionCost: model.acquisitionCost, holdingCost: model.holdingCost, backorderFraction: model.backorderFraction, backorderCost: model.backorderCost, lostSalesFraction: model.lostSalesFraction, lostSalesCost: model.lostSalesCost, fixedShortageCost: model.fixedShortageCost, leadTimeDistribution: "Variable", leadTime: model.leadTime, averageOrderSize: model.averageOrderSize, reviewCost: model.reviewCost)
    let validate = ValidateOnlyInventoryBackend()
    let report = validate.validationReport(for: invalid)
    #expect(!report.isValid)
    #expect(report.diagnostics.contains { $0.code == "inventory.stochastic.distribution.unsupported" })
    #expect(report.diagnostics.contains { $0.code == "inventory.stochastic.leadTimeDistribution.unsupported" })
    #expect(NativeEducationalInventoryBackend().runMetadata(for: model).exactness == .approximate)
    do {
        _ = try validate.solve(model)
        Issue.record("validateOnly unexpectedly solved a stochastic inventory model")
    } catch {
        #expect(String(describing: error).contains("validateOnly"))
    }
}

@Test func routesInventoryModelsThroughNamedBackends() throws {
    let eoqData = try LegacyCompressedFile.expandedData(
        from: Data(contentsOf: legacyFixtureURL("EOQ.IT_"))
    )
    let discountData = try LegacyCompressedFile.expandedData(
        from: Data(contentsOf: legacyFixtureURL("DISCOUNT.IT_"))
    )
    let newsboyData = try LegacyCompressedFile.expandedData(
        from: Data(contentsOf: legacyFixtureURL("NEWSBOY.IT_"))
    )
    let lotSizingData = try LegacyCompressedFile.expandedData(
        from: Data(contentsOf: legacyFixtureURL("LOTSIZE.IT_"))
    )
    let eoq = try WinQSBInventoryParser.parseEOQ(from: eoqData)
    let discount = try WinQSBInventoryParser.parseQuantityDiscountEOQ(from: discountData)
    let newsboy = try WinQSBInventoryParser.parseNewsboy(from: newsboyData)
    let lotSizing = try WinQSBInventoryParser.parseLotSizing(from: lotSizingData)

    let nativeBackend = NativeEducationalInventoryBackend()
    #expect(nativeBackend.capabilities.backendKind == .nativeEducational)
    #expect(nativeBackend.capabilities.solves)
    #expect(abs(try nativeBackend.solve(eoq).economicOrderQuantity - 31.622776601683793) < 1e-8)
    #expect(abs(try nativeBackend.solve(discount).optimum.cost.orderQuantity - 80) < 1e-8)
    #expect(abs(try nativeBackend.solve(newsboy).criticalRatio - 0.8) < 1e-8)
    #expect(abs(try nativeBackend.solve(lotSizing).totalCost - 907.5) < 1e-8)
    #expect(nativeBackend.runMetadata(for: eoq).exactness == .closedForm)
    #expect(nativeBackend.runMetadata(for: discount).algorithm == "allUnitsDiscountTierEnumeration")
    #expect(nativeBackend.runMetadata(for: newsboy).algorithm == "normalDemandCriticalFractile")
    #expect(nativeBackend.runMetadata(for: lotSizing).exactness == .fixtureScale)

    let validateBackend = ValidateOnlyInventoryBackend()
    #expect(validateBackend.capabilities.backendKind == .validateOnly)
    #expect(!validateBackend.capabilities.solves)
    #expect(validateBackend.validationReport(for: eoq).isValid)
    #expect(validateBackend.validationReport(for: discount).isValid)
    #expect(validateBackend.validationReport(for: newsboy).isValid)
    #expect(validateBackend.validationReport(for: lotSizing).isValid)

    let invalidEOQ = EOQModel(
        title: "Invalid production rate",
        timeUnit: "year",
        demand: 10,
        setupCost: 5,
        holdingCost: 2,
        replenishmentRate: 10
    )
    let invalidReport = validateBackend.validationReport(for: invalidEOQ)
    #expect(!invalidReport.isValid)
    #expect(invalidReport.diagnostics.contains {
        $0.code == "inventory.eoq.replenishmentRate.insufficient" && $0.severity == .error
    })

    do {
        _ = try validateBackend.solve(eoq)
        Issue.record("Expected validateOnly backend to reject EOQ solving")
    } catch {
        #expect(String(describing: error).contains("validateOnly"))
    }

    #expect(InventoryBackends.backend(for: .nativeEducational) != nil)
    #expect(InventoryBackends.backend(for: .validateOnly) != nil)
    #expect(InventoryBackends.backend(for: .externalHighPerformance) == nil)
}

@Test func parsesAndSolvesWinQSBFlowShopFixture() throws {
    let url = legacyFixtureURL("FLOWSHOP.JO_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBSchedulingParser.parseFlowShop(from: expanded)
    let solution = try FlowShopSolver.solve(problem)

    #expect(problem.title == "QS P.602")
    #expect(problem.timeUnit == "minute")
    #expect(problem.jobs.count == 5)
    #expect(problem.machines == [
        FlowShopMachine(id: 1, name: "Machine 1"),
        FlowShopMachine(id: 2, name: "Machine 2"),
        FlowShopMachine(id: 3, name: "Machine 3"),
        FlowShopMachine(id: 4, name: "Machine 4")
    ])
    #expect(problem.jobs[0] == FlowShopJob(
        id: 1,
        name: "Job 1",
        operations: [
            FlowShopOperation(machineID: 1, duration: 31),
            FlowShopOperation(machineID: 2, duration: 41),
            FlowShopOperation(machineID: 3, duration: 25),
            FlowShopOperation(machineID: 4, duration: 30)
        ],
        dueDate: 100,
        weight: 1
    ))
    #expect(solution.sequence == ["Job 4", "Job 2", "Job 5", "Job 1", "Job 3"])
    #expect(solution.makespan == 213)
    #expect(solution.machineCompletionTimes == [119, 179, 206, 213])
    #expect(solution.schedules[0] == FlowShopJobSchedule(
        jobID: 4,
        jobName: "Job 4",
        operations: [
            ScheduledOperation(machineID: 1, start: 0, finish: 13),
            ScheduledOperation(machineID: 2, start: 13, finish: 35),
            ScheduledOperation(machineID: 3, start: 35, finish: 49),
            ScheduledOperation(machineID: 4, start: 49, finish: 62)
        ],
        completionTime: 62
    ))
    #expect(solution.schedules.last == FlowShopJobSchedule(
        jobID: 3,
        jobName: "Job 3",
        operations: [
            ScheduledOperation(machineID: 1, start: 96, finish: 119),
            ScheduledOperation(machineID: 2, start: 137, finish: 179),
            ScheduledOperation(machineID: 3, start: 179, finish: 206),
            ScheduledOperation(machineID: 4, start: 207, finish: 213)
        ],
        completionTime: 213
    ))
}

@Test func validatesWinQSBFlowShopFixtureWithBackendDiagnostics() throws {
    let url = legacyFixtureURL("FLOWSHOP.JO_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBSchedulingParser.parseFlowShop(from: expanded)
    let diagnostics = FlowShopValidator.diagnostics(for: problem)
    let report = ValidationReport(backend: .validateOnly, diagnostics: diagnostics)

    #expect(report.isValid)
    #expect(report.backend == .validateOnly)
    #expect(diagnostics.contains(ValidationDiagnostic(
        severity: .info,
        code: "scheduling.flowShop.valid",
        message: "Flow shop model is valid"
    )))
}

@Test func parsesAndSolvesWinQSBJobShopFixture() throws {
    let url = legacyFixtureURL("JOBSHOP.JO_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBSchedulingParser.parseJobShop(from: expanded)
    let solution = try JobShopSolver.solve(problem)

    #expect(problem.title == "QS P.616")
    #expect(problem.timeUnit == "minute")
    #expect(problem.jobs.count == 5)
    #expect(problem.machines == [
        FlowShopMachine(id: 1, name: "Machine 1"),
        FlowShopMachine(id: 2, name: "Machine 2"),
        FlowShopMachine(id: 3, name: "Machine 3"),
        FlowShopMachine(id: 4, name: "Machine 4"),
        FlowShopMachine(id: 5, name: "Machine 5")
    ])
    #expect(problem.jobs[0] == FlowShopJob(
        id: 1,
        name: "Job 1",
        operations: [
            FlowShopOperation(machineID: 3, duration: 2),
            FlowShopOperation(machineID: 1, duration: 8),
            FlowShopOperation(machineID: 2, duration: 4),
            FlowShopOperation(machineID: 4, duration: 6),
            FlowShopOperation(machineID: 5, duration: 7)
        ],
        dueDate: 20,
        weight: 1
    ))
    #expect(solution.makespan == 34)
    #expect(solution.machineCompletionTimes == [27, 33, 30, 34, 32])
    #expect(solution.dispatchOrder.first == JobShopDispatchStep(
        jobID: 1,
        jobName: "Job 1",
        operationIndex: 1,
        machineID: 3,
        start: 0,
        finish: 2
    ))
    #expect(solution.dispatchOrder.last == JobShopDispatchStep(
        jobID: 5,
        jobName: "Job 5",
        operationIndex: 5,
        machineID: 4,
        start: 30,
        finish: 34
    ))
    #expect(solution.schedules.map(\.completionTime) == [32, 29, 33, 22, 34])
    #expect(solution.schedules[0] == FlowShopJobSchedule(
        jobID: 1,
        jobName: "Job 1",
        operations: [
            ScheduledOperation(machineID: 3, start: 0, finish: 2),
            ScheduledOperation(machineID: 1, start: 7, finish: 15),
            ScheduledOperation(machineID: 2, start: 15, finish: 19),
            ScheduledOperation(machineID: 4, start: 19, finish: 25),
            ScheduledOperation(machineID: 5, start: 25, finish: 32)
        ],
        completionTime: 32
    ))
    #expect(solution.schedules[4] == FlowShopJobSchedule(
        jobID: 5,
        jobName: "Job 5",
        operations: [
            ScheduledOperation(machineID: 5, start: 0, finish: 5),
            ScheduledOperation(machineID: 3, start: 14, finish: 21),
            ScheduledOperation(machineID: 1, start: 21, finish: 24),
            ScheduledOperation(machineID: 2, start: 24, finish: 30),
            ScheduledOperation(machineID: 4, start: 30, finish: 34)
        ],
        completionTime: 34
    ))
}

@Test func validatesWinQSBJobShopFixtureWithBackendDiagnostics() throws {
    let url = legacyFixtureURL("JOBSHOP.JO_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBSchedulingParser.parseJobShop(from: expanded)
    let diagnostics = JobShopValidator.diagnostics(for: problem)
    let report = ValidationReport(backend: .validateOnly, diagnostics: diagnostics)

    #expect(report.isValid)
    #expect(report.backend == .validateOnly)
    #expect(diagnostics.contains(ValidationDiagnostic(
        severity: .info,
        code: "scheduling.jobShop.valid",
        message: "Job shop model is valid"
    )))
}

@Test func routesSchedulingModelsThroughNamedBackends() throws {
    let flowShopData = try Data(contentsOf: legacyFixtureURL("FLOWSHOP.JO_"))
    let flowShopExpanded = try LegacyCompressedFile.expandedData(from: flowShopData)
    let flowShop = try WinQSBSchedulingParser.parseFlowShop(from: flowShopExpanded)

    let jobShopData = try Data(contentsOf: legacyFixtureURL("JOBSHOP.JO_"))
    let jobShopExpanded = try LegacyCompressedFile.expandedData(from: jobShopData)
    let jobShop = try WinQSBSchedulingParser.parseJobShop(from: jobShopExpanded)

    let nativeBackend = NativeEducationalSchedulingBackend()
    #expect(nativeBackend.capabilities.backendKind == .nativeEducational)
    #expect(nativeBackend.capabilities.solves)
    #expect(nativeBackend.capabilities.validates)

    let flowShopSolution = try nativeBackend.solve(flowShop)
    #expect(flowShopSolution.makespan == 213)

    let jobShopSolution = try nativeBackend.solve(jobShop)
    #expect(jobShopSolution.makespan == 34)

    let validateBackend = ValidateOnlySchedulingBackend()
    let flowShopReport = validateBackend.validationReport(for: flowShop)
    let jobShopReport = validateBackend.validationReport(for: jobShop)
    #expect(validateBackend.capabilities.backendKind == .validateOnly)
    #expect(!validateBackend.capabilities.solves)
    #expect(flowShopReport.backend == .validateOnly)
    #expect(flowShopReport.isValid)
    #expect(jobShopReport.backend == .validateOnly)
    #expect(jobShopReport.isValid)

    do {
        _ = try validateBackend.solve(flowShop)
        Issue.record("Expected validateOnly backend to reject flow-shop solving")
    } catch SchedulingModelError.invalidModel(let message) {
        #expect(message.contains("validateOnly"))
    }

    let selectedBackend = try #require(SchedulingBackends.backend(for: .nativeEducational))
    #expect(selectedBackend.capabilities.backendKind == .nativeEducational)
    #expect(SchedulingBackends.backend(for: .externalHighPerformance) == nil)
}

@Test func encodesSchedulingGanttJSONDocuments() throws {
    let flowShopData = try Data(contentsOf: legacyFixtureURL("FLOWSHOP.JO_"))
    let flowShopExpanded = try LegacyCompressedFile.expandedData(from: flowShopData)
    let flowShop = try WinQSBSchedulingParser.parseFlowShop(from: flowShopExpanded)
    let flowShopSolution = try NativeEducationalSchedulingBackend().solve(flowShop)
    let flowShopDocument = SchedulingSolutionJSON.flowShopDocument(
        problem: flowShop,
        solution: flowShopSolution,
        backend: SolverRunMetadata(
            backendKind: .nativeEducational,
            algorithm: "flowShopPermutationSearch",
            exactness: .fixtureScale
        )
    )
    let flowShopJSON = try SchedulingSolutionJSON.encode(flowShopDocument)
    let decodedFlowShop = try SchedulingModelJSON.decodeSolution(from: flowShopJSON)
    let flowShopText = try #require(String(data: flowShopJSON, encoding: .utf8))

    #expect(decodedFlowShop.kind == .flowShop)
    #expect(decodedFlowShop == flowShopDocument)
    #expect(decodedFlowShop.backend.algorithm == "flowShopPermutationSearch")
    #expect(decodedFlowShop.makespan == 213)
    #expect(decodedFlowShop.operations.count == 20)
    #expect(decodedFlowShop.machineTimelines.count == 4)
    #expect(decodedFlowShop.operations[0].jobName == "Job 4")
    #expect(decodedFlowShop.operations[0].operationIndex == 1)
    #expect(decodedFlowShop.operations[0].duration == 13)
    #expect(decodedFlowShop.operations[0].idleBefore == 0)
    #expect(decodedFlowShop.machineTimelines[3].operations.contains {
        $0.jobName == "Job 2" && $0.idleBefore == 31
    })
    #expect(flowShopText.contains("\"kind\" : \"flowShop\""))
    #expect(flowShopText.contains("\"idleBefore\""))
    #expect(flowShopText.contains("\"machineTimelines\""))

    let jobShopData = try Data(contentsOf: legacyFixtureURL("JOBSHOP.JO_"))
    let jobShopExpanded = try LegacyCompressedFile.expandedData(from: jobShopData)
    let jobShop = try WinQSBSchedulingParser.parseJobShop(from: jobShopExpanded)
    let jobShopSolution = try NativeEducationalSchedulingBackend().solve(jobShop)
    let jobShopDocument = SchedulingSolutionJSON.jobShopDocument(
        problem: jobShop,
        solution: jobShopSolution,
        backend: SolverRunMetadata(
            backendKind: .nativeEducational,
            algorithm: "jobShopBranchAndBoundDominancePruning",
            exactness: .fixtureScale
        )
    )
    let jobShopJSON = try SchedulingSolutionJSON.encode(jobShopDocument)
    let decodedJobShop = try SchedulingModelJSON.decodeSolution(from: jobShopJSON)
    let jobShopText = try #require(String(data: jobShopJSON, encoding: .utf8))

    #expect(decodedJobShop.kind == .jobShop)
    #expect(decodedJobShop == jobShopDocument)
    #expect(decodedJobShop.backend.algorithm == "jobShopBranchAndBoundDominancePruning")
    #expect(decodedJobShop.makespan == 34)
    #expect(decodedJobShop.operations.count == 25)
    #expect(decodedJobShop.machineTimelines.count == 5)
    #expect(decodedJobShop.operations.contains {
        $0.jobName == "Job 5" && $0.operationIndex == 5 && $0.machineID == 4 && $0.finish == 34
    })
    #expect(jobShopText.contains("\"kind\" : \"jobShop\""))
    #expect(jobShopText.contains("\"duration\""))
}

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

@Test func parsesAndSolvesWinQSBKnapsackFixture() throws {
    let url = legacyFixtureURL("KNAPSACK.DP_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBDynamicProgrammingParser.parseKnapsack(from: expanded)
    let solution = try KnapsackSolver.solve(problem)

    #expect(problem.title == "QSB P.112")
    #expect(problem.capacity == 20)
    #expect(problem.items == [
        KnapsackItem(name: "A", available: 5, capacityRequired: 10, returnPerUnit: 8),
        KnapsackItem(name: "B", available: 3, capacityRequired: 6, returnPerUnit: 10),
        KnapsackItem(name: "C", available: 4, capacityRequired: 3, returnPerUnit: 4),
        KnapsackItem(name: "D", available: 2, capacityRequired: 5, returnPerUnit: 7)
    ])
    #expect(abs(solution.totalReturn - 31) < 1e-8)
    #expect(solution.capacityUsed == 20)
    #expect(solution.selections == [
        KnapsackSelection(item: "B", quantity: 2, capacityUsed: 12, returnValue: 20),
        KnapsackSelection(item: "C", quantity: 1, capacityUsed: 3, returnValue: 4),
        KnapsackSelection(item: "D", quantity: 1, capacityUsed: 5, returnValue: 7)
    ])
}

@Test func parsesAndSolvesWinQSBStagecoachFixture() throws {
    let url = legacyFixtureURL("STAGE.DP_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBDynamicProgrammingParser.parseStagecoach(from: expanded)
    let solution = try StagecoachSolver.solve(problem)

    #expect(problem.title == "QSB 119")
    #expect(problem.nodes == ["Node1", "Node2", "Node3", "Node4", "Node5", "Node6", "Node7", "Node8", "Node9", "Node10"])
    #expect(problem.arcs.count == 20)
    #expect(solution.source == "Node1")
    #expect(solution.sink == "Node10")
    #expect(abs(solution.totalCost - 19) < 1e-8)
    #expect(solution.path == ["Node1", "Node3", "Node5", "Node8", "Node10"])
}

@Test func parsesAndSolvesWinQSBProductionInventoryFixture() throws {
    let url = legacyFixtureURL("PRODINVT.DP_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBDynamicProgrammingParser.parseProductionInventory(from: expanded)
    let solution = try ProductionInventorySolver.solve(problem)

    #expect(problem.title == "QSB P.116")
    #expect(problem.periods.count == 4)
    #expect(problem.periods[0] == ProductionInventoryPeriod(
        name: "January",
        demand: 4,
        productionCapacity: 6,
        storageCapacity: 4,
        setupCost: 500,
        productionUnitCost: 300,
        holdingUnitCost: 100
    ))
    #expect(abs(solution.totalCost - 7080) < 1e-8)
    #expect(solution.decisions == [
        ProductionInventoryDecision(period: "January", beginningInventory: 0, productionQuantity: 5, demand: 4, endingInventory: 1, cost: 2100),
        ProductionInventoryDecision(period: "February", beginningInventory: 1, productionQuantity: 4, demand: 5, endingInventory: 0, cost: 1730),
        ProductionInventoryDecision(period: "March", beginningInventory: 0, productionQuantity: 3, demand: 3, endingInventory: 0, cost: 1250),
        ProductionInventoryDecision(period: "April", beginningInventory: 0, productionQuantity: 4, demand: 4, endingInventory: 0, cost: 2000)
    ])
}

@Test func roundTripsNormalizedDynamicProgrammingModelsAndSolutions() throws {
    let fixtures: [(String, DynamicProgrammingProblemKind)] = [
        ("KNAPSACK.DP_", .boundedKnapsack),
        ("STAGE.DP_", .stagecoach),
        ("PRODINVT.DP_", .productionInventory)
    ]
    let backend = NativeEducationalDynamicProgrammingBackend()

    for (fileName, expectedKind) in fixtures {
        let data = try Data(contentsOf: legacyFixtureURL(fileName))
        let model = try WinQSBDynamicProgrammingParser.parseModelEnvelope(from: LegacyCompressedFile.expandedData(from: data))
        #expect(model.kind == expectedKind)

        let encodedModel = try DynamicProgrammingModelJSON.encodeModel(model)
        #expect(try DynamicProgrammingModelJSON.decodeModel(from: encodedModel) == model)

        let solution = try backend.solve(model)
        #expect(solution.kind == expectedKind)
        #expect(!solution.trace.isEmpty)
        let document = backend.solutionDocument(for: model, solution: solution)
        let encodedSolution = try DynamicProgrammingModelJSON.encodeSolutionDocument(document)
        #expect(try DynamicProgrammingModelJSON.decodeSolutionDocument(from: encodedSolution) == document)
    }
}

@Test func routesDynamicProgrammingModelsThroughNamedBackends() throws {
    let native = NativeEducationalDynamicProgrammingBackend()
    let validateOnly = ValidateOnlyDynamicProgrammingBackend()
    let data = try Data(contentsOf: legacyFixtureURL("KNAPSACK.DP_"))
    let model = try WinQSBDynamicProgrammingParser.parseModelEnvelope(from: LegacyCompressedFile.expandedData(from: data))

    #expect(native.capabilities.solves)
    #expect(native.runMetadata(for: model).algorithm == "boundedKnapsackDynamicProgramming")
    #expect(native.runMetadata(for: model).exactness == .fixtureScale)
    #expect(validateOnly.validationReport(for: model).isValid)
    #expect(DynamicProgrammingBackends.backend(for: .externalHighPerformance) == nil)

    let invalid = DynamicProgrammingModelEnvelope.boundedKnapsack(KnapsackProblem(title: "invalid", capacity: 0, items: []))
    let report = validateOnly.validationReport(for: invalid)
    #expect(!report.isValid)
    #expect(report.diagnostics.contains { $0.code == "dynamicProgramming.boundedKnapsack.capacity.nonpositive" })
    #expect(report.diagnostics.contains { $0.code == "dynamicProgramming.boundedKnapsack.items.empty" })

    do {
        _ = try validateOnly.solve(model)
        Issue.record("validateOnly unexpectedly solved a dynamic-programming model")
    } catch {
        #expect(String(describing: error).contains("validateOnly"))
    }
}

@Test func parsesAndSolvesWinQSBPayoffFixture() throws {
    let url = legacyFixtureURL("PAYOFF.DA_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBDecisionAnalysisParser.parsePayoff(from: expanded)
    let solution = try DecisionPayoffSolver.solve(problem)

    #expect(problem.title == "QSB P.277")
    #expect(problem.states == ["High", "Medium", "Low"])
    #expect(problem.indicators == ["Favorable", "Unfavorable", "Neutral"])
    #expect(problem.decisions == ["Advertise", "Do Nothing", "Pricing"])
    #expect(solution.bestPriorDecision == "Pricing")
    #expect(abs(solution.bestPriorExpectedValue - 56300) < 1e-8)
    #expect(solution.priorExpectedValues == [
        DecisionExpectedValue(decision: "Advertise", expectedValue: 55000),
        DecisionExpectedValue(decision: "Do Nothing", expectedValue: -7000),
        DecisionExpectedValue(decision: "Pricing", expectedValue: 56300)
    ])
    #expect(abs(solution.expectedValueWithSampleInformation - 57170) < 1e-8)
    #expect(abs(solution.expectedValueOfSampleInformation - 870) < 1e-8)
    #expect(abs(solution.expectedValueWithPerfectInformation - 59500) < 1e-8)
    #expect(abs(solution.expectedValueOfPerfectInformation - 3200) < 1e-8)
    #expect(solution.indicatorAnalyses.map(\.bestDecision) == ["Advertise", "Pricing", "Pricing"])
    #expect(abs(solution.indicatorAnalyses[0].probability - 0.33) < 1e-8)
    #expect(abs(solution.indicatorAnalyses[0].bestExpectedValue - 65454.54545454546) < 1e-8)
}

@Test func parsesAndSolvesWinQSBDecisionTreeFixture() throws {
    let url = legacyFixtureURL("DTREE.DA_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let tree = try WinQSBDecisionAnalysisParser.parseDecisionTree(from: expanded)
    let solution = try DecisionTreeSolver.solve(tree)

    #expect(tree.title == "QSB P.283")
    #expect(tree.rootID == 1)
    #expect(tree.nodes.count == 40)
    #expect(tree.nodes[0] == DecisionTreeNode(
        id: 1,
        name: "Survey",
        kind: .chance,
        childIDs: [2, 3, 4]
    ))
    #expect(tree.nodes[13] == DecisionTreeNode(
        id: 14,
        name: "High",
        kind: .terminal,
        childIDs: [],
        payoff: 100000,
        probability: 0.36
    ))
    #expect(abs(solution.expectedValue - 57213.215998367516) < 1e-8)
    #expect(solution.policy.map(\.nodeID) == [2, 3, 4])
    #expect(solution.policy.map(\.nodeName) == ["Favorable", "Unfavorable", "Neutral"])
    #expect(solution.policy.map(\.selectedChildID) == [5, 10, 13])
    #expect(solution.policy.map(\.selectedChildName) == ["Advertise", "Pricing", "Pricing"])
    #expect(abs(solution.policy[0].expectedValue - 65454.545454545456) < 1e-8)
    #expect(abs(solution.policy[1].expectedValue - 51252.52525252525) < 1e-8)
    #expect(abs(solution.policy[2].expectedValue - 55170) < 1e-8)
}

@Test func parsesAndSolvesWinQSBBayesianFixture() throws {
    let url = legacyFixtureURL("BAYESIAN.DA_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let problem = try WinQSBDecisionAnalysisParser.parseBayesianAnalysis(from: expanded)
    let solution = try BayesianAnalysisSolver.solve(problem)

    #expect(problem.title == "QSB P.272")
    #expect(problem.states == ["High", "Medium", "Low"])
    #expect(problem.priorProbabilities == [0.20, 0.50, 0.30])
    #expect(problem.outcomes == ["Favorable", "Unfavorable", "Neutral"])
    #expect(solution.outcomes.count == 3)
    #expect(abs(solution.outcomes[0].probability - 0.33) < 1e-8)
    #expect(abs(solution.outcomes[0].posteriorProbabilities[0] - 0.36363636363636365) < 1e-8)
    #expect(abs(solution.outcomes[0].posteriorProbabilities[1] - 0.4545454545454546) < 1e-8)
    #expect(abs(solution.outcomes[0].posteriorProbabilities[2] - 0.18181818181818182) < 1e-8)
    #expect(abs(solution.outcomes[1].probability - 0.355) < 1e-8)
    #expect(abs(solution.outcomes[1].posteriorProbabilities[0] - 0.1126760563380282) < 1e-8)
    #expect(abs(solution.outcomes[1].posteriorProbabilities[1] - 0.4225352112676056) < 1e-8)
    #expect(abs(solution.outcomes[1].posteriorProbabilities[2] - 0.46478873239436624) < 1e-8)
    #expect(abs(solution.outcomes[2].probability - 0.315) < 1e-8)
    #expect(abs(solution.outcomes[2].posteriorProbabilities[0] - 0.126984126984127) < 1e-8)
    #expect(abs(solution.outcomes[2].posteriorProbabilities[1] - 0.634920634920635) < 1e-8)
    #expect(abs(solution.outcomes[2].posteriorProbabilities[2] - 0.23809523809523808) < 1e-8)
}

@Test func parsesAndSolvesWinQSBZeroSumGameFixture() throws {
    let url = legacyFixtureURL("GAME.DA_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let game = try WinQSBDecisionAnalysisParser.parseZeroSumGame(from: expanded)
    let solution = try ZeroSumGameSolver.solve(game)

    #expect(game.title == "Marketing Game")
    #expect(game.rowStrategies == ["Strategy1-1", "Strategy1-2", "Strategy1-3", "Strategy1-4", "Strategy1-5"])
    #expect(game.columnStrategies == ["Strategy2-1", "Strategy2-2", "Strategy2-3", "Strategy2-4"])
    #expect(abs(solution.value - 10.265525246662797) < 1e-8)
    #expect(abs(solution.rowStrategy[0].probability - 0) < 1e-8)
    #expect(abs(solution.rowStrategy[1].probability - 0.173824724318050) < 1e-8)
    #expect(abs(solution.rowStrategy[2].probability - 0) < 1e-8)
    #expect(abs(solution.rowStrategy[3].probability - 0.389146836912362) < 1e-8)
    #expect(abs(solution.rowStrategy[4].probability - 0.437028438769588) < 1e-8)
    #expect(abs(solution.columnStrategy[0].probability - 0.515670342426001) < 1e-8)
    #expect(abs(solution.columnStrategy[1].probability - 0.342716192687174) < 1e-8)
    #expect(abs(solution.columnStrategy[2].probability - 0) < 1e-8)
    #expect(abs(solution.columnStrategy[3].probability - 0.141613464886825) < 1e-8)
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

@Test func validatesWinQSBZeroSumGameFixtureWithBackendDiagnostics() throws {
    let url = legacyFixtureURL("GAME.DA_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let game = try WinQSBDecisionAnalysisParser.parseZeroSumGame(from: expanded)
    let diagnostics = ZeroSumGameValidator.diagnostics(for: game)
    let report = ValidationReport(backend: .validateOnly, diagnostics: diagnostics)

    #expect(report.backend == .validateOnly)
    #expect(report.isValid)
    #expect(diagnostics.contains {
        $0.severity == .info && $0.code == "decisionAnalysis.zeroSumGame.valid"
    })
}

@Test func roundTripsNormalizedDecisionAnalysisModelsAndSolutions() throws {
    let fixtures = ["PAYOFF.DA_", "BAYESIAN.DA_", "DTREE.DA_", "GAME.DA_"]
    let backend = NativeEducationalDecisionAnalysisBackend()

    for fixture in fixtures {
        let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL(fixture)))
        let model = try WinQSBDecisionAnalysisParser.parseModelEnvelope(from: expanded)
        let encodedModel = try DecisionAnalysisModelJSON.encodeModel(model)
        #expect(try DecisionAnalysisModelJSON.decodeModel(from: encodedModel) == model)

        let solution = try backend.solve(model)
        #expect(solution.kind == model.kind)
        let document = backend.solutionDocument(for: model, solution: solution)
        let encodedSolution = try DecisionAnalysisModelJSON.encodeSolutionDocument(document)
        #expect(try DecisionAnalysisModelJSON.decodeSolutionDocument(from: encodedSolution) == document)
    }
}

@Test func routesDecisionAnalysisThroughNamedBackendsAndStructuredValidation() throws {
    let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("PAYOFF.DA_")))
    let model = try WinQSBDecisionAnalysisParser.parseModelEnvelope(from: expanded)
    let native = NativeEducationalDecisionAnalysisBackend()
    let validateOnly = ValidateOnlyDecisionAnalysisBackend()

    #expect(native.capabilities.solves)
    #expect(native.runMetadata(for: model).algorithm == "expectedValueOfInformation")
    #expect(native.runMetadata(for: model).exactness == .exact)
    #expect(validateOnly.validationReport(for: model).isValid)
    #expect(DecisionAnalysisBackends.backend(for: .externalHighPerformance) == nil)

    let invalid = DecisionAnalysisModelEnvelope.bayesian(BayesianAnalysisProblem(
        title: "Invalid",
        states: ["A", "B"],
        priorProbabilities: [0.8, 0.8],
        outcomes: ["Yes"],
        likelihoods: [[0.5, 0.5]]
    ))
    let report = validateOnly.validationReport(for: invalid)
    #expect(!report.isValid)
    #expect(report.diagnostics.contains { $0.code == "decisionAnalysis.priors.sum" })
    #expect(report.diagnostics.contains { $0.code == "decisionAnalysis.bayesian.likelihoods.sum" })

    do {
        _ = try validateOnly.solve(model)
        Issue.record("validateOnly unexpectedly solved a decision-analysis model")
    } catch {
        #expect(String(describing: error).contains("validateOnly"))
    }
}

@Test func parsesAndSolvesWinQSBMM1QueueFixture() throws {
    let url = legacyFixtureURL("QUEUE1.QA_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let model = try WinQSBQueuingParser.parseMM1(from: expanded)
    let solution = try MM1QueueSolver.solve(model)

    #expect(model.title == "Sample M/M/1 Problem")
    #expect(model.timeUnit == "hour")
    #expect(model.serviceRate == 3)
    #expect(model.arrivalRate == 2)
    #expect(abs(solution.utilization - 2.0 / 3.0) < 1e-8)
    #expect(abs(solution.probabilitySystemEmpty - 1.0 / 3.0) < 1e-8)
    #expect(abs(solution.averageNumberInSystem - 2) < 1e-8)
    #expect(abs(solution.averageNumberInQueue - 4.0 / 3.0) < 1e-8)
    #expect(abs(solution.averageTimeInSystem - 1) < 1e-8)
    #expect(abs(solution.averageTimeInQueue - 2.0 / 3.0) < 1e-8)
    #expect(abs((solution.cost?.busyServerCost ?? 0) - 400.0 / 3.0) < 1e-8)
    #expect(abs((solution.cost?.idleServerCost ?? 0) - 200.0 / 3.0) < 1e-8)
    #expect(abs((solution.cost?.customerWaitingCost ?? 0) - 200.0 / 3.0) < 1e-8)
    #expect(abs((solution.cost?.customerBeingServedCost ?? 0) - 100.0 / 3.0) < 1e-8)
    #expect(abs((solution.cost?.totalCost ?? 0) - 300) < 1e-8)
}

@Test func parsesAndSolvesWinQSBFiniteCapacityQueueFixture() throws {
    let url = legacyFixtureURL("QUEUE2.QA_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)

    let model = try WinQSBQueuingParser.parseFiniteCapacity(from: expanded)
    let solution = try FiniteCapacityQueueSolver.solve(model)

    #expect(model.title == "Queuing Sample Problem 2")
    #expect(model.timeUnit == "hour")
    #expect(model.servers == 2)
    #expect(model.serviceDistribution == "Normal")
    #expect(model.meanServiceTime == 0.66666667)
    #expect(model.serviceTimeStandardDeviation == 0.2)
    #expect(model.interarrivalDistribution == "Exponential")
    #expect(model.meanInterarrivalTime == 0.5)
    #expect(model.batchSize == 1)
    #expect(model.queueCapacity == 3)
    #expect(abs(solution.arrivalRate - 2) < 1e-8)
    #expect(abs(solution.serviceRatePerServer - 1.4999999925) < 1e-8)
    #expect(abs(solution.effectiveArrivalRate - 1.8822447082925162) < 1e-8)
    #expect(abs(solution.utilization - 0.6274149059012466) < 1e-8)
    #expect(abs(solution.probabilitySystemEmpty - 0.22355105601214997) < 1e-8)
    #expect(abs(solution.probabilitySystemFull - 0.05887764585374193) < 1e-8)
    #expect(abs(solution.averageNumberInSystem - 1.7405703878879524) < 1e-8)
    #expect(abs(solution.averageNumberInQueue - 0.48574057608545923) < 1e-8)
    #expect(abs(solution.averageNumberBeingServed - 1.2548298118024932) < 1e-8)
    #expect(abs(solution.averageTimeInSystem - 0.9247311894248416) < 1e-8)
    #expect(abs(solution.averageTimeInQueue - 0.25806451942484154) < 1e-8)
    #expect(abs(solution.stateProbabilities.reduce(0, +) - 1) < 1e-8)
    #expect(abs((solution.cost?.busyServerCost ?? 0) - 125.48298118024933) < 1e-8)
    #expect(abs((solution.cost?.idleServerCost ?? 0) - 74.51701881975067) < 1e-8)
    #expect(abs((solution.cost?.customerWaitingCost ?? 0) - 24.28702880427296) < 1e-8)
    #expect(abs((solution.cost?.customerBeingServedCost ?? 0) - 62.74149059012466) < 1e-8)
    #expect(abs((solution.cost?.balkedCustomerCost ?? 0) - 7.065317502449032) < 1e-8)
    #expect(abs((solution.cost?.queueCapacityCost ?? 0) - 45) < 1e-8)
    #expect(abs((solution.cost?.totalCost ?? 0) - 339.09383689684665) < 1e-8)
}

@Test func validatesQueuingModelsWithStructuredDiagnostics() throws {
    let mm1Data = try Data(contentsOf: legacyFixtureURL("QUEUE1.QA_"))
    let mm1Expanded = try LegacyCompressedFile.expandedData(from: mm1Data)
    let mm1 = try WinQSBQueuingParser.parseMM1(from: mm1Expanded)
    let mm1Report = ValidationReport(
        backend: .validateOnly,
        diagnostics: MM1QueueValidator.diagnostics(for: mm1)
    )

    #expect(mm1Report.isValid)
    #expect(mm1Report.diagnostics.contains {
        $0.severity == .info && $0.code == "queuing.mm1.valid"
    })

    let unstable = MM1QueueModel(
        title: "Unstable",
        timeUnit: "hour",
        serviceRate: 2,
        arrivalRate: 2,
        customerWaitingCostPerTime: -1
    )
    let unstableDiagnostics = MM1QueueValidator.diagnostics(for: unstable)
    #expect(unstableDiagnostics.contains { $0.code == "queuing.mm1.unstable" && $0.severity == .error })
    #expect(unstableDiagnostics.contains {
        $0.code == "queuing.mm1.cost" && $0.path == "customerWaitingCostPerTime"
    })

    let invalidFinite = FiniteCapacityQueueModel(
        title: "Invalid finite queue",
        timeUnit: "hour",
        servers: 0,
        serviceDistribution: "Normal",
        meanServiceTime: 0,
        interarrivalDistribution: "Constant",
        meanInterarrivalTime: 0.5,
        batchSize: 2,
        queueCapacity: -1
    )
    let finiteDiagnostics = FiniteCapacityQueueValidator.diagnostics(for: invalidFinite)
    #expect(finiteDiagnostics.contains { $0.code == "queuing.finiteCapacity.servers" })
    #expect(finiteDiagnostics.contains { $0.code == "queuing.finiteCapacity.meanServiceTime" })
    #expect(finiteDiagnostics.contains { $0.code == "queuing.finiteCapacity.batchSize" })
    #expect(finiteDiagnostics.contains { $0.code == "queuing.finiteCapacity.queueCapacity" })
    #expect(finiteDiagnostics.contains { $0.code == "queuing.finiteCapacity.interarrivalDistribution" })
}

@Test func routesQueuingModelsThroughNamedBackends() throws {
    let mm1Data = try Data(contentsOf: legacyFixtureURL("QUEUE1.QA_"))
    let mm1Expanded = try LegacyCompressedFile.expandedData(from: mm1Data)
    let mm1 = try WinQSBQueuingParser.parseMM1(from: mm1Expanded)

    let finiteData = try Data(contentsOf: legacyFixtureURL("QUEUE2.QA_"))
    let finiteExpanded = try LegacyCompressedFile.expandedData(from: finiteData)
    let finite = try WinQSBQueuingParser.parseFiniteCapacity(from: finiteExpanded)

    let nativeBackend = NativeEducationalQueuingBackend()
    #expect(nativeBackend.capabilities.backendKind == .nativeEducational)
    #expect(nativeBackend.capabilities.solves)
    #expect(nativeBackend.capabilities.validates)
    #expect(nativeBackend.capabilities.exportsStructuredSolution)
    #expect(abs(try nativeBackend.solve(mm1).utilization - 2.0 / 3.0) < 1e-8)
    #expect(abs(try nativeBackend.solve(finite).effectiveArrivalRate - 1.8822447082925162) < 1e-8)

    let validateBackend = ValidateOnlyQueuingBackend()
    #expect(!validateBackend.capabilities.solves)
    #expect(validateBackend.validationReport(for: mm1).isValid)
    #expect(validateBackend.validationReport(for: finite).isValid)
    #expect(validateBackend.validationReport(for: finite).diagnostics.contains {
        $0.severity == .warning && $0.code == "queuing.finiteCapacity.serviceApproximation"
    })

    do {
        _ = try validateBackend.solve(mm1)
        Issue.record("Expected validateOnly backend to reject M/M/1 solving")
    } catch QueuingModelError.invalidModel(let message) {
        #expect(message.contains("validateOnly"))
    }

    let selectedBackend = try #require(QueuingBackends.backend(for: .nativeEducational))
    #expect(selectedBackend.capabilities.backendKind == .nativeEducational)
    #expect(QueuingBackends.backend(for: .externalHighPerformance) == nil)
}

@Test func encodesNormalizedQueuingSolutionDocuments() throws {
    let mm1Data = try Data(contentsOf: legacyFixtureURL("QUEUE1.QA_"))
    let mm1Expanded = try LegacyCompressedFile.expandedData(from: mm1Data)
    let mm1 = try WinQSBQueuingParser.parseMM1(from: mm1Expanded)
    let mm1Solution = try NativeEducationalQueuingBackend().solve(mm1)
    let mm1Document = QueuingSolutionJSON.mm1Document(
        model: mm1,
        solution: mm1Solution,
        backend: SolverRunMetadata(
            backendKind: .nativeEducational,
            algorithm: "mm1ClosedForm",
            exactness: .closedForm
        )
    )
    let mm1JSON = try QueuingSolutionJSON.encode(mm1Document)
    let decodedMM1 = try JSONDecoder().decode(QueuingSolutionDocument.self, from: mm1JSON)

    #expect(decodedMM1.kind == .mm1)
    #expect(decodedMM1.notation == "M/M/1")
    #expect(decodedMM1.backend.exactness == .closedForm)
    #expect(decodedMM1.metrics.servers == 1)
    #expect(decodedMM1.metrics.systemCapacity == nil)
    #expect(decodedMM1.metrics.blockingProbability == 0)
    #expect(abs(decodedMM1.metrics.averageNumberInQueue - 4.0 / 3.0) < 1e-8)
    #expect(abs((decodedMM1.cost?.totalCost ?? 0) - 300) < 1e-8)

    let finiteData = try Data(contentsOf: legacyFixtureURL("QUEUE2.QA_"))
    let finiteExpanded = try LegacyCompressedFile.expandedData(from: finiteData)
    let finite = try WinQSBQueuingParser.parseFiniteCapacity(from: finiteExpanded)
    let finiteSolution = try NativeEducationalQueuingBackend().solve(finite)
    let finiteDocument = QueuingSolutionJSON.finiteCapacityDocument(
        model: finite,
        solution: finiteSolution,
        backend: SolverRunMetadata(
            backendKind: .nativeEducational,
            algorithm: "finiteCapacityBirthDeath",
            exactness: .approximate
        )
    )
    let finiteJSON = try QueuingSolutionJSON.encode(finiteDocument)
    let decodedFinite = try JSONDecoder().decode(QueuingSolutionDocument.self, from: finiteJSON)
    let finiteText = try #require(String(data: finiteJSON, encoding: .utf8))

    #expect(decodedFinite.kind == .finiteCapacity)
    #expect(decodedFinite.notation == "M/G/2/5")
    #expect(decodedFinite.backend.exactness == .approximate)
    #expect(decodedFinite.metrics.systemCapacity == 5)
    #expect(decodedFinite.stateProbabilities.count == 6)
    #expect(abs(decodedFinite.metrics.blockingProbability - 0.05887764585374193) < 1e-8)
    #expect(abs((decodedFinite.cost?.totalCost ?? 0) - 339.09383689684665) < 1e-8)
    #expect(finiteText.contains("\"effectiveArrivalRate\""))
    #expect(finiteText.contains("\"stateProbabilities\""))
}

@Test func encodesAndDecodesNormalizedNetworkJSONModel() throws {
    let url = legacyFixtureURL("TSP.NE_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)
    let model = try WinQSBNetworkParser.parseModelEnvelope(from: expanded)

    let json = try NetworkModelJSON.encodeModel(model)
    let decoded = try NetworkModelJSON.decodeModel(from: json)

    #expect(decoded == model)
    #expect(String(data: json, encoding: .utf8)?.contains("\"kind\" : \"TSP\"") == true)
}

@Test func solvesDecodedNetworkJSONModel() throws {
    let url = legacyFixtureURL("SHTPATH.NE_")
    let data = try Data(contentsOf: url)
    let expanded = try LegacyCompressedFile.expandedData(from: data)
    let model = try WinQSBNetworkParser.parseModelEnvelope(from: expanded)
    let json = try NetworkModelJSON.encodeModel(model)
    let decoded = try NetworkModelJSON.decodeModel(from: json)

    guard case .shortestPath(let network) = decoded else {
        Issue.record("Expected shortest path network JSON")
        return
    }
    let solution = try ShortestPathSolver.solve(network)
    let solutionJSON = try NetworkModelJSON.encodeSolution(.shortestPath(solution))
    let solutionText = try #require(String(data: solutionJSON, encoding: .utf8))

    #expect(abs(solution.totalCost - 29) < 1e-8)
    #expect(solutionText.contains("\"kind\" : \"SPP\""))
    #expect(solutionText.contains("\"totalCost\" : 29"))
}

@Test func routesAllNetworkModelsThroughNamedBackends() throws {
    let fixtures = ["NETFLOW.NE_", "SHTPATH.NE_", "SPANTREE.NE_", "MAXFLOW.NE_", "TSP.NE_", "ASSIMENT.NE_", "TRNSPORT.NE_"]
    let expectedAlgorithms = ["continuousLinearProgramming", "dijkstra", "kruskal", "edmondsKarp", "heldKarpDynamicProgramming", "hungarianRectangular", "continuousLinearProgramming"]
    let native = NativeEducationalNetworkBackend()
    let validateOnly = ValidateOnlyNetworkBackend()

    for (fixture, algorithm) in zip(fixtures, expectedAlgorithms) {
        let expanded = try LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL(fixture)))
        let model = try WinQSBNetworkParser.parseModelEnvelope(from: expanded)
        #expect(validateOnly.validationReport(for: model).isValid)
        #expect(native.runMetadata(for: model).algorithm == algorithm)
        let solution = try native.solve(model)
        #expect(solution.kind == model.kind)
        let document = native.solutionDocument(for: model, solution: solution)
        let encoded = try NetworkModelJSON.encodeSolutionDocument(document)
        #expect(try NetworkModelJSON.decodeSolutionDocument(from: encoded) == document)
    }

    #expect(native.runMetadata(for: try WinQSBNetworkParser.parseModelEnvelope(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("TSP.NE_"))))).exactness == .fixtureScale)
    #expect(NetworkBackends.backend(for: .externalHighPerformance) == nil)
}

@Test func validatesNetworkModelsWithStructuredDiagnostics() throws {
    let invalidGraph = NetworkModelEnvelope.shortestPath(ShortestPathNetwork(
        title: "Invalid",
        nodes: ["A", "A"],
        arcs: [NetworkArc(from: "A", to: "B", cost: -1)]
    ))
    let graphReport = ValidateOnlyNetworkBackend().validationReport(for: invalidGraph)
    #expect(!graphReport.isValid)
    #expect(graphReport.diagnostics.contains { $0.code == "network.SPP.nodes.duplicate" })
    #expect(graphReport.diagnostics.contains { $0.code == "network.SPP.arc.endpoint" })
    #expect(graphReport.diagnostics.contains { $0.code == "network.SPP.arc.value" })

    let invalidAssignment = NetworkModelEnvelope.assignment(AssignmentProblem(
        title: "Invalid",
        workers: ["W1", "W2"],
        tasks: ["T1"],
        costs: [[1], [2]]
    ))
    let assignmentReport = ValidateOnlyNetworkBackend().validationReport(for: invalidAssignment)
    #expect(!assignmentReport.isValid)
    #expect(assignmentReport.diagnostics.contains { $0.code == "network.AP.tasks.insufficient" })

    do {
        _ = try ValidateOnlyNetworkBackend().solve(invalidGraph)
        Issue.record("validateOnly unexpectedly solved a network model")
    } catch {
        #expect(String(describing: error).contains("validateOnly"))
    }
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

private func expectInvalidModel(_ json: String, containing expectedText: String) throws {
    do {
        _ = try LinearProgramJSON.decodeProgram(from: Data(json.utf8))
        Issue.record("Expected JSON model to be rejected")
    } catch LinearProgramError.invalidModel(let message) {
        #expect(message.contains(expectedText))
    }
}
