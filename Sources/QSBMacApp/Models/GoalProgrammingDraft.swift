import Foundation
import QSBCore

struct GoalDraft: Identifiable, Equatable, Sendable {
  let id: UUID
  var name: String
  var sense: ObjectiveSense
  var coefficients: [String]
  init(id: UUID = UUID(), name: String, sense: ObjectiveSense = .maximize, coefficients: [String]) {
    self.id = id
    self.name = name
    self.sense = sense
    self.coefficients = coefficients
  }
}
struct GoalProgrammingDraft: Equatable, Sendable {
  private(set) var hasImportedDimensionIssue = false
  var title: String
  var variables: [OptimizationVariableDraft]
  var goals: [GoalDraft]
  var constraints: [OptimizationConstraintDraft]
  private init(
    title: String, variables: [OptimizationVariableDraft], goals: [GoalDraft],
    constraints: [OptimizationConstraintDraft]
  ) {
    self.title = title
    self.variables = variables
    self.goals = goals
    self.constraints = constraints
  }
  static func blank() -> Self {
    Self(
      title: "New Goal Program",
      variables: [OptimizationVariableDraft(name: "x1", upperBound: "10")],
      goals: [GoalDraft(name: "Priority 1", coefficients: ["1"])], constraints: [])
  }
  init(_ model: GoalProgram) {
    let sourceCount = model.variableNames.count
    // Unnamed imported coefficients remain editable instead of being truncated.
    let n = [sourceCount, model.variableTypes.count, model.lowerBounds.count,
      model.upperBounds.count, model.goals.map { $0.coefficients.count }.max() ?? 0,
      model.constraints.map { $0.coefficients.count }.max() ?? 0].max() ?? 0
    hasImportedDimensionIssue = sourceCount != n ||
      model.variableTypes.count != n || model.lowerBounds.count != n || model.upperBounds.count != n
      || model.goals.contains { $0.coefficients.count != n }
      || model.constraints.contains { $0.coefficients.count != n }
    title = model.title
    variables = (0..<n).map {
      OptimizationVariableDraft(
        name: model.variableNames[safe: $0] ?? "", type: model.variableTypes[safe: $0] ?? .continuous,
        lowerBound: model.lowerBounds[safe: $0].map { String($0) } ?? "",
        upperBound: model.upperBounds[safe: $0]?.map { String($0) } ?? "")
    }
    goals = model.goals.map { goal in
      GoalDraft(
        name: goal.name, sense: goal.sense,
        coefficients: (0..<n).map { index in goal.coefficients[safe: index].map { String($0) } ?? ""
        })
    }
    constraints = model.constraints.map { constraint in
      OptimizationConstraintDraft(
        name: constraint.name,
        coefficients: (0..<n).map { index in
          constraint.coefficients[safe: index].map { String($0) } ?? ""
        }, relation: constraint.relation,
        rhs: String(constraint.rhs))
    }
  }
  mutating func confirmImportedDimensions() {
    // Review accepts displayed type and optional upper-bound defaults only.
    // Required lower bounds, names, and missing coefficients stay invalid.
    hasImportedDimensionIssue = false
  }
  func makeModel() throws -> GoalProgram {
    guard !hasImportedDimensionIssue else { throw OptimizationDraftError.dimension(path: "model") }
    try req(title, "model.title", "a model title")
    let n = variables.count
    guard n > 0, goals.allSatisfy({ $0.coefficients.count == n }),
      constraints.allSatisfy({ $0.coefficients.count == n })
    else { throw OptimizationDraftError.dimension(path: "model") }
    for (i, v) in variables.enumerated() {
      try req(v.name, "model.variableNames.\(i)", "a variable name")
    }
    return GoalProgram(
      title: title, variableNames: variables.map(\.name),
      goals: try goals.enumerated().map {
        try req($0.element.name, "model.goals.\($0.offset).name", "a goal name")
        return GoalObjective(
          name: $0.element.name, sense: $0.element.sense,
          coefficients: try nums($0.element.coefficients, "model.goals.\($0.offset).coefficients"))
      },
      constraints: try constraints.enumerated().map {
        try req($0.element.name, "model.constraints.\($0.offset).name", "a constraint name")
        return LinearConstraint(
          name: $0.element.name,
          coefficients: try nums(
            $0.element.coefficients, "model.constraints.\($0.offset).coefficients"),
          relation: $0.element.relation,
          rhs: try num($0.element.rhs, "model.constraints.\($0.offset).rhs", "right-hand side"))
      },
      lowerBounds: try variables.enumerated().map {
        try num($0.element.lowerBound, "model.lowerBounds.\($0.offset)", "lower bound")
      },
      upperBounds: try variables.enumerated().map {
        $0.element.upperBound.isEmpty
          ? nil : try num($0.element.upperBound, "model.upperBounds.\($0.offset)", "upper bound")
      }, variableTypes: variables.map(\.type))
  }
  func draftDiagnostics() -> [ValidationDiagnostic] {
    do { return GoalProgrammingValidator.diagnostics(for: try makeModel()) } catch let e
      as OptimizationDraftError
    {
      return [
        ValidationDiagnostic(
          severity: .error, code: "goal.draft.\(e.path.replacingOccurrences(of:".",with:"_"))",
          message: e.description, path: e.path)
      ]
    } catch {
      return [
        ValidationDiagnostic(
          severity: .error, code: "goal.draft.invalid", message: error.localizedDescription)
      ]
    }
  }
  @discardableResult mutating func addVariable() -> UUID {
    var index = variables.count + 1
    while variables.contains(where: { $0.name == "x\(index)" }) { index += 1 }
    let v = OptimizationVariableDraft(name: "x\(index)", upperBound: "10")
    variables.append(v)
    for i in goals.indices { goals[i].coefficients.append("0") }
    for i in constraints.indices { constraints[i].coefficients.append("0") }
    return v.id
  }
  mutating func removeVariable(id: UUID) {
    guard variables.count > 1, let i = variables.firstIndex(where: { $0.id == id }) else { return }
    variables.remove(at: i)
    for r in goals.indices { goals[r].coefficients.remove(at: i) }
    for r in constraints.indices { constraints[r].coefficients.remove(at: i) }
  }
  @discardableResult mutating func addGoal() -> UUID {
    let g = GoalDraft(
      name: "Priority \(goals.count+1)", coefficients: Array(repeating: "0", count: variables.count)
    )
    goals.append(g)
    return g.id
  }
  mutating func moveGoal(id: UUID, by offset: Int) {
    guard let index = goals.firstIndex(where: { $0.id == id }),
      goals.indices.contains(index + offset)
    else { return }
    let goal = goals.remove(at: index)
    goals.insert(goal, at: index + offset)
  }
  mutating func removeGoal(id: UUID) {
    guard goals.count > 1 else { return }
    goals.removeAll { $0.id == id }
  }
  @discardableResult mutating func addConstraint() -> UUID {
    let c = OptimizationConstraintDraft(
      name: "Constraint \(constraints.count+1)",
      coefficients: Array(repeating: "0", count: variables.count))
    constraints.append(c)
    return c.id
  }
  mutating func removeConstraint(id: UUID) { constraints.removeAll { $0.id == id } }
  func variablesTable() -> String {
    optimizationTable(
      headers: ["Variable", "Type", "Lower Bound", "Upper Bound"],
      rows: variables.map { [$0.name, $0.type.rawValue, $0.lowerBound, $0.upperBound] })
  }
  func goalsTable() -> String {
    optimizationTable(
      headers: ["Goal", "Sense"] + variables.map(\.name),
      rows: goals.map { [$0.name, $0.sense.rawValue] + $0.coefficients })
  }
  func constraintsTable() -> String {
    optimizationTable(
      headers: ["Constraint"] + variables.map(\.name) + ["Relation", "RHS"],
      rows: constraints.map { [$0.name] + $0.coefficients + [$0.relation.rawValue, $0.rhs] })
  }
  mutating func replaceVariables(with text: String) throws {
    let rows = try optimizationDataRows(text, header: "variable")
    let oldNameIndexes = Dictionary(grouping: variables.indices, by: { variables[$0].name })
    let pastedNameCounts = Dictionary(grouping: rows, by: { $0.first ?? "" }).mapValues(\.count)
    let indexes: [Int?] = rows.enumerated().map { index, row in
      let name = row.first ?? ""
      if let matches = oldNameIndexes[name], matches.count == 1, pastedNameCounts[name] == 1 {
        return matches[0]
      }
      return variables.indices.contains(index) && variables[index].name == name ? index : nil
    }
    let vals = try rows.enumerated().map { i, r in
      guard r.count == 4 else {
        throw SpreadsheetTransferError.inconsistentColumns(expected: 4, actual: r.count, row: i + 1)
      }
      guard let t = VariableType(rawValue: r[1]) else {
        throw SpreadsheetTransferError.invalidValue(r[1], column: "Type", row: i + 1)
      }
      guard !r[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw SpreadsheetTransferError.invalidValue(r[0], column: "Variable", row: i + 1)
      }
      try SpreadsheetTable.requireFinite(r[2], column: "Lower Bound", row: i + 1)
      if !r[3].isEmpty { try SpreadsheetTable.requireFinite(r[3], column: "Upper Bound", row: i + 1) }
      return OptimizationVariableDraft(id: indexes[i].map { variables[$0].id } ?? UUID(),
        name: r[0], type: t, lowerBound: r[2], upperBound: r[3])
    }
    guard !vals.isEmpty else { throw SpreadsheetTransferError.emptyClipboard }
    var candidate = self
    candidate.variables = vals
    for i in goals.indices {
      candidate.goals[i].coefficients = indexes.map { $0.map { goals[i].coefficients[$0] } ?? "0" }
    }
    for i in constraints.indices {
      candidate.constraints[i].coefficients = indexes.map {
        $0.map { constraints[i].coefficients[$0] } ?? "0"
      }
    }
    // An unfinished goal or constraint must not block a valid variable-table repair.
    candidate.hasImportedDimensionIssue = false
    self = candidate
  }
  mutating func replaceGoals(with text: String) throws {
    let rows = try alignedRows(
      text, headers: ["Goal", "Sense"] + variables.map(\.name), allowEmpty: false)
    let vals = try rows.enumerated().map { i, r in
      let e = variables.count + 2
      guard r.count == e else {
        throw SpreadsheetTransferError.inconsistentColumns(expected: e, actual: r.count, row: i + 1)
      }
      guard let s = ObjectiveSense(rawValue: r[1]) else {
        throw SpreadsheetTransferError.invalidValue(r[1], column: "Sense", row: i + 1)
      }
      for v in r.dropFirst(2) {
        try SpreadsheetTable.requireFinite(v, column: "Coefficient", row: i + 1)
      }
      guard !r[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw SpreadsheetTransferError.invalidValue(r[0], column: "Goal", row: i + 1)
      }
      return GoalDraft(name: r[0], sense: s, coefficients: Array(r.dropFirst(2)))
    }
    goals = vals
  }
  mutating func replaceConstraints(with text: String) throws {
    let rows = try alignedRows(
      text, headers: ["Constraint"] + variables.map(\.name) + ["Relation", "RHS"], allowEmpty: true)
    let vals = try rows.enumerated().map { i, r in
      let e = variables.count + 3
      guard r.count == e else {
        throw SpreadsheetTransferError.inconsistentColumns(expected: e, actual: r.count, row: i + 1)
      }
      guard let rel = ConstraintRelation(rawValue: r[variables.count + 1]) else {
        throw SpreadsheetTransferError.invalidValue(
          r[variables.count + 1], column: "Relation", row: i + 1)
      }
      for v in r.dropFirst().prefix(variables.count) {
        try SpreadsheetTable.requireFinite(v, column: "Coefficient", row: i + 1)
      }
      try SpreadsheetTable.requireFinite(r[variables.count + 2], column: "RHS", row: i + 1)
      guard !r[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw SpreadsheetTransferError.invalidValue(r[0], column: "Constraint", row: i + 1)
      }
      return OptimizationConstraintDraft(
        name: r[0], coefficients: Array(r.dropFirst().prefix(variables.count)), relation: rel,
        rhs: r[variables.count + 2])
    }
    constraints = vals
  }
  private func alignedRows(_ text: String, headers: [String], allowEmpty: Bool) throws -> [[String]]
  {
    var rows = try SpreadsheetTable(text: text).rows
    if rows.first?.first?.lowercased() == headers[0].lowercased() {
      guard rows.first == headers else {
        throw SpreadsheetTransferError.invalidValue(
          rows[0].joined(separator: ", "), column: "Headers in current variable order", row: 1)
      }
      rows.removeFirst()
    }
    guard allowEmpty || !rows.isEmpty else { throw SpreadsheetTransferError.emptyClipboard }
    return rows
  }
  private func req(_ v: String, _ p: String, _ l: String) throws {
    guard !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw OptimizationDraftError.emptyField(path: p, label: l)
    }
  }
  private func num(_ v: String, _ p: String, _ l: String) throws -> Double {
    guard let x = Double(v), x.isFinite else {
      throw OptimizationDraftError.invalidNumber(path: p, label: l, value: v)
    }
    return x
  }
  private func nums(_ a: [String], _ p: String) throws -> [Double] {
    try a.enumerated().map { try num($0.element, "\(p).\($0.offset)", "coefficient") }
  }
}

extension Collection {
  fileprivate subscript(safe index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
