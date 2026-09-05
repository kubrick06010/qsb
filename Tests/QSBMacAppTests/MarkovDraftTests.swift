import Foundation
import Testing
@testable import QSBMacApp
@testable import QSBCore

@Test("blank Markov draft converts through the existing backend")
func blankMarkovDraftConvertsAndSolves() throws {
    let draft = MarkovDraft.blank()
    let request = try draft.makeRequest()
    let backend = try #require(MarkovBackends.backend(for: .nativeEducational))
    let solution = try backend.solve(request)

    #expect(request.model.states == ["State 1", "State 2"])
    #expect(request.model.transitionMatrix == [[0.8, 0.2], [0.3, 0.7]])
    #expect(solution.transientResults.count == 11)
    #expect(solution.stationaryProbabilities.count == 2)
}

@Test("Markov state mutations preserve matrix dimensions and existing identities")
func markovDraftStateMutationsAreDimensionSafe() throws {
    var draft = MarkovDraft.blank()
    let firstID = try #require(draft.states.first?.id)

    draft.addState()
    #expect(draft.states.count == 3)
    #expect(draft.transitionMatrix.count == 3)
    #expect(draft.transitionMatrix.allSatisfy { $0.count == 3 })
    #expect(draft.states.first?.id == firstID)
    #expect(draft.transitionMatrix[2] == ["0", "0", "1"])

    draft.removeState(at: 1)
    #expect(draft.states.count == 2)
    #expect(draft.transitionMatrix.count == 2)
    #expect(draft.transitionMatrix.allSatisfy { $0.count == 2 })
    #expect(draft.states.first?.id == firstID)
}

@Test("Markov draft keeps malformed input visible as structured diagnostics")
func markovDraftDiagnosticsPreserveInputErrors() {
    var draft = MarkovDraft.blank()
    draft.states[0].name = ""
    draft.transitionMatrix[0][0] = "unfinished"
    draft.periodsText = "many"

    let diagnostics = draft.draftDiagnostics()

    #expect(diagnostics.contains { $0.code == "markov.draft.model_states_0" })
    #expect(diagnostics.contains { $0.code == "markov.draft.model_transitionMatrix_0_0" })
    #expect(diagnostics.contains { $0.code == "markov.draft.periods" })
}

@Test("Markov draft can inspect dimensionally invalid normalized input")
func markovDraftHandlesInvalidDimensionsWithoutCrashing() throws {
    let request = MarkovAnalysisRequest(
        model: MarkovChainModel(
            title: "Invalid",
            states: ["A", "B"],
            transitionMatrix: [[1]],
            initialProbabilities: [1],
            stateCosts: [4]
        ),
        periods: 2
    )
    let draft = MarkovDraft(request)

    #expect(draft.states.count == 2)
    #expect(draft.draftDiagnostics().contains { $0.code == "markov.draft.model_transitionMatrix" })
}

@Test("workspace routes a Markov draft through JSON and the shared backend")
func workspaceRoutesMarkovDraftThroughExistingWorkflow() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.markov)

    #expect(workspace.markovDraft != nil)
    if case .markov = workspace.currentModelFamily {
    } else {
        Issue.record("Expected Markov family detection")
    }

    workspace.updateMarkovDraft { draft in
        draft.states[0].costText = "9"
    }
    workspace.runCurrentModel()

    let solution = try #require(workspace.markovSolution)
    #expect(solution.request.model.stateCosts[0] == 9)
    #expect(workspace.solutionJSON.contains("stationaryProbabilities"))
}
