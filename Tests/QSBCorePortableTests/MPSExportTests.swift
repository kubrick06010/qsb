import Testing
import QSBCore

@Suite struct MPSExportTests {
    @Test(arguments: [
        1e-15, -1e-15, Double.leastNonzeroMagnitude,
        1.0000000000000002, 1.2345678901234567,
        Double(Int.max), 1e100, -1e100, Double.greatestFiniteMagnitude
    ])
    func preservesFiniteNumbers(value: Double) throws {
        let model = LinearProgram(
            title: "Numeric interchange", sense: .minimize,
            variableNames: ["x"], objectiveCoefficients: [value],
            constraints: [LinearConstraint(name: "row", coefficients: [value], relation: .equal, rhs: value)],
            lowerBounds: [abs(value)], upperBounds: [abs(value)]
        )
        let rows = try records(model)
        let column = try #require(rows.first { $0.first == "X" })
        #expect(Double(column[2]) == value)
        #expect(Double(column[4]) == value)
        let rhs = try #require(rows.first { $0.first == "RHS1" })
        #expect(Double(rhs[2]) == value)
        for kind in ["LO", "UP"] {
            let bound = try #require(rows.first { $0.first == kind })
            #expect(Double(bound[3]) == abs(value))
        }
    }

    @Test func reservesObjectiveNameAndResolvesSanitizedCollisions() throws {
        let model = LinearProgram(
            title: "Names", sense: .maximize,
            variableNames: ["x one", "X_ONE", "X_ONE_2"], objectiveCoefficients: [1, 2, 3],
            constraints: ["obj", "OBJ_2", "obj!", "OBJ"].enumerated().map { index, name in
                LinearConstraint(name: name, coefficients: [1, 1, 1], relation: .lessThanOrEqual, rhs: Double(index + 1))
            }
        )
        let text = try LinearProgramMPSExporter.export(model)
        #expect(try LinearProgramMPSExporter.export(model) == text)
        let rows = try records(model)
        let objective = try #require(rows.first { $0.first == "N" }?.last)
        let constraints = rows.filter { $0.first == "L" }.compactMap(\.last)
        #expect(Set(constraints).count == 4)
        #expect(!constraints.contains(objective))
        let rhsNames = rows.filter { $0.first == "RHS1" }.map { $0[1] }
        #expect(rhsNames == constraints)
        let start = try #require(rows.firstIndex(of: ["COLUMNS"]))
        let end = try #require(rows.firstIndex(of: ["RHS"]))
        let columns = rows[(start + 1)..<end]
        #expect(Set(columns.map { $0[0] }).count == 3)
        for record in columns {
            for index in stride(from: 1, to: record.count, by: 2) {
                #expect(record[index] == objective || constraints.contains(record[index]))
            }
        }
        #expect(model.constraints[0].name == "obj")
    }

    @Test func writesExplicitGeneralIntegerAndZeroBounds() throws {
        let model = LinearProgram(
            title: "Bounds", sense: .minimize,
            variableNames: ["integer", "fixed", "binary", "free"],
            objectiveCoefficients: [1, 1, 1, 1], constraints: [],
            upperBounds: [nil, 0, nil, -2],
            variableTypes: [.integer, .continuous, .binary, .continuous],
            unrestrictedVariables: [false, false, false, true]
        )
        let rows = try records(model)
        #expect(rows.contains(["LO", "BND1", "INTEGER", "0"]))
        #expect(rows.contains(["PL", "BND1", "INTEGER"]))
        #expect(rows.contains(["LO", "BND1", "FIXED", "0"]))
        #expect(rows.contains(["UP", "BND1", "FIXED", "0"]))
        #expect(rows.contains(["BV", "BND1", "BINARY"]))
        #expect(rows.contains(["FR", "BND1", "FREE"]))
        #expect(rows.contains(["UP", "BND1", "FREE", "-2"]))
    }

    @Test func rejectsNonfiniteCoefficientsBeforeExport() {
        let model = LinearProgram(
            title: "Invalid", sense: .minimize,
            variableNames: ["x"], objectiveCoefficients: [.infinity], constraints: []
        )
        #expect(throws: LinearProgramError.self) { try LinearProgramMPSExporter.export(model) }
    }

    private func records(_ model: LinearProgram) throws -> [[String]] {
        try LinearProgramMPSExporter.export(model).split(separator: "\n").map {
            $0.split(whereSeparator: \.isWhitespace).map(String.init)
        }
    }
}
