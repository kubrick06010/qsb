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

