import Foundation

public enum FacilityLayoutSolver {
    public static func solve(_ problem: FacilityLayoutProblem) throws -> FacilityLayoutSolution {
        try FacilityLayoutValidator.validate(problem)
        return evaluate(problem, source: "initialLayoutEvaluation", moves: [], search: nil)
    }

    public static func improve(_ problem: FacilityLayoutProblem) throws -> FacilityLayoutSolution {
        try FacilityLayoutValidator.validate(problem)

        var currentProblem = problem
        var currentSolution = evaluate(currentProblem, source: "initialLayoutEvaluation", moves: [], search: nil)
        let initialObjectiveValue = currentSolution.objectiveValue
        var appliedMoves: [FacilityLayoutMove] = []
        var evaluatedMoveCount = 0

        while true {
            let pairs = sameSizeMovablePairs(in: currentProblem)
            var bestMove: FacilityLayoutMove?
            var bestProblem: FacilityLayoutProblem?

            for pair in pairs {
                let candidateProblem = swappingLayouts(in: currentProblem, firstIndex: pair.first, secondIndex: pair.second)
                let candidateSolution = evaluate(candidateProblem, source: "pairwiseSwapCandidate", moves: [], search: nil)
                evaluatedMoveCount += 1

                let improvement = currentSolution.objectiveValue - candidateSolution.objectiveValue
                guard improvement > 1e-8 else {
                    continue
                }

                let first = currentProblem.departments[pair.first]
                let second = currentProblem.departments[pair.second]
                let move = FacilityLayoutMove(
                    kind: "pairwiseSameSizeSwap",
                    firstDepartmentID: first.id,
                    firstDepartmentName: first.name,
                    secondDepartmentID: second.id,
                    secondDepartmentName: second.name,
                    firstBeforeRectangles: first.initialLayout,
                    firstAfterRectangles: second.initialLayout,
                    secondBeforeRectangles: second.initialLayout,
                    secondAfterRectangles: first.initialLayout,
                    objectiveBefore: currentSolution.objectiveValue,
                    objectiveAfter: candidateSolution.objectiveValue,
                    improvement: improvement
                )

                if bestMove == nil || move.improvement > (bestMove?.improvement ?? 0) + 1e-8 {
                    bestMove = move
                    bestProblem = candidateProblem
                }
            }

            guard let bestMove, let bestProblem else {
                break
            }

            appliedMoves.append(bestMove)
            currentProblem = bestProblem
            currentSolution = evaluate(currentProblem, source: "pairwiseSwapLocalSearch", moves: [], search: nil)
        }

        let search = FacilityLayoutSearchSummary(
            strategy: .pairwiseSwap,
            evaluatedMoveCount: evaluatedMoveCount,
            appliedMoveCount: appliedMoves.count,
            initialObjectiveValue: initialObjectiveValue,
            finalObjectiveValue: currentSolution.objectiveValue,
            improvement: initialObjectiveValue - currentSolution.objectiveValue
        )

        return evaluate(
            currentProblem,
            source: "pairwiseSwapLocalSearch",
            moves: appliedMoves,
            search: search
        )
    }

    private static func evaluate(
        _ problem: FacilityLayoutProblem,
        source: String,
        moves: [FacilityLayoutMove],
        search: FacilityLayoutSearchSummary?
    ) -> FacilityLayoutSolution {
        let placements = problem.departments.map(placement)
        let placementByID = Dictionary(uniqueKeysWithValues: placements.map { ($0.departmentID, $0) })
        var interactions: [FacilityLayoutInteraction] = []

        for (fromIndex, fromDepartment) in problem.departments.enumerated() {
            guard let fromPlacement = placementByID[fromDepartment.id] else {
                continue
            }
            for (toIndex, toDepartment) in problem.departments.enumerated() where fromIndex != toIndex {
                let weight = fromDepartment.flowUnitCosts[toIndex] ?? 0
                guard weight > 0, let toPlacement = placementByID[toDepartment.id] else {
                    continue
                }
                let distance = abs(fromPlacement.centroidRow - toPlacement.centroidRow)
                    + abs(fromPlacement.centroidColumn - toPlacement.centroidColumn)
                interactions.append(FacilityLayoutInteraction(
                    fromDepartmentID: fromDepartment.id,
                    fromDepartmentName: fromDepartment.name,
                    toDepartmentID: toDepartment.id,
                    toDepartmentName: toDepartment.name,
                    weight: weight,
                    distance: distance,
                    weightedDistance: weight * distance
                ))
            }
        }

        return FacilityLayoutSolution(
            objective: problem.objective,
            objectiveValue: interactions.reduce(0) { $0 + $1.weightedDistance },
            source: source,
            search: search,
            moves: moves,
            placements: placements,
            interactions: interactions
        )
    }

    private static func sameSizeMovablePairs(in problem: FacilityLayoutProblem) -> [(first: Int, second: Int)] {
        let cellCounts = problem.departments.map { layoutCells(in: $0.initialLayout).count }
        var pairs: [(first: Int, second: Int)] = []

        for firstIndex in problem.departments.indices {
            guard !problem.departments[firstIndex].fixed else {
                continue
            }
            for secondIndex in problem.departments.indices where secondIndex > firstIndex {
                guard !problem.departments[secondIndex].fixed else {
                    continue
                }
                guard cellCounts[firstIndex] == cellCounts[secondIndex] else {
                    continue
                }
                pairs.append((firstIndex, secondIndex))
            }
        }

        return pairs
    }

    private static func swappingLayouts(
        in problem: FacilityLayoutProblem,
        firstIndex: Int,
        secondIndex: Int
    ) -> FacilityLayoutProblem {
        var departments = problem.departments
        let first = departments[firstIndex]
        let second = departments[secondIndex]

        departments[firstIndex] = FacilityLayoutDepartment(
            id: first.id,
            name: first.name,
            fixed: first.fixed,
            flowUnitCosts: first.flowUnitCosts,
            initialLayout: second.initialLayout
        )
        departments[secondIndex] = FacilityLayoutDepartment(
            id: second.id,
            name: second.name,
            fixed: second.fixed,
            flowUnitCosts: second.flowUnitCosts,
            initialLayout: first.initialLayout
        )

        return FacilityLayoutProblem(
            title: problem.title,
            rowCount: problem.rowCount,
            columnCount: problem.columnCount,
            objective: problem.objective,
            departments: departments
        )
    }

    private static func placement(for department: FacilityLayoutDepartment) -> FacilityLayoutPlacement {
        let cells = layoutCells(in: department.initialLayout)
        let cellCount = cells.count
        let centroidRow = cells.reduce(0.0) { $0 + Double($1.row) } / Double(cellCount)
        let centroidColumn = cells.reduce(0.0) { $0 + Double($1.column) } / Double(cellCount)
        return FacilityLayoutPlacement(
            departmentID: department.id,
            departmentName: department.name,
            fixed: department.fixed,
            rectangles: department.initialLayout,
            cellCount: cellCount,
            centroidRow: centroidRow,
            centroidColumn: centroidColumn
        )
    }
}


