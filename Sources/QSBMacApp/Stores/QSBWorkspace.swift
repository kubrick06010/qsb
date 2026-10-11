import Foundation
import AppKit
import Observation
import QSBCore
import SwiftUI

@Observable
final class QSBWorkspace {
    var selectedPane: WorkspacePane? = .overview
    var modelJSON: String {
        didSet {
            guard oldValue != modelJSON else { return }
            modelState = modelJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : .editing
            runState = .notRun
            solutionJSON = ""
            validationJSON = ""
            validationDiagnostics = []
            runNotes = []
            lastResultLabel = nil
            lastErrorMessage = nil
        }
    }
    var lpDraft: LinearProgrammingDraft?
    var inventoryDraft: InventoryDraft?
    var networkDraft: NetworkDraft?
    var networkFlowDraft: NetworkFlowDraft?
    var assignmentDraft: AssignmentDraft?
    var transportationDraft: TransportationDraft?
    var forecastingDraft: ForecastingDraft?
    var markovDraft: MarkovDraft?
    var queuingDraft: QueuingDraft?
    var decisionDraft: DecisionAnalysisDraft?
    var zeroSumGameDraft: ZeroSumGameDraft?
    var decisionTreeDraft: DecisionTreeDraft?
    var projectSchedulingDraft: ProjectSchedulingDraft?
    var aggregatePlanningDraft: AggregatePlanningDraft?
    var materialRequirementsPlanningDraft: MaterialRequirementsPlanningDraft?
    var simulationDraft: SimulationDraft?
    var knapsackDraft: KnapsackDraft?
    var acceptanceSamplingDraft: AcceptanceSamplingDraft?
    var qualityControlDraft: QualityControlDraft?
    var quadraticProgrammingDraft: QuadraticProgrammingDraft?
    var nonlinearProgrammingDraft: NonlinearProgrammingDraft?
    var goalProgrammingDraft: GoalProgrammingDraft?
    var facilityLocationDraft: FacilityLocationDraft?
    var lineBalancingDraft: LineBalancingDraft?
    var facilityLayoutDraft: FacilityLayoutDraft?
    var solutionJSON: String = ""
    var validationJSON: String = ""
    var validationDiagnostics: [ValidationDiagnostic] = []
    var status: String = "Ready"
    var lastResultLabel: String?
    var modelSource: String = "New model"
    var modelState: ModelLifecycleState
    var runState: RunLifecycleState = .notRun {
        didSet {
            // Edits, validation, imports, and synchronous runs invalidate pending UI results.
            if runState != .solving { interactiveRunID = nil }
        }
    }
    @ObservationIgnored private var interactiveRunID: UUID?
    var lastErrorMessage: String?
    var runNotes: [String] = []
    var selectedBackend: SolverBackendKind = .nativeEducational
    var selectedLayoutStrategy: FacilityLayoutSolvingStrategy = .initial
    var simulationReplications = 1
    var isImportingModel = false
    var isShowingNewModelPicker = false
    var isExportingModel = false
    var isExportingSolution = false
    var isShowingAbout = false

    init(modelJSON: String = "") {
        self.modelJSON = modelJSON
        self.modelState = modelJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : .editing
        if let program = try? LinearProgramJSON.decodeProgram(from: Data(modelJSON.utf8)) {
            self.lpDraft = LinearProgrammingDraft(program: program)
        } else {
            self.lpDraft = nil
        }
        if let envelope = try? InventoryModelJSON.decodeUncheckedModel(from: Data(modelJSON.utf8)) {
            self.inventoryDraft = InventoryDraft(envelope)
        } else {
            self.inventoryDraft = nil
        }
        if let envelope = try? NetworkModelJSON.decodeModel(from: Data(modelJSON.utf8)) {
            self.networkDraft = NetworkDraft(envelope: envelope)
            self.networkFlowDraft = NetworkFlowDraft(envelope: envelope)
            self.assignmentDraft = AssignmentDraft(envelope: envelope)
            self.transportationDraft = TransportationDraft(envelope: envelope)
        } else {
            self.networkDraft = nil
            self.networkFlowDraft = nil
            self.assignmentDraft = nil
            self.transportationDraft = nil
        }
        if let request = try? ForecastingModelJSON.decodeRequest(from: Data(modelJSON.utf8)) {
            self.forecastingDraft = ForecastingDraft(request)
        } else {
            self.forecastingDraft = nil
        }
        if let request = try? MarkovJSON.decodeRequest(from: Data(modelJSON.utf8)) {
            self.markovDraft = MarkovDraft(request)
        } else {
            self.markovDraft = nil
        }
        if let envelope = try? QueuingModelJSON.decodeModel(from: Data(modelJSON.utf8)) {
            self.queuingDraft = QueuingDraft(envelope)
        } else {
            self.queuingDraft = nil
        }
        if let envelope = try? DecisionAnalysisModelJSON.decodeModel(from: Data(modelJSON.utf8)) {
            self.decisionDraft = DecisionAnalysisDraft(envelope)
            self.zeroSumGameDraft = ZeroSumGameDraft(envelope)
            self.decisionTreeDraft = DecisionTreeDraft(envelope)
        } else {
            self.decisionDraft = nil
            self.zeroSumGameDraft = nil
            self.decisionTreeDraft = nil
        }
        if let envelope = try? ProjectSchedulingJSON.decodeModel(from: Data(modelJSON.utf8)) {
            self.projectSchedulingDraft = ProjectSchedulingDraft(envelope)
        } else {
            self.projectSchedulingDraft = nil
            self.aggregatePlanningDraft = nil
            self.materialRequirementsPlanningDraft = nil
            self.simulationDraft = nil
            self.knapsackDraft = nil
            self.acceptanceSamplingDraft = nil
            self.qualityControlDraft = nil
            self.quadraticProgrammingDraft = nil
            self.nonlinearProgrammingDraft = nil
            self.goalProgrammingDraft = nil
            self.facilityLocationDraft = nil
            self.lineBalancingDraft = nil
            self.facilityLayoutDraft = nil
        }
        if let model = try? AggregatePlanningJSON.decodeModel(from: Data(modelJSON.utf8)) {
            self.aggregatePlanningDraft = AggregatePlanningDraft(model)
        } else {
            self.aggregatePlanningDraft = nil
            self.materialRequirementsPlanningDraft = nil
            self.simulationDraft = nil
            self.knapsackDraft = nil
            self.acceptanceSamplingDraft = nil
            self.qualityControlDraft = nil
            self.quadraticProgrammingDraft = nil
            self.nonlinearProgrammingDraft = nil
            self.goalProgrammingDraft = nil
            self.facilityLocationDraft = nil
            self.lineBalancingDraft = nil
            self.facilityLayoutDraft = nil
        }
        if let model = try? MaterialRequirementsPlanningJSON.decodeModel(from: Data(modelJSON.utf8)) {
            self.materialRequirementsPlanningDraft = MaterialRequirementsPlanningDraft(model)
        } else {
            self.materialRequirementsPlanningDraft = nil
            self.simulationDraft = nil
            self.knapsackDraft = nil
            self.acceptanceSamplingDraft = nil
            self.qualityControlDraft = nil
            self.quadraticProgrammingDraft = nil
            self.nonlinearProgrammingDraft = nil
            self.goalProgrammingDraft = nil
            self.facilityLocationDraft = nil
            self.lineBalancingDraft = nil
            self.facilityLayoutDraft = nil
        }
        if let model = try? SimulationJSON.decodeUncheckedModel(from: Data(modelJSON.utf8)) {
            self.simulationDraft = SimulationDraft(model)
        } else {
            self.simulationDraft = nil
            self.knapsackDraft = nil
            self.acceptanceSamplingDraft = nil
            self.qualityControlDraft = nil
            self.quadraticProgrammingDraft = nil
            self.nonlinearProgrammingDraft = nil
            self.goalProgrammingDraft = nil
            self.facilityLocationDraft = nil
            self.lineBalancingDraft = nil
            self.facilityLayoutDraft = nil
        }
        if let envelope = try? DynamicProgrammingModelJSON.decodeUncheckedModel(from: Data(modelJSON.utf8)),
           case .boundedKnapsack(let problem) = envelope {
            self.knapsackDraft = KnapsackDraft(problem)
        } else {
            self.knapsackDraft = nil
            self.acceptanceSamplingDraft = nil
            self.qualityControlDraft = nil
            self.quadraticProgrammingDraft = nil
            self.nonlinearProgrammingDraft = nil
            self.goalProgrammingDraft = nil
            self.facilityLocationDraft = nil
            self.lineBalancingDraft = nil
            self.facilityLayoutDraft = nil
        }
        if let model = try? AcceptanceSamplingJSON.decodeModel(from: Data(modelJSON.utf8)) {
            self.acceptanceSamplingDraft = AcceptanceSamplingDraft(model)
        } else {
            self.acceptanceSamplingDraft = nil
            self.qualityControlDraft = nil
            self.quadraticProgrammingDraft = nil
            self.nonlinearProgrammingDraft = nil
            self.goalProgrammingDraft = nil
            self.facilityLocationDraft = nil
            self.lineBalancingDraft = nil
            self.facilityLayoutDraft = nil
        }
        if let model = try? QualityControlJSON.decodeModel(from: Data(modelJSON.utf8)) {
            self.qualityControlDraft = QualityControlDraft(model)
        } else {
            self.qualityControlDraft = nil
            self.quadraticProgrammingDraft = nil
            self.nonlinearProgrammingDraft = nil
            self.goalProgrammingDraft = nil
            self.facilityLocationDraft = nil
            self.lineBalancingDraft = nil
            self.facilityLayoutDraft = nil
        }
        if let model = try? QuadraticProgrammingJSON.decodeUncheckedModel(from: Data(modelJSON.utf8)) {
            self.quadraticProgrammingDraft = QuadraticProgrammingDraft(model)
        } else {
            self.quadraticProgrammingDraft = nil
            self.nonlinearProgrammingDraft = nil
            self.goalProgrammingDraft = nil
            self.facilityLocationDraft = nil
            self.lineBalancingDraft = nil
            self.facilityLayoutDraft = nil
        }
        nonlinearProgrammingDraft = (try? NonlinearProgrammingJSON.decodeUncheckedModel(from: Data(modelJSON.utf8))).map(NonlinearProgrammingDraft.init)
        goalProgrammingDraft = (try? GoalProgrammingJSON.decodeModel(from: Data(modelJSON.utf8))).map(GoalProgrammingDraft.init)
        if let envelope = try? FacilitiesModelJSON.decodeUncheckedModel(from: Data(modelJSON.utf8)), case .location(let problem) = envelope { facilityLocationDraft = FacilityLocationDraft(problem) }
        if let envelope = try? FacilitiesModelJSON.decodeUncheckedModel(from: Data(modelJSON.utf8)), case .lineBalancing(let problem) = envelope { lineBalancingDraft = LineBalancingDraft(problem) }
        if let envelope = try? FacilitiesModelJSON.decodeUncheckedModel(from: Data(modelJSON.utf8)), case .layout(let problem) = envelope { facilityLayoutDraft = FacilityLayoutDraft(problem) }
    }

    func startNewLinearProgram() {
        lpDraft = .blank()
        inventoryDraft = nil
        networkDraft = nil
        networkFlowDraft = nil
        assignmentDraft = nil
        transportationDraft = nil
        forecastingDraft = nil
        markovDraft = nil
        queuingDraft = nil
        decisionDraft = nil
        zeroSumGameDraft = nil
        decisionTreeDraft = nil
        projectSchedulingDraft = nil
        aggregatePlanningDraft = nil
        materialRequirementsPlanningDraft = nil
        simulationDraft = nil
        knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
        modelJSON = ""
        modelSource = "New · Linear Programming"
        modelState = .editing
        runState = .notRun
        solutionJSON = ""
        validationJSON = ""
        validationDiagnostics = []
        lastErrorMessage = nil
        lastResultLabel = nil
        status = "Editing a new linear program"
        selectedPane = .model
    }

    func startNewModelSelection() {
        isShowingNewModelPicker = true
    }

    func startNewInventory(_ kind: InventoryProblemKind) {
        lpDraft = nil
        networkDraft = nil
        networkFlowDraft = nil
        assignmentDraft = nil
        transportationDraft = nil
        forecastingDraft = nil
        markovDraft = nil
        queuingDraft = nil
        decisionDraft = nil
        zeroSumGameDraft = nil
        decisionTreeDraft = nil
        projectSchedulingDraft = nil
        aggregatePlanningDraft = nil
        materialRequirementsPlanningDraft = nil
        simulationDraft = nil
        knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
        inventoryDraft = .blank(kind)
        modelJSON = ""
        modelSource = "New · Inventory · \(kind.displayName)"
        modelState = .editing
        runState = .notRun
        solutionJSON = ""
        validationJSON = ""
        validationDiagnostics = []
        lastErrorMessage = nil
        lastResultLabel = nil
        status = "Editing a new \(kind.displayName) model"
        selectedPane = .model
    }

    func startNewNetwork(_ kind: NetworkDraftKind) {
        lpDraft = nil
        inventoryDraft = nil
        assignmentDraft = nil
        transportationDraft = nil
        forecastingDraft = nil
        markovDraft = nil
        queuingDraft = nil
        decisionDraft = nil
        zeroSumGameDraft = nil
        decisionTreeDraft = nil
        projectSchedulingDraft = nil
        aggregatePlanningDraft = nil
        materialRequirementsPlanningDraft = nil
        simulationDraft = nil
        knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
        networkDraft = .blank(kind)
        networkFlowDraft = nil
        modelJSON = ""
        modelSource = "New · Network · \(kind.displayName)"
        modelState = .editing
        runState = .notRun
        solutionJSON = ""
        validationJSON = ""
        validationDiagnostics = []
        lastErrorMessage = nil
        lastResultLabel = nil
        status = "Editing a new \(kind.displayName) model"
        selectedPane = .model
    }

    func startNewAssignment() {
        lpDraft = nil
        inventoryDraft = nil
        networkDraft = nil
        networkFlowDraft = nil
        transportationDraft = nil
        markovDraft = nil
        queuingDraft = nil
        decisionDraft = nil
        zeroSumGameDraft = nil
        decisionTreeDraft = nil
        projectSchedulingDraft = nil
        aggregatePlanningDraft = nil
        materialRequirementsPlanningDraft = nil
        simulationDraft = nil
        knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
        assignmentDraft = .blank()
        prepareNewNetworkModel(source: "New · Network · Assignment", status: "Editing a new Assignment model")
    }

    func startNewTransportation() {
        lpDraft = nil
        inventoryDraft = nil
        networkDraft = nil
        networkFlowDraft = nil
        assignmentDraft = nil
        transportationDraft = .blank()
        markovDraft = nil
        queuingDraft = nil
        decisionDraft = nil
        zeroSumGameDraft = nil
        decisionTreeDraft = nil
        projectSchedulingDraft = nil
        aggregatePlanningDraft = nil
        materialRequirementsPlanningDraft = nil
        simulationDraft = nil
        knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
        prepareNewNetworkModel(source: "New · Network · Transportation", status: "Editing a new Transportation model")
    }

    func startNewNetworkFlow() {
        lpDraft = nil
        inventoryDraft = nil
        networkDraft = nil
        networkFlowDraft = .blank()
        assignmentDraft = nil
        transportationDraft = nil
        forecastingDraft = nil
        markovDraft = nil
        queuingDraft = nil
        decisionDraft = nil
        zeroSumGameDraft = nil
        decisionTreeDraft = nil
        projectSchedulingDraft = nil
        aggregatePlanningDraft = nil
        materialRequirementsPlanningDraft = nil
        simulationDraft = nil
        knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
        prepareNewNetworkModel(source: "New · Network · Minimum-Cost Transshipment", status: "Editing a new minimum-cost transshipment model")
    }

    func startNewForecasting(_ method: ForecastingMethod) {
        lpDraft = nil
        inventoryDraft = nil
        networkDraft = nil
        networkFlowDraft = nil
        assignmentDraft = nil
        transportationDraft = nil
        forecastingDraft = .blank(method)
        markovDraft = nil
        queuingDraft = nil
        decisionDraft = nil
        zeroSumGameDraft = nil
        decisionTreeDraft = nil
        projectSchedulingDraft = nil
        aggregatePlanningDraft = nil
        materialRequirementsPlanningDraft = nil
        simulationDraft = nil
        knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
        modelJSON = ""
        modelSource = "New · Forecasting · \(method.displayName)"
        modelState = .editing
        runState = .notRun
        solutionJSON = ""
        validationJSON = ""
        validationDiagnostics = []
        lastErrorMessage = nil
        lastResultLabel = nil
        status = "Editing a new \(method.displayName) model"
        selectedPane = .model
    }

    func startNewMarkov() {
        lpDraft = nil
        inventoryDraft = nil
        networkDraft = nil
        networkFlowDraft = nil
        assignmentDraft = nil
        transportationDraft = nil
        forecastingDraft = nil
        markovDraft = .blank()
        queuingDraft = nil
        decisionDraft = nil
        zeroSumGameDraft = nil
        decisionTreeDraft = nil
        projectSchedulingDraft = nil
        aggregatePlanningDraft = nil
        materialRequirementsPlanningDraft = nil
        simulationDraft = nil
        knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
        modelJSON = ""
        modelSource = "New · Markov Analysis"
        modelState = .editing
        runState = .notRun
        solutionJSON = ""
        validationJSON = ""
        validationDiagnostics = []
        lastErrorMessage = nil
        lastResultLabel = nil
        status = "Editing a new Markov analysis"
        selectedPane = .model
    }

    func startNewQueuing(_ kind: QueuingProblemKind) {
        lpDraft = nil
        inventoryDraft = nil
        networkDraft = nil
        networkFlowDraft = nil
        assignmentDraft = nil
        transportationDraft = nil
        forecastingDraft = nil
        markovDraft = nil
        queuingDraft = .blank(kind)
        decisionDraft = nil
        zeroSumGameDraft = nil
        decisionTreeDraft = nil
        projectSchedulingDraft = nil
        aggregatePlanningDraft = nil
        materialRequirementsPlanningDraft = nil
        simulationDraft = nil
        knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
        modelJSON = ""
        modelSource = "New · Queuing · \(kind.displayName)"
        modelState = .editing
        runState = .notRun
        solutionJSON = ""
        validationJSON = ""
        validationDiagnostics = []
        lastErrorMessage = nil
        lastResultLabel = nil
        status = "Editing a new \(kind.displayName) model"
        selectedPane = .model
    }

    func startNewDecisionAnalysis(_ kind: DecisionAnalysisProblemKind) {
        let draft = DecisionAnalysisDraft.blank(kind)
        let gameDraft = kind == .zeroSumGame ? ZeroSumGameDraft.blank() : nil
        let treeDraft = kind == .decisionTree ? DecisionTreeDraft.blank() : nil
        guard draft != nil || gameDraft != nil || treeDraft != nil else { return }
        lpDraft = nil
        inventoryDraft = nil
        networkDraft = nil
        networkFlowDraft = nil
        assignmentDraft = nil
        transportationDraft = nil
        forecastingDraft = nil
        markovDraft = nil
        queuingDraft = nil
        decisionDraft = draft
        zeroSumGameDraft = gameDraft
        decisionTreeDraft = treeDraft
        projectSchedulingDraft = nil
        aggregatePlanningDraft = nil
        materialRequirementsPlanningDraft = nil
        simulationDraft = nil
        knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
        modelJSON = ""
        modelSource = "New · Decision Analysis · \(kind.displayName)"
        modelState = .editing
        runState = .notRun
        solutionJSON = ""
        validationJSON = ""
        validationDiagnostics = []
        lastErrorMessage = nil
        lastResultLabel = nil
        status = "Editing a new \(kind.displayName) model"
        selectedPane = .model
    }

    func startNewGuidedModel(from sample: SampleModel) {
        loadSample(sample)
        modelSource = "New · \(sample.label) starter"
        status = "Editing a new \(sample.label) model from a guided starter"
        selectedPane = .model
    }

    func startNewProjectScheduling(_ kind: ProjectSchedulingProblemKind = .deterministicCPM) {
        lpDraft = nil
        inventoryDraft = nil
        networkDraft = nil
        networkFlowDraft = nil
        assignmentDraft = nil
        transportationDraft = nil
        forecastingDraft = nil
        markovDraft = nil
        queuingDraft = nil
        decisionDraft = nil
        zeroSumGameDraft = nil
        decisionTreeDraft = nil
        aggregatePlanningDraft = nil
        materialRequirementsPlanningDraft = nil
        simulationDraft = nil
        knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
        projectSchedulingDraft = .blank(kind)
        modelJSON = ""
        modelSource = "New · Project Scheduling · \(kind.rawValue)"
        markMatrixDraftEdited(status: "Editing a new \(kind.rawValue) project")
        selectedPane = .model
    }

    func startNewAggregatePlanning() {
        lpDraft = nil
        inventoryDraft = nil
        networkDraft = nil
        networkFlowDraft = nil
        assignmentDraft = nil
        transportationDraft = nil
        forecastingDraft = nil
        markovDraft = nil
        queuingDraft = nil
        decisionDraft = nil
        zeroSumGameDraft = nil
        decisionTreeDraft = nil
        projectSchedulingDraft = nil
        materialRequirementsPlanningDraft = nil
        simulationDraft = nil
        knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
        aggregatePlanningDraft = .blank()
        modelJSON = ""
        modelSource = "New · Aggregate Planning"
        markMatrixDraftEdited(status: "Editing a new aggregate plan")
        selectedPane = .model
    }

    func startNewMaterialRequirementsPlanning() {
        lpDraft = nil
        inventoryDraft = nil
        networkDraft = nil
        networkFlowDraft = nil
        assignmentDraft = nil
        transportationDraft = nil
        forecastingDraft = nil
        markovDraft = nil
        queuingDraft = nil
        decisionDraft = nil
        zeroSumGameDraft = nil
        decisionTreeDraft = nil
        projectSchedulingDraft = nil
        aggregatePlanningDraft = nil
        simulationDraft = nil
        knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
        materialRequirementsPlanningDraft = .blank()
        modelJSON = ""
        modelSource = "New · Material Requirements Planning"
        markMatrixDraftEdited(status: "Editing a new material requirements plan")
        selectedPane = .model
    }

    func startNewSimulation() {
        lpDraft = nil
        inventoryDraft = nil
        networkDraft = nil
        networkFlowDraft = nil
        assignmentDraft = nil
        transportationDraft = nil
        forecastingDraft = nil
        markovDraft = nil
        queuingDraft = nil
        decisionDraft = nil
        zeroSumGameDraft = nil
        decisionTreeDraft = nil
        projectSchedulingDraft = nil
        aggregatePlanningDraft = nil
        materialRequirementsPlanningDraft = nil
        knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
        simulationDraft = .blank()
        modelJSON = ""
        modelSource = "New · Simulation"
        markMatrixDraftEdited(status: "Editing a new simulation")
        selectedPane = .model
    }

    func startNewKnapsack() {
        lpDraft = nil
        inventoryDraft = nil
        networkDraft = nil
        networkFlowDraft = nil
        assignmentDraft = nil
        transportationDraft = nil
        forecastingDraft = nil
        markovDraft = nil
        queuingDraft = nil
        decisionDraft = nil
        zeroSumGameDraft = nil
        decisionTreeDraft = nil
        projectSchedulingDraft = nil
        aggregatePlanningDraft = nil
        materialRequirementsPlanningDraft = nil
        simulationDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
        knapsackDraft = .blank()
        modelJSON = ""
        modelSource = "New · Bounded Knapsack"
        markMatrixDraftEdited(status: "Editing a new bounded knapsack")
        selectedPane = .model
    }

    func startNewAcceptanceSampling(_ kind: AcceptanceSamplingPlanKind = .single) {
        lpDraft = nil
        inventoryDraft = nil
        networkDraft = nil
        networkFlowDraft = nil
        assignmentDraft = nil
        transportationDraft = nil
        forecastingDraft = nil
        markovDraft = nil
        queuingDraft = nil
        decisionDraft = nil
        zeroSumGameDraft = nil
        decisionTreeDraft = nil
        projectSchedulingDraft = nil
        aggregatePlanningDraft = nil
        materialRequirementsPlanningDraft = nil
        simulationDraft = nil
        knapsackDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
        acceptanceSamplingDraft = .blank(kind)
        modelJSON = ""
        modelSource = "New · Acceptance Sampling"
        markMatrixDraftEdited(status: "Editing a new acceptance-sampling plan")
        selectedPane = .model
    }

    func startNewQualityControl(_ kind: QualityControlProblemKind = .cChart) {
        lpDraft = nil
        inventoryDraft = nil
        networkDraft = nil
        networkFlowDraft = nil
        assignmentDraft = nil
        transportationDraft = nil
        forecastingDraft = nil
        markovDraft = nil
        queuingDraft = nil
        decisionDraft = nil
        zeroSumGameDraft = nil
        decisionTreeDraft = nil
        projectSchedulingDraft = nil
        aggregatePlanningDraft = nil
        materialRequirementsPlanningDraft = nil
        simulationDraft = nil
        knapsackDraft = nil
        acceptanceSamplingDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
        qualityControlDraft = .blank(kind)
        modelJSON = ""
        modelSource = "New · Quality Control"
        markMatrixDraftEdited(status: "Editing a new quality-control analysis")
        selectedPane = .model
    }

    func startNewQuadraticProgramming() {
        lpDraft=nil;inventoryDraft=nil;networkDraft=nil;networkFlowDraft=nil;assignmentDraft=nil;transportationDraft=nil
        forecastingDraft=nil;markovDraft=nil;queuingDraft=nil;decisionDraft=nil;zeroSumGameDraft=nil;decisionTreeDraft=nil
        projectSchedulingDraft=nil;aggregatePlanningDraft=nil;materialRequirementsPlanningDraft=nil;simulationDraft=nil;knapsackDraft=nil
        acceptanceSamplingDraft=nil;qualityControlDraft=nil;quadraticProgrammingDraft = .blank();nonlinearProgrammingDraft=nil;goalProgrammingDraft=nil;facilityLocationDraft=nil;lineBalancingDraft=nil;facilityLayoutDraft=nil
        modelJSON="";modelSource="New · Quadratic Programming";markMatrixDraftEdited(status:"Editing a new quadratic program");selectedPane = .model
    }

    func startNewNonlinearProgramming() {
        lpDraft=nil;inventoryDraft=nil;networkDraft=nil;networkFlowDraft=nil;assignmentDraft=nil;transportationDraft=nil
        forecastingDraft=nil;markovDraft=nil;queuingDraft=nil;decisionDraft=nil;zeroSumGameDraft=nil;decisionTreeDraft=nil
        projectSchedulingDraft=nil;aggregatePlanningDraft=nil;materialRequirementsPlanningDraft=nil;simulationDraft=nil;knapsackDraft=nil
        acceptanceSamplingDraft=nil;qualityControlDraft=nil;quadraticProgrammingDraft=nil;nonlinearProgrammingDraft = .blank();goalProgrammingDraft=nil;facilityLocationDraft=nil;lineBalancingDraft=nil;facilityLayoutDraft=nil
        modelJSON="";modelSource="New · Nonlinear Programming";markMatrixDraftEdited(status:"Editing a new nonlinear program");selectedPane = .model
    }

    func startNewGoalProgramming() {
        lpDraft=nil;inventoryDraft=nil;networkDraft=nil;networkFlowDraft=nil;assignmentDraft=nil;transportationDraft=nil
        forecastingDraft=nil;markovDraft=nil;queuingDraft=nil;decisionDraft=nil;zeroSumGameDraft=nil;decisionTreeDraft=nil
        projectSchedulingDraft=nil;aggregatePlanningDraft=nil;materialRequirementsPlanningDraft=nil;simulationDraft=nil;knapsackDraft=nil
        acceptanceSamplingDraft=nil;qualityControlDraft=nil;quadraticProgrammingDraft=nil;nonlinearProgrammingDraft=nil;goalProgrammingDraft = .blank();facilityLocationDraft=nil;lineBalancingDraft=nil;facilityLayoutDraft=nil
        modelJSON="";modelSource="New · Goal Programming";markMatrixDraftEdited(status:"Editing a new goal program");selectedPane = .model
    }

    func startNewFacilityLocation() {
        lpDraft=nil;inventoryDraft=nil;networkDraft=nil;networkFlowDraft=nil;assignmentDraft=nil;transportationDraft=nil
        forecastingDraft=nil;markovDraft=nil;queuingDraft=nil;decisionDraft=nil;zeroSumGameDraft=nil;decisionTreeDraft=nil
        projectSchedulingDraft=nil;aggregatePlanningDraft=nil;materialRequirementsPlanningDraft=nil;simulationDraft=nil;knapsackDraft=nil
        acceptanceSamplingDraft=nil;qualityControlDraft=nil;quadraticProgrammingDraft=nil;nonlinearProgrammingDraft=nil;goalProgrammingDraft=nil;facilityLocationDraft = .blank();lineBalancingDraft=nil;facilityLayoutDraft=nil
        modelJSON="";modelSource="New · Facility Location";markMatrixDraftEdited(status:"Editing a new facility location");selectedPane = .model
    }

    func startNewLineBalancing() {
        lpDraft=nil;inventoryDraft=nil;networkDraft=nil;networkFlowDraft=nil;assignmentDraft=nil;transportationDraft=nil
        forecastingDraft=nil;markovDraft=nil;queuingDraft=nil;decisionDraft=nil;zeroSumGameDraft=nil;decisionTreeDraft=nil
        projectSchedulingDraft=nil;aggregatePlanningDraft=nil;materialRequirementsPlanningDraft=nil;simulationDraft=nil;knapsackDraft=nil
        acceptanceSamplingDraft=nil;qualityControlDraft=nil;quadraticProgrammingDraft=nil;nonlinearProgrammingDraft=nil;goalProgrammingDraft=nil;facilityLocationDraft=nil;lineBalancingDraft = .blank();facilityLayoutDraft=nil
        modelJSON="";modelSource="New · Line Balancing";markMatrixDraftEdited(status:"Editing a new line balancing");selectedPane = .model
    }

    func startNewFacilityLayout() {
        lpDraft=nil;inventoryDraft=nil;networkDraft=nil;networkFlowDraft=nil;assignmentDraft=nil;transportationDraft=nil
        forecastingDraft=nil;markovDraft=nil;queuingDraft=nil;decisionDraft=nil;zeroSumGameDraft=nil;decisionTreeDraft=nil
        projectSchedulingDraft=nil;aggregatePlanningDraft=nil;materialRequirementsPlanningDraft=nil;simulationDraft=nil;knapsackDraft=nil
        acceptanceSamplingDraft=nil;qualityControlDraft=nil;quadraticProgrammingDraft=nil;nonlinearProgrammingDraft=nil;goalProgrammingDraft=nil;facilityLocationDraft=nil;lineBalancingDraft=nil;facilityLayoutDraft = .blank()
        modelJSON="";modelSource="New · Facility Layout";markMatrixDraftEdited(status:"Editing a new facility layout");selectedPane = .model
    }


    private func prepareNewNetworkModel(source: String, status: String) {
        modelJSON = ""
        modelSource = source
        modelState = .editing
        runState = .notRun
        solutionJSON = ""
        validationJSON = ""
        validationDiagnostics = []
        lastErrorMessage = nil
        lastResultLabel = nil
        self.status = status
        selectedPane = .model
    }

    func updateLPDraft(_ update: (inout LinearProgrammingDraft) -> Void) {
        guard var draft = lpDraft else { return }
        update(&draft)
        lpDraft = draft
        modelState = .editing
        runState = .notRun
        solutionJSON = ""
        validationJSON = ""
        validationDiagnostics = []
        lastResultLabel = nil
        lastErrorMessage = nil
        status = "Editing linear program"
    }

    func updateInventoryDraft(_ update: (inout InventoryDraft) -> Void) {
        guard var draft = inventoryDraft else { return }
        update(&draft)
        inventoryDraft = draft
        modelState = .editing
        runState = .notRun
        solutionJSON = ""
        validationJSON = ""
        validationDiagnostics = []
        lastResultLabel = nil
        lastErrorMessage = nil
        status = "Editing inventory model"
    }

    func updateNetworkDraft(_ update: (inout NetworkDraft) -> Void) {
        guard var draft = networkDraft else { return }
        update(&draft)
        networkDraft = draft
        modelState = .editing
        runState = .notRun
        solutionJSON = ""
        validationJSON = ""
        validationDiagnostics = []
        lastResultLabel = nil
        lastErrorMessage = nil
        status = "Editing network model"
    }

    func updateNetworkFlowDraft(_ update: (inout NetworkFlowDraft) -> Void) {
        guard var draft = networkFlowDraft else { return }
        update(&draft)
        networkFlowDraft = draft
        markMatrixDraftEdited(status: "Editing minimum-cost transshipment model")
    }

    func updateAssignmentDraft(_ update: (inout AssignmentDraft) -> Void) {
        guard var draft = assignmentDraft else { return }
        update(&draft)
        assignmentDraft = draft
        markMatrixDraftEdited(status: "Editing assignment model")
    }

    func updateTransportationDraft(_ update: (inout TransportationDraft) -> Void) {
        guard var draft = transportationDraft else { return }
        update(&draft)
        transportationDraft = draft
        markMatrixDraftEdited(status: "Editing transportation model")
    }

    func updateForecastingDraft(_ update: (inout ForecastingDraft) -> Void) {
        guard var draft = forecastingDraft else { return }
        update(&draft)
        forecastingDraft = draft
        markMatrixDraftEdited(status: "Editing forecasting model")
    }

    func updateMarkovDraft(_ update: (inout MarkovDraft) -> Void) {
        guard var draft = markovDraft else { return }
        update(&draft)
        markovDraft = draft
        markMatrixDraftEdited(status: "Editing Markov analysis")
    }

    func updateQueuingDraft(_ update: (inout QueuingDraft) -> Void) {
        guard var draft = queuingDraft else { return }
        update(&draft)
        queuingDraft = draft
        markMatrixDraftEdited(status: "Editing queuing model")
    }

    func updateDecisionDraft(_ update: (inout DecisionAnalysisDraft) -> Void) {
        guard var draft = decisionDraft else { return }
        update(&draft)
        decisionDraft = draft
        markMatrixDraftEdited(status: "Editing decision analysis")
    }

    func updateZeroSumGameDraft(_ update: (inout ZeroSumGameDraft) -> Void) {
        guard var draft = zeroSumGameDraft else { return }
        update(&draft)
        zeroSumGameDraft = draft
        markMatrixDraftEdited(status: "Editing zero-sum game")
    }

    func updateDecisionTreeDraft(_ update: (inout DecisionTreeDraft) -> Void) {
        guard var draft = decisionTreeDraft else { return }
        update(&draft)
        decisionTreeDraft = draft
        markMatrixDraftEdited(status: "Editing decision tree")
    }

    @MainActor
    func replaceProjectSchedulingDraft(
        _ draft: ProjectSchedulingDraft,
        undoManager: UndoManager? = nil,
        actionName: String = "Edit Project"
    ) {
        guard projectSchedulingDraft != draft else { return }
        if let previous = projectSchedulingDraft {
            undoManager?.registerUndo(withTarget: self) { target in
                target.replaceProjectSchedulingDraft(previous, undoManager: undoManager, actionName: actionName)
            }
            undoManager?.setActionName(actionName)
        }
        projectSchedulingDraft = draft
        markMatrixDraftEdited(status: "Editing \(draft.kind.rawValue) project")
    }

    @MainActor
    func replaceAggregatePlanningDraft(
        _ draft: AggregatePlanningDraft,
        undoManager: UndoManager? = nil,
        actionName: String = "Edit Aggregate Plan"
    ) {
        guard aggregatePlanningDraft != draft else { return }
        if let previous = aggregatePlanningDraft {
            undoManager?.registerUndo(withTarget: self) { target in
                target.replaceAggregatePlanningDraft(previous, undoManager: undoManager, actionName: actionName)
            }
            undoManager?.setActionName(actionName)
        }
        aggregatePlanningDraft = draft
        markMatrixDraftEdited(status: "Editing aggregate plan")
    }

    @MainActor
    func replaceMaterialRequirementsPlanningDraft(
        _ draft: MaterialRequirementsPlanningDraft,
        undoManager: UndoManager? = nil,
        actionName: String = "Edit Material Requirements Plan"
    ) {
        guard materialRequirementsPlanningDraft != draft else { return }
        if let previous = materialRequirementsPlanningDraft {
            undoManager?.registerUndo(withTarget: self) { target in
                target.replaceMaterialRequirementsPlanningDraft(previous, undoManager: undoManager, actionName: actionName)
            }
            undoManager?.setActionName(actionName)
        }
        materialRequirementsPlanningDraft = draft
        markMatrixDraftEdited(status: "Editing material requirements plan")
    }

    @MainActor
    func replaceSimulationDraft(
        _ draft: SimulationDraft,
        undoManager: UndoManager? = nil,
        actionName: String = "Edit Simulation"
    ) {
        guard simulationDraft != draft else { return }
        if let previous = simulationDraft {
            undoManager?.registerUndo(withTarget: self) { target in
                target.replaceSimulationDraft(previous, undoManager: undoManager, actionName: actionName)
            }
            undoManager?.setActionName(actionName)
        }
        simulationDraft = draft
        markMatrixDraftEdited(status: "Editing simulation")
    }

    @MainActor
    func replaceKnapsackDraft(
        _ draft: KnapsackDraft,
        undoManager: UndoManager? = nil,
        actionName: String = "Edit Bounded Knapsack"
    ) {
        guard knapsackDraft != draft else { return }
        if let previous = knapsackDraft {
            undoManager?.registerUndo(withTarget: self) { target in
                target.replaceKnapsackDraft(previous, undoManager: undoManager, actionName: actionName)
            }
            undoManager?.setActionName(actionName)
        }
        knapsackDraft = draft
        markMatrixDraftEdited(status: "Editing bounded knapsack")
    }

    @MainActor
    func replaceAcceptanceSamplingDraft(
        _ draft: AcceptanceSamplingDraft,
        undoManager: UndoManager? = nil,
        actionName: String = "Edit Acceptance Sampling Plan"
    ) {
        guard acceptanceSamplingDraft != draft else { return }
        if let previous = acceptanceSamplingDraft {
            undoManager?.registerUndo(withTarget: self) { target in
                target.replaceAcceptanceSamplingDraft(previous, undoManager: undoManager, actionName: actionName)
            }
            undoManager?.setActionName(actionName)
        }
        acceptanceSamplingDraft = draft
        markMatrixDraftEdited(status: "Editing acceptance-sampling plan")
    }

    @MainActor
    func replaceQualityControlDraft(
        _ draft: QualityControlDraft,
        undoManager: UndoManager? = nil,
        actionName: String = "Edit Quality Control Analysis"
    ) {
        guard qualityControlDraft != draft else { return }
        if let previous = qualityControlDraft {
            undoManager?.registerUndo(withTarget: self) { target in
                target.replaceQualityControlDraft(previous, undoManager: undoManager, actionName: actionName)
            }
            undoManager?.setActionName(actionName)
        }
        qualityControlDraft = draft
        markMatrixDraftEdited(status: "Editing quality-control analysis")
    }

    @MainActor
    func replaceQuadraticProgrammingDraft(_ draft:QuadraticProgrammingDraft,undoManager:UndoManager?=nil,actionName:String="Edit Quadratic Program") {
        guard quadraticProgrammingDraft != draft else{return};if let previous=quadraticProgrammingDraft{undoManager?.registerUndo(withTarget:self){$0.replaceQuadraticProgrammingDraft(previous,undoManager:undoManager,actionName:actionName)};undoManager?.setActionName(actionName)};quadraticProgrammingDraft=draft;markMatrixDraftEdited(status:"Editing quadratic program")
    }
    @MainActor
    func replaceNonlinearProgrammingDraft(
        _ draft: NonlinearProgrammingDraft,
        undoManager: UndoManager? = nil,
        actionName: String = "Edit Nonlinear Program"
    ) {
        guard nonlinearProgrammingDraft != draft else { return }
        if let previous = nonlinearProgrammingDraft {
            undoManager?.registerUndo(withTarget: self) { target in
                target.replaceNonlinearProgrammingDraft(previous, undoManager: undoManager, actionName: actionName)
            }
            undoManager?.setActionName(actionName)
        }
        nonlinearProgrammingDraft = draft
        markMatrixDraftEdited(status: "Editing nonlinear program")
    }

    @MainActor
    func replaceGoalProgrammingDraft(
        _ draft: GoalProgrammingDraft,
        undoManager: UndoManager? = nil,
        actionName: String = "Edit Goal Program"
    ) {
        guard goalProgrammingDraft != draft else { return }
        if let previous = goalProgrammingDraft {
            undoManager?.registerUndo(withTarget: self) { target in
                target.replaceGoalProgrammingDraft(previous, undoManager: undoManager, actionName: actionName)
            }
            undoManager?.setActionName(actionName)
        }
        goalProgrammingDraft = draft
        markMatrixDraftEdited(status: "Editing goal program")
    }

    @MainActor
    func replaceFacilityLocationDraft(
        _ draft: FacilityLocationDraft,
        undoManager: UndoManager? = nil,
        actionName: String = "Edit Facility Location"
    ) {
        guard facilityLocationDraft != draft else { return }
        if let previous = facilityLocationDraft {
            undoManager?.registerUndo(withTarget: self) { target in
                target.replaceFacilityLocationDraft(previous, undoManager: undoManager, actionName: actionName)
            }
            undoManager?.setActionName(actionName)
        }
        facilityLocationDraft = draft
        markMatrixDraftEdited(status: "Editing facility location")
    }

    @MainActor
    func replaceLineBalancingDraft(
        _ draft: LineBalancingDraft,
        undoManager: UndoManager? = nil,
        actionName: String = "Edit Line Balancing"
    ) {
        guard lineBalancingDraft != draft else { return }
        if let previous = lineBalancingDraft {
            undoManager?.registerUndo(withTarget: self) { target in
                target.replaceLineBalancingDraft(previous, undoManager: undoManager, actionName: actionName)
            }
            undoManager?.setActionName(actionName)
        }
        lineBalancingDraft = draft
        markMatrixDraftEdited(status: "Editing line balancing")
    }

    @MainActor
    func replaceFacilityLayoutDraft(
        _ draft: FacilityLayoutDraft,
        undoManager: UndoManager? = nil,
        actionName: String = "Edit Facility Layout"
    ) {
        guard facilityLayoutDraft != draft else { return }
        if let previous = facilityLayoutDraft {
            undoManager?.registerUndo(withTarget: self) { target in
                target.replaceFacilityLayoutDraft(previous, undoManager: undoManager, actionName: actionName)
            }
            undoManager?.setActionName(actionName)
        }
        facilityLayoutDraft = draft
        markMatrixDraftEdited(status: "Editing facility layout")
    }


    func pasteForecastingHistoricalDataFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string) else {
            status = "Paste not applied: The clipboard is empty."
            lastErrorMessage = "The clipboard is empty."
            return
        }
        pasteForecastingHistoricalData(text)
    }

    func pasteForecastingHistoricalData(_ text: String) {
        guard var draft = forecastingDraft else { return }
        do {
            try draft.replaceTimeSeriesObservations(with: text)
            forecastingDraft = draft
            markMatrixDraftEdited(status: "Pasted forecasting observations")
        } catch {
            lastErrorMessage = Self.message(for: error)
            status = "Paste not applied: " + (lastErrorMessage ?? "Invalid tabular data")
        }
    }

    private func markMatrixDraftEdited(status: String) {
        modelState = .editing
        runState = .notRun
        solutionJSON = ""
        validationJSON = ""
        validationDiagnostics = []
        lastResultLabel = nil
        lastErrorMessage = nil
        self.status = status
    }

    func updateStructuredModelJSON(_ json: String) {
        guard modelJSON != json else { return }
        modelJSON = json
        modelState = .editing
        status = "Saved guided model changes"
    }

    func applyModelJSONToNativeEditor() {
        do {
            let program = try LinearProgramJSON.decodeProgram(from: Data(modelJSON.utf8))
            lpDraft = LinearProgrammingDraft(program: program)
            decisionDraft = nil
            zeroSumGameDraft = nil
            decisionTreeDraft = nil
            projectSchedulingDraft = nil
            aggregatePlanningDraft = nil
            materialRequirementsPlanningDraft = nil
            simulationDraft = nil
            knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
            modelSource = "Normalized JSON · Linear Programming"
            modelState = .editing
            runState = .notRun
            solutionJSON = ""
            validationJSON = ""
            validationDiagnostics = []
            lastErrorMessage = nil
            status = "JSON applied to the LP editor"
            selectedPane = .model
        } catch {
            lastErrorMessage = Self.message(for: error)
            status = "JSON was not applied: \(lastErrorMessage ?? "Invalid JSON")"
            selectedPane = .json
        }
    }

    func applyInventoryJSONToNativeEditor() {
        do {
            let envelope = try InventoryModelJSON.decodeModel(from: Data(modelJSON.utf8))
            inventoryDraft = InventoryDraft(envelope)
            lpDraft = nil
            decisionDraft = nil
            zeroSumGameDraft = nil
            decisionTreeDraft = nil
            projectSchedulingDraft = nil
            aggregatePlanningDraft = nil
            materialRequirementsPlanningDraft = nil
            simulationDraft = nil
            knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
            modelSource = "Normalized JSON · Inventory"
            modelState = .editing
            runState = .notRun
            solutionJSON = ""
            validationJSON = ""
            validationDiagnostics = []
            lastErrorMessage = nil
            status = "JSON applied to the Inventory editor"
            selectedPane = .model
        } catch {
            lastErrorMessage = Self.message(for: error)
            status = "JSON was not applied: \(lastErrorMessage ?? "Invalid JSON")"
            selectedPane = .json
        }
    }

    func applyNetworkJSONToNativeEditor() {
        do {
            let envelope = try NetworkModelJSON.decodeModel(from: Data(modelJSON.utf8))
            let graphDraft = NetworkDraft(envelope: envelope)
            let flowDraft = NetworkFlowDraft(envelope: envelope)
            let assignment = AssignmentDraft(envelope: envelope)
            let transportation = TransportationDraft(envelope: envelope)
            guard graphDraft != nil || flowDraft != nil || assignment != nil || transportation != nil else {
                throw NetworkModelError.unsupportedProblemType(envelope.kind.rawValue)
            }
            networkDraft = graphDraft
            networkFlowDraft = flowDraft
            assignmentDraft = assignment
            transportationDraft = transportation
            lpDraft = nil
            inventoryDraft = nil
            decisionDraft = nil
            zeroSumGameDraft = nil
            decisionTreeDraft = nil
            projectSchedulingDraft = nil
            aggregatePlanningDraft = nil
            materialRequirementsPlanningDraft = nil
            simulationDraft = nil
            knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
            modelSource = "Normalized JSON · Network"
            modelState = .editing
            runState = .notRun
            solutionJSON = ""
            validationJSON = ""
            validationDiagnostics = []
            lastErrorMessage = nil
            status = "JSON applied to the Network editor"
            selectedPane = .model
        } catch {
            lastErrorMessage = Self.message(for: error)
            status = "JSON was not applied: \(lastErrorMessage ?? "Invalid JSON")"
            selectedPane = .json
        }
    }

    func applyForecastingJSONToNativeEditor() {
        do {
            forecastingDraft = ForecastingDraft(try ForecastingModelJSON.decodeRequest(from: Data(modelJSON.utf8)))
            decisionDraft = nil
            zeroSumGameDraft = nil
            decisionTreeDraft = nil
            projectSchedulingDraft = nil
            aggregatePlanningDraft = nil
            materialRequirementsPlanningDraft = nil
            simulationDraft = nil
            knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
            lpDraft = nil; inventoryDraft = nil; networkDraft = nil; networkFlowDraft = nil; assignmentDraft = nil; transportationDraft = nil
            modelSource = "Normalized JSON · Forecasting"
            modelState = .editing; runState = .notRun; solutionJSON = ""; validationJSON = ""; validationDiagnostics = []; lastErrorMessage = nil
            status = "JSON applied to the Forecasting editor"
            selectedPane = .model
        } catch {
            lastErrorMessage = Self.message(for: error)
            status = "JSON was not applied: \(lastErrorMessage ?? "Invalid JSON")"
            selectedPane = .json
        }
    }

    func applyMarkovJSONToNativeEditor() {
        do {
            markovDraft = MarkovDraft(try MarkovJSON.decodeRequest(from: Data(modelJSON.utf8)))
            lpDraft = nil
            inventoryDraft = nil
            networkDraft = nil
            networkFlowDraft = nil
            assignmentDraft = nil
            transportationDraft = nil
            forecastingDraft = nil
            decisionDraft = nil
            zeroSumGameDraft = nil
            decisionTreeDraft = nil
            projectSchedulingDraft = nil
            aggregatePlanningDraft = nil
            materialRequirementsPlanningDraft = nil
            simulationDraft = nil
            knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
            modelSource = "Normalized JSON · Markov Analysis"
            modelState = .editing
            runState = .notRun
            solutionJSON = ""
            validationJSON = ""
            validationDiagnostics = []
            lastErrorMessage = nil
            status = "JSON applied to the Markov editor"
            selectedPane = .model
        } catch {
            lastErrorMessage = Self.message(for: error)
            status = "JSON was not applied: \(lastErrorMessage ?? "Invalid JSON")"
            selectedPane = .json
        }
    }

    func applyQueuingJSONToNativeEditor() {
        do {
            queuingDraft = QueuingDraft(try QueuingModelJSON.decodeModel(from: Data(modelJSON.utf8)))
            lpDraft = nil
            inventoryDraft = nil
            networkDraft = nil
            networkFlowDraft = nil
            assignmentDraft = nil
            transportationDraft = nil
            forecastingDraft = nil
            markovDraft = nil
            decisionDraft = nil
            zeroSumGameDraft = nil
            decisionTreeDraft = nil
            projectSchedulingDraft = nil
            aggregatePlanningDraft = nil
            materialRequirementsPlanningDraft = nil
            simulationDraft = nil
            knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
            modelSource = "Normalized JSON · Queuing"
            modelState = .editing
            runState = .notRun
            solutionJSON = ""
            validationJSON = ""
            validationDiagnostics = []
            lastErrorMessage = nil
            status = "JSON applied to the Queuing editor"
            selectedPane = .model
        } catch {
            lastErrorMessage = Self.message(for: error)
            status = "JSON was not applied: \(lastErrorMessage ?? "Invalid JSON")"
            selectedPane = .json
        }
    }

    func applyDecisionAnalysisJSONToNativeEditor() {
        do {
            let envelope = try DecisionAnalysisModelJSON.decodeModel(from: Data(modelJSON.utf8))
            let draft = DecisionAnalysisDraft(envelope)
            let gameDraft = ZeroSumGameDraft(envelope)
            let treeDraft = DecisionTreeDraft(envelope)
            guard draft != nil || gameDraft != nil || treeDraft != nil else {
                throw DecisionAnalysisModelError.invalidModel("The native editor cannot represent this Decision Analysis model.")
            }
            decisionDraft = draft
            zeroSumGameDraft = gameDraft
            decisionTreeDraft = treeDraft
            projectSchedulingDraft = nil
            aggregatePlanningDraft = nil
            materialRequirementsPlanningDraft = nil
            simulationDraft = nil
            knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
            lpDraft = nil
            inventoryDraft = nil
            networkDraft = nil
            networkFlowDraft = nil
            assignmentDraft = nil
            transportationDraft = nil
            forecastingDraft = nil
            markovDraft = nil
            queuingDraft = nil
            modelSource = "Normalized JSON · Decision Analysis"
            markMatrixDraftEdited(status: "JSON applied to the Decision Analysis editor")
            selectedPane = .model
        } catch {
            lastErrorMessage = Self.message(for: error)
            status = "JSON was not applied: \(lastErrorMessage ?? "Invalid JSON")"
            selectedPane = .json
        }
    }

    func applyProjectSchedulingJSONToNativeEditor() {
        do {
            let envelope = try ProjectSchedulingJSON.decodeModel(from: Data(modelJSON.utf8))
            projectSchedulingDraft = ProjectSchedulingDraft(envelope)
            lpDraft = nil
            inventoryDraft = nil
            networkDraft = nil
            networkFlowDraft = nil
            assignmentDraft = nil
            transportationDraft = nil
            forecastingDraft = nil
            markovDraft = nil
            queuingDraft = nil
            decisionDraft = nil
            zeroSumGameDraft = nil
            decisionTreeDraft = nil
            aggregatePlanningDraft = nil
            materialRequirementsPlanningDraft = nil
            simulationDraft = nil
            knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
            modelSource = "Normalized JSON · Project Scheduling"
            markMatrixDraftEdited(status: "JSON applied to the Project Scheduling editor")
            selectedPane = .model
        } catch {
            lastErrorMessage = Self.message(for: error)
            status = "JSON was not applied: \(lastErrorMessage ?? "Invalid JSON")"
            selectedPane = .json
        }
    }

    func applyAggregatePlanningJSONToNativeEditor() {
        do {
            let model = try AggregatePlanningJSON.decodeModel(from: Data(modelJSON.utf8))
            aggregatePlanningDraft = AggregatePlanningDraft(model)
            lpDraft = nil
            inventoryDraft = nil
            networkDraft = nil
            networkFlowDraft = nil
            assignmentDraft = nil
            transportationDraft = nil
            forecastingDraft = nil
            markovDraft = nil
            queuingDraft = nil
            decisionDraft = nil
            zeroSumGameDraft = nil
            decisionTreeDraft = nil
            projectSchedulingDraft = nil
            materialRequirementsPlanningDraft = nil
            simulationDraft = nil
            knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
            modelSource = "Normalized JSON · Aggregate Planning"
            markMatrixDraftEdited(status: "JSON applied to the Aggregate Planning editor")
            selectedPane = .model
        } catch {
            lastErrorMessage = Self.message(for: error)
            status = "JSON was not applied: \(lastErrorMessage ?? "Invalid JSON")"
            selectedPane = .json
        }
    }

    func applyMaterialRequirementsPlanningJSONToNativeEditor() {
        do {
            let model = try MaterialRequirementsPlanningJSON.decodeModel(from: Data(modelJSON.utf8))
            materialRequirementsPlanningDraft = MaterialRequirementsPlanningDraft(model)
            lpDraft = nil
            inventoryDraft = nil
            networkDraft = nil
            networkFlowDraft = nil
            assignmentDraft = nil
            transportationDraft = nil
            forecastingDraft = nil
            markovDraft = nil
            queuingDraft = nil
            decisionDraft = nil
            zeroSumGameDraft = nil
            decisionTreeDraft = nil
            projectSchedulingDraft = nil
            aggregatePlanningDraft = nil
            modelSource = "Normalized JSON · Material Requirements Planning"
            markMatrixDraftEdited(status: "JSON applied to the Material Requirements Planning editor")
            selectedPane = .model
        } catch {
            lastErrorMessage = Self.message(for: error)
            status = "JSON was not applied: \(lastErrorMessage ?? "Invalid JSON")"
            selectedPane = .json
        }
    }

    func applySimulationJSONToNativeEditor() {
        do {
            let model = try SimulationJSON.decodeUncheckedModel(from: Data(modelJSON.utf8))
            simulationDraft = SimulationDraft(model)
            lpDraft = nil
            inventoryDraft = nil
            networkDraft = nil
            networkFlowDraft = nil
            assignmentDraft = nil
            transportationDraft = nil
            forecastingDraft = nil
            markovDraft = nil
            queuingDraft = nil
            decisionDraft = nil
            zeroSumGameDraft = nil
            decisionTreeDraft = nil
            projectSchedulingDraft = nil
            aggregatePlanningDraft = nil
            materialRequirementsPlanningDraft = nil
            knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
            modelSource = "Normalized JSON · Simulation"
            markMatrixDraftEdited(status: "JSON applied to the Simulation editor")
            selectedPane = .model
        } catch {
            lastErrorMessage = Self.message(for: error)
            status = "JSON was not applied: \(lastErrorMessage ?? "Invalid JSON")"
            selectedPane = .json
        }
    }

    func applyKnapsackJSONToNativeEditor() {
        do {
            let envelope = try DynamicProgrammingModelJSON.decodeUncheckedModel(from: Data(modelJSON.utf8))
            guard case .boundedKnapsack(let problem) = envelope else {
                throw DynamicProgrammingModelError.invalidModel("The native editor requires a bounded-knapsack model.")
            }
            knapsackDraft = KnapsackDraft(problem)
            lpDraft = nil
            inventoryDraft = nil
            networkDraft = nil
            networkFlowDraft = nil
            assignmentDraft = nil
            transportationDraft = nil
            forecastingDraft = nil
            markovDraft = nil
            queuingDraft = nil
            decisionDraft = nil
            zeroSumGameDraft = nil
            decisionTreeDraft = nil
            projectSchedulingDraft = nil
            aggregatePlanningDraft = nil
            materialRequirementsPlanningDraft = nil
            simulationDraft = nil
            acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
            modelSource = "Normalized JSON · Bounded Knapsack"
            markMatrixDraftEdited(status: "JSON applied to the Bounded Knapsack editor")
            selectedPane = .model
        } catch {
            lastErrorMessage = Self.message(for: error)
            status = "JSON was not applied: \(lastErrorMessage ?? "Invalid JSON")"
            selectedPane = .json
        }
    }

    func beginSolving() {
        runState = .solving
        modelState = hasModel ? .valid : .empty
        lastErrorMessage = nil
        validationDiagnostics = []
    }

    func beginValidation() {
        modelState = .validating
        runState = .validating
        solutionJSON = ""
        validationJSON = ""
        validationDiagnostics = []
        lastErrorMessage = nil
    }

    func applyAcceptanceSamplingJSONToNativeEditor() {
        do {
            let model = try AcceptanceSamplingJSON.decodeModel(from: Data(modelJSON.utf8))
            qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
            acceptanceSamplingDraft = AcceptanceSamplingDraft(model)
            lpDraft = nil
            inventoryDraft = nil
            networkDraft = nil
            networkFlowDraft = nil
            assignmentDraft = nil
            transportationDraft = nil
            forecastingDraft = nil
            markovDraft = nil
            queuingDraft = nil
            decisionDraft = nil
            zeroSumGameDraft = nil
            decisionTreeDraft = nil
            projectSchedulingDraft = nil
            aggregatePlanningDraft = nil
            materialRequirementsPlanningDraft = nil
            simulationDraft = nil
            knapsackDraft = nil
            modelSource = "Normalized JSON · Acceptance Sampling"
            markMatrixDraftEdited(status: "JSON applied to the Acceptance Sampling editor")
            selectedPane = .model
        } catch {
            lastErrorMessage = Self.message(for: error)
            status = "JSON was not applied: \(lastErrorMessage ?? "Invalid JSON")"
            selectedPane = .json
        }
    }

    func applyQualityControlJSONToNativeEditor() {
        do {
            let model = try QualityControlJSON.decodeModel(from: Data(modelJSON.utf8))
            quadraticProgrammingDraft = nil
            nonlinearProgrammingDraft = nil
            goalProgrammingDraft = nil
            facilityLocationDraft = nil
            lineBalancingDraft = nil
            facilityLayoutDraft = nil
            qualityControlDraft = QualityControlDraft(model)
            lpDraft = nil
            inventoryDraft = nil
            networkDraft = nil
            networkFlowDraft = nil
            assignmentDraft = nil
            transportationDraft = nil
            forecastingDraft = nil
            markovDraft = nil
            queuingDraft = nil
            decisionDraft = nil
            zeroSumGameDraft = nil
            decisionTreeDraft = nil
            projectSchedulingDraft = nil
            aggregatePlanningDraft = nil
            materialRequirementsPlanningDraft = nil
            simulationDraft = nil
            knapsackDraft = nil
            acceptanceSamplingDraft = nil
            modelSource = "Normalized JSON · Quality Control"
            markMatrixDraftEdited(status: "JSON applied to the Quality Control editor")
            selectedPane = .model
        } catch {
            lastErrorMessage = Self.message(for: error)
            status = "JSON was not applied: \(lastErrorMessage ?? "Invalid JSON")"
            selectedPane = .json
        }
    }

    func applyQuadraticProgrammingJSONToNativeEditor() {
        do { let model=try QuadraticProgrammingJSON.decodeUncheckedModel(from:Data(modelJSON.utf8));quadraticProgrammingDraft=QuadraticProgrammingDraft(model)
            lpDraft=nil;inventoryDraft=nil;networkDraft=nil;networkFlowDraft=nil;assignmentDraft=nil;transportationDraft=nil;forecastingDraft=nil;markovDraft=nil;queuingDraft=nil;decisionDraft=nil;zeroSumGameDraft=nil;decisionTreeDraft=nil;projectSchedulingDraft=nil;aggregatePlanningDraft=nil;materialRequirementsPlanningDraft=nil;simulationDraft=nil;knapsackDraft=nil;acceptanceSamplingDraft=nil;qualityControlDraft=nil;nonlinearProgrammingDraft=nil;goalProgrammingDraft=nil;facilityLocationDraft=nil;lineBalancingDraft=nil;facilityLayoutDraft=nil
            modelSource="Normalized JSON · Quadratic Programming";markMatrixDraftEdited(status:"JSON applied to the Quadratic Programming editor");selectedPane = .model
        } catch {lastErrorMessage=Self.message(for:error);status="JSON was not applied: \(lastErrorMessage ?? "Invalid JSON")";selectedPane = .json}
    }

    func applyNonlinearProgrammingJSONToNativeEditor() {
        do { let model=try NonlinearProgrammingJSON.decodeUncheckedModel(from:Data(modelJSON.utf8));nonlinearProgrammingDraft=NonlinearProgrammingDraft(model)
            lpDraft=nil;inventoryDraft=nil;networkDraft=nil;networkFlowDraft=nil;assignmentDraft=nil;transportationDraft=nil;forecastingDraft=nil;markovDraft=nil;queuingDraft=nil;decisionDraft=nil;zeroSumGameDraft=nil;decisionTreeDraft=nil;projectSchedulingDraft=nil;aggregatePlanningDraft=nil;materialRequirementsPlanningDraft=nil;simulationDraft=nil;knapsackDraft=nil;acceptanceSamplingDraft=nil;qualityControlDraft=nil;quadraticProgrammingDraft=nil;goalProgrammingDraft=nil;facilityLocationDraft=nil;lineBalancingDraft=nil;facilityLayoutDraft=nil
            modelSource="Normalized JSON · Nonlinear Programming";markMatrixDraftEdited(status:"JSON applied to the Nonlinear Programming editor");selectedPane = .model
        } catch {lastErrorMessage=Self.message(for:error);status="JSON was not applied: \(lastErrorMessage ?? "Invalid JSON")";selectedPane = .json}
    }

    func applyGoalProgrammingJSONToNativeEditor() {
        do { let model=try GoalProgrammingJSON.decodeModel(from:Data(modelJSON.utf8));goalProgrammingDraft=GoalProgrammingDraft(model)
            lpDraft=nil;inventoryDraft=nil;networkDraft=nil;networkFlowDraft=nil;assignmentDraft=nil;transportationDraft=nil;forecastingDraft=nil;markovDraft=nil;queuingDraft=nil;decisionDraft=nil;zeroSumGameDraft=nil;decisionTreeDraft=nil;projectSchedulingDraft=nil;aggregatePlanningDraft=nil;materialRequirementsPlanningDraft=nil;simulationDraft=nil;knapsackDraft=nil;acceptanceSamplingDraft=nil;qualityControlDraft=nil;quadraticProgrammingDraft=nil;nonlinearProgrammingDraft=nil;facilityLocationDraft=nil;lineBalancingDraft=nil;facilityLayoutDraft=nil
            modelSource="Normalized JSON · Goal Programming";markMatrixDraftEdited(status:"JSON applied to the Goal Programming editor");selectedPane = .model
        } catch {lastErrorMessage=Self.message(for:error);status="JSON was not applied: \(lastErrorMessage ?? "Invalid JSON")";selectedPane = .json}
    }

    func applyFacilityLocationJSONToNativeEditor() {
        do { let envelope = try FacilitiesModelJSON.decodeUncheckedModel(from: Data(modelJSON.utf8)); guard case .location(let model) = envelope else { throw FacilitiesModelError.invalidModel("Expected a location model") };facilityLocationDraft=FacilityLocationDraft(model)
            lpDraft=nil;inventoryDraft=nil;networkDraft=nil;networkFlowDraft=nil;assignmentDraft=nil;transportationDraft=nil;forecastingDraft=nil;markovDraft=nil;queuingDraft=nil;decisionDraft=nil;zeroSumGameDraft=nil;decisionTreeDraft=nil;projectSchedulingDraft=nil;aggregatePlanningDraft=nil;materialRequirementsPlanningDraft=nil;simulationDraft=nil;knapsackDraft=nil;acceptanceSamplingDraft=nil;qualityControlDraft=nil;quadraticProgrammingDraft=nil;nonlinearProgrammingDraft=nil;goalProgrammingDraft=nil;lineBalancingDraft=nil;facilityLayoutDraft=nil
            modelSource="Normalized JSON · Facility Location";markMatrixDraftEdited(status:"JSON applied to the Facility Location editor");selectedPane = .model
        } catch {lastErrorMessage=Self.message(for:error);status="JSON was not applied: \(lastErrorMessage ?? "Invalid JSON")";selectedPane = .json}
    }

    func applyLineBalancingJSONToNativeEditor() {
        do { let envelope = try FacilitiesModelJSON.decodeUncheckedModel(from: Data(modelJSON.utf8)); guard case .lineBalancing(let model) = envelope else { throw FacilitiesModelError.invalidModel("Expected a line-balancing model") };lineBalancingDraft=LineBalancingDraft(model)
            lpDraft=nil;inventoryDraft=nil;networkDraft=nil;networkFlowDraft=nil;assignmentDraft=nil;transportationDraft=nil;forecastingDraft=nil;markovDraft=nil;queuingDraft=nil;decisionDraft=nil;zeroSumGameDraft=nil;decisionTreeDraft=nil;projectSchedulingDraft=nil;aggregatePlanningDraft=nil;materialRequirementsPlanningDraft=nil;simulationDraft=nil;knapsackDraft=nil;acceptanceSamplingDraft=nil;qualityControlDraft=nil;quadraticProgrammingDraft=nil;nonlinearProgrammingDraft=nil;goalProgrammingDraft=nil;facilityLocationDraft=nil;facilityLayoutDraft=nil
            modelSource="Normalized JSON · Line Balancing";markMatrixDraftEdited(status:"JSON applied to the Line Balancing editor");selectedPane = .model
        } catch {lastErrorMessage=Self.message(for:error);status="JSON was not applied: \(lastErrorMessage ?? "Invalid JSON")";selectedPane = .json}
    }

    func applyFacilityLayoutJSONToNativeEditor() {
        do { let envelope = try FacilitiesModelJSON.decodeUncheckedModel(from: Data(modelJSON.utf8)); guard case .layout(let model) = envelope else { throw FacilitiesModelError.invalidModel("Expected a layout model") };facilityLayoutDraft=FacilityLayoutDraft(model)
            lpDraft=nil;inventoryDraft=nil;networkDraft=nil;networkFlowDraft=nil;assignmentDraft=nil;transportationDraft=nil;forecastingDraft=nil;markovDraft=nil;queuingDraft=nil;decisionDraft=nil;zeroSumGameDraft=nil;decisionTreeDraft=nil;projectSchedulingDraft=nil;aggregatePlanningDraft=nil;materialRequirementsPlanningDraft=nil;simulationDraft=nil;knapsackDraft=nil;acceptanceSamplingDraft=nil;qualityControlDraft=nil;quadraticProgrammingDraft=nil;nonlinearProgrammingDraft=nil;goalProgrammingDraft=nil;facilityLocationDraft=nil;lineBalancingDraft=nil
            modelSource="Normalized JSON · Facility Layout";markMatrixDraftEdited(status:"JSON applied to the Facility Layout editor");selectedPane = .model
        } catch {lastErrorMessage=Self.message(for:error);status="JSON was not applied: \(lastErrorMessage ?? "Invalid JSON")";selectedPane = .json}
    }


    func solve(_ mode: SolveMode) {
        beginSolving()
        do {
            let program = try currentLPProgram()
            try syncLPDraftToJSON(program)
            guard let solver = LinearProgrammingBackends.backend(for: selectedBackend) else {
                showUnavailableExternalBackend()
                return
            }
            guard solver.capabilities.solves else {
                try showValidationReport(solver.validationReport(for: program), source: mode.label)
                return
            }

            let solution = try solver.solve(
                program,
                mode: mode == .relaxation ? .continuous : .integer
            )

            let output = try LinearProgramJSON.encodeSolution(solution)
            solutionJSON = String(decoding: output, as: UTF8.self)
            markSolved()
            status = "\(mode.label) solved with \(selectedBackend.rawValue): objective \(format(solution.objectiveValue))"
            lastResultLabel = mode.label
            selectedPane = .solution
        } catch {
            solutionJSON = ""
            runState = .failed
            lastErrorMessage = Self.message(for: error)
            status = "Run failed: \(lastErrorMessage ?? "Unknown run failure")"
            selectedPane = .run
        }
    }

    func solveNetwork() {
        beginSolving()
        do {
            let model = try currentNetworkModel()
            try syncNetworkDraftToJSON(model)
            guard let solver = NetworkBackends.backend(for: selectedBackend) else {
                showUnavailableExternalBackend()
                return
            }
            guard solver.capabilities.solves else {
                try showNetworkValidationReport(solver.validationReport(for: model), model: model)
                return
            }
            let solution = try solver.solve(model)
            let output = try NetworkModelJSON.encodeSolutionDocument(solver.solutionDocument(for: model, solution: solution))
            solutionJSON = String(decoding: output, as: UTF8.self)
            markSolved()
            status = "\(model.kind.rawValue) solved with \(selectedBackend.rawValue): \(solution.summary(format: format))"
            lastResultLabel = "\(model.kind.rawValue) Solution"
            selectedPane = .solution
        } catch {
            solutionJSON = ""
            runState = .failed
            lastErrorMessage = Self.message(for: error)
            status = "Run failed: \(lastErrorMessage ?? "Unknown run failure")"
            selectedPane = .run
        }
    }

    func solveFacilities() {
        beginSolving()
        do {
            let envelope = try currentFacilitiesModel()
            try syncFacilitiesDraftToJSON(envelope)
            guard let solver = FacilitiesBackends.backend(for: selectedBackend) else {
                showUnavailableExternalBackend()
                return
            }
            guard solver.capabilities.solves else {
                try showFacilitiesValidationReport(
                    solver.validationReport(for: envelope),
                    kind: envelope.kind
                )
                return
            }

            let solution = try solver.solve(
                envelope,
                layoutStrategy: selectedLayoutStrategy
            )
            let document = FacilitiesSolutionDocument(
                backend: solver.runMetadata(
                    for: envelope,
                    layoutStrategy: selectedLayoutStrategy
                ),
                solution: solution
            )
            let output = try FacilitiesModelJSON.encodeSolutionDocument(document)
            solutionJSON = String(decoding: output, as: UTF8.self)
            markSolved()
            status = "\(envelope.kind.displayName) solved with \(selectedBackend.rawValue): \(solution.summary(format: format))"
            lastResultLabel = "\(envelope.kind.displayName) Solution"
            selectedPane = .solution
        } catch {
            solutionJSON = ""
            runState = .failed
            lastErrorMessage = Self.message(for: error)
            status = "Run failed: \(lastErrorMessage ?? "Unknown run failure")"
            selectedPane = .run
        }
    }

    func solveInventory() {
        beginSolving()
        do {
            let model = try currentInventoryEnvelope()
            guard let solver = InventoryBackends.backend(for: selectedBackend) else {
                showUnavailableExternalBackend()
                return
            }
            guard solver.capabilities.solves else {
                try showInventoryValidationReport(solver.validationReport(for: model), kind: model.kind)
                return
            }
            try syncInventoryDraftToJSON(model)
            let solution = try solver.solve(model)
            let output = try InventoryModelJSON.encodeSolutionDocument(solver.solutionDocument(for: model, solution: solution))
            solutionJSON = String(decoding: output, as: UTF8.self)
            markSolved()
            status = "\(model.kind.displayName) solved with \(selectedBackend.rawValue)"
            lastResultLabel = "\(model.kind.displayName) Solution"
            selectedPane = .solution
        } catch {
            showSolveError(error)
        }
    }

    func solveDynamicProgramming() {
        beginSolving()
        do {
            let model = try currentDynamicProgrammingModel()
            try syncKnapsackDraftToJSON(model)
            guard let solver = DynamicProgrammingBackends.backend(for: selectedBackend) else {
                showUnavailableExternalBackend()
                return
            }
            guard solver.capabilities.solves else {
                try showDynamicProgrammingValidationReport(solver.validationReport(for: model), kind: model.kind)
                return
            }
            let solution = try solver.solve(model)
            let output = try DynamicProgrammingModelJSON.encodeSolutionDocument(solver.solutionDocument(for: model, solution: solution))
            solutionJSON = String(decoding: output, as: UTF8.self)
            markSolved()
            status = "\(model.kind.displayName) solved with \(selectedBackend.rawValue)"
            lastResultLabel = "\(model.kind.displayName) Solution"
            selectedPane = .solution
        } catch {
            showSolveError(error)
        }
    }

    func solveForecasting() {
        beginSolving()
        do {
            let request = try currentForecastingRequest()
            try syncForecastingDraftToJSON(request)
            guard let solver = ForecastingBackends.backend(for: selectedBackend) else {
                showUnavailableExternalBackend()
                return
            }
            guard solver.capabilities.solves else {
                try showForecastingValidationReport(solver.validationReport(for: request), request: request)
                return
            }
            let solution = try solver.solve(request)
            let output = try ForecastingModelJSON.encodeSolutionDocument(
                solver.solutionDocument(for: request, solution: solution)
            )
            solutionJSON = String(decoding: output, as: UTF8.self)
            markSolved()
            status = "\(request.method.displayName) solved with \(selectedBackend.rawValue)"
            lastResultLabel = "\(request.method.displayName) Solution"
            selectedPane = .solution
        } catch {
            showSolveError(error)
        }
    }

    func solveDecisionAnalysis() {
        beginSolving()
        do {
            let model = try currentDecisionAnalysisEnvelope()
            try syncDecisionDraftToJSON(model)
            guard let solver = DecisionAnalysisBackends.backend(for: selectedBackend) else {
                showUnavailableExternalBackend()
                return
            }
            guard solver.capabilities.solves else {
                try showDecisionAnalysisValidationReport(solver.validationReport(for: model), model: model)
                return
            }
            let solution = try solver.solve(model)
            let output = try DecisionAnalysisModelJSON.encodeSolutionDocument(
                solver.solutionDocument(for: model, solution: solution)
            )
            solutionJSON = String(decoding: output, as: UTF8.self)
            markSolved()
            status = "\(model.kind.displayName) solved with \(selectedBackend.rawValue)"
            lastResultLabel = "\(model.kind.displayName) Solution"
            selectedPane = .solution
        } catch {
            showSolveError(error)
        }
    }

    func solveSimulation() {
        beginSolving()
        do {
            let model = try currentSimulationModel()
            try syncSimulationDraftToJSON(model)
            guard let solver = SimulationBackends.backend(for: selectedBackend) else {
                showUnavailableExternalBackend()
                return
            }
            guard solver.capabilities.solves else {
                try showSimulationValidationReport(solver.validationReport(for: model), model: model)
                return
            }
            let solution = try solver.solve(
                model,
                options: SolverOptions(replications: simulationReplications)
            )
            let output = try SimulationJSON.encodeSolution(solver.solutionDocument(for: model, solution: solution))
            solutionJSON = String(decoding: output, as: UTF8.self)
            markSolved()
            let replicationLabel = solution.replications == 1 ? "replication" : "replications"
            status = "Simulation completed with \(selectedBackend.rawValue): \(solution.completedEntities) entities across \(solution.replications) \(replicationLabel)"
            lastResultLabel = "Simulation Solution"
            selectedPane = .solution
        } catch {
            showSolveError(error)
        }
    }

    func solveQuadraticProgramming() {
        beginSolving()
        do {
            let model = try currentQuadraticProgrammingModel()
            try syncQuadraticProgrammingDraftToJSON(model)
            guard let solver = QuadraticProgrammingBackends.backend(for: selectedBackend) else { showUnavailableExternalBackend(); return }
            guard solver.capabilities.solves else { try showQuadraticProgrammingValidationReport(solver.validationReport(for: model)); return }
            let solution = try solver.solve(model)
            solutionJSON = String(decoding: try QuadraticProgrammingJSON.encodeSolution(solver.solutionDocument(for: model, solution: solution)), as: UTF8.self)
            showSolvedStatus("Quadratic Programming", detail: "objective \(format(solution.objectiveValue))")
        } catch { showSolveError(error) }
    }

    func solveNonlinearProgramming() {
        beginSolving()
        do {
            let model = try currentNonlinearProgrammingModel()
            try syncNonlinearProgrammingDraftToJSON(model)
            guard let solver = NonlinearProgrammingBackends.backend(for: selectedBackend) else { showUnavailableExternalBackend(); return }
            guard solver.capabilities.solves else { try showNonlinearProgrammingValidationReport(solver.validationReport(for: model)); return }
            let solution = try solver.solve(model)
            solutionJSON = String(decoding: try NonlinearProgrammingJSON.encodeSolution(solver.solutionDocument(for: model, solution: solution)), as: UTF8.self)
            showSolvedStatus("Nonlinear Programming", detail: "objective \(format(solution.objectiveValue))")
        } catch { showSolveError(error) }
    }

    func solveMarkov() {
        beginSolving()
        do {
            let request = try currentMarkovRequest()
            try syncMarkovDraftToJSON(request)
            guard let solver = MarkovBackends.backend(for: selectedBackend) else { showUnavailableExternalBackend(); return }
            guard solver.capabilities.solves else { try showMarkovValidationReport(solver.validationReport(for: request)); return }
            let solution = try solver.solve(request)
            solutionJSON = String(decoding: try MarkovJSON.encodeSolution(solver.solutionDocument(for: request, solution: solution)), as: UTF8.self)
            showSolvedStatus("Markov Analysis", detail: "stationary cost \(format(solution.stationaryExpectedCost))")
        } catch { showSolveError(error) }
    }

    func solveGoalProgramming() {
        beginSolving()
        do {
            let model = try currentGoalProgrammingModel()
            try syncGoalProgrammingDraftToJSON(model)
            guard let solver = GoalProgrammingBackends.backend(for: selectedBackend) else { showUnavailableExternalBackend(); return }
            guard solver.capabilities.solves else { try showGoalProgrammingValidationReport(solver.validationReport(for: model)); return }
            let solution = try solver.solve(model)
            solutionJSON = String(decoding: try GoalProgrammingJSON.encodeSolution(solver.solutionDocument(for: model, solution: solution)), as: UTF8.self)
            showSolvedStatus("Goal Programming", detail: "\(solution.goalOutcomes.count) priorities")
        } catch { showSolveError(error) }
    }

    func solveProjectScheduling() {
        beginSolving()
        do {
            let model = try currentProjectSchedulingModel()
            try syncProjectSchedulingDraftToJSON(model)
            guard let solver = ProjectSchedulingBackends.backend(for: selectedBackend) else { showUnavailableExternalBackend(); return }
            guard solver.capabilities.solves else { try showProjectSchedulingValidationReport(solver.validationReport(for: model), model: model); return }
            let solution = try solver.solve(model)
            solutionJSON = String(decoding: try ProjectSchedulingJSON.encodeSolution(solver.solutionDocument(for: model, solution: solution)), as: UTF8.self)
            showSolvedStatus("Project Scheduling", detail: "duration \(format(solution.projectDuration))")
        } catch { showSolveError(error) }
    }

    func solveAcceptanceSampling() {
        beginSolving()
        do {
            let model = try currentAcceptanceSamplingModel()
            try syncAcceptanceSamplingDraftToJSON(model)
            guard let solver = AcceptanceSamplingBackends.backend(for: selectedBackend) else { showUnavailableExternalBackend(); return }
            guard solver.capabilities.solves else { try showAcceptanceSamplingValidationReport(solver.validationReport(for: model), model: model); return }
            let solution = try solver.solve(model)
            solutionJSON = String(decoding: try AcceptanceSamplingJSON.encodeSolution(solver.solutionDocument(for: model, solution: solution)), as: UTF8.self)
            showSolvedStatus("Acceptance Sampling", detail: "producer risk \(format(solution.producerRiskAtAQL))")
        } catch { showSolveError(error) }
    }

    func solveQualityControl() {
        beginSolving()
        do {
            let model = try currentQualityControlModel()
            try syncQualityControlDraftToJSON(model)
            guard let solver = QualityControlBackends.backend(for: selectedBackend) else { showUnavailableExternalBackend(); return }
            guard solver.capabilities.solves else { try showQualityControlValidationReport(solver.validationReport(for: model), model: model); return }
            let solution = try solver.solve(model)
            solutionJSON = String(decoding: try QualityControlJSON.encodeSolution(solver.solutionDocument(for: model, solution: solution)), as: UTF8.self)
            showSolvedStatus("Quality Control", detail: model.kind.rawValue)
        } catch { showSolveError(error) }
    }

    func solveAggregatePlanning() {
        beginSolving()
        do {
            let model = try currentAggregatePlanningModel()
            try syncAggregatePlanningDraftToJSON(model)
            guard let solver = AggregatePlanningBackends.backend(for: selectedBackend) else { showUnavailableExternalBackend(); return }
            guard solver.capabilities.solves else { try showAggregatePlanningValidationReport(solver.validationReport(for: model)); return }
            let solution = try solver.solve(model)
            solutionJSON = String(decoding: try AggregatePlanningJSON.encodeSolution(solver.solutionDocument(for: model, solution: solution)), as: UTF8.self)
            showSolvedStatus("Aggregate Planning", detail: "cost \(format(solution.totalCost))")
        } catch { showSolveError(error) }
    }

    func solveMaterialRequirementsPlanning() {
        beginSolving()
        do {
            let model = try currentMaterialRequirementsPlanningModel()
            try syncMaterialRequirementsPlanningDraftToJSON(model)
            guard let solver = MaterialRequirementsPlanningBackends.backend(for: selectedBackend) else { showUnavailableExternalBackend(); return }
            guard solver.capabilities.solves else { try showMaterialRequirementsPlanningValidationReport(solver.validationReport(for: model)); return }
            let solution = try solver.solve(model)
            solutionJSON = String(decoding: try MaterialRequirementsPlanningJSON.encodeSolution(solver.solutionDocument(for: model, solution: solution)), as: UTF8.self)
            showSolvedStatus("Material Requirements Planning", detail: "\(solution.schedules.count) item schedules")
        } catch { showSolveError(error) }
    }

    func solveScheduling() {
        beginSolving()
        do {
            let model = try SchedulingModelJSON.decodeModel(from: Data(modelJSON.utf8))
            guard let solver = SchedulingBackends.backend(for: selectedBackend) else { showUnavailableExternalBackend(); return }
            guard solver.capabilities.solves else { try showSchedulingValidationReport(solver.validationReport(for: model), model: model); return }
            let document = try solver.solve(model)
            solutionJSON = String(decoding: try SchedulingModelJSON.encodeSolution(document), as: UTF8.self)
            showSolvedStatus("Scheduling", detail: "makespan \(document.makespan)")
        } catch { showSolveError(error) }
    }

    func solveQueuing() {
        beginSolving()
        do {
            let model = try currentQueuingEnvelope()
            try syncQueuingDraftToJSON(model)
            guard let solver = QueuingBackends.backend(for: selectedBackend) else { showUnavailableExternalBackend(); return }
            guard solver.capabilities.solves else { try showQueuingValidationReport(solver.validationReport(for: model), model: model); return }
            let document = try solver.solve(model)
            solutionJSON = String(decoding: try QueuingModelJSON.encodeSolution(document), as: UTF8.self)
            showSolvedStatus("Queuing", detail: "utilization \(format(document.metrics.utilization))")
        } catch { showSolveError(error) }
    }

    func solveCurrentModel() {
        switch currentModelFamily {
        case .network: solveNetwork()
        case .facilities: solveFacilities()
        case .inventory: solveInventory()
        case .dynamicProgramming: solveDynamicProgramming()
        case .forecasting: solveForecasting()
        case .decisionAnalysis: solveDecisionAnalysis()
        case .simulation: solveSimulation()
        case .quadraticProgramming: solveQuadraticProgramming()
        case .nonlinearProgramming: solveNonlinearProgramming()
        case .markov: solveMarkov()
        case .goalProgramming: solveGoalProgramming()
        case .projectScheduling: solveProjectScheduling()
        case .acceptanceSampling: solveAcceptanceSampling()
        case .qualityControl: solveQualityControl()
        case .aggregatePlanning: solveAggregatePlanning()
        case .materialRequirementsPlanning: solveMaterialRequirementsPlanning()
        case .scheduling: solveScheduling()
        case .queuing: solveQueuing()
        case .linearProgramming, .unknown: break
        }
    }

    @MainActor
    @discardableResult
    func startCurrentModelRun() -> Task<Void, Never>? {
        guard runState != .solving else { return nil }
        if isSimulationModel { return startSimulationRun() }
        if isProjectSchedulingModel { return startProjectSchedulingRun() }
        if isMaterialRequirementsPlanningModel { return startMaterialRequirementsPlanningRun() }
        if isAggregatePlanningModel { return startAggregatePlanningRun() }
        if isFacilitiesModel { return startFacilitiesRun() }
        if case .dynamicProgramming(.boundedKnapsack) = currentModelFamily { return startKnapsackRun() }
        switch currentModelFamily {
        case .quadraticProgramming, .nonlinearProgramming, .goalProgramming, .acceptanceSampling, .qualityControl:
            return startTypedModelRun()
        default: break
        }
        runCurrentModel()
        return nil
    }

    @MainActor
    @discardableResult
    func startSimulationRun(
        operation: @escaping @Sendable (SolverRequest<SimulationModel>) throws -> SimulationRunOutput = SimulationRunOperation.run
    ) -> Task<Void, Never>? {
        guard runState != .solving else { return nil }
        do {
            let model = try currentSimulationModel()
            try syncSimulationDraftToJSON(model)
            let request = SolverRequest(model: model, backend: selectedBackend,
                options: SolverOptions(replications: simulationReplications))
            let sourceJSON = modelJSON
            let sourceDraft = simulationDraft
            beginSolving()
            solutionJSON = ""
            validationJSON = ""
            runNotes = []
            lastResultLabel = nil
            status = "Running Simulation with \(request.backend.rawValue)…"
            let id = UUID()
            interactiveRunID = id
            return Task { @MainActor [weak self] in
                let result = await Task.detached(priority: .userInitiated) {
                    Result { try operation(request) }
                }.value
                guard let self, self.interactiveRunID == id else { return }
                guard self.modelJSON == sourceJSON, self.simulationDraft == sourceDraft,
                      self.selectedBackend == request.backend,
                      self.simulationReplications == request.options.replications else {
                    self.runState = .notRun
                    self.status = "Simulation inputs changed. Run again to obtain a current result."
                    return
                }
                switch result {
                case .success(.solved(let json, let completed, let replications)):
                    self.solutionJSON = String(decoding: json, as: UTF8.self)
                    self.markSolved()
                    let unit = replications == 1 ? "replication" : "replications"
                    self.status = "Simulation completed with \(request.backend.rawValue): \(completed) entities across \(replications) \(unit)"
                    self.lastResultLabel = "Simulation Solution"
                    self.selectedPane = .solution
                case .success(.validated(let json, let report)):
                    self.showDomainValidationOutput(json, report: report, name: "Simulation")
                case .success(.unavailable):
                    self.showUnavailableExternalBackend()
                case .failure(let error):
                    self.showSolveError(error)
                }
            }
        } catch {
            showSolveError(error)
            return nil
        }
    }

    @MainActor
    @discardableResult
    func startProjectSchedulingRun(
        operation: @escaping @Sendable (SolverRequest<ProjectSchedulingModelEnvelope>) throws -> ProjectSchedulingRunOutput = ProjectSchedulingRunOperation.run
    ) -> Task<Void, Never>? {
        guard runState != .solving else { return nil }
        do {
            let model = try currentProjectSchedulingModel()
            try syncProjectSchedulingDraftToJSON(model)
            let request = SolverRequest(model: model, backend: selectedBackend)
            let sourceJSON = modelJSON
            let sourceDraft = projectSchedulingDraft
            beginSolving()
            solutionJSON = ""
            validationJSON = ""
            runNotes = []
            lastResultLabel = nil
            status = "Running \(model.kind.rawValue) with \(request.backend.rawValue)…"
            let id = UUID()
            interactiveRunID = id
            return Task { @MainActor [weak self] in
                let result = await Task.detached(priority: .userInitiated) {
                    Result { try operation(request) }
                }.value
                guard let self, self.interactiveRunID == id else { return }
                guard self.modelJSON == sourceJSON, self.projectSchedulingDraft == sourceDraft,
                      self.selectedBackend == request.backend else {
                    self.runState = .notRun
                    self.status = "Project inputs changed. Run again to obtain a current result."
                    return
                }
                switch result {
                case .success(.solved(let json, let duration)):
                    self.solutionJSON = String(decoding: json, as: UTF8.self)
                    self.showSolvedStatus("Project Scheduling", detail: "duration \(self.format(duration))")
                case .success(.validated(let json, let report)):
                    self.showDomainValidationOutput(json, report: report, name: model.kind.rawValue)
                case .success(.unavailable):
                    self.showUnavailableExternalBackend()
                case .failure(let error):
                    self.showSolveError(error)
                }
            }
        } catch {
            if error is ProjectSchedulingDraftError { validateCurrentModel() }
            else { showSolveError(error) }
            return nil
        }
    }

    @MainActor
    @discardableResult
    func startAggregatePlanningRun(
        operation: @escaping @Sendable (SolverRequest<AggregatePlanningModel>) throws -> AggregatePlanningRunOutput = AggregatePlanningRunOperation.run
    ) -> Task<Void, Never>? {
        guard runState != .solving else { return nil }
        do {
            let model = try currentAggregatePlanningModel()
            try syncAggregatePlanningDraftToJSON(model)
            let request = SolverRequest(model: model, backend: selectedBackend)
            let sourceJSON = modelJSON
            let sourceDraft = aggregatePlanningDraft
            beginSolving()
            solutionJSON = ""
            validationJSON = ""
            runNotes = []
            lastResultLabel = nil
            status = "Running Aggregate Planning with \(request.backend.rawValue)…"
            let id = UUID()
            interactiveRunID = id
            return Task { @MainActor [weak self] in
                let result = await Task.detached(priority: .userInitiated) {
                    Result { try operation(request) }
                }.value
                guard let self, self.interactiveRunID == id else { return }
                guard self.modelJSON == sourceJSON, self.aggregatePlanningDraft == sourceDraft,
                      self.selectedBackend == request.backend else {
                    self.runState = .notRun
                    self.status = "Aggregate Planning inputs changed. Run again to obtain a current result."
                    return
                }
                switch result {
                case .success(.solved(let json, let cost)):
                    self.solutionJSON = String(decoding: json, as: UTF8.self)
                    self.showSolvedStatus("Aggregate Planning", detail: "cost \(self.format(cost))")
                case .success(.validated(let json, let report)):
                    self.showDomainValidationOutput(json, report: report, name: "Aggregate Planning")
                case .success(.unavailable):
                    self.showUnavailableExternalBackend()
                case .failure(let error):
                    self.showSolveError(error)
                }
            }
        } catch {
            if error is AggregatePlanningDraftError { validateCurrentModel() }
            else { showSolveError(error) }
            return nil
        }
    }

    @MainActor
    @discardableResult
    func startMaterialRequirementsPlanningRun(
        operation: @escaping @Sendable (SolverRequest<MaterialRequirementsPlanningModel>) throws -> MaterialRequirementsPlanningRunOutput = MaterialRequirementsPlanningRunOperation.run
    ) -> Task<Void, Never>? {
        guard runState != .solving else { return nil }
        do {
            let model = try currentMaterialRequirementsPlanningModel()
            try syncMaterialRequirementsPlanningDraftToJSON(model)
            let request = SolverRequest(model: model, backend: selectedBackend)
            let sourceJSON = modelJSON
            let sourceDraft = materialRequirementsPlanningDraft
            beginSolving()
            solutionJSON = ""
            validationJSON = ""
            runNotes = []
            lastResultLabel = nil
            status = "Running Material Requirements Planning with \(request.backend.rawValue)…"
            let id = UUID()
            interactiveRunID = id
            return Task { @MainActor [weak self] in
                let result = await Task.detached(priority: .userInitiated) {
                    Result { try operation(request) }
                }.value
                guard let self, self.interactiveRunID == id else { return }
                guard self.modelJSON == sourceJSON, self.materialRequirementsPlanningDraft == sourceDraft,
                      self.selectedBackend == request.backend else {
                    self.runState = .notRun
                    self.status = "Material Requirements Planning inputs changed. Run again to obtain a current result."
                    return
                }
                switch result {
                case .success(.solved(let json, let schedules)):
                    self.solutionJSON = String(decoding: json, as: UTF8.self)
                    self.showSolvedStatus("Material Requirements Planning", detail: "\(schedules) item schedules")
                case .success(.validated(let json, let report)):
                    self.showDomainValidationOutput(json, report: report, name: "Material Requirements Planning")
                case .success(.unavailable):
                    self.showUnavailableExternalBackend()
                case .failure(let error):
                    self.showSolveError(error)
                }
            }
        } catch {
            if error is MaterialRequirementsPlanningDraftError { validateCurrentModel() }
            else { showSolveError(error) }
            return nil
        }
    }

    @MainActor
    @discardableResult
    func startKnapsackRun(
        operation: @escaping @Sendable (SolverRequest<DynamicProgrammingModelEnvelope>) throws -> KnapsackRunOutput = KnapsackRunOperation.run
    ) -> Task<Void, Never>? {
        guard runState != .solving else { return nil }
        do {
            let model = try currentDynamicProgrammingModel()
            try syncKnapsackDraftToJSON(model)
            let request = SolverRequest(model: model, backend: selectedBackend)
            let sourceJSON = modelJSON
            let sourceDraft = knapsackDraft
            beginSolving()
            solutionJSON = ""
            validationJSON = ""
            runNotes = []
            lastResultLabel = nil
            status = "Running \(model.kind.displayName) with \(request.backend.rawValue)…"
            let id = UUID()
            interactiveRunID = id
            return Task { @MainActor [weak self] in
                let result = await Task.detached(priority: .userInitiated) {
                    Result { try operation(request) }
                }.value
                guard let self, self.interactiveRunID == id else { return }
                guard self.modelJSON == sourceJSON, self.knapsackDraft == sourceDraft,
                      self.selectedBackend == request.backend else {
                    self.runState = .notRun
                    self.status = "Knapsack inputs changed. Run again to obtain a current result."
                    return
                }
                switch result {
                case .success(.solved(let json)):
                    self.solutionJSON = String(decoding: json, as: UTF8.self)
                    self.showSolvedStatus(model.kind.displayName, detail: "complete")
                case .success(.validated(let json, let report)):
                    self.showDomainValidationOutput(json, report: report, name: model.kind.displayName)
                case .success(.unavailable):
                    self.showUnavailableExternalBackend()
                case .failure(let error):
                    self.showSolveError(error)
                }
            }
        } catch {
            if error is KnapsackDraftError { validateCurrentModel() }
            else { showSolveError(error) }
            return nil
        }
    }

    @MainActor
    @discardableResult
    func startFacilitiesRun(
        operation: @escaping @Sendable (SolverRequest<FacilitiesModelEnvelope>, FacilityLayoutSolvingStrategy) throws -> FacilitiesRunOutput = FacilitiesRunOperation.run
    ) -> Task<Void, Never>? {
        guard runState != .solving else { return nil }
        do {
            let model = try currentFacilitiesModel()
            try syncFacilitiesDraftToJSON(model)
            let strategy = selectedLayoutStrategy
            let sourceLayout = facilityLayoutDraft
            let sourceLocation = facilityLocationDraft
            let request = SolverRequest(model: model, backend: selectedBackend)
            let sourceJSON = modelJSON
            let sourceDraft = lineBalancingDraft
            beginSolving()
            solutionJSON = ""
            validationJSON = ""
            runNotes = []
            lastResultLabel = nil
            status = "Running \(model.kind.displayName) with \(request.backend.rawValue)…"
            let id = UUID()
            interactiveRunID = id
            return Task { @MainActor [weak self] in
                let result = await Task.detached(priority: .userInitiated) {
                    Result { try operation(request, strategy) }
                }.value
                guard let self, self.interactiveRunID == id else { return }
                guard self.modelJSON == sourceJSON, self.lineBalancingDraft == sourceDraft,
                      self.selectedBackend == request.backend,
                      self.facilityLayoutDraft == sourceLayout, self.facilityLocationDraft == sourceLocation,
                      (model.kind != .layout || self.selectedLayoutStrategy == strategy) else {
                    self.runState = .notRun
                    self.status = "Facilities inputs changed. Run again to obtain a current result."
                    return
                }
                switch result {
                case .success(.solved(let json, let solution)):
                    self.solutionJSON = String(decoding: json, as: UTF8.self)
                    self.showSolvedStatus(model.kind.displayName, detail: solution.summary(format: self.format))
                case .success(.validated(let json, let report)):
                    self.showDomainValidationOutput(json, report: report, name: model.kind.displayName)
                case .success(.unavailable):
                    self.showUnavailableExternalBackend()
                case .failure(let error):
                    self.showSolveError(error)
                }
            }
        } catch {
            if error is OptimizationDraftError { validateCurrentModel() }
            else { showSolveError(error) }
            return nil
        }
    }

    @MainActor
    @discardableResult
    func startTypedModelRun(
        operation: @escaping @Sendable (TypedModelRunRequest) throws -> TypedModelRunOutput = TypedModelRunOperation.run
    ) -> Task<Void, Never>? {
        guard runState != .solving else { return nil }
        do {
            let request: TypedModelRunRequest
            switch currentModelFamily {
            case .quadraticProgramming:
                let model = try currentQuadraticProgrammingModel()
                try syncQuadraticProgrammingDraftToJSON(model)
                request = .quadratic(SolverRequest(model: model, backend: selectedBackend))
            case .nonlinearProgramming:
                let model = try currentNonlinearProgrammingModel()
                try syncNonlinearProgrammingDraftToJSON(model)
                request = .nonlinear(SolverRequest(model: model, backend: selectedBackend))
            case .goalProgramming:
                let model = try currentGoalProgrammingModel()
                try syncGoalProgrammingDraftToJSON(model)
                request = .goal(SolverRequest(model: model, backend: selectedBackend))
            case .acceptanceSampling:
                let model = try currentAcceptanceSamplingModel()
                try syncAcceptanceSamplingDraftToJSON(model)
                request = .acceptance(SolverRequest(model: model, backend: selectedBackend))
            case .qualityControl:
                let model = try currentQualityControlModel()
                try syncQualityControlDraftToJSON(model)
                request = .quality(SolverRequest(model: model, backend: selectedBackend))
            default: return nil
            }
            let source = TypedModelRunSnapshot(self)
            beginSolving()
            solutionJSON = ""
            validationJSON = ""
            runNotes = []
            lastResultLabel = nil
            status = "Running \(request.name) with \(source.backend.rawValue)…"
            let id = UUID()
            interactiveRunID = id
            return Task { @MainActor [weak self] in
                let result = await Task.detached(priority: .userInitiated) {
                    Result { try operation(request) }
                }.value
                guard let self, self.interactiveRunID == id else { return }
                guard TypedModelRunSnapshot(self) == source else {
                    self.runState = .notRun
                    self.status = "Inputs changed. Run again to obtain a current result."
                    return
                }
                switch result {
                case .success(.solved(let json, let summary)):
                    self.solutionJSON = String(decoding: json, as: UTF8.self)
                    let detail: String
                    switch summary {
                    case .objective(let value): detail = "objective \(self.format(value))"
                    case .priorities(let count): detail = "\(count) priorities"
                    case .producerRisk(let value): detail = "producer risk \(self.format(value))"
                    case .qualityKind(let kind): detail = kind
                    }
                    self.showSolvedStatus(request.name, detail: detail)
                case .success(.validated(let json, let report)):
                    self.showDomainValidationOutput(json, report: report, name: request.name)
                case .success(.unavailable): self.showUnavailableExternalBackend()
                case .failure(let error): self.showSolveError(error)
                }
            }
        } catch {
            if error is OptimizationDraftError || error is AcceptanceSamplingDraftError || error is QualityControlDraftError {
                validateCurrentModel()
            } else { showSolveError(error) }
            return nil
        }
    }

    func runCurrentModel() {
        if isLinearProgrammingModel {
            if let draft = lpDraft, draft.draftDiagnostics().contains(where: { $0.severity == .error }) {
                validateCurrentModel()
                return
            }
            solve(lpDraft?.variables.contains(where: { $0.type != .continuous }) == true ? .integer : .relaxation)
        } else if isInventoryModel, inventoryDraft != nil {
            solveInventory()
        } else if forecastingDraft != nil {
            solveForecasting()
        } else if queuingDraft != nil {
            solveQueuing()
        } else if decisionDraft != nil || zeroSumGameDraft != nil || decisionTreeDraft != nil {
            solveDecisionAnalysis()
        } else {
            solveCurrentModel()
        }
    }

    func validateCurrentModel() {
        beginValidation()
        do {
            let data = Data(modelJSON.utf8)
            switch currentModelFamily {
            case .linearProgramming:
                let program = try currentLPProgram()
                try validate(program: program, source: "LP/ILP JSON")
            case .network:
                let model = try currentNetworkModel(); let backend = ValidateOnlyNetworkBackend(); try syncNetworkDraftToJSON(model); try showNetworkValidationReport(backend.validationReport(for: model), model: model)
            case .facilities(let kind):
                let model = try currentFacilitiesModel(); try syncFacilitiesDraftToJSON(model); try showFacilitiesValidationReport(ValidateOnlyFacilitiesBackend().validationReport(for: model), kind: kind)
            case .inventory(let kind):
                let model = try currentInventoryEnvelope(); try validateInventory(model, kind: kind)
            case .dynamicProgramming(let kind):
                let model = try currentDynamicProgrammingModel(); try syncKnapsackDraftToJSON(model); try showDynamicProgrammingValidationReport(ValidateOnlyDynamicProgrammingBackend().validationReport(for: model), kind: kind)
            case .forecasting:
                let request = try currentForecastingRequest(); try syncForecastingDraftToJSON(request); try showForecastingValidationReport(ValidateOnlyForecastingBackend().validationReport(for: request), request: request)
            case .decisionAnalysis:
                let model = try currentDecisionAnalysisEnvelope(); try syncDecisionDraftToJSON(model); try showDecisionAnalysisValidationReport(ValidateOnlyDecisionAnalysisBackend().validationReport(for: model), model: model)
            case .simulation:
                let model = try currentSimulationModel(); try syncSimulationDraftToJSON(model); try showSimulationValidationReport(ValidateOnlySimulationBackend().validationReport(for: model), model: model)
            case .quadraticProgramming:
                let model = try currentQuadraticProgrammingModel(); try syncQuadraticProgrammingDraftToJSON(model); try showQuadraticProgrammingValidationReport(ValidateOnlyQuadraticProgrammingBackend().validationReport(for: model))
            case .nonlinearProgramming:
                let model = try currentNonlinearProgrammingModel(); try syncNonlinearProgrammingDraftToJSON(model); try showNonlinearProgrammingValidationReport(ValidateOnlyNonlinearProgrammingBackend().validationReport(for: model))
            case .markov:
                let request = try currentMarkovRequest(); try syncMarkovDraftToJSON(request); try showMarkovValidationReport(ValidateOnlyMarkovBackend().validationReport(for: request))
            case .goalProgramming:
                let model = try currentGoalProgrammingModel(); try syncGoalProgrammingDraftToJSON(model); try showGoalProgrammingValidationReport(ValidateOnlyGoalProgrammingBackend().validationReport(for: model))
            case .projectScheduling:
                let model = try currentProjectSchedulingModel(); try syncProjectSchedulingDraftToJSON(model); try showProjectSchedulingValidationReport(ValidateOnlyProjectSchedulingBackend().validationReport(for: model), model: model)
            case .acceptanceSampling:
                let model = try currentAcceptanceSamplingModel(); try syncAcceptanceSamplingDraftToJSON(model); try showAcceptanceSamplingValidationReport(ValidateOnlyAcceptanceSamplingBackend().validationReport(for: model), model: model)
            case .qualityControl:
                let model = try currentQualityControlModel(); try syncQualityControlDraftToJSON(model); try showQualityControlValidationReport(ValidateOnlyQualityControlBackend().validationReport(for: model), model: model)
            case .aggregatePlanning:
                let model = try currentAggregatePlanningModel(); try syncAggregatePlanningDraftToJSON(model); try showAggregatePlanningValidationReport(ValidateOnlyAggregatePlanningBackend().validationReport(for: model))
            case .materialRequirementsPlanning:
                let model = try currentMaterialRequirementsPlanningModel(); try syncMaterialRequirementsPlanningDraftToJSON(model); try showMaterialRequirementsPlanningValidationReport(ValidateOnlyMaterialRequirementsPlanningBackend().validationReport(for: model))
            case .scheduling:
                let model = try SchedulingModelJSON.decodeModel(from: data); try showSchedulingValidationReport(ValidateOnlySchedulingBackend().validationReport(for: model), model: model)
            case .queuing:
                let model = try currentQueuingEnvelope(); try syncQueuingDraftToJSON(model); try showQueuingValidationReport(ValidateOnlyQueuingBackend().validationReport(for: model), model: model)
            case .unknown:
                throw CocoaError(.fileReadCorruptFile, userInfo: [NSLocalizedDescriptionKey: "Unsupported normalized model JSON"])
            }
        } catch {
            solutionJSON = ""
            modelState = .invalid
            runState = .notRun
            if let draft = lpDraft, error is LPDraftError {
                validationDiagnostics = draft.draftDiagnostics()
                validationJSON = (try? String(decoding: Self.jsonEncoder.encode(
                    ValidationReport(backend: .validateOnly, diagnostics: validationDiagnostics)
                ), as: UTF8.self)) ?? ""
                lastErrorMessage = validationDiagnostics.first?.message
                status = "LP draft has \(validationDiagnostics.count) input issue(s)"
            } else if let draft = networkDraft, let draftError = error as? NetworkDraftError {
                validationDiagnostics = Self.networkDraftDiagnostics(draftError, kind: draft.kind)
                validationJSON = (try? String(decoding: Self.jsonEncoder.encode(
                    NetworkValidationDocument(kind: draft.kind.problemKind, backend: .validateOnly, diagnostics: validationDiagnostics)
                ), as: UTF8.self)) ?? ""
                lastErrorMessage = validationDiagnostics.first?.message
                status = "Network draft has \(validationDiagnostics.count) input issue(s)"
            } else if let draftError = error as? AssignmentDraftError {
                validationDiagnostics = draftError.issues.map { ValidationDiagnostic(severity: .error, code: "network.AP.input", message: $0.message) }
                validationJSON = (try? String(decoding: Self.jsonEncoder.encode(ValidationReport(backend: .validateOnly, diagnostics: validationDiagnostics)), as: UTF8.self)) ?? ""
                lastErrorMessage = validationDiagnostics.first?.message
                status = "Assignment draft has \(validationDiagnostics.count) input issue(s)"
            } else if let draftError = error as? TransportationDraftError {
                validationDiagnostics = draftError.issues.map { ValidationDiagnostic(severity: .error, code: "network.TP.input", message: $0.message) }
                validationJSON = (try? String(decoding: Self.jsonEncoder.encode(ValidationReport(backend: .validateOnly, diagnostics: validationDiagnostics)), as: UTF8.self)) ?? ""
                lastErrorMessage = validationDiagnostics.first?.message
                status = "Transportation draft has \(validationDiagnostics.count) input issue(s)"
            } else if let draftError = error as? NetworkFlowDraftError {
                validationDiagnostics = draftError.issues.map { ValidationDiagnostic(severity: .error, code: "network.CNF.input", message: $0.message) }
                validationJSON = (try? String(decoding: Self.jsonEncoder.encode(ValidationReport(backend: .validateOnly, diagnostics: validationDiagnostics)), as: UTF8.self)) ?? ""
                lastErrorMessage = validationDiagnostics.first?.message
                status = "CNF draft has \(validationDiagnostics.count) input issue(s)"
            } else if let draft = decisionDraft, error is DecisionAnalysisDraftError {
                validationDiagnostics = draft.draftDiagnostics()
                let document = DecisionAnalysisValidationDocument(kind: draft.kind, backend: .validateOnly, diagnostics: validationDiagnostics)
                validationJSON = (try? String(decoding: DecisionAnalysisModelJSON.encodeValidation(document), as: UTF8.self)) ?? ""
                lastErrorMessage = validationDiagnostics.first?.message
                status = "Decision analysis draft has \(validationDiagnostics.count) input issue(s)"
            } else if let draft = zeroSumGameDraft, error is DecisionAnalysisDraftError {
                validationDiagnostics = draft.draftDiagnostics()
                let document = DecisionAnalysisValidationDocument(kind: .zeroSumGame, backend: .validateOnly, diagnostics: validationDiagnostics)
                validationJSON = (try? String(decoding: DecisionAnalysisModelJSON.encodeValidation(document), as: UTF8.self)) ?? ""
                lastErrorMessage = validationDiagnostics.first?.message
                status = "Zero-sum game draft has \(validationDiagnostics.count) input issue(s)"
            } else if let draft = decisionTreeDraft, error is DecisionTreeDraftError {
                validationDiagnostics = draft.draftDiagnostics()
                let document = DecisionAnalysisValidationDocument(kind: .decisionTree, backend: .validateOnly, diagnostics: validationDiagnostics)
                validationJSON = (try? String(decoding: DecisionAnalysisModelJSON.encodeValidation(document), as: UTF8.self)) ?? ""
                lastErrorMessage = validationDiagnostics.first?.message
                status = "Decision tree draft has \(validationDiagnostics.count) input issue(s)"
            } else if let draft = projectSchedulingDraft, error is ProjectSchedulingDraftError {
                validationDiagnostics = draft.draftDiagnostics()
                let document = ProjectSchedulingValidationDocument(kind: draft.kind, backend: .validateOnly, diagnostics: validationDiagnostics)
                validationJSON = (try? String(decoding: ProjectSchedulingJSON.encodeValidation(document), as: UTF8.self)) ?? ""
                lastErrorMessage = validationDiagnostics.first?.message
                status = "Project draft has \(validationDiagnostics.count) input issue(s)"
            } else if let draft = aggregatePlanningDraft, error is AggregatePlanningDraftError {
                validationDiagnostics = draft.draftDiagnostics()
                let document = AggregatePlanningValidationDocument(backend: .validateOnly, diagnostics: validationDiagnostics)
                validationJSON = (try? String(decoding: AggregatePlanningJSON.encodeValidation(document), as: UTF8.self)) ?? ""
                lastErrorMessage = validationDiagnostics.first?.message
                status = "Aggregate-planning draft has \(validationDiagnostics.count) input issue(s)"
            } else if let draft = materialRequirementsPlanningDraft, error is MaterialRequirementsPlanningDraftError {
                validationDiagnostics = draft.draftDiagnostics()
                let document = MaterialRequirementsPlanningValidationDocument(backend: .validateOnly, diagnostics: validationDiagnostics)
                validationJSON = (try? String(decoding: MaterialRequirementsPlanningJSON.encodeValidation(document), as: UTF8.self)) ?? ""
                lastErrorMessage = validationDiagnostics.first?.message
                status = "Material-requirements-planning draft has \(validationDiagnostics.count) input issue(s)"
            } else if let draft = simulationDraft, error is SimulationDraftError {
                validationDiagnostics = draft.draftDiagnostics()
                let report = ValidationReport(backend: .validateOnly, diagnostics: validationDiagnostics)
                validationJSON = (try? String(decoding: SimulationJSON.encodeValidation(SimulationValidationDocument(model: (try? draft.makeModel()) ?? SimulationModel(title: draft.title, timeUnit: draft.timeUnit, representation: draft.representation, components: []), report: report)), as: UTF8.self)) ?? ""
                lastErrorMessage = validationDiagnostics.first?.message
                status = "Simulation draft has \(validationDiagnostics.count) input issue(s)"
            } else if let draft = knapsackDraft, error is KnapsackDraftError {
                validationDiagnostics = draft.draftDiagnostics()
                let document = DynamicProgrammingValidationDocument(kind: .boundedKnapsack, backend: .validateOnly, diagnostics: validationDiagnostics)
                validationJSON = (try? String(decoding: DynamicProgrammingModelJSON.encodeValidation(document), as: UTF8.self)) ?? ""
                lastErrorMessage = validationDiagnostics.first?.message
                status = "Bounded-knapsack draft has \(validationDiagnostics.count) input issue(s)"
            } else if let draft = acceptanceSamplingDraft, error is AcceptanceSamplingDraftError {
                validationDiagnostics = draft.draftDiagnostics()
                let document = AcceptanceSamplingValidationDocument(kind: draft.kind, backend: .validateOnly, diagnostics: validationDiagnostics)
                validationJSON = (try? String(decoding: AcceptanceSamplingJSON.encodeValidation(document), as: UTF8.self)) ?? ""
                lastErrorMessage = validationDiagnostics.first?.message
                status = "Acceptance-sampling draft has \(validationDiagnostics.count) input issue(s)"
            } else if let draft = qualityControlDraft, error is QualityControlDraftError {
                validationDiagnostics = draft.draftDiagnostics()
                let document = QualityControlValidationDocument(kind: draft.kind, backend: .validateOnly, diagnostics: validationDiagnostics)
                validationJSON = (try? String(decoding: QualityControlJSON.encodeValidation(document), as: UTF8.self)) ?? ""
                lastErrorMessage = validationDiagnostics.first?.message
                status = "Quality-control draft has \(validationDiagnostics.count) input issue(s)"
            } else if let draft = facilityLayoutDraft, error is OptimizationDraftError {
                validationDiagnostics = draft.draftDiagnostics()
                validationJSON = (try? String(decoding: FacilitiesModelJSON.encodeValidation(FacilitiesValidationDocument(kind: .layout, diagnostics: validationDiagnostics)), as: UTF8.self)) ?? ""
                lastErrorMessage = validationDiagnostics.first?.message
                status = "Facility-layout draft has input issues"
            } else if let draft = lineBalancingDraft, error is OptimizationDraftError {
                validationDiagnostics = draft.draftDiagnostics()
                validationJSON = (try? String(decoding: FacilitiesModelJSON.encodeValidation(FacilitiesValidationDocument(kind: .lineBalancing, diagnostics: validationDiagnostics)), as: UTF8.self)) ?? ""
                lastErrorMessage = validationDiagnostics.first?.message
                status = "Line-balancing draft has input issues"
            } else if let draft = facilityLocationDraft, error is OptimizationDraftError {
                validationDiagnostics = draft.draftDiagnostics()
                validationJSON = (try? String(decoding: FacilitiesModelJSON.encodeValidation(FacilitiesValidationDocument(kind: .location, diagnostics: validationDiagnostics)), as: UTF8.self)) ?? ""
                lastErrorMessage = validationDiagnostics.first?.message
                status = "Facility-location draft has input issues"
            } else if let draft = goalProgrammingDraft, error is OptimizationDraftError {
                validationDiagnostics = draft.draftDiagnostics()
                validationJSON = (try? String(decoding: GoalProgrammingJSON.encodeValidation(GoalProgrammingValidationDocument(backend: .validateOnly, diagnostics: validationDiagnostics)), as: UTF8.self)) ?? ""
                lastErrorMessage = validationDiagnostics.first?.message
                status = "Goal-programming draft has input issues"
            } else if let draft = nonlinearProgrammingDraft, error is OptimizationDraftError {
                validationDiagnostics = draft.draftDiagnostics()
                validationJSON = (try? String(decoding: NonlinearProgrammingJSON.encodeValidation(NonlinearProgramValidationDocument(backend: .validateOnly, diagnostics: validationDiagnostics)), as: UTF8.self)) ?? ""
                lastErrorMessage = validationDiagnostics.first?.message
                status = "Nonlinear-programming draft has input issues"
            } else if let draft = quadraticProgrammingDraft, error is OptimizationDraftError {
                validationDiagnostics = draft.draftDiagnostics()
                validationJSON = (try? String(decoding: QuadraticProgrammingJSON.encodeValidation(QuadraticProgramValidationDocument(backend:.validateOnly,diagnostics:validationDiagnostics)), as: UTF8.self)) ?? ""
                lastErrorMessage=validationDiagnostics.first?.message;status="Quadratic-programming draft has \(validationDiagnostics.count) input issue(s)"
            } else {
                lastErrorMessage = Self.message(for: error)
                status = "Validation failed: \(Self.message(for: error))"
            }
            selectedPane = .validation
        }
    }

    func loadSample(_ sample: SampleModel) {
        lpDraft = nil
        inventoryDraft = nil
        networkDraft = nil
        networkFlowDraft = nil
        assignmentDraft = nil
        transportationDraft = nil
        forecastingDraft = nil
        markovDraft = nil
        queuingDraft = nil
        decisionDraft = nil
        zeroSumGameDraft = nil
        decisionTreeDraft = nil
        projectSchedulingDraft = nil
        aggregatePlanningDraft = nil
        materialRequirementsPlanningDraft = nil
        simulationDraft = nil
        knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
        switch sample {
        case .linearProgram:
            modelJSON = SampleModels.linearProgramJSON
        case .integerProgram:
            modelJSON = SampleModels.integerProgramJSON
        case .travelingSalesperson:
            modelJSON = SampleModels.travelingSalespersonJSON
        case .facilityLayout:
            modelJSON = SampleModels.facilityLayoutJSON
        case .facilityLocation:
            modelJSON = SampleModels.facilityLocationJSON
        case .lineBalancing:
            modelJSON = SampleModels.lineBalancingJSON
        case .economicOrderQuantity:
            modelJSON = SampleModels.economicOrderQuantityJSON
        case .boundedKnapsack:
            modelJSON = SampleModels.boundedKnapsackJSON
        case .linearTrendForecast:
            modelJSON = SampleModels.linearTrendForecastJSON
        case .payoffAnalysis:
            modelJSON = SampleModels.payoffAnalysisJSON
        case .decisionTree:
            modelJSON = SampleModels.decisionTreeJSON
        case .mm1Queue:
            modelJSON = SampleModels.mm1QueueJSON
        case .simulation:
            modelJSON = SampleModels.simulationJSON
        case .quadraticProgramming:
            modelJSON = SampleModels.quadraticProgrammingJSON
        case .nonlinearProgramming:
            modelJSON = SampleModels.nonlinearProgrammingJSON
        case .markov:
            modelJSON = SampleModels.markovJSON
        case .goalProgramming:
            modelJSON = SampleModels.goalProgrammingJSON
        case .aggregatePlanning:
            modelJSON = SampleModels.aggregatePlanningJSON
        case .materialRequirementsPlanning:
            modelJSON = SampleModels.materialRequirementsPlanningJSON
        case .acceptanceSampling:
            modelJSON = SampleModels.acceptanceSamplingJSON
        case .qualityControl:
            modelJSON = SampleModels.qualityControlJSON
        case .projectScheduling:
            modelJSON = SampleModels.projectSchedulingJSON
        }
        if case .linearProgram = sample, let program = try? LinearProgramJSON.decodeProgram(from: Data(modelJSON.utf8)) {
            lpDraft = LinearProgrammingDraft(program: program)
        }
        if case .integerProgram = sample, let program = try? LinearProgramJSON.decodeProgram(from: Data(modelJSON.utf8)) {
            lpDraft = LinearProgrammingDraft(program: program)
        }
        if case .travelingSalesperson = sample,
           let envelope = try? NetworkModelJSON.decodeModel(from: Data(modelJSON.utf8)) {
            networkDraft = NetworkDraft(envelope: envelope)
        }
        if case .linearTrendForecast = sample,
           let request = try? ForecastingModelJSON.decodeRequest(from: Data(modelJSON.utf8)) {
            forecastingDraft = ForecastingDraft(request)
        } else if case .linearTrendForecast = sample {
            forecastingDraft = nil
        }
        if case .markov = sample,
           let request = try? MarkovJSON.decodeRequest(from: Data(modelJSON.utf8)) {
            markovDraft = MarkovDraft(request)
        }
        if case .mm1Queue = sample,
           let envelope = try? QueuingModelJSON.decodeModel(from: Data(modelJSON.utf8)) {
            queuingDraft = QueuingDraft(envelope)
        }
        if sample == .payoffAnalysis || sample == .decisionTree,
           let envelope = try? DecisionAnalysisModelJSON.decodeModel(from: Data(modelJSON.utf8)) {
            decisionDraft = DecisionAnalysisDraft(envelope)
            decisionTreeDraft = DecisionTreeDraft(envelope)
        }
        if case .projectScheduling = sample,
           let envelope = try? ProjectSchedulingJSON.decodeModel(from: Data(modelJSON.utf8)) {
            projectSchedulingDraft = ProjectSchedulingDraft(envelope)
        }
        if case .aggregatePlanning = sample,
           let model = try? AggregatePlanningJSON.decodeModel(from: Data(modelJSON.utf8)) {
            aggregatePlanningDraft = AggregatePlanningDraft(model)
        }
        if case .materialRequirementsPlanning = sample,
           let model = try? MaterialRequirementsPlanningJSON.decodeModel(from: Data(modelJSON.utf8)) {
            materialRequirementsPlanningDraft = MaterialRequirementsPlanningDraft(model)
        }
        if case .simulation = sample,
           let model = try? SimulationJSON.decodeUncheckedModel(from: Data(modelJSON.utf8)) {
            simulationDraft = SimulationDraft(model)
        }
        if case .boundedKnapsack = sample,
           let envelope = try? DynamicProgrammingModelJSON.decodeUncheckedModel(from: Data(modelJSON.utf8)),
           case .boundedKnapsack(let problem) = envelope {
            knapsackDraft = KnapsackDraft(problem)
        }
        if case .acceptanceSampling = sample,
           let model = try? AcceptanceSamplingJSON.decodeModel(from: Data(modelJSON.utf8)) {
            acceptanceSamplingDraft = AcceptanceSamplingDraft(model)
        }
        if case .qualityControl = sample,
           let model = try? QualityControlJSON.decodeModel(from: Data(modelJSON.utf8)) {
            qualityControlDraft = QualityControlDraft(model)
        }
        if case .quadraticProgramming = sample, let model = try? QuadraticProgrammingJSON.decodeUncheckedModel(from:Data(modelJSON.utf8)) { quadraticProgrammingDraft=QuadraticProgrammingDraft(model) }
        if case .nonlinearProgramming = sample, let model = try? NonlinearProgrammingJSON.decodeUncheckedModel(from:Data(modelJSON.utf8)) { nonlinearProgrammingDraft=NonlinearProgrammingDraft(model) }
        if case .goalProgramming = sample, let model = try? GoalProgrammingJSON.decodeModel(from:Data(modelJSON.utf8)) { goalProgrammingDraft=GoalProgrammingDraft(model) }
        if case .facilityLocation = sample, let envelope = try? FacilitiesModelJSON.decodeUncheckedModel(from: Data(modelJSON.utf8)), case .location(let problem) = envelope { facilityLocationDraft = FacilityLocationDraft(problem) }
        if case .lineBalancing = sample, let envelope = try? FacilitiesModelJSON.decodeUncheckedModel(from: Data(modelJSON.utf8)), case .lineBalancing(let problem) = envelope { lineBalancingDraft = LineBalancingDraft(problem) }
        if case .facilityLayout = sample, let envelope = try? FacilitiesModelJSON.decodeUncheckedModel(from: Data(modelJSON.utf8)), case .layout(let problem) = envelope { facilityLayoutDraft = FacilityLayoutDraft(problem) }
        solutionJSON = ""
        validationJSON = ""
        validationDiagnostics = []
        modelSource = "Sample · \(sample.label)"
        lastResultLabel = nil
        status = "Loaded sample model"
        modelState = .editing
        runState = .notRun
        selectedPane = .overview
    }

    func importModel(from url: URL) {
        let hasSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let normalizedData: Data
            let importDescription: String
            do {
                try validateSupportedModel(data)
                normalizedData = data
                importDescription = url.lastPathComponent
            } catch let normalizedModelError {
                do {
                    let imported = try LegacyModelImporter.importModel(
                        from: data,
                        fileName: url.lastPathComponent
                    )
                    try validateSupportedModel(imported.normalizedJSON)
                    normalizedData = imported.normalizedJSON
                    importDescription = "\(url.lastPathComponent) as \(imported.family.rawValue)"
                } catch {
                    if url.pathExtension.lowercased() == "json" {
                        throw normalizedModelError
                    }
                    throw error
                }
            }
            modelJSON = String(decoding: normalizedData, as: UTF8.self)
            if let program = try? LinearProgramJSON.decodeProgram(from: normalizedData) {
                lpDraft = LinearProgrammingDraft(program: program)
            } else {
                lpDraft = nil
            }
            if let envelope = try? InventoryModelJSON.decodeUncheckedModel(from: normalizedData) {
                inventoryDraft = InventoryDraft(envelope)
            } else {
                inventoryDraft = nil
            }
            if let envelope = try? NetworkModelJSON.decodeModel(from: normalizedData) {
                networkDraft = NetworkDraft(envelope: envelope)
                networkFlowDraft = NetworkFlowDraft(envelope: envelope)
                assignmentDraft = AssignmentDraft(envelope: envelope)
                transportationDraft = TransportationDraft(envelope: envelope)
            } else {
                networkDraft = nil
                networkFlowDraft = nil
                assignmentDraft = nil
                transportationDraft = nil
            }
            if let request = try? ForecastingModelJSON.decodeRequest(from: normalizedData) {
                forecastingDraft = ForecastingDraft(request)
            } else {
                forecastingDraft = nil
            }
            if let request = try? MarkovJSON.decodeRequest(from: normalizedData) {
                markovDraft = MarkovDraft(request)
            } else {
                markovDraft = nil
            }
            if let envelope = try? QueuingModelJSON.decodeModel(from: normalizedData) {
                queuingDraft = QueuingDraft(envelope)
            } else {
                queuingDraft = nil
            }
            if let envelope = try? DecisionAnalysisModelJSON.decodeModel(from: normalizedData) {
                decisionDraft = DecisionAnalysisDraft(envelope)
                zeroSumGameDraft = ZeroSumGameDraft(envelope)
                decisionTreeDraft = DecisionTreeDraft(envelope)
            } else {
                decisionDraft = nil
                zeroSumGameDraft = nil
                decisionTreeDraft = nil
            }
            if let envelope = try? ProjectSchedulingJSON.decodeModel(from: normalizedData) {
                projectSchedulingDraft = ProjectSchedulingDraft(envelope)
            } else {
                projectSchedulingDraft = nil
                aggregatePlanningDraft = nil
                materialRequirementsPlanningDraft = nil
                simulationDraft = nil
                knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
            }
            if let model = try? AggregatePlanningJSON.decodeModel(from: normalizedData) {
                aggregatePlanningDraft = AggregatePlanningDraft(model)
            } else {
                aggregatePlanningDraft = nil
                materialRequirementsPlanningDraft = nil
                simulationDraft = nil
                knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
            }
            if let model = try? MaterialRequirementsPlanningJSON.decodeModel(from: normalizedData) {
                materialRequirementsPlanningDraft = MaterialRequirementsPlanningDraft(model)
            } else {
                materialRequirementsPlanningDraft = nil
                simulationDraft = nil
                knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
            }
            if let model = try? SimulationJSON.decodeUncheckedModel(from: normalizedData) {
                simulationDraft = SimulationDraft(model)
            } else {
                simulationDraft = nil
                knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
            }
            if let envelope = try? DynamicProgrammingModelJSON.decodeUncheckedModel(from: normalizedData),
               case .boundedKnapsack(let problem) = envelope {
                knapsackDraft = KnapsackDraft(problem)
            } else {
                knapsackDraft = nil
        acceptanceSamplingDraft = nil
        qualityControlDraft = nil
        quadraticProgrammingDraft = nil
        nonlinearProgrammingDraft = nil
        goalProgrammingDraft = nil
        facilityLocationDraft = nil
        lineBalancingDraft = nil
        facilityLayoutDraft = nil
            }
            acceptanceSamplingDraft = (try? AcceptanceSamplingJSON.decodeModel(from: normalizedData)).map(AcceptanceSamplingDraft.init)
            qualityControlDraft = (try? QualityControlJSON.decodeModel(from: normalizedData)).map(QualityControlDraft.init)
            quadraticProgrammingDraft = (try? QuadraticProgrammingJSON.decodeUncheckedModel(from: normalizedData)).map(QuadraticProgrammingDraft.init)
            nonlinearProgrammingDraft = (try? NonlinearProgrammingJSON.decodeUncheckedModel(from: normalizedData)).map(NonlinearProgrammingDraft.init)
        goalProgrammingDraft = (try? GoalProgrammingJSON.decodeModel(from: normalizedData)).map(GoalProgrammingDraft.init)
        if let envelope = try? FacilitiesModelJSON.decodeUncheckedModel(from: normalizedData), case .location(let problem) = envelope { facilityLocationDraft = FacilityLocationDraft(problem) }
        if let envelope = try? FacilitiesModelJSON.decodeUncheckedModel(from: normalizedData), case .lineBalancing(let problem) = envelope { lineBalancingDraft = LineBalancingDraft(problem) }
        if let envelope = try? FacilitiesModelJSON.decodeUncheckedModel(from: normalizedData), case .layout(let problem) = envelope { facilityLayoutDraft = FacilityLayoutDraft(problem) }
            solutionJSON = ""
            validationJSON = ""
            validationDiagnostics = []
            modelSource = importDescription
            modelState = .valid
            runState = .notRun
            lastErrorMessage = nil
            lastResultLabel = nil
            status = "Imported \(importDescription)"
            selectedPane = .overview
        } catch {
            modelState = .invalid
            runState = .notRun
            lastErrorMessage = Self.message(for: error)
            status = "Import failed: \(Self.message(for: error))"
            selectedPane = .validation
        }
    }

    func recordExportResult(_ result: Result<URL, Error>, label: String) {
        switch result {
        case .success(let url):
            status = "Exported \(label) to \(url.lastPathComponent)"
        case .failure(let error):
            status = "Export failed: \(Self.message(for: error))"
        }
    }

    func beginModelExport() {
        do {
            if lpDraft != nil {
                try syncLPDraftToJSON(currentLPProgram())
            } else if inventoryDraft != nil {
                try syncInventoryDraftToJSON(currentInventoryEnvelope())
            } else if networkDraft != nil || networkFlowDraft != nil || assignmentDraft != nil || transportationDraft != nil {
                try syncNetworkDraftToJSON(currentNetworkModel())
            } else if forecastingDraft != nil {
                try syncForecastingDraftToJSON(currentForecastingRequest())
            } else if markovDraft != nil {
                try syncMarkovDraftToJSON(currentMarkovRequest())
            } else if queuingDraft != nil {
                try syncQueuingDraftToJSON(currentQueuingEnvelope())
            } else if decisionDraft != nil || zeroSumGameDraft != nil || decisionTreeDraft != nil {
                try syncDecisionDraftToJSON(currentDecisionAnalysisEnvelope())
            } else if projectSchedulingDraft != nil {
                try syncProjectSchedulingDraftToJSON(currentProjectSchedulingModel())
            } else if aggregatePlanningDraft != nil {
                try syncAggregatePlanningDraftToJSON(currentAggregatePlanningModel())
            } else if materialRequirementsPlanningDraft != nil {
                try syncMaterialRequirementsPlanningDraftToJSON(currentMaterialRequirementsPlanningModel())
            } else if simulationDraft != nil {
                try syncSimulationDraftToJSON(currentSimulationModel())
            } else if knapsackDraft != nil {
                try syncKnapsackDraftToJSON(currentDynamicProgrammingModel())
            } else if acceptanceSamplingDraft != nil {
                try syncAcceptanceSamplingDraftToJSON(currentAcceptanceSamplingModel())
            } else if qualityControlDraft != nil {
                try syncQualityControlDraftToJSON(currentQualityControlModel())
            } else if quadraticProgrammingDraft != nil {
                try syncQuadraticProgrammingDraftToJSON(currentQuadraticProgrammingModel())
            } else if nonlinearProgrammingDraft != nil {
                try syncNonlinearProgrammingDraftToJSON(currentNonlinearProgrammingModel())
            } else if goalProgrammingDraft != nil {
                try syncGoalProgrammingDraftToJSON(currentGoalProgrammingModel())
            } else if facilityLocationDraft != nil || lineBalancingDraft != nil || facilityLayoutDraft != nil {
                try syncFacilitiesDraftToJSON(currentFacilitiesModel())
            }
            isExportingModel = true
        } catch {
            validateCurrentModel()
        }
    }

    private func validateSupportedModel(_ data: Data) throws {
        do {
            _ = try LinearProgramJSON.decodeProgram(from: data)
        } catch {
            do {
                _ = try NetworkModelJSON.decodeModel(from: data)
            } catch {
                do {
                    _ = try FacilitiesModelJSON.decodeModel(from: data)
                } catch {
                    do {
                        _ = try InventoryModelJSON.decodeModel(from: data)
                    } catch {
                        do {
                            _ = try DynamicProgrammingModelJSON.decodeModel(from: data)
                        } catch {
                            do {
                                _ = try ForecastingModelJSON.decodeRequest(from: data)
                            } catch {
                                do {
                                    _ = try DecisionAnalysisModelJSON.decodeModel(from: data)
                                } catch {
                                    do {
                                        _ = try SimulationJSON.decodeModel(from: data)
                                    } catch {
                                        try validateExtendedModel(data)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func validate(program: LinearProgram, source: String) throws {
        let report = ValidationReport(diagnostics: LinearProgramValidator.diagnostics(for: program))
        try showValidationReport(report, source: source)
    }

    private func currentLPProgram() throws -> LinearProgram {
        if let lpDraft {
            return try lpDraft.makeLinearProgram()
        }
        return try LinearProgramJSON.decodeProgram(from: Data(modelJSON.utf8))
    }

    private func currentInventoryEnvelope() throws -> InventoryModelEnvelope {
        if let inventoryDraft {
            return try inventoryDraft.makeModel()
        }
        return try InventoryModelJSON.decodeUncheckedModel(from: Data(modelJSON.utf8))
    }

    private func currentNetworkModel() throws -> NetworkModelEnvelope {
        if let networkFlowDraft { return .minimumCostFlow(try networkFlowDraft.makeModel()) }
        if let assignmentDraft { return .assignment(try assignmentDraft.makeModel()) }
        if let transportationDraft { return .transportation(try transportationDraft.makeModel()) }
        if let networkDraft {
            return try networkDraft.makeNetworkModel()
        }
        return try NetworkModelJSON.decodeModel(from: Data(modelJSON.utf8))
    }

    private func currentForecastingRequest() throws -> ForecastingRequest {
        if let forecastingDraft { return try forecastingDraft.makeRequest() }
        return try ForecastingModelJSON.decodeRequest(from: Data(modelJSON.utf8))
    }

    private func currentMarkovRequest() throws -> MarkovAnalysisRequest {
        if let markovDraft { return try markovDraft.makeRequest() }
        return try MarkovJSON.decodeRequest(from: Data(modelJSON.utf8))
    }

    private func currentQueuingEnvelope() throws -> QueuingModelEnvelope {
        if let queuingDraft { return try queuingDraft.makeModel() }
        return try QueuingModelJSON.decodeModel(from: Data(modelJSON.utf8))
    }

    private func currentDecisionAnalysisEnvelope() throws -> DecisionAnalysisModelEnvelope {
        if let decisionDraft { return try decisionDraft.makeModel() }
        if let zeroSumGameDraft { return try zeroSumGameDraft.makeModel() }
        if let decisionTreeDraft { return try decisionTreeDraft.makeModel() }
        return try DecisionAnalysisModelJSON.decodeModel(from: Data(modelJSON.utf8))
    }

    private func currentProjectSchedulingModel() throws -> ProjectSchedulingModelEnvelope {
        if let projectSchedulingDraft { return try projectSchedulingDraft.makeModel() }
        return try ProjectSchedulingJSON.decodeModel(from: Data(modelJSON.utf8))
    }

    private func currentAggregatePlanningModel() throws -> AggregatePlanningModel {
        if let aggregatePlanningDraft { return try aggregatePlanningDraft.makeModel() }
        return try AggregatePlanningJSON.decodeModel(from: Data(modelJSON.utf8))
    }

    private func currentMaterialRequirementsPlanningModel() throws -> MaterialRequirementsPlanningModel {
        if let materialRequirementsPlanningDraft { return try materialRequirementsPlanningDraft.makeModel() }
        return try MaterialRequirementsPlanningJSON.decodeModel(from: Data(modelJSON.utf8))
    }

    private func currentSimulationModel() throws -> SimulationModel {
        if let simulationDraft { return try simulationDraft.makeModel() }
        return try SimulationJSON.decodeUncheckedModel(from: Data(modelJSON.utf8))
    }

    private func currentDynamicProgrammingModel() throws -> DynamicProgrammingModelEnvelope {
        if let knapsackDraft { return .boundedKnapsack(try knapsackDraft.makeProblem()) }
        return try DynamicProgrammingModelJSON.decodeUncheckedModel(from: Data(modelJSON.utf8))
    }

    private func currentAcceptanceSamplingModel() throws -> AcceptanceSamplingModelEnvelope {
        if let acceptanceSamplingDraft { return try acceptanceSamplingDraft.makeModel() }
        return try AcceptanceSamplingJSON.decodeModel(from: Data(modelJSON.utf8))
    }

    private func currentQualityControlModel() throws -> QualityControlModelEnvelope {
        if let qualityControlDraft { return try qualityControlDraft.makeModel() }
        return try QualityControlJSON.decodeModel(from: Data(modelJSON.utf8))
    }

    private func currentFacilitiesModel() throws -> FacilitiesModelEnvelope {
        if let facilityLayoutDraft { return .layout(try facilityLayoutDraft.makeProblem()) }
        if let lineBalancingDraft { return .lineBalancing(try lineBalancingDraft.makeProblem()) }
        if let facilityLocationDraft { return .location(try facilityLocationDraft.makeProblem()) }
        return try FacilitiesModelJSON.decodeUncheckedModel(from: Data(modelJSON.utf8))
    }

    private func syncFacilitiesDraftToJSON(_ model: FacilitiesModelEnvelope) throws {
        guard facilityLocationDraft != nil || lineBalancingDraft != nil || facilityLayoutDraft != nil else { return }
        modelJSON = String(decoding: try FacilitiesModelJSON.encodeModel(model), as: UTF8.self)
    }

    private func currentGoalProgrammingModel() throws -> GoalProgram {
        if let goalProgrammingDraft { return try goalProgrammingDraft.makeModel() }
        return try GoalProgrammingJSON.decodeModel(from: Data(modelJSON.utf8))
    }

    private func syncGoalProgrammingDraftToJSON(_ model: GoalProgram) throws {
        guard goalProgrammingDraft != nil else { return }
        modelJSON = String(decoding: try GoalProgrammingJSON.encodeModel(model), as: UTF8.self)
    }

    private func currentNonlinearProgrammingModel() throws -> NonlinearProgram {
        if let nonlinearProgrammingDraft { return try nonlinearProgrammingDraft.makeModel() }
        return try NonlinearProgrammingJSON.decodeUncheckedModel(from: Data(modelJSON.utf8))
    }

    private func syncNonlinearProgrammingDraftToJSON(_ model: NonlinearProgram) throws {
        guard nonlinearProgrammingDraft != nil else { return }
        modelJSON = String(decoding: try NonlinearProgrammingJSON.encodeModel(model), as: UTF8.self)
    }

    private func currentQuadraticProgrammingModel() throws -> QuadraticProgram {
        if let quadraticProgrammingDraft { return try quadraticProgrammingDraft.makeModel() }
        return try QuadraticProgrammingJSON.decodeUncheckedModel(from: Data(modelJSON.utf8))
    }

    private func syncInventoryDraftToJSON(_ model: InventoryModelEnvelope) throws {
        guard inventoryDraft != nil else { return }
        modelJSON = String(decoding: try InventoryModelJSON.encodeModel(model), as: UTF8.self)
    }

    private func validateInventory(_ model: InventoryModelEnvelope, kind: InventoryProblemKind) throws {
        let report = ValidateOnlyInventoryBackend().validationReport(for: model)
        try syncInventoryDraftToJSON(model)
        try showInventoryValidationReport(report, kind: kind)
    }

    private func syncLPDraftToJSON(_ program: LinearProgram) throws {
        guard lpDraft != nil else { return }
        modelJSON = String(decoding: try LinearProgramJSON.encodeProgram(program), as: UTF8.self)
    }

    private func syncNetworkDraftToJSON(_ model: NetworkModelEnvelope) throws {
        guard networkDraft != nil || networkFlowDraft != nil || assignmentDraft != nil || transportationDraft != nil else { return }
        modelJSON = String(decoding: try NetworkModelJSON.encodeModel(model), as: UTF8.self)
    }

    private func syncForecastingDraftToJSON(_ request: ForecastingRequest) throws {
        guard forecastingDraft != nil else { return }
        modelJSON = String(decoding: try ForecastingModelJSON.encodeRequest(request), as: UTF8.self)
    }

    private func syncMarkovDraftToJSON(_ request: MarkovAnalysisRequest) throws {
        guard markovDraft != nil else { return }
        modelJSON = String(decoding: try MarkovJSON.encodeRequest(request), as: UTF8.self)
    }

    private func syncQueuingDraftToJSON(_ model: QueuingModelEnvelope) throws {
        guard queuingDraft != nil else { return }
        modelJSON = String(decoding: try QueuingModelJSON.encodeModel(model), as: UTF8.self)
    }

    private func syncDecisionDraftToJSON(_ model: DecisionAnalysisModelEnvelope) throws {
        guard decisionDraft != nil || zeroSumGameDraft != nil || decisionTreeDraft != nil else { return }
        modelJSON = String(decoding: try DecisionAnalysisModelJSON.encodeModel(model), as: UTF8.self)
    }

    private func syncProjectSchedulingDraftToJSON(_ model: ProjectSchedulingModelEnvelope) throws {
        guard projectSchedulingDraft != nil else { return }
        modelJSON = String(decoding: try ProjectSchedulingJSON.encodeModel(model), as: UTF8.self)
    }

    private func syncAggregatePlanningDraftToJSON(_ model: AggregatePlanningModel) throws {
        guard aggregatePlanningDraft != nil else { return }
        modelJSON = String(decoding: try AggregatePlanningJSON.encodeModel(model), as: UTF8.self)
    }

    private func syncMaterialRequirementsPlanningDraftToJSON(_ model: MaterialRequirementsPlanningModel) throws {
        guard materialRequirementsPlanningDraft != nil else { return }
        modelJSON = String(decoding: try MaterialRequirementsPlanningJSON.encodeModel(model), as: UTF8.self)
    }

    private func syncSimulationDraftToJSON(_ model: SimulationModel) throws {
        guard simulationDraft != nil else { return }
        modelJSON = String(decoding: try SimulationJSON.encodeModel(model), as: UTF8.self)
    }

    private func syncKnapsackDraftToJSON(_ model: DynamicProgrammingModelEnvelope) throws {
        guard knapsackDraft != nil else { return }
        modelJSON = String(decoding: try DynamicProgrammingModelJSON.encodeModel(model), as: UTF8.self)
    }

    private func syncAcceptanceSamplingDraftToJSON(_ model: AcceptanceSamplingModelEnvelope) throws {
        guard acceptanceSamplingDraft != nil else { return }
        modelJSON = String(decoding: try AcceptanceSamplingJSON.encodeModel(model), as: UTF8.self)
    }

    private func syncQualityControlDraftToJSON(_ model: QualityControlModelEnvelope) throws {
        guard qualityControlDraft != nil else { return }
        modelJSON = String(decoding: try QualityControlJSON.encodeModel(model), as: UTF8.self)
    }

    private func syncQuadraticProgrammingDraftToJSON(_ model:QuadraticProgram) throws {
        guard quadraticProgrammingDraft != nil else{return};modelJSON=String(decoding:try QuadraticProgrammingJSON.encodeModel(model),as:UTF8.self)
    }

    private func validateExtendedModel(_ data: Data) throws {
        if (try? QuadraticProgrammingJSON.decodeModel(from: data)) != nil { return }
        if (try? NonlinearProgrammingJSON.decodeModel(from: data)) != nil { return }
        if let request = try? MarkovJSON.decodeRequest(from: data) { try MarkovValidator.validate(request); return }
        if let model = try? GoalProgrammingJSON.decodeModel(from: data) { try GoalProgrammingValidator.validate(model); return }
        if let model = try? ProjectSchedulingJSON.decodeModel(from: data), ValidateOnlyProjectSchedulingBackend().validationReport(for: model).isValid { return }
        if let model = try? AcceptanceSamplingJSON.decodeModel(from: data), ValidateOnlyAcceptanceSamplingBackend().validationReport(for: model).isValid { return }
        if let model = try? QualityControlJSON.decodeModel(from: data), ValidateOnlyQualityControlBackend().validationReport(for: model).isValid { return }
        if let model = try? AggregatePlanningJSON.decodeModel(from: data), ValidateOnlyAggregatePlanningBackend().validationReport(for: model).isValid { return }
        if let model = try? MaterialRequirementsPlanningJSON.decodeModel(from: data), ValidateOnlyMaterialRequirementsPlanningBackend().validationReport(for: model).isValid { return }
        if let model = try? SchedulingModelJSON.decodeModel(from: data), ValidateOnlySchedulingBackend().validationReport(for: model).isValid { return }
        if let model = try? QueuingModelJSON.decodeModel(from: data), ValidateOnlyQueuingBackend().validationReport(for: model).isValid { return }
        throw CocoaError(.fileReadCorruptFile, userInfo: [NSLocalizedDescriptionKey: "Unsupported normalized model JSON"])
    }

    private func showValidationReport(_ report: ValidationReport, source: String) throws {
        let output = try Self.jsonEncoder.encode(report)
        validationJSON = String(decoding: output, as: UTF8.self)
        validationDiagnostics = report.diagnostics
        let errorCount = report.diagnostics.filter { $0.severity == .error }.count
        modelState = report.isValid ? .valid : .invalid
        runState = .notRun
        status = report.isValid
            ? "\(source) is valid"
            : "\(source) has \(errorCount) validation error(s)"
        lastResultLabel = "\(source) Validation"
        selectedPane = .validation
    }

    private func showFacilitiesValidationReport(
        _ report: ValidationReport,
        kind: FacilitiesProblemKind
    ) throws {
        let document = FacilitiesValidationDocument(
            kind: kind,
            backend: report.backend,
            diagnostics: report.diagnostics
        )
        let output = try FacilitiesModelJSON.encodeValidation(document)
        validationJSON = String(decoding: output, as: UTF8.self)
        validationDiagnostics = report.diagnostics
        let errorCount = report.diagnostics.filter { $0.severity == .error }.count
        modelState = report.isValid ? .valid : .invalid
        runState = .notRun
        status = report.isValid
            ? "\(kind.displayName) is valid"
            : "\(kind.displayName) has \(errorCount) validation error(s)"
        lastResultLabel = "\(kind.displayName) Validation"
        selectedPane = .validation
    }

    private func showNetworkValidationReport(_ report: ValidationReport, model: NetworkModelEnvelope) throws {
        let document = NetworkValidationDocument(kind: model.kind, backend: report.backend, diagnostics: report.diagnostics)
        let output = try NetworkModelJSON.encodeValidation(document)
        showDomainValidationOutput(output, report: report, name: model.kind.rawValue)
    }

    private static func networkDraftDiagnostics(_ error: NetworkDraftError, kind: NetworkDraftKind) -> [ValidationDiagnostic] {
        guard case .issues(let issues) = error else { return [] }
        return issues.map { issue in
            let code: String
            switch issue {
            case .emptyTitle: code = "network.draft.title.empty"
            case .emptyNodeName: code = "network.draft.node.name.empty"
            case .duplicateNodeName: code = "network.draft.node.name.duplicate"
            case .missingArcEndpoint: code = "network.draft.arc.endpoint.missing"
            case .danglingArcEndpoint: code = "network.draft.arc.endpoint.dangling"
            case .invalidArcCost: code = "network.draft.arc.cost.invalid"
            case .missingSource: code = "network.draft.source.missing"
            case .missingSink: code = "network.draft.sink.missing"
            case .sourceAndSinkMustDiffer: code = "network.draft.source-sink.distinct"
            }
            return ValidationDiagnostic(severity: .error, code: "network.\(kind.problemKind.rawValue).\(code)", message: issue.message)
        }
    }

    private func showInventoryValidationReport(_ report: ValidationReport, kind: InventoryProblemKind) throws {
        let document = InventoryValidationDocument(kind: kind, backend: report.backend, diagnostics: report.diagnostics)
        let output = try InventoryModelJSON.encodeValidation(document)
        showDomainValidationOutput(output, report: report, name: kind.displayName)
    }

    private func showDynamicProgrammingValidationReport(_ report: ValidationReport, kind: DynamicProgrammingProblemKind) throws {
        let document = DynamicProgrammingValidationDocument(kind: kind, backend: report.backend, diagnostics: report.diagnostics)
        let output = try DynamicProgrammingModelJSON.encodeValidation(document)
        showDomainValidationOutput(output, report: report, name: kind.displayName)
    }

    private func showForecastingValidationReport(_ report: ValidationReport, request: ForecastingRequest) throws {
        let document = ForecastingValidationDocument(
            method: request.method,
            backend: report.backend,
            diagnostics: report.diagnostics
        )
        let output = try ForecastingModelJSON.encodeValidation(document)
        showDomainValidationOutput(output, report: report, name: request.method.displayName)
    }

    private func showDecisionAnalysisValidationReport(_ report: ValidationReport, model: DecisionAnalysisModelEnvelope) throws {
        let document = DecisionAnalysisValidationDocument(kind: model.kind, backend: report.backend, diagnostics: report.diagnostics)
        let output = try DecisionAnalysisModelJSON.encodeValidation(document)
        showDomainValidationOutput(output, report: report, name: model.kind.displayName)
    }

    private func showSimulationValidationReport(_ report: ValidationReport, model: SimulationModel) throws {
        let output = try SimulationJSON.encodeValidation(SimulationValidationDocument(model: model, report: report))
        showDomainValidationOutput(output, report: report, name: "Simulation")
    }

    private func showQuadraticProgrammingValidationReport(_ report: ValidationReport) throws {
        let output = try QuadraticProgrammingJSON.encodeValidation(QuadraticProgramValidationDocument(backend: report.backend, diagnostics: report.diagnostics))
        showDomainValidationOutput(output, report: report, name: "Quadratic Programming")
    }

    private func showNonlinearProgrammingValidationReport(_ report: ValidationReport) throws {
        let output = try NonlinearProgrammingJSON.encodeValidation(NonlinearProgramValidationDocument(backend: report.backend, diagnostics: report.diagnostics))
        showDomainValidationOutput(output, report: report, name: "Nonlinear Programming")
    }

    private func showMarkovValidationReport(_ report: ValidationReport) throws {
        let output = try MarkovJSON.encodeValidation(MarkovValidationDocument(backend: report.backend, diagnostics: report.diagnostics))
        showDomainValidationOutput(output, report: report, name: "Markov Analysis")
    }

    private func showGoalProgrammingValidationReport(_ report: ValidationReport) throws {
        let output = try GoalProgrammingJSON.encodeValidation(GoalProgrammingValidationDocument(backend: report.backend, diagnostics: report.diagnostics))
        showDomainValidationOutput(output, report: report, name: "Goal Programming")
    }

    private func showProjectSchedulingValidationReport(_ report: ValidationReport, model: ProjectSchedulingModelEnvelope) throws {
        let output = try ProjectSchedulingJSON.encodeValidation(ProjectSchedulingValidationDocument(kind: model.kind, backend: report.backend, diagnostics: report.diagnostics))
        showDomainValidationOutput(output, report: report, name: model.kind.rawValue)
    }

    private func showAcceptanceSamplingValidationReport(_ report: ValidationReport, model: AcceptanceSamplingModelEnvelope) throws {
        let output = try AcceptanceSamplingJSON.encodeValidation(AcceptanceSamplingValidationDocument(kind: model.kind, backend: report.backend, diagnostics: report.diagnostics))
        showDomainValidationOutput(output, report: report, name: "Acceptance Sampling")
    }

    private func showQualityControlValidationReport(_ report: ValidationReport, model: QualityControlModelEnvelope) throws {
        let output = try QualityControlJSON.encodeValidation(QualityControlValidationDocument(kind: model.kind, backend: report.backend, diagnostics: report.diagnostics))
        showDomainValidationOutput(output, report: report, name: "Quality Control")
    }

    private func showAggregatePlanningValidationReport(_ report: ValidationReport) throws {
        let output = try AggregatePlanningJSON.encodeValidation(AggregatePlanningValidationDocument(backend: report.backend, diagnostics: report.diagnostics))
        showDomainValidationOutput(output, report: report, name: "Aggregate Planning")
    }

    private func showMaterialRequirementsPlanningValidationReport(_ report: ValidationReport) throws {
        let output = try MaterialRequirementsPlanningJSON.encodeValidation(MaterialRequirementsPlanningValidationDocument(backend: report.backend, diagnostics: report.diagnostics))
        showDomainValidationOutput(output, report: report, name: "Material Requirements Planning")
    }

    private func showSchedulingValidationReport(_ report: ValidationReport, model: SchedulingModelEnvelope) throws {
        let output = try SchedulingModelJSON.encodeValidation(SchedulingValidationDocument(kind: model.kind, backend: report.backend, diagnostics: report.diagnostics))
        showDomainValidationOutput(output, report: report, name: "Scheduling")
    }

    private func showQueuingValidationReport(_ report: ValidationReport, model: QueuingModelEnvelope) throws {
        let output = try QueuingModelJSON.encodeValidation(QueuingValidationDocument(kind: model.kind, backend: report.backend, diagnostics: report.diagnostics))
        showDomainValidationOutput(output, report: report, name: "Queuing")
    }

    private func showSolvedStatus(_ name: String, detail: String) {
        markSolved()
        status = "\(name) solved with \(selectedBackend.rawValue): \(detail)"
        lastResultLabel = "\(name) Solution"
        selectedPane = .solution
    }

    private func showDomainValidationOutput(_ output: Data, report: ValidationReport, name: String) {
        validationJSON = String(decoding: output, as: UTF8.self)
        validationDiagnostics = report.diagnostics
        let errorCount = report.diagnostics.filter { $0.severity == .error }.count
        modelState = report.isValid ? .valid : .invalid
        runState = .notRun
        status = report.isValid ? "\(name) is valid" : "\(name) has \(errorCount) validation error(s)"
        lastResultLabel = "\(name) Validation"
        selectedPane = .validation
    }

    private func showUnavailableExternalBackend() {
        solutionJSON = ""
        runState = .failed
        if isSimulationModel {
            lastErrorMessage = "External Simulation backend is unavailable; choose QSB Native or Validate only"
        } else if isFacilitiesModel || isDynamicProgrammingModel {
            lastErrorMessage = "External backend is unavailable for this model; choose QSB Native or Validate only"
        } else if isMaterialRequirementsPlanningModel {
            lastErrorMessage = "External MRP backend is unavailable; choose QSB Native or Validate only"
        } else if isProjectSchedulingModel {
            lastErrorMessage = "External Project Scheduling backend is unavailable; choose QSB Native or Validate only"
        } else if isNonlinearProgrammingModel || isQualityControlModel || isAcceptanceSamplingModel {
            lastErrorMessage = "External backend is unavailable for this model; choose QSB Native or Validate only"
        } else if isQuadraticProgrammingModel {
            lastErrorMessage = "External QP backend is unavailable; install HiGHS and expose it through QSB_HIGHS_PATH or PATH"
        } else {
            lastErrorMessage = "External solver is unavailable; install HiGHS and expose it through QSB_HIGHS_PATH or PATH"
        }
        status = lastErrorMessage ?? "External solver is unavailable"
        selectedPane = .run
    }

    private func showSolveError(_ error: Error) {
        solutionJSON = ""
        runState = .failed
        lastErrorMessage = Self.message(for: error)
        status = "Run failed: \(lastErrorMessage ?? "Unknown run failure")"
        selectedPane = .run
    }

    private func markSolved() {
        modelState = .valid
        runState = .solved
        lastErrorMessage = nil
        validationDiagnostics = []
        validationJSON = ""
        runNotes = ["Backend: \(runBackendLabel)"]
    }

    var currentModelFamily: WorkspaceModelFamily {
        if lpDraft != nil {
            return .linearProgramming
        }
        if let inventoryDraft {
            return .inventory(inventoryDraft.kind)
        }
        if networkDraft != nil || networkFlowDraft != nil || assignmentDraft != nil || transportationDraft != nil {
            return .network
        }
        if let forecastingDraft { return .forecasting(forecastingDraft.method) }
        if markovDraft != nil { return .markov }
        if let queuingDraft { return .queuing(queuingDraft.kind) }
        if let decisionDraft { return .decisionAnalysis(decisionDraft.kind) }
        if zeroSumGameDraft != nil { return .decisionAnalysis(.zeroSumGame) }
        if decisionTreeDraft != nil { return .decisionAnalysis(.decisionTree) }
        if let projectSchedulingDraft { return .projectScheduling(projectSchedulingDraft.kind) }
        if aggregatePlanningDraft != nil { return .aggregatePlanning }
        if materialRequirementsPlanningDraft != nil { return .materialRequirementsPlanning }
        if let simulationDraft { return .simulation(simulationDraft.representation) }
        if knapsackDraft != nil { return .dynamicProgramming(.boundedKnapsack) }
        if let acceptanceSamplingDraft { return .acceptanceSampling(acceptanceSamplingDraft.kind) }
        if let qualityControlDraft { return .qualityControl(qualityControlDraft.kind) }
        if facilityLayoutDraft != nil { return .facilities(.layout) }
        if lineBalancingDraft != nil { return .facilities(.lineBalancing) }
        if facilityLocationDraft != nil { return .facilities(.location) }
        if goalProgrammingDraft != nil { return .goalProgramming }
        if nonlinearProgrammingDraft != nil { return .nonlinearProgramming }
        if quadraticProgrammingDraft != nil { return .quadraticProgramming }
        let data = Data(modelJSON.utf8)
        if (try? LinearProgramJSON.decodeProgram(from: data)) != nil {
            return .linearProgramming
        }
        if (try? NetworkModelJSON.decodeModel(from: data)) != nil {
            return .network
        }
        if let envelope = try? FacilitiesModelJSON.decodeUncheckedModel(from: data) {
            return .facilities(envelope.kind)
        }
        if let envelope = try? InventoryModelJSON.decodeUncheckedModel(from: data) {
            return .inventory(envelope.kind)
        }
        if let envelope = try? DynamicProgrammingModelJSON.decodeUncheckedModel(from: data) {
            return .dynamicProgramming(envelope.kind)
        }
        if let request = try? ForecastingModelJSON.decodeRequest(from: data) {
            return .forecasting(request.method)
        }
        if let model = try? DecisionAnalysisModelJSON.decodeModel(from: data) {
            return .decisionAnalysis(model.kind)
        }
        if let model = try? SimulationJSON.decodeUncheckedModel(from: data) {
            return .simulation(model.representation)
        }
        if (try? QuadraticProgrammingJSON.decodeUncheckedModel(from: data)) != nil { return .quadraticProgramming }
        if (try? NonlinearProgrammingJSON.decodeUncheckedModel(from: data)) != nil { return .nonlinearProgramming }
        if (try? MarkovJSON.decodeRequest(from: data)) != nil { return .markov }
        if (try? GoalProgrammingJSON.decodeModel(from: data)) != nil { return .goalProgramming }
        if let model = try? ProjectSchedulingJSON.decodeModel(from: data) { return .projectScheduling(model.kind) }
        if let model = try? AcceptanceSamplingJSON.decodeModel(from: data) { return .acceptanceSampling(model.kind) }
        if let model = try? QualityControlJSON.decodeModel(from: data) { return .qualityControl(model.kind) }
        if (try? AggregatePlanningJSON.decodeModel(from: data)) != nil { return .aggregatePlanning }
        if (try? MaterialRequirementsPlanningJSON.decodeModel(from: data)) != nil { return .materialRequirementsPlanning }
        if let model = try? SchedulingModelJSON.decodeModel(from: data) { return .scheduling(model.kind) }
        if let model = try? QueuingModelJSON.decodeModel(from: data) { return .queuing(model.kind) }
        return .unknown
    }

    var hasModel: Bool {
        lpDraft != nil || inventoryDraft != nil || networkDraft != nil || networkFlowDraft != nil || assignmentDraft != nil || transportationDraft != nil || forecastingDraft != nil || markovDraft != nil || queuingDraft != nil || decisionDraft != nil || zeroSumGameDraft != nil || decisionTreeDraft != nil || projectSchedulingDraft != nil || aggregatePlanningDraft != nil || materialRequirementsPlanningDraft != nil || simulationDraft != nil || knapsackDraft != nil || acceptanceSamplingDraft != nil || qualityControlDraft != nil || quadraticProgrammingDraft != nil || nonlinearProgrammingDraft != nil || goalProgrammingDraft != nil || facilityLocationDraft != nil || lineBalancingDraft != nil || facilityLayoutDraft != nil || !modelJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasSolution: Bool {
        !solutionJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var modelTitle: String {
        if let title = lpDraft?.title.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        if let inventoryDraft {
            switch inventoryDraft {
            case .eoq(let draft): return draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? currentModelFamily.displayName : draft.title
            case .quantityDiscount(let draft): return draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? currentModelFamily.displayName : draft.title
            case .newsboy(let draft): return draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? currentModelFamily.displayName : draft.title
            case .lotSizing(let draft): return draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? currentModelFamily.displayName : draft.title
            case .stochasticReview(let model): return model.title
            }
        }
        if let forecastingDraft, !forecastingDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return forecastingDraft.title
        }
        if let networkDraft, !networkDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return networkDraft.title
        }
        if let networkFlowDraft, !networkFlowDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return networkFlowDraft.title
        }
        if let assignmentDraft, !assignmentDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return assignmentDraft.title
        }
        if let transportationDraft, !transportationDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return transportationDraft.title
        }
        if let markovDraft, !markovDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return markovDraft.title
        }
        if let queuingDraft {
            let title: String
            switch queuingDraft {
            case .mm1(let draft): title = draft.title
            case .finiteCapacity(let draft): title = draft.title
            }
            if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return title }
        }
        if let decisionDraft, !decisionDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return decisionDraft.title
        }
        if let zeroSumGameDraft, !zeroSumGameDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return zeroSumGameDraft.title
        }
        if let decisionTreeDraft, !decisionTreeDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return decisionTreeDraft.title
        }
        if let projectSchedulingDraft, !projectSchedulingDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return projectSchedulingDraft.title
        }
        if let aggregatePlanningDraft, !aggregatePlanningDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return aggregatePlanningDraft.title
        }
        if let materialRequirementsPlanningDraft, !materialRequirementsPlanningDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return materialRequirementsPlanningDraft.title
        }
        if let simulationDraft, !simulationDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return simulationDraft.title
        }
        if let knapsackDraft, !knapsackDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return knapsackDraft.title
        }
        if let acceptanceSamplingDraft, !acceptanceSamplingDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return acceptanceSamplingDraft.title
        }
        if let qualityControlDraft, !qualityControlDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return qualityControlDraft.title
        }
        if let facilityLayoutDraft, !facilityLayoutDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return facilityLayoutDraft.title }
        if let lineBalancingDraft, !lineBalancingDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return lineBalancingDraft.title }
        if let facilityLocationDraft, !facilityLocationDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return facilityLocationDraft.title }
        if let goalProgrammingDraft, !goalProgrammingDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return goalProgrammingDraft.title }
        if let nonlinearProgrammingDraft, !nonlinearProgrammingDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nonlinearProgrammingDraft.title }
        if let quadraticProgrammingDraft, !quadraticProgrammingDraft.title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty { return quadraticProgrammingDraft.title }
        return hasModel ? currentModelFamily.displayName : "No model open"
    }

    var validationSummary: String {
        switch modelState {
        case .empty: "No model to validate"
        case .editing: "Draft requires validation"
        case .validating: "Validation in progress"
        case .invalid: "\(validationDiagnostics.count) diagnostic(s) require attention"
        case .valid: "Model is valid"
        }
    }

    var runBackendLabel: String {
        switch selectedBackend {
        case .nativeEducational: "QSB Native"
        case .validateOnly: "Validate only"
        case .externalHighPerformance: "External solver"
        }
    }

    var externalBackendSummary: String {
        if isNonlinearProgrammingModel || isQualityControlModel || isAcceptanceSamplingModel {
            return "This model has no external solver integration. Choose QSB Native to run or Validate only to check the model."
        }
        if isFacilitiesModel || isDynamicProgrammingModel {
            return "This model has no external solver integration. Choose QSB Native to run or Validate only to check the model."
        }
        if isMaterialRequirementsPlanningModel {
            return "MRP has no external solver integration. Choose QSB Native to run or Validate only to check the model."
        }
        if isProjectSchedulingModel {
            return "Project Scheduling has no external solver integration. Choose QSB Native to run or Validate only to check the model."
        }
        if isSimulationModel {
            return "Simulation has no external solver integration. Choose QSB Native to run or Validate only to check the model."
        }
        let supportsExternalFamily: Bool
        switch currentModelFamily {
        case .linearProgramming, .network, .goalProgramming, .aggregatePlanning, .quadraticProgramming:
            supportsExternalFamily = true
        default:
            supportsExternalFamily = false
        }
        guard supportsExternalFamily else {
            return "HiGHS external solving is available for LP/ILP, CNF/TP, aggregate planning, goal programming, and supported continuous QP."
        }
        if HiGHSLinearProgrammingBackend.discovered() != nil {
            return "HiGHS detected through QSB_HIGHS_PATH or PATH."
        }
        return "Install HiGHS and expose it through QSB_HIGHS_PATH or PATH."
    }

    var statusSystemImage: String {
        if runState == .solving { return "hourglass" }
        if runState == .failed || modelState == .invalid { return "exclamationmark.octagon" }
        if runState == .solved { return "checkmark.circle" }
        if modelState == .valid { return "checkmark.seal" }
        if modelState == .editing { return "pencil" }
        return "circle.dashed"
    }

    var statusColor: Color {
        if runState == .failed || modelState == .invalid { return .red }
        if runState == .solved || modelState == .valid { return .green }
        return .secondary
    }

    var isFacilityLayoutModel: Bool {
        guard case .facilities(.layout) = currentModelFamily else {
            return false
        }
        return true
    }

    var isLinearProgrammingModel: Bool {
        if lpDraft != nil { return true }
        guard case .linearProgramming = currentModelFamily else {
            return false
        }
        return true
    }

    var isNetworkModel: Bool {
        if networkDraft != nil || networkFlowDraft != nil || assignmentDraft != nil || transportationDraft != nil { return true }
        guard case .network = currentModelFamily else {
            return false
        }
        return true
    }

    var isQualityControlModel: Bool { if case .qualityControl = currentModelFamily { true } else { false } }

    var isAcceptanceSamplingModel: Bool { if case .acceptanceSampling = currentModelFamily { true } else { false } }

    var isFacilitiesModel: Bool {
        guard case .facilities = currentModelFamily else {
            return false
        }
        return true
    }

    var isInventoryModel: Bool {
        guard case .inventory = currentModelFamily else { return false }
        return true
    }

    var inventoryStochasticDraft: InventoryStochasticDraft? {
        guard case .stochasticReview(let draft) = inventoryDraft else { return nil }
        return draft
    }

    var isDynamicProgrammingModel: Bool {
        guard case .dynamicProgramming = currentModelFamily else { return false }
        return true
    }

    var isForecastingModel: Bool {
        guard case .forecasting = currentModelFamily else { return false }
        return true
    }

    var isDecisionAnalysisModel: Bool {
        guard case .decisionAnalysis = currentModelFamily else { return false }
        return true
    }

    var isAggregatePlanningModel: Bool {
        if case .aggregatePlanning = currentModelFamily { true } else { false }
    }

    var isMaterialRequirementsPlanningModel: Bool {
        if case .materialRequirementsPlanning = currentModelFamily { true } else { false }
    }

    var isProjectSchedulingModel: Bool {
        if case .projectScheduling = currentModelFamily { true } else { false }
    }

    var isSimulationModel: Bool {
        guard case .simulation = currentModelFamily else { return false }
        return true
    }

    var isQuadraticProgrammingModel: Bool { if case .quadraticProgramming = currentModelFamily { true } else { false } }
    var isNonlinearProgrammingModel: Bool { if case .nonlinearProgramming = currentModelFamily { true } else { false } }
    var isMarkovModel: Bool { if case .markov = currentModelFamily { true } else { false } }
    var isGoalProgrammingModel: Bool { if case .goalProgramming = currentModelFamily { true } else { false } }

    var canSolveCurrentModel: Bool {
        switch currentModelFamily {
        case .unknown: false
        default: hasModel && modelState != .invalid && runState != .solving
        }
    }

    var solutionSubtitle: String {
        lastResultLabel ?? "No solve or validation has run"
    }

    var schedulingSolution: SchedulingSolutionDocument? {
        try? SchedulingModelJSON.decodeSolution(from: Data(solutionJSON.utf8))
    }

    var linearProgramSolution: LinearProgramSolution? {
        try? JSONDecoder().decode(LinearProgramSolution.self, from: Data(solutionJSON.utf8))
    }

    var linearProgramForPresentation: LinearProgram? {
        try? currentLPProgram()
    }

    var networkSolution: NetworkSolutionDocument? {
        try? NetworkModelJSON.decodeSolutionDocument(from: Data(solutionJSON.utf8))
    }

    var forecastingSolution: ForecastingSolutionDocument? {
        try? ForecastingModelJSON.decodeSolutionDocument(from: Data(solutionJSON.utf8))
    }

    var inventorySolution: InventorySolutionDocument? {
        try? InventoryModelJSON.decodeSolutionDocument(from: Data(solutionJSON.utf8))
    }

    var dynamicProgrammingSolution: DynamicProgrammingSolutionDocument? {
        try? DynamicProgrammingModelJSON.decodeSolutionDocument(
            from: Data(solutionJSON.utf8)
        )
    }

    var decisionAnalysisSolution: DecisionAnalysisSolutionDocument? {
        try? DecisionAnalysisModelJSON.decodeSolutionDocument(
            from: Data(solutionJSON.utf8)
        )
    }

    var queuingSolution: QueuingSolutionDocument? {
        try? QueuingModelJSON.decodeSolution(from: Data(solutionJSON.utf8))
    }

    var markovSolution: MarkovSolutionDocument? {
        try? MarkovJSON.decodeSolution(from: Data(solutionJSON.utf8))
    }

    var goalProgrammingSolution: GoalProgrammingSolutionDocument? {
        try? GoalProgrammingJSON.decodeSolution(from: Data(solutionJSON.utf8))
    }

    var aggregatePlanningSolution: AggregatePlanningSolutionDocument? {
        try? AggregatePlanningJSON.decodeSolution(from: Data(solutionJSON.utf8))
    }

    var materialRequirementsPlanningSolution: MaterialRequirementsPlanningSolutionDocument? {
        try? MaterialRequirementsPlanningJSON.decodeSolution(from: Data(solutionJSON.utf8))
    }

    var acceptanceSamplingSolution: AcceptanceSamplingSolutionDocument? {
        try? AcceptanceSamplingJSON.decodeSolution(from: Data(solutionJSON.utf8))
    }

    var qualityControlSolution: QualityControlSolutionDocument? {
        try? QualityControlJSON.decodeSolution(from: Data(solutionJSON.utf8))
    }

    var quadraticProgrammingSolution: QuadraticProgramSolutionDocument? {
        try? QuadraticProgrammingJSON.decodeSolution(from: Data(solutionJSON.utf8))
    }

    var nonlinearProgrammingSolution: NonlinearProgramSolutionDocument? {
        try? NonlinearProgrammingJSON.decodeSolution(from: Data(solutionJSON.utf8))
    }

    var projectSchedulingSolution: ProjectSchedulingSolutionDocument? {
        try? ProjectSchedulingJSON.decodeSolution(from: Data(solutionJSON.utf8))
    }

    var simulationSolution: SimulationSolutionDocument? {
        try? SimulationJSON.decodeSolution(from: Data(solutionJSON.utf8))
    }

    var facilityLocationPresentation: FacilityLocationPresentation? {
        guard
            let document = try? FacilitiesModelJSON.decodeSolutionDocument(from: Data(solutionJSON.utf8)),
            case .location = document.solution,
            let model = try? FacilitiesModelJSON.decodeUncheckedModel(from: Data(modelJSON.utf8)),
            case .location(let problem) = model
        else { return nil }
        return FacilityLocationPresentation(document: document, problem: problem)
    }

    var lineBalancingPresentation: LineBalancingPresentation? {
        guard
            let document = try? FacilitiesModelJSON.decodeSolutionDocument(from: Data(solutionJSON.utf8)),
            case .lineBalancing = document.solution,
            let model = try? FacilitiesModelJSON.decodeUncheckedModel(from: Data(modelJSON.utf8)),
            case .lineBalancing(let problem) = model
        else { return nil }
        return LineBalancingPresentation(document: document, problem: problem)
    }

    var facilityLayoutPresentation: FacilityLayoutPresentation? {
        guard
            let document = try? FacilitiesModelJSON.decodeSolutionDocument(
                from: Data(solutionJSON.utf8)
            ),
            case .layout = document.solution,
            let model = try? FacilitiesModelJSON.decodeUncheckedModel(
                from: Data(modelJSON.utf8)
            ),
            case .layout(let problem) = model
        else {
            return nil
        }

        return FacilityLayoutPresentation(document: document, problem: problem)
    }

    var modelDocument: JSONTextDocument {
        JSONTextDocument(text: modelJSON)
    }

    var solutionDocument: JSONTextDocument {
        JSONTextDocument(text: solutionJSON.isEmpty ? "{}" : solutionJSON)
    }

    private func format(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 1e-8 {
            return String(Int(rounded))
        }
        return String(format: "%.6f", value)
    }

    private static func message(for error: Error) -> String {
        switch error {
        case let error as LinearProgramError:
            return error.description
        case let error as NetworkModelError:
            return error.description
        case let error as FacilitiesModelError:
            return error.description
        case let error as InventoryModelError:
            return error.description
        case let error as DynamicProgrammingModelError:
            return error.description
        case let error as ForecastingModelError:
            return error.description
        case let error as DecisionAnalysisModelError:
            return error.description
        case let error as SimulationError:
            return error.description
        case let error as QuadraticProgrammingError:
            return error.description
        case let error as NonlinearProgrammingError:
            return error.description
        case let error as MarkovModelError:
            return error.description
        case let error as GoalProgrammingError:
            return error.description
        case let error as ProjectSchedulingError:
            return error.description
        case let error as AcceptanceSamplingError:
            return error.description
        case let error as QualityControlError:
            return error.description
        case let error as AggregatePlanningError:
            return error.description
        case let error as MaterialRequirementsPlanningError:
            return error.description
        case let error as SchedulingModelError:
            return error.description
        case let error as QueuingModelError:
            return error.description
        case let error as DecodingError:
            return "Invalid JSON model: \(error)"
        default:
            return String(describing: error)
        }
    }

    private static var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension FacilitiesProblemKind {
    var displayName: String {
        switch self {
        case .lineBalancing:
            "Line Balancing"
        case .location:
            "Facility Location"
        case .layout:
            "Facility Layout"
        }
    }
}

private extension FacilitiesSolutionEnvelope {
    func summary(format: (Double) -> String) -> String {
        switch self {
        case .lineBalancing(let solution):
            "\(solution.stationCount) stations, efficiency \(format(solution.efficiency))"
        case .location(let solution):
            "objective \(format(solution.objectiveValue))"
        case .layout(let solution):
            if let search = solution.search {
                "objective \(format(solution.objectiveValue)), improvement \(format(search.improvement))"
            } else {
                "objective \(format(solution.objectiveValue))"
            }
        }
    }
}

private extension NetworkSolutionEnvelope {
    func summary(format: (Double) -> String) -> String {
        switch self {
        case .minimumCostFlow(let solution):
            return "cost \(format(solution.totalCost))"
        case .shortestPath(let solution):
            return "cost \(format(solution.totalCost))"
        case .minimumSpanningTree(let solution):
            return "cost \(format(solution.totalCost))"
        case .maxFlow(let solution):
            return "flow \(format(solution.maxFlow))"
        case .travelingSalesperson(let solution):
            return "cost \(format(solution.totalCost))"
        case .assignment(let solution):
            return "cost \(format(solution.totalCost))"
        case .transportation(let solution):
            return "cost \(format(solution.totalCost))"
        }
    }
}
