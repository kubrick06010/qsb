import Foundation

public enum LegacyModelFamily: String, Codable, CaseIterable, Sendable {
    case acceptanceSampling
    case aggregatePlanning
    case decisionAnalysis
    case dynamicProgramming
    case facilities
    case forecasting
    case goalProgramming
    case inventory
    case linearProgramming
    case markov
    case materialRequirementsPlanning
    case network
    case nonlinearProgramming
    case projectScheduling
    case quadraticProgramming
    case qualityControl
    case queuing
    case scheduling
    case simulation
}

public struct LegacyModelImportResult: Equatable, Sendable {
    public let family: LegacyModelFamily
    public let sourceFileName: String
    public let restoredFileName: String
    public let normalizedJSON: Data

    public init(
        family: LegacyModelFamily,
        sourceFileName: String,
        restoredFileName: String,
        normalizedJSON: Data
    ) {
        self.family = family
        self.sourceFileName = sourceFileName
        self.restoredFileName = restoredFileName
        self.normalizedJSON = normalizedJSON
    }
}

public enum LegacyModelImportError: Error, CustomStringConvertible {
    case referenceOnly(fileName: String, role: String)
    case unsupportedFile(fileName: String, extensionCode: String)
    case invalidModel(fileName: String, family: LegacyModelFamily, underlying: any Error)

    public var description: String {
        switch self {
        case .referenceOnly(let fileName, let role):
            "\(fileName) is a reference-only \(role), not an importable model"
        case .unsupportedFile(let fileName, let extensionCode):
            "Unsupported legacy model file \(fileName) (type \(extensionCode))"
        case .invalidModel(let fileName, let family, let underlying):
            "Could not import \(fileName) as \(family.rawValue): \(underlying)"
        }
    }
}

public enum LegacyModelImporter {
    public static func importModel(at url: URL) throws -> LegacyModelImportResult {
        try importModel(
            from: Data(contentsOf: url),
            fileName: url.lastPathComponent
        )
    }

    public static func importModel(
        from data: Data,
        fileName: String
    ) throws -> LegacyModelImportResult {
        let inventory = try LegacyFixtureInventory.entry(for: data, fileName: fileName)
        if inventory.supportStatus == .referenceOnly {
            throw LegacyModelImportError.referenceOnly(
                fileName: fileName,
                role: inventory.role
            )
        }

        guard let family = family(for: inventory.extensionCode) else {
            throw LegacyModelImportError.unsupportedFile(
                fileName: fileName,
                extensionCode: inventory.extensionCode
            )
        }

        do {
            let expanded = try LegacyCompressedFile.expandedData(from: data)
            let normalizedJSON = try normalize(
                expanded,
                as: family
            )
            return LegacyModelImportResult(
                family: family,
                sourceFileName: fileName,
                restoredFileName: inventory.restoredFileName,
                normalizedJSON: normalizedJSON
            )
        } catch let error as LegacyModelImportError {
            throw error
        } catch {
            throw LegacyModelImportError.invalidModel(
                fileName: fileName,
                family: family,
                underlying: error
            )
        }
    }

    private static func family(for extensionCode: String) -> LegacyModelFamily? {
        switch extensionCode.uppercased() {
        case "AP": .aggregatePlanning
        case "AS", "ASA": .acceptanceSampling
        case "CP", "CPM": .projectScheduling
        case "DA": .decisionAnalysis
        case "DP": .dynamicProgramming
        case "FC": .forecasting
        case "FL": .facilities
        case "GP": .goalProgramming
        case "IT", "ITS": .inventory
        case "JO", "JOB": .scheduling
        case "LP": .linearProgramming
        case "MK", "MKP": .markov
        case "MRP": .materialRequirementsPlanning
        case "NE", "NET": .network
        case "NL", "NLP": .nonlinearProgramming
        case "QA": .queuing
        case "QC": .qualityControl
        case "QP": .quadraticProgramming
        case "QS", "QSS": .simulation
        default: nil
        }
    }

    private static func normalize(
        _ data: Data,
        as family: LegacyModelFamily
    ) throws -> Data {
        switch family {
        case .acceptanceSampling:
            return try AcceptanceSamplingJSON.encodeModel(WinQSBAcceptanceSamplingParser.parse(from: data))
        case .aggregatePlanning:
            return try AggregatePlanningJSON.encodeModel(WinQSBAggregatePlanningParser.parse(from: data))
        case .decisionAnalysis:
            return try DecisionAnalysisModelJSON.encodeModel(WinQSBDecisionAnalysisParser.parseModelEnvelope(from: data))
        case .dynamicProgramming:
            return try DynamicProgrammingModelJSON.encodeModel(WinQSBDynamicProgrammingParser.parseModelEnvelope(from: data))
        case .facilities:
            return try FacilitiesModelJSON.encodeModel(WinQSBFacilitiesParser.parseModelEnvelope(from: data))
        case .forecasting:
            let model = try WinQSBForecastingParser.parseModelEnvelope(from: data)
            let method: ForecastingMethod = model.kind == .regression
                ? .ordinaryLeastSquares
                : .linearTrend
            return try ForecastingModelJSON.encodeRequest(
                ForecastingRequest(model: model, method: method)
            )
        case .goalProgramming:
            return try GoalProgrammingJSON.encodeModel(WinQSBGoalProgrammingParser.parse(from: data))
        case .inventory:
            return try InventoryModelJSON.encodeModel(WinQSBInventoryParser.parseModelEnvelope(from: data))
        case .linearProgramming:
            return try LinearProgramJSON.encodeProgram(WinQSBMatrixParser.parseLP(from: data))
        case .markov:
            return try MarkovJSON.encodeRequest(
                MarkovAnalysisRequest(model: WinQSBMarkovParser.parse(from: data))
            )
        case .materialRequirementsPlanning:
            return try MaterialRequirementsPlanningJSON.encodeModel(WinQSBMaterialRequirementsPlanningParser.parse(from: data))
        case .network:
            return try NetworkModelJSON.encodeModel(WinQSBNetworkParser.parseModelEnvelope(from: data))
        case .nonlinearProgramming:
            return try NonlinearProgrammingJSON.encodeModel(WinQSBNonlinearProgrammingParser.parse(from: data))
        case .projectScheduling:
            return try ProjectSchedulingJSON.encodeModel(WinQSBProjectSchedulingParser.parseModelEnvelope(from: data))
        case .quadraticProgramming:
            return try QuadraticProgrammingJSON.encodeModel(WinQSBQuadraticProgrammingParser.parse(from: data))
        case .qualityControl:
            return try QualityControlJSON.encodeModel(WinQSBQualityControlParser.parse(from: data))
        case .queuing:
            return try QueuingModelJSON.encodeModel(WinQSBQueuingParser.parseModelEnvelope(from: data))
        case .scheduling:
            return try SchedulingModelJSON.encodeModel(WinQSBSchedulingParser.parseModelEnvelope(from: data))
        case .simulation:
            return try SimulationJSON.encodeModel(WinQSBSimulationParser.parse(from: data))
        }
    }
}
