import Foundation

public enum LegacyFixtureCompressionFormat: String, Codable, Sendable {
    case legacySZDD
    case plain
}

public enum LegacyFixtureSupportStatus: String, Codable, Sendable {
    case verified
    case familyPartial
    case referenceOnly
    case unknown
}

public struct LegacyFixtureInventoryEntry: Codable, Equatable, Sendable {
    public let fileName: String
    public let restoredFileName: String
    public let compressionFormat: LegacyFixtureCompressionFormat
    public let byteSize: Int
    public let expandedSize: Int?
    public let extensionCode: String
    public let family: String
    public let role: String
    public let supportStatus: LegacyFixtureSupportStatus
    public let supportedCommands: [String]
    public let notes: [String]

    public init(
        fileName: String,
        restoredFileName: String,
        compressionFormat: LegacyFixtureCompressionFormat,
        byteSize: Int,
        expandedSize: Int?,
        extensionCode: String,
        family: String,
        role: String,
        supportStatus: LegacyFixtureSupportStatus,
        supportedCommands: [String] = [],
        notes: [String] = []
    ) {
        self.fileName = fileName
        self.restoredFileName = restoredFileName
        self.compressionFormat = compressionFormat
        self.byteSize = byteSize
        self.expandedSize = expandedSize
        self.extensionCode = extensionCode
        self.family = family
        self.role = role
        self.supportStatus = supportStatus
        self.supportedCommands = supportedCommands
        self.notes = notes
    }
}

public enum LegacyFixtureInventory {
    public static func scanDirectory(at directoryURL: URL) throws -> [LegacyFixtureInventoryEntry] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return try urls
            .filter { url in
                let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
                return values?.isRegularFile == true
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { try entry(for: $0) }
    }

    public static func entry(forFileAt url: URL) throws -> LegacyFixtureInventoryEntry {
        try entry(for: url)
    }

    public static func entry(
        for data: Data,
        fileName: String
    ) throws -> LegacyFixtureInventoryEntry {
        try makeEntry(data: data, fileName: fileName)
    }

    public static func encode(_ entries: [LegacyFixtureInventoryEntry]) throws -> Data {
        try encoder.encode(entries)
    }

    private static func entry(for url: URL) throws -> LegacyFixtureInventoryEntry {
        let data = try Data(contentsOf: url)
        return try makeEntry(data: data, fileName: url.lastPathComponent)
    }

    private static func makeEntry(
        data: Data,
        fileName: String
    ) throws -> LegacyFixtureInventoryEntry {

        let compressionFormat: LegacyFixtureCompressionFormat
        let restoredFileName: String
        let expandedSize: Int?

        if LegacyCompressedFile.isCompressed(data) {
            let compressed = try LegacyCompressedFile(data: data)
            compressionFormat = .legacySZDD
            restoredFileName = URL(
                fileURLWithPath: LegacyCompressedFile.restoredFilename(
                    for: fileName,
                    lastCharacter: compressed.originalLastCharacter
                )
            ).lastPathComponent
            expandedSize = compressed.expandedSize
        } else {
            compressionFormat = .plain
            restoredFileName = fileName
            expandedSize = nil
        }

        let extensionCode = extensionCode(for: restoredFileName)
        let classification = classify(restoredFileName: restoredFileName, extensionCode: extensionCode)

        return LegacyFixtureInventoryEntry(
            fileName: fileName,
            restoredFileName: restoredFileName,
            compressionFormat: compressionFormat,
            byteSize: data.count,
            expandedSize: expandedSize,
            extensionCode: extensionCode,
            family: classification.family,
            role: classification.role,
            supportStatus: classification.supportStatus,
            supportedCommands: classification.supportedCommands,
            notes: classification.notes
        )
    }

    private static func classify(
        restoredFileName: String,
        extensionCode: String
    ) -> FixtureClassification {
        let normalizedName = restoredFileName.uppercased()
        if let verified = verifiedFixtures[normalizedName] {
            return verified
        }

        if let resource = resourceExtensions[extensionCode] {
            return resource
        }

        if let family = modelFamilies[extensionCode] {
            return FixtureClassification(
                family: family,
                role: "legacy model fixture",
                supportStatus: .familyPartial,
                supportedCommands: [],
                notes: [
                    "Model family is recognized, but this fixture is not yet covered by a verified parser/solver command."
                ]
            )
        }

        return FixtureClassification(
            family: "Unknown",
            role: "reference artifact",
            supportStatus: .unknown,
            supportedCommands: [],
            notes: [
                "File type has not yet been classified for compatibility work."
            ]
        )
    }

    private static func extensionCode(for fileName: String) -> String {
        let extensionText = URL(fileURLWithPath: fileName).pathExtension
        return extensionText.isEmpty ? "(none)" : extensionText.uppercased()
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private struct FixtureClassification {
        let family: String
        let role: String
        let supportStatus: LegacyFixtureSupportStatus
        let supportedCommands: [String]
        let notes: [String]
    }

    private static let modelFamilies: [String: String] = [
        "AP": "Aggregate planning",
        "AS": "Acceptance sampling",
        "ASA": "Acceptance sampling",
        "CP": "PERT/CPM",
        "CPM": "PERT/CPM",
        "DA": "Decision analysis",
        "DP": "Dynamic programming",
        "FC": "Forecasting",
        "FL": "Facilities and workflow",
        "GP": "Goal programming",
        "IT": "Inventory theory",
        "ITS": "Inventory theory",
        "JO": "Scheduling",
        "JOB": "Scheduling",
        "LP": "Linear/integer programming",
        "MK": "Markov processes",
        "MKP": "Markov processes",
        "MRP": "Material requirements planning",
        "NE": "Network models",
        "NET": "Network models",
        "NL": "Nonlinear programming",
        "NLP": "Nonlinear programming",
        "QA": "Queuing analysis",
        "QC": "Quality control",
        "QP": "Quadratic/integer quadratic programming",
        "QS": "Simulation",
        "QSS": "Simulation"
    ]

    private static let resourceExtensions: [String: FixtureClassification] = [
        "DL": FixtureClassification(
            family: "Runtime support",
            role: "support library",
            supportStatus: .referenceOnly,
            supportedCommands: [],
            notes: ["Preserved to keep the original WinQSB payload intact."]
        ),
        "DLL": FixtureClassification(
            family: "Runtime support",
            role: "support library",
            supportStatus: .referenceOnly,
            supportedCommands: [],
            notes: ["Preserved to keep the original WinQSB payload intact."]
        ),
        "EX": FixtureClassification(
            family: "WinQSB application",
            role: "application executable",
            supportStatus: .referenceOnly,
            supportedCommands: [],
            notes: ["Original executable retained only as a compatibility reference."]
        ),
        "EXE": FixtureClassification(
            family: "WinQSB application",
            role: "application executable",
            supportStatus: .referenceOnly,
            supportedCommands: [],
            notes: ["Original executable retained only as a compatibility reference."]
        ),
        "HL": FixtureClassification(
            family: "WinQSB help",
            role: "help file",
            supportStatus: .referenceOnly,
            supportedCommands: [],
            notes: ["Original help content retained as a reference artifact."]
        ),
        "HLP": FixtureClassification(
            family: "WinQSB help",
            role: "help file",
            supportStatus: .referenceOnly,
            supportedCommands: [],
            notes: ["Original help content retained as a reference artifact."]
        ),
        "LST": FixtureClassification(
            family: "Installer metadata",
            role: "installer file list",
            supportStatus: .referenceOnly,
            supportedCommands: [],
            notes: ["Original installer metadata retained as a reference artifact."]
        ),
        "MD": FixtureClassification(
            family: "Project documentation",
            role: "documentation",
            supportStatus: .referenceOnly,
            supportedCommands: [],
            notes: ["Local documentation for the preserved reference directory."]
        ),
        "PDF": FixtureClassification(
            family: "WinQSB manual",
            role: "manual",
            supportStatus: .referenceOnly,
            supportedCommands: [],
            notes: ["Original manual retained as a reference artifact."]
        ),
        "VB": FixtureClassification(
            family: "Runtime support",
            role: "Visual Basic support file",
            supportStatus: .referenceOnly,
            supportedCommands: [],
            notes: ["Preserved to keep the original WinQSB payload intact."]
        ),
        "VBX": FixtureClassification(
            family: "Runtime support",
            role: "Visual Basic support file",
            supportStatus: .referenceOnly,
            supportedCommands: [],
            notes: ["Preserved to keep the original WinQSB payload intact."]
        )
    ]

    private static let verifiedFixtures: [String: FixtureClassification] = [
        "APLP.AP": verified(family: "Aggregate planning", commands: ["qsb solve-aggregate", "qsb validate-aggregate", "qsb export-aggregate-json", "qsb solve-aggregate-json", "qsb validate-aggregate-json"]),
        "APSIMPLE.AP": verified(family: "Aggregate planning", commands: ["qsb solve-aggregate", "qsb validate-aggregate", "qsb export-aggregate-json", "qsb solve-aggregate-json", "qsb validate-aggregate-json"]),
        "APTRP.AP": verified(family: "Aggregate planning", commands: ["qsb solve-aggregate", "qsb validate-aggregate", "qsb export-aggregate-json", "qsb solve-aggregate-json", "qsb validate-aggregate-json"]),
        "ASSIMENT.NET": verified(
            family: "Network models",
            commands: ["qsb solve-assignment", "qsb validate-assignment", "qsb export-network-json", "qsb solve-network-json", "qsb validate-network-json"]
        ),
        "ASA1.ASA": verified(family: "Acceptance sampling", commands: ["qsb solve-acceptance", "qsb validate-acceptance", "qsb export-acceptance-json", "qsb solve-acceptance-json", "qsb validate-acceptance-json"]),
        "ASA2.ASA": verified(family: "Acceptance sampling", commands: ["qsb solve-acceptance", "qsb validate-acceptance", "qsb export-acceptance-json", "qsb solve-acceptance-json", "qsb validate-acceptance-json"]),
        "BAYESIAN.DA": verified(family: "Decision analysis", commands: ["qsb solve-bayesian", "qsb validate-bayesian", "qsb export-decision-json", "qsb solve-decision-json", "qsb validate-decision-json"]),
        "CPM.CPM": verified(family: "PERT/CPM", commands: ["qsb solve-cpm", "qsb validate-cpm", "qsb export-project-json", "qsb solve-project-json", "qsb validate-project-json"]),
        "CPMGRAPH.CPM": verified(family: "PERT/CPM", commands: ["qsb solve-cpm", "qsb validate-cpm", "qsb export-project-json", "qsb solve-project-json", "qsb validate-project-json"]),
        "CRSQ.ITS": verified(family: "Inventory theory", commands: ["qsb solve-stochastic-inventory", "qsb validate-stochastic-inventory", "qsb export-inventory-json", "qsb solve-inventory-json", "qsb validate-inventory-json"]),
        "CRSS.ITS": verified(family: "Inventory theory", commands: ["qsb solve-stochastic-inventory", "qsb validate-stochastic-inventory", "qsb export-inventory-json", "qsb solve-inventory-json", "qsb validate-inventory-json"]),
        "C_CHART.QC": verified(family: "Quality control", commands: ["qsb solve-quality", "qsb validate-quality", "qsb export-quality-json", "qsb solve-quality-json", "qsb validate-quality-json"]),
        "DISCOUNT.ITS": verified(
            family: "Inventory theory",
            commands: ["qsb solve-discount-eoq", "qsb validate-discount-eoq", "qsb export-inventory-json", "qsb solve-inventory-json"]
        ),
        "DTREE.DA": verified(family: "Decision analysis", commands: ["qsb solve-decision-tree", "qsb validate-decision-tree", "qsb export-decision-json", "qsb solve-decision-json", "qsb validate-decision-json"]),
        "EOQ.ITS": verified(
            family: "Inventory theory",
            commands: ["qsb solve-eoq", "qsb validate-eoq", "qsb export-inventory-json", "qsb solve-inventory-json"]
        ),
        "FLOWSHOP.JOB": verified(
            family: "Scheduling",
            commands: ["qsb solve-flowshop", "qsb validate-flowshop", "qsb solve-flowshop-json", "qsb export-scheduling-json", "qsb solve-scheduling-json", "qsb validate-scheduling-json"]
        ),
        "GAME.DA": verified(
            family: "Decision analysis",
            commands: ["qsb solve-game", "qsb validate-game", "qsb export-decision-json", "qsb solve-decision-json", "qsb validate-decision-json"]
        ),
        "GP.GP": verified(family: "Goal programming", commands: ["qsb solve-goal", "qsb validate-goal", "qsb export-goal-json", "qsb solve-goal-json", "qsb validate-goal-json"]),
        "GPNORMAL.GP": verified(family: "Goal programming", commands: ["qsb solve-goal", "qsb validate-goal", "qsb export-goal-json", "qsb solve-goal-json", "qsb validate-goal-json"]),
        "ILP.LP": verified(
            family: "Linear/integer programming",
            commands: ["qsb solve-ilp", "qsb validate-lp", "qsb export-json"]
        ),
        "IGP.GP": verified(family: "Goal programming", commands: ["qsb solve-goal", "qsb validate-goal", "qsb export-goal-json", "qsb solve-goal-json", "qsb validate-goal-json"]),
        "IQP.QP": verified(family: "Quadratic/integer quadratic programming", commands: ["qsb solve-qp", "qsb validate-qp", "qsb export-qp-json", "qsb solve-qp-json", "qsb validate-qp-json"]),
        "JOBSHOP.JOB": verified(
            family: "Scheduling",
            commands: ["qsb solve-jobshop", "qsb validate-jobshop", "qsb solve-jobshop-json", "qsb export-scheduling-json", "qsb solve-scheduling-json", "qsb validate-scheduling-json"]
        ),
        "KNAPSACK.DP": verified(family: "Dynamic programming", commands: ["qsb solve-knapsack", "qsb validate-knapsack", "qsb export-dp-json", "qsb solve-dp-json"]),
        "LAYOUT.FL": verified(
            family: "Facilities and workflow",
            commands: [
                "qsb solve-layout",
                "qsb validate-layout",
                "qsb export-layout-json",
                "qsb export-facilities-json",
                "qsb solve-facilities-json"
            ]
        ),
        "LINEBAL.FL": verified(
            family: "Facilities and workflow",
            commands: [
                "qsb solve-line-balancing",
                "qsb validate-line-balancing",
                "qsb export-line-balancing-json",
                "qsb export-facilities-json",
                "qsb solve-facilities-json"
            ]
        ),
        "LINEREG.FC": verified(family: "Forecasting", commands: ["qsb solve-regression", "qsb export-forecast-json", "qsb solve-forecast-json", "qsb validate-forecast-json"]),
        "LOCATION.FL": verified(
            family: "Facilities and workflow",
            commands: [
                "qsb solve-location",
                "qsb validate-location",
                "qsb export-location-json",
                "qsb export-facilities-json",
                "qsb solve-facilities-json"
            ]
        ),
        "LOTSIZE.ITS": verified(
            family: "Inventory theory",
            commands: ["qsb solve-lot-sizing", "qsb validate-lot-sizing", "qsb export-inventory-json", "qsb solve-inventory-json"]
        ),
        "LP.LP": verified(
            family: "Linear/integer programming",
            commands: ["qsb solve-lp", "qsb validate-lp", "qsb export-json"]
        ),
        "LPNORMAL.LP": verified(
            family: "Linear/integer programming",
            commands: ["qsb solve-lp", "qsb validate-lp", "qsb export-json"]
        ),
        "MAXFLOW.NET": verified(
            family: "Network models",
            commands: ["qsb solve-maxflow", "qsb validate-maxflow", "qsb export-network-json", "qsb solve-network-json", "qsb validate-network-json"]
        ),
        "MKP1.MKP": verified(family: "Markov processes", commands: ["qsb solve-markov", "qsb validate-markov", "qsb export-markov-json", "qsb solve-markov-json", "qsb validate-markov-json"]),
        "MKP2.MKP": verified(family: "Markov processes", commands: ["qsb solve-markov", "qsb validate-markov", "qsb export-markov-json", "qsb solve-markov-json", "qsb validate-markov-json"]),
        "NETFLOW.NET": verified(
            family: "Network models",
            commands: ["qsb solve-netflow", "qsb validate-netflow", "qsb export-network-json", "qsb solve-network-json", "qsb validate-network-json"]
        ),
        "NLP1.NLP": verified(family: "Nonlinear programming", commands: ["qsb solve-nlp", "qsb validate-nlp", "qsb export-nlp-json", "qsb solve-nlp-json", "qsb validate-nlp-json"]),
        "NLP2.NLP": verified(family: "Nonlinear programming", commands: ["qsb solve-nlp", "qsb validate-nlp", "qsb export-nlp-json", "qsb solve-nlp-json", "qsb validate-nlp-json"]),
        "NLP3.NLP": verified(family: "Nonlinear programming", commands: ["qsb solve-nlp", "qsb validate-nlp", "qsb export-nlp-json", "qsb solve-nlp-json", "qsb validate-nlp-json"]),
        "QSS1.QS": verified(family: "Simulation", commands: ["qsb solve-simulation", "qsb validate-simulation", "qsb export-simulation-json", "qsb solve-simulation-json", "qsb validate-simulation-json"]),
        "QSS2.QS": verified(family: "Simulation", commands: ["qsb solve-simulation", "qsb validate-simulation", "qsb export-simulation-json", "qsb solve-simulation-json", "qsb validate-simulation-json"]),
        "QSS3.QS": verified(family: "Simulation", commands: ["qsb solve-simulation", "qsb validate-simulation", "qsb export-simulation-json", "qsb solve-simulation-json", "qsb validate-simulation-json"]),
        "QSSGRAPH.QS": verified(family: "Simulation", commands: ["qsb solve-simulation", "qsb validate-simulation", "qsb export-simulation-json", "qsb solve-simulation-json", "qsb validate-simulation-json"]),
        "NEWSBOY.ITS": verified(
            family: "Inventory theory",
            commands: ["qsb solve-newsboy", "qsb validate-newsboy", "qsb export-inventory-json", "qsb solve-inventory-json"]
        ),
        "PAYOFF.DA": verified(family: "Decision analysis", commands: ["qsb solve-payoff", "qsb validate-payoff", "qsb export-decision-json", "qsb solve-decision-json", "qsb validate-decision-json"]),
        "PARETO.QC": verified(family: "Quality control", commands: ["qsb solve-quality", "qsb validate-quality", "qsb export-quality-json", "qsb solve-quality-json", "qsb validate-quality-json"]),
        "PERT.CPM": verified(family: "PERT/CPM", commands: ["qsb solve-pert", "qsb validate-pert", "qsb export-project-json", "qsb solve-project-json", "qsb validate-project-json"]),
        "PERTGRPH.CPM": verified(family: "PERT/CPM", commands: ["qsb solve-pert", "qsb validate-pert", "qsb export-project-json", "qsb solve-project-json", "qsb validate-project-json"]),
        "PROBPLOT.QC": verified(family: "Quality control", commands: ["qsb solve-quality", "qsb validate-quality", "qsb export-quality-json", "qsb solve-quality-json", "qsb validate-quality-json"]),
        "PRODINVT.DP": verified(family: "Dynamic programming", commands: ["qsb solve-prod-inventory", "qsb validate-prod-inventory", "qsb export-dp-json", "qsb solve-dp-json"]),
        "PRRS.ITS": verified(family: "Inventory theory", commands: ["qsb solve-stochastic-inventory", "qsb validate-stochastic-inventory", "qsb export-inventory-json", "qsb solve-inventory-json", "qsb validate-inventory-json"]),
        "PRRSS.ITS": verified(family: "Inventory theory", commands: ["qsb solve-stochastic-inventory", "qsb validate-stochastic-inventory", "qsb export-inventory-json", "qsb solve-inventory-json", "qsb validate-inventory-json"]),
        "QUEUE1.QA": verified(
            family: "Queuing analysis",
            commands: ["qsb solve-mm1", "qsb solve-mm1-json", "qsb validate-mm1", "qsb export-queuing-json", "qsb solve-queuing-json", "qsb validate-queuing-json"]
        ),
        "QUEUE2.QA": verified(
            family: "Queuing analysis",
            commands: ["qsb solve-finite-queue", "qsb solve-finite-queue-json", "qsb validate-finite-queue", "qsb export-queuing-json", "qsb solve-queuing-json", "qsb validate-queuing-json"]
        ),
        "QSB.MRP": verified(family: "Material requirements planning", commands: ["qsb solve-mrp", "qsb validate-mrp", "qsb export-mrp-json", "qsb solve-mrp-json", "qsb validate-mrp-json"]),
        "QP.QP": verified(family: "Quadratic/integer quadratic programming", commands: ["qsb solve-qp", "qsb validate-qp", "qsb export-qp-json", "qsb solve-qp-json", "qsb validate-qp-json"]),
        "QPNORMAL.QP": verified(family: "Quadratic/integer quadratic programming", commands: ["qsb solve-qp", "qsb validate-qp", "qsb export-qp-json", "qsb solve-qp-json", "qsb validate-qp-json"]),
        "SALES.FC": verified(
            family: "Forecasting",
            commands: [
                "qsb solve-timeseries",
                "qsb solve-moving-average",
                "qsb solve-exp-smoothing",
                "qsb solve-seasonal",
                "qsb export-forecast-json",
                "qsb solve-forecast-json",
                "qsb validate-forecast-json"
            ]
        ),
        "P_CHART.QC": verified(family: "Quality control", commands: ["qsb solve-quality", "qsb validate-quality", "qsb export-quality-json", "qsb solve-quality-json", "qsb validate-quality-json"]),
        "SHTPATH.NET": verified(
            family: "Network models",
            commands: ["qsb solve-spp", "qsb validate-spp", "qsb export-network-json", "qsb solve-network-json", "qsb validate-network-json"]
        ),
        "SPANTREE.NET": verified(
            family: "Network models",
            commands: ["qsb solve-mst", "qsb validate-mst", "qsb export-network-json", "qsb solve-network-json", "qsb validate-network-json"]
        ),
        "STAGE.DP": verified(family: "Dynamic programming", commands: ["qsb solve-stagecoach", "qsb validate-stagecoach", "qsb export-dp-json", "qsb solve-dp-json"]),
        "TRNSPORT.NET": verified(
            family: "Network models",
            commands: [
                "qsb solve-transport",
                "qsb validate-transport",
                "qsb export-network-json",
                "qsb solve-network-json",
                "qsb validate-network-json"
            ]
        ),
        "TSP.NET": verified(
            family: "Network models",
            commands: ["qsb solve-tsp", "qsb validate-tsp", "qsb export-network-json", "qsb solve-network-json", "qsb validate-network-json"]
        ),
        "VARIABLE.QC": verified(family: "Quality control", commands: ["qsb solve-quality", "qsb validate-quality", "qsb export-quality-json", "qsb solve-quality-json", "qsb validate-quality-json"])
    ]

    private static func verified(family: String, commands: [String]) -> FixtureClassification {
        FixtureClassification(
            family: family,
            role: "verified legacy model fixture",
            supportStatus: .verified,
            supportedCommands: commands + ["qsb import-legacy-json"],
            notes: ["Covered by parser/solver regression tests."]
        )
    }
}
