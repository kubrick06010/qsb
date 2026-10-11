import AppKit
import QSBCore
import SwiftUI
import Testing
@testable import QSBMacApp

@MainActor
@Test("render compact and wide UI layouts")
func renderCompactAndWideUILayouts() throws {
    let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(".build/ui-audit", isDirectory: true)
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    try renderEditor(
        named: "decision-tree-editor",
        workspace: workspace(sample: .decisionTree),
        view: { DecisionTreeEditorView(workspace: $0) },
        outputDirectory: outputDirectory
    )

    try renderEditor(
        named: "linear-programming-editor",
        workspace: workspace(sample: .linearProgram),
        view: { LinearProgrammingEditorView(workspace: $0) },
        outputDirectory: outputDirectory
    )

    let assignmentWorkspace = QSBWorkspace()
    assignmentWorkspace.startNewAssignment()
    try renderEditor(
        named: "assignment-editor",
        workspace: assignmentWorkspace,
        view: { AssignmentEditorView(workspace: $0) },
        outputDirectory: outputDirectory
    )

    let transportationWorkspace = QSBWorkspace()
    transportationWorkspace.startNewTransportation()
    try renderEditor(
        named: "transportation-editor",
        workspace: transportationWorkspace,
        view: { TransportationEditorView(workspace: $0) },
        outputDirectory: outputDirectory
    )

    let lotSizingWorkspace = QSBWorkspace()
    lotSizingWorkspace.startNewInventory(.lotSizing)
    try renderEditor(
        named: "lot-sizing-editor",
        workspace: lotSizingWorkspace,
        view: { InventoryEditorView(workspace: $0) },
        outputDirectory: outputDirectory
    )

    try renderEditor(
        named: "markov-editor",
        workspace: workspace(sample: .markov),
        view: { MarkovEditorView(workspace: $0) },
        outputDirectory: outputDirectory
    )

    try renderEditor(
        named: "payoff-editor",
        workspace: workspace(sample: .payoffAnalysis),
        view: { DecisionAnalysisEditorView(workspace: $0) },
        outputDirectory: outputDirectory
    )

    let bayesianWorkspace = QSBWorkspace()
    bayesianWorkspace.startNewDecisionAnalysis(.bayesian)
    try renderEditor(
        named: "bayesian-editor",
        workspace: bayesianWorkspace,
        view: { DecisionAnalysisEditorView(workspace: $0) },
        outputDirectory: outputDirectory
    )

    let zeroSumWorkspace = QSBWorkspace()
    zeroSumWorkspace.startNewDecisionAnalysis(.zeroSumGame)
    try renderEditor(
        named: "zero-sum-editor",
        workspace: zeroSumWorkspace,
        view: { ZeroSumGameEditorView(workspace: $0) },
        outputDirectory: outputDirectory
    )

    let finiteQueueWorkspace = QSBWorkspace()
    finiteQueueWorkspace.startNewQueuing(.finiteCapacity)
    try renderEditor(
        named: "finite-queue-editor",
        workspace: finiteQueueWorkspace,
        view: { QueuingEditorView(workspace: $0) },
        outputDirectory: outputDirectory
    )

    try renderEditor(
        named: "mm1-queue-editor",
        workspace: workspace(sample: .mm1Queue),
        view: { QueuingEditorView(workspace: $0) },
        outputDirectory: outputDirectory
    )

    try renderEditor(
        named: "goal-programming-guided-editor",
        workspace: workspace(sample: .goalProgramming),
        view: { ModelEditorView(workspace: $0) },
        outputDirectory: outputDirectory
    )

    try renderEditor(
        named: "quadratic-programming-guided-editor",
        workspace: workspace(sample: .quadraticProgramming),
        view: { ModelEditorView(workspace: $0) },
        outputDirectory: outputDirectory
    )

    try renderEditor(
        named: "simulation-editor",
        workspace: workspace(sample: .simulation),
        view: { SimulationEditorView(workspace: $0) },
        outputDirectory: outputDirectory
    )

    let runningSimulation = workspace(sample: .simulation)
    runningSimulation.beginSolving()
    runningSimulation.status = "Running Simulation with nativeEducational…"
    try renderEditor(named: "simulation-solving", workspace: runningSimulation,
        view: { modelWorkspace in VStack(spacing: 0) {
            SimulationEditorView(workspace: modelWorkspace)
            StatusBar(workspace: modelWorkspace)
        } }, outputDirectory: outputDirectory)
    let failedSimulation = workspace(sample: .simulation)
    failedSimulation.selectedBackend = .externalHighPerformance
    failedSimulation.solveSimulation()
    try renderEditor(named: "simulation-failed", workspace: failedSimulation,
        view: { RunConfigurationView(workspace: $0) }, outputDirectory: outputDirectory)

    try renderEditor(
        named: "simulation-routes",
        workspace: workspace(sample: .simulation),
        view: { SimulationEditorView(workspace: $0, initialSection: .routes) },
        outputDirectory: outputDirectory
    )

    try renderEditor(
        named: "simulation-service-rules",
        workspace: workspace(sample: .simulation),
        view: { SimulationEditorView(workspace: $0, initialSection: .serviceRules) },
        outputDirectory: outputDirectory
    )

    try renderEditor(
        named: "bounded-knapsack-editor",
        workspace: workspace(sample: .boundedKnapsack),
        view: { KnapsackEditorView(workspace: $0) },
        outputDirectory: outputDirectory
    )

    try renderEditor(
        named: "acceptance-sampling-editor",
        workspace: workspace(sample: .acceptanceSampling),
        view: { AcceptanceSamplingEditorView(workspace: $0) },
        outputDirectory: outputDirectory
    )

    try renderEditor(
        named: "quality-control-editor",
        workspace: workspace(sample: .qualityControl),
        view: { QualityControlEditorView(workspace: $0) },
        outputDirectory: outputDirectory
    )

    let layoutWorkspace = workspace(sample: .facilityLayout)
    try renderEditor(named: "facility-layout-editor", workspace: layoutWorkspace,
        view: { FacilityLayoutEditorView(workspace: $0) }, outputDirectory: outputDirectory)
    try renderEditor(named: "facility-layout-rectangles", workspace: layoutWorkspace,
        view: { FacilityLayoutEditorView(workspace: $0, initialSection: .rectangles) }, outputDirectory: outputDirectory)
    try renderEditor(named: "facility-layout-costs", workspace: layoutWorkspace,
        view: { FacilityLayoutEditorView(workspace: $0, initialSection: .costs) }, outputDirectory: outputDirectory)
    if var invalidLayoutDraft = layoutWorkspace.facilityLayoutDraft {
        invalidLayoutDraft.departments[0].rectangles[0].startRow = "invalid"
        layoutWorkspace.replaceFacilityLayoutDraft(invalidLayoutDraft)
        layoutWorkspace.validateCurrentModel()
        try renderEditor(named: "facility-layout-invalid", workspace: layoutWorkspace,
            view: { FacilityLayoutEditorView(workspace: $0, initialSection: .rectangles) }, outputDirectory: outputDirectory)
    }

    let largeGrid = FacilityLayoutProblem(title: "Large layout overview", rowCount: 1_000_000_000,
        columnCount: 1_000_000_000, objective: "MIN", departments: [
            FacilityLayoutDepartment(id: Int.min, name: "Large department", fixed: false,
                flowUnitCosts: [nil], initialLayout: [
                    FacilityLayoutRect(startRow: 1, startColumn: 1, endRow: 1_000_000_000, endColumn: 1_000_000_000)
                ])
        ])
    let largeSolution = try FacilityLayoutSolver.solve(largeGrid)
    let largePresentation = FacilityLayoutPresentation(document: FacilitiesSolutionDocument(
        backend: SolverRunMetadata(backendKind: .nativeEducational, algorithm: "initialLayoutEvaluation", exactness: .closedForm),
        solution: .layout(largeSolution)), problem: largeGrid)
    try renderEditor(named: "facility-layout-large-solution", workspace: layoutWorkspace,
        view: { _ in FacilityLayoutSolutionView(presentation: largePresentation) }, outputDirectory: outputDirectory)

    let lineWorkspace = workspace(sample: .lineBalancing)
    var invalidLineDraft = try #require(lineWorkspace.lineBalancingDraft)
    invalidLineDraft.cycleTime = "unfinished"
    let invalidLineWorkspace = workspace(sample: .lineBalancing)
    invalidLineWorkspace.replaceLineBalancingDraft(invalidLineDraft)
    try renderEditor(named: "line-independent-repair-invalid", workspace: invalidLineWorkspace,
        view: { LineBalancingEditorView(workspace: $0) }, outputDirectory: outputDirectory)

    let runningKnapsack = workspace(sample: .boundedKnapsack)
    runningKnapsack.beginSolving()
    runningKnapsack.status = "Running knapsack with nativeEducational…"
    try renderEditor(named: "knapsack-solving", workspace: runningKnapsack,
        view: { modelWorkspace in VStack(spacing: 0) {
            KnapsackEditorView(workspace: modelWorkspace)
            StatusBar(workspace: modelWorkspace)
        } }, outputDirectory: outputDirectory)
    let runningLine = workspace(sample: .lineBalancing)
    runningLine.beginSolving()
    runningLine.status = "Running line with nativeEducational…"
    try renderEditor(named: "line-solving", workspace: runningLine,
        view: { modelWorkspace in VStack(spacing: 0) {
            LineBalancingEditorView(workspace: modelWorkspace)
            StatusBar(workspace: modelWorkspace)
        } }, outputDirectory: outputDirectory)
    let runningLocation = workspace(sample: .facilityLocation)
    runningLocation.beginSolving()
    runningLocation.status = "Running location with nativeEducational…"
    try renderEditor(named: "location-solving", workspace: runningLocation,
        view: { modelWorkspace in VStack(spacing: 0) {
            FacilityLocationEditorView(workspace: modelWorkspace)
            StatusBar(workspace: modelWorkspace)
        } }, outputDirectory: outputDirectory)
    let runningLayout = workspace(sample: .facilityLayout)
    runningLayout.beginSolving()
    runningLayout.status = "Running layout with nativeEducational…"
    try renderEditor(named: "layout-solving", workspace: runningLayout,
        view: { modelWorkspace in VStack(spacing: 0) {
            FacilityLayoutEditorView(workspace: modelWorkspace)
            StatusBar(workspace: modelWorkspace)
        } }, outputDirectory: outputDirectory)

    let runningQuadratic = workspace(sample: .quadraticProgramming)
    runningQuadratic.beginSolving()
    runningQuadratic.status = "Running quadratic with nativeEducational…"
    try renderEditor(named: "quadratic-solving", workspace: runningQuadratic,
        view: { modelWorkspace in VStack(spacing: 0) {
            QuadraticProgrammingEditorView(workspace: modelWorkspace)
            StatusBar(workspace: modelWorkspace)
        } }, outputDirectory: outputDirectory)
    let runningNonlinear = workspace(sample: .nonlinearProgramming)
    runningNonlinear.beginSolving()
    runningNonlinear.status = "Running nonlinear with nativeEducational…"
    try renderEditor(named: "nonlinear-solving", workspace: runningNonlinear,
        view: { modelWorkspace in VStack(spacing: 0) {
            NonlinearProgrammingEditorView(workspace: modelWorkspace)
            StatusBar(workspace: modelWorkspace)
        } }, outputDirectory: outputDirectory)
    let runningGoal = workspace(sample: .goalProgramming)
    runningGoal.beginSolving()
    runningGoal.status = "Running goal with nativeEducational…"
    try renderEditor(named: "goal-solving", workspace: runningGoal,
        view: { modelWorkspace in VStack(spacing: 0) {
            GoalProgrammingEditorView(workspace: modelWorkspace)
            StatusBar(workspace: modelWorkspace)
        } }, outputDirectory: outputDirectory)
    let runningAcceptance = workspace(sample: .acceptanceSampling)
    runningAcceptance.beginSolving()
    runningAcceptance.status = "Running acceptance with nativeEducational…"
    try renderEditor(named: "acceptance-solving", workspace: runningAcceptance,
        view: { modelWorkspace in VStack(spacing: 0) {
            AcceptanceSamplingEditorView(workspace: modelWorkspace)
            StatusBar(workspace: modelWorkspace)
        } }, outputDirectory: outputDirectory)
    let runningQuality = workspace(sample: .qualityControl)
    runningQuality.beginSolving()
    runningQuality.status = "Running quality with nativeEducational…"
    try renderEditor(named: "quality-solving", workspace: runningQuality,
        view: { modelWorkspace in VStack(spacing: 0) {
            QualityControlEditorView(workspace: modelWorkspace)
            StatusBar(workspace: modelWorkspace)
        } }, outputDirectory: outputDirectory)

    let invalidKnapsackWorkspace = workspace(sample: .boundedKnapsack)
    var invalidKnapsackDraft = try #require(invalidKnapsackWorkspace.knapsackDraft)
    invalidKnapsackDraft.capacity = "unfinished"
    invalidKnapsackWorkspace.replaceKnapsackDraft(invalidKnapsackDraft)
    try renderEditor(named: "knapsack-independent-repair-invalid", workspace: invalidKnapsackWorkspace,
        view: { KnapsackEditorView(workspace: $0) }, outputDirectory: outputDirectory)

    try renderEditor(named: "line-balancing-editor", workspace: lineWorkspace,
        view: { LineBalancingEditorView(workspace: $0) }, outputDirectory: outputDirectory)
    if var invalidLineDraft = lineWorkspace.lineBalancingDraft {
        invalidLineDraft.tasks[0].time = "invalid"
        lineWorkspace.replaceLineBalancingDraft(invalidLineDraft)
        lineWorkspace.validateCurrentModel()
        try renderEditor(named: "line-balancing-invalid", workspace: lineWorkspace,
            view: { LineBalancingEditorView(workspace: $0) }, outputDirectory: outputDirectory)
    }

    let locationWorkspace = workspace(sample: .facilityLocation)
    try renderEditor(named: "facility-location-editor", workspace: locationWorkspace,
        view: { FacilityLocationEditorView(workspace: $0) }, outputDirectory: outputDirectory)
    try renderEditor(named: "facility-location-interactions", workspace: locationWorkspace,
        view: { FacilityLocationEditorView(workspace: $0, initialSection: .interactions) }, outputDirectory: outputDirectory)
    if var invalidLocationDraft = locationWorkspace.facilityLocationDraft {
        invalidLocationDraft.facilities[0].x = "invalid"
        locationWorkspace.replaceFacilityLocationDraft(invalidLocationDraft)
        locationWorkspace.validateCurrentModel()
        try renderEditor(named: "facility-location-invalid", workspace: locationWorkspace,
            view: { FacilityLocationEditorView(workspace: $0) }, outputDirectory: outputDirectory)
    }

    let matrixSize = 35
    let denseLayoutDepartments: [FacilityLayoutDepartment] = (0..<matrixSize).map { row in
        let flowUnitCosts: [Double?] = (0..<matrixSize).map { column in
            row == column ? nil : Double(row * matrixSize + column + 1) / 100.0
        }
        let layout: [FacilityLayoutRect] = [
            FacilityLayoutRect(startRow: 1, startColumn: row + 1, endRow: 1, endColumn: row + 1)
        ]
        return FacilityLayoutDepartment(
            id: row + 1,
            name: "Area \(row + 1)",
            fixed: false,
            flowUnitCosts: flowUnitCosts,
            initialLayout: layout
        )
    }
    let denseLayoutProblem = FacilityLayoutProblem(
        title: "35-department flow matrix",
        rowCount: 1,
        columnCount: matrixSize,
        objective: "MIN",
        departments: denseLayoutDepartments
    )
    let denseLayoutWorkspace = workspace(sample: .facilityLayout)
    let denseLayoutDraft = FacilityLayoutDraft(denseLayoutProblem)
    denseLayoutWorkspace.replaceFacilityLayoutDraft(denseLayoutDraft)
    try renderEditor(named: "facility-layout-dense-costs", workspace: denseLayoutWorkspace,
        view: { FacilityLayoutEditorView(workspace: $0, initialSection: .costs) }, outputDirectory: outputDirectory)
    try renderEditor(named: "facility-layout-dense-costs-last", workspace: denseLayoutWorkspace,
        view: { FacilityLayoutEditorView(workspace: $0, initialSection: .costs,
            initialMatrixRow: denseLayoutDraft.departments.last?.id, initialMatrixColumnGroup: 2) }, outputDirectory: outputDirectory)

    let denseLocationFacilities: [FacilityLocationFacility] = (0..<matrixSize).map { row in
        let isLast = row == matrixSize - 1
        let interactionCosts: [Double?] = (0..<matrixSize).map { column in
            row == column ? nil : Double(row * matrixSize + column + 1) / 100.0
        }
        return FacilityLocationFacility(
            id: isLast ? 1 : row + 1,
            name: "Site \(row + 1)",
            isNew: isLast,
            x: isLast ? nil : Double(row),
            y: isLast ? nil : 0.0,
            interactionCosts: interactionCosts
        )
    }
    let denseLocationProblem = FacilityLocationProblem(
        title: "35-facility interactions",
        distanceMeasure: .squaredEuclidean,
        objective: "MIN",
        facilities: denseLocationFacilities
    )
    let denseLocationWorkspace = workspace(sample: .facilityLocation)
    let denseLocationDraft = FacilityLocationDraft(denseLocationProblem)
    denseLocationWorkspace.replaceFacilityLocationDraft(denseLocationDraft)
    try renderEditor(named: "facility-location-dense-interactions", workspace: denseLocationWorkspace,
        view: { FacilityLocationEditorView(workspace: $0, initialSection: .interactions) }, outputDirectory: outputDirectory)
    try renderEditor(named: "facility-location-dense-interactions-last", workspace: denseLocationWorkspace,
        view: { FacilityLocationEditorView(workspace: $0, initialSection: .interactions,
            initialMatrixRow: denseLocationDraft.facilities.last?.id, initialMatrixColumnGroup: 2) }, outputDirectory: outputDirectory)

    let goalWorkspace = workspace(sample: .goalProgramming)
    try renderEditor(named: "goal-programming-editor", workspace: goalWorkspace,
        view: { GoalProgrammingEditorView(workspace: $0) }, outputDirectory: outputDirectory)
    try renderEditor(named: "goal-programming-priorities", workspace: goalWorkspace,
        view: { GoalProgrammingEditorView(workspace: $0, initialSection: .goals) }, outputDirectory: outputDirectory)
    try renderEditor(named: "goal-programming-constraints", workspace: goalWorkspace,
        view: { GoalProgrammingEditorView(workspace: $0, initialSection: .constraints) }, outputDirectory: outputDirectory)
    if var invalidGoalDraft = goalWorkspace.goalProgrammingDraft {
        invalidGoalDraft.goals[0].coefficients[0] = "invalid"
        goalWorkspace.replaceGoalProgrammingDraft(invalidGoalDraft)
        goalWorkspace.validateCurrentModel()
        try renderEditor(named: "goal-programming-invalid", workspace: goalWorkspace,
            view: { GoalProgrammingEditorView(workspace: $0, initialSection: .goals) }, outputDirectory: outputDirectory)
    }

    let denseGoalObjectives: [GoalObjective] = (1...35).map { row in
        let coefficients = (1...40).map { Double(row * 100 + $0) }
        return GoalObjective(name: "Goal \(row)", sense: .maximize, coefficients: coefficients)
    }
    let denseGoalConstraints: [LinearConstraint] = (1...35).map { row in
        let coefficients = (1...40).map { Double(row * 100 + $0) }
        return LinearConstraint(name: "Capacity \(row)", coefficients: coefficients, relation: .lessThanOrEqual, rhs: 10000)
    }
    let denseGoalModel = GoalProgram(
        title: "35 priorities, 40 variables",
        variableNames: (1...40).map { "x\($0)" },
        goals: denseGoalObjectives,
        constraints: denseGoalConstraints,
        lowerBounds: Array(repeating: 0, count: 40),
        upperBounds: Array(repeating: 10, count: 40),
        variableTypes: Array(repeating: .continuous, count: 40)
    )
    let denseGoalDraft = GoalProgrammingDraft(denseGoalModel)
    let denseGoalWorkspace = workspace(sample: .goalProgramming)
    denseGoalWorkspace.replaceGoalProgrammingDraft(denseGoalDraft)
    for selectedSection in [GoalProgrammingEditorView.Section.goals, .constraints] {
        let name = selectedSection == .goals ? "priorities" : "constraints"
        let lastRow = selectedSection == .goals ? denseGoalDraft.goals.last?.id : denseGoalDraft.constraints.last?.id
        try renderEditor(named: "goal-dense-\(name)", workspace: denseGoalWorkspace,
            view: { GoalProgrammingEditorView(workspace: $0, initialSection: selectedSection) }, outputDirectory: outputDirectory)
        try renderEditor(named: "goal-dense-\(name)-last", workspace: denseGoalWorkspace,
            view: { GoalProgrammingEditorView(workspace: $0, initialSection: selectedSection,
                initialMatrixRow: lastRow, initialMatrixColumnGroup: 3) }, outputDirectory: outputDirectory)
    }

    let incompleteGoal = GoalProgram(title: "Review goal dimensions", variableNames: ["a"],
        goals: [GoalObjective(name: "Profit", sense: .maximize, coefficients: [2, 5])], constraints: [],
        lowerBounds: [], upperBounds: [], variableTypes: [])
    let goalRepairWorkspace = workspace(sample: .goalProgramming)
    goalRepairWorkspace.replaceGoalProgrammingDraft(GoalProgrammingDraft(incompleteGoal))
    try renderEditor(named: "goal-programming-dimension-review", workspace: goalRepairWorkspace,
        view: { GoalProgrammingEditorView(workspace: $0) }, outputDirectory: outputDirectory)

    let nonlinearWorkspace = workspace(sample: .nonlinearProgramming)
    var nonlinearDraft = NonlinearProgrammingDraft.blank()
    let constraintID = nonlinearDraft.addConstraint()
    if let index = nonlinearDraft.constraints.firstIndex(where: { $0.id == constraintID }) {
        nonlinearDraft.constraints[index].name = "Resource capacity"
        nonlinearDraft.constraints[index].expression = "exp(x1)"
        nonlinearDraft.constraints[index].rhs = "100"
    }
    nonlinearWorkspace.replaceNonlinearProgrammingDraft(nonlinearDraft)
    try renderEditor(named: "nonlinear-programming-editor", workspace: nonlinearWorkspace,
        view: { NonlinearProgrammingEditorView(workspace: $0) }, outputDirectory: outputDirectory)
    nonlinearDraft.objectiveExpression = "unknown + ("
    nonlinearWorkspace.replaceNonlinearProgrammingDraft(nonlinearDraft)
    nonlinearWorkspace.validateCurrentModel()
    try renderEditor(named: "nonlinear-programming-invalid", workspace: nonlinearWorkspace,
        view: { NonlinearProgrammingEditorView(workspace: $0) }, outputDirectory: outputDirectory)

    let nonlinearRepairWorkspace = workspace(sample: .nonlinearProgramming)
    nonlinearRepairWorkspace.replaceNonlinearProgrammingDraft(NonlinearProgrammingDraft(
        NonlinearProgram(title: "Review imported bounds", sense: .minimize, objectiveExpression: "x^2",
            variableNames: ["x"], lowerBounds: [0, -7], upperBounds: [10], constraints: [],
            normalizedStrictInequalities: false)))
    try renderEditor(named: "nonlinear-programming-dimension-review", workspace: nonlinearRepairWorkspace,
        view: { NonlinearProgrammingEditorView(workspace: $0) }, outputDirectory: outputDirectory)

    try renderEditor(named: "quadratic-programming-editor", workspace: workspace(sample: .quadraticProgramming), view: { QuadraticProgrammingEditorView(workspace: $0) }, outputDirectory: outputDirectory)
    try renderEditor(named: "quadratic-programming-matrix", workspace: workspace(sample: .quadraticProgramming), view: { QuadraticProgrammingEditorView(workspace: $0, initialSection: .matrix) }, outputDirectory: outputDirectory)

    let coupledWorkspace = workspace(sample: .quadraticProgramming)
    let coupledModel = QuadraticProgram(
        title: "Production Mix", sense: .minimize,
        variableNames: ["Product A", "Product B", "Product C"],
        linearCoefficients: [-3, -7, -2],
        quadraticMatrix: [[4, 1, 0], [1, 2, 0], [0, 0, 2]],
        constraints: [LinearConstraint(name: "Weekly capacity", coefficients: [2, 5, 3], relation: .lessThanOrEqual, rhs: 20)],
        lowerBounds: [0, 0, 0], upperBounds: [10, 12, 8],
        variableTypes: [.continuous, .continuous, .continuous])
    coupledWorkspace.replaceQuadraticProgrammingDraft(QuadraticProgrammingDraft(coupledModel))
    try renderEditor(named: "quadratic-programming-coupled-matrix", workspace: coupledWorkspace,
        view: { QuadraticProgrammingEditorView(workspace: $0, initialSection: .matrix) }, outputDirectory: outputDirectory)
    try renderEditor(named: "quadratic-programming-constraints", workspace: coupledWorkspace,
        view: { QuadraticProgrammingEditorView(workspace: $0, initialSection: .constraints) }, outputDirectory: outputDirectory)
    var invalidQuadraticDraft = QuadraticProgrammingDraft(coupledModel)
    invalidQuadraticDraft.linearCoefficients[0] = "invalid"
    coupledWorkspace.replaceQuadraticProgrammingDraft(invalidQuadraticDraft)
    coupledWorkspace.validateCurrentModel()
    try renderEditor(named: "quadratic-programming-invalid", workspace: coupledWorkspace,
        view: { QuadraticProgrammingEditorView(workspace: $0) }, outputDirectory: outputDirectory)

    let malformedQP = QuadraticProgram(title: "Review imported dimensions", sense: .minimize,
        variableNames: ["a", "b"], linearCoefficients: [-1], quadraticMatrix: [[4, 1], [1, 3]],
        constraints: [], lowerBounds: [], upperBounds: [], variableTypes: [])
    let repairWorkspace = workspace(sample: .quadraticProgramming)
    repairWorkspace.replaceQuadraticProgrammingDraft(QuadraticProgrammingDraft(malformedQP))
    try renderEditor(named: "quadratic-programming-dimension-review", workspace: repairWorkspace,
        view: { QuadraticProgrammingEditorView(workspace: $0) }, outputDirectory: outputDirectory)

    let largeQPWorkspace = workspace(sample: .quadraticProgramming)
    let variableCount = 40
    let largeQP = QuadraticProgram(title: "Forty-variable model", sense: .minimize,
        variableNames: (1...variableCount).map { "Product \($0)" },
        linearCoefficients: Array(repeating: -1, count: variableCount),
        quadraticMatrix: (0..<variableCount).map { row in
            (0..<variableCount).map { column in row == column ? 10.0 : 0.01 }
        }, constraints: [], lowerBounds: Array(repeating: 0, count: variableCount),
        upperBounds: Array(repeating: 100, count: variableCount), variableTypes: Array(repeating: .continuous, count: variableCount))
    let largeQPDraft = QuadraticProgrammingDraft(largeQP)
    largeQPWorkspace.replaceQuadraticProgrammingDraft(largeQPDraft)
    try renderEditor(named: "quadratic-programming-large-matrix", workspace: largeQPWorkspace,
        view: { QuadraticProgrammingEditorView(workspace: $0, initialSection: .matrix) }, outputDirectory: outputDirectory)
    try renderEditor(named: "quadratic-programming-large-matrix-last", workspace: largeQPWorkspace,
        view: { QuadraticProgrammingEditorView(workspace: $0, initialSection: .matrix,
            initialMatrixRow: largeQPDraft.variables.last?.id, initialMatrixColumnGroup: 3) }, outputDirectory: outputDirectory)

    try renderEditor(
        named: "project-scheduling-editor",
        workspace: workspace(sample: .projectScheduling),
        view: { ProjectSchedulingEditorView(workspace: $0) },
        outputDirectory: outputDirectory
    )

    let runningProject = workspace(sample: .projectScheduling)
    runningProject.beginSolving()
    runningProject.status = "Running CPM with nativeEducational…"
    try renderEditor(named: "project-solving", workspace: runningProject,
        view: { modelWorkspace in VStack(spacing: 0) {
            ProjectSchedulingEditorView(workspace: modelWorkspace)
            StatusBar(workspace: modelWorkspace)
        } }, outputDirectory: outputDirectory)
    let failedProject = workspace(sample: .projectScheduling)
    failedProject.selectedBackend = .externalHighPerformance
    failedProject.solveProjectScheduling()
    try renderEditor(named: "project-failed", workspace: failedProject,
        view: { RunConfigurationView(workspace: $0) }, outputDirectory: outputDirectory)

    let projectRepairWorkspace = workspace(sample: .projectScheduling)
    var projectRepairDraft = try #require(projectRepairWorkspace.projectSchedulingDraft)
    projectRepairDraft.activities[0].normalCost = "unfinished"
    projectRepairDraft.changeKind(to: .probabilisticPERT)
    projectRepairDraft.activities[0].optimisticTime = "unfinished"
    projectRepairWorkspace.replaceProjectSchedulingDraft(projectRepairDraft)
    try renderEditor(named: "project-pert-invalid", workspace: projectRepairWorkspace,
        view: { ProjectSchedulingEditorView(workspace: $0) }, outputDirectory: outputDirectory)
    projectRepairDraft.changeKind(to: .deterministicCPM)
    projectRepairWorkspace.replaceProjectSchedulingDraft(projectRepairDraft)
    try renderEditor(named: "project-cpm-restored-invalid", workspace: projectRepairWorkspace,
        view: { ProjectSchedulingEditorView(workspace: $0) }, outputDirectory: outputDirectory)

    try renderEditor(
        named: "aggregate-planning-editor",
        workspace: workspace(sample: .aggregatePlanning),
        view: { AggregatePlanningEditorView(workspace: $0) },
        outputDirectory: outputDirectory
    )

    let runningAggregate = workspace(sample: .aggregatePlanning)
    runningAggregate.beginSolving()
    runningAggregate.status = "Running Aggregate Planning with nativeEducational…"
    try renderEditor(named: "aggregate-solving", workspace: runningAggregate,
        view: { modelWorkspace in VStack(spacing: 0) {
            AggregatePlanningEditorView(workspace: modelWorkspace)
            StatusBar(workspace: modelWorkspace)
        } }, outputDirectory: outputDirectory)
    let runningMRP = workspace(sample: .materialRequirementsPlanning)
    runningMRP.beginSolving()
    runningMRP.status = "Running Material Requirements Planning with nativeEducational…"
    try renderEditor(named: "mrp-solving", workspace: runningMRP,
        view: { modelWorkspace in VStack(spacing: 0) {
            MaterialRequirementsPlanningEditorView(workspace: modelWorkspace)
            StatusBar(workspace: modelWorkspace)
        } }, outputDirectory: outputDirectory)
    let failedMRP = workspace(sample: .materialRequirementsPlanning)
    failedMRP.selectedBackend = .externalHighPerformance
    failedMRP.solveMaterialRequirementsPlanning()
    try renderEditor(named: "mrp-failed", workspace: failedMRP,
        view: { RunConfigurationView(workspace: $0) }, outputDirectory: outputDirectory)

    var aggregateObject = try #require(JSONSerialization.jsonObject(with: Data(SampleModels.aggregatePlanningJSON.utf8)) as? [String: Any])
    aggregateObject["periodNames"] = ["January"]
    aggregateObject["demand"] = [80, 120, 160, 200]
    aggregateObject["regularCapacity"] = [100]
    let aggregateReviewModel = try AggregatePlanningJSON.decodeModel(from: JSONSerialization.data(withJSONObject: aggregateObject))
    let aggregateReviewWorkspace = workspace(sample: .aggregatePlanning)
    aggregateReviewWorkspace.replaceAggregatePlanningDraft(AggregatePlanningDraft(aggregateReviewModel))
    try renderEditor(named: "aggregate-dimension-review", workspace: aggregateReviewWorkspace,
        view: { AggregatePlanningEditorView(workspace: $0) }, outputDirectory: outputDirectory)

    try renderEditor(
        named: "material-requirements-planning-editor",
        workspace: workspace(sample: .materialRequirementsPlanning),
        view: { MaterialRequirementsPlanningEditorView(workspace: $0) },
        outputDirectory: outputDirectory
    )

    try renderEditor(
        named: "material-requirements-planning-schedules",
        workspace: workspace(sample: .materialRequirementsPlanning),
        view: { MaterialRequirementsPlanningEditorView(workspace: $0, initialSection: .schedules) },
        outputDirectory: outputDirectory
    )

    try renderEditor(
        named: "material-requirements-planning-bom",
        workspace: workspace(sample: .materialRequirementsPlanning),
        view: { MaterialRequirementsPlanningEditorView(workspace: $0, initialSection: .billOfMaterials) },
        outputDirectory: outputDirectory
    )

    var denseMRPDraft = MaterialRequirementsPlanningDraft.blank()
    denseMRPDraft.title = "35 bucket material requirements plan"
    denseMRPDraft.bucketNames = ["Overdue"] + (1...34).map { "Period \($0)" }
    denseMRPDraft.items[0].scheduledReceipts = (0..<35).map { String($0) }
    denseMRPDraft.items[0].capacity = Array(repeating: "", count: 35)
    denseMRPDraft.items[0].masterProductionSchedule = (0..<35).map { String($0 * 10) }
    let denseMRPWorkspace = workspace(sample: .materialRequirementsPlanning)
    denseMRPWorkspace.replaceMaterialRequirementsPlanningDraft(denseMRPDraft)
    try renderEditor(named: "mrp-dense-schedules", workspace: denseMRPWorkspace,
        view: { MaterialRequirementsPlanningEditorView(workspace: $0, initialSection: .schedules) }, outputDirectory: outputDirectory)
    try renderEditor(named: "mrp-dense-schedules-last", workspace: denseMRPWorkspace,
        view: { MaterialRequirementsPlanningEditorView(workspace: $0, initialSection: .schedules,
            initialScheduleGroup: 2) }, outputDirectory: outputDirectory)

    let originalMRP = try MaterialRequirementsPlanningDraft.blank().makeModel()
    let importedMRP = MaterialRequirementsPlanningModel(title: "Review imported MRP schedules", timeUnit: "Period",
        periodsPerYear: 12, bucketNames: ["Overdue"], items: originalMRP.items, billsOfMaterial: [],
        masterProductionSchedule: ["ITEM1": [11, 12, 13, 14], "ORPHAN": [21, 22, 23, 24, 25]])
    let mrpReviewDraft = MaterialRequirementsPlanningDraft(importedMRP)
    let mrpReviewWorkspace = workspace(sample: .materialRequirementsPlanning)
    mrpReviewWorkspace.replaceMaterialRequirementsPlanningDraft(mrpReviewDraft)
    try renderEditor(named: "mrp-dimension-review", workspace: mrpReviewWorkspace,
        view: { MaterialRequirementsPlanningEditorView(workspace: $0) }, outputDirectory: outputDirectory)
    try renderEditor(named: "mrp-dimension-schedules", workspace: mrpReviewWorkspace,
        view: { MaterialRequirementsPlanningEditorView(workspace: $0, initialSection: .schedules) }, outputDirectory: outputDirectory)
    try renderEditor(named: "mrp-orphan-item", workspace: mrpReviewWorkspace,
        view: { MaterialRequirementsPlanningEditorView(workspace: $0, initialItemID: mrpReviewDraft.items.last?.id) }, outputDirectory: outputDirectory)

    let solutionSamples: [(String, SampleModel)] = [
        ("goal-programming", .goalProgramming),
        ("bounded-knapsack", .boundedKnapsack),
        ("aggregate-planning", .aggregatePlanning),
        ("material-requirements", .materialRequirementsPlanning),
        ("acceptance-sampling", .acceptanceSampling),
        ("quality-control", .qualityControl),
        ("quadratic-programming", .quadraticProgramming),
        ("nonlinear-programming", .nonlinearProgramming),
        ("facility-location", .facilityLocation),
        ("line-balancing", .lineBalancing),
        ("project-scheduling", .projectScheduling),
        ("simulation", .simulation)
    ]

    for (name, sample) in solutionSamples {
        let sampleWorkspace = workspace(sample: sample)
        sampleWorkspace.runCurrentModel()
        #expect(sampleWorkspace.runState == .solved)
        try renderEditor(
            named: "\(name)-solution",
            workspace: sampleWorkspace,
            view: { SolutionView(workspace: $0) },
            outputDirectory: outputDirectory
        )
    }
}

@MainActor
private func workspace(sample: SampleModel) -> QSBWorkspace {
    let workspace = QSBWorkspace()
    workspace.loadSample(sample)
    return workspace
}

@MainActor
private func renderEditor<Content: View>(
    named name: String,
    workspace: QSBWorkspace,
    @ViewBuilder view: (QSBWorkspace) -> Content,
    outputDirectory: URL
) throws {
    try render(
        AnyView(view(workspace)),
        named: "\(name)-compact",
        size: CGSize(width: 1_000, height: 700),
        outputDirectory: outputDirectory
    )
    try render(
        AnyView(view(workspace)),
        named: "\(name)-wide",
        size: CGSize(width: 1_400, height: 900),
        outputDirectory: outputDirectory
    )
}

@MainActor
private func render(
    _ view: AnyView,
    named name: String,
    size: CGSize,
    outputDirectory: URL
) throws {
    let hostingView = NSHostingView(
        rootView: view
            .frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, .light)
    )
    hostingView.frame = CGRect(origin: .zero, size: size)
    hostingView.appearance = NSAppearance(named: .aqua)
    hostingView.layoutSubtreeIfNeeded()
    hostingView.displayIfNeeded()

    let representation = try #require(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
    hostingView.cacheDisplay(in: hostingView.bounds, to: representation)
    let data = try #require(representation.representation(using: .png, properties: [:]))
    #expect(data.count > 10_000)
    try data.write(to: outputDirectory.appendingPathComponent("\(name).png"))
}
