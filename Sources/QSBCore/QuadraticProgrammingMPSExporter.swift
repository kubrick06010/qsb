import Foundation

/// Exports a continuous quadratic program as free MPS with a `QUADOBJ` Hessian.
/// `QuadraticProgram` stores `xᵀQx`; MPS stores `0.5xᵀHx`, so each emitted
/// lower-triangular Hessian entry is `2Qᵢⱼ`.
public enum QuadraticProgramMPSExporter {
    static func variableNames(for model: QuadraticProgram) -> [String] {
        LinearProgramMPSExporter.variableNames(for: model.variableNames)
    }

    public static func export(_ model: QuadraticProgram) throws -> String {
        try QuadraticProgramValidator.validate(model)
        guard model.variableTypes.allSatisfy({ $0 == .continuous }) else {
            throw QuadraticProgrammingError.invalidModel("HiGHS does not support mixed-integer QP")
        }

        let names = variableNames(for: model)
        let constraintNames = LinearProgramMPSExporter.uniqueNames(
            model.constraints.map(\.name), prefix: "C", reserved: ["OBJ"]
        )
        var lines = [
            "NAME          \(LinearProgramMPSExporter.safeName(model.title, fallback: "QSB"))",
            "OBJSENSE",
            model.sense == .maximize ? " MAX" : " MIN",
            "ROWS",
            " N  OBJ"
        ]
        for (index, constraint) in model.constraints.enumerated() {
            let relation: String
            switch constraint.relation {
            case .lessThanOrEqual: relation = "L"
            case .greaterThanOrEqual: relation = "G"
            case .equal: relation = "E"
            }
            lines.append(" \(relation)  \(constraintNames[index])")
        }

        lines.append("COLUMNS")
        for index in names.indices {
            var entries: [(String, Double)] = []
            let linear = model.linearCoefficients[index]
            if linear != 0 { entries.append(("OBJ", linear)) }
            for (row, constraint) in model.constraints.enumerated() {
                let coefficient = constraint.coefficients[index]
                if coefficient != 0 { entries.append((constraintNames[row], coefficient)) }
            }
            if entries.isEmpty { entries.append(("OBJ", 0)) }
            for chunk in stride(from: 0, to: entries.count, by: 2) {
                let first = entries[chunk]
                if chunk + 1 < entries.count {
                    let second = entries[chunk + 1]
                    lines.append("    \(names[index])  \(first.0)  \(number(first.1))  \(second.0)  \(number(second.1))")
                } else {
                    lines.append("    \(names[index])  \(first.0)  \(number(first.1))")
                }
            }
        }

        lines.append("RHS")
        for (index, constraint) in model.constraints.enumerated() {
            lines.append("    RHS1  \(constraintNames[index])  \(number(constraint.rhs))")
        }

        lines.append("BOUNDS")
        for index in names.indices {
            let name = names[index]
            if let lower = model.lowerBounds[index] {
                lines.append(" LO BND1  \(name)  \(number(lower))")
            } else {
                // `FR` removes the MPS default lower bound of zero. An optional
                // `UP` record below restores an upper-only domain.
                lines.append(" FR BND1  \(name)")
            }
            if let upper = model.upperBounds[index] {
                lines.append(" UP BND1  \(name)  \(number(upper))")
            }
        }

        lines.append("QUADOBJ")
        for column in names.indices {
            for row in column..<names.count {
                let coefficient = 2 * model.quadraticMatrix[row][column]
                if coefficient != 0 {
                    guard coefficient.isFinite else {
                        throw QuadraticProgrammingError.invalidModel("Quadratic coefficient overflows the HiGHS Hessian")
                    }
                    lines.append("    \(names[column])  \(names[row])  \(number(coefficient))")
                }
            }
        }
        lines.append("ENDATA")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func number(_ value: Double) -> String {
        LinearProgramMPSExporter.number(value)
    }
}
