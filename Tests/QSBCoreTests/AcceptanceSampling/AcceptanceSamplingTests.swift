import Foundation
import Testing
@testable import QSBCore

@Test func parsesAndEvaluatesWinQSBSingleAcceptanceSamplingFixture() throws {
    let model = try WinQSBAcceptanceSamplingParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("ASA1.AS_"))))
    let solution = try NativeEducationalAcceptanceSamplingBackend().solve(model)
    guard case .single(let plan) = model else { Issue.record("Expected single sampling plan"); return }

    #expect(plan.sampleSize == 89)
    #expect(plan.acceptanceNumber == 2)
    #expect(solution.operatingCharacteristic.count == 101)
    #expect(abs(solution.producerRiskAtAQL - 0.06031008168644125) < 1e-8)
    #expect(abs(solution.consumerRiskAtRQL - 0.09186934717218487) < 1e-8)
    #expect(solution.atAQL.averageSampleNumber == 89)
}

@Test func parsesAndEvaluatesWinQSBDoubleAcceptanceSamplingFixture() throws {
    let model = try WinQSBAcceptanceSamplingParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("ASA2.AS_"))))
    let solution = try AcceptanceSamplingSolver.solve(model)
    guard case .double(let plan) = model else { Issue.record("Expected double sampling plan"); return }

    #expect(plan.firstSampleSize == 40)
    #expect(plan.secondSampleSize == 80)
    #expect(plan.cumulativeSecondAcceptanceNumber == 5)
    #expect(abs(solution.producerRiskAtAQL - 0.0009487338644097454) < 1e-8)
    #expect(abs(solution.consumerRiskAtRQL - 0.41007373405511627) < 1e-8)
    #expect(abs(solution.atRQL.averageSampleNumber - 88.91005913444376) < 1e-8)
}

@Test func roundTripsAndValidatesAcceptanceSamplingBackends() throws {
    let model = try WinQSBAcceptanceSamplingParser.parse(from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL("ASA1.AS_"))))
    let encoded = try AcceptanceSamplingJSON.encodeModel(model)
    #expect(try AcceptanceSamplingJSON.decodeModel(from: encoded) == model)
    let native = NativeEducationalAcceptanceSamplingBackend()
    let document = native.solutionDocument(for: model, solution: try native.solve(model))
    #expect(try AcceptanceSamplingJSON.decodeSolution(from: AcceptanceSamplingJSON.encodeSolution(document)) == document)
    #expect(ValidateOnlyAcceptanceSamplingBackend().validationReport(for: model).isValid)
    #expect(AcceptanceSamplingBackends.backend(for: .externalHighPerformance) == nil)

    let invalid = AcceptanceSamplingModelEnvelope.single(SingleSamplingPlan(
        title: "Invalid", sampleSize: 10, acceptanceNumber: 10,
        acceptableQualityLevel: 0.1, rejectableQualityLevel: 0.05,
        nominalProducerRisk: 0.05, nominalConsumerRisk: 0.1,
        economics: AcceptanceSamplingEconomics(lotSize: 5, unitSamplingCost: 1, unitInspectionCost: 1, producerDefectiveCost: 1, consumerDefectiveCost: 1)
    ))
    let report = ValidateOnlyAcceptanceSamplingBackend().validationReport(for: invalid)
    #expect(!report.isValid)
    #expect(report.diagnostics.contains { $0.code == "acceptanceSampling.single.acceptanceNumber" })
    #expect(report.diagnostics.contains { $0.code == "acceptanceSampling.qualityLevels" })
    do {
        _ = try ValidateOnlyAcceptanceSamplingBackend().solve(model)
        Issue.record("validateOnly unexpectedly evaluated a sampling plan")
    } catch { #expect(String(describing: error).contains("validateOnly")) }
}

