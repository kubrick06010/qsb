import Foundation

public struct MM1QueueModel: Codable, Equatable, Sendable {
    public let title: String
    public let timeUnit: String
    public let serviceRate: Double
    public let arrivalRate: Double
    public let busyServerCostPerTime: Double?
    public let idleServerCostPerTime: Double?
    public let customerWaitingCostPerTime: Double?
    public let customerBeingServedCostPerTime: Double?

    public init(
        title: String,
        timeUnit: String,
        serviceRate: Double,
        arrivalRate: Double,
        busyServerCostPerTime: Double? = nil,
        idleServerCostPerTime: Double? = nil,
        customerWaitingCostPerTime: Double? = nil,
        customerBeingServedCostPerTime: Double? = nil
    ) {
        self.title = title
        self.timeUnit = timeUnit
        self.serviceRate = serviceRate
        self.arrivalRate = arrivalRate
        self.busyServerCostPerTime = busyServerCostPerTime
        self.idleServerCostPerTime = idleServerCostPerTime
        self.customerWaitingCostPerTime = customerWaitingCostPerTime
        self.customerBeingServedCostPerTime = customerBeingServedCostPerTime
    }
}

public struct MM1QueueCostBreakdown: Codable, Equatable, Sendable {
    public let busyServerCost: Double
    public let idleServerCost: Double
    public let customerWaitingCost: Double
    public let customerBeingServedCost: Double
    public let totalCost: Double
}

public struct MM1QueueSolution: Codable, Equatable, Sendable {
    public let utilization: Double
    public let probabilitySystemEmpty: Double
    public let averageNumberInSystem: Double
    public let averageNumberInQueue: Double
    public let averageTimeInSystem: Double
    public let averageTimeInQueue: Double
    public let cost: MM1QueueCostBreakdown?
}

public struct FiniteCapacityQueueModel: Codable, Equatable, Sendable {
    public let title: String
    public let timeUnit: String
    public let servers: Int
    public let serviceDistribution: String
    public let meanServiceTime: Double
    public let serviceTimeStandardDeviation: Double?
    public let interarrivalDistribution: String
    public let meanInterarrivalTime: Double
    public let batchSize: Int
    public let queueCapacity: Int
    public let busyServerCostPerTime: Double?
    public let idleServerCostPerTime: Double?
    public let customerWaitingCostPerTime: Double?
    public let customerBeingServedCostPerTime: Double?
    public let balkedCustomerCost: Double?
    public let queueCapacityCostPerSlot: Double?

    public init(
        title: String,
        timeUnit: String,
        servers: Int,
        serviceDistribution: String,
        meanServiceTime: Double,
        serviceTimeStandardDeviation: Double? = nil,
        interarrivalDistribution: String,
        meanInterarrivalTime: Double,
        batchSize: Int,
        queueCapacity: Int,
        busyServerCostPerTime: Double? = nil,
        idleServerCostPerTime: Double? = nil,
        customerWaitingCostPerTime: Double? = nil,
        customerBeingServedCostPerTime: Double? = nil,
        balkedCustomerCost: Double? = nil,
        queueCapacityCostPerSlot: Double? = nil
    ) {
        self.title = title
        self.timeUnit = timeUnit
        self.servers = servers
        self.serviceDistribution = serviceDistribution
        self.meanServiceTime = meanServiceTime
        self.serviceTimeStandardDeviation = serviceTimeStandardDeviation
        self.interarrivalDistribution = interarrivalDistribution
        self.meanInterarrivalTime = meanInterarrivalTime
        self.batchSize = batchSize
        self.queueCapacity = queueCapacity
        self.busyServerCostPerTime = busyServerCostPerTime
        self.idleServerCostPerTime = idleServerCostPerTime
        self.customerWaitingCostPerTime = customerWaitingCostPerTime
        self.customerBeingServedCostPerTime = customerBeingServedCostPerTime
        self.balkedCustomerCost = balkedCustomerCost
        self.queueCapacityCostPerSlot = queueCapacityCostPerSlot
    }
}

public struct FiniteCapacityQueueCostBreakdown: Codable, Equatable, Sendable {
    public let busyServerCost: Double
    public let idleServerCost: Double
    public let customerWaitingCost: Double
    public let customerBeingServedCost: Double
    public let balkedCustomerCost: Double
    public let queueCapacityCost: Double
    public let totalCost: Double
}

public struct FiniteCapacityQueueSolution: Codable, Equatable, Sendable {
    public let arrivalRate: Double
    public let serviceRatePerServer: Double
    public let effectiveArrivalRate: Double
    public let utilization: Double
    public let probabilitySystemEmpty: Double
    public let probabilitySystemFull: Double
    public let averageNumberInSystem: Double
    public let averageNumberInQueue: Double
    public let averageNumberBeingServed: Double
    public let averageTimeInSystem: Double
    public let averageTimeInQueue: Double
    public let stateProbabilities: [Double]
    public let cost: FiniteCapacityQueueCostBreakdown?
}

public enum QueuingProblemKind: String, Codable, Sendable {
    case mm1
    case finiteCapacity
}

public struct QueuingPerformanceMetrics: Codable, Equatable, Sendable {
    public let arrivalRate: Double
    public let effectiveArrivalRate: Double
    public let serviceRatePerServer: Double
    public let servers: Int
    public let systemCapacity: Int?
    public let utilization: Double
    public let probabilitySystemEmpty: Double
    public let blockingProbability: Double
    public let averageNumberInSystem: Double
    public let averageNumberInQueue: Double
    public let averageNumberBeingServed: Double
    public let averageTimeInSystem: Double
    public let averageTimeInQueue: Double

    public init(
        arrivalRate: Double,
        effectiveArrivalRate: Double,
        serviceRatePerServer: Double,
        servers: Int,
        systemCapacity: Int?,
        utilization: Double,
        probabilitySystemEmpty: Double,
        blockingProbability: Double,
        averageNumberInSystem: Double,
        averageNumberInQueue: Double,
        averageNumberBeingServed: Double,
        averageTimeInSystem: Double,
        averageTimeInQueue: Double
    ) {
        self.arrivalRate = arrivalRate
        self.effectiveArrivalRate = effectiveArrivalRate
        self.serviceRatePerServer = serviceRatePerServer
        self.servers = servers
        self.systemCapacity = systemCapacity
        self.utilization = utilization
        self.probabilitySystemEmpty = probabilitySystemEmpty
        self.blockingProbability = blockingProbability
        self.averageNumberInSystem = averageNumberInSystem
        self.averageNumberInQueue = averageNumberInQueue
        self.averageNumberBeingServed = averageNumberBeingServed
        self.averageTimeInSystem = averageTimeInSystem
        self.averageTimeInQueue = averageTimeInQueue
    }
}

public struct QueuingCostMetrics: Codable, Equatable, Sendable {
    public let busyServerCost: Double
    public let idleServerCost: Double
    public let customerWaitingCost: Double
    public let customerBeingServedCost: Double
    public let blockedCustomerCost: Double
    public let capacityCost: Double
    public let totalCost: Double

    public init(
        busyServerCost: Double,
        idleServerCost: Double,
        customerWaitingCost: Double,
        customerBeingServedCost: Double,
        blockedCustomerCost: Double,
        capacityCost: Double,
        totalCost: Double
    ) {
        self.busyServerCost = busyServerCost
        self.idleServerCost = idleServerCost
        self.customerWaitingCost = customerWaitingCost
        self.customerBeingServedCost = customerBeingServedCost
        self.blockedCustomerCost = blockedCustomerCost
        self.capacityCost = capacityCost
        self.totalCost = totalCost
    }
}

public struct QueuingSolutionDocument: Codable, Equatable, Sendable {
    public let kind: QueuingProblemKind
    public let backend: SolverRunMetadata
    public let title: String
    public let timeUnit: String
    public let notation: String
    public let assumptions: [String]
    public let metrics: QueuingPerformanceMetrics
    public let stateProbabilities: [Double]
    public let cost: QueuingCostMetrics?

    public init(
        kind: QueuingProblemKind,
        backend: SolverRunMetadata,
        title: String,
        timeUnit: String,
        notation: String,
        assumptions: [String],
        metrics: QueuingPerformanceMetrics,
        stateProbabilities: [Double],
        cost: QueuingCostMetrics?
    ) {
        self.kind = kind
        self.backend = backend
        self.title = title
        self.timeUnit = timeUnit
        self.notation = notation
        self.assumptions = assumptions
        self.metrics = metrics
        self.stateProbabilities = stateProbabilities
        self.cost = cost
    }
}

public enum QueuingModelError: Error, CustomStringConvertible {
    case unsupportedFormat
    case invalidNumericValue(String)
    case invalidModel(String)

    public var description: String {
        switch self {
        case .unsupportedFormat:
            "Unsupported queuing model format"
        case .invalidNumericValue(let value):
            "Invalid numeric value: \(value)"
        case .invalidModel(let detail):
            "Invalid queuing model: \(detail)"
        }
    }
}

public protocol QueuingBackend: Sendable {
    var capabilities: SolverCapabilities { get }

    func validationReport(for model: MM1QueueModel) -> ValidationReport
    func validationReport(for model: FiniteCapacityQueueModel) -> ValidationReport
    func solve(_ model: MM1QueueModel, options: SolverOptions) throws -> MM1QueueSolution
    func solve(_ model: FiniteCapacityQueueModel, options: SolverOptions) throws -> FiniteCapacityQueueSolution
}

public extension QueuingBackend {
    func validationReport(for model: MM1QueueModel) -> ValidationReport {
        ValidationReport(
            backend: capabilities.backendKind,
            diagnostics: MM1QueueValidator.diagnostics(for: model)
        )
    }

    func validationReport(for model: FiniteCapacityQueueModel) -> ValidationReport {
        ValidationReport(
            backend: capabilities.backendKind,
            diagnostics: FiniteCapacityQueueValidator.diagnostics(for: model)
        )
    }

    func solve(_ model: MM1QueueModel) throws -> MM1QueueSolution {
        try solve(model, options: SolverOptions())
    }

    func solve(_ model: FiniteCapacityQueueModel) throws -> FiniteCapacityQueueSolution {
        try solve(model, options: SolverOptions())
    }
}

public struct NativeEducationalQueuingBackend: QueuingBackend {
    public init() {}

    public var capabilities: SolverCapabilities {
        SolverCapabilities(
            backendKind: .nativeEducational,
            solves: true,
            validates: true,
            exportsStructuredSolution: true,
            notes: [
                "Uses exact M/M/1 closed-form equations.",
                "Uses a finite-state birth-death approximation for finite-capacity multi-server models."
            ]
        )
    }

    public func solve(
        _ model: MM1QueueModel,
        options _: SolverOptions = SolverOptions()
    ) throws -> MM1QueueSolution {
        try MM1QueueSolver.solve(model)
    }

    public func solve(
        _ model: FiniteCapacityQueueModel,
        options _: SolverOptions = SolverOptions()
    ) throws -> FiniteCapacityQueueSolution {
        try FiniteCapacityQueueSolver.solve(model)
    }
}

public struct ValidateOnlyQueuingBackend: QueuingBackend {
    public init() {}

    public var capabilities: SolverCapabilities {
        SolverCapabilities(
            backendKind: .validateOnly,
            solves: false,
            validates: true,
            exportsStructuredSolution: false,
            notes: ["Runs queuing validation without solving the model."]
        )
    }

    public func solve(
        _ model: MM1QueueModel,
        options _: SolverOptions = SolverOptions()
    ) throws -> MM1QueueSolution {
        throw QueuingModelError.invalidModel("validateOnly backend does not solve M/M/1 models")
    }

    public func solve(
        _ model: FiniteCapacityQueueModel,
        options _: SolverOptions = SolverOptions()
    ) throws -> FiniteCapacityQueueSolution {
        throw QueuingModelError.invalidModel("validateOnly backend does not solve finite-capacity models")
    }
}

public enum QueuingBackends {
    public static func backend(for kind: SolverBackendKind) -> (any QueuingBackend)? {
        switch kind {
        case .nativeEducational:
            NativeEducationalQueuingBackend()
        case .validateOnly:
            ValidateOnlyQueuingBackend()
        case .externalHighPerformance:
            nil
        }
    }
}

public enum QueuingSolutionJSON {
    public static func mm1Document(
        model: MM1QueueModel,
        solution: MM1QueueSolution,
        backend: SolverRunMetadata
    ) -> QueuingSolutionDocument {
        let averageNumberBeingServed = solution.averageNumberInSystem - solution.averageNumberInQueue
        return QueuingSolutionDocument(
            kind: .mm1,
            backend: backend,
            title: model.title,
            timeUnit: model.timeUnit,
            notation: "M/M/1",
            assumptions: [
                "Poisson arrivals and exponential service times.",
                "One server, infinite waiting capacity, infinite source population, and steady state."
            ],
            metrics: QueuingPerformanceMetrics(
                arrivalRate: model.arrivalRate,
                effectiveArrivalRate: model.arrivalRate,
                serviceRatePerServer: model.serviceRate,
                servers: 1,
                systemCapacity: nil,
                utilization: solution.utilization,
                probabilitySystemEmpty: solution.probabilitySystemEmpty,
                blockingProbability: 0,
                averageNumberInSystem: solution.averageNumberInSystem,
                averageNumberInQueue: solution.averageNumberInQueue,
                averageNumberBeingServed: averageNumberBeingServed,
                averageTimeInSystem: solution.averageTimeInSystem,
                averageTimeInQueue: solution.averageTimeInQueue
            ),
            stateProbabilities: [],
            cost: solution.cost.map {
                QueuingCostMetrics(
                    busyServerCost: $0.busyServerCost,
                    idleServerCost: $0.idleServerCost,
                    customerWaitingCost: $0.customerWaitingCost,
                    customerBeingServedCost: $0.customerBeingServedCost,
                    blockedCustomerCost: 0,
                    capacityCost: 0,
                    totalCost: $0.totalCost
                )
            }
        )
    }

    public static func finiteCapacityDocument(
        model: FiniteCapacityQueueModel,
        solution: FiniteCapacityQueueSolution,
        backend: SolverRunMetadata
    ) -> QueuingSolutionDocument {
        let serviceCode = model.serviceDistribution.lowercased() == "exponential" ? "M" : "G"
        return QueuingSolutionDocument(
            kind: .finiteCapacity,
            backend: backend,
            title: model.title,
            timeUnit: model.timeUnit,
            notation: "M/\(serviceCode)/\(model.servers)/\(model.servers + model.queueCapacity)",
            assumptions: [
                "Exponential interarrival times, independent customers, and unit batch arrivals.",
                "The native backend reduces service behavior to its mean rate in a finite-state birth-death approximation."
            ],
            metrics: QueuingPerformanceMetrics(
                arrivalRate: solution.arrivalRate,
                effectiveArrivalRate: solution.effectiveArrivalRate,
                serviceRatePerServer: solution.serviceRatePerServer,
                servers: model.servers,
                systemCapacity: model.servers + model.queueCapacity,
                utilization: solution.utilization,
                probabilitySystemEmpty: solution.probabilitySystemEmpty,
                blockingProbability: solution.probabilitySystemFull,
                averageNumberInSystem: solution.averageNumberInSystem,
                averageNumberInQueue: solution.averageNumberInQueue,
                averageNumberBeingServed: solution.averageNumberBeingServed,
                averageTimeInSystem: solution.averageTimeInSystem,
                averageTimeInQueue: solution.averageTimeInQueue
            ),
            stateProbabilities: solution.stateProbabilities,
            cost: solution.cost.map {
                QueuingCostMetrics(
                    busyServerCost: $0.busyServerCost,
                    idleServerCost: $0.idleServerCost,
                    customerWaitingCost: $0.customerWaitingCost,
                    customerBeingServedCost: $0.customerBeingServedCost,
                    blockedCustomerCost: $0.balkedCustomerCost,
                    capacityCost: $0.queueCapacityCost,
                    totalCost: $0.totalCost
                )
            }
        )
    }

    public static func encode(_ document: QueuingSolutionDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }
}

public enum WinQSBQueuingParser {
    public static func parseMM1(from data: Data) throws -> MM1QueueModel {
        let (metadata, entries) = try parseEntryTable(from: data)
        guard metadata.count >= 4,
              metadata[0] == "QA",
              metadata[3] == "0"
        else {
            throw QueuingModelError.unsupportedFormat
        }

        let servers = try requiredDouble(entries, "number of servers")
        guard abs(servers - 1) < 1e-8 else {
            throw QueuingModelError.invalidModel("only M/M/1 queues are currently supported")
        }
        guard try optionalDouble(entries["queue capacity (maximum waiting space)"]) == nil,
              try optionalDouble(entries["customer population"]) == nil
        else {
            throw QueuingModelError.invalidModel("only infinite-capacity, infinite-population M/M/1 queues are currently supported")
        }

        return MM1QueueModel(
            title: metadata[1],
            timeUnit: metadata[2],
            serviceRate: try requiredDouble(entries, "service rate (per server per hour)"),
            arrivalRate: try requiredDouble(entries, "customer arrival rate (per hour)"),
            busyServerCostPerTime: try optionalDouble(entries["busy server cost per hour"]),
            idleServerCostPerTime: try optionalDouble(entries["idle server cost per hour"]),
            customerWaitingCostPerTime: try optionalDouble(entries["customer waiting cost per hour"]),
            customerBeingServedCostPerTime: try optionalDouble(entries["customer being served cost per hour"])
        )
    }

    public static func parseFiniteCapacity(from data: Data) throws -> FiniteCapacityQueueModel {
        let (metadata, entries) = try parseEntryTable(from: data)
        guard metadata.count >= 4,
              metadata[0] == "QA",
              metadata[3] == "1"
        else {
            throw QueuingModelError.unsupportedFormat
        }

        let serviceDistribution = entries["service time distribution (in \(metadata[2]))"] ?? ""
        let interarrivalDistribution = entries["interarrival time distribution (in \(metadata[2]))"] ?? ""
        let batchDistribution = entries["batch (bulk) size distribution"] ?? ""
        guard batchDistribution.lowercased() == "constant" else {
            throw QueuingModelError.invalidModel("only constant queue batch sizes are currently supported")
        }

        let customerPopulation = try optionalDouble(entries["customer population"])
        guard customerPopulation == nil else {
            throw QueuingModelError.invalidModel("finite customer populations are not yet supported")
        }

        return FiniteCapacityQueueModel(
            title: metadata[1],
            timeUnit: metadata[2],
            servers: try requiredInt(entries, "number of servers"),
            serviceDistribution: serviceDistribution,
            meanServiceTime: try requiredDouble(entries, "mean (u)"),
            serviceTimeStandardDeviation: try optionalDouble(entries["standard deviation (s>0)"]),
            interarrivalDistribution: interarrivalDistribution,
            meanInterarrivalTime: try requiredDouble(entries, "scale parameter (b>0) (b=mean if a=0)"),
            batchSize: try requiredInt(entries, "constant value"),
            queueCapacity: try requiredInt(entries, "queue capacity (maximum waiting space)"),
            busyServerCostPerTime: try optionalDouble(entries["busy server cost per \(metadata[2])"]),
            idleServerCostPerTime: try optionalDouble(entries["idle server cost per \(metadata[2])"]),
            customerWaitingCostPerTime: try optionalDouble(entries["customer waiting cost per \(metadata[2])"]),
            customerBeingServedCostPerTime: try optionalDouble(entries["customer being served cost per \(metadata[2])"]),
            balkedCustomerCost: try optionalDouble(entries["cost of customer being balked"]),
            queueCapacityCostPerSlot: try optionalDouble(entries["unit queue capacity cost"])
        )
    }

    private static func parseEntryTable(from data: Data) throws -> ([String], [String: String]) {
        guard let text = String(data: data, encoding: .isoLatin1) else {
            throw QueuingModelError.unsupportedFormat
        }

        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(clean) }

        guard let metadata = lines.first, metadata.count >= 4 else {
            throw QueuingModelError.unsupportedFormat
        }

        var entries: [String: String] = [:]
        for row in lines.dropFirst(2) where row.count >= 2 {
            entries[row[0].lowercased()] = row[1]
        }
        return (metadata, entries)
    }

    private static func requiredDouble(_ entries: [String: String], _ key: String) throws -> Double {
        guard let value = entries[key] else {
            throw QueuingModelError.unsupportedFormat
        }
        guard let number = try optionalDouble(value) else {
            throw QueuingModelError.invalidNumericValue(value)
        }
        return number
    }

    private static func requiredInt(_ entries: [String: String], _ key: String) throws -> Int {
        let number = try requiredDouble(entries, key)
        let rounded = number.rounded()
        guard abs(number - rounded) < 1e-8 else {
            throw QueuingModelError.invalidModel("\(key) must be an integer")
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
            throw QueuingModelError.invalidNumericValue(value)
        }
        return number
    }

    private static func clean(_ value: Substring) -> String {
        String(value).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum MM1QueueValidator {
    public static func diagnostics(for model: MM1QueueModel) -> [ValidationDiagnostic] {
        var diagnostics: [ValidationDiagnostic] = []

        if !model.serviceRate.isFinite || model.serviceRate <= 0 {
            diagnostics.append(queueError(
                "queuing.mm1.serviceRate",
                "service rate must be finite and positive",
                path: "serviceRate"
            ))
        }
        if !model.arrivalRate.isFinite || model.arrivalRate < 0 {
            diagnostics.append(queueError(
                "queuing.mm1.arrivalRate",
                "arrival rate must be finite and nonnegative",
                path: "arrivalRate"
            ))
        } else if model.serviceRate.isFinite,
                  model.serviceRate > 0,
                  model.arrivalRate >= model.serviceRate {
            diagnostics.append(queueError(
                "queuing.mm1.unstable",
                "M/M/1 queue is unstable because arrival rate must be less than service rate",
                path: "arrivalRate"
            ))
        }

        appendQueueCostDiagnostics([
            ("busyServerCostPerTime", model.busyServerCostPerTime),
            ("idleServerCostPerTime", model.idleServerCostPerTime),
            ("customerWaitingCostPerTime", model.customerWaitingCostPerTime),
            ("customerBeingServedCostPerTime", model.customerBeingServedCostPerTime)
        ], family: "mm1", diagnostics: &diagnostics)

        if model.timeUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            diagnostics.append(queueWarning(
                "queuing.mm1.timeUnit.empty",
                "time unit is empty",
                path: "timeUnit"
            ))
        }

        return finalizedQueueDiagnostics(
            diagnostics,
            validCode: "queuing.mm1.valid",
            validMessage: "M/M/1 queue model is valid"
        )
    }

    public static func validate(_ model: MM1QueueModel) throws {
        if let diagnostic = diagnostics(for: model).first(where: { $0.severity == .error }) {
            throw QueuingModelError.invalidModel(diagnostic.message)
        }
    }
}

public enum FiniteCapacityQueueValidator {
    public static func diagnostics(for model: FiniteCapacityQueueModel) -> [ValidationDiagnostic] {
        var diagnostics: [ValidationDiagnostic] = []

        if model.servers <= 0 {
            diagnostics.append(queueError(
                "queuing.finiteCapacity.servers",
                "server count must be positive",
                path: "servers"
            ))
        }
        if !model.meanServiceTime.isFinite || model.meanServiceTime <= 0 {
            diagnostics.append(queueError(
                "queuing.finiteCapacity.meanServiceTime",
                "mean service time must be finite and positive",
                path: "meanServiceTime"
            ))
        }
        if !model.meanInterarrivalTime.isFinite || model.meanInterarrivalTime <= 0 {
            diagnostics.append(queueError(
                "queuing.finiteCapacity.meanInterarrivalTime",
                "mean interarrival time must be finite and positive",
                path: "meanInterarrivalTime"
            ))
        }
        if let standardDeviation = model.serviceTimeStandardDeviation,
           !standardDeviation.isFinite || standardDeviation < 0 {
            diagnostics.append(queueError(
                "queuing.finiteCapacity.serviceTimeStandardDeviation",
                "service-time standard deviation must be finite and nonnegative",
                path: "serviceTimeStandardDeviation"
            ))
        }
        if model.batchSize != 1 {
            diagnostics.append(queueError(
                "queuing.finiteCapacity.batchSize",
                "native finite-capacity solver currently requires unit batch arrivals",
                path: "batchSize"
            ))
        }
        if model.queueCapacity < 0 {
            diagnostics.append(queueError(
                "queuing.finiteCapacity.queueCapacity",
                "queue capacity must be nonnegative",
                path: "queueCapacity"
            ))
        }
        if model.interarrivalDistribution.lowercased() != "exponential" {
            diagnostics.append(queueError(
                "queuing.finiteCapacity.interarrivalDistribution",
                "native finite-capacity solver currently requires exponential interarrival times",
                path: "interarrivalDistribution"
            ))
        }
        if model.serviceDistribution.lowercased() != "exponential" {
            diagnostics.append(queueWarning(
                "queuing.finiteCapacity.serviceApproximation",
                "native solver approximates the service distribution using its mean rate",
                path: "serviceDistribution"
            ))
        }

        appendQueueCostDiagnostics([
            ("busyServerCostPerTime", model.busyServerCostPerTime),
            ("idleServerCostPerTime", model.idleServerCostPerTime),
            ("customerWaitingCostPerTime", model.customerWaitingCostPerTime),
            ("customerBeingServedCostPerTime", model.customerBeingServedCostPerTime),
            ("balkedCustomerCost", model.balkedCustomerCost),
            ("queueCapacityCostPerSlot", model.queueCapacityCostPerSlot)
        ], family: "finiteCapacity", diagnostics: &diagnostics)

        if model.servers > 0,
           model.meanServiceTime.isFinite,
           model.meanServiceTime > 0,
           model.meanInterarrivalTime.isFinite,
           model.meanInterarrivalTime > 0 {
            let offeredUtilization = model.meanServiceTime / (model.meanInterarrivalTime * Double(model.servers))
            if offeredUtilization >= 1 {
                diagnostics.append(queueWarning(
                    "queuing.finiteCapacity.saturatedOfferedLoad",
                    "offered load is at least total service capacity; finite capacity prevents instability but blocking may be substantial",
                    path: "meanInterarrivalTime"
                ))
            }
        }

        return finalizedQueueDiagnostics(
            diagnostics,
            validCode: "queuing.finiteCapacity.valid",
            validMessage: "Finite-capacity queue model is valid"
        )
    }

    public static func validate(_ model: FiniteCapacityQueueModel) throws {
        if let diagnostic = diagnostics(for: model).first(where: { $0.severity == .error }) {
            throw QueuingModelError.invalidModel(diagnostic.message)
        }
    }
}

private func appendQueueCostDiagnostics(
    _ costs: [(String, Double?)],
    family: String,
    diagnostics: inout [ValidationDiagnostic]
) {
    for (path, value) in costs {
        if let value, !value.isFinite || value < 0 {
            diagnostics.append(queueError(
                "queuing.\(family).cost",
                "queue costs must be finite and nonnegative",
                path: path
            ))
        }
    }
}

private func finalizedQueueDiagnostics(
    _ diagnostics: [ValidationDiagnostic],
    validCode: String,
    validMessage: String
) -> [ValidationDiagnostic] {
    guard !diagnostics.contains(where: { $0.severity == .error }) else {
        return diagnostics
    }
    return diagnostics + [ValidationDiagnostic(severity: .info, code: validCode, message: validMessage)]
}

private func queueError(_ code: String, _ message: String, path: String? = nil) -> ValidationDiagnostic {
    ValidationDiagnostic(severity: .error, code: code, message: message, path: path)
}

private func queueWarning(_ code: String, _ message: String, path: String? = nil) -> ValidationDiagnostic {
    ValidationDiagnostic(severity: .warning, code: code, message: message, path: path)
}

public enum MM1QueueSolver {
    public static func solve(_ model: MM1QueueModel) throws -> MM1QueueSolution {
        try MM1QueueValidator.validate(model)

        let utilization = model.arrivalRate / model.serviceRate
        let probabilitySystemEmpty = 1 - utilization
        let averageNumberInSystem = model.arrivalRate / (model.serviceRate - model.arrivalRate)
        let averageNumberInQueue = model.arrivalRate * model.arrivalRate
            / (model.serviceRate * (model.serviceRate - model.arrivalRate))
        let averageTimeInSystem = 1 / (model.serviceRate - model.arrivalRate)
        let averageTimeInQueue = model.arrivalRate / (model.serviceRate * (model.serviceRate - model.arrivalRate))
        let averageNumberBeingServed = averageNumberInSystem - averageNumberInQueue

        let cost: MM1QueueCostBreakdown?
        if model.busyServerCostPerTime != nil ||
            model.idleServerCostPerTime != nil ||
            model.customerWaitingCostPerTime != nil ||
            model.customerBeingServedCostPerTime != nil {
            let busyServerCost = utilization * (model.busyServerCostPerTime ?? 0)
            let idleServerCost = probabilitySystemEmpty * (model.idleServerCostPerTime ?? 0)
            let customerWaitingCost = averageNumberInQueue * (model.customerWaitingCostPerTime ?? 0)
            let customerBeingServedCost = averageNumberBeingServed * (model.customerBeingServedCostPerTime ?? 0)
            cost = MM1QueueCostBreakdown(
                busyServerCost: busyServerCost,
                idleServerCost: idleServerCost,
                customerWaitingCost: customerWaitingCost,
                customerBeingServedCost: customerBeingServedCost,
                totalCost: busyServerCost + idleServerCost + customerWaitingCost + customerBeingServedCost
            )
        } else {
            cost = nil
        }

        return MM1QueueSolution(
            utilization: utilization,
            probabilitySystemEmpty: probabilitySystemEmpty,
            averageNumberInSystem: averageNumberInSystem,
            averageNumberInQueue: averageNumberInQueue,
            averageTimeInSystem: averageTimeInSystem,
            averageTimeInQueue: averageTimeInQueue,
            cost: cost
        )
    }

}

public enum FiniteCapacityQueueSolver {
    public static func solve(_ model: FiniteCapacityQueueModel) throws -> FiniteCapacityQueueSolution {
        try FiniteCapacityQueueValidator.validate(model)

        let arrivalRate = 1 / model.meanInterarrivalTime
        let serviceRate = 1 / model.meanServiceTime
        let systemCapacity = model.servers + model.queueCapacity

        var weights = [1.0]
        if systemCapacity > 0 {
            for systemSize in 1...systemCapacity {
                let aggregateServiceRate = Double(min(systemSize, model.servers)) * serviceRate
                weights.append(weights[systemSize - 1] * arrivalRate / aggregateServiceRate)
            }
        }

        let normalizer = weights.reduce(0, +)
        let stateProbabilities = weights.map { $0 / normalizer }
        let probabilitySystemEmpty = stateProbabilities[0]
        let probabilitySystemFull = stateProbabilities[systemCapacity]
        let effectiveArrivalRate = arrivalRate * (1 - probabilitySystemFull)

        let averageNumberInSystem = stateProbabilities.enumerated().reduce(0.0) { partial, pair in
            partial + Double(pair.offset) * pair.element
        }
        let averageNumberInQueue = stateProbabilities.enumerated().reduce(0.0) { partial, pair in
            partial + Double(max(0, pair.offset - model.servers)) * pair.element
        }
        let averageNumberBeingServed = averageNumberInSystem - averageNumberInQueue
        let utilization = averageNumberBeingServed / Double(model.servers)
        let averageTimeInSystem = effectiveArrivalRate > 1e-12
            ? averageNumberInSystem / effectiveArrivalRate
            : 0
        let averageTimeInQueue = effectiveArrivalRate > 1e-12
            ? averageNumberInQueue / effectiveArrivalRate
            : 0

        let cost: FiniteCapacityQueueCostBreakdown?
        if model.busyServerCostPerTime != nil ||
            model.idleServerCostPerTime != nil ||
            model.customerWaitingCostPerTime != nil ||
            model.customerBeingServedCostPerTime != nil ||
            model.balkedCustomerCost != nil ||
            model.queueCapacityCostPerSlot != nil {
            let busyServerCost = averageNumberBeingServed * (model.busyServerCostPerTime ?? 0)
            let idleServerCost = (Double(model.servers) - averageNumberBeingServed) * (model.idleServerCostPerTime ?? 0)
            let customerWaitingCost = averageNumberInQueue * (model.customerWaitingCostPerTime ?? 0)
            let customerBeingServedCost = averageNumberBeingServed * (model.customerBeingServedCostPerTime ?? 0)
            let balkedCustomerCost = arrivalRate * probabilitySystemFull * (model.balkedCustomerCost ?? 0)
            let queueCapacityCost = Double(model.queueCapacity) * (model.queueCapacityCostPerSlot ?? 0)
            cost = FiniteCapacityQueueCostBreakdown(
                busyServerCost: busyServerCost,
                idleServerCost: idleServerCost,
                customerWaitingCost: customerWaitingCost,
                customerBeingServedCost: customerBeingServedCost,
                balkedCustomerCost: balkedCustomerCost,
                queueCapacityCost: queueCapacityCost,
                totalCost: busyServerCost
                    + idleServerCost
                    + customerWaitingCost
                    + customerBeingServedCost
                    + balkedCustomerCost
                    + queueCapacityCost
            )
        } else {
            cost = nil
        }

        return FiniteCapacityQueueSolution(
            arrivalRate: arrivalRate,
            serviceRatePerServer: serviceRate,
            effectiveArrivalRate: effectiveArrivalRate,
            utilization: utilization,
            probabilitySystemEmpty: probabilitySystemEmpty,
            probabilitySystemFull: probabilitySystemFull,
            averageNumberInSystem: averageNumberInSystem,
            averageNumberInQueue: averageNumberInQueue,
            averageNumberBeingServed: averageNumberBeingServed,
            averageTimeInSystem: averageTimeInSystem,
            averageTimeInQueue: averageTimeInQueue,
            stateProbabilities: stateProbabilities,
            cost: cost
        )
    }

}
