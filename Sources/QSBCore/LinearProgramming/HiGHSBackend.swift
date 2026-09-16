import Foundation

/// Locates a host-provided HiGHS executable without making it a package or
/// repository dependency. `QSB_HIGHS_PATH` takes precedence over `PATH` so a
/// caller can select a pinned, independently installed build.
public enum HiGHSExecutableLocator {
    public static let environmentVariable = "QSB_HIGHS_PATH"

    public static func locate(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL? {
        if let configured = environment[environmentVariable] {
            if configured.contains("/") {
                if let url = executableURL(for: configured) { return url }
            } else if let path = environment["PATH"], let url = executableURL(named: configured, in: path) {
                return url
            }
        }
        guard let path = environment["PATH"] else { return nil }
        return executableURL(named: "highs", in: path)
    }

    private static func executableURL(named name: String, in path: String) -> URL? {
        for directory in path.split(separator: ":", omittingEmptySubsequences: true) {
            if let url = executableURL(for: String(directory) + "/" + name) {
                return url
            }
        }
        return nil
    }

    private static func executableURL(for rawPath: String) -> URL? {
        let fileManager = FileManager.default
        var url = URL(fileURLWithPath: rawPath)
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            url.appendPathComponent("highs")
        }
        return fileManager.isExecutableFile(atPath: url.path) ? url.standardizedFileURL : nil
    }
}

/// HiGHS adapter backed by its standalone executable and free MPS interchange.
///
/// The adapter is intentionally process-based: it keeps the Swift package
/// portable and avoids shipping a solver binary while still allowing users to
/// install a permissively licensed engine independently. The normalized model
/// remains the source of truth and the temporary files are removed after each
/// solve.
public struct HiGHSLinearProgrammingBackend: LinearProgrammingBackend {
    public let executableURL: URL
    public let defaultTimeLimitSeconds: Double?

    public init(executableURL: URL, defaultTimeLimitSeconds: Double? = nil) {
        self.executableURL = executableURL
        self.defaultTimeLimitSeconds = defaultTimeLimitSeconds
    }

    public static func discovered(defaultTimeLimitSeconds: Double? = nil) -> Self? {
        guard let executableURL = HiGHSExecutableLocator.locate() else { return nil }
        return Self(executableURL: executableURL, defaultTimeLimitSeconds: defaultTimeLimitSeconds)
    }

    public var capabilities: SolverCapabilities {
        SolverCapabilities(
            backendKind: .externalHighPerformance,
            solves: true,
            validates: true,
            exportsStructuredSolution: true,
            notes: [
                "Uses a host-provided HiGHS executable through validated free MPS.",
                "Supports LP and MIP models; the executable and version remain host configuration.",
                "SolverOptions are passed through a temporary HiGHS options file."
            ]
        )
    }

    public func solve(
        _ program: LinearProgram,
        mode _: LinearProgramSolveMode,
        options: SolverOptions = SolverOptions()
    ) throws -> LinearProgramSolution {
        try LinearProgramValidator.validate(program)
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw LinearProgramError.externalSolverUnavailable(executableURL.path)
        }
        if let limit = options.timeLimitSeconds ?? defaultTimeLimitSeconds,
           (!limit.isFinite || limit <= 0) {
            throw LinearProgramError.invalidModel("time limit must be finite and positive")
        }
        if let nodes = options.nodeLimit, nodes <= 0 {
            throw LinearProgramError.invalidModel("node limit must be positive")
        }
        if let tolerance = options.tolerance, (!tolerance.isFinite || tolerance < 0) {
            throw LinearProgramError.invalidModel("solver tolerance must be finite and nonnegative")
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("qsb-highs-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let modelURL = directory.appendingPathComponent("model.mps")
        let solutionURL = directory.appendingPathComponent("solution.txt")
        let optionsURL = directory.appendingPathComponent("options.txt")
        try LinearProgramMPSExporter.export(program).write(to: modelURL, atomically: true, encoding: .utf8)

        var optionLines = [
            // The standalone app otherwise defaults to Highs.log in its cwd.
            "output_flag = false",
            "log_to_console = false"
        ]
        if let limit = options.timeLimitSeconds ?? defaultTimeLimitSeconds {
            optionLines.append("time_limit = \(limit)")
        }
        if let nodes = options.nodeLimit {
            optionLines.append("mip_max_nodes = \(nodes)")
        }
        if let tolerance = options.tolerance {
            optionLines.append("mip_rel_gap = \(tolerance)")
        }
        if let randomSeed = options.randomSeed {
            optionLines.append("random_seed = \(randomSeed)")
        }
        try (optionLines.joined(separator: "\n") + "\n").write(to: optionsURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = executableURL
        process.currentDirectoryURL = directory
        let arguments = [
            "--model_file", modelURL.path,
            "--solution_file", solutionURL.path,
            "--options_file", optionsURL.path
        ]
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw LinearProgramError.externalSolverFailed("could not launch '\(executableURL.path)': \(error.localizedDescription)")
        }
        process.waitUntilExit()
        guard process.terminationReason == .exit else {
            throw LinearProgramError.externalSolverFailed("process terminated by signal")
        }
        guard process.terminationStatus == 0 else {
            throw LinearProgramError.externalSolverFailed("process exited with status \(process.terminationStatus)")
        }
        guard let solutionData = try? Data(contentsOf: solutionURL) else {
            throw LinearProgramError.externalSolverMalformedOutput("solution file was not written")
        }
        return try HiGHSSolutionParser.parse(
            solutionData,
            program: program,
            exportedVariableNames: LinearProgramMPSExporter.variableNames(for: program)
        )
    }
}

private enum HiGHSSolutionParser {
    static func parse(
        _ data: Data,
        program: LinearProgram,
        exportedVariableNames: [String]
    ) throws -> LinearProgramSolution {
        let lines = String(decoding: data, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let statusIndex = lines.firstIndex(of: "Model status"), statusIndex + 1 < lines.count else {
            throw LinearProgramError.externalSolverMalformedOutput("missing model status")
        }
        let status = lines[statusIndex + 1]
        switch status.lowercased() {
        case "optimal": break
        case "infeasible": throw LinearProgramError.infeasible
        case "unbounded", "unbounded or infeasible": throw LinearProgramError.unbounded
        default: throw LinearProgramError.externalSolverFailed("HiGHS model status: \(status)")
        }

        guard let columnsIndex = lines.firstIndex(where: { $0.hasPrefix("# Columns") }),
              let rowsIndex = lines[(columnsIndex + 1)...].firstIndex(where: { $0.hasPrefix("# Rows") }),
              columnsIndex < rowsIndex else {
            throw LinearProgramError.externalSolverMalformedOutput("missing primal column section")
        }
        var values: [String: Double] = [:]
        for line in lines[(columnsIndex + 1)..<rowsIndex] {
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count >= 2, let value = Double(fields[1]), value.isFinite else {
                throw LinearProgramError.externalSolverMalformedOutput("invalid primal value '\(line)'")
            }
            let name = String(fields[0])
            guard values[name] == nil else {
                throw LinearProgramError.externalSolverMalformedOutput("duplicate primal column '\(name)'")
            }
            values[name] = value
        }

        guard exportedVariableNames.count == program.variableNames.count else {
            throw LinearProgramError.externalSolverMalformedOutput("exported variable count does not match model")
        }
        var variableValues: [String: Double] = [:]
        for (index, exportedName) in exportedVariableNames.enumerated() {
            guard let value = values[exportedName] else {
                throw LinearProgramError.externalSolverMalformedOutput("missing primal column '\(exportedName)'")
            }
            variableValues[program.variableNames[index]] = value
        }
        let objectiveValue = zip(program.variableNames, program.objectiveCoefficients)
            .reduce(0.0) { $0 + $1.1 * (variableValues[$1.0] ?? 0) }
        guard objectiveValue.isFinite else {
            throw LinearProgramError.externalSolverMalformedOutput("objective value is not finite")
        }
        return LinearProgramSolution(objectiveValue: objectiveValue, variableValues: variableValues)
    }
}
