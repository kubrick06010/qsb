import Foundation
import Testing
@testable import QSBCore

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

@Test func optimizesCPMCrashTimeCostTradeoffThroughNativeLP() throws {
    let project = CPMProject(
        title: "Crash sample",
        timeUnit: "days",
        activities: [
            CPMActivity(name: "A", predecessors: [], normalTime: 5, crashTime: 3, normalCost: 10, crashCost: 30),
            CPMActivity(name: "B", predecessors: ["A"], normalTime: 4, crashTime: 2, normalCost: 20, crashCost: 24),
            CPMActivity(name: "C", predecessors: ["A"], normalTime: 6, crashTime: 5, normalCost: 15, crashCost: 45),
            CPMActivity(name: "D", predecessors: ["B", "C"], normalTime: 2, crashTime: 2, normalCost: 5, crashCost: 5)
        ]
    )
    let result = try CPMCrashSolver.solve(project, targetDuration: 11)
    #expect(abs(result.normalProjectDuration - 13) < 1e-8)
    #expect(result.isFeasible)
    #expect(abs(result.plannedProjectDuration - 11) < 1e-7)
    #expect(abs(result.plannedCost - 70) < 1e-7)
    #expect(result.activityPlans.first { $0.name == "C" }?.reduction ?? -1 < 1e-8)
    #expect(abs((result.activityPlans.first { $0.name == "A" }?.reduction ?? 0) - 2) < 1e-7)
}

@Test func rejectsCPMCrashDeadlineBelowAllCrashDuration() throws {
    let project = CPMProject(
        title: "Infeasible crash",
        timeUnit: "days",
        activities: [CPMActivity(name: "A", predecessors: [], normalTime: 5, crashTime: 3, normalCost: 1, crashCost: 2)]
    )
    #expect(throws: ProjectSchedulingError.self) { _ = try CPMCrashSolver.solve(project, targetDuration: 2) }
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
