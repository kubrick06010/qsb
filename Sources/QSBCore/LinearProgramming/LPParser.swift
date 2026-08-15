import Foundation
public enum WinQSBMatrixParser {
    public static func parseLP(from data: Data) throws -> LinearProgram {
        guard let text = data.legacyLatin1String else {
            throw LinearProgramError.unsupportedMatrixFormat
        }

        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(clean) }

        guard let metadata = lines.first, metadata.count >= 2, metadata[0] == "LP" else {
            throw LinearProgramError.unsupportedMatrixFormat
        }

        switch metadata[1] {
        case "MatrixFormat":
            return try parseMatrixFormat(lines)
        case "NormalModel":
            return try parseNormalModel(lines)
        default:
            throw LinearProgramError.unsupportedMatrixFormat
        }
    }

    private static func parseMatrixFormat(_ lines: [[String]]) throws -> LinearProgram {
        guard
            let metadata = lines.first,
            metadata.count >= 5,
            metadata[0] == "LP",
            metadata[1] == "MatrixFormat",
            let variableCount = Int(metadata[3]),
            let constraintCount = Int(metadata[4]),
            lines.count >= constraintCount + 3
        else {
            throw LinearProgramError.unsupportedMatrixFormat
        }

        let title = metadata[2]
        let header = lines[1]
        guard header.count >= variableCount + 1 else {
            throw LinearProgramError.unsupportedMatrixFormat
        }

        let variableNames = Array(header[1...(variableCount)])
        let objectiveRow = lines[2]
        guard objectiveRow.count >= variableCount + 1 else {
            throw LinearProgramError.unsupportedMatrixFormat
        }

        let sense: ObjectiveSense
        switch objectiveRow[0].lowercased() {
        case "maximize":
            sense = .maximize
        case "minimize":
            sense = .minimize
        default:
            throw LinearProgramError.unsupportedMatrixFormat
        }

        let objective = try objectiveRow[1...variableCount].map(parseDouble)
        let constraints = try lines[3..<(3 + constraintCount)].map { row in
            guard row.count >= variableCount + 3 else {
                throw LinearProgramError.unsupportedMatrixFormat
            }

            let relationText = row[variableCount + 1]
            let relation: ConstraintRelation
            switch relationText {
            case "<=":
                relation = .lessThanOrEqual
            case ">=":
                relation = .greaterThanOrEqual
            case "=":
                relation = .equal
            default:
                throw LinearProgramError.unsupportedRelation(relationText)
            }

            return LinearConstraint(
                name: row[0],
                coefficients: try row[1...variableCount].map(parseDouble),
                relation: relation,
                rhs: try parseDouble(row[variableCount + 2])
            )
        }

        var lowerBounds = Array(repeating: 0.0, count: variableCount)
        var upperBounds = Array<Double?>(repeating: nil, count: variableCount)
        var variableTypes = Array(repeating: VariableType.continuous, count: variableCount)

        for row in lines.dropFirst(3 + constraintCount) {
            guard let label = row.first else { continue }
            switch label.lowercased() {
            case "lowerbound":
                for index in 0..<variableCount where index + 1 < row.count {
                    lowerBounds[index] = try parseBound(row[index + 1]) ?? 0
                }
            case "upperbound":
                for index in 0..<variableCount where index + 1 < row.count {
                    upperBounds[index] = try parseBound(row[index + 1])
                }
            case "variabletype":
                for index in 0..<variableCount where index + 1 < row.count {
                    variableTypes[index] = try parseVariableType(row[index + 1])
                }
            default:
                continue
            }
        }

        return LinearProgram(
            title: title,
            sense: sense,
            variableNames: variableNames,
            objectiveCoefficients: objective,
            constraints: constraints,
            lowerBounds: lowerBounds,
            upperBounds: upperBounds,
            variableTypes: variableTypes
        )
    }

    private static func parseNormalModel(_ lines: [[String]]) throws -> LinearProgram {
        guard
            let metadata = lines.first,
            metadata.count >= 5,
            metadata[0] == "LP",
            metadata[1] == "NormalModel",
            let variableCount = Int(metadata[3]),
            let constraintCount = Int(metadata[4]),
            lines.count >= constraintCount + 3
        else {
            throw LinearProgramError.unsupportedMatrixFormat
        }

        let title = metadata[2]
        let objectiveRow = lines[2]
        guard objectiveRow.count >= 2 else {
            throw LinearProgramError.unsupportedMatrixFormat
        }

        let sense: ObjectiveSense
        switch objectiveRow[0].lowercased() {
        case "maximize":
            sense = .maximize
        case "minimize":
            sense = .minimize
        default:
            throw LinearProgramError.unsupportedMatrixFormat
        }

        let variableNames = try normalModelVariableNames(lines: lines, variableCount: variableCount, constraintCount: constraintCount)
        let objective = try coefficients(for: parseLinearExpression(objectiveRow[1]), variableNames: variableNames)
        let constraints = try lines[3..<(3 + constraintCount)].map { row in
            guard row.count >= 2 else {
                throw LinearProgramError.unsupportedMatrixFormat
            }
            let parsed = try parseConstraintExpression(row[1])
            return LinearConstraint(
                name: row[0],
                coefficients: try coefficients(for: parsed.coefficients, variableNames: variableNames),
                relation: parsed.relation,
                rhs: parsed.rhs
            )
        }

        var lowerBounds = Array(repeating: 0.0, count: variableCount)
        var upperBounds = Array<Double?>(repeating: nil, count: variableCount)
        var variableTypes = Array(repeating: VariableType.continuous, count: variableCount)
        var unrestrictedVariables = Array(repeating: false, count: variableCount)
        let variableIndexByName = Dictionary(uniqueKeysWithValues: variableNames.enumerated().map { ($1, $0) })

        for row in lines.dropFirst(3 + constraintCount) {
            guard let label = row.first, !label.isEmpty else { continue }
            let normalizedLabel = label.lowercased()
            if normalizedLabel == "integer:" || normalizedLabel == "binary:" || normalizedLabel == "unrestricted:" {
                let type: VariableType? = normalizedLabel == "integer:" ? .integer : normalizedLabel == "binary:" ? .binary : nil
                for name in variableList(from: Array(row.dropFirst())) {
                    if let index = variableIndexByName[name] {
                        if let type {
                            variableTypes[index] = type
                        } else {
                            unrestrictedVariables[index] = true
                        }
                    }
                }
            } else if let index = variableIndexByName[label], row.count >= 2 {
                let bounds = try parseNormalBounds(row[1])
                lowerBounds[index] = bounds.lower
                upperBounds[index] = bounds.upper
            }
        }

        for index in 0..<variableCount where variableTypes[index] == .binary {
            upperBounds[index] = min(upperBounds[index] ?? 1, 1)
        }

        return LinearProgram(
            title: title,
            sense: sense,
            variableNames: variableNames,
            objectiveCoefficients: objective,
            constraints: constraints,
            lowerBounds: lowerBounds,
            upperBounds: upperBounds,
            variableTypes: variableTypes,
            unrestrictedVariables: unrestrictedVariables
        )
    }

    private static func clean(_ value: Substring) -> String {
        String(value).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseDouble(_ value: String) throws -> Double {
        guard let double = Double(value) else {
            throw LinearProgramError.invalidNumericValue(value)
        }
        return double
    }

    private static func parseBound(_ value: String) throws -> Double? {
        if value.lowercased() == "m" {
            return nil
        }
        return try parseDouble(value)
    }

    private static func parseVariableType(_ value: String) throws -> VariableType {
        switch value.lowercased() {
        case "continuous":
            .continuous
        case "integer":
            .integer
        case "binary":
            .binary
        default:
            throw LinearProgramError.unsupportedVariableType(value)
        }
    }

    private static func normalModelVariableNames(
        lines: [[String]],
        variableCount: Int,
        constraintCount: Int
    ) throws -> [String] {
        var names: [String] = []
        var seen: Set<String> = []

        func append(_ name: String) {
            guard !name.isEmpty, !seen.contains(name) else { return }
            seen.insert(name)
            names.append(name)
        }

        for row in lines.dropFirst(3 + constraintCount) {
            guard let label = row.first, !label.isEmpty else { continue }
            switch label.lowercased() {
            case "integer:", "binary:", "unrestricted:":
                for name in variableList(from: Array(row.dropFirst())) {
                    append(name)
                }
            default:
                if row.count >= 2, row[1].contains(">") || row[1].contains("<") || row[1].contains("=") {
                    append(label)
                }
            }
        }

        if lines.count > 2, lines[2].count >= 2 {
            for name in try parseLinearExpression(lines[2][1]).keys {
                append(name)
            }
        }

        for row in lines[3..<(3 + constraintCount)] where row.count >= 2 {
            for name in try parseConstraintExpression(row[1]).coefficients.keys {
                append(name)
            }
        }

        guard names.count == variableCount else {
            throw LinearProgramError.unsupportedModel("NormalModel variable count mismatch")
        }
        return names
    }

    private static func parseConstraintExpression(_ expression: String) throws -> (
        coefficients: [String: Double],
        relation: ConstraintRelation,
        rhs: Double
    ) {
        let relationText: String
        if expression.contains("<=") {
            relationText = "<="
        } else if expression.contains(">=") {
            relationText = ">="
        } else if expression.contains("=") {
            relationText = "="
        } else {
            throw LinearProgramError.unsupportedMatrixFormat
        }

        let parts = expression.components(separatedBy: relationText)
        guard parts.count == 2 else {
            throw LinearProgramError.unsupportedMatrixFormat
        }

        let relation: ConstraintRelation
        switch relationText {
        case "<=":
            relation = .lessThanOrEqual
        case ">=":
            relation = .greaterThanOrEqual
        case "=":
            relation = .equal
        default:
            throw LinearProgramError.unsupportedRelation(relationText)
        }

        return (
            coefficients: try parseLinearExpression(parts[0]),
            relation: relation,
            rhs: try parseDouble(parts[1].trimmingCharacters(in: .whitespacesAndNewlines))
        )
    }

    private static func parseLinearExpression(_ expression: String) throws -> [String: Double] {
        let compact = expression
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "+-")
        let terms = compact.split(separator: "+").map(String.init).filter { !$0.isEmpty }
        var coefficients: [String: Double] = [:]

        for term in terms {
            let split = term.firstIndex { $0.isLetter || $0 == "_" }
            guard let split else {
                throw LinearProgramError.unsupportedMatrixFormat
            }

            let coefficientText = String(term[..<split])
            let variableName = String(term[split...])
            let coefficient: Double
            switch coefficientText {
            case "", "+":
                coefficient = 1
            case "-":
                coefficient = -1
            default:
                coefficient = try parseDouble(coefficientText)
            }
            coefficients[variableName, default: 0] += coefficient
        }

        return coefficients
    }

    private static func coefficients(for values: [String: Double], variableNames: [String]) throws -> [Double] {
        let knownNames = Set(variableNames)
        let unknownNames = Set(values.keys).subtracting(knownNames)
        guard unknownNames.isEmpty else {
            throw LinearProgramError.unsupportedModel("Unknown variables: \(unknownNames.sorted().joined(separator: ", "))")
        }
        return variableNames.map { values[$0] ?? 0 }
    }

    private static func parseNormalBounds(_ text: String) throws -> (lower: Double, upper: Double?) {
        var lower = 0.0
        var upper: Double?
        let parts = text.split(separator: ",").map { clean($0) }
        for part in parts {
            if part.hasPrefix(">=") {
                lower = try parseBound(String(part.dropFirst(2))) ?? 0
            } else if part.hasPrefix("<=") {
                upper = try parseBound(String(part.dropFirst(2)))
            }
        }
        return (lower, upper)
    }

    private static func variableList(from values: [String]) -> [String] {
        values
            .flatMap { $0.split { $0 == "," || $0 == " " || $0 == "\t" } }
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

