import Foundation

/// Emits a validated `LinearProgram` in the industry-standard free MPS format.
///
/// The exporter deliberately keeps the native solver independent from an
/// external engine.  MPS is only an interchange boundary: a caller can write
/// this text to a file and hand it to CBC, HiGHS, GLPK, or another compatible
/// command-line solver when one is installed.
public enum LinearProgramMPSExporter {
    public static func export(_ program: LinearProgram) throws -> String {
        try LinearProgramValidator.validate(program)

        let variableNames = uniqueNames(program.variableNames, prefix: "V")
        let constraintNames = uniqueNames(program.constraints.map(\.name), prefix: "C")
        let objectiveName = "OBJ"

        var lines: [String] = []
        lines.append("NAME          \(safeName(program.title, fallback: "QSB"))")
        lines.append("OBJSENSE")
        lines.append(program.sense == .maximize ? " MAX" : " MIN")
        lines.append("ROWS")
        lines.append(" N  \(objectiveName)")
        for (index, constraint) in program.constraints.enumerated() {
            let relation: String
            switch constraint.relation {
            case .lessThanOrEqual: relation = "L"
            case .greaterThanOrEqual: relation = "G"
            case .equal: relation = "E"
            }
            lines.append(String(format: " %@  %@", relation, constraintNames[index]))
        }

        lines.append("COLUMNS")
        var integerMarkerIndex = 0
        for index in program.variableNames.indices {
            let variable = variableNames[index]
            if program.variableTypes[index] != .continuous {
                let marker = String(format: "MARK%04d", integerMarkerIndex)
                lines.append("    \(marker)  'MARKER'                 'INTORG'")
                integerMarkerIndex += 1
            }

            var entries: [(String, Double)] = []
            let objective = program.objectiveCoefficients[index]
            if abs(objective) > 0 { entries.append((objectiveName, objective)) }
            for (constraintIndex, constraint) in program.constraints.enumerated() {
                let coefficient = constraint.coefficients[index]
                if abs(coefficient) > 0 { entries.append((constraintNames[constraintIndex], coefficient)) }
            }
            if entries.isEmpty {
                // A zero column still needs a record in some fixed-format
                // readers; a zero objective entry is harmless in free MPS.
                entries.append((objectiveName, 0))
            }
            for chunk in stride(from: 0, to: entries.count, by: 2) {
                let first = entries[chunk]
                if chunk + 1 < entries.count {
                    let second = entries[chunk + 1]
                    lines.append("    \(variable)  \(first.0)  \(number(first.1))  \(second.0)  \(number(second.1))")
                } else {
                    lines.append("    \(variable)  \(first.0)  \(number(first.1))")
                }
            }
            if program.variableTypes[index] != .continuous {
                let marker = String(format: "MARK%04d", integerMarkerIndex)
                lines.append("    \(marker)  'MARKER'                 'INTEND'")
                integerMarkerIndex += 1
            }
        }

        lines.append("RHS")
        for (index, constraint) in program.constraints.enumerated() {
            lines.append("    RHS1  \(constraintNames[index])  \(number(constraint.rhs))")
        }

        lines.append("BOUNDS")
        for index in program.variableNames.indices {
            let variable = variableNames[index]
            let lower = program.lowerBounds[index]
            let upper = program.upperBounds[index]
            if program.unrestrictedVariables[index] {
                lines.append(" FR BND1  \(variable)")
                if let upper { lines.append(" UP BND1  \(variable)  \(number(upper))") }
                continue
            }

            switch program.variableTypes[index] {
            case .binary:
                lines.append(" BV BND1  \(variable)")
                if lower > 0 { lines.append(" LO BND1  \(variable)  \(number(lower))") }
                if let upper, upper < 1 { lines.append(" UP BND1  \(variable)  \(number(upper))") }
            case .continuous, .integer:
                if lower != 0 { lines.append(" LO BND1  \(variable)  \(number(lower))") }
                if let upper { lines.append(" UP BND1  \(variable)  \(number(upper))") }
            }
        }
        lines.append("ENDATA")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func uniqueNames(_ source: [String], prefix: String) -> [String] {
        var used = Set<String>()
        return source.enumerated().map { index, raw in
            var candidate = safeName(raw, fallback: "\(prefix)\(index + 1)")
            if candidate.isEmpty { candidate = "\(prefix)\(index + 1)" }
            var suffix = 1
            while used.contains(candidate) {
                suffix += 1
                candidate = "\(safeName(raw, fallback: prefix))_\(suffix)"
            }
            used.insert(candidate)
            return candidate
        }
    }

    private static func safeName(_ raw: String, fallback: String) -> String {
        let transformed = raw.uppercased().map { character -> Character in
            if character.isLetter || character.isNumber || character == "_" { return character }
            return "_"
        }
        let value = String(transformed).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return value.isEmpty ? fallback : value
    }

    private static func number(_ value: Double) -> String {
        if abs(value.rounded() - value) < 1e-12 { return String(Int(value.rounded())) }
        return String(format: "%.12g", value)
    }
}
