import Foundation
import Testing
@testable import QSBCLI
@testable import QSBCore

struct GenericRoutingTests {
    @Test("generic routing validates unrelated legacy families")
    func validatesLegacyFamilies() throws {
        try QSBCLI.genericValidate(path: legacyFixtureURL("LP.LP_").path)
        try QSBCLI.genericValidate(path: legacyFixtureURL("LOTSIZE.IT_").path)
        try QSBCLI.genericValidate(path: legacyFixtureURL("LOCATION.FL_").path)
    }

    @Test("generic solve rejects unavailable external backends explicitly")
    func rejectsUnavailableExternalBackend() {
        #expect(throws: QSBCLI.GenericRoutingError.self) {
            try QSBCLI.genericSolve(path: legacyFixtureURL("LP.LP_").path, backend: .externalHighPerformance)
        }
    }

    @Test("generic solve accepts normalized JSON through the same route")
    func solvesNormalizedJSON() throws {
        let imported = try LegacyModelImporter.importModel(at: legacyFixtureURL("LP.LP_"))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("qsb-generic-routing-\(UUID().uuidString).json")
        try imported.normalizedJSON.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        try QSBCLI.genericSolveJSON(path: url.path, backend: .validateOnly)
    }
}
