import AppKit
import SwiftUI

enum SpreadsheetClipboard {
    static func read() throws -> String {
        guard let text = NSPasteboard.general.string(forType: .string) else {
            throw SpreadsheetTransferError.emptyClipboard
        }
        return text
    }

    static func write(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

struct SpreadsheetTransferActions: View {
    let subject: String
    let issue: String?
    let paste: () -> Void
    let copy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Button("Paste Table", systemImage: "doc.on.clipboard", action: paste)
                    .help("Replace \(subject) from Excel, Numbers, LibreOffice, TSV, or CSV after validating the complete range")
                    .accessibilityHint("Checks every pasted cell before replacing \(subject)")
                Button("Copy Table", systemImage: "doc.on.doc", action: copy)
                    .help("Copy \(subject) as tab-separated text for a spreadsheet")
                Text("Excel, Numbers, LibreOffice, TSV, or CSV")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let issue {
                Label(issue, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Table import error: \(issue)")
            }
        }
    }
}
