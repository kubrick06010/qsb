import Foundation
import QSBCore

extension QSBCLI {
    enum GenericRoutingError: Error, CustomStringConvertible {
        case unsupportedNormalizedModel
        case unavailableBackend(family: LegacyModelFamily, backend: SolverBackendKind)

        var description: String {
            switch self {
            case .unsupportedNormalizedModel:
                "Input is not a supported normalized QSBCore model"
            case let .unavailableBackend(family, backend):
                "Backend \(backend.rawValue) is unavailable for \(family.rawValue)"
            }
        }
    }

    static func genericInspect(path: String) throws {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        if let imported = try? LegacyModelImporter.importModel(at: url) {
            print("format: legacy-model")
            print("family: \(imported.family.rawValue)")
            print("source-file: \(imported.sourceFileName)")
            print("restored-file: \(imported.restoredFileName)")
            print("normalized-json: available")
            return
        }

        if let family = try? normalizedFamily(from: data) {
            print("format: normalized-json")
            print("family: \(family.rawValue)")
            print("source-file: \(url.lastPathComponent)")
            print("normalized-json: available")
        } else if LegacyCompressedFile.isCompressed(data) {
            let file = try LegacyCompressedFile(data: data)
            print("format: SZDD")
            print("expanded-size: \(file.expandedSize)")
            print("restored-path: \(LegacyCompressedFile.restoredFilename(for: path, lastCharacter: file.originalLastCharacter))")
        } else {
            print("format: plain")
            print("size: \(data.count)")
        }
    }

    static func genericValidate(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let normalized: Data
        do {
            normalized = try LegacyModelImporter.importModel(at: URL(fileURLWithPath: path)).normalizedJSON
        } catch {
            guard (try? normalizedFamily(from: data)) != nil else { throw error }
            normalized = data
        }

        let family = try normalizedFamily(from: normalized)
        let report = try validationReport(for: family, data: normalized)
        FileHandle.standardOutput.write(try genericJSONEncoder().encode(report))
        print()
    }

    static func genericSolve(path: String, backend: SolverBackendKind) throws {
        let url = URL(fileURLWithPath: path)
        let imported = try LegacyModelImporter.importModel(at: url)
        try genericSolve(normalized: imported.normalizedJSON, family: imported.family, backend: backend)
    }

    static func genericSolveJSON(path: String, backend: SolverBackendKind) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let family = try normalizedFamily(from: data)
        try genericSolve(normalized: data, family: family, backend: backend)
    }

    private static func normalizedFamily(from data: Data) throws -> LegacyModelFamily {
        if (try? LinearProgramJSON.decodeProgram(from: data)) != nil { return .linearProgramming }
        if (try? NetworkModelJSON.decodeModel(from: data)) != nil { return .network }
        if (try? ForecastingModelJSON.decodeRequest(from: data)) != nil { return .forecasting }
        if (try? InventoryModelJSON.decodeModel(from: data)) != nil { return .inventory }
        if (try? DynamicProgrammingModelJSON.decodeUncheckedModel(from: data)) != nil { return .dynamicProgramming }
        if (try? DecisionAnalysisModelJSON.decodeModel(from: data)) != nil { return .decisionAnalysis }
        if (try? FacilitiesModelJSON.decodeUncheckedModel(from: data)) != nil { return .facilities }
        if (try? SchedulingModelJSON.decodeModel(from: data)) != nil { return .scheduling }
        if (try? QueuingModelJSON.decodeModel(from: data)) != nil { return .queuing }
        if (try? SimulationJSON.decodeUncheckedModel(from: data)) != nil { return .simulation }
        if (try? ProjectSchedulingJSON.decodeModel(from: data)) != nil { return .projectScheduling }
        if (try? MarkovJSON.decodeRequest(from: data)) != nil { return .markov }
        if (try? GoalProgrammingJSON.decodeModel(from: data)) != nil { return .goalProgramming }
        if (try? AcceptanceSamplingJSON.decodeModel(from: data)) != nil { return .acceptanceSampling }
        if (try? QualityControlJSON.decodeModel(from: data)) != nil { return .qualityControl }
        if (try? AggregatePlanningJSON.decodeModel(from: data)) != nil { return .aggregatePlanning }
        if (try? MaterialRequirementsPlanningJSON.decodeModel(from: data)) != nil { return .materialRequirementsPlanning }
        if (try? QuadraticProgrammingJSON.decodeUncheckedModel(from: data)) != nil { return .quadraticProgramming }
        if (try? NonlinearProgrammingJSON.decodeUncheckedModel(from: data)) != nil { return .nonlinearProgramming }
        throw GenericRoutingError.unsupportedNormalizedModel
    }

    private static func validationReport(for family: LegacyModelFamily, data: Data) throws -> ValidationReport {
        switch family {
        case .linearProgramming:
            let model = try LinearProgramJSON.decodeProgram(from: data)
            return ValidateOnlyLinearProgrammingBackend().validationReport(for: model)
        case .network:
            return ValidateOnlyNetworkBackend().validationReport(for: try NetworkModelJSON.decodeModel(from: data))
        case .forecasting:
            return ValidateOnlyForecastingBackend().validationReport(for: try ForecastingModelJSON.decodeRequest(from: data))
        case .inventory:
            return ValidateOnlyInventoryBackend().validationReport(for: try InventoryModelJSON.decodeModel(from: data))
        case .dynamicProgramming:
            return ValidateOnlyDynamicProgrammingBackend().validationReport(for: try DynamicProgrammingModelJSON.decodeUncheckedModel(from: data))
        case .decisionAnalysis:
            return ValidateOnlyDecisionAnalysisBackend().validationReport(for: try DecisionAnalysisModelJSON.decodeModel(from: data))
        case .facilities:
            return ValidateOnlyFacilitiesBackend().validationReport(for: try FacilitiesModelJSON.decodeUncheckedModel(from: data))
        case .scheduling:
            return ValidateOnlySchedulingBackend().validationReport(for: try SchedulingModelJSON.decodeModel(from: data))
        case .queuing:
            return try validateQueuing(data)
        case .simulation:
            return ValidateOnlySimulationBackend().validationReport(for: try SimulationJSON.decodeUncheckedModel(from: data))
        case .projectScheduling:
            return ValidateOnlyProjectSchedulingBackend().validationReport(for: try ProjectSchedulingJSON.decodeModel(from: data))
        case .markov:
            return ValidateOnlyMarkovBackend().validationReport(for: try MarkovJSON.decodeRequest(from: data))
        case .goalProgramming:
            return ValidateOnlyGoalProgrammingBackend().validationReport(for: try GoalProgrammingJSON.decodeModel(from: data))
        case .acceptanceSampling:
            return ValidateOnlyAcceptanceSamplingBackend().validationReport(for: try AcceptanceSamplingJSON.decodeModel(from: data))
        case .qualityControl:
            return ValidateOnlyQualityControlBackend().validationReport(for: try QualityControlJSON.decodeModel(from: data))
        case .aggregatePlanning:
            return ValidateOnlyAggregatePlanningBackend().validationReport(for: try AggregatePlanningJSON.decodeModel(from: data))
        case .materialRequirementsPlanning:
            return ValidateOnlyMaterialRequirementsPlanningBackend().validationReport(for: try MaterialRequirementsPlanningJSON.decodeModel(from: data))
        case .quadraticProgramming:
            return ValidateOnlyQuadraticProgrammingBackend().validationReport(for: try QuadraticProgrammingJSON.decodeUncheckedModel(from: data))
        case .nonlinearProgramming:
            return ValidateOnlyNonlinearProgrammingBackend().validationReport(for: try NonlinearProgrammingJSON.decodeUncheckedModel(from: data))
        }
    }

    private static func validateQueuing(_ data: Data) throws -> ValidationReport {
        let model = try QueuingModelJSON.decodeModel(from: data)
        let backend = ValidateOnlyQueuingBackend()
        switch model {
        case .mm1(let value): return backend.validationReport(for: value)
        case .finiteCapacity(let value): return backend.validationReport(for: value)
        }
    }

    static func genericSolve(normalized data: Data, family: LegacyModelFamily, backend kind: SolverBackendKind) throws {
        switch family {
        case .linearProgramming:
            let model = try LinearProgramJSON.decodeProgram(from: data)
            guard let solver = LinearProgrammingBackends.backend(for: kind) else { throw GenericRoutingError.unavailableBackend(family: family, backend: kind) }
            guard solver.capabilities.solves else { try writeGenericValidation(solver.validationReport(for: model)); return }
            let mode: LinearProgramSolveMode = model.variableTypes.contains { $0 != .continuous } ? .integer : .continuous
            let solution = try solver.solve(model, mode: mode, options: SolverOptions())
            FileHandle.standardOutput.write(try LinearProgramJSON.encodeSolution(solution)); print()
        case .network:
            let model = try NetworkModelJSON.decodeModel(from: data)
            guard let solver = NetworkBackends.backend(for: kind) else { throw GenericRoutingError.unavailableBackend(family: family, backend: kind) }
            guard solver.capabilities.solves else { try writeGenericValidation(solver.validationReport(for: model)); return }
            FileHandle.standardOutput.write(try NetworkModelJSON.encodeSolutionDocument(solver.solutionDocument(for: model, solution: try solver.solve(model)))); print()
        case .inventory:
            let model = try InventoryModelJSON.decodeModel(from: data)
            guard let solver = InventoryBackends.backend(for: kind) else { throw GenericRoutingError.unavailableBackend(family: family, backend: kind) }
            guard solver.capabilities.solves else { try writeGenericValidation(solver.validationReport(for: model)); return }
            FileHandle.standardOutput.write(try InventoryModelJSON.encodeSolutionDocument(solver.solutionDocument(for: model, solution: try solver.solve(model)))); print()
        case .facilities:
            let model = try FacilitiesModelJSON.decodeUncheckedModel(from: data)
            guard let solver = FacilitiesBackends.backend(for: kind) else { throw GenericRoutingError.unavailableBackend(family: family, backend: kind) }
            guard solver.capabilities.solves else { try writeGenericValidation(solver.validationReport(for: model)); return }
            FileHandle.standardOutput.write(try FacilitiesModelJSON.encodeSolutionDocument(FacilitiesSolutionDocument(backend: solver.runMetadata(for: model), solution: try solver.solve(model)))); print()
        case .dynamicProgramming:
            let model = try DynamicProgrammingModelJSON.decodeUncheckedModel(from: data)
            guard let solver = DynamicProgrammingBackends.backend(for: kind) else { throw GenericRoutingError.unavailableBackend(family: family, backend: kind) }
            guard solver.capabilities.solves else { try writeGenericValidation(solver.validationReport(for: model)); return }
            FileHandle.standardOutput.write(try DynamicProgrammingModelJSON.encodeSolutionDocument(solver.solutionDocument(for: model, solution: try solver.solve(model)))); print()
        case .forecasting:
            let model = try ForecastingModelJSON.decodeRequest(from: data)
            guard let solver = ForecastingBackends.backend(for: kind) else { throw GenericRoutingError.unavailableBackend(family: family, backend: kind) }
            guard solver.capabilities.solves else { try writeGenericValidation(solver.validationReport(for: model)); return }
            FileHandle.standardOutput.write(try ForecastingModelJSON.encodeSolutionDocument(solver.solutionDocument(for: model, solution: try solver.solve(model)))); print()
        case .decisionAnalysis:
            let model = try DecisionAnalysisModelJSON.decodeModel(from: data)
            guard let solver = DecisionAnalysisBackends.backend(for: kind) else { throw GenericRoutingError.unavailableBackend(family: family, backend: kind) }
            guard solver.capabilities.solves else { try writeGenericValidation(solver.validationReport(for: model)); return }
            FileHandle.standardOutput.write(try DecisionAnalysisModelJSON.encodeSolutionDocument(solver.solutionDocument(for: model, solution: try solver.solve(model)))); print()
        case .scheduling:
            let model = try SchedulingModelJSON.decodeModel(from: data)
            guard let solver = SchedulingBackends.backend(for: kind) else { throw GenericRoutingError.unavailableBackend(family: family, backend: kind) }
            guard solver.capabilities.solves else { try writeGenericValidation(solver.validationReport(for: model)); return }
            FileHandle.standardOutput.write(try SchedulingModelJSON.encodeSolution(try solver.solve(model))); print()
        case .queuing:
            let model = try QueuingModelJSON.decodeModel(from: data)
            guard let solver = QueuingBackends.backend(for: kind) else { throw GenericRoutingError.unavailableBackend(family: family, backend: kind) }
            guard solver.capabilities.solves else { try writeGenericValidation(try validateQueuing(data)); return }
            switch model {
            case .mm1(let value): FileHandle.standardOutput.write(try QueuingSolutionJSON.encode(QueuingSolutionJSON.mm1Document(model: value, solution: try solver.solve(value), backend: SolverRunMetadata(backendKind: kind, algorithm: "generic", exactness: .exact)))); print()
            case .finiteCapacity(let value): FileHandle.standardOutput.write(try QueuingSolutionJSON.encode(QueuingSolutionJSON.finiteCapacityDocument(model: value, solution: try solver.solve(value), backend: SolverRunMetadata(backendKind: kind, algorithm: "generic", exactness: .approximate)))); print()
            }
        case .simulation:
            let model = try SimulationJSON.decodeUncheckedModel(from: data)
            guard let solver = SimulationBackends.backend(for: kind) else { throw GenericRoutingError.unavailableBackend(family: family, backend: kind) }
            guard solver.capabilities.solves else { try writeGenericValidation(solver.validationReport(for: model)); return }
            FileHandle.standardOutput.write(try SimulationJSON.encodeSolution(solver.solutionDocument(for: model, solution: try solver.solve(model)))); print()
        case .projectScheduling:
            let model = try ProjectSchedulingJSON.decodeModel(from: data)
            guard let solver = ProjectSchedulingBackends.backend(for: kind) else { throw GenericRoutingError.unavailableBackend(family: family, backend: kind) }
            guard solver.capabilities.solves else { try writeGenericValidation(solver.validationReport(for: model)); return }
            FileHandle.standardOutput.write(try ProjectSchedulingJSON.encodeSolution(solver.solutionDocument(for: model, solution: try solver.solve(model)))); print()
        case .markov:
            let model = try MarkovJSON.decodeRequest(from: data)
            guard let solver = MarkovBackends.backend(for: kind) else { throw GenericRoutingError.unavailableBackend(family: family, backend: kind) }
            guard solver.capabilities.solves else { try writeGenericValidation(solver.validationReport(for: model)); return }
            FileHandle.standardOutput.write(try MarkovJSON.encodeSolution(solver.solutionDocument(for: model, solution: try solver.solve(model)))); print()
        case .goalProgramming:
            let model = try GoalProgrammingJSON.decodeModel(from: data)
            guard let solver = GoalProgrammingBackends.backend(for: kind) else { throw GenericRoutingError.unavailableBackend(family: family, backend: kind) }
            guard solver.capabilities.solves else { try writeGenericValidation(solver.validationReport(for: model)); return }
            FileHandle.standardOutput.write(try GoalProgrammingJSON.encodeSolution(solver.solutionDocument(for: model, solution: try solver.solve(model)))); print()
        case .acceptanceSampling:
            let model = try AcceptanceSamplingJSON.decodeModel(from: data)
            guard let solver = AcceptanceSamplingBackends.backend(for: kind) else { throw GenericRoutingError.unavailableBackend(family: family, backend: kind) }
            guard solver.capabilities.solves else { try writeGenericValidation(solver.validationReport(for: model)); return }
            FileHandle.standardOutput.write(try AcceptanceSamplingJSON.encodeSolution(solver.solutionDocument(for: model, solution: try solver.solve(model)))); print()
        case .qualityControl:
            let model = try QualityControlJSON.decodeModel(from: data)
            guard let solver = QualityControlBackends.backend(for: kind) else { throw GenericRoutingError.unavailableBackend(family: family, backend: kind) }
            guard solver.capabilities.solves else { try writeGenericValidation(solver.validationReport(for: model)); return }
            FileHandle.standardOutput.write(try QualityControlJSON.encodeSolution(solver.solutionDocument(for: model, solution: try solver.solve(model)))); print()
        case .aggregatePlanning:
            let model = try AggregatePlanningJSON.decodeModel(from: data)
            guard let solver = AggregatePlanningBackends.backend(for: kind) else { throw GenericRoutingError.unavailableBackend(family: family, backend: kind) }
            guard solver.capabilities.solves else { try writeGenericValidation(solver.validationReport(for: model)); return }
            FileHandle.standardOutput.write(try AggregatePlanningJSON.encodeSolution(solver.solutionDocument(for: model, solution: try solver.solve(model)))); print()
        case .materialRequirementsPlanning:
            let model = try MaterialRequirementsPlanningJSON.decodeModel(from: data)
            guard let solver = MaterialRequirementsPlanningBackends.backend(for: kind) else { throw GenericRoutingError.unavailableBackend(family: family, backend: kind) }
            guard solver.capabilities.solves else { try writeGenericValidation(solver.validationReport(for: model)); return }
            FileHandle.standardOutput.write(try MaterialRequirementsPlanningJSON.encodeSolution(solver.solutionDocument(for: model, solution: try solver.solve(model)))); print()
        case .quadraticProgramming:
            let model = try QuadraticProgrammingJSON.decodeUncheckedModel(from: data)
            guard let solver = QuadraticProgrammingBackends.backend(for: kind) else { throw GenericRoutingError.unavailableBackend(family: family, backend: kind) }
            guard solver.capabilities.solves else { try writeGenericValidation(solver.validationReport(for: model)); return }
            FileHandle.standardOutput.write(try QuadraticProgrammingJSON.encodeSolution(solver.solutionDocument(for: model, solution: try solver.solve(model)))); print()
        case .nonlinearProgramming:
            let model = try NonlinearProgrammingJSON.decodeUncheckedModel(from: data)
            guard let solver = NonlinearProgrammingBackends.backend(for: kind) else { throw GenericRoutingError.unavailableBackend(family: family, backend: kind) }
            guard solver.capabilities.solves else { try writeGenericValidation(solver.validationReport(for: model)); return }
            FileHandle.standardOutput.write(try NonlinearProgrammingJSON.encodeSolution(solver.solutionDocument(for: model, solution: try solver.solve(model)))); print()
        }
    }

    private static func writeGenericValidation(_ report: ValidationReport) throws {
        FileHandle.standardOutput.write(try genericJSONEncoder().encode(report)); print()
    }

    private static func genericJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
