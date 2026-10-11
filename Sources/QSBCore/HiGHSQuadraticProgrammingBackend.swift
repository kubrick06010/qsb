import Foundation

/// Optional process adapter for continuous, strictly convex or concave QP.
/// The typed model and normalized JSON remain independent of the host solver.
public struct HiGHSQuadraticProgrammingBackend: QuadraticProgrammingBackend {
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
            notes: ["Continuous, strictly convex or concave QP through a host-provided HiGHS executable and QUADOBJ MPS."]
        )
    }

    public func runMetadata(for _: QuadraticProgram) -> SolverRunMetadata {
        SolverRunMetadata(
            backendKind: .externalHighPerformance,
            algorithm: "highsQuadraticProgramming",
            exactness: .exact,
            notes: ["Global optimum for supported continuous convex or concave QP, subject to HiGHS numerical tolerances."]
        )
    }

    public func solve(_ model: QuadraticProgram, options: SolverOptions = SolverOptions()) throws -> QuadraticProgramSolution {
        try QuadraticProgramValidator.validate(model)
        guard model.variableTypes.allSatisfy({ $0 == .continuous }) else {
            throw QuadraticProgrammingError.invalidModel("HiGHS does not support mixed-integer QP")
        }
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw QuadraticProgrammingError.externalSolverUnavailable(executableURL.path)
        }
        let limit = options.timeLimitSeconds ?? defaultTimeLimitSeconds
        if let limit, (!limit.isFinite || limit <= 0) {
            throw QuadraticProgrammingError.invalidModel("time limit must be finite and positive")
        }
        if options.nodeLimit != nil {
            throw QuadraticProgrammingError.invalidModel("node limit does not apply to continuous QP")
        }
        if let tolerance = options.tolerance, (!tolerance.isFinite || tolerance < 1e-10) {
            throw QuadraticProgrammingError.invalidModel("QP tolerance must be finite and at least 1e-10")
        }
        if let seed = options.randomSeed, seed < 0 || seed > Int(Int32.max) {
            throw QuadraticProgrammingError.invalidModel("random seed must be between 0 and 2147483647")
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("qsb-highs-qp-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let modelURL = directory.appendingPathComponent("model.mps")
        let solutionURL = directory.appendingPathComponent("solution.txt")
        let optionsURL = directory.appendingPathComponent("options.txt")
        try QuadraticProgramMPSExporter.export(model).write(to: modelURL, atomically: true, encoding: .utf8)

        var optionLines = ["output_flag = false", "log_to_console = false"]
        if let limit { optionLines.append("time_limit = \(limit)") }
        if let tolerance = options.tolerance { optionLines.append("kkt_tolerance = \(tolerance)") }
        if let seed = options.randomSeed { optionLines.append("random_seed = \(seed)") }
        try (optionLines.joined(separator: "\n") + "\n").write(to: optionsURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = executableURL
        process.currentDirectoryURL = directory
        process.arguments = [
            "--model_file", modelURL.path,
            "--solution_file", solutionURL.path,
            "--options_file", optionsURL.path
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw QuadraticProgrammingError.externalSolverFailed("could not launch '\(executableURL.path)': \(error.localizedDescription)")
        }
        process.waitUntilExit()
        guard process.terminationReason == .exit else {
            throw QuadraticProgrammingError.externalSolverFailed("process terminated by signal")
        }
        guard let data = try? Data(contentsOf: solutionURL) else {
            throw QuadraticProgrammingError.externalSolverFailed("process exited with status \(process.terminationStatus) without a solution file")
        }
        let solution = try HiGHSQuadraticSolutionParser.parse(
            data,
            model: model,
            exportedNames: QuadraticProgramMPSExporter.variableNames(for: model)
        )
        // HiGHS 1.15.1 can write an Optimal zero-row QP solution and exit 1.
        // Accept only that observed combination after parsing and checking the
        // complete primal solution; other nonzero exits remain failures.
        guard process.terminationStatus == 0 || (model.constraints.isEmpty && process.terminationStatus == 1) else {
            throw QuadraticProgrammingError.externalSolverFailed("process exited with status \(process.terminationStatus)")
        }
        return solution
    }
}

private enum HiGHSQuadraticSolutionParser {
    static func parse(_ data: Data, model: QuadraticProgram, exportedNames: [String]) throws -> QuadraticProgramSolution {
        let lines = String(decoding: data, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let statusIndex = lines.firstIndex(of: "Model status"), statusIndex + 1 < lines.count else {
            throw QuadraticProgrammingError.externalSolverMalformedOutput("missing model status")
        }
        let status = lines[statusIndex + 1].lowercased()
        switch status {
        case "optimal": break
        case "infeasible": throw QuadraticProgrammingError.infeasible
        case "unbounded", "unbounded or infeasible": throw QuadraticProgrammingError.unbounded
        default: throw QuadraticProgrammingError.externalSolverFailed("HiGHS model status: \(status)")
        }

        guard let objectiveLine = lines.first(where: { $0.hasPrefix("Objective ") }),
              let reportedObjective = Double(objectiveLine.dropFirst("Objective ".count)), reportedObjective.isFinite else {
            throw QuadraticProgrammingError.externalSolverMalformedOutput("missing or invalid objective")
        }
        guard let columnsIndex = lines.firstIndex(where: { $0.hasPrefix("# Columns") }),
              let rowsIndex = lines[(columnsIndex + 1)...].firstIndex(where: { $0.hasPrefix("# Rows") }),
              let declaredCount = Int(lines[columnsIndex].dropFirst("# Columns".count).trimmingCharacters(in: .whitespaces)),
              declaredCount == exportedNames.count else {
            throw QuadraticProgrammingError.externalSolverMalformedOutput("missing or mismatched primal column section")
        }
        var exportedValues: [String: Double] = [:]
        for line in lines[(columnsIndex + 1)..<rowsIndex] {
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count >= 2, let value = Double(fields[1]), value.isFinite else {
                throw QuadraticProgrammingError.externalSolverMalformedOutput("invalid primal value '\(line)'")
            }
            let name = String(fields[0])
            guard exportedValues[name] == nil else {
                throw QuadraticProgrammingError.externalSolverMalformedOutput("duplicate primal column '\(name)'")
            }
            exportedValues[name] = value
        }
        guard exportedValues.count == declaredCount else {
            throw QuadraticProgrammingError.externalSolverMalformedOutput("primal column count does not match model")
        }
        let values = try exportedNames.map { name -> Double in
            guard let value = exportedValues[name] else {
                throw QuadraticProgrammingError.externalSolverMalformedOutput("missing primal column '\(name)'")
            }
            return value
        }
        try checkFeasibility(values, model: model)
        let objective = objectiveValue(values, model: model)
        guard objective.isFinite,
              abs(objective - reportedObjective) <= 1e-5 * max(1, abs(objective), abs(reportedObjective)) else {
            throw QuadraticProgrammingError.externalSolverMalformedOutput("reported objective disagrees with the normalized quadratic model")
        }
        return QuadraticProgramSolution(
            objectiveValue: objective,
            variableValues: Dictionary(uniqueKeysWithValues: zip(model.variableNames, values)),
            activeConstraints: activeConstraints(values, model: model)
        )
    }

    private static func objectiveValue(_ values: [Double], model: QuadraticProgram) -> Double {
        let linear = zip(values, model.linearCoefficients).reduce(0.0) { $0 + $1.0 * $1.1 }
        let quadratic = values.indices.reduce(0.0) { sum, row in
            sum + values.indices.reduce(0.0) { $0 + values[row] * model.quadraticMatrix[row][$1] * values[$1] }
        }
        return linear + quadratic
    }

    private static func checkFeasibility(_ values: [Double], model: QuadraticProgram) throws {
        for index in values.indices {
            let value = values[index]
            if let lower = model.lowerBounds[index], value < lower - tolerance(lower) {
                throw QuadraticProgrammingError.externalSolverMalformedOutput("primal value violates lower bound for '\(model.variableNames[index])'")
            }
            if let upper = model.upperBounds[index], value > upper + tolerance(upper) {
                throw QuadraticProgrammingError.externalSolverMalformedOutput("primal value violates upper bound for '\(model.variableNames[index])'")
            }
        }
        for constraint in model.constraints {
            let lhs = zip(constraint.coefficients, values).reduce(0.0) { $0 + $1.0 * $1.1 }
            let slack = lhs - constraint.rhs
            let threshold = tolerance(max(abs(lhs), abs(constraint.rhs)))
            let valid: Bool
            switch constraint.relation {
            case .lessThanOrEqual: valid = slack <= threshold
            case .greaterThanOrEqual: valid = slack >= -threshold
            case .equal: valid = abs(slack) <= threshold
            }
            guard valid else {
                throw QuadraticProgrammingError.externalSolverMalformedOutput("primal value violates constraint '\(constraint.name)'")
            }
        }
    }

    private static func activeConstraints(_ values: [Double], model: QuadraticProgram) -> [String] {
        var active: [String] = []
        for constraint in model.constraints {
            let lhs = zip(constraint.coefficients, values).reduce(0.0) { $0 + $1.0 * $1.1 }
            if abs(lhs - constraint.rhs) <= tolerance(max(abs(lhs), abs(constraint.rhs))) {
                active.append(constraint.name)
            }
        }
        for index in values.indices {
            if let lower = model.lowerBounds[index], abs(values[index] - lower) <= tolerance(lower) {
                active.append("\(model.variableNames[index]) lower")
            }
            if let upper = model.upperBounds[index], abs(values[index] - upper) <= tolerance(upper) {
                active.append("\(model.variableNames[index]) upper")
            }
        }
        return active
    }

    private static func tolerance(_ scale: Double) -> Double {
        1e-6 * max(1, abs(scale))
    }
}
