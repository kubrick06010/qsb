import Testing
import QSBCore
@testable import QSBMacApp

struct QueuingSolutionTests {
    @Test("M/M/1 sample routes through the workbench into a typed queue solution")
    func sampleRouting() throws {
        let workspace = QSBWorkspace()

        workspace.loadSample(.linearTrendForecast)
        workspace.loadSample(.mm1Queue)
        guard case .queuing(.mm1) = workspace.currentModelFamily else {
            Issue.record("Expected the M/M/1 sample to replace the prior native draft")
            return
        }

        workspace.runCurrentModel()

        let document = try #require(workspace.queuingSolution)
        #expect(document.kind == .mm1)
        #expect(document.notation == "M/M/1")
        #expect(abs(document.metrics.utilization - (2.0 / 3.0)) < 1e-8)
        #expect(workspace.runState == .solved)
    }
}
