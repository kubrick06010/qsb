import Foundation
import Testing
@testable import QSBCore

@Suite struct HiGHSBackendTests {
    @Test func solvesThroughInjectedExecutableAndMapsSanitizedNames() throws {
        let executable = try makeFakeExecutable(solution: """
        Model status
        Optimal

        # Primal solution values
        Feasible
        Objective 8
        # Columns 2
        X_ONE 2
        X_ONE_2 3
        # Rows 1
        C1 5
        """)
        defer { try? FileManager.default.removeItem(at: executable.deletingLastPathComponent()) }

        let program = LinearProgram(
            title: "Injected HiGHS",
            sense: .maximize,
            variableNames: ["x one", "x-one"],
            objectiveCoefficients: [1, 2],
            constraints: [LinearConstraint(name: "limit", coefficients: [1, 1], relation: .lessThanOrEqual, rhs: 5)]
        )
        let backend = HiGHSLinearProgrammingBackend(executableURL: executable)
        let solution = try backend.solve(program, mode: .continuous)
        #expect(solution.variableValues == ["x one": 2, "x-one": 3])
        #expect(solution.objectiveValue == 8)
        #expect(backend.capabilities.backendKind == .externalHighPerformance)
    }

    @Test func passesSolverOptionsThroughTemporaryHiGHSOptionsFile() throws {
        let executable = try makeFakeExecutable(
            solution: """
            Model status
            Optimal

            # Primal solution values
            Feasible
            Objective 1
            # Columns 1
            X 1
            # Rows 0
            """,
            requiredOptions: [
                "output_flag = false",
                "log_to_console = false",
                "time_limit = 2.5",
                "mip_max_nodes = 7",
                "mip_rel_gap = 0.01",
                "random_seed = 11"
            ]
        )
        defer { try? FileManager.default.removeItem(at: executable.deletingLastPathComponent()) }

        let program = LinearProgram(
            title: "Options",
            sense: .maximize,
            variableNames: ["X"],
            objectiveCoefficients: [1],
            constraints: []
        )
        let solution = try HiGHSLinearProgrammingBackend(executableURL: executable).solve(
            program,
            mode: .continuous,
            options: SolverOptions(
                timeLimitSeconds: 2.5,
                nodeLimit: 7,
                tolerance: 0.01,
                randomSeed: 11
            )
        )
        #expect(solution.objectiveValue == 1)
    }

    @Test func propagatesExternalStatusesAsTypedErrors() throws {
        let executable = try makeFakeExecutable(solution: "Model status\nInfeasible\n")
        defer { try? FileManager.default.removeItem(at: executable.deletingLastPathComponent()) }
        let program = LinearProgram(
            title: "Infeasible",
            sense: .minimize,
            variableNames: ["x"],
            objectiveCoefficients: [1],
            constraints: []
        )
        do {
            _ = try HiGHSLinearProgrammingBackend(executableURL: executable).solve(program, mode: .continuous)
            Issue.record("Expected HiGHS infeasible status to throw")
        } catch LinearProgramError.infeasible {
            // Expected typed status mapping.
        } catch {
            Issue.record("Expected LinearProgramError.infeasible, got \(error)")
        }
    }

    @Test func discoversConfiguredExecutableByPathOrCommandName() throws {
        let executable = try makeFakeExecutable(solution: "Model status\nOptimal\n# Columns 0\n# Rows 0\n")
        defer { try? FileManager.default.removeItem(at: executable.deletingLastPathComponent()) }
        let directory = executable.deletingLastPathComponent().path
        let pathEnvironment = [
            HiGHSExecutableLocator.environmentVariable: executable.path,
            "PATH": "/missing"
        ]
        #expect(HiGHSExecutableLocator.locate(environment: pathEnvironment)?.path == executable.path)
        let commandEnvironment = [
            HiGHSExecutableLocator.environmentVariable: "highs",
            "PATH": directory
        ]
        #expect(HiGHSExecutableLocator.locate(environment: commandEnvironment)?.path == executable.path)
    }

    @Test func usesInstalledHiGHSWhenAvailable() throws {
        guard let backend = HiGHSLinearProgrammingBackend.discovered() else { return }
        let program = LinearProgram(
            title: "Installed HiGHS",
            sense: .maximize,
            variableNames: ["x", "y"],
            objectiveCoefficients: [3, 2],
            constraints: [LinearConstraint(name: "capacity", coefficients: [1, 2], relation: .lessThanOrEqual, rhs: 8)],
            upperBounds: [nil, 4]
        )
        let solution = try backend.solve(program, mode: .continuous)
        #expect(abs(solution.objectiveValue - 24) < 1e-8)
    }

    private func makeFakeExecutable(solution: String, requiredOptions: [String] = []) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("qsb-fake-highs-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executable = directory.appendingPathComponent("highs")
        let escaped = solution
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")
        let optionChecks = requiredOptions.map { option in
            let escapedOption = option
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            return "grep -Fq \"\(escapedOption)\" \"$options\" || exit 19"
        }.joined(separator: "\n")
        let script = """
        #!/bin/sh
        solution=''
        options=''
        while [ "$#" -gt 0 ]; do
          if [ "$1" = "--solution_file" ]; then solution="$2"; shift 2
          elif [ "$1" = "--options_file" ]; then options="$2"; shift 2
          else shift
          fi
        done
        \(optionChecks)
        printf \"%s\\n\" \"\" > \"$solution\"
        printf \"%s\" "\(escaped)" > \"$solution\"
        """
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        return executable
    }
}
