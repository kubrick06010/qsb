import Foundation
import Testing
@testable import QSBCore

@Test func portableLPJSONRoundTripPreservesDefaults() throws {
    let program = LinearProgram(
        title: "Portable",
        sense: .maximize,
        variableNames: ["x"],
        objectiveCoefficients: [2],
        constraints: [LinearConstraint(name: "limit", coefficients: [1], relation: .lessThanOrEqual, rhs: 4)]
    )

    let encoded = try LinearProgramJSON.encodeProgram(program)
    let decoded = try LinearProgramJSON.decodeProgram(from: encoded)
    #expect(decoded == program)
    #expect(try NativeEducationalLinearProgrammingBackend().solve(decoded, mode: .continuous).objectiveValue == 8)
}

@Test func portableDecisionTreeRollbackIsDeterministic() throws {
    let tree = DecisionTree(
        title: "Portable tree",
        rootID: 1,
        nodes: [
            DecisionTreeNode(id: 1, name: "Choose", kind: .decision, childIDs: [2, 3]),
            DecisionTreeNode(id: 2, name: "Good", kind: .terminal, childIDs: [], payoff: 10),
            DecisionTreeNode(id: 3, name: "Bad", kind: .terminal, childIDs: [], payoff: -2)
        ]
    )

    let first = try DecisionTreeSolver.solve(tree)
    let second = try DecisionTreeSolver.solve(tree)
    #expect(first == second)
    #expect(first.expectedValue == 10)
    #expect(first.policy.first?.selectedChildName == "Good")
}

@Test func portableRegressionUsesQRForWellConditionedData() throws {
    let model = RegressionModel(
        title: "Regression",
        dependentVariable: "y",
        independentVariables: ["x"],
        observations: (0...4).map { index in
            RegressionObservation(label: "\(index)", dependentValue: 2 + 3 * Double(index), independentValues: [Double(index)])
        }
    )

    let solution = try RegressionSolver.solve(model)
    #expect(abs(solution.intercept - 2) < 1e-10)
    #expect(abs((solution.coefficients["x"] ?? 0) - 3) < 1e-10)
}

@Test func portableRegressionQRHandlesNearlyCollinearPredictors() throws {
    let model = RegressionModel(
        title: "Nearly collinear",
        dependentVariable: "y",
        independentVariables: ["x1", "x2"],
        observations: (1...8).map { index in
            let x1 = Double(index)
            let x2 = 2 * x1 + (index.isMultiple(of: 2) ? 0.001 : -0.001)
            return RegressionObservation(label: "\(index)", dependentValue: 4 + 1.5 * x1 - 0.75 * x2, independentValues: [x1, x2])
        }
    )

    let solution = try RegressionSolver.solve(model)
    #expect(solution.predictions.allSatisfy { abs($0.residual) < 1e-8 })
}

@Test func portableRegressionQRReportsRankDeficiency() throws {
    let model = RegressionModel(
        title: "Singular",
        dependentVariable: "y",
        independentVariables: ["x1", "x2"],
        observations: (1...4).map { index in
            let x = Double(index)
            return RegressionObservation(label: "\(index)", dependentValue: x, independentValues: [x, x])
        }
    )

    do {
        _ = try RegressionSolver.solve(model)
        Issue.record("Expected a rank-deficient regression error")
    } catch let error as ForecastingModelError {
        #expect(String(describing: error).contains("rank deficient"))
    }
}
