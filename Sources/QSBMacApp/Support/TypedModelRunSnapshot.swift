import QSBCore

/// Tracks editable input, including invalid strings and dormant variant fields.
struct TypedModelRunSnapshot: Equatable {
    let json: String
    let backend: SolverBackendKind
    let quadraticProgrammingDraft: QuadraticProgrammingDraft?
    let nonlinearProgrammingDraft: NonlinearProgrammingDraft?
    let goalProgrammingDraft: GoalProgrammingDraft?
    let acceptanceSamplingDraft: AcceptanceSamplingDraft?
    let qualityControlDraft: QualityControlDraft?

    @MainActor
    init(_ workspace: QSBWorkspace) {
        json = workspace.modelJSON
        backend = workspace.selectedBackend
        quadraticProgrammingDraft = workspace.quadraticProgrammingDraft
        nonlinearProgrammingDraft = workspace.nonlinearProgrammingDraft
        goalProgrammingDraft = workspace.goalProgrammingDraft
        acceptanceSamplingDraft = workspace.acceptanceSamplingDraft
        qualityControlDraft = workspace.qualityControlDraft
    }
}
