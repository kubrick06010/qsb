import Foundation
import Testing
@testable import QSBCore

func expectInvalidModel(_ json: String, containing expectedText: String) throws {
    do {
        _ = try LinearProgramJSON.decodeProgram(from: Data(json.utf8))
        Issue.record("Expected JSON model to be rejected")
    } catch LinearProgramError.invalidModel(let message) {
        #expect(message.contains(expectedText))
    }
}

