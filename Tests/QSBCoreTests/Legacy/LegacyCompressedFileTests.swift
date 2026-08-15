import Foundation
import Testing
@testable import QSBCore

@Test func expandsSZDDLPFixture() throws {
    let url = legacyFixtureURL("LP.LP_")
    let data = try Data(contentsOf: url)

    let file = try LegacyCompressedFile(data: data)
    let text = try #require(file.expandedData.legacyLatin1String)

    #expect(file.expandedSize == 200)
    #expect(text.contains("LP\tMatrixFormat"))
    #expect(text.contains("LP Sample Problem"))
    #expect(text.contains("Maximize"))
}


