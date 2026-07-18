import Foundation

public enum AcceptanceSamplingPlanKind: String, Codable, Sendable {
    case single
    case double
}

public struct AcceptanceSamplingEconomics: Codable, Equatable, Sendable {
    public let lotSize: Int
    public let unitSamplingCost: Double
    public let unitInspectionCost: Double
    public let producerDefectiveCost: Double
    public let consumerDefectiveCost: Double

    public init(lotSize: Int, unitSamplingCost: Double, unitInspectionCost: Double, producerDefectiveCost: Double, consumerDefectiveCost: Double) {
        self.lotSize = lotSize; self.unitSamplingCost = unitSamplingCost; self.unitInspectionCost = unitInspectionCost; self.producerDefectiveCost = producerDefectiveCost; self.consumerDefectiveCost = consumerDefectiveCost
    }
}

public struct SingleSamplingPlan: Codable, Equatable, Sendable {
    public let title: String
    public let sampleSize: Int
    public let acceptanceNumber: Int
    public let acceptableQualityLevel: Double
    public let rejectableQualityLevel: Double
    public let nominalProducerRisk: Double
    public let nominalConsumerRisk: Double
    public let economics: AcceptanceSamplingEconomics

    public init(title: String, sampleSize: Int, acceptanceNumber: Int, acceptableQualityLevel: Double, rejectableQualityLevel: Double, nominalProducerRisk: Double, nominalConsumerRisk: Double, economics: AcceptanceSamplingEconomics) {
        self.title = title; self.sampleSize = sampleSize; self.acceptanceNumber = acceptanceNumber; self.acceptableQualityLevel = acceptableQualityLevel; self.rejectableQualityLevel = rejectableQualityLevel; self.nominalProducerRisk = nominalProducerRisk; self.nominalConsumerRisk = nominalConsumerRisk; self.economics = economics
    }
}

public struct DoubleSamplingPlan: Codable, Equatable, Sendable {
    public let title: String
    public let firstSampleSize: Int
    public let firstAcceptanceNumber: Int
    public let firstRejectionNumber: Int
    public let secondSampleSize: Int
    public let cumulativeSecondAcceptanceNumber: Int
    public let acceptableQualityLevel: Double
    public let rejectableQualityLevel: Double
    public let nominalProducerRisk: Double
    public let nominalConsumerRisk: Double
    public let economics: AcceptanceSamplingEconomics

    public init(title: String, firstSampleSize: Int, firstAcceptanceNumber: Int, firstRejectionNumber: Int, secondSampleSize: Int, cumulativeSecondAcceptanceNumber: Int, acceptableQualityLevel: Double, rejectableQualityLevel: Double, nominalProducerRisk: Double, nominalConsumerRisk: Double, economics: AcceptanceSamplingEconomics) {
        self.title = title; self.firstSampleSize = firstSampleSize; self.firstAcceptanceNumber = firstAcceptanceNumber; self.firstRejectionNumber = firstRejectionNumber; self.secondSampleSize = secondSampleSize; self.cumulativeSecondAcceptanceNumber = cumulativeSecondAcceptanceNumber; self.acceptableQualityLevel = acceptableQualityLevel; self.rejectableQualityLevel = rejectableQualityLevel; self.nominalProducerRisk = nominalProducerRisk; self.nominalConsumerRisk = nominalConsumerRisk; self.economics = economics
    }
}

public enum AcceptanceSamplingModelEnvelope: Codable, Equatable, Sendable {
    case single(SingleSamplingPlan)
    case double(DoubleSamplingPlan)

    private enum CodingKeys: String, CodingKey { case kind, model }
    public var kind: AcceptanceSamplingPlanKind { switch self { case .single: .single; case .double: .double } }
    public var title: String { switch self { case .single(let value): value.title; case .double(let value): value.title } }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(AcceptanceSamplingPlanKind.self, forKey: .kind) {
        case .single: self = .single(try container.decode(SingleSamplingPlan.self, forKey: .model))
        case .double: self = .double(try container.decode(DoubleSamplingPlan.self, forKey: .model))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self { case .single(let value): try container.encode(value, forKey: .model); case .double(let value): try container.encode(value, forKey: .model) }
    }
}

public struct AcceptanceSamplingPoint: Codable, Equatable, Sendable {
    public let fractionDefective: Double
    public let acceptanceProbability: Double
    public let averageSampleNumber: Double
    public let averageTotalInspection: Double
    public let averageOutgoingQuality: Double
}

public struct AcceptanceSamplingSolution: Codable, Equatable, Sendable {
    public let producerRiskAtAQL: Double
    public let consumerRiskAtRQL: Double
    public let atAQL: AcceptanceSamplingPoint
    public let atRQL: AcceptanceSamplingPoint
    public let operatingCharacteristic: [AcceptanceSamplingPoint]
}

public struct AcceptanceSamplingSolutionDocument: Codable, Equatable, Sendable {
    public let backend: SolverRunMetadata
    public let model: AcceptanceSamplingModelEnvelope
    public let solution: AcceptanceSamplingSolution
}

public struct AcceptanceSamplingValidationDocument: Codable, Equatable, Sendable {
    public let kind: AcceptanceSamplingPlanKind
    public let backend: SolverBackendKind
    public let isValid: Bool
    public let diagnostics: [ValidationDiagnostic]

    public init(kind: AcceptanceSamplingPlanKind, backend: SolverBackendKind, diagnostics: [ValidationDiagnostic]) {
        self.kind = kind; self.backend = backend; self.isValid = !diagnostics.contains { $0.severity == .error }; self.diagnostics = diagnostics
    }
}

public enum AcceptanceSamplingError: Error, CustomStringConvertible {
    case unsupportedFormat
    case invalidModel(String)

    public var description: String { switch self { case .unsupportedFormat: "Unsupported acceptance-sampling format"; case .invalidModel(let detail): "Invalid acceptance-sampling model: \(detail)" } }
}

public enum WinQSBAcceptanceSamplingParser {
    public static func parse(from data: Data) throws -> AcceptanceSamplingModelEnvelope {
        guard let text = data.legacyLatin1String else { throw AcceptanceSamplingError.unsupportedFormat }
        let rows = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } }
        guard rows.count >= 4, rows[0].count >= 4, rows[0][0] == "ASA" else { throw AcceptanceSamplingError.unsupportedFormat }
        let entries = Dictionary(rows.dropFirst(3).compactMap { row -> (String, String)? in guard row.count >= 2 else { return nil }; return (row[0].lowercased(), row[1]) }, uniquingKeysWith: { first, _ in first })
        let common = try commonFields(entries)
        switch rows[0][3] {
        case "0":
            return .single(SingleSamplingPlan(title: rows[0][1], sampleSize: try integer(entries, prefix: "sample size"), acceptanceNumber: try integer(entries, prefix: "acceptance number"), acceptableQualityLevel: common.aql, rejectableQualityLevel: common.rql, nominalProducerRisk: common.alpha, nominalConsumerRisk: common.beta, economics: common.economics))
        case "1":
            return .double(DoubleSamplingPlan(title: rows[0][1], firstSampleSize: try integer(entries, prefix: "first sample size"), firstAcceptanceNumber: try integer(entries, prefix: "first acceptance number"), firstRejectionNumber: try integer(entries, prefix: "first rejection number"), secondSampleSize: try integer(entries, prefix: "second sample size"), cumulativeSecondAcceptanceNumber: try integer(entries, prefix: "second acceptance number"), acceptableQualityLevel: common.aql, rejectableQualityLevel: common.rql, nominalProducerRisk: common.alpha, nominalConsumerRisk: common.beta, economics: common.economics))
        default: throw AcceptanceSamplingError.unsupportedFormat
        }
    }

    private static func commonFields(_ entries: [String: String]) throws -> (aql: Double, rql: Double, alpha: Double, beta: Double, economics: AcceptanceSamplingEconomics) {
        guard let distribution = value(entries, prefix: "probability distribution"), distribution.lowercased() == "binomial" else { throw AcceptanceSamplingError.invalidModel("Only Binomial fixture distributions are currently supported") }
        return (
            try percent(entries, prefix: "acceptable quality level"), try percent(entries, prefix: "rejectable quality level"),
            try percent(entries, prefix: "producer's risk level"), try percent(entries, prefix: "consumer's risk level"),
            AcceptanceSamplingEconomics(lotSize: try integer(entries, prefix: "lot size"), unitSamplingCost: try number(entries, prefix: "unit sampling cost"), unitInspectionCost: try number(entries, prefix: "unit inspection cost"), producerDefectiveCost: try number(entries, prefix: "unit producer's cost"), consumerDefectiveCost: try number(entries, prefix: "unit consumer's cost"))
        )
    }

    private static func value(_ entries: [String: String], prefix: String) -> String? { entries.first { $0.key.hasPrefix(prefix) }?.value }
    private static func number(_ entries: [String: String], prefix: String) throws -> Double { guard let raw = value(entries, prefix: prefix), let result = Double(raw), result.isFinite else { throw AcceptanceSamplingError.invalidModel("Missing or invalid \(prefix)") }; return result }
    private static func integer(_ entries: [String: String], prefix: String) throws -> Int { let result = try number(entries, prefix: prefix); guard result.rounded() == result else { throw AcceptanceSamplingError.invalidModel("\(prefix) must be an integer") }; return Int(result) }
    private static func percent(_ entries: [String: String], prefix: String) throws -> Double { try number(entries, prefix: prefix) / 100 }
}

public enum AcceptanceSamplingValidator {
    public static func diagnostics(for model: AcceptanceSamplingModelEnvelope) -> [ValidationDiagnostic] {
        var result: [ValidationDiagnostic] = []
        let aql: Double, rql: Double, alpha: Double, beta: Double, economics: AcceptanceSamplingEconomics
        switch model {
        case .single(let plan):
            aql = plan.acceptableQualityLevel; rql = plan.rejectableQualityLevel; alpha = plan.nominalProducerRisk; beta = plan.nominalConsumerRisk; economics = plan.economics
            if plan.sampleSize <= 0 { result.append(error("single.sampleSize", "Sample size must be positive.", "model.sampleSize")) }
            if plan.acceptanceNumber < 0 || plan.acceptanceNumber >= plan.sampleSize { result.append(error("single.acceptanceNumber", "Acceptance number must be in [0, sampleSize).", "model.acceptanceNumber")) }
            if plan.sampleSize > economics.lotSize { result.append(error("single.lotSize", "Sample size must not exceed lot size.", "model.economics.lotSize")) }
        case .double(let plan):
            aql = plan.acceptableQualityLevel; rql = plan.rejectableQualityLevel; alpha = plan.nominalProducerRisk; beta = plan.nominalConsumerRisk; economics = plan.economics
            if plan.firstSampleSize <= 0 || plan.secondSampleSize <= 0 { result.append(error("double.sampleSize", "Both sample sizes must be positive.", "model")) }
            if plan.firstAcceptanceNumber < 0 || plan.firstRejectionNumber <= plan.firstAcceptanceNumber + 1 || plan.firstRejectionNumber > plan.firstSampleSize { result.append(error("double.firstDecision", "First rejection number must leave a nonempty continuation region after acceptance.", "model")) }
            if plan.cumulativeSecondAcceptanceNumber < plan.firstAcceptanceNumber || plan.cumulativeSecondAcceptanceNumber >= plan.firstSampleSize + plan.secondSampleSize { result.append(error("double.secondDecision", "Second acceptance number is outside the combined sample range.", "model.cumulativeSecondAcceptanceNumber")) }
            if plan.firstSampleSize + plan.secondSampleSize > economics.lotSize { result.append(error("double.lotSize", "Combined sample size must not exceed lot size.", "model.economics.lotSize")) }
        }
        if !(aql >= 0 && aql < rql && rql <= 1) { result.append(error("qualityLevels", "Quality levels must satisfy 0 <= AQL < RQL <= 1.", "model")) }
        if !(alpha >= 0 && alpha <= 1 && beta >= 0 && beta <= 1) { result.append(error("nominalRisks", "Nominal risks must be probabilities.", "model")) }
        if economics.lotSize <= 0 { result.append(error("lotSize", "Lot size must be positive.", "model.economics.lotSize")) }
        if [economics.unitSamplingCost, economics.unitInspectionCost, economics.producerDefectiveCost, economics.consumerDefectiveCost].contains(where: { !$0.isFinite || $0 < 0 }) { result.append(error("economics", "Economic inputs must be finite and nonnegative.", "model.economics")) }
        guard !result.contains(where: { $0.severity == .error }) else { return result }
        return [ValidationDiagnostic(severity: .info, code: "acceptanceSampling.\(model.kind.rawValue).valid", message: "Acceptance-sampling plan is valid")]
    }

    public static func validate(_ model: AcceptanceSamplingModelEnvelope) throws { if let item = diagnostics(for: model).first(where: { $0.severity == .error }) { throw AcceptanceSamplingError.invalidModel(item.message) } }
    private static func error(_ suffix: String, _ message: String, _ path: String) -> ValidationDiagnostic { ValidationDiagnostic(severity: .error, code: "acceptanceSampling.\(suffix)", message: message, path: path) }
}

public enum AcceptanceSamplingSolver {
    public static func solve(_ model: AcceptanceSamplingModelEnvelope) throws -> AcceptanceSamplingSolution {
        try AcceptanceSamplingValidator.validate(model)
        let aql: Double, rql: Double
        switch model { case .single(let plan): aql = plan.acceptableQualityLevel; rql = plan.rejectableQualityLevel; case .double(let plan): aql = plan.acceptableQualityLevel; rql = plan.rejectableQualityLevel }
        let atAQL = point(model, defective: aql)
        let atRQL = point(model, defective: rql)
        let curve = (0...100).map { point(model, defective: Double($0) / 100) }
        return AcceptanceSamplingSolution(producerRiskAtAQL: 1 - atAQL.acceptanceProbability, consumerRiskAtRQL: atRQL.acceptanceProbability, atAQL: atAQL, atRQL: atRQL, operatingCharacteristic: curve)
    }

    private static func point(_ model: AcceptanceSamplingModelEnvelope, defective p: Double) -> AcceptanceSamplingPoint {
        let probability: Double, asn: Double, lotSize: Double
        switch model {
        case .single(let plan):
            probability = binomialCDF(n: plan.sampleSize, c: plan.acceptanceNumber, p: p); asn = Double(plan.sampleSize); lotSize = Double(plan.economics.lotSize)
        case .double(let plan):
            let additional = plan.secondSampleSize
            var accept = binomialCDF(n: plan.firstSampleSize, c: plan.firstAcceptanceNumber, p: p)
            var continuation = 0.0
            if plan.firstRejectionNumber > plan.firstAcceptanceNumber + 1 {
                for firstDefects in (plan.firstAcceptanceNumber + 1)..<plan.firstRejectionNumber {
                    let firstProbability = binomialPMF(n: plan.firstSampleSize, k: firstDefects, p: p)
                    continuation += firstProbability
                    accept += firstProbability * binomialCDF(n: additional, c: plan.cumulativeSecondAcceptanceNumber - firstDefects, p: p)
                }
            }
            probability = accept; asn = Double(plan.firstSampleSize) + continuation * Double(additional); lotSize = Double(plan.economics.lotSize)
        }
        let ati = asn + (1 - probability) * (lotSize - asn)
        let aoq = p * probability * (lotSize - asn) / lotSize
        return AcceptanceSamplingPoint(fractionDefective: p, acceptanceProbability: probability, averageSampleNumber: asn, averageTotalInspection: ati, averageOutgoingQuality: aoq)
    }

    private static func binomialCDF(n: Int, c: Int, p: Double) -> Double {
        guard c >= 0 else { return 0 }; guard c < n else { return 1 }
        return (0...c).reduce(0) { $0 + binomialPMF(n: n, k: $1, p: p) }
    }

    private static func binomialPMF(n: Int, k: Int, p: Double) -> Double {
        guard k >= 0, k <= n else { return 0 }; if p == 0 { return k == 0 ? 1 : 0 }; if p == 1 { return k == n ? 1 : 0 }
        var coefficient = 1.0
        let terms = min(k, n - k)
        if terms > 0 { for value in 1...terms { coefficient *= Double(n - terms + value) / Double(value) } }
        return coefficient * pow(p, Double(k)) * pow(1 - p, Double(n - k))
    }
}

public protocol AcceptanceSamplingBackend: Sendable {
    var capabilities: SolverCapabilities { get }
    func validationReport(for model: AcceptanceSamplingModelEnvelope) -> ValidationReport
    func solve(_ model: AcceptanceSamplingModelEnvelope, options: SolverOptions) throws -> AcceptanceSamplingSolution
    func runMetadata(for model: AcceptanceSamplingModelEnvelope) -> SolverRunMetadata
}

public extension AcceptanceSamplingBackend {
    func validationReport(for model: AcceptanceSamplingModelEnvelope) -> ValidationReport { ValidationReport(backend: capabilities.backendKind, diagnostics: AcceptanceSamplingValidator.diagnostics(for: model)) }
    func solve(_ model: AcceptanceSamplingModelEnvelope) throws -> AcceptanceSamplingSolution { try solve(model, options: SolverOptions()) }
    func solutionDocument(for model: AcceptanceSamplingModelEnvelope, solution: AcceptanceSamplingSolution) -> AcceptanceSamplingSolutionDocument { AcceptanceSamplingSolutionDocument(backend: runMetadata(for: model), model: model, solution: solution) }
}

public struct NativeEducationalAcceptanceSamplingBackend: AcceptanceSamplingBackend {
    public init() {}
    public var capabilities: SolverCapabilities { SolverCapabilities(backendKind: .nativeEducational, solves: true, validates: true, exportsStructuredSolution: true, notes: ["Exact binomial single- and double-sampling plan evaluation."]) }
    public func solve(_ model: AcceptanceSamplingModelEnvelope, options _: SolverOptions = SolverOptions()) throws -> AcceptanceSamplingSolution { try AcceptanceSamplingSolver.solve(model) }
    public func runMetadata(for model: AcceptanceSamplingModelEnvelope) -> SolverRunMetadata { SolverRunMetadata(backendKind: .nativeEducational, algorithm: model.kind == .single ? "binomialSingleSamplingEvaluation" : "binomialDoubleSamplingEvaluation", exactness: .exact, notes: ["Double-plan n2 is the additional second sample and c2 is the cumulative defect acceptance limit; rejected lots use rectifying-inspection ATI/AOQ conventions."]) }
}

public struct ValidateOnlyAcceptanceSamplingBackend: AcceptanceSamplingBackend {
    public init() {}
    public var capabilities: SolverCapabilities { SolverCapabilities(backendKind: .validateOnly, solves: false, validates: true, exportsStructuredSolution: false) }
    public func solve(_ model: AcceptanceSamplingModelEnvelope, options _: SolverOptions = SolverOptions()) throws -> AcceptanceSamplingSolution { throw AcceptanceSamplingError.invalidModel("validateOnly backend does not evaluate acceptance-sampling plans") }
    public func runMetadata(for _: AcceptanceSamplingModelEnvelope) -> SolverRunMetadata { SolverRunMetadata(backendKind: .validateOnly, algorithm: "validationOnly", exactness: .exact) }
}

public enum AcceptanceSamplingBackends {
    public static func backend(for kind: SolverBackendKind) -> (any AcceptanceSamplingBackend)? { switch kind { case .nativeEducational: NativeEducationalAcceptanceSamplingBackend(); case .validateOnly: ValidateOnlyAcceptanceSamplingBackend(); case .externalHighPerformance: nil } }
}

public enum AcceptanceSamplingJSON {
    public static func encodeModel(_ value: AcceptanceSamplingModelEnvelope) throws -> Data { try encoder.encode(value) }
    public static func decodeModel(from data: Data) throws -> AcceptanceSamplingModelEnvelope { try JSONDecoder().decode(AcceptanceSamplingModelEnvelope.self, from: data) }
    public static func encodeSolution(_ value: AcceptanceSamplingSolutionDocument) throws -> Data { try encoder.encode(value) }
    public static func decodeSolution(from data: Data) throws -> AcceptanceSamplingSolutionDocument { try JSONDecoder().decode(AcceptanceSamplingSolutionDocument.self, from: data) }
    public static func encodeValidation(_ value: AcceptanceSamplingValidationDocument) throws -> Data { try encoder.encode(value) }
    private static var encoder: JSONEncoder { let value = JSONEncoder(); value.outputFormatting = [.prettyPrinted, .sortedKeys]; return value }
}
