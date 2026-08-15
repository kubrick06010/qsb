import Foundation
func commonInventoryDiagnostics(
    title: String,
    timeUnit: String,
    codePrefix: String
) -> [ValidationDiagnostic] {
    var diagnostics: [ValidationDiagnostic] = []
    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        diagnostics.append(ValidationDiagnostic(
            severity: .warning,
            code: "\(codePrefix).title.empty",
            message: "Model title is empty.",
            path: "model.title"
        ))
    }
    if timeUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        diagnostics.append(errorDiagnostic(
            code: "\(codePrefix).timeUnit.empty",
            message: "Time unit must not be empty.",
            path: "model.timeUnit"
        ))
    }
    return diagnostics
}

func appendPositiveError(
    _ value: Double,
    name: String,
    path: String,
    codePrefix: String,
    to diagnostics: inout [ValidationDiagnostic]
) {
    guard value.isFinite, value > 0 else {
        diagnostics.append(errorDiagnostic(
            code: "\(codePrefix).\(path.split(separator: ".").last ?? "value").nonpositive",
            message: "\(name.capitalized) must be finite and positive.",
            path: path
        ))
        return
    }
}

func appendNonnegativeError(
    _ value: Double,
    name: String,
    path: String,
    codePrefix: String,
    to diagnostics: inout [ValidationDiagnostic]
) {
    guard value.isFinite, value >= 0 else {
        diagnostics.append(errorDiagnostic(
            code: "\(codePrefix).\(path.split(separator: ".").last ?? "value").negative",
            message: "\(name.capitalized) must be finite and nonnegative.",
            path: path
        ))
        return
    }
}

func errorDiagnostic(code: String, message: String, path: String) -> ValidationDiagnostic {
    ValidationDiagnostic(severity: .error, code: code, message: message, path: path)
}

func throwFirstInventoryValidationError(_ diagnostics: [ValidationDiagnostic]) throws {
    if let diagnostic = diagnostics.first(where: { $0.severity == .error }) {
        throw InventoryModelError.invalidModel(diagnostic.message)
    }
}
