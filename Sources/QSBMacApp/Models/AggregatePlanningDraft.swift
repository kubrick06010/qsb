import Foundation
import QSBCore

enum AggregatePlanningDraftError: Error, Equatable, CustomStringConvertible {
    case importedDimensions
    case emptyField(path: String, label: String)
    case invalidNumber(path: String, label: String, value: String)

    var path: String {
        switch self {
        case .importedDimensions: "model.periods"
        case .emptyField(let path, _), .invalidNumber(let path, _, _): path
        }
    }

    var description: String {
        switch self {
        case .importedDimensions: "Review the imported period dimensions before validating or running the plan."
        case .emptyField(_, let label): "Enter \(label)."
        case .invalidNumber(_, let label, let value): "Enter a finite number for \(label) (received ‘\(value)’)."
        }
    }
}

struct AggregatePlanningPeriodDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var demand: String
    var regularCapacity: String
    var regularCost: String
    var undertimeCost: String
    var overtimeCapacity: String
    var overtimeCost: String
    var hiringCost: String
    var dismissalCost: String
    var maximumWorkforce: String
    var minimumWorkforce: String
    var maximumInventory: String
    var minimumInventory: String
    var inventoryHoldingCost: String
    var maximumSubcontracting: String
    var subcontractingCost: String
    var maximumBackorder: String
    var backorderCost: String
    var otherUnitProductionCost: String
    var capacityRequirementPerUnit: String

    init(
        id: UUID = UUID(), name: String, demand: String = "0", regularCapacity: String = "0",
        regularCost: String = "0", undertimeCost: String = "0", overtimeCapacity: String = "0",
        overtimeCost: String = "0", hiringCost: String = "0", dismissalCost: String = "0",
        maximumWorkforce: String = "", minimumWorkforce: String = "0", maximumInventory: String = "",
        minimumInventory: String = "0", inventoryHoldingCost: String = "0", maximumSubcontracting: String = "",
        subcontractingCost: String = "0", maximumBackorder: String = "0", backorderCost: String = "0",
        otherUnitProductionCost: String = "0", capacityRequirementPerUnit: String = "1"
    ) {
        self.id = id; self.name = name; self.demand = demand; self.regularCapacity = regularCapacity
        self.regularCost = regularCost; self.undertimeCost = undertimeCost; self.overtimeCapacity = overtimeCapacity
        self.overtimeCost = overtimeCost; self.hiringCost = hiringCost; self.dismissalCost = dismissalCost
        self.maximumWorkforce = maximumWorkforce; self.minimumWorkforce = minimumWorkforce
        self.maximumInventory = maximumInventory; self.minimumInventory = minimumInventory
        self.inventoryHoldingCost = inventoryHoldingCost; self.maximumSubcontracting = maximumSubcontracting
        self.subcontractingCost = subcontractingCost; self.maximumBackorder = maximumBackorder
        self.backorderCost = backorderCost; self.otherUnitProductionCost = otherUnitProductionCost
        self.capacityRequirementPerUnit = capacityRequirementPerUnit
    }
}

struct AggregatePlanningDraft: Equatable, Sendable {
    var title: String
    var method: AggregatePlanningLegacyMethod
    var workforceUnit: String
    var capacityUnit: String
    var initialWorkforce: String
    var initialInventory: String
    var capacityIsPerWorker: Bool
    var periods: [AggregatePlanningPeriodDraft]
    private(set) var hasImportedDimensionIssue = false

    private init(
        title: String, method: AggregatePlanningLegacyMethod, workforceUnit: String,
        capacityUnit: String, initialWorkforce: String, initialInventory: String,
        capacityIsPerWorker: Bool, periods: [AggregatePlanningPeriodDraft]
    ) {
        self.title = title; self.method = method; self.workforceUnit = workforceUnit
        self.capacityUnit = capacityUnit; self.initialWorkforce = initialWorkforce
        self.initialInventory = initialInventory; self.capacityIsPerWorker = capacityIsPerWorker
        self.periods = periods
    }

    static func blank() -> Self {
        Self(
            title: "New Aggregate Plan", method: .linearProgramming,
            workforceUnit: "workers", capacityUnit: "units",
            initialWorkforce: "0", initialInventory: "0", capacityIsPerWorker: false,
            periods: [AggregatePlanningPeriodDraft(name: "Period 1", demand: "100", regularCapacity: "100", regularCost: "1")]
        )
    }

    init(_ model: AggregatePlanningModel) {
        title = model.title
        method = model.method
        workforceUnit = model.workforceUnit
        capacityUnit = model.capacityUnit
        initialWorkforce = model.initialWorkforce.map { String($0) } ?? ""
        initialInventory = String(model.initialInventory)
        capacityIsPerWorker = model.capacityIsPerWorker
        let counts: [Int] = [model.periodNames.count,
            model.demand.count, model.regularCapacity.count, model.regularCost.count, model.undertimeCost.count, model.overtimeCapacity.count, model.overtimeCost.count, model.hiringCost.count, model.dismissalCost.count, model.minimumWorkforce.count, model.minimumInventory.count, model.inventoryHoldingCost.count, model.subcontractingCost.count, model.backorderCost.count, model.otherUnitProductionCost.count, model.capacityRequirementPerUnit.count, model.maximumWorkforce.count, model.maximumInventory.count, model.maximumSubcontracting.count, model.maximumBackorder.count]
        let extent = counts.max() ?? 0
        hasImportedDimensionIssue = counts.contains { $0 != model.periodNames.count }
        // Retain unnamed values and expose missing required cells for native repair.
        // Optional maxima remain blank (unbounded), pending explicit dimension review.
        func value(_ values: [Double], _ index: Int) -> String {
            values.indices.contains(index) ? String(values[index]) : ""
        }
        func maximum(_ values: [Double?], _ index: Int) -> String {
            values.indices.contains(index) ? values[index].map { String($0) } ?? "" : ""
        }
        periods = (0..<extent).map { index in
            AggregatePlanningPeriodDraft(
                name: model.periodNames.indices.contains(index) ? model.periodNames[index] : "", demand: value(model.demand, index),
                regularCapacity: value(model.regularCapacity, index), regularCost: value(model.regularCost, index),
                undertimeCost: value(model.undertimeCost, index), overtimeCapacity: value(model.overtimeCapacity, index),
                overtimeCost: value(model.overtimeCost, index), hiringCost: value(model.hiringCost, index),
                dismissalCost: value(model.dismissalCost, index), maximumWorkforce: maximum(model.maximumWorkforce, index),
                minimumWorkforce: value(model.minimumWorkforce, index), maximumInventory: maximum(model.maximumInventory, index),
                minimumInventory: value(model.minimumInventory, index), inventoryHoldingCost: value(model.inventoryHoldingCost, index),
                maximumSubcontracting: maximum(model.maximumSubcontracting, index),
                subcontractingCost: value(model.subcontractingCost, index), maximumBackorder: maximum(model.maximumBackorder, index),
                backorderCost: value(model.backorderCost, index), otherUnitProductionCost: value(model.otherUnitProductionCost, index),
                capacityRequirementPerUnit: value(model.capacityRequirementPerUnit, index)
            )
        }
    }

    mutating func confirmImportedDimensions() { hasImportedDimensionIssue = false }

    func makeModel() throws -> AggregatePlanningModel {
        guard !hasImportedDimensionIssue else { throw AggregatePlanningDraftError.importedDimensions }
        try required(title, path: "model.title", label: "a plan title")
        try required(workforceUnit, path: "model.workforceUnit", label: "a workforce unit")
        try required(capacityUnit, path: "model.capacityUnit", label: "a capacity unit")
        let initial = try number(initialInventory, path: "model.initialInventory", label: "initial inventory")
        let workforce = capacityIsPerWorker
            ? try number(initialWorkforce, path: "model.initialWorkforce", label: "initial workforce")
            : nil
        for (index, period) in periods.enumerated() {
            try required(period.name, path: path(index, "name"), label: "a period name")
        }
        return AggregatePlanningModel(
            title: title, method: method, periodNames: periods.map(\.name), workforceUnit: workforceUnit,
            capacityUnit: capacityUnit, demand: try values(\.demand, "demand"), initialWorkforce: workforce,
            initialInventory: initial, regularCapacity: try values(\.regularCapacity, "regular capacity"),
            regularCost: try values(\.regularCost, "regular cost"), undertimeCost: try values(\.undertimeCost, "undertime cost"),
            overtimeCapacity: try values(\.overtimeCapacity, "overtime capacity"), overtimeCost: try values(\.overtimeCost, "overtime cost"),
            hiringCost: try values(\.hiringCost, "hiring cost"), dismissalCost: try values(\.dismissalCost, "dismissal cost"),
            maximumWorkforce: try optionalValues(\.maximumWorkforce, "maximum workforce"), minimumWorkforce: try values(\.minimumWorkforce, "minimum workforce"),
            maximumInventory: try optionalValues(\.maximumInventory, "maximum inventory"), minimumInventory: try values(\.minimumInventory, "minimum inventory"),
            inventoryHoldingCost: try values(\.inventoryHoldingCost, "inventory holding cost"),
            maximumSubcontracting: try optionalValues(\.maximumSubcontracting, "maximum subcontracting"), subcontractingCost: try values(\.subcontractingCost, "subcontracting cost"),
            maximumBackorder: try optionalValues(\.maximumBackorder, "maximum backorder"), backorderCost: try values(\.backorderCost, "backorder cost"),
            otherUnitProductionCost: try values(\.otherUnitProductionCost, "other unit production cost"),
            capacityRequirementPerUnit: try values(\.capacityRequirementPerUnit, "capacity requirement per unit"), capacityIsPerWorker: capacityIsPerWorker
        )
    }

    func draftDiagnostics() -> [ValidationDiagnostic] {
        do {
            return AggregatePlanningValidator.diagnostics(for: try makeModel())
        } catch let error as AggregatePlanningDraftError {
            return [ValidationDiagnostic(severity: .error, code: "aggregatePlanning.draft.\(error.path.replacingOccurrences(of: ".", with: "_"))", message: error.description, path: error.path)]
        } catch {
            return [ValidationDiagnostic(severity: .error, code: "aggregatePlanning.draft.invalid", message: error.localizedDescription)]
        }
    }

    @discardableResult
    mutating func addPeriod() -> UUID {
        let names = Set(periods.map(\.name))
        var number = periods.count + 1
        while names.contains("Period \(number)") { number += 1 }
        let period = AggregatePlanningPeriodDraft(name: "Period \(number)")
        periods.append(period)
        return period.id
    }

    mutating func removePeriod(id: UUID) {
        guard periods.count > 1 else { return }
        periods.removeAll { $0.id == id }
    }

    func tabularText() -> String {
        ([Self.headers] + periods.map(Self.cells)).map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }

    mutating func replacePeriods(withTabularText text: String) throws {
        var rows = try SpreadsheetTable(text: text).rows
        if rows.first?.map({ $0.lowercased() }) == Self.headers.map({ $0.lowercased() }) { rows.removeFirst() }
        guard !rows.isEmpty else { throw SpreadsheetTransferError.emptyClipboard }
        let existing = Dictionary(grouping: periods, by: \.name)
        let incoming = Dictionary(grouping: rows, by: { $0.first ?? "" })
        var replacement: [AggregatePlanningPeriodDraft] = []
        for (index, row) in rows.enumerated() {
            let displayRow = index + 1
            guard row.count == Self.headers.count else {
                throw SpreadsheetTransferError.inconsistentColumns(expected: Self.headers.count, actual: row.count, row: displayRow)
            }
            guard !row[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SpreadsheetTransferError.invalidValue(row[0], column: "Period", row: displayRow) }
            for column in 1..<row.count where !Self.optionalColumns.contains(column) || !row[column].isEmpty {
                try SpreadsheetTable.requireFinite(row[column], column: Self.headers[column], row: displayRow)
            }
            // Reuse identity only when a period name identifies one row on both sides.
            let id = existing[row[0]]?.count == 1 && incoming[row[0]]?.count == 1
                ? existing[row[0]]?.first?.id : nil
            replacement.append(Self.period(from: row, id: id ?? UUID()))
        }
        periods = replacement
    }

    static let headers = [
        "Period", "Demand", "Regular Capacity", "Regular Cost", "Undertime Cost",
        "Overtime Capacity", "Overtime Cost", "Hiring Cost", "Dismissal Cost",
        "Maximum Workforce", "Minimum Workforce", "Maximum Inventory", "Minimum Inventory",
        "Inventory Holding Cost", "Maximum Subcontracting", "Subcontracting Cost",
        "Maximum Backorder", "Backorder Cost", "Other Unit Production Cost", "Capacity Requirement Per Unit"
    ]
    private static let optionalColumns: Set<Int> = [9, 11, 14, 16]

    private static func cells(_ period: AggregatePlanningPeriodDraft) -> [String] {
        [period.name, period.demand, period.regularCapacity, period.regularCost, period.undertimeCost,
         period.overtimeCapacity, period.overtimeCost, period.hiringCost, period.dismissalCost,
         period.maximumWorkforce, period.minimumWorkforce, period.maximumInventory, period.minimumInventory,
         period.inventoryHoldingCost, period.maximumSubcontracting, period.subcontractingCost,
         period.maximumBackorder, period.backorderCost, period.otherUnitProductionCost, period.capacityRequirementPerUnit]
    }

    private static func period(from cells: [String], id: UUID) -> AggregatePlanningPeriodDraft {
        AggregatePlanningPeriodDraft(
            id: id, name: cells[0], demand: cells[1], regularCapacity: cells[2], regularCost: cells[3], undertimeCost: cells[4],
            overtimeCapacity: cells[5], overtimeCost: cells[6], hiringCost: cells[7], dismissalCost: cells[8],
            maximumWorkforce: cells[9], minimumWorkforce: cells[10], maximumInventory: cells[11], minimumInventory: cells[12],
            inventoryHoldingCost: cells[13], maximumSubcontracting: cells[14], subcontractingCost: cells[15],
            maximumBackorder: cells[16], backorderCost: cells[17], otherUnitProductionCost: cells[18], capacityRequirementPerUnit: cells[19]
        )
    }

    private func values(_ keyPath: KeyPath<AggregatePlanningPeriodDraft, String>, _ label: String) throws -> [Double] {
        try periods.enumerated().map { try number($0.element[keyPath: keyPath], path: path($0.offset, label.replacingOccurrences(of: " ", with: "")), label: label) }
    }

    private func optionalValues(_ keyPath: KeyPath<AggregatePlanningPeriodDraft, String>, _ label: String) throws -> [Double?] {
        try periods.enumerated().map { index, period in
            let raw = period[keyPath: keyPath].trimmingCharacters(in: .whitespacesAndNewlines)
            return raw.isEmpty ? nil : try number(raw, path: path(index, label.replacingOccurrences(of: " ", with: "")), label: label)
        }
    }

    private func required(_ value: String, path: String, label: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AggregatePlanningDraftError.emptyField(path: path, label: label)
        }
    }

    private func number(_ value: String, path: String, label: String) throws -> Double {
        guard let number = Double(value), number.isFinite else {
            throw AggregatePlanningDraftError.invalidNumber(path: path, label: label, value: value)
        }
        return number
    }

    private func path(_ index: Int, _ field: String) -> String { "model.periods.\(index).\(field)" }
}
