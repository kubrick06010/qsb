import Foundation

public enum AggregatePlanningLegacyMethod: Int, Codable, Sendable {
    case simple = 0
    case transportation = 1
    case linearProgramming = 2
}

public struct AggregatePlanningModel: Codable, Equatable, Sendable {
    public let title: String
    public let method: AggregatePlanningLegacyMethod
    public let periodNames: [String]
    public let workforceUnit: String
    public let capacityUnit: String
    public let demand: [Double]
    public let initialWorkforce: Double?
    public let initialInventory: Double
    public let regularCapacity: [Double]
    public let regularCost: [Double]
    public let undertimeCost: [Double]
    public let overtimeCapacity: [Double]
    public let overtimeCost: [Double]
    public let hiringCost: [Double]
    public let dismissalCost: [Double]
    public let maximumWorkforce: [Double?]
    public let minimumWorkforce: [Double]
    public let maximumInventory: [Double?]
    public let minimumInventory: [Double]
    public let inventoryHoldingCost: [Double]
    public let maximumSubcontracting: [Double?]
    public let subcontractingCost: [Double]
    public let maximumBackorder: [Double?]
    public let backorderCost: [Double]
    public let otherUnitProductionCost: [Double]
    public let capacityRequirementPerUnit: [Double]
    public let capacityIsPerWorker: Bool

    public init(
        title: String,
        method: AggregatePlanningLegacyMethod,
        periodNames: [String],
        workforceUnit: String,
        capacityUnit: String,
        demand: [Double],
        initialWorkforce: Double?,
        initialInventory: Double,
        regularCapacity: [Double],
        regularCost: [Double],
        undertimeCost: [Double],
        overtimeCapacity: [Double],
        overtimeCost: [Double],
        hiringCost: [Double],
        dismissalCost: [Double],
        maximumWorkforce: [Double?],
        minimumWorkforce: [Double],
        maximumInventory: [Double?],
        minimumInventory: [Double],
        inventoryHoldingCost: [Double],
        maximumSubcontracting: [Double?],
        subcontractingCost: [Double],
        maximumBackorder: [Double?],
        backorderCost: [Double],
        otherUnitProductionCost: [Double],
        capacityRequirementPerUnit: [Double],
        capacityIsPerWorker: Bool
    ) {
        self.title = title
        self.method = method
        self.periodNames = periodNames
        self.workforceUnit = workforceUnit
        self.capacityUnit = capacityUnit
        self.demand = demand
        self.initialWorkforce = initialWorkforce
        self.initialInventory = initialInventory
        self.regularCapacity = regularCapacity
        self.regularCost = regularCost
        self.undertimeCost = undertimeCost
        self.overtimeCapacity = overtimeCapacity
        self.overtimeCost = overtimeCost
        self.hiringCost = hiringCost
        self.dismissalCost = dismissalCost
        self.maximumWorkforce = maximumWorkforce
        self.minimumWorkforce = minimumWorkforce
        self.maximumInventory = maximumInventory
        self.minimumInventory = minimumInventory
        self.inventoryHoldingCost = inventoryHoldingCost
        self.maximumSubcontracting = maximumSubcontracting
        self.subcontractingCost = subcontractingCost
        self.maximumBackorder = maximumBackorder
        self.backorderCost = backorderCost
        self.otherUnitProductionCost = otherUnitProductionCost
        self.capacityRequirementPerUnit = capacityRequirementPerUnit
        self.capacityIsPerWorker = capacityIsPerWorker
    }
}

public struct AggregatePlanningPeriodSolution: Codable, Equatable, Sendable {
    public let period: String
    public let workforce: Double?
    public let hired: Double
    public let dismissed: Double
    public let regularProduction: Double
    public let overtimeProduction: Double
    public let subcontracted: Double
    public let endingInventory: Double
    public let endingBackorder: Double
    public let unusedRegularCapacity: Double
}

public struct AggregatePlanningSolution: Codable, Equatable, Sendable {
    public let totalCost: Double
    public let periods: [AggregatePlanningPeriodSolution]
}

public struct AggregatePlanningSolutionDocument: Codable, Equatable, Sendable {
    public let backend: SolverRunMetadata
    public let model: AggregatePlanningModel
    public let solution: AggregatePlanningSolution
}

public struct AggregatePlanningValidationDocument: Codable, Equatable, Sendable {
    public let backend: SolverBackendKind
    public let isValid: Bool
    public let diagnostics: [ValidationDiagnostic]

    public init(backend: SolverBackendKind, diagnostics: [ValidationDiagnostic]) {
        self.backend = backend
        self.isValid = !diagnostics.contains { $0.severity == .error }
        self.diagnostics = diagnostics
    }
}

public enum AggregatePlanningError: Error, CustomStringConvertible {
    case unsupportedFormat
    case invalidModel(String)

    public var description: String {
        switch self {
        case .unsupportedFormat: "Unsupported aggregate-planning format"
        case .invalidModel(let message): "Invalid aggregate-planning model: \(message)"
        }
    }
}

public enum WinQSBAggregatePlanningParser {
    public static func parse(from data: Data) throws -> AggregatePlanningModel {
        guard let text = data.legacyLatin1String else {
            throw AggregatePlanningError.unsupportedFormat
        }
        let rows = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
        guard rows.count >= 6,
              rows[0].count >= 3,
              rows[0][0] == "AP",
              let methodValue = Int(rows[0][2]),
              let method = AggregatePlanningLegacyMethod(rawValue: methodValue),
              rows[1].count >= 4,
              let periodCount = Int(rows[1][0]),
              periodCount > 0,
              rows[3].count >= periodCount + 1 else {
            throw AggregatePlanningError.unsupportedFormat
        }

        let table = Dictionary(uniqueKeysWithValues: rows.dropFirst(4).map { row in
            (row[0].trimmingCharacters(in: .whitespacesAndNewlines), Array(row.dropFirst()))
        })
        let names = Array(rows[3].dropFirst().prefix(periodCount))
        let workforceUnit = rows[1][1]
        let capacityUnit = rows[1][2]
        let capacityIsPerWorker = table.keys.contains { $0.localizedCaseInsensitiveContains("per \(workforceUnit)") }

        func row(containing fragments: [String]) -> [String]? {
            table.first { key, _ in fragments.allSatisfy { key.localizedCaseInsensitiveContains($0) } }?.value
        }
        func values(_ fragments: [String], default fallback: Double = 0, propagate: Bool = false) throws -> [Double] {
            guard let raw = row(containing: fragments) else { return Array(repeating: fallback, count: periodCount) }
            var result: [Double] = []
            for index in 0..<periodCount {
                let value = index < raw.count ? raw[index].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                if value.isEmpty {
                    result.append(propagate ? (result.last ?? fallback) : fallback)
                } else if let number = Double(value), number.isFinite {
                    result.append(number)
                } else if value.lowercased() == "m" {
                    result.append(fallback)
                } else {
                    throw AggregatePlanningError.invalidModel("Invalid numeric value '\(value)'")
                }
            }
            return result
        }
        func maxima(_ fragments: [String], absentMeansZero: Bool = false) throws -> [Double?] {
            guard let raw = row(containing: fragments) else {
                return Array(repeating: absentMeansZero ? 0 : nil, count: periodCount)
            }
            return try (0..<periodCount).map { index in
                let value = index < raw.count ? raw[index].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                if value.isEmpty || value.lowercased() == "m" { return nil }
                guard let number = Double(value), number.isFinite else {
                    throw AggregatePlanningError.invalidModel("Invalid maximum '\(value)'")
                }
                return number
            }
        }
        func maxima(matchingAny candidates: [[String]], absentMeansZero: Bool = false) throws -> [Double?] {
            for fragments in candidates where row(containing: fragments) != nil {
                return try maxima(fragments, absentMeansZero: absentMeansZero)
            }
            return Array(repeating: absentMeansZero ? 0 : nil, count: periodCount)
        }

        let initialWorkforceValues = try values(["Initial Number"], propagate: true)
        let initialInventoryValues = try values(["Initial Inventory"])
        let regularCapacityFragments = capacityIsPerWorker ? ["Regular Time Capacity", "per"] : ["Regular Time Capacity"]
        let backorderRowExists = row(containing: ["Maximum Backorder"]) != nil
        let model = AggregatePlanningModel(
            title: rows[0][1],
            method: method,
            periodNames: names,
            workforceUnit: workforceUnit,
            capacityUnit: capacityUnit,
            demand: try values(["Forecast Demand"]),
            initialWorkforce: capacityIsPerWorker ? initialWorkforceValues.first : nil,
            initialInventory: initialInventoryValues.first ?? 0,
            regularCapacity: try values(regularCapacityFragments),
            regularCost: try values(["Regular Time Cost"]),
            undertimeCost: try values(["Undertime Cost"]),
            overtimeCapacity: try values(["Overtime Capacity"]),
            overtimeCost: try values(["Overtime Cost"]),
            hiringCost: try values(["Hiring Cost"]),
            dismissalCost: try values(["Dismissal Cost"]),
            maximumWorkforce: try maxima(["Maximum Number"]),
            minimumWorkforce: try values(["Minimum Number"]),
            maximumInventory: try maxima(["Maximum", "Inventory"]),
            minimumInventory: try values(["Minimum Ending Inventory"]),
            inventoryHoldingCost: try values(["Inventory Holding Cost"]),
            maximumSubcontracting: try maxima(matchingAny: [["Maximum Subcontracting"], ["Subcontracting Capacity"]]),
            subcontractingCost: try values(["Subcontracting Cost"]),
            maximumBackorder: try maxima(["Maximum Backorder"], absentMeansZero: !backorderRowExists),
            backorderCost: try values(["Backorder Cost"]),
            otherUnitProductionCost: try values(["Other Unit Production Cost"]),
            capacityRequirementPerUnit: try values(["Capacity Requirement"], default: 1, propagate: true),
            capacityIsPerWorker: capacityIsPerWorker
        )
        try AggregatePlanningValidator.validate(model)
        return model
    }
}

public enum AggregatePlanningValidator {
    public static func diagnostics(for model: AggregatePlanningModel) -> [ValidationDiagnostic] {
        let n = model.periodNames.count
        let arrays: [(String, Int)] = [
            ("demand", model.demand.count), ("regularCapacity", model.regularCapacity.count),
            ("regularCost", model.regularCost.count), ("undertimeCost", model.undertimeCost.count),
            ("overtimeCapacity", model.overtimeCapacity.count), ("overtimeCost", model.overtimeCost.count),
            ("hiringCost", model.hiringCost.count), ("dismissalCost", model.dismissalCost.count),
            ("maximumWorkforce", model.maximumWorkforce.count), ("minimumWorkforce", model.minimumWorkforce.count),
            ("maximumInventory", model.maximumInventory.count), ("minimumInventory", model.minimumInventory.count),
            ("inventoryHoldingCost", model.inventoryHoldingCost.count),
            ("maximumSubcontracting", model.maximumSubcontracting.count),
            ("subcontractingCost", model.subcontractingCost.count),
            ("maximumBackorder", model.maximumBackorder.count), ("backorderCost", model.backorderCost.count),
            ("otherUnitProductionCost", model.otherUnitProductionCost.count),
            ("capacityRequirementPerUnit", model.capacityRequirementPerUnit.count)
        ]
        var diagnostics: [ValidationDiagnostic] = []
        if n == 0 || arrays.contains(where: { $0.1 != n }) {
            diagnostics.append(error("dimension", "Every period vector must match periodNames.", "model"))
        }
        let finiteNonnegative = model.demand + model.regularCapacity + model.regularCost + model.undertimeCost
            + model.overtimeCapacity + model.overtimeCost + model.hiringCost + model.dismissalCost
            + model.minimumWorkforce + model.minimumInventory + model.inventoryHoldingCost
            + model.subcontractingCost + model.backorderCost + model.otherUnitProductionCost
        if finiteNonnegative.contains(where: { !$0.isFinite || $0 < 0 }) || !model.initialInventory.isFinite {
            diagnostics.append(error("values", "Costs, demand, capacities, and minima must be finite and nonnegative.", "model"))
        }
        if model.capacityRequirementPerUnit.contains(where: { !$0.isFinite || $0 <= 0 }) {
            diagnostics.append(error("capacityRequirement", "Capacity requirement per unit must be finite and positive.", "model.capacityRequirementPerUnit"))
        }
        if model.capacityIsPerWorker && (model.initialWorkforce == nil || !model.initialWorkforce!.isFinite || model.initialWorkforce! < 0) {
            diagnostics.append(error("initialWorkforce", "Workforce-based models require a nonnegative initial workforce.", "model.initialWorkforce"))
        }
        let optionalMaxima = model.maximumWorkforce + model.maximumInventory + model.maximumSubcontracting + model.maximumBackorder
        if optionalMaxima.compactMap({ $0 }).contains(where: { !$0.isFinite || $0 < 0 }) {
            diagnostics.append(error("maximumValues", "Optional maxima must be finite and nonnegative.", "model"))
        }
        for index in 0..<min(n, arrays.map(\.1).min() ?? 0) {
            if let maximum = model.maximumWorkforce[index], maximum < model.minimumWorkforce[index] {
                diagnostics.append(error("workforceBounds", "Maximum workforce is below its minimum.", "model.maximumWorkforce[\(index)]"))
            }
            if let maximum = model.maximumInventory[index], maximum < model.minimumInventory[index] {
                diagnostics.append(error("inventoryBounds", "Maximum inventory is below safety stock.", "model.maximumInventory[\(index)]"))
            }
        }
        if diagnostics.isEmpty {
            diagnostics.append(ValidationDiagnostic(severity: .info, code: "aggregatePlanning.valid", message: "Aggregate-planning model is valid"))
        }
        return diagnostics
    }

    public static func validate(_ model: AggregatePlanningModel) throws {
        if let diagnostic = diagnostics(for: model).first(where: { $0.severity == .error }) {
            throw AggregatePlanningError.invalidModel(diagnostic.message)
        }
    }

    private static func error(_ code: String, _ message: String, _ path: String) -> ValidationDiagnostic {
        ValidationDiagnostic(severity: .error, code: "aggregatePlanning.\(code)", message: message, path: path)
    }
}

public enum AggregatePlanningSolver {
    public static func solve(
        _ model: AggregatePlanningModel,
        linearProgrammingBackend: any LinearProgrammingBackend = NativeEducationalLinearProgrammingBackend(),
        options: SolverOptions = SolverOptions()
    ) throws -> AggregatePlanningSolution {
        try AggregatePlanningValidator.validate(model)
        let program = makeLinearProgram(model)
        let raw = try linearProgrammingBackend.solve(program, mode: .continuous, options: options)
        let periods = model.periodNames.indices.map { index in
            let requirement = model.capacityRequirementPerUnit[index]
            return AggregatePlanningPeriodSolution(
                period: model.periodNames[index],
                workforce: model.capacityIsPerWorker ? value("workforce", index, raw) : nil,
                hired: value("hired", index, raw),
                dismissed: value("dismissed", index, raw),
                regularProduction: value("regular", index, raw) / requirement,
                overtimeProduction: value("overtime", index, raw) / requirement,
                subcontracted: value("subcontract", index, raw),
                endingInventory: value("inventory", index, raw),
                endingBackorder: value("backorder", index, raw),
                unusedRegularCapacity: value("undertime", index, raw)
            )
        }
        return AggregatePlanningSolution(totalCost: raw.objectiveValue, periods: periods)
    }

    public static func makeLinearProgram(_ model: AggregatePlanningModel) -> LinearProgram {
        let n = model.periodNames.count
        let kinds = model.capacityIsPerWorker
            ? ["workforce", "hired", "dismissed", "regular", "undertime", "overtime", "subcontract", "inventory", "backorder"]
            : ["regular", "overtime", "subcontract", "inventory", "backorder"]
        let names = kinds.flatMap { kind in (0..<n).map { "\(kind)[\($0 + 1)]" } }
        let positions = Dictionary(uniqueKeysWithValues: names.enumerated().map { ($1, $0) })
        func position(_ kind: String, _ period: Int) -> Int { positions["\(kind)[\(period + 1)]"]! }
        var objective = Array(repeating: 0.0, count: names.count)
        var upper = Array<Double?>(repeating: nil, count: names.count)
        var lower = Array(repeating: 0.0, count: names.count)
        var constraints: [LinearConstraint] = []
        func coefficients(_ entries: [(String, Int, Double)]) -> [Double] {
            var row = Array(repeating: 0.0, count: names.count)
            for (kind, period, coefficient) in entries { row[position(kind, period)] += coefficient }
            return row
        }

        for period in 0..<n {
            let requirement = model.capacityRequirementPerUnit[period]
            objective[position("regular", period)] = model.regularCost[period] + model.otherUnitProductionCost[period] / requirement
            objective[position("overtime", period)] = model.overtimeCost[period] + model.otherUnitProductionCost[period] / requirement
            objective[position("subcontract", period)] = model.subcontractingCost[period]
            objective[position("inventory", period)] = model.inventoryHoldingCost[period]
            objective[position("backorder", period)] = model.backorderCost[period]
            lower[position("inventory", period)] = model.minimumInventory[period]
            upper[position("inventory", period)] = model.maximumInventory[period]
            upper[position("backorder", period)] = model.maximumBackorder[period]
            upper[position("subcontract", period)] = model.maximumSubcontracting[period]

            if model.capacityIsPerWorker {
                objective[position("hired", period)] = model.hiringCost[period]
                objective[position("dismissed", period)] = model.dismissalCost[period]
                objective[position("undertime", period)] = model.undertimeCost[period]
                lower[position("workforce", period)] = model.minimumWorkforce[period]
                upper[position("workforce", period)] = model.maximumWorkforce[period]
                var workforceEntries = [("workforce", period, 1.0), ("hired", period, -1.0), ("dismissed", period, 1.0)]
                var workforceRHS = model.initialWorkforce ?? 0
                if period > 0 {
                    workforceEntries.append(("workforce", period - 1, -1))
                    workforceRHS = 0
                }
                constraints.append(LinearConstraint(name: "workforce balance \(period + 1)", coefficients: coefficients(workforceEntries), relation: .equal, rhs: workforceRHS))
                constraints.append(LinearConstraint(name: "regular capacity \(period + 1)", coefficients: coefficients([("regular", period, 1), ("undertime", period, 1), ("workforce", period, -model.regularCapacity[period])]), relation: .equal, rhs: 0))
                constraints.append(LinearConstraint(name: "overtime capacity \(period + 1)", coefficients: coefficients([("overtime", period, 1), ("workforce", period, -model.overtimeCapacity[period])]), relation: .lessThanOrEqual, rhs: 0))
            } else {
                upper[position("regular", period)] = model.regularCapacity[period]
                upper[position("overtime", period)] = model.overtimeCapacity[period]
            }

            var balance = [("regular", period, 1 / requirement), ("overtime", period, 1 / requirement), ("subcontract", period, 1), ("inventory", period, -1), ("backorder", period, 1)]
            var rhs = model.demand[period]
            if period == 0 {
                rhs -= model.initialInventory
            } else {
                balance.append(("inventory", period - 1, 1))
                balance.append(("backorder", period - 1, -1))
            }
            constraints.append(LinearConstraint(name: "demand balance \(period + 1)", coefficients: coefficients(balance), relation: .equal, rhs: rhs))
        }
        return LinearProgram(title: model.title, sense: .minimize, variableNames: names, objectiveCoefficients: objective, constraints: constraints, lowerBounds: lower, upperBounds: upper)
    }

    private static func value(_ kind: String, _ period: Int, _ solution: LinearProgramSolution) -> Double {
        solution.variableValues["\(kind)[\(period + 1)]"] ?? 0
    }
}

public protocol AggregatePlanningBackend: Sendable {
    var capabilities: SolverCapabilities { get }
    func validationReport(for model: AggregatePlanningModel) -> ValidationReport
    func solve(_ model: AggregatePlanningModel, options: SolverOptions) throws -> AggregatePlanningSolution
    func runMetadata(for model: AggregatePlanningModel) -> SolverRunMetadata
}

public extension AggregatePlanningBackend {
    func validationReport(for model: AggregatePlanningModel) -> ValidationReport {
        ValidationReport(backend: capabilities.backendKind, diagnostics: AggregatePlanningValidator.diagnostics(for: model))
    }
    func solve(_ model: AggregatePlanningModel) throws -> AggregatePlanningSolution {
        try solve(model, options: SolverOptions())
    }
    func solutionDocument(for model: AggregatePlanningModel, solution: AggregatePlanningSolution) -> AggregatePlanningSolutionDocument {
        AggregatePlanningSolutionDocument(backend: runMetadata(for: model), model: model, solution: solution)
    }
}

public struct NativeEducationalAggregatePlanningBackend: AggregatePlanningBackend {
    public init() {}
    public var capabilities: SolverCapabilities {
        SolverCapabilities(backendKind: .nativeEducational, solves: true, validates: true, exportsStructuredSolution: true, notes: ["Routes the normalized planning formulation through LinearProgrammingBackend."])
    }
    public func solve(_ model: AggregatePlanningModel, options: SolverOptions = SolverOptions()) throws -> AggregatePlanningSolution {
        try AggregatePlanningSolver.solve(model, linearProgrammingBackend: NativeEducationalLinearProgrammingBackend(), options: options)
    }
    public func runMetadata(for _: AggregatePlanningModel) -> SolverRunMetadata {
        SolverRunMetadata(backendKind: .nativeEducational, algorithm: "continuousAggregatePlanningLP", exactness: .exact, notes: ["Continuous planning quantities; workforce is not constrained to integer values."])
    }
}

public struct ValidateOnlyAggregatePlanningBackend: AggregatePlanningBackend {
    public init() {}
    public var capabilities: SolverCapabilities {
        SolverCapabilities(backendKind: .validateOnly, solves: false, validates: true, exportsStructuredSolution: false)
    }
    public func solve(_ model: AggregatePlanningModel, options _: SolverOptions = SolverOptions()) throws -> AggregatePlanningSolution {
        throw AggregatePlanningError.invalidModel("validateOnly backend does not solve aggregate-planning models")
    }
    public func runMetadata(for _: AggregatePlanningModel) -> SolverRunMetadata {
        SolverRunMetadata(backendKind: .validateOnly, algorithm: "validationOnly", exactness: .exact)
    }
}

public enum AggregatePlanningBackends {
    public static func backend(for kind: SolverBackendKind) -> (any AggregatePlanningBackend)? {
        switch kind {
        case .nativeEducational: NativeEducationalAggregatePlanningBackend()
        case .validateOnly: ValidateOnlyAggregatePlanningBackend()
        case .externalHighPerformance: nil
        }
    }
}

public enum AggregatePlanningJSON {
    public static func encodeModel(_ model: AggregatePlanningModel) throws -> Data { try encoder.encode(model) }
    public static func decodeModel(from data: Data) throws -> AggregatePlanningModel { try JSONDecoder().decode(AggregatePlanningModel.self, from: data) }
    public static func encodeSolution(_ document: AggregatePlanningSolutionDocument) throws -> Data { try encoder.encode(document) }
    public static func decodeSolution(from data: Data) throws -> AggregatePlanningSolutionDocument { try JSONDecoder().decode(AggregatePlanningSolutionDocument.self, from: data) }
    public static func encodeValidation(_ document: AggregatePlanningValidationDocument) throws -> Data { try encoder.encode(document) }
    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
