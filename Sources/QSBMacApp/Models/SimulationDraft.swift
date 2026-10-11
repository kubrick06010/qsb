import Foundation
import QSBCore

enum SimulationDraftError: Error, Equatable, CustomStringConvertible {
    case emptyField(path: String, label: String)
    case invalidNumber(path: String, label: String, value: String)
    case invalidInteger(path: String, label: String, value: String)

    var path: String {
        switch self {
        case .emptyField(let path, _), .invalidNumber(let path, _, _), .invalidInteger(let path, _, _): path
        }
    }

    var description: String {
        switch self {
        case .emptyField(_, let label): "Enter \(label)."
        case .invalidNumber(_, let label, let value): "Enter a finite number for \(label) (received ‘\(value)’)."
        case .invalidInteger(_, let label, let value): "Enter a whole number for \(label) (received ‘\(value)’)."
        }
    }
}

struct SimulationDistributionDraft: Equatable, Sendable {
    var kind: SimulationDistributionKind
    var parameters: [String]

    init(kind: SimulationDistributionKind, parameters: [String]? = nil) {
        self.kind = kind
        self.parameters = parameters ?? Self.defaultParameters(for: kind)
    }

    init(_ distribution: SimulationDistribution) {
        kind = distribution.kind
        parameters = distribution.parameters.map { String($0) }
    }

    mutating func changeKind(to newKind: SimulationDistributionKind) {
        guard kind != newKind else { return }
        kind = newKind
        parameters = Self.defaultParameters(for: newKind)
    }

    static func defaultParameters(for kind: SimulationDistributionKind) -> [String] {
        switch kind {
        case .constant, .exponential: ["1"]
        case .normal: ["0", "1"]
        case .uniform: ["0", "1"]
        case .triangular: ["0", "0.5", "1"]
        }
    }

    var parameterLabels: [String] {
        switch kind {
        case .constant: ["Value"]
        case .exponential: parameters.count > 1 ? ["Offset", "Mean"] : ["Mean"]
        case .normal: ["Mean", "Standard deviation"]
        case .uniform: ["Minimum", "Maximum"]
        case .triangular: ["Minimum", "Mode", "Maximum"]
        }
    }
}

struct SimulationRouteDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var target: String
    var probability: String
    var transferTime: String

    init(id: UUID = UUID(), target: String, probability: String = "1", transferTime: String = "0") {
        self.id = id; self.target = target; self.probability = probability; self.transferTime = transferTime
    }
}

struct SimulationServiceRuleDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var entityType: String
    var distribution: SimulationDistributionDraft

    init(id: UUID = UUID(), entityType: String, distribution: SimulationDistributionDraft = .init(kind: .constant)) {
        self.id = id; self.entityType = entityType; self.distribution = distribution
    }
}

struct SimulationComponentDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var kind: SimulationComponentKind
    var routes: [SimulationRouteDraft]
    var inputRule: String
    var outputRule: String
    var queueDiscipline: String
    var queueCapacity: String
    var attributeValue: String
    var interarrivalTime: SimulationDistributionDraft?
    var batchSize: SimulationDistributionDraft?
    var serviceRules: [SimulationServiceRuleDraft]

    init(
        id: UUID = UUID(), name: String, kind: SimulationComponentKind,
        routes: [SimulationRouteDraft] = [], inputRule: String = "", outputRule: String = "",
        queueDiscipline: String = "", queueCapacity: String = "", attributeValue: String = "",
        interarrivalTime: SimulationDistributionDraft? = nil,
        batchSize: SimulationDistributionDraft? = nil,
        serviceRules: [SimulationServiceRuleDraft] = []
    ) {
        self.id = id; self.name = name; self.kind = kind; self.routes = routes
        self.inputRule = inputRule; self.outputRule = outputRule
        self.queueDiscipline = queueDiscipline; self.queueCapacity = queueCapacity
        self.attributeValue = attributeValue; self.interarrivalTime = interarrivalTime
        self.batchSize = batchSize; self.serviceRules = serviceRules
    }
}

private struct SimulationSpreadsheetRowKey: Hashable {
    let source: String
    let member: String
    init(source: String, member: String) {
        self.source = source.lowercased()
        self.member = member.lowercased()
    }
}

struct SimulationDraft: Equatable, Sendable {
    var title: String
    var timeUnit: String
    var representation: SimulationRepresentation
    var components: [SimulationComponentDraft]

    static let componentHeaders = [
        "Component", "Kind", "Input Rule", "Output Rule", "Queue Discipline", "Queue Capacity",
        "Attribute Value", "Interarrival Distribution", "Interarrival Parameters", "Batch Distribution", "Batch Parameters"
    ]
    static let routeHeaders = ["Source", "Target", "Probability", "Transfer Time"]
    static let serviceHeaders = ["Server", "Entity Type", "Distribution", "Parameters"]

    private init(title: String, timeUnit: String, representation: SimulationRepresentation, components: [SimulationComponentDraft]) {
        self.title = title; self.timeUnit = timeUnit; self.representation = representation; self.components = components
    }

    static func blank() -> Self {
        Self(
            title: "New Simulation", timeUnit: "hour", representation: .matrix,
            components: [
                SimulationComponentDraft(
                    name: "Customer", kind: .customer,
                    routes: [SimulationRouteDraft(target: "Queue")],
                    interarrivalTime: .init(kind: .exponential), batchSize: .init(kind: .constant)
                ),
                SimulationComponentDraft(
                    name: "Queue", kind: .queue, routes: [SimulationRouteDraft(target: "Server")],
                    queueDiscipline: "FIFO", queueCapacity: "100"
                ),
                SimulationComponentDraft(
                    name: "Server", kind: .server,
                    serviceRules: [SimulationServiceRuleDraft(entityType: "Customer", distribution: .init(kind: .exponential))]
                )
            ]
        )
    }

    init(_ model: SimulationModel) {
        title = model.title
        timeUnit = model.timeUnit
        representation = model.representation
        components = model.components.map { component in
            SimulationComponentDraft(
                name: component.name, kind: component.kind,
                routes: component.routes.map { SimulationRouteDraft(target: $0.target, probability: String($0.probability), transferTime: String($0.transferTime)) },
                inputRule: component.inputRule ?? "", outputRule: component.outputRule ?? "",
                queueDiscipline: component.queueDiscipline ?? "", queueCapacity: component.queueCapacity.map { String($0) } ?? "",
                attributeValue: component.attributeValue.map { String($0) } ?? "",
                interarrivalTime: component.interarrivalTime.map(SimulationDistributionDraft.init),
                batchSize: component.batchSize.map(SimulationDistributionDraft.init),
                serviceRules: component.serviceRules.map {
                    SimulationServiceRuleDraft(entityType: $0.entityType, distribution: SimulationDistributionDraft($0.distribution))
                }
            )
        }
    }

    func makeModel() throws -> SimulationModel {
        try required(title, path: "model.title", label: "a simulation title")
        try required(timeUnit, path: "model.timeUnit", label: "a time unit")
        let modelComponents = try components.enumerated().map { index, component in
            let base = "model.components.\(index)"
            try required(component.name, path: "\(base).name", label: "a component name")
            return SimulationComponent(
                name: component.name,
                kind: component.kind,
                routes: try component.routes.enumerated().map { routeIndex, route in
                    try required(route.target, path: "\(base).routes.\(routeIndex).target", label: "a route target")
                    return SimulationRoute(
                        target: route.target,
                        probability: try number(route.probability, path: "\(base).routes.\(routeIndex).probability", label: "route probability"),
                        transferTime: try number(route.transferTime, path: "\(base).routes.\(routeIndex).transferTime", label: "route transfer time")
                    )
                },
                inputRule: optionalText(component.inputRule), outputRule: optionalText(component.outputRule),
                queueDiscipline: optionalText(component.queueDiscipline),
                queueCapacity: try optionalInteger(component.queueCapacity, path: "\(base).queueCapacity", label: "queue capacity"),
                attributeValue: try optionalNumber(component.attributeValue, path: "\(base).attributeValue", label: "attribute value"),
                interarrivalTime: try component.interarrivalTime.map { try distribution($0, path: "\(base).interarrivalTime") },
                batchSize: try component.batchSize.map { try distribution($0, path: "\(base).batchSize") },
                serviceRules: try component.serviceRules.enumerated().map { ruleIndex, rule in
                    try required(rule.entityType, path: "\(base).serviceRules.\(ruleIndex).entityType", label: "an entity type")
                    return SimulationServiceRule(
                        entityType: rule.entityType,
                        distribution: try distribution(rule.distribution, path: "\(base).serviceRules.\(ruleIndex).distribution")
                    )
                }
            )
        }
        return SimulationModel(title: title, timeUnit: timeUnit, representation: representation, components: modelComponents)
    }

    func draftDiagnostics() -> [ValidationDiagnostic] {
        do {
            return SimulationValidator.diagnostics(for: try makeModel())
        } catch let error as SimulationDraftError {
            return [ValidationDiagnostic(
                severity: .error, code: "simulation.draft.\(error.path.replacingOccurrences(of: ".", with: "_"))",
                message: error.description, path: error.path
            )]
        } catch {
            return [ValidationDiagnostic(severity: .error, code: "simulation.draft.invalid", message: error.localizedDescription)]
        }
    }

    @discardableResult
    mutating func addComponent(kind: SimulationComponentKind = .queue) -> UUID {
        var suffix = components.count + 1
        var name = "Component \(suffix)"
        while components.contains(where: { $0.name == name }) { suffix += 1; name = "Component \(suffix)" }
        let component = SimulationComponentDraft(
            name: name, kind: kind,
            queueDiscipline: kind == .queue ? "FIFO" : "",
            queueCapacity: kind == .queue ? "100" : "",
            interarrivalTime: kind == .customer ? .init(kind: .exponential) : nil,
            batchSize: kind == .customer ? .init(kind: .constant) : nil,
            serviceRules: kind == .server ? [SimulationServiceRuleDraft(entityType: "Entity")] : []
        )
        components.append(component)
        return component.id
    }

    mutating func removeComponent(id: UUID) {
        guard components.count > 1, let component = components.first(where: { $0.id == id }) else { return }
        components.removeAll { $0.id == id }
        for index in components.indices { components[index].routes.removeAll { $0.target.caseInsensitiveCompare(component.name) == .orderedSame } }
    }

    mutating func renameComponent(id: UUID, to name: String) {
        guard let index = components.firstIndex(where: { $0.id == id }) else { return }
        let oldName = components[index].name
        components[index].name = name
        for componentIndex in components.indices {
            for routeIndex in components[componentIndex].routes.indices where components[componentIndex].routes[routeIndex].target.caseInsensitiveCompare(oldName) == .orderedSame {
                components[componentIndex].routes[routeIndex].target = name
            }
        }
    }

    mutating func changeKind(id: UUID, to kind: SimulationComponentKind) {
        guard let index = components.firstIndex(where: { $0.id == id }) else { return }
        components[index].kind = kind
        if kind == .customer {
            components[index].interarrivalTime = components[index].interarrivalTime ?? .init(kind: .exponential)
            components[index].batchSize = components[index].batchSize ?? .init(kind: .constant)
        }
        if kind == .queue {
            if components[index].queueDiscipline.isEmpty { components[index].queueDiscipline = "FIFO" }
            if components[index].queueCapacity.isEmpty { components[index].queueCapacity = "100" }
        }
        if kind == .server, components[index].serviceRules.isEmpty {
            components[index].serviceRules = [SimulationServiceRuleDraft(entityType: "Entity")]
        }
    }

    @discardableResult
    mutating func addRoute(to componentID: UUID) -> UUID? {
        guard let index = components.firstIndex(where: { $0.id == componentID }) else { return nil }
        let target = components.first(where: { $0.id != componentID })?.name ?? components[index].name
        let route = SimulationRouteDraft(target: target)
        components[index].routes.append(route)
        return route.id
    }

    mutating func removeRoute(_ routeID: UUID, from componentID: UUID) {
        guard let index = components.firstIndex(where: { $0.id == componentID }) else { return }
        components[index].routes.removeAll { $0.id == routeID }
    }

    @discardableResult
    mutating func addServiceRule(to componentID: UUID) -> UUID? {
        guard let index = components.firstIndex(where: { $0.id == componentID }) else { return nil }
        let entity = components.first(where: { $0.kind == .customer })?.name ?? "Entity"
        let rule = SimulationServiceRuleDraft(entityType: entity)
        components[index].serviceRules.append(rule)
        return rule.id
    }

    mutating func removeServiceRule(_ ruleID: UUID, from componentID: UUID) {
        guard let index = components.firstIndex(where: { $0.id == componentID }) else { return }
        components[index].serviceRules.removeAll { $0.id == ruleID }
    }

    func componentTabularText() -> String {
        ([Self.componentHeaders] + components.map { component in
            [component.name, component.kind.rawValue, component.inputRule, component.outputRule,
             component.queueDiscipline, component.queueCapacity, component.attributeValue,
             component.interarrivalTime?.kind.rawValue ?? "", parameterText(component.interarrivalTime),
             component.batchSize?.kind.rawValue ?? "", parameterText(component.batchSize)]
        }).map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }

    mutating func replaceComponents(withTabularText text: String) throws {
        var rows = try SpreadsheetTable(text: text).rows
        if rows.first?.map({ $0.lowercased() }) == Self.componentHeaders.map({ $0.lowercased() }) { rows.removeFirst() }
        guard !rows.isEmpty else { throw SpreadsheetTransferError.emptyClipboard }
        let existing = Dictionary(grouping: components, by: { $0.name.lowercased() })
        let incoming = Dictionary(grouping: rows, by: { ($0.first ?? "").lowercased() })
        var replacement: [SimulationComponentDraft] = []
        for (index, row) in rows.enumerated() {
            let displayRow = index + 1
            guard row.count == Self.componentHeaders.count else {
                throw SpreadsheetTransferError.inconsistentColumns(expected: Self.componentHeaders.count, actual: row.count, row: displayRow)
            }
            guard !row[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SpreadsheetTransferError.invalidValue(row[0], column: "Component", row: displayRow) }
            guard let kind = SimulationComponentKind(rawValue: row[1].uppercased()) else {
                throw SpreadsheetTransferError.invalidValue(row[1], column: "Kind", row: displayRow)
            }
            if !row[5].isEmpty, Int(row[5]) == nil { throw SpreadsheetTransferError.invalidValue(row[5], column: "Queue Capacity", row: displayRow) }
            if !row[6].isEmpty { try SpreadsheetTable.requireFinite(row[6], column: "Attribute Value", row: displayRow) }
            let arrival = try parseOptionalDistribution(kind: row[7], parameters: row[8], column: "Interarrival", row: displayRow)
            let batch = try parseOptionalDistribution(kind: row[9], parameters: row[10], column: "Batch", row: displayRow)
            // Only an unambiguous name can carry hidden routes and service rules.
            let name = row[0].lowercased()
            let previous = existing[name]?.count == 1 && incoming[name]?.count == 1 ? existing[name]?.first : nil
            replacement.append(SimulationComponentDraft(
                id: previous?.id ?? UUID(), name: row[0], kind: kind,
                routes: previous?.routes ?? [], inputRule: row[2], outputRule: row[3],
                queueDiscipline: row[4], queueCapacity: row[5], attributeValue: row[6],
                interarrivalTime: arrival, batchSize: batch, serviceRules: previous?.serviceRules ?? []
            ))
        }
        components = replacement
    }

    func routeTabularText() -> String {
        var rows = [Self.routeHeaders]
        for component in components {
            rows += component.routes.map { [component.name, $0.target, $0.probability, $0.transferTime] }
        }
        return rows.map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }

    mutating func replaceRoutes(withTabularText text: String) throws {
        var rows = try SpreadsheetTable(text: text).rows
        if rows.first?.map({ $0.lowercased() }) == Self.routeHeaders.map({ $0.lowercased() }) { rows.removeFirst() }
        var grouped: [String: [SimulationRouteDraft]] = [:]
        let componentNames = Dictionary(grouping: components, by: { $0.name.lowercased() })
        let existing = Dictionary(grouping: components.flatMap { component in
            component.routes.map { (key: SimulationSpreadsheetRowKey(source: component.name, member: $0.target), value: $0) }
        }, by: \.key)
        let incoming = Dictionary(grouping: rows.filter { $0.count == 4 }, by: { SimulationSpreadsheetRowKey(source: $0[0], member: $0[1]) })
        for (index, row) in rows.enumerated() {
            let displayRow = index + 1
            guard row.count == Self.routeHeaders.count else {
                throw SpreadsheetTransferError.inconsistentColumns(expected: Self.routeHeaders.count, actual: row.count, row: displayRow)
            }
            let source = row[0].lowercased()
            guard componentNames[source]?.count == 1 else { throw SpreadsheetTransferError.invalidValue(row[0], column: "Source", row: displayRow) }
            guard !row[1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SpreadsheetTransferError.invalidValue(row[1], column: "Target", row: displayRow) }
            try SpreadsheetTable.requireFinite(row[2], column: "Probability", row: displayRow)
            try SpreadsheetTable.requireFinite(row[3], column: "Transfer Time", row: displayRow)
            let key = SimulationSpreadsheetRowKey(source: row[0], member: row[1])
            let id = existing[key]?.count == 1 && incoming[key]?.count == 1 ? existing[key]?.first?.value.id : nil
            grouped[source, default: []].append(SimulationRouteDraft(id: id ?? UUID(), target: row[1], probability: row[2], transferTime: row[3]))
        }
        var replacement = components
        for index in replacement.indices { replacement[index].routes = grouped[replacement[index].name.lowercased()] ?? [] }
        components = replacement
    }

    func serviceTabularText() -> String {
        var rows = [Self.serviceHeaders]
        for component in components {
            rows += component.serviceRules.map {
                [component.name, $0.entityType, $0.distribution.kind.rawValue, $0.distribution.parameters.joined(separator: " ")]
            }
        }
        return rows.map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }

    mutating func replaceServiceRules(withTabularText text: String) throws {
        var rows = try SpreadsheetTable(text: text).rows
        if rows.first?.map({ $0.lowercased() }) == Self.serviceHeaders.map({ $0.lowercased() }) { rows.removeFirst() }
        var grouped: [String: [SimulationServiceRuleDraft]] = [:]
        let componentNames = Dictionary(grouping: components, by: { $0.name.lowercased() })
        let existing = Dictionary(grouping: components.flatMap { component in
            component.serviceRules.map { (key: SimulationSpreadsheetRowKey(source: component.name, member: $0.entityType), value: $0) }
        }, by: \.key)
        let incoming = Dictionary(grouping: rows.filter { $0.count == 4 }, by: { SimulationSpreadsheetRowKey(source: $0[0], member: $0[1]) })
        for (index, row) in rows.enumerated() {
            let displayRow = index + 1
            guard row.count == Self.serviceHeaders.count else {
                throw SpreadsheetTransferError.inconsistentColumns(expected: Self.serviceHeaders.count, actual: row.count, row: displayRow)
            }
            let server = row[0].lowercased()
            guard componentNames[server]?.count == 1 else { throw SpreadsheetTransferError.invalidValue(row[0], column: "Server", row: displayRow) }
            guard !row[1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SpreadsheetTransferError.invalidValue(row[1], column: "Entity Type", row: displayRow) }
            let distribution = try parseRequiredDistribution(kind: row[2], parameters: row[3], column: "Distribution", row: displayRow)
            let key = SimulationSpreadsheetRowKey(source: row[0], member: row[1])
            let id = existing[key]?.count == 1 && incoming[key]?.count == 1 ? existing[key]?.first?.value.id : nil
            grouped[server, default: []].append(SimulationServiceRuleDraft(id: id ?? UUID(), entityType: row[1], distribution: distribution))
        }
        var replacement = components
        for index in replacement.indices { replacement[index].serviceRules = grouped[replacement[index].name.lowercased()] ?? [] }
        components = replacement
    }

    private func distribution(_ draft: SimulationDistributionDraft, path: String) throws -> SimulationDistribution {
        SimulationDistribution(kind: draft.kind, parameters: try draft.parameters.enumerated().map {
            try number($0.element, path: "\(path).parameters.\($0.offset)", label: "distribution parameter")
        })
    }

    private func parameterText(_ draft: SimulationDistributionDraft?) -> String {
        draft?.parameters.joined(separator: " ") ?? ""
    }

    private func parseOptionalDistribution(kind: String, parameters: String, column: String, row: Int) throws -> SimulationDistributionDraft? {
        if kind.isEmpty && parameters.isEmpty { return nil }
        guard !kind.isEmpty else { throw SpreadsheetTransferError.invalidValue(parameters, column: "\(column) Distribution", row: row) }
        return try parseRequiredDistribution(kind: kind, parameters: parameters, column: column, row: row)
    }

    private func parseRequiredDistribution(kind: String, parameters: String, column: String, row: Int) throws -> SimulationDistributionDraft {
        guard let distributionKind = SimulationDistributionKind(rawValue: kind.lowercased()) else {
            throw SpreadsheetTransferError.invalidValue(kind, column: column, row: row)
        }
        let values = parameters.split(whereSeparator: { $0.isWhitespace || $0 == "|" }).map(String.init)
        guard !values.isEmpty else { throw SpreadsheetTransferError.invalidValue(parameters, column: "\(column) Parameters", row: row) }
        for value in values { try SpreadsheetTable.requireFinite(value, column: "\(column) Parameters", row: row) }
        return SimulationDistributionDraft(kind: distributionKind, parameters: values)
    }

    private func required(_ value: String, path: String, label: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SimulationDraftError.emptyField(path: path, label: label)
        }
    }

    private func optionalText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : value
    }

    private func number(_ value: String, path: String, label: String) throws -> Double {
        guard let number = Double(value), number.isFinite else {
            throw SimulationDraftError.invalidNumber(path: path, label: label, value: value)
        }
        return number
    }

    private func optionalNumber(_ value: String, path: String, label: String) throws -> Double? {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : try number(value, path: path, label: label)
    }

    private func optionalInteger(_ value: String, path: String, label: String) throws -> Int? {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let integer = Int(value) else { throw SimulationDraftError.invalidInteger(path: path, label: label, value: value) }
        return integer
    }
}
