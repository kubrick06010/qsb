import Foundation
import QSBCore

enum QueuingDraftError: Error, Equatable, CustomStringConvertible {
    case emptyTitle
    case invalidNumber(path: String, value: String)
    case invalidInteger(path: String, value: String)
    case emptyDistribution(path: String)

    var path: String {
        switch self {
        case .emptyTitle: "title"
        case .invalidNumber(let path, _), .invalidInteger(let path, _), .emptyDistribution(let path): path
        }
    }

    var description: String {
        switch self {
        case .emptyTitle:
            "Enter a model title."
        case .invalidNumber(let path, let value):
            "Enter a finite number for \(path) (received ‘\(value)’)."
        case .invalidInteger(let path, let value):
            "Enter a whole number for \(path) (received ‘\(value)’)."
        case .emptyDistribution(let path):
            "Enter a distribution name for \(path)."
        }
    }
}

struct MM1QueueDraft: Equatable, Sendable {
    var title: String
    var timeUnit: String
    var serviceRate: String
    var arrivalRate: String
    var busyServerCostPerTime: String
    var idleServerCostPerTime: String
    var customerWaitingCostPerTime: String
    var customerBeingServedCostPerTime: String

    init(
        title: String = "New M/M/1 Queue",
        timeUnit: String = "hour",
        serviceRate: String = "3",
        arrivalRate: String = "2",
        busyServerCostPerTime: String = "",
        idleServerCostPerTime: String = "",
        customerWaitingCostPerTime: String = "",
        customerBeingServedCostPerTime: String = ""
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

    init(_ model: MM1QueueModel) {
        title = model.title
        timeUnit = model.timeUnit
        serviceRate = Self.format(model.serviceRate)
        arrivalRate = Self.format(model.arrivalRate)
        busyServerCostPerTime = model.busyServerCostPerTime.map(Self.format) ?? ""
        idleServerCostPerTime = model.idleServerCostPerTime.map(Self.format) ?? ""
        customerWaitingCostPerTime = model.customerWaitingCostPerTime.map(Self.format) ?? ""
        customerBeingServedCostPerTime = model.customerBeingServedCostPerTime.map(Self.format) ?? ""
    }

    func makeModel() throws -> MM1QueueModel {
        MM1QueueModel(
            title: try Self.title(title),
            timeUnit: timeUnit,
            serviceRate: try Self.number(serviceRate, path: "serviceRate"),
            arrivalRate: try Self.number(arrivalRate, path: "arrivalRate"),
            busyServerCostPerTime: try Self.optionalNumber(busyServerCostPerTime, path: "busyServerCostPerTime"),
            idleServerCostPerTime: try Self.optionalNumber(idleServerCostPerTime, path: "idleServerCostPerTime"),
            customerWaitingCostPerTime: try Self.optionalNumber(customerWaitingCostPerTime, path: "customerWaitingCostPerTime"),
            customerBeingServedCostPerTime: try Self.optionalNumber(customerBeingServedCostPerTime, path: "customerBeingServedCostPerTime")
        )
    }

    private static func title(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw QueuingDraftError.emptyTitle }
        return trimmed
    }

    private static func number(_ value: String, path: String) throws -> Double {
        guard let number = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)), number.isFinite else {
            throw QueuingDraftError.invalidNumber(path: path, value: value)
        }
        return number
    }

    private static func optionalNumber(_ value: String, path: String) throws -> Double? {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : try number(value, path: path)
    }

    fileprivate static func format(_ value: Double) -> String {
        let rounded = value.rounded()
        return abs(value - rounded) < 1e-10 ? String(Int(rounded)) : String(format: "%.6g", value)
    }
}

struct FiniteCapacityQueueDraft: Equatable, Sendable {
    var title: String
    var timeUnit: String
    var servers: String
    var serviceDistribution: String
    var meanServiceTime: String
    var serviceTimeStandardDeviation: String
    var interarrivalDistribution: String
    var meanInterarrivalTime: String
    var batchSize: String
    var queueCapacity: String
    var busyServerCostPerTime: String
    var idleServerCostPerTime: String
    var customerWaitingCostPerTime: String
    var customerBeingServedCostPerTime: String
    var balkedCustomerCost: String
    var queueCapacityCostPerSlot: String

    init(
        title: String = "New Finite-Capacity Queue",
        timeUnit: String = "hour",
        servers: String = "2",
        serviceDistribution: String = "Exponential",
        meanServiceTime: String = "0.5",
        serviceTimeStandardDeviation: String = "",
        interarrivalDistribution: String = "Exponential",
        meanInterarrivalTime: String = "0.5",
        batchSize: String = "1",
        queueCapacity: String = "3",
        busyServerCostPerTime: String = "",
        idleServerCostPerTime: String = "",
        customerWaitingCostPerTime: String = "",
        customerBeingServedCostPerTime: String = "",
        balkedCustomerCost: String = "",
        queueCapacityCostPerSlot: String = ""
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

    init(_ model: FiniteCapacityQueueModel) {
        title = model.title
        timeUnit = model.timeUnit
        servers = String(model.servers)
        serviceDistribution = model.serviceDistribution
        meanServiceTime = Self.format(model.meanServiceTime)
        serviceTimeStandardDeviation = model.serviceTimeStandardDeviation.map(Self.format) ?? ""
        interarrivalDistribution = model.interarrivalDistribution
        meanInterarrivalTime = Self.format(model.meanInterarrivalTime)
        batchSize = String(model.batchSize)
        queueCapacity = String(model.queueCapacity)
        busyServerCostPerTime = model.busyServerCostPerTime.map(Self.format) ?? ""
        idleServerCostPerTime = model.idleServerCostPerTime.map(Self.format) ?? ""
        customerWaitingCostPerTime = model.customerWaitingCostPerTime.map(Self.format) ?? ""
        customerBeingServedCostPerTime = model.customerBeingServedCostPerTime.map(Self.format) ?? ""
        balkedCustomerCost = model.balkedCustomerCost.map(Self.format) ?? ""
        queueCapacityCostPerSlot = model.queueCapacityCostPerSlot.map(Self.format) ?? ""
    }

    func makeModel() throws -> FiniteCapacityQueueModel {
        let serviceDistribution = try Self.distribution(serviceDistribution, path: "serviceDistribution")
        let interarrivalDistribution = try Self.distribution(interarrivalDistribution, path: "interarrivalDistribution")
        return FiniteCapacityQueueModel(
            title: try Self.title(title),
            timeUnit: timeUnit,
            servers: try Self.integer(servers, path: "servers"),
            serviceDistribution: serviceDistribution,
            meanServiceTime: try Self.number(meanServiceTime, path: "meanServiceTime"),
            serviceTimeStandardDeviation: try Self.optionalNumber(serviceTimeStandardDeviation, path: "serviceTimeStandardDeviation"),
            interarrivalDistribution: interarrivalDistribution,
            meanInterarrivalTime: try Self.number(meanInterarrivalTime, path: "meanInterarrivalTime"),
            batchSize: try Self.integer(batchSize, path: "batchSize"),
            queueCapacity: try Self.integer(queueCapacity, path: "queueCapacity"),
            busyServerCostPerTime: try Self.optionalNumber(busyServerCostPerTime, path: "busyServerCostPerTime"),
            idleServerCostPerTime: try Self.optionalNumber(idleServerCostPerTime, path: "idleServerCostPerTime"),
            customerWaitingCostPerTime: try Self.optionalNumber(customerWaitingCostPerTime, path: "customerWaitingCostPerTime"),
            customerBeingServedCostPerTime: try Self.optionalNumber(customerBeingServedCostPerTime, path: "customerBeingServedCostPerTime"),
            balkedCustomerCost: try Self.optionalNumber(balkedCustomerCost, path: "balkedCustomerCost"),
            queueCapacityCostPerSlot: try Self.optionalNumber(queueCapacityCostPerSlot, path: "queueCapacityCostPerSlot")
        )
    }

    private static func title(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw QueuingDraftError.emptyTitle }
        return trimmed
    }

    private static func distribution(_ value: String, path: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw QueuingDraftError.emptyDistribution(path: path) }
        return trimmed
    }

    private static func number(_ value: String, path: String) throws -> Double {
        guard let number = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)), number.isFinite else {
            throw QueuingDraftError.invalidNumber(path: path, value: value)
        }
        return number
    }

    private static func optionalNumber(_ value: String, path: String) throws -> Double? {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : try number(value, path: path)
    }

    private static func integer(_ value: String, path: String) throws -> Int {
        let number = try number(value, path: path)
        let rounded = number.rounded()
        guard abs(number - rounded) < 1e-8 else { throw QueuingDraftError.invalidInteger(path: path, value: value) }
        return Int(rounded)
    }

    fileprivate static func format(_ value: Double) -> String {
        let rounded = value.rounded()
        return abs(value - rounded) < 1e-10 ? String(Int(rounded)) : String(format: "%.6g", value)
    }
}

enum QueuingDraft: Equatable, Sendable {
    case mm1(MM1QueueDraft)
    case finiteCapacity(FiniteCapacityQueueDraft)

    static func blank(_ kind: QueuingProblemKind) -> Self {
        switch kind {
        case .mm1: .mm1(MM1QueueDraft())
        case .finiteCapacity: .finiteCapacity(FiniteCapacityQueueDraft())
        }
    }

    init(_ envelope: QueuingModelEnvelope) {
        switch envelope {
        case .mm1(let model): self = .mm1(MM1QueueDraft(model))
        case .finiteCapacity(let model): self = .finiteCapacity(FiniteCapacityQueueDraft(model))
        }
    }

    var kind: QueuingProblemKind {
        switch self {
        case .mm1: .mm1
        case .finiteCapacity: .finiteCapacity
        }
    }

    func makeModel() throws -> QueuingModelEnvelope {
        switch self {
        case .mm1(let draft): .mm1(try draft.makeModel())
        case .finiteCapacity(let draft): .finiteCapacity(try draft.makeModel())
        }
    }

    func draftDiagnostics() -> [ValidationDiagnostic] {
        do {
            let model = try makeModel()
            switch model {
            case .mm1(let queue): return MM1QueueValidator.diagnostics(for: queue)
            case .finiteCapacity(let queue): return FiniteCapacityQueueValidator.diagnostics(for: queue)
            }
        } catch let error as QueuingDraftError {
            return [ValidationDiagnostic(
                severity: .error,
                code: "queuing.draft.\(error.path.replacingOccurrences(of: ".", with: "_"))",
                message: error.description,
                path: error.path
            )]
        } catch {
            return [ValidationDiagnostic(severity: .error, code: "queuing.draft.invalid", message: error.localizedDescription)]
        }
    }

    mutating func setKind(_ kind: QueuingProblemKind) {
        guard self.kind != kind else { return }
        self = .blank(kind)
    }

    mutating func updateMM1(_ update: (inout MM1QueueDraft) -> Void) {
        guard case .mm1(var draft) = self else { return }
        update(&draft)
        self = .mm1(draft)
    }

    mutating func updateFiniteCapacity(_ update: (inout FiniteCapacityQueueDraft) -> Void) {
        guard case .finiteCapacity(var draft) = self else { return }
        update(&draft)
        self = .finiteCapacity(draft)
    }
}

extension QueuingProblemKind {
    var displayName: String {
        switch self {
        case .mm1: "M/M/1 Queue"
        case .finiteCapacity: "Finite-Capacity Queue"
        }
    }
}
