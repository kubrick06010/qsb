import Foundation

public struct FlowShopOperation: Codable, Equatable, Sendable {
    public let machineID: Int
    public let duration: Int

    public init(machineID: Int, duration: Int) {
        self.machineID = machineID
        self.duration = duration
    }
}

public struct FlowShopJob: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let operations: [FlowShopOperation]
    public let readyTime: Int?
    public let dueDate: Int?
    public let weight: Double?

    public init(
        id: Int,
        name: String,
        operations: [FlowShopOperation],
        readyTime: Int? = nil,
        dueDate: Int? = nil,
        weight: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.operations = operations
        self.readyTime = readyTime
        self.dueDate = dueDate
        self.weight = weight
    }
}

public struct FlowShopMachine: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let readyTime: Int?

    public init(id: Int, name: String, readyTime: Int? = nil) {
        self.id = id
        self.name = name
        self.readyTime = readyTime
    }
}

public struct FlowShopProblem: Codable, Equatable, Sendable {
    public let title: String
    public let timeUnit: String
    public let jobs: [FlowShopJob]
    public let machines: [FlowShopMachine]

    public init(title: String, timeUnit: String, jobs: [FlowShopJob], machines: [FlowShopMachine]) {
        self.title = title
        self.timeUnit = timeUnit
        self.jobs = jobs
        self.machines = machines
    }
}

public struct ScheduledOperation: Codable, Equatable, Sendable {
    public let machineID: Int
    public let start: Int
    public let finish: Int
}

public struct FlowShopJobSchedule: Codable, Equatable, Sendable {
    public let jobID: Int
    public let jobName: String
    public let operations: [ScheduledOperation]
    public let completionTime: Int
}

public struct FlowShopSolution: Codable, Equatable, Sendable {
    public let sequence: [String]
    public let makespan: Int
    public let machineCompletionTimes: [Int]
    public let schedules: [FlowShopJobSchedule]
}

public struct JobShopProblem: Codable, Equatable, Sendable {
    public let title: String
    public let timeUnit: String
    public let jobs: [FlowShopJob]
    public let machines: [FlowShopMachine]

    public init(title: String, timeUnit: String, jobs: [FlowShopJob], machines: [FlowShopMachine]) {
        self.title = title
        self.timeUnit = timeUnit
        self.jobs = jobs
        self.machines = machines
    }
}

public struct JobShopDispatchStep: Codable, Equatable, Sendable {
    public let jobID: Int
    public let jobName: String
    public let operationIndex: Int
    public let machineID: Int
    public let start: Int
    public let finish: Int
}

public struct JobShopSolution: Codable, Equatable, Sendable {
    public let makespan: Int
    public let machineCompletionTimes: [Int]
    public let dispatchOrder: [JobShopDispatchStep]
    public let schedules: [FlowShopJobSchedule]
}

public enum SchedulingProblemKind: String, Codable, Sendable {
    case flowShop
    case jobShop
}

public struct SchedulingGanttOperation: Codable, Equatable, Sendable {
    public let jobID: Int
    public let jobName: String
    public let operationIndex: Int
    public let machineID: Int
    public let machineName: String
    public let start: Int
    public let finish: Int
    public let duration: Int
    public let idleBefore: Int
    public let sequenceIndex: Int

    public init(
        jobID: Int,
        jobName: String,
        operationIndex: Int,
        machineID: Int,
        machineName: String,
        start: Int,
        finish: Int,
        duration: Int,
        idleBefore: Int,
        sequenceIndex: Int
    ) {
        self.jobID = jobID
        self.jobName = jobName
        self.operationIndex = operationIndex
        self.machineID = machineID
        self.machineName = machineName
        self.start = start
        self.finish = finish
        self.duration = duration
        self.idleBefore = idleBefore
        self.sequenceIndex = sequenceIndex
    }
}

public struct SchedulingMachineTimeline: Codable, Equatable, Sendable {
    public let machineID: Int
    public let machineName: String
    public let readyTime: Int
    public let completionTime: Int
    public let operations: [SchedulingGanttOperation]

    public init(
        machineID: Int,
        machineName: String,
        readyTime: Int,
        completionTime: Int,
        operations: [SchedulingGanttOperation]
    ) {
        self.machineID = machineID
        self.machineName = machineName
        self.readyTime = readyTime
        self.completionTime = completionTime
        self.operations = operations
    }
}

public struct SchedulingSolutionDocument: Codable, Equatable, Sendable {
    public let kind: SchedulingProblemKind
    public let backend: SolverRunMetadata
    public let title: String
    public let timeUnit: String
    public let makespan: Int
    public let jobSequence: [String]
    public let machineCompletionTimes: [Int]
    public let operations: [SchedulingGanttOperation]
    public let machineTimelines: [SchedulingMachineTimeline]

    public init(
        kind: SchedulingProblemKind,
        backend: SolverRunMetadata,
        title: String,
        timeUnit: String,
        makespan: Int,
        jobSequence: [String],
        machineCompletionTimes: [Int],
        operations: [SchedulingGanttOperation],
        machineTimelines: [SchedulingMachineTimeline]
    ) {
        self.kind = kind
        self.backend = backend
        self.title = title
        self.timeUnit = timeUnit
        self.makespan = makespan
        self.jobSequence = jobSequence
        self.machineCompletionTimes = machineCompletionTimes
        self.operations = operations
        self.machineTimelines = machineTimelines
    }
}

public enum SchedulingModelError: Error, CustomStringConvertible {
    case unsupportedFormat
    case invalidNumericValue(String)
    case invalidModel(String)

    public var description: String {
        switch self {
        case .unsupportedFormat:
            "Unsupported scheduling model format"
        case .invalidNumericValue(let value):
            "Invalid numeric value: \(value)"
        case .invalidModel(let detail):
            "Invalid scheduling model: \(detail)"
        }
    }
}

public protocol SchedulingBackend: Sendable {
    var capabilities: SolverCapabilities { get }

    func validationReport(for problem: FlowShopProblem) -> ValidationReport
    func validationReport(for problem: JobShopProblem) -> ValidationReport
    func solve(_ problem: FlowShopProblem, options: SolverOptions) throws -> FlowShopSolution
    func solve(_ problem: JobShopProblem, options: SolverOptions) throws -> JobShopSolution
}

public extension SchedulingBackend {
    func validationReport(for problem: FlowShopProblem) -> ValidationReport {
        ValidationReport(
            backend: capabilities.backendKind,
            diagnostics: FlowShopValidator.diagnostics(for: problem)
        )
    }

    func validationReport(for problem: JobShopProblem) -> ValidationReport {
        ValidationReport(
            backend: capabilities.backendKind,
            diagnostics: JobShopValidator.diagnostics(for: problem)
        )
    }

    func solve(_ problem: FlowShopProblem) throws -> FlowShopSolution {
        try solve(problem, options: SolverOptions())
    }

    func solve(_ problem: JobShopProblem) throws -> JobShopSolution {
        try solve(problem, options: SolverOptions())
    }
}

public struct NativeEducationalSchedulingBackend: SchedulingBackend {
    public init() {}

    public var capabilities: SolverCapabilities {
        SolverCapabilities(
            backendKind: .nativeEducational,
            solves: true,
            validates: true,
            exportsStructuredSolution: true,
            notes: [
                "Uses exact fixture-scale flow-shop permutation search.",
                "Uses exact fixture-scale job-shop branch and bound with dominance pruning."
            ]
        )
    }

    public func solve(
        _ problem: FlowShopProblem,
        options _: SolverOptions = SolverOptions()
    ) throws -> FlowShopSolution {
        try FlowShopSolver.solve(problem)
    }

    public func solve(
        _ problem: JobShopProblem,
        options _: SolverOptions = SolverOptions()
    ) throws -> JobShopSolution {
        try JobShopSolver.solve(problem)
    }
}

public struct ValidateOnlySchedulingBackend: SchedulingBackend {
    public init() {}

    public var capabilities: SolverCapabilities {
        SolverCapabilities(
            backendKind: .validateOnly,
            solves: false,
            validates: true,
            exportsStructuredSolution: false,
            notes: [
                "Runs scheduling validation without solving the model."
            ]
        )
    }

    public func solve(
        _ problem: FlowShopProblem,
        options _: SolverOptions = SolverOptions()
    ) throws -> FlowShopSolution {
        throw SchedulingModelError.invalidModel("validateOnly backend does not solve flow-shop models")
    }

    public func solve(
        _ problem: JobShopProblem,
        options _: SolverOptions = SolverOptions()
    ) throws -> JobShopSolution {
        throw SchedulingModelError.invalidModel("validateOnly backend does not solve job-shop models")
    }
}

public enum SchedulingBackends {
    public static func backend(for kind: SolverBackendKind) -> (any SchedulingBackend)? {
        switch kind {
        case .nativeEducational:
            NativeEducationalSchedulingBackend()
        case .validateOnly:
            ValidateOnlySchedulingBackend()
        case .externalHighPerformance:
            nil
        }
    }
}

public enum SchedulingSolutionJSON {
    public static func flowShopDocument(
        problem: FlowShopProblem,
        solution: FlowShopSolution,
        backend: SolverRunMetadata
    ) -> SchedulingSolutionDocument {
        let operations = ganttOperations(
            schedules: solution.schedules,
            machines: problem.machines
        )
        return SchedulingSolutionDocument(
            kind: .flowShop,
            backend: backend,
            title: problem.title,
            timeUnit: problem.timeUnit,
            makespan: solution.makespan,
            jobSequence: solution.sequence,
            machineCompletionTimes: solution.machineCompletionTimes,
            operations: operations,
            machineTimelines: machineTimelines(
                machines: problem.machines,
                machineCompletionTimes: solution.machineCompletionTimes,
                operations: operations
            )
        )
    }

    public static func jobShopDocument(
        problem: JobShopProblem,
        solution: JobShopSolution,
        backend: SolverRunMetadata
    ) -> SchedulingSolutionDocument {
        let operations = ganttOperations(
            schedules: solution.schedules,
            machines: problem.machines
        )
        return SchedulingSolutionDocument(
            kind: .jobShop,
            backend: backend,
            title: problem.title,
            timeUnit: problem.timeUnit,
            makespan: solution.makespan,
            jobSequence: solution.dispatchOrder.map(\.jobName),
            machineCompletionTimes: solution.machineCompletionTimes,
            operations: operations,
            machineTimelines: machineTimelines(
                machines: problem.machines,
                machineCompletionTimes: solution.machineCompletionTimes,
                operations: operations
            )
        )
    }

    public static func encode(_ document: SchedulingSolutionDocument) throws -> Data {
        try encoder.encode(document)
    }

    private static func ganttOperations(
        schedules: [FlowShopJobSchedule],
        machines: [FlowShopMachine]
    ) -> [SchedulingGanttOperation] {
        let machineNames = Dictionary(uniqueKeysWithValues: machines.map { ($0.id, $0.name) })
        let readyTimes = Dictionary(uniqueKeysWithValues: machines.map { ($0.id, $0.readyTime ?? 0) })
        let flatOperations = schedules.flatMap { schedule in
            schedule.operations.enumerated().map { offset, operation in
                (
                    schedule: schedule,
                    operationIndex: offset + 1,
                    operation: operation
                )
            }
        }
        let indexedOperations = flatOperations
            .sorted {
                if $0.operation.start != $1.operation.start { return $0.operation.start < $1.operation.start }
                if $0.operation.machineID != $1.operation.machineID { return $0.operation.machineID < $1.operation.machineID }
                if $0.schedule.jobID != $1.schedule.jobID { return $0.schedule.jobID < $1.schedule.jobID }
                return $0.operationIndex < $1.operationIndex
            }
            .enumerated()

        var previousFinishByMachine: [Int: Int] = readyTimes
        return indexedOperations.map { sequenceIndex, entry in
            let operation = entry.operation
            let previousFinish = previousFinishByMachine[operation.machineID] ?? 0
            let idleBefore = max(0, operation.start - previousFinish)
            previousFinishByMachine[operation.machineID] = operation.finish
            return SchedulingGanttOperation(
                jobID: entry.schedule.jobID,
                jobName: entry.schedule.jobName,
                operationIndex: entry.operationIndex,
                machineID: operation.machineID,
                machineName: machineNames[operation.machineID] ?? "Machine \(operation.machineID)",
                start: operation.start,
                finish: operation.finish,
                duration: operation.finish - operation.start,
                idleBefore: idleBefore,
                sequenceIndex: sequenceIndex + 1
            )
        }
    }

    private static func machineTimelines(
        machines: [FlowShopMachine],
        machineCompletionTimes: [Int],
        operations: [SchedulingGanttOperation]
    ) -> [SchedulingMachineTimeline] {
        let operationsByMachine = Dictionary(grouping: operations, by: \.machineID)
        return machines.enumerated().map { index, machine in
            let machineOperations = (operationsByMachine[machine.id] ?? []).sorted {
                if $0.start != $1.start { return $0.start < $1.start }
                if $0.finish != $1.finish { return $0.finish < $1.finish }
                return $0.sequenceIndex < $1.sequenceIndex
            }
            return SchedulingMachineTimeline(
                machineID: machine.id,
                machineName: machine.name,
                readyTime: machine.readyTime ?? 0,
                completionTime: machineCompletionTimes[safe: index] ?? machineOperations.map(\.finish).max() ?? (machine.readyTime ?? 0),
                operations: machineOperations
            )
        }
    }

    private static var encoder: JSONEncoder { NormalizedJSONCoding.encoder() }
}

public enum FlowShopValidator {
    public static func diagnostics(for problem: FlowShopProblem) -> [ValidationDiagnostic] {
        var diagnostics: [ValidationDiagnostic] = []
        appendCommonDiagnostics(
            jobs: problem.jobs,
            machines: problem.machines,
            family: "flowShop",
            diagnostics: &diagnostics
        )

        let machineIDs = problem.machines.map(\.id)
        if let firstJob = problem.jobs.first {
            let referenceOrder = firstJob.operations.map(\.machineID)
            if referenceOrder != machineIDs {
                diagnostics.append(error(
                    "scheduling.flowShop.machineOrder",
                    "flow shop machine rows must match operation order",
                    path: "jobs.\(firstJob.name).operations"
                ))
            }
            for job in problem.jobs where job.operations.map(\.machineID) != referenceOrder {
                diagnostics.append(error(
                    "scheduling.flowShop.sameRouting",
                    "all flow shop jobs must visit machines in the same order",
                    path: "jobs.\(job.name).operations"
                ))
            }
        }

        if problem.jobs.count > 8 {
            diagnostics.append(warning(
                "scheduling.flowShop.fixtureScale",
                "native educational flow-shop solver currently supports up to 8 jobs",
                path: "jobs"
            ))
        }

        return finalized(diagnostics, validCode: "scheduling.flowShop.valid", validMessage: "Flow shop model is valid")
    }

    public static func validate(_ problem: FlowShopProblem) throws {
        if let diagnostic = diagnostics(for: problem).first(where: { $0.severity == .error }) {
            throw SchedulingModelError.invalidModel(diagnostic.message)
        }
    }
}

public enum JobShopValidator {
    public static func diagnostics(for problem: JobShopProblem) -> [ValidationDiagnostic] {
        var diagnostics: [ValidationDiagnostic] = []
        appendCommonDiagnostics(
            jobs: problem.jobs,
            machines: problem.machines,
            family: "jobShop",
            diagnostics: &diagnostics
        )

        let machineIDs = Set(problem.machines.map(\.id))
        for job in problem.jobs {
            for operation in job.operations where !machineIDs.contains(operation.machineID) {
                diagnostics.append(error(
                    "scheduling.jobShop.missingMachine",
                    "job shop operation references missing machine \(operation.machineID)",
                    path: "jobs.\(job.name).operations"
                ))
            }
        }

        let totalOperationCount = problem.jobs.reduce(0) { $0 + $1.operations.count }
        if problem.jobs.count > 6 || totalOperationCount > 36 {
            diagnostics.append(warning(
                "scheduling.jobShop.fixtureScale",
                "native educational job-shop solver currently supports up to 6 jobs and 36 operations",
                path: "jobs"
            ))
        }

        return finalized(diagnostics, validCode: "scheduling.jobShop.valid", validMessage: "Job shop model is valid")
    }

    public static func validate(_ problem: JobShopProblem) throws {
        if let diagnostic = diagnostics(for: problem).first(where: { $0.severity == .error }) {
            throw SchedulingModelError.invalidModel(diagnostic.message)
        }
    }
}

private func appendCommonDiagnostics(
    jobs: [FlowShopJob],
    machines: [FlowShopMachine],
    family: String,
    diagnostics: inout [ValidationDiagnostic]
) {
    if jobs.isEmpty {
        diagnostics.append(error("scheduling.\(family).jobs.empty", "\(family) jobs must not be empty", path: "jobs"))
    }
    if machines.isEmpty {
        diagnostics.append(error("scheduling.\(family).machines.empty", "\(family) machines must not be empty", path: "machines"))
    }

    let machineIDs = machines.map(\.id)
    if Set(machineIDs).count != machineIDs.count {
        diagnostics.append(error("scheduling.\(family).machines.duplicate", "\(family) machine ids must be unique", path: "machines"))
    }
    let jobIDs = jobs.map(\.id)
    if Set(jobIDs).count != jobIDs.count {
        diagnostics.append(error("scheduling.\(family).jobs.duplicate", "\(family) job ids must be unique", path: "jobs"))
    }

    for job in jobs {
        if job.operations.isEmpty {
            diagnostics.append(error("scheduling.\(family).operations.empty", "\(family) jobs must have at least one operation", path: "jobs.\(job.name).operations"))
        }
        for operation in job.operations where operation.duration < 0 {
            diagnostics.append(error("scheduling.\(family).duration.nonnegative", "\(family) operation durations must be nonnegative", path: "jobs.\(job.name).operations"))
        }
    }
}

private func finalized(
    _ diagnostics: [ValidationDiagnostic],
    validCode: String,
    validMessage: String
) -> [ValidationDiagnostic] {
    guard diagnostics.contains(where: { $0.severity == .error }) == false else {
        return diagnostics
    }
    return diagnostics + [
        ValidationDiagnostic(
            severity: .info,
            code: validCode,
            message: validMessage
        )
    ]
}

private func error(_ code: String, _ message: String, path: String?) -> ValidationDiagnostic {
    ValidationDiagnostic(severity: .error, code: code, message: message, path: path)
}

private func warning(_ code: String, _ message: String, path: String?) -> ValidationDiagnostic {
    ValidationDiagnostic(severity: .warning, code: code, message: message, path: path)
}

public enum WinQSBSchedulingParser {
    public static func parseFlowShop(from data: Data) throws -> FlowShopProblem {
        let lines = try tabularLines(from: data)
        guard let metadata = lines.first,
              metadata.count >= 7,
              metadata[0] == "SCH",
              metadata[6] == "-1",
              let jobCount = Int(metadata[3]),
              let operationCount = Int(metadata[4]),
              let machineCount = Int(metadata[5]),
              jobCount > 0,
              operationCount > 0,
              machineCount > 0,
              lines.count >= jobCount + machineCount + 3
        else {
            throw SchedulingModelError.unsupportedFormat
        }

        let jobRows = lines[2..<(2 + jobCount)]
        let jobs = try jobRows.map { row -> FlowShopJob in
            guard row.count >= operationCount + 2,
                  let id = Int(row[0])
            else {
                throw SchedulingModelError.unsupportedFormat
            }
            let operations = try (0..<operationCount).map { operationIndex in
                try parseOperation(row[2 + operationIndex])
            }
            return FlowShopJob(
                id: id,
                name: row[1],
                operations: operations,
                readyTime: try optionalInt(row[safe: operationCount + 2]),
                dueDate: try optionalInt(row[safe: operationCount + 3]),
                weight: try optionalDouble(row[safe: operationCount + 4])
            )
        }

        let machineRowsStart = 2 + jobCount + 1
        let machines = try lines[machineRowsStart..<(machineRowsStart + machineCount)].map { row -> FlowShopMachine in
            guard row.count >= 2,
                  let id = Int(row[0])
            else {
                throw SchedulingModelError.unsupportedFormat
            }
            return FlowShopMachine(
                id: id,
                name: row[1],
                readyTime: try optionalInt(row[safe: 2])
            )
        }

        return FlowShopProblem(
            title: metadata[1],
            timeUnit: metadata[2],
            jobs: jobs,
            machines: machines
        )
    }

    public static func parseJobShop(from data: Data) throws -> JobShopProblem {
        let lines = try tabularLines(from: data)
        guard let metadata = lines.first,
              metadata.count >= 7,
              metadata[0] == "SCH",
              metadata[6] == "0",
              let jobCount = Int(metadata[3]),
              let operationCount = Int(metadata[4]),
              let machineCount = Int(metadata[5]),
              jobCount > 0,
              operationCount > 0,
              machineCount > 0,
              lines.count >= jobCount + machineCount + 3
        else {
            throw SchedulingModelError.unsupportedFormat
        }

        let jobRows = lines[2..<(2 + jobCount)]
        let jobs = try jobRows.map { row -> FlowShopJob in
            guard row.count >= operationCount + 2,
                  let id = Int(row[0])
            else {
                throw SchedulingModelError.unsupportedFormat
            }
            let operations = try (0..<operationCount).map { operationIndex in
                try parseOperation(row[2 + operationIndex])
            }
            return FlowShopJob(
                id: id,
                name: row[1],
                operations: operations,
                readyTime: try optionalInt(row[safe: operationCount + 2]),
                dueDate: try optionalInt(row[safe: operationCount + 3]),
                weight: try optionalDouble(row[safe: operationCount + 4])
            )
        }

        let machineRowsStart = 2 + jobCount + 1
        let machines = try lines[machineRowsStart..<(machineRowsStart + machineCount)].map { row -> FlowShopMachine in
            guard row.count >= 2,
                  let id = Int(row[0])
            else {
                throw SchedulingModelError.unsupportedFormat
            }
            return FlowShopMachine(
                id: id,
                name: row[1],
                readyTime: try optionalInt(row[safe: 2])
            )
        }

        return JobShopProblem(
            title: metadata[1],
            timeUnit: metadata[2],
            jobs: jobs,
            machines: machines
        )
    }

    private static func tabularLines(from data: Data) throws -> [[String]] {
        guard let text = data.legacyLatin1String else {
            throw SchedulingModelError.unsupportedFormat
        }

        return text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(clean) }
    }

    private static func parseOperation(_ value: String) throws -> FlowShopOperation {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        let pieces = normalized.split(separator: "/")
        guard pieces.count == 2,
              let duration = Int(pieces[0]),
              let machineID = Int(pieces[1])
        else {
            throw SchedulingModelError.unsupportedFormat
        }
        return FlowShopOperation(machineID: machineID, duration: duration)
    }

    private static func optionalInt(_ value: String?) throws -> Int? {
        guard let number = try optionalDouble(value) else {
            return nil
        }
        let rounded = number.rounded()
        guard abs(number - rounded) < 1e-8 else {
            throw SchedulingModelError.invalidNumericValue(value ?? "")
        }
        return Int(rounded)
    }

    private static func optionalDouble(_ value: String?) throws -> Double? {
        guard let value else {
            return nil
        }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.uppercased() != "M" else {
            return nil
        }
        guard let number = Double(normalized), number.isFinite else {
            throw SchedulingModelError.invalidNumericValue(value)
        }
        return number
    }

    private static func clean(_ value: Substring) -> String {
        String(value).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum JobShopSolver {
    private struct Candidate {
        let jobIndex: Int
        let operationIndex: Int
        let machineIndex: Int
        let machineID: Int
        let duration: Int
        let start: Int
        let finish: Int
    }

    public static func solve(_ problem: JobShopProblem) throws -> JobShopSolution {
        let machineIndexByID = try validate(problem)
        let remainingJobDurations = remainingDurationsByJob(problem.jobs)

        var bestSolution = greedySolutions(problem, machineIndexByID: machineIndexByID)
            .min { $0.makespan < $1.makespan }
        guard bestSolution != nil else {
            throw SchedulingModelError.invalidModel("job shop requires at least one operation")
        }

        var progress = Array(repeating: 0, count: problem.jobs.count)
        var jobAvailability = problem.jobs.map { $0.readyTime ?? 0 }
        var machineAvailability = problem.machines.map { $0.readyTime ?? 0 }
        var steps: [JobShopDispatchStep] = []
        var nondominatedAvailabilityByProgress: [[Int]: [[Int]]] = [:]
        let totalOperationCount = problem.jobs.reduce(0) { $0 + $1.operations.count }

        func search(scheduledOperationCount: Int) {
            if scheduledOperationCount == totalOperationCount {
                let makespan = max(machineAvailability.max() ?? 0, jobAvailability.max() ?? 0)
                if let currentBest = bestSolution, makespan >= currentBest.makespan {
                    return
                }
                bestSolution = buildSolution(
                    problem,
                    steps: steps,
                    makespan: makespan
                )
                return
            }

            guard let currentBest = bestSolution else {
                return
            }
            let lowerBound = lowerBound(
                problem,
                progress: progress,
                jobAvailability: jobAvailability,
                machineAvailability: machineAvailability,
                remainingJobDurations: remainingJobDurations,
                machineIndexByID: machineIndexByID
            )
            guard lowerBound < currentBest.makespan else {
                return
            }

            let availabilityVector = jobAvailability + machineAvailability
            guard !isDominated(
                availabilityVector,
                progress: progress,
                nondominatedAvailabilityByProgress: &nondominatedAvailabilityByProgress
            ) else {
                return
            }

            for candidate in candidates(
                problem,
                progress: progress,
                jobAvailability: jobAvailability,
                machineAvailability: machineAvailability,
                machineIndexByID: machineIndexByID
            ) {
                let previousProgress = progress[candidate.jobIndex]
                let previousJobAvailability = jobAvailability[candidate.jobIndex]
                let previousMachineAvailability = machineAvailability[candidate.machineIndex]
                let job = problem.jobs[candidate.jobIndex]

                progress[candidate.jobIndex] = candidate.operationIndex + 1
                jobAvailability[candidate.jobIndex] = candidate.finish
                machineAvailability[candidate.machineIndex] = candidate.finish
                steps.append(JobShopDispatchStep(
                    jobID: job.id,
                    jobName: job.name,
                    operationIndex: candidate.operationIndex + 1,
                    machineID: candidate.machineID,
                    start: candidate.start,
                    finish: candidate.finish
                ))

                search(scheduledOperationCount: scheduledOperationCount + 1)

                _ = steps.popLast()
                machineAvailability[candidate.machineIndex] = previousMachineAvailability
                jobAvailability[candidate.jobIndex] = previousJobAvailability
                progress[candidate.jobIndex] = previousProgress
            }
        }

        search(scheduledOperationCount: 0)

        guard let bestSolution else {
            throw SchedulingModelError.invalidModel("job shop could not be solved")
        }
        return bestSolution
    }

    private static func validate(_ problem: JobShopProblem) throws -> [Int: Int] {
        try JobShopValidator.validate(problem)

        let totalOperationCount = problem.jobs.reduce(0) { $0 + $1.operations.count }
        guard problem.jobs.count <= 6, totalOperationCount <= 36 else {
            throw SchedulingModelError.invalidModel("exact job shop solver currently supports up to 6 jobs and 36 operations")
        }

        let machineIndexByID = Dictionary(uniqueKeysWithValues: problem.machines.enumerated().map { ($0.element.id, $0.offset) })
        for job in problem.jobs {
            for operation in job.operations {
                guard machineIndexByID[operation.machineID] != nil else {
                    throw SchedulingModelError.invalidModel("job shop operation references missing machine \(operation.machineID)")
                }
            }
        }

        return machineIndexByID
    }

    private static func remainingDurationsByJob(_ jobs: [FlowShopJob]) -> [[Int]] {
        jobs.map { job in
            var remaining = Array(repeating: 0, count: job.operations.count + 1)
            for operationIndex in stride(from: job.operations.count - 1, through: 0, by: -1) {
                remaining[operationIndex] = remaining[operationIndex + 1] + job.operations[operationIndex].duration
            }
            return remaining
        }
    }

    private static func lowerBound(
        _ problem: JobShopProblem,
        progress: [Int],
        jobAvailability: [Int],
        machineAvailability: [Int],
        remainingJobDurations: [[Int]],
        machineIndexByID: [Int: Int]
    ) -> Int {
        var bound = max(machineAvailability.max() ?? 0, jobAvailability.max() ?? 0)
        for jobIndex in problem.jobs.indices {
            bound = max(bound, jobAvailability[jobIndex] + remainingJobDurations[jobIndex][progress[jobIndex]])
        }

        var remainingMachineDurations = Array(repeating: 0, count: problem.machines.count)
        for jobIndex in problem.jobs.indices {
            let job = problem.jobs[jobIndex]
            for operationIndex in progress[jobIndex]..<job.operations.count {
                let operation = job.operations[operationIndex]
                if let machineIndex = machineIndexByID[operation.machineID] {
                    remainingMachineDurations[machineIndex] += operation.duration
                }
            }
        }
        for machineIndex in problem.machines.indices {
            bound = max(bound, machineAvailability[machineIndex] + remainingMachineDurations[machineIndex])
        }
        return bound
    }

    private static func isDominated(
        _ availabilityVector: [Int],
        progress: [Int],
        nondominatedAvailabilityByProgress: inout [[Int]: [[Int]]]
    ) -> Bool {
        var vectors = nondominatedAvailabilityByProgress[progress] ?? []
        if vectors.contains(where: { dominates($0, availabilityVector) }) {
            return true
        }
        vectors.removeAll { dominates(availabilityVector, $0) }
        vectors.append(availabilityVector)
        nondominatedAvailabilityByProgress[progress] = vectors
        return false
    }

    private static func dominates(_ left: [Int], _ right: [Int]) -> Bool {
        zip(left, right).allSatisfy { $0.0 <= $0.1 }
    }

    private static func candidates(
        _ problem: JobShopProblem,
        progress: [Int],
        jobAvailability: [Int],
        machineAvailability: [Int],
        machineIndexByID: [Int: Int]
    ) -> [Candidate] {
        var candidates: [Candidate] = []
        for jobIndex in problem.jobs.indices {
            let job = problem.jobs[jobIndex]
            let operationIndex = progress[jobIndex]
            guard operationIndex < job.operations.count else {
                continue
            }
            let operation = job.operations[operationIndex]
            guard let machineIndex = machineIndexByID[operation.machineID] else {
                continue
            }
            let start = max(jobAvailability[jobIndex], machineAvailability[machineIndex])
            let finish = start + operation.duration
            candidates.append(Candidate(
                jobIndex: jobIndex,
                operationIndex: operationIndex,
                machineIndex: machineIndex,
                machineID: operation.machineID,
                duration: operation.duration,
                start: start,
                finish: finish
            ))
        }
        return candidates.sorted { left, right in
            if left.finish != right.finish { return left.finish < right.finish }
            if left.start != right.start { return left.start < right.start }
            if left.duration != right.duration { return left.duration < right.duration }
            if left.jobIndex != right.jobIndex { return left.jobIndex < right.jobIndex }
            return left.machineIndex < right.machineIndex
        }
    }

    private enum GreedyRule {
        case earliestFinish
        case shortestProcessing
        case longestProcessing
        case jobOrder
    }

    private static func greedySolutions(
        _ problem: JobShopProblem,
        machineIndexByID: [Int: Int]
    ) -> [JobShopSolution] {
        [GreedyRule.earliestFinish, .shortestProcessing, .longestProcessing, .jobOrder].map { rule in
            var progress = Array(repeating: 0, count: problem.jobs.count)
            var jobAvailability = problem.jobs.map { $0.readyTime ?? 0 }
            var machineAvailability = problem.machines.map { $0.readyTime ?? 0 }
            var steps: [JobShopDispatchStep] = []
            let totalOperationCount = problem.jobs.reduce(0) { $0 + $1.operations.count }

            while steps.count < totalOperationCount {
                guard let candidate = candidates(
                    problem,
                    progress: progress,
                    jobAvailability: jobAvailability,
                    machineAvailability: machineAvailability,
                    machineIndexByID: machineIndexByID
                ).sorted(by: { left, right in
                    switch rule {
                    case .earliestFinish:
                        if left.finish != right.finish { return left.finish < right.finish }
                    case .shortestProcessing:
                        if left.duration != right.duration { return left.duration < right.duration }
                    case .longestProcessing:
                        if left.duration != right.duration { return left.duration > right.duration }
                    case .jobOrder:
                        if left.jobIndex != right.jobIndex { return left.jobIndex < right.jobIndex }
                    }
                    if left.finish != right.finish { return left.finish < right.finish }
                    if left.start != right.start { return left.start < right.start }
                    return left.jobIndex < right.jobIndex
                }).first else {
                    break
                }

                let job = problem.jobs[candidate.jobIndex]
                progress[candidate.jobIndex] = candidate.operationIndex + 1
                jobAvailability[candidate.jobIndex] = candidate.finish
                machineAvailability[candidate.machineIndex] = candidate.finish
                steps.append(JobShopDispatchStep(
                    jobID: job.id,
                    jobName: job.name,
                    operationIndex: candidate.operationIndex + 1,
                    machineID: candidate.machineID,
                    start: candidate.start,
                    finish: candidate.finish
                ))
            }

            return buildSolution(
                problem,
                steps: steps,
                makespan: max(machineAvailability.max() ?? 0, jobAvailability.max() ?? 0)
            )
        }
    }

    private static func buildSolution(
        _ problem: JobShopProblem,
        steps: [JobShopDispatchStep],
        makespan: Int
    ) -> JobShopSolution {
        let machineCompletionTimes = problem.machines.map { machine in
            max(
                machine.readyTime ?? 0,
                steps
                    .filter { $0.machineID == machine.id }
                    .map(\.finish)
                    .max() ?? 0
            )
        }
        let stepsByJobID = Dictionary(grouping: steps, by: \.jobID)
        let schedules = problem.jobs.map { job in
            let jobSteps = (stepsByJobID[job.id] ?? []).sorted { $0.operationIndex < $1.operationIndex }
            let operations = jobSteps.map { step in
                ScheduledOperation(machineID: step.machineID, start: step.start, finish: step.finish)
            }
            return FlowShopJobSchedule(
                jobID: job.id,
                jobName: job.name,
                operations: operations,
                completionTime: operations.map(\.finish).max() ?? (job.readyTime ?? 0)
            )
        }

        return JobShopSolution(
            makespan: makespan,
            machineCompletionTimes: machineCompletionTimes,
            dispatchOrder: steps,
            schedules: schedules
        )
    }
}

public enum FlowShopSolver {
    public static func solve(_ problem: FlowShopProblem) throws -> FlowShopSolution {
        try validate(problem)

        var bestSolution: FlowShopSolution?
        for permutation in permutations(of: problem.jobs) {
            let candidate = schedule(permutation, machines: problem.machines)
            if bestSolution == nil || candidate.makespan < bestSolution!.makespan {
                bestSolution = candidate
            }
        }

        guard let bestSolution else {
            throw SchedulingModelError.invalidModel("flow shop requires at least one job")
        }
        return bestSolution
    }

    private static func validate(_ problem: FlowShopProblem) throws {
        try FlowShopValidator.validate(problem)

        guard problem.jobs.count <= 8 else {
            throw SchedulingModelError.invalidModel("exact flow shop solver currently supports up to 8 jobs")
        }
    }

    private static func schedule(_ jobs: [FlowShopJob], machines: [FlowShopMachine]) -> FlowShopSolution {
        var machineAvailability = machines.map { $0.readyTime ?? 0 }
        var schedules: [FlowShopJobSchedule] = []

        for job in jobs {
            var previousOperationFinish = job.readyTime ?? 0
            var scheduledOperations: [ScheduledOperation] = []
            for operationIndex in job.operations.indices {
                let operation = job.operations[operationIndex]
                let start = max(previousOperationFinish, machineAvailability[operationIndex])
                let finish = start + operation.duration
                machineAvailability[operationIndex] = finish
                previousOperationFinish = finish
                scheduledOperations.append(ScheduledOperation(
                    machineID: operation.machineID,
                    start: start,
                    finish: finish
                ))
            }
            schedules.append(FlowShopJobSchedule(
                jobID: job.id,
                jobName: job.name,
                operations: scheduledOperations,
                completionTime: previousOperationFinish
            ))
        }

        return FlowShopSolution(
            sequence: jobs.map(\.name),
            makespan: machineAvailability.last ?? 0,
            machineCompletionTimes: machineAvailability,
            schedules: schedules
        )
    }

    private static func permutations(of jobs: [FlowShopJob]) -> [[FlowShopJob]] {
        guard !jobs.isEmpty else {
            return []
        }
        var jobs = jobs
        var result: [[FlowShopJob]] = []

        func permute(_ index: Int) {
            if index == jobs.count {
                result.append(jobs)
                return
            }
            for swapIndex in index..<jobs.count {
                jobs.swapAt(index, swapIndex)
                permute(index + 1)
                jobs.swapAt(index, swapIndex)
            }
        }

        permute(0)
        return result
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
