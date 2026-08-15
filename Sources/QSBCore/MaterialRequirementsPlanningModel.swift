import Foundation

public enum MRPLotSizingRule: String, Codable, Hashable, Sendable {
    case lotForLot = "LFL"
    case economicOrderQuantity = "EOQ"
    case leastUnitCost = "LUC"
    case leastTotalCost = "LTC"
    case partPeriodBalancing = "PPB"
}

public struct MRPItem: Codable, Equatable, Sendable {
    public let identifier: String
    public let levelCode: String
    public let sourceCode: String
    public let materialType: String
    public let unit: String
    public let leadTime: Int
    public let lotSizingRule: MRPLotSizingRule
    public let lotSizingLookahead: Int?
    public let annualDemand: Double
    public let unitCost: Double
    public let orderingCost: Double
    public let annualHoldingCost: Double
    public let description: String
    public let safetyStock: Double
    public let initialOnHand: Double
    public let scheduledReceipts: [Double]
    public let capacity: [Double?]

    public init(identifier: String, levelCode: String, sourceCode: String, materialType: String, unit: String, leadTime: Int, lotSizingRule: MRPLotSizingRule, lotSizingLookahead: Int?, annualDemand: Double, unitCost: Double, orderingCost: Double, annualHoldingCost: Double, description: String, safetyStock: Double, initialOnHand: Double, scheduledReceipts: [Double], capacity: [Double?]) {
        self.identifier = identifier; self.levelCode = levelCode; self.sourceCode = sourceCode
        self.materialType = materialType; self.unit = unit; self.leadTime = leadTime
        self.lotSizingRule = lotSizingRule; self.lotSizingLookahead = lotSizingLookahead
        self.annualDemand = annualDemand; self.unitCost = unitCost; self.orderingCost = orderingCost
        self.annualHoldingCost = annualHoldingCost; self.description = description
        self.safetyStock = safetyStock; self.initialOnHand = initialOnHand
        self.scheduledReceipts = scheduledReceipts; self.capacity = capacity
    }
}

public struct MRPComponent: Codable, Equatable, Sendable {
    public let itemIdentifier: String
    public let quantityPerParent: Double
    public init(itemIdentifier: String, quantityPerParent: Double) { self.itemIdentifier = itemIdentifier; self.quantityPerParent = quantityPerParent }
}

public struct MRPBillOfMaterial: Codable, Equatable, Sendable {
    public let parentIdentifier: String
    public let components: [MRPComponent]
    public init(parentIdentifier: String, components: [MRPComponent]) { self.parentIdentifier = parentIdentifier; self.components = components }
}

public struct MaterialRequirementsPlanningModel: Codable, Equatable, Sendable {
    public let title: String
    public let timeUnit: String
    public let periodsPerYear: Int
    public let bucketNames: [String]
    public let items: [MRPItem]
    public let billsOfMaterial: [MRPBillOfMaterial]
    public let masterProductionSchedule: [String: [Double]]
    public init(title: String, timeUnit: String, periodsPerYear: Int, bucketNames: [String], items: [MRPItem], billsOfMaterial: [MRPBillOfMaterial], masterProductionSchedule: [String: [Double]]) {
        self.title = title; self.timeUnit = timeUnit; self.periodsPerYear = periodsPerYear
        self.bucketNames = bucketNames; self.items = items; self.billsOfMaterial = billsOfMaterial
        self.masterProductionSchedule = masterProductionSchedule
    }
}

public struct MRPItemSchedule: Codable, Equatable, Sendable {
    public let itemIdentifier: String
    public let grossRequirements: [Double]
    public let scheduledReceipts: [Double]
    public let projectedOnHand: [Double]
    public let netRequirements: [Double]
    public let plannedOrderReceipts: [Double]
    public let plannedOrderReleases: [Double]
    public let capacityExcess: [Double]
}

public struct MaterialRequirementsPlanningSolution: Codable, Equatable, Sendable {
    public let bucketNames: [String]
    public let schedules: [MRPItemSchedule]
}

public struct MaterialRequirementsPlanningSolutionDocument: Codable, Equatable, Sendable {
    public let backend: SolverRunMetadata
    public let model: MaterialRequirementsPlanningModel
    public let solution: MaterialRequirementsPlanningSolution
}

public struct MaterialRequirementsPlanningValidationDocument: Codable, Equatable, Sendable {
    public let backend: SolverBackendKind
    public let isValid: Bool
    public let diagnostics: [ValidationDiagnostic]

    public init(backend: SolverBackendKind, diagnostics: [ValidationDiagnostic]) {
        self.backend = backend
        self.isValid = !diagnostics.contains { $0.severity == .error }
        self.diagnostics = diagnostics
    }
}

public enum MaterialRequirementsPlanningError: Error, CustomStringConvertible {
    case unsupportedFormat
    case invalidModel(String)

    public var description: String {
        switch self {
        case .unsupportedFormat: "Unsupported material-requirements-planning format"
        case .invalidModel(let message): "Invalid material-requirements-planning model: \(message)"
        }
    }
}

public enum WinQSBMaterialRequirementsPlanningParser {
    public static func parse(from data: Data) throws -> MaterialRequirementsPlanningModel {
        guard let text = data.legacyLatin1String else {
            throw MaterialRequirementsPlanningError.unsupportedFormat
        }
        let rows = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
        guard rows.count >= 6, rows[0].count >= 7, rows[0][0] == "MRP",
              let itemCount = Int(rows[0][2]), let planningPeriods = Int(rows[0][4]),
              let periodsPerYear = Int(rows[0][5]), itemCount > 0, planningPeriods > 0,
              let itemStart = section("**Item Master", in: rows),
              let bomStart = section("**BOM", in: rows),
              let mpsStart = section("**MPS", in: rows),
              let inventoryStart = section("**Inventory", in: rows),
              let capacityStart = section("**Capacity", in: rows),
              itemStart < bomStart, bomStart < mpsStart, mpsStart < inventoryStart, inventoryStart < capacityStart else {
            throw MaterialRequirementsPlanningError.unsupportedFormat
        }
        let bucketCount = planningPeriods + 1
        let bucketNames = ["Overdue"] + (1...planningPeriods).map { "\(rows[0][3]) \($0)" }

        struct Master {
            let identifier: String; let level: String; let source: String; let material: String; let unit: String
            let lead: Int; let rule: MRPLotSizingRule; let lookahead: Int?; let annualDemand: Double
            let unitCost: Double; let orderingCost: Double; let holdingCost: Double; let description: String
        }
        let masters: [Master] = try rows[(itemStart + 1)..<bomStart].map { row in
            guard row.count >= 15, let lead = Int(row[5]), let rule = MRPLotSizingRule(rawValue: row[6]),
                  let annualDemand = Double(row[9]), let unitCost = Double(row[10]),
                  let orderingCost = Double(row[11]), let holdingCost = Double(row[12]) else {
                throw MaterialRequirementsPlanningError.unsupportedFormat
            }
            return Master(identifier: row[0], level: row[1], source: row[2], material: row[3], unit: row[4], lead: lead, rule: rule, lookahead: Int(row[8]), annualDemand: annualDemand, unitCost: unitCost, orderingCost: orderingCost, holdingCost: holdingCost, description: row[14])
        }
        guard masters.count == itemCount else {
            throw MaterialRequirementsPlanningError.invalidModel("Item count does not match Item Master")
        }

        let bills = try rows[(bomStart + 1)..<mpsStart].map { row -> MRPBillOfMaterial in
            guard !row.isEmpty else { throw MaterialRequirementsPlanningError.unsupportedFormat }
            let components = try row.dropFirst().filter { !$0.isEmpty }.map(parseComponent)
            return MRPBillOfMaterial(parentIdentifier: row[0], components: components)
        }
        let mps = try keyedVectors(rows[(mpsStart + 1)..<inventoryStart], count: bucketCount)
        let inventoryRows = Dictionary(uniqueKeysWithValues: rows[(inventoryStart + 1)..<capacityStart].map { ($0[0], $0) })
        let capacityRows = Dictionary(uniqueKeysWithValues: rows[(capacityStart + 1)...].map { ($0[0], $0) })

        let items = try masters.map { master -> MRPItem in
            guard let inventory = inventoryRows[master.identifier], inventory.count >= 3,
                  let safetyStock = Double(inventory[1]), let initialOnHand = Double(inventory[2]) else {
                throw MaterialRequirementsPlanningError.invalidModel("Missing inventory row for \(master.identifier)")
            }
            let receipts = try numericVector(Array(inventory.dropFirst(3)), count: bucketCount)
            let rawCapacity = capacityRows[master.identifier].map { Array($0.dropFirst()) } ?? []
            var capacity: [Double?] = [nil]
            capacity += try (0..<planningPeriods).map { index -> Double? in
                guard index < rawCapacity.count else { return nil }
                let raw = rawCapacity[index].trimmingCharacters(in: .whitespacesAndNewlines)
                if raw.isEmpty || raw.lowercased() == "m" { return nil }
                guard let value = Double(raw), value.isFinite else {
                    throw MaterialRequirementsPlanningError.invalidModel("Invalid capacity '\(raw)' for \(master.identifier)")
                }
                return value
            }
            return MRPItem(identifier: master.identifier, levelCode: master.level, sourceCode: master.source, materialType: master.material, unit: master.unit, leadTime: master.lead, lotSizingRule: master.rule, lotSizingLookahead: master.lookahead, annualDemand: master.annualDemand, unitCost: master.unitCost, orderingCost: master.orderingCost, annualHoldingCost: master.holdingCost, description: master.description, safetyStock: safetyStock, initialOnHand: initialOnHand, scheduledReceipts: receipts, capacity: capacity)
        }
        let model = MaterialRequirementsPlanningModel(title: rows[0][1], timeUnit: rows[0][3], periodsPerYear: periodsPerYear, bucketNames: bucketNames, items: items, billsOfMaterial: bills, masterProductionSchedule: mps)
        try MaterialRequirementsPlanningValidator.validate(model)
        return model
    }

    private static func section(_ marker: String, in rows: [[String]]) -> Int? {
        rows.firstIndex { $0.first == marker }
    }

    private static func parseComponent(_ raw: String) throws -> MRPComponent {
        let parts = raw.split(separator: "/", maxSplits: 1).map(String.init)
        let quantity = parts.count == 2 ? Double(parts[1]) : 1
        guard let quantity, quantity.isFinite, quantity > 0 else {
            throw MaterialRequirementsPlanningError.invalidModel("Invalid BOM component '\(raw)'")
        }
        return MRPComponent(itemIdentifier: parts[0], quantityPerParent: quantity)
    }

    private static func keyedVectors(_ rows: ArraySlice<[String]>, count: Int) throws -> [String: [Double]] {
        try Dictionary(uniqueKeysWithValues: rows.map { row in
            guard let identifier = row.first else { throw MaterialRequirementsPlanningError.unsupportedFormat }
            return (identifier, try numericVector(Array(row.dropFirst()), count: count))
        })
    }

    private static func numericVector(_ raw: [String], count: Int) throws -> [Double] {
        try (0..<count).map { index in
            guard index < raw.count else { return 0 }
            let value = raw[index].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return 0 }
            guard let number = Double(value), number.isFinite else {
                throw MaterialRequirementsPlanningError.invalidModel("Invalid numeric value '\(value)'")
            }
            return number
        }
    }
}

public enum MaterialRequirementsPlanningValidator {
    public static func diagnostics(for model: MaterialRequirementsPlanningModel) -> [ValidationDiagnostic] {
        var diagnostics: [ValidationDiagnostic] = []
        let bucketCount = model.bucketNames.count
        let identifiers = model.items.map(\.identifier)
        let identifierSet = Set(identifiers)
        if identifiers.isEmpty || identifierSet.count != identifiers.count {
            diagnostics.append(error("items", "Item identifiers must be nonempty and unique.", "model.items"))
        }
        for (index, item) in model.items.enumerated() {
            if item.leadTime < 0 || item.safetyStock < 0 || item.initialOnHand < 0 || item.periodsInvalid(bucketCount: bucketCount) {
                diagnostics.append(error("item", "Item values and bucket dimensions are invalid.", "model.items[\(index)]"))
            }
        }
        for bill in model.billsOfMaterial {
            if !identifierSet.contains(bill.parentIdentifier) || bill.components.contains(where: { !identifierSet.contains($0.itemIdentifier) || $0.quantityPerParent <= 0 }) {
                diagnostics.append(error("bomReference", "Every BOM parent and component must reference a known item with positive usage.", "model.billsOfMaterial"))
            }
        }
        if Set(model.billsOfMaterial.map(\.parentIdentifier)).count != model.billsOfMaterial.count {
            diagnostics.append(error("bomParent", "Each BOM parent may have only one component row.", "model.billsOfMaterial"))
        }
        if hasCycle(model.billsOfMaterial) {
            diagnostics.append(error("bomCycle", "Bill of materials must be acyclic.", "model.billsOfMaterial"))
        }
        if model.masterProductionSchedule.contains(where: { !identifierSet.contains($0.key) || $0.value.count != bucketCount || $0.value.contains(where: { !$0.isFinite || $0 < 0 }) }) {
            diagnostics.append(error("mps", "MPS rows must reference known items and match all buckets with nonnegative values.", "model.masterProductionSchedule"))
        }
        if diagnostics.isEmpty {
            diagnostics.append(ValidationDiagnostic(severity: .info, code: "mrp.valid", message: "Material-requirements-planning model is valid"))
        }
        return diagnostics
    }

    public static func validate(_ model: MaterialRequirementsPlanningModel) throws {
        if let diagnostic = diagnostics(for: model).first(where: { $0.severity == .error }) {
            throw MaterialRequirementsPlanningError.invalidModel(diagnostic.message)
        }
    }

    private static func hasCycle(_ bills: [MRPBillOfMaterial]) -> Bool {
        let edges = Dictionary(grouping: bills, by: \.parentIdentifier).mapValues { rows in rows.flatMap { $0.components.map(\.itemIdentifier) } }
        var visiting = Set<String>(), visited = Set<String>()
        func visit(_ node: String) -> Bool {
            if visiting.contains(node) { return true }
            if visited.contains(node) { return false }
            visiting.insert(node)
            for child in edges[node] ?? [] where visit(child) { return true }
            visiting.remove(node); visited.insert(node)
            return false
        }
        return edges.keys.contains(where: visit)
    }

    private static func error(_ code: String, _ message: String, _ path: String) -> ValidationDiagnostic {
        ValidationDiagnostic(severity: .error, code: "mrp.\(code)", message: message, path: path)
    }
}

private extension MRPItem {
    func periodsInvalid(bucketCount: Int) -> Bool {
        scheduledReceipts.count != bucketCount || capacity.count != bucketCount
            || scheduledReceipts.contains(where: { !$0.isFinite || $0 < 0 })
            || capacity.compactMap { $0 }.contains(where: { !$0.isFinite || $0 < 0 })
            || !annualDemand.isFinite || annualDemand < 0 || !orderingCost.isFinite || orderingCost < 0
            || !annualHoldingCost.isFinite || annualHoldingCost < 0
    }
}

public enum MaterialRequirementsPlanningSolver {
    public static func solve(_ model: MaterialRequirementsPlanningModel) throws -> MaterialRequirementsPlanningSolution {
        try MaterialRequirementsPlanningValidator.validate(model)
        let order = try topologicalOrder(model)
        let itemByID = Dictionary(uniqueKeysWithValues: model.items.map { ($0.identifier, $0) })
        let bills = Dictionary(uniqueKeysWithValues: model.billsOfMaterial.map { ($0.parentIdentifier, $0.components) })
        let count = model.bucketNames.count
        var gross = Dictionary(uniqueKeysWithValues: model.items.map { ($0.identifier, model.masterProductionSchedule[$0.identifier] ?? Array(repeating: 0, count: count)) })
        var schedules: [String: MRPItemSchedule] = [:]

        for identifier in order {
            let item = itemByID[identifier]!
            let schedule = schedule(item: item, gross: gross[identifier]!, periodsPerYear: model.periodsPerYear)
            schedules[identifier] = schedule
            for component in bills[identifier] ?? [] {
                for bucket in 0..<count {
                    gross[component.itemIdentifier]![bucket] += schedule.plannedOrderReleases[bucket] * component.quantityPerParent
                }
            }
        }
        return MaterialRequirementsPlanningSolution(bucketNames: model.bucketNames, schedules: model.items.compactMap { schedules[$0.identifier] })
    }

    private static func schedule(item: MRPItem, gross: [Double], periodsPerYear: Int) -> MRPItemSchedule {
        let count = gross.count
        var projected = Array(repeating: 0.0, count: count)
        var net = Array(repeating: 0.0, count: count)
        var receipts = Array(repeating: 0.0, count: count)
        var releases = Array(repeating: 0.0, count: count)
        var prior = item.initialOnHand
        for bucket in 0..<count {
            let available = prior + item.scheduledReceipts[bucket]
            let shortage = max(0, gross[bucket] + item.safetyStock - available)
            if shortage > 1e-10 {
                net[bucket] = shortage
                let quantity = lotQuantity(item: item, shortage: shortage, bucket: bucket, gross: gross, periodsPerYear: periodsPerYear)
                receipts[bucket] = quantity
                releases[max(0, bucket - item.leadTime)] += quantity
            }
            projected[bucket] = available + receipts[bucket] - gross[bucket]
            prior = projected[bucket]
        }
        let excess = zip(receipts, item.capacity).map { receipt, capacity in capacity.map { max(0, receipt - $0) } ?? 0 }
        return MRPItemSchedule(itemIdentifier: item.identifier, grossRequirements: gross, scheduledReceipts: item.scheduledReceipts, projectedOnHand: projected, netRequirements: net, plannedOrderReceipts: receipts, plannedOrderReleases: releases, capacityExcess: excess)
    }

    private static func lotQuantity(item: MRPItem, shortage: Double, bucket: Int, gross: [Double], periodsPerYear: Int) -> Double {
        switch item.lotSizingRule {
        case .lotForLot:
            return shortage
        case .economicOrderQuantity:
            guard item.annualHoldingCost > 0 else { return shortage }
            let eoq = sqrt(2 * item.annualDemand * item.orderingCost / item.annualHoldingCost)
            let multiple = Double(max(1, item.lotSizingLookahead ?? 1))
            return max(shortage, ceil(eoq / multiple) * multiple)
        case .leastUnitCost, .leastTotalCost, .partPeriodBalancing:
            let limit = min(gross.count - 1, bucket + max(1, item.lotSizingLookahead ?? (gross.count - bucket)) - 1)
            let holding = item.annualHoldingCost / Double(max(1, periodsPerYear))
            var quantity = shortage, partPeriods = 0.0
            var candidates: [(quantity: Double, holding: Double, unitCost: Double)] = [(shortage, 0, item.orderingCost / max(shortage, 1e-12))]
            if limit > bucket {
                for future in (bucket + 1)...limit where gross[future] > 0 {
                    quantity += gross[future]
                    partPeriods += gross[future] * Double(future - bucket)
                    let carrying = holding * partPeriods
                    candidates.append((quantity, carrying, (item.orderingCost + carrying) / quantity))
                }
            }
            switch item.lotSizingRule {
            case .leastUnitCost:
                return candidates.min { $0.unitCost < $1.unitCost }!.quantity
            case .leastTotalCost, .partPeriodBalancing:
                return candidates.min { abs($0.holding - item.orderingCost) < abs($1.holding - item.orderingCost) }!.quantity
            default:
                return shortage
            }
        }
    }

    private static func topologicalOrder(_ model: MaterialRequirementsPlanningModel) throws -> [String] {
        var indegree = Dictionary(uniqueKeysWithValues: model.items.map { ($0.identifier, 0) })
        var edges: [String: [String]] = [:]
        for bill in model.billsOfMaterial {
            edges[bill.parentIdentifier] = bill.components.map(\.itemIdentifier)
            for component in bill.components { indegree[component.itemIdentifier, default: 0] += 1 }
        }
        var queue = model.items.map(\.identifier).filter { indegree[$0] == 0 }
        var order: [String] = []
        while !queue.isEmpty {
            let parent = queue.removeFirst(); order.append(parent)
            for child in edges[parent] ?? [] {
                indegree[child]! -= 1
                if indegree[child] == 0 { queue.append(child) }
            }
        }
        guard order.count == model.items.count else { throw MaterialRequirementsPlanningError.invalidModel("Bill of materials contains a cycle") }
        return order
    }
}

public protocol MaterialRequirementsPlanningBackend: Sendable {
    var capabilities: SolverCapabilities { get }
    func validationReport(for model: MaterialRequirementsPlanningModel) -> ValidationReport
    func solve(_ model: MaterialRequirementsPlanningModel, options: SolverOptions) throws -> MaterialRequirementsPlanningSolution
    func runMetadata(for model: MaterialRequirementsPlanningModel) -> SolverRunMetadata
}

public extension MaterialRequirementsPlanningBackend {
    func validationReport(for model: MaterialRequirementsPlanningModel) -> ValidationReport {
        ValidationReport(backend: capabilities.backendKind, diagnostics: MaterialRequirementsPlanningValidator.diagnostics(for: model))
    }
    func solve(_ model: MaterialRequirementsPlanningModel) throws -> MaterialRequirementsPlanningSolution { try solve(model, options: SolverOptions()) }
    func solutionDocument(for model: MaterialRequirementsPlanningModel, solution: MaterialRequirementsPlanningSolution) -> MaterialRequirementsPlanningSolutionDocument {
        MaterialRequirementsPlanningSolutionDocument(backend: runMetadata(for: model), model: model, solution: solution)
    }
}

public struct NativeEducationalMaterialRequirementsPlanningBackend: MaterialRequirementsPlanningBackend {
    public init() {}
    public var capabilities: SolverCapabilities {
        SolverCapabilities(backendKind: .nativeEducational, solves: true, validates: true, exportsStructuredSolution: true, notes: ["Deterministic multi-level MRP explosion with classical lot-sizing rules."])
    }
    public func solve(_ model: MaterialRequirementsPlanningModel, options _: SolverOptions = SolverOptions()) throws -> MaterialRequirementsPlanningSolution { try MaterialRequirementsPlanningSolver.solve(model) }
    public func runMetadata(for _: MaterialRequirementsPlanningModel) -> SolverRunMetadata {
        SolverRunMetadata(backendKind: .nativeEducational, algorithm: "multiLevelMRPExplosion", exactness: .heuristic, notes: ["LFL and EOQ use their stated formulas; LUC, LTC, and PPB are classical forward lot-sizing heuristics.", "Capacity excess is reported but not automatically leveled."])
    }
}

public struct ValidateOnlyMaterialRequirementsPlanningBackend: MaterialRequirementsPlanningBackend {
    public init() {}
    public var capabilities: SolverCapabilities { SolverCapabilities(backendKind: .validateOnly, solves: false, validates: true, exportsStructuredSolution: false) }
    public func solve(_ model: MaterialRequirementsPlanningModel, options _: SolverOptions = SolverOptions()) throws -> MaterialRequirementsPlanningSolution { throw MaterialRequirementsPlanningError.invalidModel("validateOnly backend does not explode MRP models") }
    public func runMetadata(for _: MaterialRequirementsPlanningModel) -> SolverRunMetadata { SolverRunMetadata(backendKind: .validateOnly, algorithm: "validationOnly", exactness: .exact) }
}

public enum MaterialRequirementsPlanningBackends {
    public static func backend(for kind: SolverBackendKind) -> (any MaterialRequirementsPlanningBackend)? {
        switch kind {
        case .nativeEducational: NativeEducationalMaterialRequirementsPlanningBackend()
        case .validateOnly: ValidateOnlyMaterialRequirementsPlanningBackend()
        case .externalHighPerformance: nil
        }
    }
}

public enum MaterialRequirementsPlanningJSON {
    public static func encodeModel(_ model: MaterialRequirementsPlanningModel) throws -> Data { try encoder.encode(model) }
    public static func decodeModel(from data: Data) throws -> MaterialRequirementsPlanningModel { try JSONDecoder().decode(MaterialRequirementsPlanningModel.self, from: data) }
    public static func encodeSolution(_ document: MaterialRequirementsPlanningSolutionDocument) throws -> Data { try encoder.encode(document) }
    public static func decodeSolution(from data: Data) throws -> MaterialRequirementsPlanningSolutionDocument { try JSONDecoder().decode(MaterialRequirementsPlanningSolutionDocument.self, from: data) }
    public static func encodeValidation(_ document: MaterialRequirementsPlanningValidationDocument) throws -> Data { try encoder.encode(document) }
    private static var encoder: JSONEncoder { NormalizedJSONCoding.encoder() }
}
