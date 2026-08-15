import Foundation
import QSBCore

struct TransportationSourceDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var supply: String

    init(id: UUID = UUID(), name: String, supply: String) {
        self.id = id
        self.name = name
        self.supply = supply
    }
}

struct TransportationDestinationDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var demand: String

    init(id: UUID = UUID(), name: String, demand: String) {
        self.id = id
        self.name = name
        self.demand = demand
    }
}

enum TransportationDraftIssue: Equatable, Sendable {
    case emptyTitle
    case emptySourceName(UUID)
    case emptyDestinationName(UUID)
    case invalidSupply(UUID)
    case invalidDemand(UUID)
    case invalidCost(UUID, UUID)
    case inconsistentDimensions

    var message: String {
        switch self {
        case .emptyTitle: "Model title must not be empty."
        case .emptySourceName: "Origin names must not be empty."
        case .emptyDestinationName: "Destination names must not be empty."
        case .invalidSupply: "Enter a finite numeric supply value."
        case .invalidDemand: "Enter a finite numeric demand value."
        case .invalidCost: "Enter a finite numeric transportation cost."
        case .inconsistentDimensions: "The transportation matrix and quantity vectors are inconsistent."
        }
    }
}

enum TransportationDraftError: Error, Equatable, CustomStringConvertible {
    case issues([TransportationDraftIssue])

    var issues: [TransportationDraftIssue] {
        if case .issues(let value) = self { return value }
        return []
    }

    var description: String {
        switch self {
        case .issues(let issues): issues.map(\.message).joined(separator: " ")
        }
    }
}

struct TransportationDraft: Equatable, Sendable {
    var title: String
    var sources: [TransportationSourceDraft]
    var destinations: [TransportationDestinationDraft]
    var costs: [[String]]

    init(
        title: String = "New Transportation",
        sources: [TransportationSourceDraft],
        destinations: [TransportationDestinationDraft],
        costs: [[String]]
    ) {
        self.title = title
        self.sources = sources
        self.destinations = destinations
        self.costs = costs
    }

    static func blank() -> Self {
        Self(
            sources: [TransportationSourceDraft(name: "Origin 1", supply: "0"), TransportationSourceDraft(name: "Origin 2", supply: "0")],
            destinations: [TransportationDestinationDraft(name: "Destination 1", demand: "0"), TransportationDestinationDraft(name: "Destination 2", demand: "0")],
            costs: Array(repeating: Array(repeating: "0", count: 2), count: 2)
        )
    }

    init(model: TransportationProblem) {
        title = model.title
        sources = zip(model.origins, model.supply).map { TransportationSourceDraft(name: $0.0, supply: String($0.1)) }
        destinations = zip(model.destinations, model.demand).map { TransportationDestinationDraft(name: $0.0, demand: String($0.1)) }
        costs = model.costs.map { $0.map { String($0) } }
    }

    init?(envelope: NetworkModelEnvelope) {
        guard case .transportation(let model) = envelope else { return nil }
        self.init(model: model)
    }

    func draftIssues() -> [TransportationDraftIssue] {
        var issues: [TransportationDraftIssue] = []
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append(.emptyTitle) }
        for source in sources where source.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append(.emptySourceName(source.id)) }
        for destination in destinations where destination.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append(.emptyDestinationName(destination.id)) }
        for source in sources where parseFinite(source.supply) == nil { issues.append(.invalidSupply(source.id)) }
        for destination in destinations where parseFinite(destination.demand) == nil { issues.append(.invalidDemand(destination.id)) }
        guard costs.count == sources.count, costs.allSatisfy({ $0.count == destinations.count }) else {
            issues.append(.inconsistentDimensions)
            return issues
        }
        for (rowIndex, source) in sources.enumerated() {
            for (columnIndex, destination) in destinations.enumerated() where parseFinite(costs[rowIndex][columnIndex]) == nil {
                issues.append(.invalidCost(source.id, destination.id))
            }
        }
        return issues
    }

    func makeModel() throws -> TransportationProblem {
        let issues = draftIssues()
        guard issues.isEmpty else { throw TransportationDraftError.issues(issues) }
        return TransportationProblem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            origins: sources.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) },
            destinations: destinations.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) },
            costs: costs.map { $0.compactMap(parseFinite) },
            supply: sources.compactMap { parseFinite($0.supply) },
            demand: destinations.compactMap { parseFinite($0.demand) }
        )
    }

    @discardableResult
    mutating func addSource(name: String? = nil, supply: String = "0") -> UUID {
        let source = TransportationSourceDraft(name: name ?? "Origin \(sources.count + 1)", supply: supply)
        sources.append(source)
        costs.append(Array(repeating: "0", count: destinations.count))
        return source.id
    }

    mutating func removeSource(at index: Int) {
        guard sources.indices.contains(index) else { return }
        sources.remove(at: index)
        if costs.indices.contains(index) { costs.remove(at: index) }
    }

    @discardableResult
    mutating func addDestination(name: String? = nil, demand: String = "0") -> UUID {
        let destination = TransportationDestinationDraft(name: name ?? "Destination \(destinations.count + 1)", demand: demand)
        destinations.append(destination)
        for index in costs.indices { costs[index].append("0") }
        return destination.id
    }

    mutating func removeDestination(at index: Int) {
        guard destinations.indices.contains(index) else { return }
        destinations.remove(at: index)
        for row in costs.indices where costs[row].indices.contains(index) { costs[row].remove(at: index) }
    }

    private func parseFinite(_ text: String) -> Double? {
        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)), value.isFinite else { return nil }
        return value
    }
}
