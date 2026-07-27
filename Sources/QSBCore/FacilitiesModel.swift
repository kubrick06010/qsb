import Foundation

public struct LineBalancingTask: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let time: Int
    public let isolated: Bool
    public let successorIDs: [Int]

    public init(id: Int, name: String, time: Int, isolated: Bool, successorIDs: [Int]) {
        self.id = id
        self.name = name
        self.time = time
        self.isolated = isolated
        self.successorIDs = successorIDs
    }
}

public struct LineBalancingProblem: Codable, Equatable, Sendable {
    public let title: String
    public let timeUnit: String
    public let cycleTime: Int
    public let tasks: [LineBalancingTask]

    public init(title: String, timeUnit: String, cycleTime: Int, tasks: [LineBalancingTask]) {
        self.title = title
        self.timeUnit = timeUnit
        self.cycleTime = cycleTime
        self.tasks = tasks
    }
}

public struct LineBalancingStation: Codable, Equatable, Sendable {
    public let index: Int
    public let taskIDs: [Int]
    public let taskNames: [String]
    public let workload: Int
    public let idleTime: Int
}

public struct LineBalancingSolution: Codable, Equatable, Sendable {
    public let stationCount: Int
    public let totalTaskTime: Int
    public let cycleTime: Int
    public let efficiency: Double
    public let balanceDelay: Double
    public let stations: [LineBalancingStation]
}

public enum FacilityLocationDistanceMeasure: String, Codable, Equatable, Sendable {
    case rectilinear
    case squaredEuclidean
    case euclidean
}

public struct FacilityLocationFacility: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let isNew: Bool
    public let x: Double?
    public let y: Double?
    public let interactionCosts: [Double?]

    public init(
        id: Int,
        name: String,
        isNew: Bool,
        x: Double?,
        y: Double?,
        interactionCosts: [Double?]
    ) {
        self.id = id
        self.name = name
        self.isNew = isNew
        self.x = x
        self.y = y
        self.interactionCosts = interactionCosts
    }
}

public struct FacilityLocationProblem: Codable, Equatable, Sendable {
    public let title: String
    public let distanceMeasure: FacilityLocationDistanceMeasure
    public let objective: String
    public let facilities: [FacilityLocationFacility]

    public init(
        title: String,
        distanceMeasure: FacilityLocationDistanceMeasure,
        objective: String,
        facilities: [FacilityLocationFacility]
    ) {
        self.title = title
        self.distanceMeasure = distanceMeasure
        self.objective = objective
        self.facilities = facilities
    }

    public var existingFacilities: [FacilityLocationFacility] {
        facilities.filter { !$0.isNew }
    }

    public var newFacilities: [FacilityLocationFacility] {
        facilities.filter(\.isNew)
    }
}

public struct FacilityLocationInteraction: Codable, Equatable, Sendable {
    public let existingFacilityID: Int
    public let existingFacilityName: String
    public let weight: Double
    public let distance: Double
    public let weightedDistance: Double
}

public struct FacilityLocationPlacement: Codable, Equatable, Sendable {
    public let facilityID: Int
    public let facilityName: String
    public let x: Double
    public let y: Double
    public let weightedDistance: Double
    public let interactions: [FacilityLocationInteraction]
}

public struct FacilityLocationSolution: Codable, Equatable, Sendable {
    public let distanceMeasure: FacilityLocationDistanceMeasure
    public let objectiveValue: Double
    public let placements: [FacilityLocationPlacement]
}

public enum LineBalancingJSON {
    public static func decodeModel(from data: Data) throws -> LineBalancingProblem {
        let problem = try decoder.decode(LineBalancingProblem.self, from: data)
        try LineBalancingValidator.validate(problem)
        return problem
    }

    public static func encodeModel(_ problem: LineBalancingProblem) throws -> Data {
        try encoder.encode(problem)
    }

    public static func encodeSolution(_ solution: LineBalancingSolution) throws -> Data {
        try encoder.encode(solution)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        JSONDecoder()
    }
}

public enum FacilityLocationJSON {
    public static func decodeModel(from data: Data) throws -> FacilityLocationProblem {
        let problem = try decoder.decode(FacilityLocationProblem.self, from: data)
        try FacilityLocationValidator.validate(problem)
        return problem
    }

    public static func encodeModel(_ problem: FacilityLocationProblem) throws -> Data {
        try encoder.encode(problem)
    }

    public static func encodeSolution(_ solution: FacilityLocationSolution) throws -> Data {
        try encoder.encode(solution)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        JSONDecoder()
    }
}

public struct FacilityLayoutRect: Codable, Equatable, Sendable {
    public let startRow: Int
    public let startColumn: Int
    public let endRow: Int
    public let endColumn: Int

    public init(startRow: Int, startColumn: Int, endRow: Int, endColumn: Int) {
        self.startRow = startRow
        self.startColumn = startColumn
        self.endRow = endRow
        self.endColumn = endColumn
    }

    public var cellCount: Int {
        max(0, endRow - startRow + 1) * max(0, endColumn - startColumn + 1)
    }
}

public struct FacilityLayoutDepartment: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let fixed: Bool
    public let flowUnitCosts: [Double?]
    public let initialLayout: [FacilityLayoutRect]

    public init(
        id: Int,
        name: String,
        fixed: Bool,
        flowUnitCosts: [Double?],
        initialLayout: [FacilityLayoutRect]
    ) {
        self.id = id
        self.name = name
        self.fixed = fixed
        self.flowUnitCosts = flowUnitCosts
        self.initialLayout = initialLayout
    }
}

public struct FacilityLayoutProblem: Codable, Equatable, Sendable {
    public let title: String
    public let rowCount: Int
    public let columnCount: Int
    public let objective: String
    public let departments: [FacilityLayoutDepartment]

    public init(
        title: String,
        rowCount: Int,
        columnCount: Int,
        objective: String,
        departments: [FacilityLayoutDepartment]
    ) {
        self.title = title
        self.rowCount = rowCount
        self.columnCount = columnCount
        self.objective = objective
        self.departments = departments
    }

    public var fixedDepartments: [FacilityLayoutDepartment] {
        departments.filter(\.fixed)
    }
}

public enum FacilityLayoutSolvingStrategy: String, Codable, Sendable {
    case initial
    case pairwiseSwap
}

public struct FacilityLayoutPlacement: Codable, Equatable, Sendable {
    public let departmentID: Int
    public let departmentName: String
    public let fixed: Bool
    public let rectangles: [FacilityLayoutRect]
    public let cellCount: Int
    public let centroidRow: Double
    public let centroidColumn: Double
}

public struct FacilityLayoutInteraction: Codable, Equatable, Sendable {
    public let fromDepartmentID: Int
    public let fromDepartmentName: String
    public let toDepartmentID: Int
    public let toDepartmentName: String
    public let weight: Double
    public let distance: Double
    public let weightedDistance: Double
}

public struct FacilityLayoutMove: Codable, Equatable, Sendable {
    public let kind: String
    public let firstDepartmentID: Int
    public let firstDepartmentName: String
    public let secondDepartmentID: Int
    public let secondDepartmentName: String
    public let firstBeforeRectangles: [FacilityLayoutRect]
    public let firstAfterRectangles: [FacilityLayoutRect]
    public let secondBeforeRectangles: [FacilityLayoutRect]
    public let secondAfterRectangles: [FacilityLayoutRect]
    public let objectiveBefore: Double
    public let objectiveAfter: Double
    public let improvement: Double
}

public struct FacilityLayoutSearchSummary: Codable, Equatable, Sendable {
    public let strategy: FacilityLayoutSolvingStrategy
    public let evaluatedMoveCount: Int
    public let appliedMoveCount: Int
    public let initialObjectiveValue: Double
    public let finalObjectiveValue: Double
    public let improvement: Double
}

public struct FacilityLayoutSolution: Codable, Equatable, Sendable {
    public let objective: String
    public let objectiveValue: Double
    public let source: String
    public let search: FacilityLayoutSearchSummary?
    public let moves: [FacilityLayoutMove]
    public let placements: [FacilityLayoutPlacement]
    public let interactions: [FacilityLayoutInteraction]
}

public enum FacilitiesProblemKind: String, Codable, Sendable {
    case lineBalancing
    case location
    case layout
}

public enum FacilitiesModelEnvelope: Equatable, Sendable {
    case lineBalancing(LineBalancingProblem)
    case location(FacilityLocationProblem)
    case layout(FacilityLayoutProblem)

    public var kind: FacilitiesProblemKind {
        switch self {
        case .lineBalancing:
            .lineBalancing
        case .location:
            .location
        case .layout:
            .layout
        }
    }
}

public enum FacilitiesSolutionEnvelope: Equatable, Sendable {
    case lineBalancing(LineBalancingSolution)
    case location(FacilityLocationSolution)
    case layout(FacilityLayoutSolution)

    public var kind: FacilitiesProblemKind {
        switch self {
        case .lineBalancing:
            .lineBalancing
        case .location:
            .location
        case .layout:
            .layout
        }
    }
}

public struct FacilitiesSolutionDocument: Equatable, Sendable {
    public let backend: SolverRunMetadata
    public let solution: FacilitiesSolutionEnvelope

    public init(backend: SolverRunMetadata, solution: FacilitiesSolutionEnvelope) {
        self.backend = backend
        self.solution = solution
    }

    public var kind: FacilitiesProblemKind {
        solution.kind
    }
}

public struct FacilitiesValidationDocument: Codable, Equatable, Sendable {
    public let kind: FacilitiesProblemKind
    public let backend: SolverBackendKind
    public let isValid: Bool
    public let diagnostics: [ValidationDiagnostic]

    public init(
        kind: FacilitiesProblemKind,
        backend: SolverBackendKind = .validateOnly,
        diagnostics: [ValidationDiagnostic]
    ) {
        self.kind = kind
        self.backend = backend
        self.isValid = !diagnostics.contains { $0.severity == .error }
        self.diagnostics = diagnostics
    }
}

extension FacilitiesModelEnvelope: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case model
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(FacilitiesProblemKind.self, forKey: .kind)
        switch kind {
        case .lineBalancing:
            self = .lineBalancing(try container.decode(LineBalancingProblem.self, forKey: .model))
        case .location:
            self = .location(try container.decode(FacilityLocationProblem.self, forKey: .model))
        case .layout:
            self = .layout(try container.decode(FacilityLayoutProblem.self, forKey: .model))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .lineBalancing(let model):
            try container.encode(model, forKey: .model)
        case .location(let model):
            try container.encode(model, forKey: .model)
        case .layout(let model):
            try container.encode(model, forKey: .model)
        }
    }
}

extension FacilitiesSolutionEnvelope: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case solution
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(FacilitiesProblemKind.self, forKey: .kind)
        switch kind {
        case .lineBalancing:
            self = .lineBalancing(try container.decode(LineBalancingSolution.self, forKey: .solution))
        case .location:
            self = .location(try container.decode(FacilityLocationSolution.self, forKey: .solution))
        case .layout:
            self = .layout(try container.decode(FacilityLayoutSolution.self, forKey: .solution))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .lineBalancing(let solution):
            try container.encode(solution, forKey: .solution)
        case .location(let solution):
            try container.encode(solution, forKey: .solution)
        case .layout(let solution):
            try container.encode(solution, forKey: .solution)
        }
    }
}

extension FacilitiesSolutionDocument: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case backend
        case solution
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(FacilitiesProblemKind.self, forKey: .kind)
        backend = try container.decode(SolverRunMetadata.self, forKey: .backend)
        switch kind {
        case .lineBalancing:
            solution = .lineBalancing(try container.decode(LineBalancingSolution.self, forKey: .solution))
        case .location:
            solution = .location(try container.decode(FacilityLocationSolution.self, forKey: .solution))
        case .layout:
            solution = .layout(try container.decode(FacilityLayoutSolution.self, forKey: .solution))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(backend, forKey: .backend)
        switch solution {
        case .lineBalancing(let solution):
            try container.encode(solution, forKey: .solution)
        case .location(let solution):
            try container.encode(solution, forKey: .solution)
        case .layout(let solution):
            try container.encode(solution, forKey: .solution)
        }
    }
}

public enum FacilitiesModelJSON {
    public static func decodeUncheckedModel(from data: Data) throws -> FacilitiesModelEnvelope {
        try decoder.decode(FacilitiesModelEnvelope.self, from: data)
    }

    public static func decodeModel(from data: Data) throws -> FacilitiesModelEnvelope {
        let envelope = try decodeUncheckedModel(from: data)
        try validate(envelope)
        return envelope
    }

    public static func encodeModel(_ envelope: FacilitiesModelEnvelope) throws -> Data {
        try encoder.encode(envelope)
    }

    public static func encodeSolution(_ envelope: FacilitiesSolutionEnvelope) throws -> Data {
        try encoder.encode(envelope)
    }

    public static func encodeSolutionDocument(_ document: FacilitiesSolutionDocument) throws -> Data {
        try encoder.encode(document)
    }

    public static func decodeSolutionDocument(from data: Data) throws -> FacilitiesSolutionDocument {
        try decoder.decode(FacilitiesSolutionDocument.self, from: data)
    }

    public static func validationDocument(
        for envelope: FacilitiesModelEnvelope,
        backend: SolverBackendKind = .validateOnly
    ) -> FacilitiesValidationDocument {
        FacilitiesValidationDocument(
            kind: envelope.kind,
            backend: backend,
            diagnostics: diagnostics(for: envelope)
        )
    }

    public static func encodeValidation(_ document: FacilitiesValidationDocument) throws -> Data {
        try encoder.encode(document)
    }

    private static func validate(_ envelope: FacilitiesModelEnvelope) throws {
        switch envelope {
        case .lineBalancing(let problem):
            try LineBalancingValidator.validate(problem)
        case .location(let problem):
            try FacilityLocationValidator.validate(problem)
        case .layout(let problem):
            try FacilityLayoutValidator.validate(problem)
        }
    }

    private static func diagnostics(for envelope: FacilitiesModelEnvelope) -> [ValidationDiagnostic] {
        switch envelope {
        case .lineBalancing(let problem):
            LineBalancingValidator.diagnostics(for: problem)
        case .location(let problem):
            FacilityLocationValidator.diagnostics(for: problem)
        case .layout(let problem):
            FacilityLayoutValidator.diagnostics(for: problem)
        }
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        JSONDecoder()
    }
}

public enum FacilitiesModelError: Error, CustomStringConvertible {
    case unsupportedFormat
    case invalidNumericValue(String)
    case invalidModel(String)

    public var description: String {
        switch self {
        case .unsupportedFormat:
            "Unsupported facilities model format"
        case .invalidNumericValue(let value):
            "Invalid numeric value: \(value)"
        case .invalidModel(let detail):
            "Invalid facilities model: \(detail)"
        }
    }
}

public protocol FacilitiesBackend: Sendable {
    var capabilities: SolverCapabilities { get }

    func validationReport(for problem: LineBalancingProblem) -> ValidationReport
    func validationReport(for problem: FacilityLocationProblem) -> ValidationReport
    func validationReport(for problem: FacilityLayoutProblem) -> ValidationReport

    func solve(_ problem: LineBalancingProblem, options: SolverOptions) throws -> LineBalancingSolution
    func solve(_ problem: FacilityLocationProblem, options: SolverOptions) throws -> FacilityLocationSolution
    func solve(
        _ problem: FacilityLayoutProblem,
        strategy: FacilityLayoutSolvingStrategy,
        options: SolverOptions
    ) throws -> FacilityLayoutSolution

    func runMetadata(for problem: LineBalancingProblem) -> SolverRunMetadata
    func runMetadata(for problem: FacilityLocationProblem) -> SolverRunMetadata
    func runMetadata(
        for problem: FacilityLayoutProblem,
        strategy: FacilityLayoutSolvingStrategy
    ) -> SolverRunMetadata
}

public extension FacilitiesBackend {
    func validationReport(for problem: LineBalancingProblem) -> ValidationReport {
        ValidationReport(
            backend: capabilities.backendKind,
            diagnostics: LineBalancingValidator.diagnostics(for: problem)
        )
    }

    func validationReport(for problem: FacilityLocationProblem) -> ValidationReport {
        ValidationReport(
            backend: capabilities.backendKind,
            diagnostics: FacilityLocationValidator.diagnostics(for: problem)
        )
    }

    func validationReport(for problem: FacilityLayoutProblem) -> ValidationReport {
        ValidationReport(
            backend: capabilities.backendKind,
            diagnostics: FacilityLayoutValidator.diagnostics(for: problem)
        )
    }

    func validationReport(for envelope: FacilitiesModelEnvelope) -> ValidationReport {
        switch envelope {
        case .lineBalancing(let problem):
            validationReport(for: problem)
        case .location(let problem):
            validationReport(for: problem)
        case .layout(let problem):
            validationReport(for: problem)
        }
    }

    func solve(_ problem: LineBalancingProblem) throws -> LineBalancingSolution {
        try solve(problem, options: SolverOptions())
    }

    func solve(_ problem: FacilityLocationProblem) throws -> FacilityLocationSolution {
        try solve(problem, options: SolverOptions())
    }

    func solve(
        _ problem: FacilityLayoutProblem,
        strategy: FacilityLayoutSolvingStrategy = .initial
    ) throws -> FacilityLayoutSolution {
        try solve(problem, strategy: strategy, options: SolverOptions())
    }

    func solve(
        _ envelope: FacilitiesModelEnvelope,
        layoutStrategy: FacilityLayoutSolvingStrategy = .initial,
        options: SolverOptions = SolverOptions()
    ) throws -> FacilitiesSolutionEnvelope {
        switch envelope {
        case .lineBalancing(let problem):
            .lineBalancing(try solve(problem, options: options))
        case .location(let problem):
            .location(try solve(problem, options: options))
        case .layout(let problem):
            .layout(try solve(problem, strategy: layoutStrategy, options: options))
        }
    }

    func runMetadata(
        for envelope: FacilitiesModelEnvelope,
        layoutStrategy: FacilityLayoutSolvingStrategy = .initial
    ) -> SolverRunMetadata {
        switch envelope {
        case .lineBalancing(let problem):
            runMetadata(for: problem)
        case .location(let problem):
            runMetadata(for: problem)
        case .layout(let problem):
            runMetadata(for: problem, strategy: layoutStrategy)
        }
    }
}

public struct NativeEducationalFacilitiesBackend: FacilitiesBackend {
    public init() {}

    public var capabilities: SolverCapabilities {
        SolverCapabilities(
            backendKind: .nativeEducational,
            solves: true,
            validates: true,
            exportsStructuredSolution: true,
            notes: [
                "Uses fixture-scale exact line-balancing search.",
                "Uses closed-form or iterative single-facility location methods.",
                "Uses initial evaluation or pairwise-swap local search for layouts."
            ]
        )
    }

    public func solve(
        _ problem: LineBalancingProblem,
        options _: SolverOptions = SolverOptions()
    ) throws -> LineBalancingSolution {
        try LineBalancingSolver.solve(problem)
    }

    public func solve(
        _ problem: FacilityLocationProblem,
        options _: SolverOptions = SolverOptions()
    ) throws -> FacilityLocationSolution {
        try FacilityLocationSolver.solve(problem)
    }

    public func solve(
        _ problem: FacilityLayoutProblem,
        strategy: FacilityLayoutSolvingStrategy = .initial,
        options _: SolverOptions = SolverOptions()
    ) throws -> FacilityLayoutSolution {
        switch strategy {
        case .initial:
            try FacilityLayoutSolver.solve(problem)
        case .pairwiseSwap:
            try FacilityLayoutSolver.improve(problem)
        }
    }

    public func runMetadata(for problem: LineBalancingProblem) -> SolverRunMetadata {
        SolverRunMetadata(
            backendKind: .nativeEducational,
            algorithm: "bitmaskDynamicProgramming",
            exactness: .fixtureScale,
            notes: [
                "Exact station minimization for supported fixture-scale instances.",
                "Current native solver rejects instances with more than 24 tasks."
            ]
        )
    }

    public func runMetadata(for problem: FacilityLocationProblem) -> SolverRunMetadata {
        switch problem.distanceMeasure {
        case .rectilinear:
            SolverRunMetadata(
                backendKind: .nativeEducational,
                algorithm: "weightedMedian",
                exactness: .closedForm,
                notes: ["Single-new-facility rectilinear distance model."]
            )
        case .squaredEuclidean:
            SolverRunMetadata(
                backendKind: .nativeEducational,
                algorithm: "weightedCentroid",
                exactness: .closedForm,
                notes: ["Single-new-facility squared Euclidean distance model."]
            )
        case .euclidean:
            SolverRunMetadata(
                backendKind: .nativeEducational,
                algorithm: "weiszfeldIteration",
                exactness: .approximate,
                notes: ["Single-new-facility Euclidean distance model solved by iterative Weiszfeld updates."]
            )
        }
    }

    public func runMetadata(
        for problem: FacilityLayoutProblem,
        strategy: FacilityLayoutSolvingStrategy
    ) -> SolverRunMetadata {
        switch strategy {
        case .initial:
            SolverRunMetadata(
                backendKind: .nativeEducational,
                algorithm: "initialLayoutEvaluation",
                exactness: .fixtureScale,
                notes: ["Evaluates centroid-based rectilinear load-distance for the provided initial layout."]
            )
        case .pairwiseSwap:
            SolverRunMetadata(
                backendKind: .nativeEducational,
                algorithm: "pairwiseSameSizeSwapLocalSearch",
                exactness: .heuristic,
                notes: ["Repeatedly swaps non-fixed departments with equal cell counts when the swap improves load-distance."]
            )
        }
    }
}

public struct ValidateOnlyFacilitiesBackend: FacilitiesBackend {
    public init() {}

    public var capabilities: SolverCapabilities {
        SolverCapabilities(
            backendKind: .validateOnly,
            solves: false,
            validates: true,
            exportsStructuredSolution: false,
            notes: ["Runs facilities validation without solving the model."]
        )
    }

    public func solve(
        _ problem: LineBalancingProblem,
        options _: SolverOptions = SolverOptions()
    ) throws -> LineBalancingSolution {
        throw FacilitiesModelError.invalidModel("validateOnly backend does not solve line-balancing models")
    }

    public func solve(
        _ problem: FacilityLocationProblem,
        options _: SolverOptions = SolverOptions()
    ) throws -> FacilityLocationSolution {
        throw FacilitiesModelError.invalidModel("validateOnly backend does not solve facility-location models")
    }

    public func solve(
        _ problem: FacilityLayoutProblem,
        strategy: FacilityLayoutSolvingStrategy = .initial,
        options _: SolverOptions = SolverOptions()
    ) throws -> FacilityLayoutSolution {
        throw FacilitiesModelError.invalidModel("validateOnly backend does not solve facility-layout models")
    }

    public func runMetadata(for problem: LineBalancingProblem) -> SolverRunMetadata {
        validationMetadata(for: .lineBalancing)
    }

    public func runMetadata(for problem: FacilityLocationProblem) -> SolverRunMetadata {
        validationMetadata(for: .location)
    }

    public func runMetadata(
        for problem: FacilityLayoutProblem,
        strategy: FacilityLayoutSolvingStrategy
    ) -> SolverRunMetadata {
        validationMetadata(for: .layout)
    }

    private func validationMetadata(for kind: FacilitiesProblemKind) -> SolverRunMetadata {
        SolverRunMetadata(
            backendKind: .validateOnly,
            algorithm: "validationOnly",
            exactness: .exact,
            notes: ["Validates the \(kind.rawValue) model without solving it."]
        )
    }
}

public enum FacilitiesBackends {
    public static func backend(for kind: SolverBackendKind) -> (any FacilitiesBackend)? {
        switch kind {
        case .nativeEducational:
            NativeEducationalFacilitiesBackend()
        case .validateOnly:
            ValidateOnlyFacilitiesBackend()
        case .externalHighPerformance:
            nil
        }
    }
}

public enum WinQSBFacilitiesParser {
    public static func parseModelEnvelope(from data: Data) throws -> FacilitiesModelEnvelope {
        let lines = try tabularLines(from: data)
        guard let metadata = lines.first,
              metadata.count >= 3,
              metadata[0] == "FLL"
        else {
            throw FacilitiesModelError.unsupportedFormat
        }

        switch metadata[2].uppercased() {
        case "LINE BALANCING":
            return .lineBalancing(try parseLineBalancing(from: data))
        case "LOCATION":
            return .location(try parseLocation(from: data))
        case "LAYOUT":
            return .layout(try parseLayout(from: data))
        default:
            throw FacilitiesModelError.unsupportedFormat
        }
    }

    public static func parseLayout(from data: Data) throws -> FacilityLayoutProblem {
        let lines = try tabularLines(from: data)
        guard let metadata = lines.first,
              metadata.count >= 7,
              metadata[0] == "FLL",
              metadata[2].uppercased() == "LAYOUT",
              let departmentCount = Int(metadata[3]),
              let rowCount = Int(metadata[4]),
              let columnCount = Int(metadata[5]),
              departmentCount > 0,
              rowCount > 0,
              columnCount > 0,
              lines.count >= departmentCount + 2
        else {
            throw FacilitiesModelError.unsupportedFormat
        }

        let departments = try lines[2..<(2 + departmentCount)].map { row -> FacilityLayoutDepartment in
            guard row.count >= departmentCount + 4,
                  let id = Int(row[0])
            else {
                throw FacilitiesModelError.unsupportedFormat
            }

            return FacilityLayoutDepartment(
                id: id,
                name: row[1],
                fixed: row[2].lowercased().hasPrefix("y"),
                flowUnitCosts: try (0..<departmentCount).map { index in
                    try optionalDouble(row[safe: 3 + index])
                },
                initialLayout: try parseLayoutRects(row[3 + departmentCount])
            )
        }

        return FacilityLayoutProblem(
            title: metadata[1],
            rowCount: rowCount,
            columnCount: columnCount,
            objective: metadata[6].uppercased(),
            departments: departments
        )
    }

    public static func parseLocation(from data: Data) throws -> FacilityLocationProblem {
        let lines = try tabularLines(from: data)
        guard let metadata = lines.first,
              metadata.count >= 7,
              metadata[0] == "FLL",
              metadata[2].uppercased() == "LOCATION",
              let existingCount = Int(metadata[3]),
              let newCount = Int(metadata[4]),
              existingCount > 0,
              newCount > 0,
              lines.count >= existingCount + newCount + 2
        else {
            throw FacilitiesModelError.unsupportedFormat
        }

        let totalFacilityCount = existingCount + newCount
        let distanceMeasure = try parseDistanceMeasure(metadata[5])
        let facilities = try lines[2..<(2 + totalFacilityCount)].enumerated().map { offset, row in
            guard row.count >= 2 + totalFacilityCount else {
                throw FacilitiesModelError.unsupportedFormat
            }

            let marker = row[0].lowercased()
            let isNew = marker.hasPrefix("new")
            let id = try parseTrailingID(row[0], fallback: offset + 1)
            let interactionCosts = try (0..<totalFacilityCount).map { costIndex in
                try optionalDouble(row[safe: 2 + costIndex])
            }

            return FacilityLocationFacility(
                id: id,
                name: row[1],
                isNew: isNew,
                x: try optionalDouble(row[safe: 2 + totalFacilityCount]),
                y: try optionalDouble(row[safe: 3 + totalFacilityCount]),
                interactionCosts: interactionCosts
            )
        }

        guard facilities.filter({ !$0.isNew }).count == existingCount,
              facilities.filter(\.isNew).count == newCount
        else {
            throw FacilitiesModelError.unsupportedFormat
        }

        return FacilityLocationProblem(
            title: metadata[1],
            distanceMeasure: distanceMeasure,
            objective: metadata[6].uppercased(),
            facilities: facilities
        )
    }

    public static func parseLineBalancing(from data: Data) throws -> LineBalancingProblem {
        let lines = try tabularLines(from: data)
        guard let metadata = lines.first,
              metadata.count >= 6,
              metadata[0] == "FLL",
              metadata[2].uppercased() == "LINE BALANCING",
              let taskCount = Int(metadata[3]),
              let cycleTime = Int(metadata[5]),
              taskCount > 0,
              cycleTime > 0,
              lines.count >= taskCount + 2
        else {
            throw FacilitiesModelError.unsupportedFormat
        }

        let tasks = try lines[2..<(2 + taskCount)].map { row -> LineBalancingTask in
            guard row.count >= 5,
                  let id = Int(row[0]),
                  let time = Int(row[2])
            else {
                throw FacilitiesModelError.unsupportedFormat
            }
            return LineBalancingTask(
                id: id,
                name: row[1],
                time: time,
                isolated: row[3].lowercased().hasPrefix("y"),
                successorIDs: try parseSuccessors(row[4])
            )
        }

        return LineBalancingProblem(
            title: metadata[1],
            timeUnit: metadata[4],
            cycleTime: cycleTime,
            tasks: tasks
        )
    }

    private static func parseDistanceMeasure(_ value: String) throws -> FacilityLocationDistanceMeasure {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "rectilinear":
            return .rectilinear
        case "2", "squared euclidean", "squared-euclidean", "squaredeuclidean":
            return .squaredEuclidean
        case "3", "euclidean":
            return .euclidean
        default:
            throw FacilitiesModelError.unsupportedFormat
        }
    }

    private static func parseTrailingID(_ value: String, fallback: Int) throws -> Int {
        guard let last = value.split(separator: " ").last else {
            return fallback
        }
        guard let id = Int(last) else {
            throw FacilitiesModelError.invalidNumericValue(String(last))
        }
        return id
    }

    private static func optionalDouble(_ value: String?) throws -> Double? {
        guard let value else {
            return nil
        }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return nil
        }
        guard let number = Double(normalized), number.isFinite else {
            throw FacilitiesModelError.invalidNumericValue(value)
        }
        return number
    }

    private static func tabularLines(from data: Data) throws -> [[String]] {
        guard let text = data.legacyLatin1String else {
            throw FacilitiesModelError.unsupportedFormat
        }

        return text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(clean) }
    }

    private static func parseSuccessors(_ value: String) throws -> [Int] {
        guard !value.isEmpty else {
            return []
        }
        return try value.split(separator: ",").map { piece in
            let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let id = Int(trimmed) else {
                throw FacilitiesModelError.invalidNumericValue(trimmed)
            }
            return id
        }
    }

    private static func parseLayoutRects(_ value: String) throws -> [FacilityLayoutRect] {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return []
        }

        var rects: [FacilityLayoutRect] = []
        var index = text.startIndex

        func skipWhitespace() {
            while index < text.endIndex, text[index].isWhitespace {
                index = text.index(after: index)
            }
        }

        func consume(_ character: Character) -> Bool {
            skipWhitespace()
            guard index < text.endIndex, text[index] == character else {
                return false
            }
            index = text.index(after: index)
            return true
        }

        func parseInt() -> Int? {
            skipWhitespace()
            let start = index
            while index < text.endIndex, text[index].isNumber {
                index = text.index(after: index)
            }
            guard start != index else {
                return nil
            }
            return Int(text[start..<index])
        }

        func parseCell() throws -> (row: Int, column: Int) {
            guard consume("("),
                  let row = parseInt(),
                  consume(","),
                  let column = parseInt(),
                  consume(")")
            else {
                throw FacilitiesModelError.unsupportedFormat
            }
            return (row: row, column: column)
        }

        while index < text.endIndex {
            let start = try parseCell()
            var end = start
            if consume("-") {
                end = try parseCell()
            }

            rects.append(FacilityLayoutRect(
                startRow: min(start.row, end.row),
                startColumn: min(start.column, end.column),
                endRow: max(start.row, end.row),
                endColumn: max(start.column, end.column)
            ))

            skipWhitespace()
            guard index < text.endIndex else {
                break
            }
            guard consume(",") else {
                throw FacilitiesModelError.unsupportedFormat
            }
        }

        return rects
    }

    private static func clean(_ value: Substring) -> String {
        String(value).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum FacilityLayoutValidator {
    public static func diagnostics(for problem: FacilityLayoutProblem) -> [ValidationDiagnostic] {
        var diagnostics: [ValidationDiagnostic] = []

        if problem.departments.isEmpty {
            diagnostics.append(error(
                "facilities.layout.departments.empty",
                "facility layout departments must not be empty",
                path: "departments"
            ))
        }
        if problem.rowCount <= 0 || problem.columnCount <= 0 {
            diagnostics.append(error(
                "facilities.layout.grid.positive",
                "facility layout grid dimensions must be positive",
                path: "grid"
            ))
        }
        if problem.objective != "MIN" {
            diagnostics.append(error(
                "facilities.layout.objective.unsupported",
                "facility layout currently supports minimization only",
                path: "objective"
            ))
        }

        let departmentIDs = problem.departments.map(\.id)
        if Set(departmentIDs).count != departmentIDs.count {
            diagnostics.append(error(
                "facilities.layout.departments.duplicate",
                "facility layout department ids must be unique",
                path: "departments"
            ))
        }

        for department in problem.departments {
            if department.flowUnitCosts.count != problem.departments.count {
                diagnostics.append(error(
                    "facilities.layout.flow.dimension",
                    "facility layout flow/unit-cost rows must match department count",
                    path: "departments.\(department.name).flowUnitCosts"
                ))
            }
            for (index, value) in department.flowUnitCosts.enumerated() where (value ?? 0) < 0 || value?.isFinite == false {
                diagnostics.append(error(
                    "facilities.layout.flow.nonnegative",
                    "facility layout flow/unit-cost values must be finite and nonnegative",
                    path: flowPath(problem: problem, department: department, index: index)
                ))
            }
            if department.initialLayout.isEmpty {
                diagnostics.append(error(
                    "facilities.layout.initial.empty",
                    "facility layout departments must have initial cell locations",
                    path: "departments.\(department.name).initialLayout"
                ))
            }
            for rect in department.initialLayout {
                if rect.startRow <= 0 || rect.startColumn <= 0 ||
                    rect.endRow > problem.rowCount || rect.endColumn > problem.columnCount ||
                    rect.startRow > rect.endRow || rect.startColumn > rect.endColumn {
                    diagnostics.append(error(
                        "facilities.layout.initial.bounds",
                        "facility layout cell locations must be inside the layout grid",
                        path: "departments.\(department.name).initialLayout"
                    ))
                }
            }
        }

        var occupied: [FacilityLayoutCell: FacilityLayoutDepartment] = [:]
        for department in problem.departments {
            for cell in layoutCells(in: department.initialLayout).sorted() {
                guard cell.row >= 1, cell.row <= problem.rowCount, cell.column >= 1, cell.column <= problem.columnCount else {
                    continue
                }
                if let owner = occupied[cell], owner.id != department.id {
                    if owner.fixed || department.fixed {
                        diagnostics.append(warning(
                            "facilities.layout.initial.fixedOverlap",
                            "facility layout cell (\(cell.row),\(cell.column)) is shared by fixed area \(owner.fixed ? owner.name : department.name)",
                            path: "departments.\(department.name).initialLayout"
                        ))
                    } else {
                        diagnostics.append(error(
                            "facilities.layout.initial.overlap",
                            "facility layout cell (\(cell.row),\(cell.column)) is assigned to both \(owner.name) and \(department.name)",
                            path: "departments.\(department.name).initialLayout"
                        ))
                    }
                } else {
                    occupied[cell] = department
                }
            }
        }

        let gridCellCount = max(0, problem.rowCount * problem.columnCount)
        if gridCellCount > 0, occupied.count != gridCellCount {
            diagnostics.append(warning(
                "facilities.layout.initial.coverage",
                "facility layout initial cells cover \(occupied.count) of \(gridCellCount) grid cells",
                path: "departments.initialLayout"
            ))
        }

        guard diagnostics.contains(where: { $0.severity == .error }) == false else {
            return diagnostics
        }

        return diagnostics + [
            ValidationDiagnostic(
                severity: .info,
                code: "facilities.layout.valid",
                message: "Facility layout model is valid"
            )
        ]
    }

    public static func validate(_ problem: FacilityLayoutProblem) throws {
        if let diagnostic = diagnostics(for: problem).first(where: { $0.severity == .error }) {
            throw FacilitiesModelError.invalidModel(diagnostic.message)
        }
    }

    private static func error(_ code: String, _ message: String, path: String?) -> ValidationDiagnostic {
        ValidationDiagnostic(severity: .error, code: code, message: message, path: path)
    }

    private static func warning(_ code: String, _ message: String, path: String?) -> ValidationDiagnostic {
        ValidationDiagnostic(severity: .warning, code: code, message: message, path: path)
    }

    private static func flowPath(
        problem: FacilityLayoutProblem,
        department: FacilityLayoutDepartment,
        index: Int
    ) -> String {
        guard index < problem.departments.count else {
            return "departments.\(department.name).flowUnitCosts.\(index)"
        }
        return "departments.\(department.name).flowUnitCosts.\(problem.departments[index].name)"
    }
}

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

public enum FacilityLayoutJSON {
    public static func decodeModel(from data: Data) throws -> FacilityLayoutProblem {
        let problem = try decoder.decode(FacilityLayoutProblem.self, from: data)
        try FacilityLayoutValidator.validate(problem)
        return problem
    }

    public static func encodeModel(_ problem: FacilityLayoutProblem) throws -> Data {
        try encoder.encode(problem)
    }

    public static func encodeSolution(_ solution: FacilityLayoutSolution) throws -> Data {
        try encoder.encode(solution)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        JSONDecoder()
    }
}

public enum FacilityLocationValidator {
    public static func diagnostics(for problem: FacilityLocationProblem) -> [ValidationDiagnostic] {
        var diagnostics: [ValidationDiagnostic] = []

        if problem.facilities.isEmpty {
            diagnostics.append(error(
                "facilities.location.facilities.empty",
                "facility location facilities must not be empty",
                path: "facilities"
            ))
        }
        if problem.objective != "MIN" {
            diagnostics.append(error(
                "facilities.location.objective.unsupported",
                "facility location currently supports minimization only",
                path: "objective"
            ))
        }
        if problem.newFacilities.count != 1 {
            diagnostics.append(error(
                "facilities.location.newFacilities.count",
                "facility location currently supports exactly one new facility",
                path: "facilities"
            ))
        }
        if problem.existingFacilities.isEmpty {
            diagnostics.append(error(
                "facilities.location.existingFacilities.empty",
                "facility location requires existing facilities",
                path: "facilities"
            ))
        }

        let facilityNames = problem.facilities.map(\.name)
        if Set(facilityNames).count != facilityNames.count {
            diagnostics.append(error(
                "facilities.location.facilities.duplicate",
                "facility location facility names must be unique",
                path: "facilities"
            ))
        }

        let totalFacilityCount = problem.facilities.count
        for facility in problem.facilities {
            if facility.interactionCosts.count != totalFacilityCount {
                diagnostics.append(error(
                    "facilities.location.interactions.dimension",
                    "facility location interaction rows must match facility count",
                    path: "facilities.\(facility.name).interactionCosts"
                ))
            }

            if !facility.isNew {
                if facility.x == nil || facility.y == nil {
                    diagnostics.append(error(
                        "facilities.location.coordinates.required",
                        "existing facilities require coordinates",
                        path: "facilities.\(facility.name)"
                    ))
                } else if facility.x?.isFinite == false || facility.y?.isFinite == false {
                    diagnostics.append(error(
                        "facilities.location.coordinates.finite",
                        "existing facility coordinates must be finite",
                        path: "facilities.\(facility.name)"
                    ))
                }
            }

            for (index, value) in facility.interactionCosts.enumerated() where (value ?? 0) < 0 || value?.isFinite == false {
                diagnostics.append(error(
                    "facilities.location.interactions.nonnegative",
                    "facility location interaction weights must be finite and nonnegative",
                    path: interactionPath(problem: problem, facility: facility, index: index)
                ))
            }
        }

        if let newIndex = problem.facilities.firstIndex(where: \.isNew),
           problem.facilities[newIndex].interactionCosts.count == totalFacilityCount {
            var hasPositiveInteraction = false
            for existingIndex in problem.facilities.indices where !problem.facilities[existingIndex].isNew {
                guard problem.facilities[existingIndex].interactionCosts.count == totalFacilityCount else {
                    continue
                }
                let forwardWeight = problem.facilities[newIndex].interactionCosts[existingIndex] ?? 0
                let reverseWeight = problem.facilities[existingIndex].interactionCosts[newIndex] ?? 0
                if forwardWeight + reverseWeight > 0 {
                    hasPositiveInteraction = true
                }
            }
            if !hasPositiveInteraction, !problem.existingFacilities.isEmpty {
                diagnostics.append(error(
                    "facilities.location.interactions.positive",
                    "facility location requires at least one positive interaction with the new facility",
                    path: "facilities"
                ))
            }
        }

        guard diagnostics.contains(where: { $0.severity == .error }) == false else {
            return diagnostics
        }

        return diagnostics + [
            ValidationDiagnostic(
                severity: .info,
                code: "facilities.location.valid",
                message: "Facility location model is valid"
            )
        ]
    }

    public static func validate(_ problem: FacilityLocationProblem) throws {
        if let diagnostic = diagnostics(for: problem).first(where: { $0.severity == .error }) {
            throw FacilitiesModelError.invalidModel(diagnostic.message)
        }
    }

    private static func error(_ code: String, _ message: String, path: String?) -> ValidationDiagnostic {
        ValidationDiagnostic(severity: .error, code: code, message: message, path: path)
    }

    private static func interactionPath(
        problem: FacilityLocationProblem,
        facility: FacilityLocationFacility,
        index: Int
    ) -> String {
        guard index < problem.facilities.count else {
            return "facilities.\(facility.name).interactionCosts.\(index)"
        }
        return "facilities.\(facility.name).interactionCosts.\(problem.facilities[index].name)"
    }
}

public enum FacilityLocationSolver {
    private struct WeightedPoint {
        let facility: FacilityLocationFacility
        let x: Double
        let y: Double
        let weight: Double
    }

    public static func solve(_ problem: FacilityLocationProblem) throws -> FacilityLocationSolution {
        let points = try validateAndBuildWeightedPoints(problem)
        let newFacility = problem.newFacilities[0]
        let coordinate = try optimalCoordinate(for: problem.distanceMeasure, points: points)
        let interactions = points.map { point in
            let distance = distance(
                from: coordinate,
                to: (x: point.x, y: point.y),
                measure: problem.distanceMeasure
            )
            return FacilityLocationInteraction(
                existingFacilityID: point.facility.id,
                existingFacilityName: point.facility.name,
                weight: point.weight,
                distance: distance,
                weightedDistance: point.weight * distance
            )
        }
        let weightedDistance = interactions.reduce(0) { $0 + $1.weightedDistance }
        let placement = FacilityLocationPlacement(
            facilityID: newFacility.id,
            facilityName: newFacility.name,
            x: coordinate.x,
            y: coordinate.y,
            weightedDistance: weightedDistance,
            interactions: interactions
        )

        return FacilityLocationSolution(
            distanceMeasure: problem.distanceMeasure,
            objectiveValue: weightedDistance,
            placements: [placement]
        )
    }

    private static func validateAndBuildWeightedPoints(_ problem: FacilityLocationProblem) throws -> [WeightedPoint] {
        try FacilityLocationValidator.validate(problem)

        guard problem.objective == "MIN" else {
            throw FacilitiesModelError.invalidModel("facility location currently supports minimization only")
        }
        guard problem.newFacilities.count == 1 else {
            throw FacilitiesModelError.invalidModel("facility location currently supports exactly one new facility")
        }
        guard !problem.existingFacilities.isEmpty else {
            throw FacilitiesModelError.invalidModel("facility location requires existing facilities")
        }

        let totalFacilityCount = problem.facilities.count
        for facility in problem.facilities {
            guard facility.interactionCosts.count == totalFacilityCount else {
                throw FacilitiesModelError.invalidModel("facility location interaction rows must match facility count")
            }
        }

        guard let newIndex = problem.facilities.firstIndex(where: \.isNew) else {
            throw FacilitiesModelError.invalidModel("facility location requires a new facility")
        }

        var points: [WeightedPoint] = []
        for existingIndex in problem.facilities.indices where !problem.facilities[existingIndex].isNew {
            let existing = problem.facilities[existingIndex]
            guard let x = existing.x, let y = existing.y else {
                throw FacilitiesModelError.invalidModel("existing facilities require coordinates")
            }
            let forwardWeight = problem.facilities[newIndex].interactionCosts[existingIndex] ?? 0
            let reverseWeight = problem.facilities[existingIndex].interactionCosts[newIndex] ?? 0
            let weight = forwardWeight + reverseWeight
            guard weight >= 0 else {
                throw FacilitiesModelError.invalidModel("facility location interaction weights must be nonnegative")
            }
            if weight > 0 {
                points.append(WeightedPoint(facility: existing, x: x, y: y, weight: weight))
            }
        }

        guard !points.isEmpty else {
            throw FacilitiesModelError.invalidModel("facility location requires at least one positive interaction")
        }
        return points
    }

    private static func optimalCoordinate(
        for measure: FacilityLocationDistanceMeasure,
        points: [WeightedPoint]
    ) throws -> (x: Double, y: Double) {
        switch measure {
        case .rectilinear:
            return (
                x: weightedMedian(points.map { (coordinate: $0.x, weight: $0.weight) }),
                y: weightedMedian(points.map { (coordinate: $0.y, weight: $0.weight) })
            )
        case .squaredEuclidean:
            let totalWeight = points.reduce(0) { $0 + $1.weight }
            guard totalWeight > 0 else {
                throw FacilitiesModelError.invalidModel("facility location requires positive total weight")
            }
            return (
                x: points.reduce(0) { $0 + $1.weight * $1.x } / totalWeight,
                y: points.reduce(0) { $0 + $1.weight * $1.y } / totalWeight
            )
        case .euclidean:
            return try weiszfeldCoordinate(points)
        }
    }

    private static func weightedMedian(_ values: [(coordinate: Double, weight: Double)]) -> Double {
        let sorted = values.sorted { $0.coordinate < $1.coordinate }
        let halfWeight = sorted.reduce(0) { $0 + $1.weight } / 2.0
        var cumulativeWeight = 0.0
        for value in sorted {
            cumulativeWeight += value.weight
            if cumulativeWeight >= halfWeight {
                return value.coordinate
            }
        }
        return sorted.last?.coordinate ?? 0
    }

    private static func weiszfeldCoordinate(_ points: [WeightedPoint]) throws -> (x: Double, y: Double) {
        var coordinate = try optimalCoordinate(for: .squaredEuclidean, points: points)
        for _ in 0..<1_000 {
            var numeratorX = 0.0
            var numeratorY = 0.0
            var denominator = 0.0
            for point in points {
                let euclideanDistance = hypot(coordinate.x - point.x, coordinate.y - point.y)
                if euclideanDistance < 1e-10 {
                    return (x: point.x, y: point.y)
                }
                let scaledWeight = point.weight / euclideanDistance
                numeratorX += scaledWeight * point.x
                numeratorY += scaledWeight * point.y
                denominator += scaledWeight
            }
            guard denominator > 0 else {
                throw FacilitiesModelError.invalidModel("facility location euclidean iteration failed")
            }
            let next = (x: numeratorX / denominator, y: numeratorY / denominator)
            if hypot(next.x - coordinate.x, next.y - coordinate.y) < 1e-9 {
                return next
            }
            coordinate = next
        }
        return coordinate
    }

    private static func distance(
        from origin: (x: Double, y: Double),
        to destination: (x: Double, y: Double),
        measure: FacilityLocationDistanceMeasure
    ) -> Double {
        let dx = origin.x - destination.x
        let dy = origin.y - destination.y
        switch measure {
        case .rectilinear:
            return abs(dx) + abs(dy)
        case .squaredEuclidean:
            return dx * dx + dy * dy
        case .euclidean:
            return hypot(dx, dy)
        }
    }
}

public enum LineBalancingValidator {
    public static func diagnostics(for problem: LineBalancingProblem) -> [ValidationDiagnostic] {
        var diagnostics: [ValidationDiagnostic] = []

        if problem.tasks.isEmpty {
            diagnostics.append(error(
                "facilities.lineBalancing.tasks.empty",
                "line balancing requires tasks",
                path: "tasks"
            ))
        }
        if problem.cycleTime <= 0 {
            diagnostics.append(error(
                "facilities.lineBalancing.cycleTime.positive",
                "line balancing requires a positive cycle time",
                path: "cycleTime"
            ))
        }
        if problem.tasks.count > 24 {
            diagnostics.append(warning(
                "facilities.lineBalancing.fixtureScale",
                "native educational line-balancing solver currently supports up to 24 tasks",
                path: "tasks"
            ))
        }

        let taskIDs = problem.tasks.map(\.id)
        if Set(taskIDs).count != taskIDs.count {
            diagnostics.append(error(
                "facilities.lineBalancing.tasks.duplicate",
                "line balancing task ids must be unique",
                path: "tasks"
            ))
        }

        let taskIDSet = Set(taskIDs)
        for task in problem.tasks {
            if task.time < 0 || (problem.cycleTime > 0 && task.time > problem.cycleTime) {
                diagnostics.append(error(
                    "facilities.lineBalancing.taskTime.bounds",
                    "task times must be nonnegative and no greater than cycle time",
                    path: "tasks.\(task.id).time"
                ))
            }
            for successorID in task.successorIDs {
                if successorID == task.id {
                    diagnostics.append(error(
                        "facilities.lineBalancing.successors.self",
                        "line balancing tasks cannot list themselves as successors",
                        path: "tasks.\(task.id).successorIDs"
                    ))
                } else if !taskIDSet.contains(successorID) {
                    diagnostics.append(error(
                        "facilities.lineBalancing.successors.missing",
                        "line balancing successor \(successorID) is missing",
                        path: "tasks.\(task.id).successorIDs"
                    ))
                }
            }
        }

        if diagnostics.contains(where: { $0.severity == .error }) == false,
           hasCycle(problem.tasks) {
            diagnostics.append(error(
                "facilities.lineBalancing.precedence.cycle",
                "line balancing precedence relationships must not contain cycles",
                path: "tasks"
            ))
        }

        guard diagnostics.contains(where: { $0.severity == .error }) == false else {
            return diagnostics
        }

        return diagnostics + [
            ValidationDiagnostic(
                severity: .info,
                code: "facilities.lineBalancing.valid",
                message: "Line balancing model is valid"
            )
        ]
    }

    public static func validate(_ problem: LineBalancingProblem) throws {
        if let diagnostic = diagnostics(for: problem).first(where: { $0.severity == .error }) {
            throw FacilitiesModelError.invalidModel(diagnostic.message)
        }
    }

    private static func hasCycle(_ tasks: [LineBalancingTask]) -> Bool {
        let successorsByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.successorIDs) })
        var visiting: Set<Int> = []
        var visited: Set<Int> = []

        func visit(_ taskID: Int) -> Bool {
            if visiting.contains(taskID) {
                return true
            }
            if visited.contains(taskID) {
                return false
            }

            visiting.insert(taskID)
            for successorID in successorsByID[taskID, default: []] where successorsByID[successorID] != nil {
                if visit(successorID) {
                    return true
                }
            }
            visiting.remove(taskID)
            visited.insert(taskID)
            return false
        }

        for task in tasks where visit(task.id) {
            return true
        }
        return false
    }

    private static func error(_ code: String, _ message: String, path: String?) -> ValidationDiagnostic {
        ValidationDiagnostic(severity: .error, code: code, message: message, path: path)
    }

    private static func warning(_ code: String, _ message: String, path: String?) -> ValidationDiagnostic {
        ValidationDiagnostic(severity: .warning, code: code, message: message, path: path)
    }
}

public enum LineBalancingSolver {
    private struct SearchNode {
        let previousMask: Int
        let stationMask: Int
    }

    public static func solve(_ problem: LineBalancingProblem) throws -> LineBalancingSolution {
        try validate(problem)

        let tasks = problem.tasks.sorted { $0.id < $1.id }
        let taskCount = tasks.count
        let fullMask = (1 << taskCount) - 1
        let totalTaskTime = tasks.reduce(0) { $0 + $1.time }
        let predecessors = predecessorMasks(for: tasks)
        var workloadCache: [Int: Int] = [0: 0]
        var parent: [Int: SearchNode] = [:]
        var distance: [Int: Int] = [0: 0]
        var queue = [0]
        var queueIndex = 0

        while queueIndex < queue.count, distance[fullMask] == nil {
            let assignedMask = queue[queueIndex]
            queueIndex += 1

            let stationMasks = feasibleStationMasks(
                assignedMask: assignedMask,
                fullMask: fullMask,
                tasks: tasks,
                predecessors: predecessors,
                cycleTime: problem.cycleTime,
                workloadCache: &workloadCache
            )

            for stationMask in stationMasks {
                let nextMask = assignedMask | stationMask
                guard distance[nextMask] == nil else {
                    continue
                }
                distance[nextMask] = (distance[assignedMask] ?? 0) + 1
                parent[nextMask] = SearchNode(previousMask: assignedMask, stationMask: stationMask)
                queue.append(nextMask)
            }
        }

        guard let stationCount = distance[fullMask] else {
            throw FacilitiesModelError.invalidModel("line balancing problem has no feasible station assignment")
        }

        var masks: [Int] = []
        var currentMask = fullMask
        while currentMask != 0 {
            guard let node = parent[currentMask] else {
                throw FacilitiesModelError.invalidModel("line balancing solution path could not be reconstructed")
            }
            masks.append(node.stationMask)
            currentMask = node.previousMask
        }
        masks.reverse()

        let stations = masks.enumerated().map { offset, mask in
            let stationTasks = tasks.enumerated()
                .filter { mask & (1 << $0.offset) != 0 }
                .map(\.element)
            let workload = stationTasks.reduce(0) { $0 + $1.time }
            return LineBalancingStation(
                index: offset + 1,
                taskIDs: stationTasks.map(\.id),
                taskNames: stationTasks.map(\.name),
                workload: workload,
                idleTime: problem.cycleTime - workload
            )
        }

        let efficiency = Double(totalTaskTime) / Double(stationCount * problem.cycleTime)
        return LineBalancingSolution(
            stationCount: stationCount,
            totalTaskTime: totalTaskTime,
            cycleTime: problem.cycleTime,
            efficiency: efficiency,
            balanceDelay: 1 - efficiency,
            stations: stations
        )
    }

    private static func validate(_ problem: LineBalancingProblem) throws {
        try LineBalancingValidator.validate(problem)
        guard problem.tasks.count <= 24 else {
            throw FacilitiesModelError.invalidModel("exact line balancing solver currently supports up to 24 tasks")
        }
    }

    private static func predecessorMasks(for tasks: [LineBalancingTask]) -> [Int] {
        let indexByID = Dictionary(uniqueKeysWithValues: tasks.enumerated().map { ($0.element.id, $0.offset) })
        var predecessors = Array(repeating: 0, count: tasks.count)
        for task in tasks {
            guard let predecessorIndex = indexByID[task.id] else { continue }
            for successorID in task.successorIDs {
                guard let successorIndex = indexByID[successorID] else { continue }
                predecessors[successorIndex] |= 1 << predecessorIndex
            }
        }
        return predecessors
    }

    private static func feasibleStationMasks(
        assignedMask: Int,
        fullMask: Int,
        tasks: [LineBalancingTask],
        predecessors: [Int],
        cycleTime: Int,
        workloadCache: inout [Int: Int]
    ) -> [Int] {
        let remainingTaskIndices = tasks.indices.filter { assignedMask & (1 << $0) == 0 }
        var candidates: [Int] = []

        func search(_ itemIndex: Int, _ mask: Int, _ workload: Int) {
            guard workload <= cycleTime else {
                return
            }
            if itemIndex == remainingTaskIndices.count {
                guard mask != 0 else { return }
                for taskIndex in tasks.indices where mask & (1 << taskIndex) != 0 {
                    guard predecessors[taskIndex] & ~(assignedMask | mask) == 0 else {
                        return
                    }
                }
                candidates.append(mask)
                workloadCache[mask] = workload
                return
            }

            let taskIndex = remainingTaskIndices[itemIndex]
            search(itemIndex + 1, mask, workload)
            search(itemIndex + 1, mask | (1 << taskIndex), workload + tasks[taskIndex].time)
        }

        search(0, 0, 0)

        let uniqueCandidates = Array(Set(candidates))
        var maximal: [Int] = []
        for candidate in uniqueCandidates.sorted(by: { left, right in
            let leftWorkload = workloadCache[left] ?? 0
            let rightWorkload = workloadCache[right] ?? 0
            if leftWorkload != rightWorkload {
                return leftWorkload > rightWorkload
            }
            return left > right
        }) {
            if !maximal.contains(where: { (candidate | $0) == $0 }) {
                maximal.append(candidate)
            }
        }
        return maximal
    }
}

private struct FacilityLayoutCell: Comparable, Hashable {
    let row: Int
    let column: Int

    static func < (left: FacilityLayoutCell, right: FacilityLayoutCell) -> Bool {
        if left.row != right.row {
            return left.row < right.row
        }
        return left.column < right.column
    }
}

private func layoutCells(in rects: [FacilityLayoutRect]) -> Set<FacilityLayoutCell> {
    var cells: Set<FacilityLayoutCell> = []
    for rect in rects {
        guard rect.startRow <= rect.endRow, rect.startColumn <= rect.endColumn else {
            continue
        }
        for row in rect.startRow...rect.endRow {
            for column in rect.startColumn...rect.endColumn {
                cells.insert(FacilityLayoutCell(row: row, column: column))
            }
        }
    }
    return cells
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
