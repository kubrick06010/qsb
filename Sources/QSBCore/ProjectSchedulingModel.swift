import Foundation

public enum ProjectSchedulingProblemKind: String, Codable, Sendable {
    case deterministicCPM = "CPM"
    case probabilisticPERT = "PERT"
}

public struct CPMActivity: Codable, Equatable, Sendable {
    public let name: String
    public let predecessors: [String]
    public let normalTime: Double
    public let crashTime: Double
    public let normalCost: Double
    public let crashCost: Double

    public init(name: String, predecessors: [String], normalTime: Double, crashTime: Double, normalCost: Double, crashCost: Double) {
        self.name = name
        self.predecessors = predecessors
        self.normalTime = normalTime
        self.crashTime = crashTime
        self.normalCost = normalCost
        self.crashCost = crashCost
    }
}

public struct PERTActivity: Codable, Equatable, Sendable {
    public let name: String
    public let predecessors: [String]
    public let optimisticTime: Double
    public let mostLikelyTime: Double
    public let pessimisticTime: Double

    public init(name: String, predecessors: [String], optimisticTime: Double, mostLikelyTime: Double, pessimisticTime: Double) {
        self.name = name
        self.predecessors = predecessors
        self.optimisticTime = optimisticTime
        self.mostLikelyTime = mostLikelyTime
        self.pessimisticTime = pessimisticTime
    }

    public var expectedTime: Double { (optimisticTime + 4 * mostLikelyTime + pessimisticTime) / 6 }
    public var variance: Double { pow((pessimisticTime - optimisticTime) / 6, 2) }
}

public struct CPMProject: Codable, Equatable, Sendable {
    public let title: String
    public let timeUnit: String
    public let activities: [CPMActivity]

    public init(title: String, timeUnit: String, activities: [CPMActivity]) {
        self.title = title
        self.timeUnit = timeUnit
        self.activities = activities
    }
}

public struct PERTProject: Codable, Equatable, Sendable {
    public let title: String
    public let timeUnit: String
    public let activities: [PERTActivity]

    public init(title: String, timeUnit: String, activities: [PERTActivity]) {
        self.title = title
        self.timeUnit = timeUnit
        self.activities = activities
    }
}

public enum ProjectSchedulingModelEnvelope: Codable, Equatable, Sendable {
    case cpm(CPMProject)
    case pert(PERTProject)

    private enum CodingKeys: String, CodingKey { case kind, model }

    public var kind: ProjectSchedulingProblemKind {
        switch self { case .cpm: .deterministicCPM; case .pert: .probabilisticPERT }
    }

    public var title: String {
        switch self { case .cpm(let value): value.title; case .pert(let value): value.title }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(ProjectSchedulingProblemKind.self, forKey: .kind) {
        case .deterministicCPM: self = .cpm(try container.decode(CPMProject.self, forKey: .model))
        case .probabilisticPERT: self = .pert(try container.decode(PERTProject.self, forKey: .model))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .cpm(let value): try container.encode(value, forKey: .model)
        case .pert(let value): try container.encode(value, forKey: .model)
        }
    }
}

public struct ProjectActivityTiming: Codable, Equatable, Sendable {
    public let name: String
    public let duration: Double
    public let variance: Double
    public let earliestStart: Double
    public let earliestFinish: Double
    public let latestStart: Double
    public let latestFinish: Double
    public let slack: Double
    public let isCritical: Bool
}

public struct ProjectSchedulingSolution: Codable, Equatable, Sendable {
    public let projectDuration: Double
    public let criticalActivities: [String]
    public let activityTimings: [ProjectActivityTiming]
    public let projectVariance: Double?
    public let projectStandardDeviation: Double?
    public let totalNormalCost: Double?
}

public struct CPMCrashActivityPlan: Codable, Equatable, Sendable {
    public let name: String
    public let normalTime: Double
    public let plannedTime: Double
    public let reduction: Double
    public let normalCost: Double
    public let plannedCost: Double
    public let marginalCostPerTime: Double

    public init(name: String, normalTime: Double, plannedTime: Double, reduction: Double, normalCost: Double, plannedCost: Double, marginalCostPerTime: Double) {
        self.name = name
        self.normalTime = normalTime
        self.plannedTime = plannedTime
        self.reduction = reduction
        self.normalCost = normalCost
        self.plannedCost = plannedCost
        self.marginalCostPerTime = marginalCostPerTime
    }
}

/// Continuous CPM time-cost trade-off optimization for a requested deadline.
///
/// Every source-to-sink path is represented as a linear deadline constraint;
/// the native LP backend then chooses activity durations between crash and
/// normal bounds while minimizing incremental crash cost.  This is exact for
/// the continuous linear cost model (and remains fixture-scale because path
/// enumeration can grow exponentially on very large DAGs).
public struct CPMCrashOptimization: Codable, Equatable, Sendable {
    public let targetDuration: Double
    public let normalProjectDuration: Double
    public let plannedProjectDuration: Double
    public let normalCost: Double
    public let plannedCost: Double
    public let incrementalCost: Double
    public let isFeasible: Bool
    public let activityPlans: [CPMCrashActivityPlan]

    public init(targetDuration: Double, normalProjectDuration: Double, plannedProjectDuration: Double, normalCost: Double, plannedCost: Double, incrementalCost: Double, isFeasible: Bool, activityPlans: [CPMCrashActivityPlan]) {
        self.targetDuration = targetDuration
        self.normalProjectDuration = normalProjectDuration
        self.plannedProjectDuration = plannedProjectDuration
        self.normalCost = normalCost
        self.plannedCost = plannedCost
        self.incrementalCost = incrementalCost
        self.isFeasible = isFeasible
        self.activityPlans = activityPlans
    }
}

public struct ProjectSchedulingSolutionDocument: Codable, Equatable, Sendable {
    public let backend: SolverRunMetadata
    public let model: ProjectSchedulingModelEnvelope
    public let solution: ProjectSchedulingSolution
}

public struct ProjectSchedulingValidationDocument: Codable, Equatable, Sendable {
    public let kind: ProjectSchedulingProblemKind
    public let backend: SolverBackendKind
    public let isValid: Bool
    public let diagnostics: [ValidationDiagnostic]

    public init(kind: ProjectSchedulingProblemKind, backend: SolverBackendKind, diagnostics: [ValidationDiagnostic]) {
        self.kind = kind
        self.backend = backend
        self.isValid = !diagnostics.contains { $0.severity == .error }
        self.diagnostics = diagnostics
    }
}

public enum ProjectSchedulingError: Error, CustomStringConvertible {
    case unsupportedFormat
    case invalidModel(String)

    public var description: String {
        switch self {
        case .unsupportedFormat: "Unsupported PERT/CPM model format"
        case .invalidModel(let detail): "Invalid PERT/CPM model: \(detail)"
        }
    }
}

public enum WinQSBProjectSchedulingParser {
    public static func parseModelEnvelope(from data: Data) throws -> ProjectSchedulingModelEnvelope {
        let rows = try tabularRows(from: data)
        guard let metadata = rows.first, metadata.count >= 5 else { throw ProjectSchedulingError.unsupportedFormat }
        switch metadata[0] {
        case "CPM": return .cpm(try parseCPM(rows))
        case "PERT": return .pert(try parsePERT(rows))
        default: throw ProjectSchedulingError.unsupportedFormat
        }
    }

    public static func parseCPM(from data: Data) throws -> CPMProject {
        try parseCPM(tabularRows(from: data))
    }

    public static func parsePERT(from data: Data) throws -> PERTProject {
        try parsePERT(tabularRows(from: data))
    }

    private static func parseCPM(_ rows: [[String]]) throws -> CPMProject {
        guard rows[0][0] == "CPM", let count = Int(rows[0][3]), count > 0, rows.count >= count + 4 else { throw ProjectSchedulingError.unsupportedFormat }
        let activityRows = Array(rows[3..<(3 + count)])
        let namesByIdentifier = Dictionary(activityRows.compactMap { row in row.count >= 2 ? (row[0], row[1]) : nil }, uniquingKeysWith: { first, _ in first })
        let activities = try activityRows.map { row -> CPMActivity in
            guard row.count >= 7 else { throw ProjectSchedulingError.unsupportedFormat }
            return CPMActivity(
                name: row[1], predecessors: predecessors(row[2], namesByIdentifier: namesByIdentifier),
                normalTime: try number(row[3]), crashTime: try number(row[4]),
                normalCost: try number(row[5]), crashCost: try number(row[6])
            )
        }
        return CPMProject(title: rows[0][1], timeUnit: rows[0][2], activities: activities)
    }

    private static func parsePERT(_ rows: [[String]]) throws -> PERTProject {
        guard rows[0][0] == "PERT", let count = Int(rows[0][3]), count > 0, rows.count >= count + 4 else { throw ProjectSchedulingError.unsupportedFormat }
        let activityRows = Array(rows[3..<(3 + count)])
        let namesByIdentifier = Dictionary(activityRows.compactMap { row in row.count >= 2 ? (row[0], row[1]) : nil }, uniquingKeysWith: { first, _ in first })
        let activities = try activityRows.map { row -> PERTActivity in
            guard row.count >= 6 else { throw ProjectSchedulingError.unsupportedFormat }
            return PERTActivity(
                name: row[1], predecessors: predecessors(row[2], namesByIdentifier: namesByIdentifier),
                optimisticTime: try number(row[3]), mostLikelyTime: try number(row[4]), pessimisticTime: try number(row[5])
            )
        }
        return PERTProject(title: rows[0][1], timeUnit: rows[0][2], activities: activities)
    }

    private static func tabularRows(from data: Data) throws -> [[String]] {
        guard let text = data.legacyLatin1String else { throw ProjectSchedulingError.unsupportedFormat }
        return text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } }
    }

    private static func predecessors(_ raw: String, namesByIdentifier: [String: String]) -> [String] {
        raw.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { namesByIdentifier[$0] ?? $0 }
    }

    private static func number(_ raw: String) throws -> Double {
        let cleaned = raw.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        guard let value = Double(cleaned), value.isFinite else { throw ProjectSchedulingError.invalidModel("Invalid numeric value \(raw)") }
        return value
    }
}

public enum ProjectSchedulingValidator {
    public static func diagnostics(for model: ProjectSchedulingModelEnvelope) -> [ValidationDiagnostic] {
        let names: [String]
        let predecessors: [[String]]
        var result: [ValidationDiagnostic] = []
        switch model {
        case .cpm(let project):
            names = project.activities.map(\.name); predecessors = project.activities.map(\.predecessors)
            for (index, activity) in project.activities.enumerated() {
                if !activity.normalTime.isFinite || activity.normalTime < 0 || !activity.crashTime.isFinite || activity.crashTime < 0 { result.append(error("time.value", "Activity times must be finite and nonnegative.", "model.activities.\(index)")) }
                if activity.crashTime > activity.normalTime { result.append(error("time.order", "Crash time must not exceed normal time.", "model.activities.\(index).crashTime")) }
                if !activity.normalCost.isFinite || activity.normalCost < 0 || !activity.crashCost.isFinite || activity.crashCost < 0 { result.append(error("cost.value", "Activity costs must be finite and nonnegative.", "model.activities.\(index)")) }
            }
        case .pert(let project):
            names = project.activities.map(\.name); predecessors = project.activities.map(\.predecessors)
            for (index, activity) in project.activities.enumerated() {
                let values = [activity.optimisticTime, activity.mostLikelyTime, activity.pessimisticTime]
                if values.contains(where: { !$0.isFinite || $0 < 0 }) { result.append(error("time.value", "PERT estimates must be finite and nonnegative.", "model.activities.\(index)")) }
                if activity.optimisticTime > activity.mostLikelyTime || activity.mostLikelyTime > activity.pessimisticTime { result.append(error("time.order", "PERT estimates must satisfy optimistic <= mostLikely <= pessimistic.", "model.activities.\(index)")) }
            }
        }
        if names.isEmpty { result.append(error("activities.empty", "Project must contain at least one activity.", "model.activities")) }
        if names.contains(where: { $0.isEmpty }) { result.append(error("activity.name", "Activity names must not be empty.", "model.activities")) }
        if Set(names).count != names.count { result.append(error("activity.duplicate", "Activity names must be unique.", "model.activities")) }
        let nameSet = Set(names)
        for (index, values) in predecessors.enumerated() {
            for predecessor in values where !nameSet.contains(predecessor) { result.append(error("predecessor.missing", "Predecessor \(predecessor) does not name an activity.", "model.activities.\(index).predecessors")) }
            if index < names.count, values.contains(names[index]) { result.append(error("predecessor.self", "Activity cannot depend on itself.", "model.activities.\(index).predecessors")) }
        }
        if result.contains(where: { $0.severity == .error }) == false, topologicalOrder(names: names, predecessors: predecessors) == nil { result.append(error("precedence.cycle", "Activity precedence graph must be acyclic.", "model.activities")) }
        guard result.contains(where: { $0.severity == .error }) == false else { return result }
        return [ValidationDiagnostic(severity: .info, code: "project.\(model.kind.rawValue).valid", message: "PERT/CPM model is valid")]
    }

    public static func validate(_ model: ProjectSchedulingModelEnvelope) throws {
        if let item = diagnostics(for: model).first(where: { $0.severity == .error }) { throw ProjectSchedulingError.invalidModel(item.message) }
    }

    static func topologicalOrder(names: [String], predecessors: [[String]]) -> [Int]? {
        let indexes = Dictionary(uniqueKeysWithValues: names.enumerated().map { ($0.element, $0.offset) })
        var indegree = predecessors.map(\.count)
        var successors = Array(repeating: [Int](), count: names.count)
        for (index, values) in predecessors.enumerated() { for name in values { if let predecessor = indexes[name] { successors[predecessor].append(index) } } }
        var queue = indegree.indices.filter { indegree[$0] == 0 }
        var cursor = 0
        var result: [Int] = []
        while cursor < queue.count {
            let current = queue[cursor]; cursor += 1; result.append(current)
            for successor in successors[current] { indegree[successor] -= 1; if indegree[successor] == 0 { queue.append(successor) } }
        }
        return result.count == names.count ? result : nil
    }

    private static func error(_ suffix: String, _ message: String, _ path: String) -> ValidationDiagnostic {
        ValidationDiagnostic(severity: .error, code: "project.\(suffix)", message: message, path: path)
    }
}

public enum ProjectSchedulingSolver {
    public static func solve(_ model: ProjectSchedulingModelEnvelope) throws -> ProjectSchedulingSolution {
        try ProjectSchedulingValidator.validate(model)
        let names: [String], predecessors: [[String]], durations: [Double], variances: [Double]
        let totalNormalCost: Double?
        switch model {
        case .cpm(let project):
            names = project.activities.map(\.name); predecessors = project.activities.map(\.predecessors)
            durations = project.activities.map(\.normalTime); variances = Array(repeating: 0, count: names.count)
            totalNormalCost = project.activities.map(\.normalCost).reduce(0, +)
        case .pert(let project):
            names = project.activities.map(\.name); predecessors = project.activities.map(\.predecessors)
            durations = project.activities.map(\.expectedTime); variances = project.activities.map(\.variance)
            totalNormalCost = nil
        }
        let order = ProjectSchedulingValidator.topologicalOrder(names: names, predecessors: predecessors)!
        let indexes = Dictionary(uniqueKeysWithValues: names.enumerated().map { ($0.element, $0.offset) })
        var successors = Array(repeating: [Int](), count: names.count)
        for (index, values) in predecessors.enumerated() { for name in values { successors[indexes[name]!].append(index) } }
        var earliestStart = Array(repeating: 0.0, count: names.count)
        var earliestFinish = Array(repeating: 0.0, count: names.count)
        for index in order {
            earliestStart[index] = predecessors[index].compactMap { indexes[$0] }.map { earliestFinish[$0] }.max() ?? 0
            earliestFinish[index] = earliestStart[index] + durations[index]
        }
        let projectDuration = earliestFinish.max() ?? 0
        var latestFinish = Array(repeating: projectDuration, count: names.count)
        var latestStart = Array(repeating: projectDuration, count: names.count)
        for index in order.reversed() {
            latestFinish[index] = successors[index].map { latestStart[$0] }.min() ?? projectDuration
            latestStart[index] = latestFinish[index] - durations[index]
        }
        let timings = names.indices.map { index -> ProjectActivityTiming in
            let slack = latestStart[index] - earliestStart[index]
            return ProjectActivityTiming(name: names[index], duration: durations[index], variance: variances[index], earliestStart: earliestStart[index], earliestFinish: earliestFinish[index], latestStart: latestStart[index], latestFinish: latestFinish[index], slack: abs(slack) < 1e-8 ? 0 : slack, isCritical: abs(slack) < 1e-8)
        }
        let critical = timings.filter(\.isCritical).map(\.name)
        let variance = model.kind == .probabilisticPERT ? timings.filter(\.isCritical).map(\.variance).reduce(0, +) : nil
        return ProjectSchedulingSolution(projectDuration: projectDuration, criticalActivities: critical, activityTimings: timings, projectVariance: variance, projectStandardDeviation: variance.map(sqrt), totalNormalCost: totalNormalCost)
    }
}

public enum CPMCrashSolver {
    public static func solve(_ project: CPMProject, targetDuration: Double) throws -> CPMCrashOptimization {
        try ProjectSchedulingValidator.validate(.cpm(project))
        guard targetDuration.isFinite, targetDuration >= 0 else {
            throw ProjectSchedulingError.invalidModel("crash target duration must be finite and nonnegative")
        }
        guard project.activities.allSatisfy({ $0.crashCost + 1e-12 >= $0.normalCost }) else {
            throw ProjectSchedulingError.invalidModel("crash cost must not be below normal cost")
        }

        let names = project.activities.map(\.name)
        let predecessors = project.activities.map(\.predecessors)
        let normalDurations = project.activities.map(\.normalTime)
        let normalCost = project.activities.reduce(0) { $0 + $1.normalCost }
        let normalDuration = projectDuration(names: names, predecessors: predecessors, durations: normalDurations)

        func plan(for durations: [Double], plannedCost: Double) -> CPMCrashOptimization {
            let activityPlans = project.activities.enumerated().map { index, activity in
                let planned = min(max(durations[index], activity.crashTime), activity.normalTime)
                let reduction = max(0, activity.normalTime - planned)
                let span = activity.normalTime - activity.crashTime
                let marginal = span > 1e-12 ? (activity.crashCost - activity.normalCost) / span : 0
                return CPMCrashActivityPlan(
                    name: activity.name,
                    normalTime: activity.normalTime,
                    plannedTime: planned,
                    reduction: reduction,
                    normalCost: activity.normalCost,
                    plannedCost: activity.normalCost + marginal * reduction,
                    marginalCostPerTime: marginal
                )
            }
            let duration = projectDuration(names: names, predecessors: predecessors, durations: durations)
            return CPMCrashOptimization(
                targetDuration: targetDuration,
                normalProjectDuration: normalDuration,
                plannedProjectDuration: duration,
                normalCost: normalCost,
                plannedCost: plannedCost,
                incrementalCost: plannedCost - normalCost,
                isFeasible: duration <= targetDuration + 1e-7,
                activityPlans: activityPlans
            )
        }

        if targetDuration >= normalDuration - 1e-9 {
            return plan(for: normalDurations, plannedCost: normalCost)
        }

        let crashDurations = project.activities.map(\.crashTime)
        let minimumDuration = projectDuration(names: names, predecessors: predecessors, durations: crashDurations)
        guard targetDuration >= minimumDuration - 1e-9 else {
            throw ProjectSchedulingError.invalidModel("target duration (targetDuration) is below the all-crash project duration (minimumDuration)")
        }

        let paths = allSourceToSinkPaths(names: names, predecessors: predecessors)
        guard !paths.isEmpty else { throw ProjectSchedulingError.invalidModel("project has no source-to-sink path") }
        let objective = project.activities.map { activity in
            let span = activity.normalTime - activity.crashTime
            return span > 1e-12 ? -(activity.crashCost - activity.normalCost) / span : 0
        }
        let constraints = paths.enumerated().map { index, path in
            var coefficients = Array(repeating: 0.0, count: names.count)
            for activityIndex in path { coefficients[activityIndex] = 1 }
            return LinearConstraint(name: "path_\(index + 1)", coefficients: coefficients, relation: .lessThanOrEqual, rhs: targetDuration)
        }
        let program = LinearProgram(
            title: "\(project.title) crash time-cost trade-off",
            sense: .minimize,
            variableNames: names,
            objectiveCoefficients: objective,
            constraints: constraints,
            lowerBounds: crashDurations,
            upperBounds: normalDurations
        )
        let solution = try NativeEducationalLinearProgrammingBackend().solve(program, mode: .continuous)
        let durations = names.indices.map { index in
            min(max(solution.variableValues[names[index]] ?? normalDurations[index], crashDurations[index]), normalDurations[index])
        }
        let plannedCost = project.activities.enumerated().reduce(0) { total, item in
            let activity = item.element
            let span = activity.normalTime - activity.crashTime
            let marginal = span > 1e-12 ? (activity.crashCost - activity.normalCost) / span : 0
            return total + activity.normalCost + marginal * (activity.normalTime - durations[item.offset])
        }
        return plan(for: durations, plannedCost: plannedCost)
    }

    private static func projectDuration(names: [String], predecessors: [[String]], durations: [Double]) -> Double {
        guard let order = ProjectSchedulingValidator.topologicalOrder(names: names, predecessors: predecessors) else { return .infinity }
        let indexes = Dictionary(uniqueKeysWithValues: names.enumerated().map { ($0.element, $0.offset) })
        var finishes = Array(repeating: 0.0, count: names.count)
        for index in order {
            let start = predecessors[index].compactMap { indexes[$0] }.map { finishes[$0] }.max() ?? 0
            finishes[index] = start + durations[index]
        }
        return finishes.max() ?? 0
    }

    private static func allSourceToSinkPaths(names: [String], predecessors: [[String]]) -> [[Int]] {
        let indexes = Dictionary(uniqueKeysWithValues: names.enumerated().map { ($0.element, $0.offset) })
        var successors = Array(repeating: [Int](), count: names.count)
        for (index, values) in predecessors.enumerated() {
            for predecessor in values {
                if let source = indexes[predecessor] { successors[source].append(index) }
            }
        }
        let sinks = Set(names.indices.filter { successors[$0].isEmpty })
        let sources = names.indices.filter { predecessors[$0].isEmpty }

        func visit(_ node: Int, _ path: [Int]) -> [[Int]] {
            let nextPath = path + [node]
            if sinks.contains(node) { return [nextPath] }
            return successors[node].flatMap { visit($0, nextPath) }
        }
        return sources.flatMap { visit($0, []) }
    }
}

public protocol ProjectSchedulingBackend: Sendable {
    var capabilities: SolverCapabilities { get }
    func validationReport(for model: ProjectSchedulingModelEnvelope) -> ValidationReport
    func solve(_ model: ProjectSchedulingModelEnvelope, options: SolverOptions) throws -> ProjectSchedulingSolution
    func runMetadata(for model: ProjectSchedulingModelEnvelope) -> SolverRunMetadata
}

public extension ProjectSchedulingBackend {
    func validationReport(for model: ProjectSchedulingModelEnvelope) -> ValidationReport { ValidationReport(backend: capabilities.backendKind, diagnostics: ProjectSchedulingValidator.diagnostics(for: model)) }
    func solve(_ model: ProjectSchedulingModelEnvelope) throws -> ProjectSchedulingSolution { try solve(model, options: SolverOptions()) }
    func solutionDocument(for model: ProjectSchedulingModelEnvelope, solution: ProjectSchedulingSolution) -> ProjectSchedulingSolutionDocument { ProjectSchedulingSolutionDocument(backend: runMetadata(for: model), model: model, solution: solution) }
}

public struct NativeEducationalProjectSchedulingBackend: ProjectSchedulingBackend {
    public init() {}
    public var capabilities: SolverCapabilities { SolverCapabilities(backendKind: .nativeEducational, solves: true, validates: true, exportsStructuredSolution: true, notes: ["Exact DAG critical-path scheduling for CPM and expected-time PERT."]) }
    public func solve(_ model: ProjectSchedulingModelEnvelope, options _: SolverOptions = SolverOptions()) throws -> ProjectSchedulingSolution { try ProjectSchedulingSolver.solve(model) }
    public func runMetadata(for model: ProjectSchedulingModelEnvelope) -> SolverRunMetadata { SolverRunMetadata(backendKind: .nativeEducational, algorithm: model.kind == .deterministicCPM ? "criticalPathMethod" : "pertExpectedTimeCriticalPath", exactness: .exact, notes: model.kind == .deterministicCPM ? ["Uses normal activity times; crash fields are preserved but cost-time crashing is not optimized."] : ["Uses beta expected times and activity variances from three-point estimates."]) }
}

public struct ValidateOnlyProjectSchedulingBackend: ProjectSchedulingBackend {
    public init() {}
    public var capabilities: SolverCapabilities { SolverCapabilities(backendKind: .validateOnly, solves: false, validates: true, exportsStructuredSolution: false) }
    public func solve(_ model: ProjectSchedulingModelEnvelope, options _: SolverOptions = SolverOptions()) throws -> ProjectSchedulingSolution { throw ProjectSchedulingError.invalidModel("validateOnly backend does not solve \(model.kind.rawValue)") }
    public func runMetadata(for model: ProjectSchedulingModelEnvelope) -> SolverRunMetadata { SolverRunMetadata(backendKind: .validateOnly, algorithm: "validationOnly", exactness: .exact, notes: ["Validates \(model.kind.rawValue) without solving."]) }
}

public enum ProjectSchedulingBackends {
    public static func backend(for kind: SolverBackendKind) -> (any ProjectSchedulingBackend)? {
        switch kind { case .nativeEducational: NativeEducationalProjectSchedulingBackend(); case .validateOnly: ValidateOnlyProjectSchedulingBackend(); case .externalHighPerformance: nil }
    }
}

public enum ProjectSchedulingJSON {
    public static func encodeModel(_ value: ProjectSchedulingModelEnvelope) throws -> Data { try encoder.encode(value) }
    public static func decodeModel(from data: Data) throws -> ProjectSchedulingModelEnvelope { try JSONDecoder().decode(ProjectSchedulingModelEnvelope.self, from: data) }
    public static func encodeSolution(_ value: ProjectSchedulingSolutionDocument) throws -> Data { try encoder.encode(value) }
    public static func decodeSolution(from data: Data) throws -> ProjectSchedulingSolutionDocument { try JSONDecoder().decode(ProjectSchedulingSolutionDocument.self, from: data) }
    public static func encodeCrashOptimization(_ value: CPMCrashOptimization) throws -> Data { try encoder.encode(value) }
    public static func encodeValidation(_ value: ProjectSchedulingValidationDocument) throws -> Data { try encoder.encode(value) }
    private static var encoder: JSONEncoder { NormalizedJSONCoding.encoder() }
}
