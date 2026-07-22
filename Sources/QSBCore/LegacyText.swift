import Foundation

public extension Data {
    /// Decodes the byte-preserving text encoding used by WinQSB payloads.
    var legacyLatin1String: String? {
        String(String.UnicodeScalarView(map { Unicode.Scalar(UInt32($0))! }))
    }
}
