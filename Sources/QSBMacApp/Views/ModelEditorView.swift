import SwiftUI

struct ModelEditorView: View {
    @Bindable var workspace: QSBWorkspace

    var body: some View {
        if workspace.isLinearProgrammingModel {
            LinearProgrammingEditorView(workspace: workspace)
        } else if workspace.isInventoryModel, workspace.inventoryDraft != nil {
            InventoryEditorView(workspace: workspace)
        } else if workspace.assignmentDraft != nil {
            AssignmentEditorView(workspace: workspace)
        } else if workspace.transportationDraft != nil {
            TransportationEditorView(workspace: workspace)
        } else if workspace.networkFlowDraft != nil {
            NetworkFlowEditorView(workspace: workspace)
        } else if workspace.forecastingDraft != nil {
            ForecastingEditorView(workspace: workspace)
        } else if workspace.markovDraft != nil {
            MarkovEditorView(workspace: workspace)
        } else if workspace.queuingDraft != nil {
            QueuingEditorView(workspace: workspace)
        } else if workspace.decisionDraft != nil {
            DecisionAnalysisEditorView(workspace: workspace)
        } else if workspace.zeroSumGameDraft != nil {
            ZeroSumGameEditorView(workspace: workspace)
        } else if workspace.decisionTreeDraft != nil {
            DecisionTreeEditorView(workspace: workspace)
        } else if workspace.projectSchedulingDraft != nil {
            ProjectSchedulingEditorView(workspace: workspace)
        } else if workspace.aggregatePlanningDraft != nil {
            AggregatePlanningEditorView(workspace: workspace)
        } else if workspace.materialRequirementsPlanningDraft != nil {
            MaterialRequirementsPlanningEditorView(workspace: workspace)
        } else if workspace.simulationDraft != nil {
            SimulationEditorView(workspace: workspace)
        } else if workspace.knapsackDraft != nil {
            KnapsackEditorView(workspace: workspace)
        } else if workspace.acceptanceSamplingDraft != nil {
            AcceptanceSamplingEditorView(workspace: workspace)
        } else if workspace.qualityControlDraft != nil {
            QualityControlEditorView(workspace: workspace)
        } else if workspace.facilityLayoutDraft != nil {
            FacilityLayoutEditorView(workspace: workspace)
        } else if workspace.lineBalancingDraft != nil {
            LineBalancingEditorView(workspace: workspace)
        } else if workspace.facilityLocationDraft != nil {
            FacilityLocationEditorView(workspace: workspace)
        } else if workspace.goalProgrammingDraft != nil {
            GoalProgrammingEditorView(workspace: workspace)
        } else if workspace.nonlinearProgrammingDraft != nil {
            NonlinearProgrammingEditorView(workspace: workspace)
        } else if workspace.quadraticProgrammingDraft != nil {
            QuadraticProgrammingEditorView(workspace: workspace)
        } else if workspace.isNetworkModel, workspace.networkDraft != nil {
            NetworkEditorView(workspace: workspace)
        } else if workspace.hasModel {
            StructuredModelEditorView(workspace: workspace)
        } else {
            EmptyWorkspaceView(workspace: workspace)
        }
    }
}
