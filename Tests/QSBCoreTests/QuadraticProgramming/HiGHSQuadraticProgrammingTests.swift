import Foundation
import Testing
@testable import QSBCore

@Test("QUADOBJ export preserves cross terms, names, signed and free bounds")
func exportsQuadraticMPSWithoutDroppingHessian() throws {
    let model = crossTermModel()
    let mps = try QuadraticProgramMPSExporter.export(model)
    #expect(mps.contains("OBJSENSE\n MIN"))
    #expect(mps.contains("X_ONE  OBJ  -4"))
    #expect(mps.contains("X_ONE_2  OBJ  -5"))
    #expect(mps.contains(" LO BND1  X_ONE  -1"))
    #expect(mps.contains(" FR BND1  X_ONE_2"))
    #expect(mps.contains(" UP BND1  X_ONE_2  3"))
    #expect(mps.contains("QUADOBJ\n    X_ONE  X_ONE  2\n    X_ONE  X_ONE_2  1\n    X_ONE_2  X_ONE_2  2\nENDATA"))
}

@Test("QP validation reports malformed matrix and bound dimensions without indexing past them")
func quadraticValidationRejectsMalformedDimensions() {
    let malformed = QuadraticProgram(
        title: "Malformed", sense: .minimize,
        variableNames: ["x", "y"], linearCoefficients: [0, 0],
        quadraticMatrix: [[1], [0, 1]], constraints: [],
        lowerBounds: [0, 0], upperBounds: [nil], variableTypes: [.continuous, .continuous]
    )
    let diagnostics = QuadraticProgramValidator.diagnostics(for: malformed)
    #expect(diagnostics.contains { $0.code == "qp.dimension" })

    let unnamed = QuadraticProgram(
        title: "Unnamed", sense: .minimize,
        variableNames: [" "], linearCoefficients: [0], quadraticMatrix: [[1]],
        constraints: [], lowerBounds: [nil], upperBounds: [nil], variableTypes: [.continuous]
    )
    #expect(QuadraticProgramValidator.diagnostics(for: unnamed).contains { $0.code == "qp.names" })
}

@Test("QP external adapter maps solver statuses and rejects invalid optimal output")
func quadraticExternalStatusesAndMalformedOutput() throws {
    let model = zeroRowModel()
    for (status, expected) in [("Infeasible", "infeasible"), ("Unbounded", "unbounded"), ("Time limit", "time limit")] {
        let executable = try fakeHiGHS(solution: "Model status\n\(status)\n")
        defer { try? FileManager.default.removeItem(at: executable.deletingLastPathComponent()) }
        do {
            _ = try HiGHSQuadraticProgrammingBackend(executableURL: executable).solve(model)
            Issue.record("Expected \(status) to fail")
        } catch {
            #expect(String(describing: error).lowercased().contains(expected))
        }
    }

    let executable = try fakeHiGHS(solution: """
    Model status
    Optimal
    Objective -1
    # Columns 1
    X 20
    # Rows 0
    """)
    defer { try? FileManager.default.removeItem(at: executable.deletingLastPathComponent()) }
    do {
        _ = try HiGHSQuadraticProgrammingBackend(executableURL: executable).solve(model)
        Issue.record("Expected objective mismatch to fail")
    } catch QuadraticProgrammingError.externalSolverMalformedOutput(let message) {
        #expect(message.contains("objective"))
    } catch {
        Issue.record("Expected malformed-output error, got \(error)")
    }
}

@Test("QP external adapter reconciles the zero-row exit status and passes solver options")
func quadraticZeroRowExitAndOptionsWithoutInstalledSolver() throws {
    let executable = try fakeHiGHS(
        solution: """
        Model status
        Optimal
        Objective -1
        # Columns 1
        X 1
        # Rows 0
        """,
        exitCode: 1,
        requiredModelLines: ["QUADOBJ", "X  X  2"],
        requiredOptionLines: ["time_limit = 2.5", "kkt_tolerance = 1e-06", "random_seed = 11"]
    )
    defer { try? FileManager.default.removeItem(at: executable.deletingLastPathComponent()) }
    let solution = try HiGHSQuadraticProgrammingBackend(executableURL: executable).solve(
        zeroRowModel(), options: SolverOptions(timeLimitSeconds: 2.5, tolerance: 1e-6, randomSeed: 11)
    )
    #expect(solution.objectiveValue == -1)
    #expect(solution.variableValues == ["x": 1])
}

@Test("QP external adapter rejects nonzero exits on constrained models and MIQP inputs")
func quadraticExternalRejectsFailedProcessAndMIQP() throws {
    let executable = try fakeHiGHS(
        solution: """
        Model status
        Optimal
        Objective -6.25
        # Columns 2
        X_ONE 0.5
        X_ONE_2 1.5
        # Rows 1
        CAPACITY 2
        """,
        exitCode: 1
    )
    defer { try? FileManager.default.removeItem(at: executable.deletingLastPathComponent()) }
    do {
        _ = try HiGHSQuadraticProgrammingBackend(executableURL: executable).solve(crossTermModel())
        Issue.record("Expected a nonzero constrained solve exit to fail")
    } catch QuadraticProgrammingError.externalSolverFailed(let message) {
        #expect(message.contains("status 1"))
    } catch {
        Issue.record("Expected external-solver failure, got \(error)")
    }

    let miqp = QuadraticProgram(
        title: "Integer QP", sense: .minimize,
        variableNames: ["x"], linearCoefficients: [-2], quadraticMatrix: [[1]],
        constraints: [], lowerBounds: [0], upperBounds: [nil], variableTypes: [.integer]
    )
    do {
        _ = try HiGHSQuadraticProgrammingBackend(executableURL: executable).solve(miqp)
        Issue.record("Expected MIQP to be rejected")
    } catch QuadraticProgrammingError.invalidModel(let message) {
        #expect(message.contains("mixed-integer"))
    } catch {
        Issue.record("Expected unsupported-MIQP error, got \(error)")
    }
}

@Test("HiGHS QP adapter solves a constrained cross-term model with typed values")
func solvesCrossTermQuadraticWithInstalledHiGHS() throws {
    guard let backend = HiGHSQuadraticProgrammingBackend.discovered() else { return }
    let model = crossTermModel()
    let solution = try backend.solve(model)
    #expect(abs(solution.objectiveValue + 6.25) < 1e-5)
    #expect(abs((solution.variableValues["x one"] ?? .nan) - 0.5) < 1e-5)
    #expect(abs((solution.variableValues["x-one"] ?? .nan) - 1.5) < 1e-5)
    #expect(solution.activeConstraints.contains("capacity"))
    #expect(backend.runMetadata(for: model).backendKind == .externalHighPerformance)
}

@Test("HiGHS QP adapter accepts an optimal zero-row solution despite the observed exit code")
func solvesZeroRowQuadraticWithInstalledHiGHS() throws {
    guard let backend = HiGHSQuadraticProgrammingBackend.discovered() else { return }
    let model = QuadraticProgram(
        title: "Zero row QP", sense: .minimize,
        variableNames: ["x"], linearCoefficients: [-2], quadraticMatrix: [[1]],
        constraints: [], lowerBounds: [nil], upperBounds: [nil], variableTypes: [.continuous]
    )
    let solution = try backend.solve(model)
    #expect(abs(solution.objectiveValue + 1) < 1e-7)
    #expect(abs((solution.variableValues["x"] ?? .nan) - 1) < 1e-7)
}

@Test("HiGHS QP adapter reproduces both continuous WinQSB fixtures")
func solvesLegacyContinuousQuadraticFixturesWithInstalledHiGHS() throws {
    guard let backend = HiGHSQuadraticProgrammingBackend.discovered() else { return }
    for filename in ["QP.QP_", "QPNORMAL.QP_"] {
        let model = try WinQSBQuadraticProgrammingParser.parse(
            from: LegacyCompressedFile.expandedData(from: Data(contentsOf: legacyFixtureURL(filename)))
        )
        let native = try NativeEducationalQuadraticProgrammingBackend().solve(model)
        let external = try backend.solve(model)
        #expect(abs(external.objectiveValue - native.objectiveValue) < 1e-4)
        for name in model.variableNames {
            #expect(abs((external.variableValues[name] ?? .nan) - (native.variableValues[name] ?? .nan)) < 1e-4)
        }
    }
}

private func crossTermModel() -> QuadraticProgram {
    QuadraticProgram(
        title: "Cross term and bounds", sense: .minimize,
        variableNames: ["x one", "x-one"], linearCoefficients: [-4, -5],
        quadraticMatrix: [[1, 0.5], [0.5, 1]],
        constraints: [LinearConstraint(name: "capacity", coefficients: [1, 1], relation: .lessThanOrEqual, rhs: 2)],
        lowerBounds: [-1, nil], upperBounds: [nil, 3], variableTypes: [.continuous, .continuous]
    )
}

private func zeroRowModel() -> QuadraticProgram {
    QuadraticProgram(
        title: "Zero row QP", sense: .minimize,
        variableNames: ["x"], linearCoefficients: [-2], quadraticMatrix: [[1]],
        constraints: [], lowerBounds: [nil], upperBounds: [nil], variableTypes: [.continuous]
    )
}

private func fakeHiGHS(
    solution: String,
    exitCode: Int32 = 0,
    requiredModelLines: [String] = [],
    requiredOptionLines: [String] = []
) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("qsb-fake-qp-highs-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let executable = directory.appendingPathComponent("highs")
    let modelChecks = requiredModelLines.map { "grep -Fq '\($0)' \"$model\" || exit 19" }.joined(separator: "\n")
    let optionChecks = requiredOptionLines.map { "grep -Fq '\($0)' \"$options\" || exit 19" }.joined(separator: "\n")
    let script = """
    #!/bin/sh
    model=''
    solution=''
    options=''
    while [ "$#" -gt 0 ]; do
      if [ "$1" = "--model_file" ]; then model="$2"; shift 2
      elif [ "$1" = "--solution_file" ]; then solution="$2"; shift 2
      elif [ "$1" = "--options_file" ]; then options="$2"; shift 2
      else shift
      fi
    done
    \(modelChecks)
    \(optionChecks)
    cat > "$solution" <<'QSB_SOLUTION'
    \(solution)
    QSB_SOLUTION
    exit \(exitCode)
    """
    try Data(script.utf8).write(to: executable)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
    return executable
}
