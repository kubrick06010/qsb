import Foundation
import QSBCore

enum AcceptanceSamplingDraftError: Error, Equatable, CustomStringConvertible {
    case emptyField(path: String, label: String)
    case invalidNumber(path: String, label: String, value: String)
    case invalidInteger(path: String, label: String, value: String)

    var path: String {
        switch self {
        case .emptyField(let path, _), .invalidNumber(let path, _, _), .invalidInteger(let path, _, _): path
        }
    }

    var description: String {
        switch self {
        case .emptyField(_, let label): "Enter \(label)."
        case .invalidNumber(_, let label, let value): "Enter a finite number for \(label) (received ‘\(value)’)."
        case .invalidInteger(_, let label, let value): "Enter a whole number for \(label) (received ‘\(value)’)."
        }
    }
}

struct AcceptanceSamplingDraft: Equatable, Sendable {
    var kind: AcceptanceSamplingPlanKind
    var title: String
    var sampleSize: String
    var acceptanceNumber: String
    var firstSampleSize: String
    var firstAcceptanceNumber: String
    var firstRejectionNumber: String
    var secondSampleSize: String
    var cumulativeSecondAcceptanceNumber: String
    var acceptableQualityLevel: String
    var rejectableQualityLevel: String
    var nominalProducerRisk: String
    var nominalConsumerRisk: String
    var lotSize: String
    var unitSamplingCost: String
    var unitInspectionCost: String
    var producerDefectiveCost: String
    var consumerDefectiveCost: String

    private init(
        kind: AcceptanceSamplingPlanKind, title: String,
        sampleSize: String, acceptanceNumber: String,
        firstSampleSize: String, firstAcceptanceNumber: String, firstRejectionNumber: String,
        secondSampleSize: String, cumulativeSecondAcceptanceNumber: String,
        acceptableQualityLevel: String, rejectableQualityLevel: String,
        nominalProducerRisk: String, nominalConsumerRisk: String,
        lotSize: String, unitSamplingCost: String, unitInspectionCost: String,
        producerDefectiveCost: String, consumerDefectiveCost: String
    ) {
        self.kind = kind; self.title = title
        self.sampleSize = sampleSize; self.acceptanceNumber = acceptanceNumber
        self.firstSampleSize = firstSampleSize; self.firstAcceptanceNumber = firstAcceptanceNumber
        self.firstRejectionNumber = firstRejectionNumber; self.secondSampleSize = secondSampleSize
        self.cumulativeSecondAcceptanceNumber = cumulativeSecondAcceptanceNumber
        self.acceptableQualityLevel = acceptableQualityLevel; self.rejectableQualityLevel = rejectableQualityLevel
        self.nominalProducerRisk = nominalProducerRisk; self.nominalConsumerRisk = nominalConsumerRisk
        self.lotSize = lotSize; self.unitSamplingCost = unitSamplingCost; self.unitInspectionCost = unitInspectionCost
        self.producerDefectiveCost = producerDefectiveCost; self.consumerDefectiveCost = consumerDefectiveCost
    }

    static func blank(_ kind: AcceptanceSamplingPlanKind = .single) -> Self {
        Self(
            kind: kind, title: "New Acceptance Sampling Plan",
            sampleSize: "50", acceptanceNumber: "1",
            firstSampleSize: "30", firstAcceptanceNumber: "0", firstRejectionNumber: "3",
            secondSampleSize: "30", cumulativeSecondAcceptanceNumber: "3",
            acceptableQualityLevel: "0.01", rejectableQualityLevel: "0.05",
            nominalProducerRisk: "0.05", nominalConsumerRisk: "0.10",
            lotSize: "500", unitSamplingCost: "1", unitInspectionCost: "0.5",
            producerDefectiveCost: "4", consumerDefectiveCost: "12"
        )
    }

    init(_ model: AcceptanceSamplingModelEnvelope) {
        var draft = Self.blank(model.kind)
        switch model {
        case .single(let plan):
            draft.title = plan.title
            draft.sampleSize = String(plan.sampleSize)
            draft.acceptanceNumber = String(plan.acceptanceNumber)
            draft.copyCommon(
                aql: plan.acceptableQualityLevel, rql: plan.rejectableQualityLevel,
                producerRisk: plan.nominalProducerRisk, consumerRisk: plan.nominalConsumerRisk,
                economics: plan.economics
            )
        case .double(let plan):
            draft.title = plan.title
            draft.firstSampleSize = String(plan.firstSampleSize)
            draft.firstAcceptanceNumber = String(plan.firstAcceptanceNumber)
            draft.firstRejectionNumber = String(plan.firstRejectionNumber)
            draft.secondSampleSize = String(plan.secondSampleSize)
            draft.cumulativeSecondAcceptanceNumber = String(plan.cumulativeSecondAcceptanceNumber)
            draft.copyCommon(
                aql: plan.acceptableQualityLevel, rql: plan.rejectableQualityLevel,
                producerRisk: plan.nominalProducerRisk, consumerRisk: plan.nominalConsumerRisk,
                economics: plan.economics
            )
        }
        self = draft
    }

    func makeModel() throws -> AcceptanceSamplingModelEnvelope {
        try required(title, path: "model.title", label: "a plan title")
        let common = try commonValues()
        switch kind {
        case .single:
            return .single(SingleSamplingPlan(
                title: title,
                sampleSize: try integer(sampleSize, path: "model.sampleSize", label: "sample size"),
                acceptanceNumber: try integer(acceptanceNumber, path: "model.acceptanceNumber", label: "acceptance number"),
                acceptableQualityLevel: common.aql, rejectableQualityLevel: common.rql,
                nominalProducerRisk: common.producerRisk, nominalConsumerRisk: common.consumerRisk,
                economics: common.economics
            ))
        case .double:
            return .double(DoubleSamplingPlan(
                title: title,
                firstSampleSize: try integer(firstSampleSize, path: "model.firstSampleSize", label: "first sample size"),
                firstAcceptanceNumber: try integer(firstAcceptanceNumber, path: "model.firstAcceptanceNumber", label: "first acceptance number"),
                firstRejectionNumber: try integer(firstRejectionNumber, path: "model.firstRejectionNumber", label: "first rejection number"),
                secondSampleSize: try integer(secondSampleSize, path: "model.secondSampleSize", label: "second sample size"),
                cumulativeSecondAcceptanceNumber: try integer(cumulativeSecondAcceptanceNumber, path: "model.cumulativeSecondAcceptanceNumber", label: "cumulative second acceptance number"),
                acceptableQualityLevel: common.aql, rejectableQualityLevel: common.rql,
                nominalProducerRisk: common.producerRisk, nominalConsumerRisk: common.consumerRisk,
                economics: common.economics
            ))
        }
    }

    func draftDiagnostics() -> [ValidationDiagnostic] {
        do { return AcceptanceSamplingValidator.diagnostics(for: try makeModel()) }
        catch let error as AcceptanceSamplingDraftError {
            return [ValidationDiagnostic(
                severity: .error,
                code: "acceptanceSampling.draft.\(error.path.replacingOccurrences(of: ".", with: "_"))",
                message: error.description, path: error.path
            )]
        } catch {
            return [ValidationDiagnostic(severity: .error, code: "acceptanceSampling.draft.invalid", message: error.localizedDescription)]
        }
    }

    mutating func switchKind(to newKind: AcceptanceSamplingPlanKind) { kind = newKind }

    private mutating func copyCommon(
        aql: Double, rql: Double, producerRisk: Double, consumerRisk: Double,
        economics: AcceptanceSamplingEconomics
    ) {
        acceptableQualityLevel = String(aql)
        rejectableQualityLevel = String(rql)
        nominalProducerRisk = String(producerRisk)
        nominalConsumerRisk = String(consumerRisk)
        lotSize = String(economics.lotSize)
        unitSamplingCost = String(economics.unitSamplingCost)
        unitInspectionCost = String(economics.unitInspectionCost)
        producerDefectiveCost = String(economics.producerDefectiveCost)
        consumerDefectiveCost = String(economics.consumerDefectiveCost)
    }

    private func commonValues() throws -> (
        aql: Double, rql: Double, producerRisk: Double, consumerRisk: Double,
        economics: AcceptanceSamplingEconomics
    ) {
        (
            try number(acceptableQualityLevel, path: "model.acceptableQualityLevel", label: "acceptable quality level"),
            try number(rejectableQualityLevel, path: "model.rejectableQualityLevel", label: "rejectable quality level"),
            try number(nominalProducerRisk, path: "model.nominalProducerRisk", label: "nominal producer risk"),
            try number(nominalConsumerRisk, path: "model.nominalConsumerRisk", label: "nominal consumer risk"),
            AcceptanceSamplingEconomics(
                lotSize: try integer(lotSize, path: "model.economics.lotSize", label: "lot size"),
                unitSamplingCost: try number(unitSamplingCost, path: "model.economics.unitSamplingCost", label: "unit sampling cost"),
                unitInspectionCost: try number(unitInspectionCost, path: "model.economics.unitInspectionCost", label: "unit inspection cost"),
                producerDefectiveCost: try number(producerDefectiveCost, path: "model.economics.producerDefectiveCost", label: "producer defective cost"),
                consumerDefectiveCost: try number(consumerDefectiveCost, path: "model.economics.consumerDefectiveCost", label: "consumer defective cost")
            )
        )
    }

    private func required(_ value: String, path: String, label: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AcceptanceSamplingDraftError.emptyField(path: path, label: label)
        }
    }

    private func integer(_ value: String, path: String, label: String) throws -> Int {
        guard let result = Int(value) else { throw AcceptanceSamplingDraftError.invalidInteger(path: path, label: label, value: value) }
        return result
    }

    private func number(_ value: String, path: String, label: String) throws -> Double {
        guard let result = Double(value), result.isFinite else { throw AcceptanceSamplingDraftError.invalidNumber(path: path, label: label, value: value) }
        return result
    }
}
