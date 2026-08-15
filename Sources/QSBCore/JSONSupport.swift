import Foundation

/// Shared configuration for normalized JSON emitted by QSBCore.
/// Keeping this internal preserves each family's public JSON API while
/// ensuring deterministic output remains identical.
enum NormalizedJSONCoding {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
