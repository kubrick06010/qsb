import Testing
import QSBCore
@testable import QSBMacApp

@Test("quadratic-programming sample produces typed optimum details")
func quadraticProgrammingSampleProducesTypedPresentation() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.quadraticProgramming)
    workspace.runCurrentModel()

    let document = try #require(workspace.quadraticProgrammingSolution)
    #expect(document.model.title == "Convex Quadratic Sample")
    #expect(abs(document.solution.objectiveValue + 4) < 1e-8)
    #expect(abs((document.solution.variableValues["x"] ?? 0) - 2) < 1e-8)
    #expect(document.backend.exactness == .exact)
    #expect(workspace.runState == .solved)
}

@Test("nonlinear-programming sample produces typed convergence details")
func nonlinearProgrammingSampleProducesTypedPresentation() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.nonlinearProgramming)
    workspace.runCurrentModel()

    let document = try #require(workspace.nonlinearProgrammingSolution)
    #expect(document.model.title == "Bounded Nonlinear Sample")
    #expect(abs(document.solution.objectiveValue) < 1e-8)
    #expect(abs((document.solution.variableValues["x"] ?? 0) - 3) < 1e-6)
    #expect(document.solution.maximumViolation == 0)
    #expect(document.backend.exactness == .approximate)
    #expect(workspace.runState == .solved)
}
