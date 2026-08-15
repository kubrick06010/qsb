import Foundation
public enum SimplexSolver {
    public static func solve(_ program: LinearProgram) throws -> LinearProgramSolution {
        let variableCount = program.variableNames.count
        guard program.lowerBounds.count == variableCount,
              program.upperBounds.count == variableCount,
              program.variableTypes.count == variableCount
        else {
            throw LinearProgramError.unsupportedModel("Variable metadata does not match variable count")
        }

        guard program.unrestrictedVariables.count == variableCount else {
            throw LinearProgramError.unsupportedModel("Unrestricted-variable metadata does not match variable count")
        }
        if program.unrestrictedVariables.contains(true) {
            return try solveWithUnrestrictedVariables(program)
        }

        var constraints = program.constraints
        for index in 0..<variableCount {
            let name = program.variableNames[index]
            let lower = program.lowerBounds[index]
            if lower < -1e-9 {
                throw LinearProgramError.unsupportedModel("Negative lower bounds require variable substitution")
            }
            if lower > 1e-9 {
                constraints.append(boundConstraint(name: "\(name)_lower", variableCount: variableCount, index: index, relation: .greaterThanOrEqual, rhs: lower))
            }
            if let upper = program.upperBounds[index] {
                constraints.append(boundConstraint(name: "\(name)_upper", variableCount: variableCount, index: index, relation: .lessThanOrEqual, rhs: upper))
            }
            if program.variableTypes[index] == .binary {
                constraints.append(boundConstraint(name: "\(name)_binary_upper", variableCount: variableCount, index: index, relation: .lessThanOrEqual, rhs: 1))
            }
        }

        let canonicalObjective = program.sense == .maximize
            ? program.objectiveCoefficients
            : program.objectiveCoefficients.map { -$0 }

        let result = try solveCanonicalMaximization(
            variableCount: variableCount,
            objectiveCoefficients: canonicalObjective,
            constraints: constraints
        )

        let objectiveValue = program.sense == .maximize ? result.objectiveValue : -result.objectiveValue
        let values = Dictionary(uniqueKeysWithValues: program.variableNames.enumerated().map { index, name in
            (name, result.variableValues[index])
        })

        return LinearProgramSolution(objectiveValue: objectiveValue, variableValues: values)
    }

    private static func solveWithUnrestrictedVariables(_ program: LinearProgram) throws -> LinearProgramSolution {
        var names: [String] = []
        var objective: [Double] = []
        var lowerBounds: [Double] = []
        var upperBounds: [Double?] = []
        var variableTypes: [VariableType] = []
        var expandedIndexes: [[Int]] = Array(repeating: [], count: program.variableNames.count)

        for index in program.variableNames.indices {
            if program.unrestrictedVariables[index] {
                expandedIndexes[index] = [names.count, names.count + 1]
                names += ["\(program.variableNames[index])__positive", "\(program.variableNames[index])__negative"]
                let coefficient = program.objectiveCoefficients[index]
                objective += [coefficient, -coefficient]
                lowerBounds += [0, 0]
                upperBounds += [nil, nil]
                variableTypes += [.continuous, .continuous]
            } else {
                expandedIndexes[index] = [names.count]
                names.append(program.variableNames[index])
                objective.append(program.objectiveCoefficients[index])
                lowerBounds.append(program.lowerBounds[index])
                upperBounds.append(program.upperBounds[index])
                variableTypes.append(program.variableTypes[index])
            }
        }

        var constraints = program.constraints.map { constraint in
            var coefficients: [Double] = []
            for index in program.variableNames.indices {
                if program.unrestrictedVariables[index] {
                    let coefficient = constraint.coefficients[index]
                    coefficients += [coefficient, -coefficient]
                } else {
                    coefficients.append(constraint.coefficients[index])
                }
            }
            return LinearConstraint(name: constraint.name, coefficients: coefficients, relation: constraint.relation, rhs: constraint.rhs)
        }

        for index in program.variableNames.indices where program.unrestrictedVariables[index] {
            if let upper = program.upperBounds[index] {
                var coefficients = Array(repeating: 0.0, count: names.count)
                coefficients[expandedIndexes[index][0]] = 1
                coefficients[expandedIndexes[index][1]] = -1
                constraints.append(LinearConstraint(name: "\(program.variableNames[index])_upper", coefficients: coefficients, relation: .lessThanOrEqual, rhs: upper))
            }
        }

        let expanded = LinearProgram(
            title: program.title,
            sense: program.sense,
            variableNames: names,
            objectiveCoefficients: objective,
            constraints: constraints,
            lowerBounds: lowerBounds,
            upperBounds: upperBounds,
            variableTypes: variableTypes
        )
        let expandedSolution = try solve(expanded)
        var values: [String: Double] = [:]
        for index in program.variableNames.indices {
            let indexes = expandedIndexes[index]
            let positive = expandedSolution.variableValues[names[indexes[0]]] ?? 0
            let negative = indexes.count == 2 ? expandedSolution.variableValues[names[indexes[1]]] ?? 0 : 0
            values[program.variableNames[index]] = positive - negative
        }
        return LinearProgramSolution(objectiveValue: expandedSolution.objectiveValue, variableValues: values)
    }

    private struct CanonicalSolution {
        let objectiveValue: Double
        let variableValues: [Double]
    }

    private enum TableauColumn {
        case decision(Int)
        case slack
        case artificial
    }

    private static func boundConstraint(
        name: String,
        variableCount: Int,
        index: Int,
        relation: ConstraintRelation,
        rhs: Double
    ) -> LinearConstraint {
        var coefficients = Array(repeating: 0.0, count: variableCount)
        coefficients[index] = 1
        return LinearConstraint(name: name, coefficients: coefficients, relation: relation, rhs: rhs)
    }

    private static func solveCanonicalMaximization(
        variableCount: Int,
        objectiveCoefficients: [Double],
        constraints: [LinearConstraint]
    ) throws -> CanonicalSolution {
        var normalizedConstraints: [LinearConstraint] = []
        for constraint in constraints {
            guard constraint.coefficients.count == variableCount else {
                throw LinearProgramError.unsupportedModel("Constraint coefficient count does not match variable count")
            }
            normalizedConstraints.append(normalized(constraint))
        }

        let constraintCount = normalizedConstraints.count
        var columns: [TableauColumn] = (0..<variableCount).map(TableauColumn.decision)
        var basis = Array(repeating: -1, count: constraintCount)
        var artificialColumns: [Int] = []
        var rowAuxiliaryColumns = Array(repeating: [(column: Int, coefficient: Double)](), count: constraintCount)

        for (row, constraint) in normalizedConstraints.enumerated() {
            switch constraint.relation {
            case .lessThanOrEqual:
                columns.append(.slack)
                basis[row] = columns.count - 1
                rowAuxiliaryColumns[row].append((columns.count - 1, 1))
            case .greaterThanOrEqual:
                columns.append(.slack)
                rowAuxiliaryColumns[row].append((columns.count - 1, -1))
                columns.append(.artificial)
                basis[row] = columns.count - 1
                artificialColumns.append(columns.count - 1)
                rowAuxiliaryColumns[row].append((columns.count - 1, 1))
            case .equal:
                columns.append(.artificial)
                basis[row] = columns.count - 1
                artificialColumns.append(columns.count - 1)
                rowAuxiliaryColumns[row].append((columns.count - 1, 1))
            }
        }

        let width = columns.count + 1
        let rhsColumn = width - 1
        var tableau = Array(
            repeating: Array(repeating: 0.0, count: width),
            count: constraintCount + 1
        )

        for (rowIndex, constraint) in normalizedConstraints.enumerated() {
            for column in 0..<variableCount {
                tableau[rowIndex][column] = constraint.coefficients[column]
            }
            for entry in rowAuxiliaryColumns[rowIndex] {
                tableau[rowIndex][entry.column] = entry.coefficient
            }
            tableau[rowIndex][rhsColumn] = constraint.rhs
        }

        let objectiveRow = constraintCount
        if !artificialColumns.isEmpty {
            setObjectiveRow(&tableau, objective: phaseOneObjective(width: width, artificialColumns: artificialColumns), basis: basis)
            debugTableau(tableau, label: "phase-1-start", basis: basis)
            try optimize(&tableau, basis: &basis, constraintCount: constraintCount, rhsColumn: rhsColumn)
            debugTableau(tableau, label: "phase-1-end", basis: basis)
            if tableau[objectiveRow][rhsColumn] < -1e-8 {
                throw LinearProgramError.infeasible
            }
        }

        var objective = Array(repeating: 0.0, count: width)
        for column in 0..<variableCount {
            objective[column] = objectiveCoefficients[column]
        }
        setObjectiveRow(&tableau, objective: objective, basis: basis)
        debugTableau(tableau, label: "phase-2-start", basis: basis)
        try optimize(
            &tableau,
            basis: &basis,
            constraintCount: constraintCount,
            rhsColumn: rhsColumn,
            forbiddenEnteringColumns: Set(artificialColumns)
        )
        debugTableau(tableau, label: "phase-2-end", basis: basis)

        var values = Array(repeating: 0.0, count: variableCount)
        for column in 0..<variableCount {
            if let row = basis.firstIndex(of: column) {
                values[column] = tableau[row][rhsColumn]
            }
        }

        return CanonicalSolution(objectiveValue: tableau[objectiveRow][rhsColumn], variableValues: values)
    }

    private static func normalized(_ constraint: LinearConstraint) -> LinearConstraint {
        guard constraint.rhs < -1e-9 else {
            return constraint
        }

        let relation: ConstraintRelation
        switch constraint.relation {
        case .lessThanOrEqual:
            relation = .greaterThanOrEqual
        case .greaterThanOrEqual:
            relation = .lessThanOrEqual
        case .equal:
            relation = .equal
        }

        return LinearConstraint(
            name: constraint.name,
            coefficients: constraint.coefficients.map { -$0 },
            relation: relation,
            rhs: -constraint.rhs
        )
    }

    private static func phaseOneObjective(width: Int, artificialColumns: [Int]) -> [Double] {
        var objective = Array(repeating: 0.0, count: width)
        for column in artificialColumns {
            objective[column] = -1
        }
        return objective
    }

    private static func setObjectiveRow(_ tableau: inout [[Double]], objective: [Double], basis: [Int]) {
        let objectiveRow = tableau.count - 1
        for column in tableau[objectiveRow].indices {
            tableau[objectiveRow][column] = column < objective.count ? -objective[column] : 0
        }

        for row in 0..<basis.count {
            let basisColumn = basis[row]
            let coefficient = basisColumn < objective.count ? objective[basisColumn] : 0
            guard abs(coefficient) > 1e-12 else { continue }
            for column in tableau[objectiveRow].indices {
                tableau[objectiveRow][column] += coefficient * tableau[row][column]
            }
        }
    }

    private static func optimize(
        _ tableau: inout [[Double]],
        basis: inout [Int],
        constraintCount: Int,
        rhsColumn: Int,
        forbiddenEnteringColumns: Set<Int> = []
    ) throws {
        while let enteringColumn = mostNegativeColumn(
            in: tableau[constraintCount].dropLast(),
            forbiddenColumns: forbiddenEnteringColumns
        ) {
            var leavingRow: Int?
            var bestRatio = Double.infinity

            for row in 0..<constraintCount {
                let coefficient = tableau[row][enteringColumn]
                guard coefficient > 1e-9 else { continue }
                let ratio = tableau[row][rhsColumn] / coefficient
                if ratio < bestRatio - 1e-12 {
                    bestRatio = ratio
                    leavingRow = row
                }
            }

            guard let pivotRow = leavingRow else {
                throw LinearProgramError.unbounded
            }

            pivot(&tableau, row: pivotRow, column: enteringColumn)
            basis[pivotRow] = enteringColumn
        }
    }

    private static func debugTableau(_ tableau: [[Double]], label: String, basis: [Int]) {
        guard ProcessInfo.processInfo.environment["QSB_DEBUG_TABLEAU"] == "1" else {
            return
        }
        let rows = tableau.map { row in
            row.map { String(format: "%9.3f", $0) }.joined(separator: " ")
        }
        FileHandle.standardError.write(Data(("\n\(label) basis=\(basis)\n" + rows.joined(separator: "\n") + "\n").utf8))
    }
}

