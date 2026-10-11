import Testing
import QSBCore
@testable import QSBMacApp

@Test("goal-programming sample produces a typed document for the native result view")
func goalProgrammingSampleProducesTypedPresentation() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.goalProgramming)

    guard case .goalProgramming = workspace.currentModelFamily else {
        Issue.record("Expected Goal Programming family detection")
        return
    }

    workspace.runCurrentModel()

    let document = try #require(workspace.goalProgrammingSolution)
    #expect(document.model.title == "Lexicographic Goal Sample")
    #expect(document.solution.goalOutcomes.map(\.name) == ["Primary Output", "Secondary Output"])
    #expect(document.solution.goalOutcomes.map(\.value) == [10, 0])
    #expect(document.solution.variableValues["Primary"] == 10)
    #expect(document.solution.variableValues["Secondary"] == 0)
    #expect(document.backend.backendKind == .nativeEducational)
    #expect(workspace.runState == .solved)
}
