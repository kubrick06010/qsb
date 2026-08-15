import Foundation
import Testing
@testable import QSBCore

@Test func inventoriesWinQSBReferenceFixtures() throws {
    let entries = try LegacyFixtureInventory.scanDirectory(at: legacyReferenceURL())
    let entriesByName = Dictionary(uniqueKeysWithValues: entries.map { ($0.fileName, $0) })

    #expect(entries.count > 100)
    #expect(!entries.contains { $0.supportStatus == .unknown })

    let lp = try #require(entriesByName["LP.LP_"])
    #expect(lp.restoredFileName == "LP.LP")
    #expect(lp.compressionFormat == .legacySZDD)
    #expect(lp.extensionCode == "LP")
    #expect(lp.family == "Linear/integer programming")
    #expect(lp.supportStatus == .verified)
    #expect(lp.supportedCommands.contains("qsb solve-lp"))

    let layout = try #require(entriesByName["LAYOUT.FL_"])
    #expect(layout.family == "Facilities and workflow")
    #expect(layout.supportStatus == .verified)
    #expect(layout.supportedCommands.contains("qsb solve-layout"))
    #expect(layout.supportedCommands.contains("qsb solve-facilities-json"))

    let assignment = try #require(entriesByName["ASSIMENT.NE_"])
    #expect(assignment.restoredFileName == "ASSIMENT.NET")
    #expect(assignment.family == "Network models")
    #expect(assignment.supportStatus == .verified)
    #expect(assignment.supportedCommands.contains("qsb solve-assignment"))

    let mm1Queue = try #require(entriesByName["QUEUE1.QA_"])
    #expect(mm1Queue.supportStatus == .verified)
    #expect(mm1Queue.supportedCommands.contains("qsb solve-mm1-json"))
    #expect(mm1Queue.supportedCommands.contains("qsb validate-mm1"))

    let finiteQueue = try #require(entriesByName["QUEUE2.QA_"])
    #expect(finiteQueue.supportStatus == .verified)
    #expect(finiteQueue.supportedCommands.contains("qsb solve-finite-queue-json"))
    #expect(finiteQueue.supportedCommands.contains("qsb validate-finite-queue"))

    for fileName in ["C_CHART.QC_", "P_CHART.QC_", "VARIABLE.QC_", "PARETO.QC_", "PROBPLOT.QC_"] {
        let qualityControl = try #require(entriesByName[fileName])
        #expect(qualityControl.family == "Quality control")
        #expect(qualityControl.supportStatus == .verified)
        #expect(qualityControl.supportedCommands.contains("qsb solve-quality-json"))
    }

    for fileName in ["APLP.AP_", "APSIMPLE.AP_", "APTRP.AP_"] {
        let aggregatePlanning = try #require(entriesByName[fileName])
        #expect(aggregatePlanning.family == "Aggregate planning")
        #expect(aggregatePlanning.supportStatus == .verified)
        #expect(aggregatePlanning.supportedCommands.contains("qsb solve-aggregate-json"))
    }

    let mrp = try #require(entriesByName["QSB.MR_"])
    #expect(mrp.restoredFileName == "QSB.MRP")
    #expect(mrp.family == "Material requirements planning")
    #expect(mrp.supportStatus == .verified)
    #expect(mrp.supportedCommands.contains("qsb solve-mrp-json"))

    for fileName in ["CRSQ.IT_", "CRSS.IT_", "PRRS.IT_", "PRRSS.IT_"] {
        let stochasticInventory = try #require(entriesByName[fileName])
        #expect(stochasticInventory.family == "Inventory theory")
        #expect(stochasticInventory.supportStatus == .verified)
        #expect(stochasticInventory.supportedCommands.contains("qsb solve-stochastic-inventory"))
    }

    for fileName in ["QP.QP_", "QPNORMAL.QP_", "IQP.QP_"] {
        let quadratic = try #require(entriesByName[fileName])
        #expect(quadratic.family == "Quadratic/integer quadratic programming")
        #expect(quadratic.supportStatus == .verified)
        #expect(quadratic.supportedCommands.contains("qsb solve-qp-json"))
    }

    for fileName in ["NLP1.NL_", "NLP2.NL_", "NLP3.NL_"] {
        let nonlinear = try #require(entriesByName[fileName])
        #expect(nonlinear.family == "Nonlinear programming")
        #expect(nonlinear.supportStatus == .verified)
        #expect(nonlinear.supportedCommands.contains("qsb solve-nlp-json"))
    }

    for fileName in ["QSS1.QS_", "QSS2.QS_", "QSS3.QS_", "QSSGRAPH.QS_"] {
        let simulation = try #require(entriesByName[fileName])
        #expect(simulation.family == "Simulation")
        #expect(simulation.supportStatus == .verified)
        #expect(simulation.supportedCommands.contains("qsb solve-simulation-json"))
    }

    let executable = try #require(entriesByName["FLL.EX_"])
    #expect(executable.family == "WinQSB application")
    #expect(executable.role == "application executable")
    #expect(executable.supportStatus == .referenceOnly)

    let json = try LegacyFixtureInventory.encode(entries)
    let text = try #require(String(data: json, encoding: .utf8))
    #expect(text.contains("\"fileName\" : \"LP.LP_\""))
    #expect(text.contains("\"supportStatus\" : \"verified\""))
}

@Test func rejectsEveryReferenceOnlyLegacyArtifactAsNonModel() throws {
    let entries = try LegacyFixtureInventory.scanDirectory(at: legacyReferenceURL())
    let referenceOnly = entries.filter { $0.supportStatus == .referenceOnly }

    #expect(referenceOnly.count == 53)
    for entry in referenceOnly {
        do {
            _ = try LegacyModelImporter.importModel(
                at: legacyFixtureURL(entry.fileName)
            )
            Issue.record("Expected \(entry.fileName) to remain reference-only")
        } catch LegacyModelImportError.referenceOnly(let fileName, _) {
            #expect(fileName == entry.fileName)
        } catch {
            Issue.record("Unexpected import error for \(entry.fileName): \(error)")
        }
    }
}

@Test func exhaustivelyClassifiesCurrentFacilitiesPayload() throws {
    let entries = try LegacyFixtureInventory.scanDirectory(at: legacyReferenceURL())
    let facilitiesPayload = entries.filter {
        $0.fileName.hasPrefix("FLL") || $0.fileName.hasSuffix(".FL_")
    }
    let byName = Dictionary(uniqueKeysWithValues: facilitiesPayload.map { ($0.fileName, $0) })

    #expect(Set(byName.keys) == [
        "FLL.EX_",
        "FLLHELP.HL_",
        "LAYOUT.FL_",
        "LINEBAL.FL_",
        "LOCATION.FL_"
    ])

    for fileName in ["LAYOUT.FL_", "LINEBAL.FL_", "LOCATION.FL_"] {
        let fixture = try #require(byName[fileName])
        #expect(fixture.family == "Facilities and workflow")
        #expect(fixture.role == "verified legacy model fixture")
        #expect(fixture.supportStatus == .verified)
        #expect(fixture.supportedCommands.contains("qsb export-facilities-json"))
        #expect(fixture.supportedCommands.contains("qsb solve-facilities-json"))
    }

    for fileName in ["FLL.EX_", "FLLHELP.HL_"] {
        let artifact = try #require(byName[fileName])
        #expect(artifact.supportStatus == .referenceOnly)
        #expect(artifact.supportedCommands.isEmpty)
    }
}

