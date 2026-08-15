import Foundation
public enum IntegerLinearProgramSolver {
    public static func solve(_ program: LinearProgram, maxNodes: Int = 10_000) throws -> LinearProgramSolution {
        let integerIndexes = program.variableTypes.enumerated().compactMap { index, type in
            type == .integer || type == .binary ? index : nil
        }
        guard !integerIndexes.isEmpty else {
            return try SimplexSolver.solve(program)
        }

        var best: LinearProgramSolution?
        var nodesVisited = 0

        func search(_ current: LinearProgram) throws {
            nodesVisited += 1
            guard nodesVisited <= maxNodes else {
                throw LinearProgramError.unsupportedModel("Branch-and-bound node limit exceeded")
            }

            let relaxation: LinearProgramSolution
            do {
                relaxation = try SimplexSolver.solve(current)
            } catch LinearProgramError.infeasible {
                return
            }

            if let incumbent = best {
                switch program.sense {
                case .maximize where relaxation.objectiveValue <= incumbent.objectiveValue + 1e-8:
                    return
                case .minimize where relaxation.objectiveValue >= incumbent.objectiveValue - 1e-8:
                    return
                default:
                    break
                }
            }

            if let heuristic = roundedFeasibleSolution(from: relaxation, program: program, integerIndexes: integerIndexes) {
                best = better(heuristic, than: best, sense: program.sense)
            }

            guard let branchIndex = firstFractionalVariable(in: relaxation, program: program, integerIndexes: integerIndexes) else {
                best = better(relaxation, than: best, sense: program.sense)
                return
            }

            let variableName = program.variableNames[branchIndex]
            let value = relaxation.variableValues[variableName] ?? 0
            let floorValue = floor(value)
            let ceilValue = ceil(value)

            let lowerBranch = addingBranchConstraint(
                to: current,
                variableIndex: branchIndex,
                relation: .lessThanOrEqual,
                rhs: floorValue
            )

            let upperBranch = addingBranchConstraint(
                to: current,
                variableIndex: branchIndex,
                relation: .greaterThanOrEqual,
                rhs: ceilValue
            )

            switch program.sense {
            case .maximize:
                try search(lowerBranch)
                try search(upperBranch)
            case .minimize:
                try search(upperBranch)
                try search(lowerBranch)
            }
        }

        try search(program)

        guard let best else {
            throw LinearProgramError.infeasible
        }
        return best
    }

    private static func firstFractionalVariable(
        in solution: LinearProgramSolution,
        program: LinearProgram,
        integerIndexes: [Int]
    ) -> Int? {
        for index in integerIndexes {
            let value = solution.variableValues[program.variableNames[index]] ?? 0
            if abs(value - value.rounded()) > 1e-8 {
                return index
            }
        }
        return nil
    }

    private static func better(
        _ candidate: LinearProgramSolution,
        than incumbent: LinearProgramSolution?,
        sense: ObjectiveSense
    ) -> LinearProgramSolution {
        guard let incumbent else {
            return candidate
        }

        switch sense {
        case .maximize:
            return candidate.objectiveValue > incumbent.objectiveValue ? candidate : incumbent
        case .minimize:
            return candidate.objectiveValue < incumbent.objectiveValue ? candidate : incumbent
        }
    }

    private static func roundedFeasibleSolution(
        from relaxation: LinearProgramSolution,
        program: LinearProgram,
        integerIndexes: [Int]
    ) -> LinearProgramSolution? {
        var values = relaxation.variableValues

        for index in integerIndexes {
            let name = program.variableNames[index]
            let value = values[name] ?? 0
            switch program.variableTypes[index] {
            case .binary:
                values[name] = min(1, max(0, value.rounded()))
            case .integer:
                values[name] = program.sense == .maximize ? floor(value) : ceil(value)
            case .continuous:
                break
            }
        }

        guard isFeasible(values: values, program: program, integerIndexes: integerIndexes) else {
            return nil
        }

        let objective = program.variableNames.enumerated().reduce(0.0) { partial, element in
            partial + program.objectiveCoefficients[element.offset] * (values[element.element] ?? 0)
        }
        return LinearProgramSolution(objectiveValue: objective, variableValues: values)
    }

    private static func isFeasible(
        values: [String: Double],
        program: LinearProgram,
        integerIndexes: [Int]
    ) -> Bool {
        for (index, name) in program.variableNames.enumerated() {
            let value = values[name] ?? 0
            if value < program.lowerBounds[index] - 1e-8 {
                return false
            }
            if let upper = program.upperBounds[index], value > upper + 1e-8 {
                return false
            }
        }

        for index in integerIndexes {
            let value = values[program.variableNames[index]] ?? 0
            if abs(value - value.rounded()) > 1e-8 {
                return false
            }
            if program.variableTypes[index] == .binary && (value < -1e-8 || value > 1 + 1e-8) {
                return false
            }
        }

        for constraint in program.constraints {
            let lhs = program.variableNames.enumerated().reduce(0.0) { partial, element in
                partial + constraint.coefficients[element.offset] * (values[element.element] ?? 0)
            }
            switch constraint.relation {
            case .lessThanOrEqual where lhs > constraint.rhs + 1e-8:
                return false
            case .greaterThanOrEqual where lhs < constraint.rhs - 1e-8:
                return false
            case .equal where abs(lhs - constraint.rhs) > 1e-8:
                return false
            default:
                break
            }
        }

        return true
    }

    private static func addingBranchConstraint(
        to program: LinearProgram,
        variableIndex: Int,
        relation: ConstraintRelation,
        rhs: Double
    ) -> LinearProgram {
        var coefficients = Array(repeating: 0.0, count: program.variableNames.count)
        coefficients[variableIndex] = 1
        let constraint = LinearConstraint(
            name: "\(program.variableNames[variableIndex])_branch_\(program.constraints.count)",
            coefficients: coefficients,
            relation: relation,
            rhs: rhs
        )
        return LinearProgram(
            title: program.title,
            sense: program.sense,
            variableNames: program.variableNames,
            objectiveCoefficients: program.objectiveCoefficients,
            constraints: program.constraints + [constraint],
            lowerBounds: program.lowerBounds,
            upperBounds: program.upperBounds,
            variableTypes: program.variableTypes,
            unrestrictedVariables: program.unrestrictedVariables
        )
    }
}

