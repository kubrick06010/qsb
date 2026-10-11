import Foundation
import QSBCore

struct NonlinearVariableDraft: Identifiable, Equatable, Sendable {
  let id: UUID
  var name: String
  var lowerBound: String
  var upperBound: String
  init(id: UUID = UUID(), name: String, lowerBound: String = "0", upperBound: String = "10") {
    self.id = id
    self.name = name
    self.lowerBound = lowerBound
    self.upperBound = upperBound
  }
}
struct NonlinearConstraintDraft: Identifiable, Equatable, Sendable {
  let id: UUID
  var name: String
  var expression: String
  var relation: NonlinearConstraintRelation
  var rhs: String
  init(
    id: UUID = UUID(), name: String, expression: String = "0",
    relation: NonlinearConstraintRelation = .lessThanOrEqual, rhs: String = "0"
  ) {
    self.id = id
    self.name = name
    self.expression = expression
    self.relation = relation
    self.rhs = rhs
  }
}

struct NonlinearProgrammingDraft: Equatable, Sendable {
  var title: String
  var sense: ObjectiveSense
  var objectiveExpression: String
  var variables: [NonlinearVariableDraft]
  var constraints: [NonlinearConstraintDraft]
  var normalizedStrictInequalities: Bool
  private(set) var hasImportedDimensionIssue = false
  private init(
    title: String, sense: ObjectiveSense, objectiveExpression: String,
    variables: [NonlinearVariableDraft], constraints: [NonlinearConstraintDraft],
    normalizedStrictInequalities: Bool
  ) {
    self.title = title
    self.sense = sense
    self.objectiveExpression = objectiveExpression
    self.variables = variables
    self.constraints = constraints
    self.normalizedStrictInequalities = normalizedStrictInequalities
  }
  static func blank() -> Self {
    Self(
      title: "New Nonlinear Program", sense: .minimize, objectiveExpression: "(x1 - 3)^2",
      variables: [NonlinearVariableDraft(name: "x1")], constraints: [],
      normalizedStrictInequalities: false)
  }
  init(_ model: NonlinearProgram) {
    hasImportedDimensionIssue =
      model.lowerBounds.count != model.variableNames.count
      || model.upperBounds.count != model.variableNames.count
    title = model.title
    sense = model.sense
    objectiveExpression = model.objectiveExpression
    // Bounds beyond named variables must remain available for native repair.
    let count = max(model.variableNames.count, model.lowerBounds.count, model.upperBounds.count)
    variables = (0..<count).map {
      NonlinearVariableDraft(
        name: model.variableNames[safe: $0] ?? "",
        lowerBound: model.lowerBounds[safe: $0]?.map { String($0) } ?? "",
        upperBound: model.upperBounds[safe: $0]?.map { String($0) } ?? "")
    }
    constraints = model.constraints.map {
      NonlinearConstraintDraft(
        name: $0.name, expression: $0.expression, relation: $0.relation, rhs: String($0.rhs))
    }
    normalizedStrictInequalities = model.normalizedStrictInequalities
  }
  mutating func confirmImportedDimensions() {
    // Accept missing bound cells as unbounded only after explicit review.
    // Missing names and invalid bound text still require repair.
    hasImportedDimensionIssue = false
  }
  func makeModel() throws -> NonlinearProgram {
    guard !hasImportedDimensionIssue else { throw OptimizationDraftError.dimension(path: "model") }
    try require(title, "model.title", "a model title")
    try require(objectiveExpression, "model.objectiveExpression", "an objective expression")
    for (i, v) in variables.enumerated() {
      try require(v.name, "model.variableNames.\(i)", "a variable name")
    }
    return NonlinearProgram(
      title: title, sense: sense, objectiveExpression: objectiveExpression,
      variableNames: variables.map(\.name),
      lowerBounds: try variables.enumerated().map {
        try optional($0.element.lowerBound, "model.lowerBounds.\($0.offset)", "lower bound")
      },
      upperBounds: try variables.enumerated().map {
        try optional($0.element.upperBound, "model.upperBounds.\($0.offset)", "upper bound")
      },
      constraints: try constraints.enumerated().map {
        try require($0.element.name, "model.constraints.\($0.offset).name", "a constraint name")
        try require(
          $0.element.expression, "model.constraints.\($0.offset).expression",
          "a constraint expression")
        return NonlinearConstraint(
          name: $0.element.name, expression: $0.element.expression, relation: $0.element.relation,
          rhs: try number($0.element.rhs, "model.constraints.\($0.offset).rhs", "right-hand side"))
      }, normalizedStrictInequalities: normalizedStrictInequalities)
  }
  func draftDiagnostics() -> [ValidationDiagnostic] {
    if hasImportedDimensionIssue {
      return [ValidationDiagnostic(severity: .error, code: "nlp.draft.model",
        message: "Review the imported variable names and bounds, then accept the displayed dimensions.", path: "model")]
    }
    do { return NonlinearProgramValidator.diagnostics(for: try makeModel()) } catch let e
      as OptimizationDraftError
    {
      return [
        ValidationDiagnostic(
          severity: .error, code: "nlp.draft.\(e.path.replacingOccurrences(of:".",with:"_"))",
          message: e.description, path: e.path)
      ]
    } catch {
      return [
        ValidationDiagnostic(
          severity: .error, code: "nlp.draft.invalid", message: error.localizedDescription)
      ]
    }
  }
  @discardableResult mutating func addVariable() -> UUID {
    var index = variables.count + 1
    while variables.contains(where: { $0.name == "x\(index)" }) { index += 1 }
    let v = NonlinearVariableDraft(name: "x\(index)")
    variables.append(v)
    return v.id
  }
  mutating func removeVariable(id: UUID) {
    guard variables.count > 1 else { return }
    variables.removeAll { $0.id == id }
  }
  @discardableResult mutating func addConstraint() -> UUID {
    let c = NonlinearConstraintDraft(name: "Constraint \(constraints.count+1)")
    constraints.append(c)
    return c.id
  }
  mutating func removeConstraint(id: UUID) { constraints.removeAll { $0.id == id } }
  func variablesTable() -> String {
    optimizationTable(
      headers: ["Variable", "Lower Bound", "Upper Bound"],
      rows: variables.map { [$0.name, $0.lowerBound, $0.upperBound] })
  }
  func constraintsTable() -> String {
    optimizationTable(
      headers: ["Constraint", "Expression", "Relation", "RHS"],
      rows: constraints.map { [$0.name, $0.expression, $0.relation.rawValue, $0.rhs] })
  }
  mutating func replaceVariables(with text: String) throws {
    var rows = try SpreadsheetTable(text: text).rows
    if rows.first?.map({ $0.lowercased() }) == ["variable", "lower bound", "upper bound"] { rows.removeFirst() }
    guard !rows.isEmpty else { throw SpreadsheetTransferError.emptyClipboard }
    let existing = Dictionary(grouping: variables, by: \.name)
    let incoming = Dictionary(grouping: rows, by: { $0.first ?? "" })
    let values = try rows.enumerated().map { index, row in
      guard row.count == 3 else {
        throw SpreadsheetTransferError.inconsistentColumns(
          expected: 3, actual: row.count, row: index + 1)
      }
      for value in row.dropFirst() where !value.isEmpty {
        try SpreadsheetTable.requireFinite(value, column: "Bound", row: index + 1)
      }
      try require(row[0], "model.variableNames.\(index)", "a variable name")
      let id = existing[row[0]]?.count == 1 && incoming[row[0]]?.count == 1
        ? existing[row[0]]?.first?.id : nil
      return NonlinearVariableDraft(id: id ?? UUID(), name: row[0], lowerBound: row[1], upperBound: row[2])
    }
    var c = self
    c.variables = values
    // An explicit replacement supplies a complete bound row for every variable.
    c.hasImportedDimensionIssue = false
    self = c
  }
  mutating func replaceConstraints(with text: String) throws {
    var rows = try SpreadsheetTable(text: text).rows
    if rows.first?.map({ $0.lowercased() }) == ["constraint", "expression", "relation", "rhs"] { rows.removeFirst() }
    let existing = Dictionary(grouping: constraints, by: \.name)
    let incoming = Dictionary(grouping: rows, by: { $0.first ?? "" })
    let values = try rows.enumerated().map { index, row in
      guard row.count == 4 else {
        throw SpreadsheetTransferError.inconsistentColumns(
          expected: 4, actual: row.count, row: index + 1)
      }
      guard let relation = NonlinearConstraintRelation(rawValue: row[2]) else {
        throw SpreadsheetTransferError.invalidValue(row[2], column: "Relation", row: index + 1)
      }
      try SpreadsheetTable.requireFinite(row[3], column: "RHS", row: index + 1)
      try require(row[0], "model.constraints.\(index).name", "a constraint name")
      try require(row[1], "model.constraints.\(index).expression", "a constraint expression")
      let id = existing[row[0]]?.count == 1 && incoming[row[0]]?.count == 1
        ? existing[row[0]]?.first?.id : nil
      return NonlinearConstraintDraft(
        id: id ?? UUID(), name: row[0], expression: row[1], relation: relation, rhs: row[3])
    }
    constraints = values
  }
  private func require(_ v: String, _ p: String, _ l: String) throws {
    guard !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw OptimizationDraftError.emptyField(path: p, label: l)
    }
  }
  private func number(_ v: String, _ p: String, _ l: String) throws -> Double {
    guard let x = Double(v), x.isFinite else {
      throw OptimizationDraftError.invalidNumber(path: p, label: l, value: v)
    }
    return x
  }
  private func optional(_ v: String, _ p: String, _ l: String) throws -> Double? {
    v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : try number(v, p, l)
  }
}

extension Collection {
  fileprivate subscript(safe index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
