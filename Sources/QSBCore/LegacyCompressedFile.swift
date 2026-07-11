import Foundation

public enum LegacyCompressionError: Error, CustomStringConvertible {
    case unsupportedHeader
    case unsupportedMode(UInt8)
    case truncatedReference
    case sizeMismatch(expected: Int, actual: Int)

    public var description: String {
        switch self {
        case .unsupportedHeader:
            "Unsupported legacy compression header"
        case .unsupportedMode(let mode):
            "Unsupported legacy compression mode: \(UnicodeScalar(mode))"
        case .truncatedReference:
            "Compressed stream ended in the middle of a reference"
        case .sizeMismatch(let expected, let actual):
            "Expanded size mismatch: expected \(expected), got \(actual)"
        }
    }
}

public struct LegacyCompressedFile {
    public let originalLastCharacter: UInt8
    public let expandedSize: Int
    public let expandedData: Data

    public static let signature = Array("SZDD".utf8) + [0x88, 0xf0, 0x27, 0x33]

    public init(data: Data) throws {
        guard data.count >= 14, Array(data.prefix(8)) == Self.signature else {
            throw LegacyCompressionError.unsupportedHeader
        }

        let mode = data[8]
        guard mode == UInt8(ascii: "A") else {
            throw LegacyCompressionError.unsupportedMode(mode)
        }

        originalLastCharacter = data[9]
        expandedSize = Int(data[10])
            | (Int(data[11]) << 8)
            | (Int(data[12]) << 16)
            | (Int(data[13]) << 24)
        expandedData = try Self.expand(Array(data.dropFirst(14)), expectedSize: expandedSize)
    }

    public static func isCompressed(_ data: Data) -> Bool {
        data.count >= 8 && Array(data.prefix(8)) == signature
    }

    public static func expandedData(from data: Data) throws -> Data {
        if isCompressed(data) {
            return try LegacyCompressedFile(data: data).expandedData
        }
        return data
    }

    public static func restoredFilename(for path: String, lastCharacter: UInt8) -> String {
        var url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent
        if name.hasSuffix("_") {
            let suffix = String(UnicodeScalar(lastCharacter)).uppercased()
            let prefix = String(name.dropLast())
            let restored = prefix.uppercased().hasSuffix(suffix) ? prefix : prefix + suffix
            url.deleteLastPathComponent()
            return url.appendingPathComponent(restored).path
        }
        return path
    }

    private static func expand(_ bytes: [UInt8], expectedSize: Int) throws -> Data {
        var ring = Array(repeating: UInt8(ascii: " "), count: 4096)
        var ringIndex = 4096 - 16
        var output: [UInt8] = []
        output.reserveCapacity(expectedSize)

        var index = 0
        while index < bytes.count && output.count < expectedSize {
            let flags = bytes[index]
            index += 1

            for bit in 0..<8 where output.count < expectedSize {
                let literal = (flags & (1 << bit)) != 0

                if literal {
                    guard index < bytes.count else { break }
                    let value = bytes[index]
                    index += 1
                    output.append(value)
                    ring[ringIndex] = value
                    ringIndex = (ringIndex + 1) & 0x0fff
                } else {
                    guard index + 1 < bytes.count else {
                        throw LegacyCompressionError.truncatedReference
                    }
                    let first = bytes[index]
                    let second = bytes[index + 1]
                    index += 2

                    let offset = Int(first) | (Int(second & 0xf0) << 4)
                    let length = Int(second & 0x0f) + 3

                    for copyIndex in 0..<length where output.count < expectedSize {
                        let value = ring[(offset + copyIndex) & 0x0fff]
                        output.append(value)
                        ring[ringIndex] = value
                        ringIndex = (ringIndex + 1) & 0x0fff
                    }
                }
            }
        }

        guard output.count == expectedSize else {
            throw LegacyCompressionError.sizeMismatch(expected: expectedSize, actual: output.count)
        }

        return Data(output)
    }
}
