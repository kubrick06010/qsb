import Foundation
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
    var solutionJSON: String = ""
    var validationJSON: String = ""
    var validationDiagnostics: [ValidationDiagnostic] = []
    var status: String = "Ready"
    var lastResultLabel: String?
    var modelSource: String = "New model"
    var modelState: ModelLifecycleState
    var runState: RunLifecycleState = .notRun
    var lastErrorMessage: String?
    var runNotes: [String] = []
    var selectedBackend: SolverBackendKind = .nativeEducational
    var selectedLayoutStrategy: FacilityLayoutSolvingStrategy = .initial
    var isImportingModel = false
    var isExportingModel = false
    var isExportingSolution = false

    init(modelJSON: String = "") {
        self.modelJSON = modelJSON
        self.modelState = modelJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : .editing
    }

    func showNewModelPlaceholder() {
        status = "New Model is planned for a future native editor phase"
        lastErrorMessage = nil
        selectedPane = .overview
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

    func solve(_ mode: SolveMode) {
        beginSolving()
        do {
            let modelData = Data(modelJSON.utf8)
            let program = try LinearProgramJSON.decodeProgram(from: modelData)
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
            let modelData = Data(modelJSON.utf8)
            let model = try NetworkModelJSON.decodeModel(from: modelData)
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
            let data = Data(modelJSON.utf8)
            let envelope = try FacilitiesModelJSON.decodeUncheckedModel(from: data)
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
            let model = try InventoryModelJSON.decodeUncheckedModel(from: Data(modelJSON.utf8))
            guard let solver = InventoryBackends.backend(for: selectedBackend) else {
                showUnavailableExternalBackend()
                return
            }
            guard solver.capabilities.solves else {
                try showInventoryValidationReport(solver.validationReport(for: model), kind: model.kind)
                return
            }
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
            let model = try DynamicProgrammingModelJSON.decodeUncheckedModel(from: Data(modelJSON.utf8))
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
            let request = try ForecastingModelJSON.decodeRequest(from: Data(modelJSON.utf8))
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
            let model = try DecisionAnalysisModelJSON.decodeModel(from: Data(modelJSON.utf8))
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
            let model = try SimulationJSON.decodeUncheckedModel(from: Data(modelJSON.utf8))
            guard let solver = SimulationBackends.backend(for: selectedBackend) else {
                showUnavailableExternalBackend()
                return
            }
            guard solver.capabilities.solves else {
                try showSimulationValidationReport(solver.validationReport(for: model), model: model)
                return
            }
            let solution = try solver.solve(model)
            let output = try SimulationJSON.encodeSolution(solver.solutionDocument(for: model, solution: solution))
            solutionJSON = String(decoding: output, as: UTF8.self)
            markSolved()
            status = "Simulation completed with \(selectedBackend.rawValue): \(solution.completedEntities) entities"
            lastResultLabel = "Simulation Solution"
            selectedPane = .solution
        } catch {
            showSolveError(error)
        }
    }

    func solveQuadraticProgramming() {
        beginSolving()
        do {
            let model = try QuadraticProgrammingJSON.decodeUncheckedModel(from: Data(modelJSON.utf8))
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
            let model = try NonlinearProgrammingJSON.decodeUncheckedModel(from: Data(modelJSON.utf8))
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
            let request = try MarkovJSON.decodeRequest(from: Data(modelJSON.utf8))
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
            let model = try GoalProgrammingJSON.decodeModel(from: Data(modelJSON.utf8))
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
            let model = try ProjectSchedulingJSON.decodeModel(from: Data(modelJSON.utf8))
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
            let model = try AcceptanceSamplingJSON.decodeModel(from: Data(modelJSON.utf8))
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
            let model = try QualityControlJSON.decodeModel(from: Data(modelJSON.utf8))
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
            let model = try AggregatePlanningJSON.decodeModel(from: Data(modelJSON.utf8))
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
            let model = try MaterialRequirementsPlanningJSON.decodeModel(from: Data(modelJSON.utf8))
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
            let model = try QueuingModelJSON.decodeModel(from: Data(modelJSON.utf8))
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

    func runCurrentModel() {
        if isLinearProgrammingModel {
            solve(.relaxation)
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
                let program = try LinearProgramJSON.decodeProgram(from: data)
                try validate(program: program, source: "LP/ILP JSON")
            case .network:
                let model = try NetworkModelJSON.decodeModel(from: data); let backend = ValidateOnlyNetworkBackend(); try showNetworkValidationReport(backend.validationReport(for: model), model: model)
            case .facilities(let kind):
                let model = try FacilitiesModelJSON.decodeUncheckedModel(from: data); try showFacilitiesValidationReport(ValidateOnlyFacilitiesBackend().validationReport(for: model), kind: kind)
            case .inventory(let kind):
                let model = try InventoryModelJSON.decodeUncheckedModel(from: data); try showInventoryValidationReport(ValidateOnlyInventoryBackend().validationReport(for: model), kind: kind)
            case .dynamicProgramming(let kind):
                let model = try DynamicProgrammingModelJSON.decodeUncheckedModel(from: data); try showDynamicProgrammingValidationReport(ValidateOnlyDynamicProgrammingBackend().validationReport(for: model), kind: kind)
            case .forecasting:
                let request = try ForecastingModelJSON.decodeRequest(from: data); try showForecastingValidationReport(ValidateOnlyForecastingBackend().validationReport(for: request), request: request)
            case .decisionAnalysis:
                let model = try DecisionAnalysisModelJSON.decodeModel(from: data); try showDecisionAnalysisValidationReport(ValidateOnlyDecisionAnalysisBackend().validationReport(for: model), model: model)
            case .simulation:
                let model = try SimulationJSON.decodeUncheckedModel(from: data); try showSimulationValidationReport(ValidateOnlySimulationBackend().validationReport(for: model), model: model)
            case .quadraticProgramming:
                let model = try QuadraticProgrammingJSON.decodeUncheckedModel(from: data); try showQuadraticProgrammingValidationReport(ValidateOnlyQuadraticProgrammingBackend().validationReport(for: model))
            case .nonlinearProgramming:
                let model = try NonlinearProgrammingJSON.decodeUncheckedModel(from: data); try showNonlinearProgrammingValidationReport(ValidateOnlyNonlinearProgrammingBackend().validationReport(for: model))
            case .markov:
                let request = try MarkovJSON.decodeRequest(from: data); try showMarkovValidationReport(ValidateOnlyMarkovBackend().validationReport(for: request))
            case .goalProgramming:
                let model = try GoalProgrammingJSON.decodeModel(from: data); try showGoalProgrammingValidationReport(ValidateOnlyGoalProgrammingBackend().validationReport(for: model))
            case .projectScheduling:
                let model = try ProjectSchedulingJSON.decodeModel(from: data); try showProjectSchedulingValidationReport(ValidateOnlyProjectSchedulingBackend().validationReport(for: model), model: model)
            case .acceptanceSampling:
                let model = try AcceptanceSamplingJSON.decodeModel(from: data); try showAcceptanceSamplingValidationReport(ValidateOnlyAcceptanceSamplingBackend().validationReport(for: model), model: model)
            case .qualityControl:
                let model = try QualityControlJSON.decodeModel(from: data); try showQualityControlValidationReport(ValidateOnlyQualityControlBackend().validationReport(for: model), model: model)
            case .aggregatePlanning:
                let model = try AggregatePlanningJSON.decodeModel(from: data); try showAggregatePlanningValidationReport(ValidateOnlyAggregatePlanningBackend().validationReport(for: model))
            case .materialRequirementsPlanning:
                let model = try MaterialRequirementsPlanningJSON.decodeModel(from: data); try showMaterialRequirementsPlanningValidationReport(ValidateOnlyMaterialRequirementsPlanningBackend().validationReport(for: model))
            case .scheduling:
                let model = try SchedulingModelJSON.decodeModel(from: data); try showSchedulingValidationReport(ValidateOnlySchedulingBackend().validationReport(for: model), model: model)
            case .queuing:
                let model = try QueuingModelJSON.decodeModel(from: data); try showQueuingValidationReport(ValidateOnlyQueuingBackend().validationReport(for: model), model: model)
            case .unknown:
                throw CocoaError(.fileReadCorruptFile, userInfo: [NSLocalizedDescriptionKey: "Unsupported normalized model JSON"])
            }
        } catch {
            solutionJSON = ""
            modelState = .invalid
            runState = .notRun
            lastErrorMessage = Self.message(for: error)
            status = "Validation failed: \(Self.message(for: error))"
            selectedPane = .validation
        }
    }

    func loadSample(_ sample: SampleModel) {
        switch sample {
        case .linearProgram:
            modelJSON = SampleModels.linearProgramJSON
        case .integerProgram:
            modelJSON = SampleModels.integerProgramJSON
        case .travelingSalesperson:
            modelJSON = SampleModels.travelingSalespersonJSON
        case .facilityLayout:
            modelJSON = SampleModels.facilityLayoutJSON
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
        }
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
        lastErrorMessage = "External solver is unavailable in this build"
        status = lastErrorMessage ?? "External solver is unavailable in this build"
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
        !modelJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasSolution: Bool {
        !solutionJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var modelTitle: String {
        hasModel ? currentModelFamily.displayName : "No model open"
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

    var statusSystemImage: String {
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
        guard case .linearProgramming = currentModelFamily else {
            return false
        }
        return true
    }

    var isNetworkModel: Bool {
        guard case .network = currentModelFamily else {
            return false
        }
        return true
    }

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
