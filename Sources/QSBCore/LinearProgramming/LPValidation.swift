import Foundation
public enum LinearProgramValidator {
    public static func diagnostics(for program: LinearProgram) -> [ValidationDiagnostic] {
        var diagnostics: [ValidationDiagnostic] = []
        let variableCount = program.variableNames.count

        if variableCount == 0 {
            diagnostics.append(error("lp.variableNames.empty", "variableNames must contain at least one variable", path: "variableNames"))
            return diagnostics
        }

        let trimmedVariableNames = program.variableNames.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if trimmedVariableNames.contains(where: \.isEmpty) {
            diagnostics.append(error("lp.variableNames.emptyName", "variableNames must not contain empty names", path: "variableNames"))
        }
        if Set(program.variableNames).count != variableCount {
            diagnostics.append(error("lp.variableNames.duplicate", "variableNames must be unique", path: "variableNames"))
        }
        if program.objectiveCoefficients.count != variableCount {
            diagnostics.append(error("lp.objectiveCoefficients.dimension", "objectiveCoefficients must contain one value per variable", path: "objectiveCoefficients"))
        }
        if program.lowerBounds.count != variableCount {
            diagnostics.append(error("lp.lowerBounds.dimension", "lowerBounds must contain one value per variable", path: "lowerBounds"))
        }
        if program.upperBounds.count != variableCount {
            diagnostics.append(error("lp.upperBounds.dimension", "upperBounds must contain one value or null per variable", path: "upperBounds"))
        }
        if program.variableTypes.count != variableCount {
            diagnostics.append(error("lp.variableTypes.dimension", "variableTypes must contain one value per variable", path: "variableTypes"))
        }
        if program.unrestrictedVariables.count != variableCount {
            diagnostics.append(error("lp.unrestrictedVariables.dimension", "unrestrictedVariables must contain one value per variable", path: "unrestrictedVariables"))
        }
        if !program.objectiveCoefficients.allSatisfy(\.isFinite) {
            diagnostics.append(error("lp.objectiveCoefficients.finite", "objectiveCoefficients must be finite", path: "objectiveCoefficients"))
        }

        guard program.lowerBounds.count == variableCount,
              program.upperBounds.count == variableCount,
              program.variableTypes.count == variableCount,
              program.unrestrictedVariables.count == variableCount
        else {
            return diagnostics
        }

        for index in 0..<variableCount {
            let name = program.variableNames[index]
            let lower = program.lowerBounds[index]
            let variablePath = "variables.\(name)"
            if program.unrestrictedVariables[index] {
                if program.variableTypes[index] != .continuous {
                    diagnostics.append(error("lp.unrestrictedVariables.type", "Unrestricted variables must be continuous", path: "\(variablePath).unrestricted"))
                }
                if let upper = program.upperBounds[index], !upper.isFinite {
                    diagnostics.append(error("lp.upperBounds.finite", "upper bound for '\(name)' must be finite", path: "\(variablePath).upperBound"))
                }
                continue
            }
            if !lower.isFinite {
                diagnostics.append(error("lp.lowerBounds.finite", "lower bound for '\(name)' must be finite", path: "\(variablePath).lowerBound"))
            }
            if lower < 0 {
                diagnostics.append(error("lp.lowerBounds.nonnegative", "lower bound for '\(name)' must be nonnegative", path: "\(variablePath).lowerBound"))
            }
            if let upper = program.upperBounds[index] {
                if !upper.isFinite {
                    diagnostics.append(error("lp.upperBounds.finite", "upper bound for '\(name)' must be finite", path: "\(variablePath).upperBound"))
                }
                if upper < lower {
                    diagnostics.append(error("lp.upperBounds.order", "upper bound for '\(name)' must be greater than or equal to its lower bound", path: "\(variablePath).upperBound"))
                }
            }
            if program.variableTypes[index] == .binary {
                if lower < 0 || lower > 1 {
                    diagnostics.append(error("lp.binary.lowerBound", "binary variable '\(name)' lower bound must be between 0 and 1", path: "\(variablePath).lowerBound"))
                }
                if let upper = program.upperBounds[index], upper < 0 || upper > 1 {
                    diagnostics.append(error("lp.binary.upperBound", "binary variable '\(name)' upper bound must be between 0 and 1", path: "\(variablePath).upperBound"))
                }
            }
        }

        for constraint in program.constraints where constraint.coefficients.count != variableCount {
            diagnostics.append(error("lp.constraintCoefficients.dimension", "constraint '\(constraint.name)' must contain one coefficient per variable", path: "constraints.\(constraint.name).coefficients"))
        }
        for constraint in program.constraints {
            if !constraint.rhs.isFinite {
                diagnostics.append(error("lp.constraintRHS.finite", "constraint '\(constraint.name)' rhs must be finite", path: "constraints.\(constraint.name).rhs"))
            }
            if !constraint.coefficients.allSatisfy(\.isFinite) {
                diagnostics.append(error("lp.constraintCoefficients.finite", "constraint '\(constraint.name)' coefficients must be finite", path: "constraints.\(constraint.name).coefficients"))
            }
        }

        if diagnostics.isEmpty {
            diagnostics.append(ValidationDiagnostic(
                severity: .info,
                code: "lp.valid",
                message: "Linear program is valid",
                path: nil
            ))
        }
        return diagnostics
    }

    public static func validate(_ program: LinearProgram) throws {
        if let diagnostic = diagnostics(for: program).first(where: { $0.severity == .error }) {
            throw LinearProgramError.invalidModel(diagnostic.message)
        }
    }

    private static func error(_ code: String, _ message: String, path: String?) -> ValidationDiagnostic {
        ValidationDiagnostic(severity: .error, code: code, message: message, path: path)
    }
}

