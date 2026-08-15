import Foundation
import Testing
@testable import QSBCore

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

