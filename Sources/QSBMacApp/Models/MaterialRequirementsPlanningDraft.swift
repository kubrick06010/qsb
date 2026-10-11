import Foundation
import QSBCore

enum MaterialRequirementsPlanningDraftError: Error, Equatable, CustomStringConvertible {
    case importedDimensions
    case emptyField(path: String, label: String)
    case invalidNumber(path: String, label: String, value: String)
    case invalidInteger(path: String, label: String, value: String)

    var path: String {
        switch self {
        case .importedDimensions: "model.schedules"
        case .emptyField(let path, _), .invalidNumber(let path, _, _), .invalidInteger(let path, _, _): path
        }
    }

    var description: String {
        switch self {
        case .importedDimensions:
            "Review the imported schedule dimensions and accept the displayed periods before validating or exporting."
        case .emptyField(_, let label):
            "Enter \(label)."
        case .invalidNumber(_, let label, let value):
            "Enter a finite number for \(label) (received ‘\(value)’)."
        case .invalidInteger(_, let label, let value):
            "Enter a whole number for \(label) (received ‘\(value)’)."
        }
    }
}

struct MRPItemDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var identifier: String
    var levelCode: String
    var sourceCode: String
    var materialType: String
    var unit: String
    var leadTime: String
    var lotSizingRule: MRPLotSizingRule
    var lotSizingLookahead: String
    var annualDemand: String
    var unitCost: String
    var orderingCost: String
    var annualHoldingCost: String
    var description: String
    var safetyStock: String
    var initialOnHand: String
    var scheduledReceipts: [String]
    var capacity: [String]
    var masterProductionSchedule: [String]?

    init(
        id: UUID = UUID(), identifier: String, levelCode: String = "0", sourceCode: String = "M",
        materialType: String = "Item", unit: String = "unit", leadTime: String = "0",
        lotSizingRule: MRPLotSizingRule = .lotForLot, lotSizingLookahead: String = "",
        annualDemand: String = "0", unitCost: String = "0", orderingCost: String = "0",
        annualHoldingCost: String = "0", description: String = "", safetyStock: String = "0",
        initialOnHand: String = "0", scheduledReceipts: [String], capacity: [String],
        masterProductionSchedule: [String]? = nil
    ) {
        self.id = id; self.identifier = identifier; self.levelCode = levelCode
        self.sourceCode = sourceCode; self.materialType = materialType; self.unit = unit
        self.leadTime = leadTime; self.lotSizingRule = lotSizingRule
        self.lotSizingLookahead = lotSizingLookahead; self.annualDemand = annualDemand
        self.unitCost = unitCost; self.orderingCost = orderingCost
        self.annualHoldingCost = annualHoldingCost; self.description = description
        self.safetyStock = safetyStock; self.initialOnHand = initialOnHand
        self.scheduledReceipts = scheduledReceipts; self.capacity = capacity
        self.masterProductionSchedule = masterProductionSchedule
    }
}

struct MRPBillComponentDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var parentIdentifier: String
    var itemIdentifier: String
    var quantityPerParent: String

    init(id: UUID = UUID(), parentIdentifier: String, itemIdentifier: String, quantityPerParent: String = "1") {
        self.id = id; self.parentIdentifier = parentIdentifier
        self.itemIdentifier = itemIdentifier; self.quantityPerParent = quantityPerParent
    }
}

struct MaterialRequirementsPlanningDraft: Equatable, Sendable {
    private(set) var hasImportedDimensionIssue = false
    var title: String
    var timeUnit: String
    var periodsPerYear: String
    var bucketNames: [String]
    var items: [MRPItemDraft]
    var billComponents: [MRPBillComponentDraft]

    static let itemHeaders = [
        "Item", "Level", "Source", "Material Type", "Unit", "Lead Time", "Lot Sizing Rule",
        "Lookahead", "Annual Demand", "Unit Cost", "Ordering Cost", "Annual Holding Cost",
        "Description", "Safety Stock", "Initial On Hand"
    ]
    static let scheduleHeaders = ["Item", "Bucket", "Scheduled Receipt", "Capacity", "MPS"]
    static let billHeaders = ["Parent", "Component", "Quantity Per Parent"]

    private init(
        title: String, timeUnit: String, periodsPerYear: String, bucketNames: [String],
        items: [MRPItemDraft], billComponents: [MRPBillComponentDraft]
    ) {
        self.title = title; self.timeUnit = timeUnit; self.periodsPerYear = periodsPerYear
        self.bucketNames = bucketNames; self.items = items; self.billComponents = billComponents
    }

    static func blank() -> Self {
        let buckets = ["Overdue", "Period 1", "Period 2", "Period 3"]
        return Self(
            title: "New Material Requirements Plan", timeUnit: "Period", periodsPerYear: "12",
            bucketNames: buckets,
            items: [MRPItemDraft(
                identifier: "ITEM1", scheduledReceipts: Array(repeating: "0", count: buckets.count),
                capacity: Array(repeating: "", count: buckets.count),
                masterProductionSchedule: Array(repeating: "0", count: buckets.count)
            )],
            billComponents: []
        )
    }

    init(_ model: MaterialRequirementsPlanningModel) {
        title = model.title
        timeUnit = model.timeUnit
        periodsPerYear = String(model.periodsPerYear)
        let count = ([model.bucketNames.count] + model.items.flatMap { [$0.scheduledReceipts.count, $0.capacity.count] }
            + model.masterProductionSchedule.values.map(\.count)).max() ?? 0
        let knownIdentifiers = Set(model.items.map(\.identifier))
        let orphanIdentifiers = model.masterProductionSchedule.keys.filter { !knownIdentifiers.contains($0) }.sorted()
        hasImportedDimensionIssue = count != model.bucketNames.count
            || model.items.contains { $0.scheduledReceipts.count != count || $0.capacity.count != count }
            || model.masterProductionSchedule.values.contains { $0.count != count }
            || !orphanIdentifiers.isEmpty
        // Preserve every imported cell. Missing required receipts and period names
        // stay empty; blank capacity explicitly represents an unbounded period.
        bucketNames = model.bucketNames + Array(repeating: "", count: count - model.bucketNames.count)
        func padded(_ values: [String]) -> [String] {
            values + Array(repeating: "", count: count - values.count)
        }
        items = model.items.map { item in
            MRPItemDraft(
                identifier: item.identifier, levelCode: item.levelCode, sourceCode: item.sourceCode,
                materialType: item.materialType, unit: item.unit, leadTime: String(item.leadTime),
                lotSizingRule: item.lotSizingRule,
                lotSizingLookahead: item.lotSizingLookahead.map { String($0) } ?? "",
                annualDemand: String(item.annualDemand), unitCost: String(item.unitCost),
                orderingCost: String(item.orderingCost), annualHoldingCost: String(item.annualHoldingCost),
                description: item.description, safetyStock: String(item.safetyStock),
                initialOnHand: String(item.initialOnHand),
                scheduledReceipts: padded(item.scheduledReceipts.map { String($0) }),
                capacity: padded(item.capacity.map { $0.map { String($0) } ?? "" }),
                masterProductionSchedule: model.masterProductionSchedule[item.identifier].map { padded($0.map { String($0) }) }
            )
        }
        // Orphan MPS rows become incomplete native items instead of disappearing.
        // Required metadata stays blank so the user must supply it deliberately.
        for identifier in orphanIdentifiers {
            items.append(MRPItemDraft(identifier: identifier, levelCode: "", sourceCode: "", materialType: "", unit: "",
                leadTime: "", annualDemand: "", unitCost: "", orderingCost: "", annualHoldingCost: "",
                safetyStock: "", initialOnHand: "", scheduledReceipts: Array(repeating: "", count: count),
                capacity: Array(repeating: "", count: count),
                masterProductionSchedule: model.masterProductionSchedule[identifier].map { padded($0.map { String($0) }) }))
        }
        billComponents = model.billsOfMaterial.flatMap { bill in
            bill.components.map {
                MRPBillComponentDraft(
                    parentIdentifier: bill.parentIdentifier,
                    itemIdentifier: $0.itemIdentifier,
                    quantityPerParent: String($0.quantityPerParent)
                )
            }
        }
    }

    mutating func confirmImportedDimensions() { hasImportedDimensionIssue = false }

    func makeModel() throws -> MaterialRequirementsPlanningModel {
        guard !hasImportedDimensionIssue else { throw MaterialRequirementsPlanningDraftError.importedDimensions }
        try required(title, path: "model.title", label: "a plan title")
        try required(timeUnit, path: "model.timeUnit", label: "a time unit")
        let periods = try integer(periodsPerYear, path: "model.periodsPerYear", label: "periods per year")
        guard !bucketNames.isEmpty else {
            throw MaterialRequirementsPlanningDraftError.emptyField(path: "model.bucketNames", label: "at least one time bucket")
        }
        for (index, name) in bucketNames.enumerated() {
            try required(name, path: "model.bucketNames.\(index)", label: "a bucket name")
        }

        let modelItems = try items.enumerated().map { index, item in
            let base = "model.items.\(index)"
            try required(item.identifier, path: "\(base).identifier", label: "an item identifier")
            try required(item.unit, path: "\(base).unit", label: "a unit")
            guard item.scheduledReceipts.count == bucketNames.count, item.capacity.count == bucketNames.count,
                  item.masterProductionSchedule?.count == bucketNames.count || item.masterProductionSchedule == nil else {
                throw MaterialRequirementsPlanningDraftError.invalidInteger(
                    path: "\(base).schedule", label: "one schedule cell per bucket", value: "dimension mismatch"
                )
            }
            return MRPItem(
                identifier: item.identifier, levelCode: item.levelCode, sourceCode: item.sourceCode,
                materialType: item.materialType, unit: item.unit,
                leadTime: try integer(item.leadTime, path: "\(base).leadTime", label: "lead time"),
                lotSizingRule: item.lotSizingRule,
                lotSizingLookahead: try optionalInteger(item.lotSizingLookahead, path: "\(base).lotSizingLookahead", label: "lot-sizing lookahead"),
                annualDemand: try number(item.annualDemand, path: "\(base).annualDemand", label: "annual demand"),
                unitCost: try number(item.unitCost, path: "\(base).unitCost", label: "unit cost"),
                orderingCost: try number(item.orderingCost, path: "\(base).orderingCost", label: "ordering cost"),
                annualHoldingCost: try number(item.annualHoldingCost, path: "\(base).annualHoldingCost", label: "annual holding cost"),
                description: item.description,
                safetyStock: try number(item.safetyStock, path: "\(base).safetyStock", label: "safety stock"),
                initialOnHand: try number(item.initialOnHand, path: "\(base).initialOnHand", label: "initial on hand"),
                scheduledReceipts: try item.scheduledReceipts.enumerated().map {
                    try number($0.element, path: "\(base).scheduledReceipts.\($0.offset)", label: "scheduled receipt")
                },
                capacity: try item.capacity.enumerated().map {
                    try optionalNumber($0.element, path: "\(base).capacity.\($0.offset)", label: "capacity")
                }
            )
        }

        var grouped: [String: [MRPComponent]] = [:]
        var parentOrder: [String] = []
        for (index, row) in billComponents.enumerated() {
            let base = "model.billsOfMaterial.\(index)"
            try required(row.parentIdentifier, path: "\(base).parentIdentifier", label: "a parent item")
            try required(row.itemIdentifier, path: "\(base).itemIdentifier", label: "a component item")
            if grouped[row.parentIdentifier] == nil { parentOrder.append(row.parentIdentifier) }
            grouped[row.parentIdentifier, default: []].append(MRPComponent(
                itemIdentifier: row.itemIdentifier,
                quantityPerParent: try number(row.quantityPerParent, path: "\(base).quantityPerParent", label: "quantity per parent")
            ))
        }
        let bills = parentOrder.map { MRPBillOfMaterial(parentIdentifier: $0, components: grouped[$0] ?? []) }
        var mps: [String: [Double]] = [:]
        for item in items {
            guard let values = item.masterProductionSchedule else { continue }
            let numbers = try values.enumerated().map {
                try number($0.element, path: "model.masterProductionSchedule.\(item.identifier).\($0.offset)", label: "MPS quantity")
            }
            mps[item.identifier] = numbers
        }
        return MaterialRequirementsPlanningModel(
            title: title, timeUnit: timeUnit, periodsPerYear: periods, bucketNames: bucketNames,
            items: modelItems, billsOfMaterial: bills, masterProductionSchedule: mps
        )
    }

    func draftDiagnostics() -> [ValidationDiagnostic] {
        do {
            return MaterialRequirementsPlanningValidator.diagnostics(for: try makeModel())
        } catch let error as MaterialRequirementsPlanningDraftError {
            return [ValidationDiagnostic(
                severity: .error,
                code: "mrp.draft.\(error.path.replacingOccurrences(of: ".", with: "_"))",
                message: error.description,
                path: error.path
            )]
        } catch {
            return [ValidationDiagnostic(severity: .error, code: "mrp.draft.invalid", message: error.localizedDescription)]
        }
    }

    @discardableResult
    mutating func addItem() -> UUID {
        var suffix = items.count + 1
        var identifier = "ITEM\(suffix)"
        while items.contains(where: { $0.identifier == identifier }) {
            suffix += 1; identifier = "ITEM\(suffix)"
        }
        let item = MRPItemDraft(
            identifier: identifier, scheduledReceipts: Array(repeating: "0", count: bucketNames.count),
            capacity: Array(repeating: "", count: bucketNames.count)
        )
        items.append(item)
        return item.id
    }

    mutating func removeItem(id: UUID) {
        guard items.count > 1, let item = items.first(where: { $0.id == id }) else { return }
        items.removeAll { $0.id == id }
        billComponents.removeAll { $0.parentIdentifier == item.identifier || $0.itemIdentifier == item.identifier }
    }

    mutating func renameItem(id: UUID, to identifier: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let oldIdentifier = items[index].identifier
        items[index].identifier = identifier
        for rowIndex in billComponents.indices {
            if billComponents[rowIndex].parentIdentifier == oldIdentifier { billComponents[rowIndex].parentIdentifier = identifier }
            if billComponents[rowIndex].itemIdentifier == oldIdentifier { billComponents[rowIndex].itemIdentifier = identifier }
        }
    }

    @discardableResult
    mutating func addBucket() -> Int {
        let prefix = timeUnit.isEmpty ? "Period" : timeUnit
        var suffix = max(1, bucketNames.count)
        while bucketNames.contains("\(prefix) \(suffix)") { suffix += 1 }
        bucketNames.append("\(prefix) \(suffix)")
        for index in items.indices {
            items[index].scheduledReceipts.append("0")
            items[index].capacity.append("")
            items[index].masterProductionSchedule?.append("0")
        }
        return bucketNames.count - 1
    }

    mutating func removeBucket(at index: Int) {
        guard bucketNames.count > 1, bucketNames.indices.contains(index) else { return }
        bucketNames.remove(at: index)
        for itemIndex in items.indices {
            if items[itemIndex].scheduledReceipts.indices.contains(index) { items[itemIndex].scheduledReceipts.remove(at: index) }
            if items[itemIndex].capacity.indices.contains(index) { items[itemIndex].capacity.remove(at: index) }
            if items[itemIndex].masterProductionSchedule?.indices.contains(index) == true { items[itemIndex].masterProductionSchedule?.remove(at: index) }
        }
    }

    @discardableResult
    mutating func addBillComponent() -> UUID {
        let parent = items.first?.identifier ?? ""
        let component = items.dropFirst().first?.identifier ?? parent
        let row = MRPBillComponentDraft(parentIdentifier: parent, itemIdentifier: component)
        billComponents.append(row)
        return row.id
    }

    mutating func removeBillComponent(id: UUID) { billComponents.removeAll { $0.id == id } }

    func itemTabularText() -> String {
        ([Self.itemHeaders] + items.map { item in
            [item.identifier, item.levelCode, item.sourceCode, item.materialType, item.unit, item.leadTime,
             item.lotSizingRule.rawValue, item.lotSizingLookahead, item.annualDemand, item.unitCost,
             item.orderingCost, item.annualHoldingCost, item.description, item.safetyStock, item.initialOnHand]
        }).map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }

    mutating func replaceItems(withTabularText text: String) throws {
        var rows = try SpreadsheetTable(text: text).rows
        if rows.first?.map({ $0.lowercased() }) == Self.itemHeaders.map({ $0.lowercased() }) { rows.removeFirst() }
        guard !rows.isEmpty else { throw SpreadsheetTransferError.emptyClipboard }
        let existingGroups = Dictionary(grouping: items, by: \.identifier)
        let existingByIdentifier = existingGroups.compactMapValues { $0.count == 1 ? $0.first : nil }
        var seenIdentifiers: Set<String> = []
        var replacement: [MRPItemDraft] = []
        for (index, row) in rows.enumerated() {
            let displayRow = index + 1
            guard row.count == Self.itemHeaders.count else {
                throw SpreadsheetTransferError.inconsistentColumns(expected: Self.itemHeaders.count, actual: row.count, row: displayRow)
            }
            guard !row[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  seenIdentifiers.insert(row[0]).inserted else {
                throw SpreadsheetTransferError.invalidValue(row[0], column: "Unique item identifier", row: displayRow)
            }
            guard !row[4].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SpreadsheetTransferError.invalidValue(row[4], column: "Unit", row: displayRow)
            }
            guard let rule = MRPLotSizingRule(rawValue: row[6].uppercased()) else {
                throw SpreadsheetTransferError.invalidValue(row[6], column: "Lot Sizing Rule", row: displayRow)
            }
            guard Int(row[5]) != nil else { throw SpreadsheetTransferError.invalidValue(row[5], column: "Lead Time", row: displayRow) }
            if !row[7].isEmpty, Int(row[7]) == nil {
                throw SpreadsheetTransferError.invalidValue(row[7], column: "Lookahead", row: displayRow)
            }
            for column in [8, 9, 10, 11, 13, 14] {
                try SpreadsheetTable.requireFinite(row[column], column: Self.itemHeaders[column], row: displayRow)
            }
            let previous = existingByIdentifier[row[0]]
            replacement.append(MRPItemDraft(
                id: previous?.id ?? UUID(), identifier: row[0], levelCode: row[1], sourceCode: row[2],
                materialType: row[3], unit: row[4], leadTime: row[5], lotSizingRule: rule,
                lotSizingLookahead: row[7], annualDemand: row[8], unitCost: row[9], orderingCost: row[10],
                annualHoldingCost: row[11], description: row[12], safetyStock: row[13], initialOnHand: row[14],
                scheduledReceipts: previous?.scheduledReceipts ?? Array(repeating: "0", count: bucketNames.count),
                capacity: previous?.capacity ?? Array(repeating: "", count: bucketNames.count),
                masterProductionSchedule: previous?.masterProductionSchedule
            ))
        }
        // A valid section remains repairable while other fields are unfinished.
        items = replacement
    }

    func scheduleTabularText() -> String {
        var rows = [Self.scheduleHeaders]
        for item in items {
            for index in bucketNames.indices {
                rows.append([
                    item.identifier, bucketNames[index], item.scheduledReceipts.indices.contains(index) ? item.scheduledReceipts[index] : "", item.capacity.indices.contains(index) ? item.capacity[index] : "",
                    item.masterProductionSchedule.flatMap { $0.indices.contains(index) ? $0[index] : nil } ?? ""
                ])
            }
        }
        return rows.map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }

    mutating func replaceSchedules(withTabularText text: String) throws {
        var rows = try SpreadsheetTable(text: text).rows
        if rows.first?.map({ $0.lowercased() }) == Self.scheduleHeaders.map({ $0.lowercased() }) { rows.removeFirst() }
        guard !rows.isEmpty else { throw SpreadsheetTransferError.emptyClipboard }
        let identifiers = items.map(\.identifier)
        guard Set(identifiers).count == identifiers.count,
              identifiers.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              Set(bucketNames).count == bucketNames.count,
              bucketNames.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw SpreadsheetTransferError.invalidValue("Ambiguous labels", column: "Use unique, nonempty item and bucket names before pasting schedules", row: 1)
        }
        // A pair key cannot alias identifiers or bucket labels containing separator characters.
        struct ScheduleKey: Hashable { let item: String; let bucket: String }
        let expectedKeys = Set(items.flatMap { item in bucketNames.map { ScheduleKey(item: item.identifier, bucket: $0) } })
        var parsed: [ScheduleKey: (String, String, String)] = [:]
        for (index, row) in rows.enumerated() {
            let displayRow = index + 1
            guard row.count == Self.scheduleHeaders.count else {
                throw SpreadsheetTransferError.inconsistentColumns(expected: Self.scheduleHeaders.count, actual: row.count, row: displayRow)
            }
            let key = ScheduleKey(item: row[0], bucket: row[1])
            guard expectedKeys.contains(key), parsed[key] == nil else {
                throw SpreadsheetTransferError.invalidValue("\(row[0]) / \(row[1])", column: "Item / Bucket", row: displayRow)
            }
            try SpreadsheetTable.requireFinite(row[2], column: "Scheduled Receipt", row: displayRow)
            if !row[3].isEmpty { try SpreadsheetTable.requireFinite(row[3], column: "Capacity", row: displayRow) }
            if !row[4].isEmpty { try SpreadsheetTable.requireFinite(row[4], column: "MPS", row: displayRow) }
            parsed[key] = (row[2], row[3], row[4])
        }
        guard Set(parsed.keys) == expectedKeys else {
            throw SpreadsheetTransferError.inconsistentRows(expected: expectedKeys.count, actual: parsed.count)
        }
        var replacement = items
        for itemIndex in replacement.indices {
            let identifier = replacement[itemIndex].identifier
            let cells = try bucketNames.map { bucket in
                guard let values = parsed[ScheduleKey(item: identifier, bucket: bucket)] else {
                    throw SpreadsheetTransferError.invalidValue("\(identifier) / \(bucket)", column: "Missing item / bucket", row: itemIndex + 1)
                }
                return values
            }
            replacement[itemIndex].scheduledReceipts = cells.map(\.0)
            replacement[itemIndex].capacity = cells.map(\.1)
            replacement[itemIndex].masterProductionSchedule = cells.contains(where: { !$0.2.isEmpty }) ? cells.map { $0.2.isEmpty ? "0" : $0.2 } : nil
        }
        // A valid section remains repairable while other fields are unfinished.
        items = replacement
    }

    func billTabularText() -> String {
        ([Self.billHeaders] + billComponents.map { [$0.parentIdentifier, $0.itemIdentifier, $0.quantityPerParent] })
            .map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }

    mutating func replaceBillComponents(withTabularText text: String) throws {
        var rows = try SpreadsheetTable(text: text).rows
        if rows.first?.map({ $0.lowercased() }) == Self.billHeaders.map({ $0.lowercased() }) { rows.removeFirst() }
        var replacement: [MRPBillComponentDraft] = []
        struct BillKey: Hashable { let parent: String; let component: String }
        let existingRows = Dictionary(grouping: billComponents) {
            BillKey(parent: $0.parentIdentifier, component: $0.itemIdentifier)
        }
        var occurrences: [BillKey: Int] = [:]
        for (index, row) in rows.enumerated() {
            let displayRow = index + 1
            guard row.count == Self.billHeaders.count else {
                throw SpreadsheetTransferError.inconsistentColumns(expected: Self.billHeaders.count, actual: row.count, row: displayRow)
            }
            guard !row[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SpreadsheetTransferError.invalidValue(row[0], column: "Parent", row: displayRow) }
            guard !row[1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SpreadsheetTransferError.invalidValue(row[1], column: "Component", row: displayRow) }
            try SpreadsheetTable.requireFinite(row[2], column: "Quantity Per Parent", row: displayRow)
            let key = BillKey(parent: row[0], component: row[1])
            let occurrence = occurrences[key, default: 0]
            let previous = existingRows[key] ?? []
            // Repeated BOM relationships remain distinct rows with distinct identities.
            let identity = previous.indices.contains(occurrence) ? previous[occurrence].id : UUID()
            occurrences[key] = occurrence + 1
            replacement.append(MRPBillComponentDraft(id: identity, parentIdentifier: row[0], itemIdentifier: row[1], quantityPerParent: row[2]))
        }
        billComponents = replacement
    }

    private func required(_ value: String, path: String, label: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MaterialRequirementsPlanningDraftError.emptyField(path: path, label: label)
        }
    }

    private func number(_ value: String, path: String, label: String) throws -> Double {
        guard let number = Double(value), number.isFinite else {
            throw MaterialRequirementsPlanningDraftError.invalidNumber(path: path, label: label, value: value)
        }
        return number
    }

    private func optionalNumber(_ value: String, path: String, label: String) throws -> Double? {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : try number(value, path: path, label: label)
    }

    private func integer(_ value: String, path: String, label: String) throws -> Int {
        guard let integer = Int(value) else {
            throw MaterialRequirementsPlanningDraftError.invalidInteger(path: path, label: label, value: value)
        }
        return integer
    }

    private func optionalInteger(_ value: String, path: String, label: String) throws -> Int? {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : try integer(value, path: path, label: label)
    }
}
