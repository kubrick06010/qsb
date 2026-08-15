import Foundation
import Testing
@testable import QSBCore

@Test func importsEveryVerifiedLegacyFixtureAsNormalizedJSON() throws {
    let entries = try LegacyFixtureInventory.scanDirectory(at: legacyReferenceURL())
    let verified = entries.filter { $0.supportStatus == .verified }

    #expect(verified.count == 64)
    for entry in verified {
        let result = try LegacyModelImporter.importModel(
            at: legacyFixtureURL(entry.fileName)
        )

        #expect(result.sourceFileName == entry.fileName)
        #expect(result.restoredFileName == entry.restoredFileName)
        try decodeImportedModel(result)
    }
}

private func decodeImportedModel(_ result: LegacyModelImportResult) throws {
    let data = result.normalizedJSON
    switch result.family {
    case .acceptanceSampling:
        _ = try AcceptanceSamplingJSON.decodeModel(from: data)
    case .aggregatePlanning:
        _ = try AggregatePlanningJSON.decodeModel(from: data)
    case .decisionAnalysis:
        _ = try DecisionAnalysisModelJSON.decodeModel(from: data)
    case .dynamicProgramming:
        _ = try DynamicProgrammingModelJSON.decodeModel(from: data)
    case .facilities:
        _ = try FacilitiesModelJSON.decodeModel(from: data)
    case .forecasting:
        _ = try ForecastingModelJSON.decodeRequest(from: data)
    case .goalProgramming:
        _ = try GoalProgrammingJSON.decodeModel(from: data)
    case .inventory:
        _ = try InventoryModelJSON.decodeModel(from: data)
    case .linearProgramming:
        _ = try LinearProgramJSON.decodeProgram(from: data)
    case .markov:
        _ = try MarkovJSON.decodeRequest(from: data)
    case .materialRequirementsPlanning:
        _ = try MaterialRequirementsPlanningJSON.decodeModel(from: data)
    case .network:
        _ = try NetworkModelJSON.decodeModel(from: data)
    case .nonlinearProgramming:
        _ = try NonlinearProgrammingJSON.decodeModel(from: data)
    case .projectScheduling:
        _ = try ProjectSchedulingJSON.decodeModel(from: data)
    case .quadraticProgramming:
        _ = try QuadraticProgrammingJSON.decodeModel(from: data)
    case .qualityControl:
        _ = try QualityControlJSON.decodeModel(from: data)
    case .queuing:
        _ = try QueuingModelJSON.decodeModel(from: data)
    case .scheduling:
        _ = try SchedulingModelJSON.decodeModel(from: data)
    case .simulation:
        _ = try SimulationJSON.decodeModel(from: data)
    }
}

