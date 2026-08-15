import Testing
import QSBCore
@testable import QSBMacApp

struct LinearProgrammingDraftTests {
    @Test("blank draft converts to a valid LP shape")
    func blankDraftConverts() throws {
        let draft = LinearProgrammingDraft.blank()
        let program = try draft.makeLinearProgram()

        #expect(program.title == "New Linear Program")
        #expect(program.variableNames == ["x1"])
        #expect(program.objectiveCoefficients == [0])
        #expect(LinearProgramValidator.diagnostics(for: program).allSatisfy { $0.severity != .error })
    }

    @Test("draft preserves integer binary bounds and unrestricted semantics")
    func draftPreservesVariableSemantics() throws {
        var draft = LinearProgrammingDraft.blank()
        draft.variables = [
            LPDraftVariable(name: "x", type: .continuous, lowerBound: "0", upperBound: .unbounded, unrestricted: true),
            LPDraftVariable(name: "y", type: .integer, lowerBound: "2", upperBound: .value("8"), unrestricted: false),
            LPDraftVariable(name: "z", type: .binary, lowerBound: "0", upperBound: .value("1"), unrestricted: false)
        ]
        draft.objectiveCoefficients = ["1", "2", "3"]
        draft.constraints = [LPDraftConstraint(
            name: "capacity",
            coefficients: ["1", "2", "3"],
            relation: .lessThanOrEqual,
            rhs: "10"
        )]

        let program = try draft.makeLinearProgram()
        #expect(program.variableTypes == [.continuous, .integer, .binary])
        #expect(program.unrestrictedVariables == [true, false, false])
        #expect(program.lowerBounds == [0, 2, 0])
        #expect(program.upperBounds == [nil, 8, 1])
        #expect(program.constraints[0].relation == .lessThanOrEqual)
    }

    @Test("variable edits preserve matrix dimensions")
    func variableDimensionEdits() throws {
        var draft = LinearProgrammingDraft.blank()
        draft.addConstraint()
        draft.addVariable()
        #expect(draft.objectiveCoefficients.count == draft.variables.count)
        #expect(draft.constraints.allSatisfy { $0.coefficients.count == draft.variables.count })

        draft.removeVariable(at: 0)
        #expect(draft.objectiveCoefficients.count == draft.variables.count)
        #expect(draft.constraints.allSatisfy { $0.coefficients.count == draft.variables.count })

        draft.removeConstraint(at: 0)
        #expect(draft.constraints.isEmpty)
    }

    @Test("draft reports input diagnostics before core validation")
    func draftDiagnostics() {
        var draft = LinearProgrammingDraft.blank()
        draft.variables[0].name = ""
        let diagnostics = draft.draftDiagnostics()

        #expect(diagnostics.count == 1)
        #expect(diagnostics[0].severity == .error)
        #expect(diagnostics[0].path == "variables.0.name")
    }

    @Test("LP import round trips through the native draft")
    func programDraftRoundTrip() throws {
        let program = LinearProgram(
            title: "Negative unrestricted optimum",
            sense: .maximize,
            variableNames: ["x", "y"],
            objectiveCoefficients: [1, 0],
            constraints: [LinearConstraint(
                name: "limit",
                coefficients: [1, 1],
                relation: .lessThanOrEqual,
                rhs: 2
            )],
            lowerBounds: [0, 0],
            upperBounds: [nil, nil],
            variableTypes: [.continuous, .continuous],
            unrestrictedVariables: [true, false]
        )
        let roundTripped = try LinearProgrammingDraft(program: program).makeLinearProgram()
        #expect(roundTripped == program)
    }
}
