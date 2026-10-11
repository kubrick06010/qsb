import Foundation
import QSBCore

struct QuadraticProgrammingDraft: Equatable, Sendable {
  var title: String
  var sense: ObjectiveSense
  var variables: [OptimizationVariableDraft]
  var linearCoefficients: [String]
  var quadraticMatrix: [[String]]
  var constraints: [OptimizationConstraintDraft]
  private(set) var hasImportedDimensionIssue = false

  private init(
    title: String, sense: ObjectiveSense, variables: [OptimizationVariableDraft],
    linearCoefficients: [String], quadraticMatrix: [[String]],
    constraints: [OptimizationConstraintDraft]
  ) {
    self.title = title
    self.sense = sense
    self.variables = variables
    self.linearCoefficients = linearCoefficients
    self.quadraticMatrix = quadraticMatrix
    self.constraints = constraints
  }

  static func blank() -> Self {
    Self(
      title: "New Quadratic Program", sense: .minimize,
      variables: [OptimizationVariableDraft(name: "x1", upperBound: "10")],
      linearCoefficients: ["0"], quadraticMatrix: [["1"]], constraints: [])
  }

  init(_ model: QuadraticProgram) {
    title = model.title
    sense = model.sense
    let sourceCount = model.variableNames.count
    // Retain coefficients beyond the named variables instead of truncating them.
    // Unnamed variables and missing numeric cells require explicit user repair.
    let n = [sourceCount, model.variableTypes.count, model.lowerBounds.count,
      model.upperBounds.count, model.linearCoefficients.count, model.quadraticMatrix.count,
      model.quadraticMatrix.map(\.count).max() ?? 0,
      model.constraints.map { $0.coefficients.count }.max() ?? 0].max() ?? 0
    hasImportedDimensionIssue = sourceCount != n || model.variableTypes.count != n || model.lowerBounds.count != n
      || model.upperBounds.count != n || model.linearCoefficients.count != n
      || model.quadraticMatrix.count != n || model.quadraticMatrix.contains { $0.count != n }
      || model.constraints.contains { $0.coefficients.count != n }
    variables = (0..<n).map { index in
      OptimizationVariableDraft(
        name: model.variableNames[safe: index] ?? "", type: model.variableTypes[safe: index] ?? .continuous,
        lowerBound: (model.lowerBounds[safe: index] ?? nil).map(Self.format) ?? "",
        upperBound: (model.upperBounds[safe: index] ?? nil).map(Self.format) ?? ""
      )
    }
    linearCoefficients = (0..<n).map { model.linearCoefficients[safe: $0].map(Self.format) ?? "" }
    quadraticMatrix = (0..<n).map { row in
      (0..<n).map { model.quadraticMatrix[safe: row]?[safe: $0].map(Self.format) ?? "" }
    }
    constraints = model.constraints.map { constraint in
      OptimizationConstraintDraft(
        name: constraint.name,
        coefficients: (0..<n).map { constraint.coefficients[safe: $0].map(Self.format) ?? "" },
        relation: constraint.relation, rhs: Self.format(constraint.rhs))
    }
  }

  mutating func confirmImportedDimensions() {
    // This explicit editor action accepts displayed type/bound defaults only;
    // empty names and missing coefficients still fail conversion and validation.
    hasImportedDimensionIssue = false
  }

  func makeModel() throws -> QuadraticProgram {
    guard !hasImportedDimensionIssue else { throw OptimizationDraftError.dimension(path: "model") }
    try required(title, path: "model.title", label: "a model title")
    let n = variables.count
    guard n > 0, linearCoefficients.count == n, quadraticMatrix.count == n,
      quadraticMatrix.allSatisfy({ $0.count == n }),
      constraints.allSatisfy({ $0.coefficients.count == n })
    else { throw OptimizationDraftError.dimension(path: "model") }
    for (index, variable) in variables.enumerated() {
      try required(variable.name, path: "model.variableNames.\(index)", label: "a variable name")
    }
    return QuadraticProgram(
      title: title, sense: sense, variableNames: variables.map(\.name),
      linearCoefficients: try linearCoefficients.enumerated().map {
        try number(
          $0.element, path: "model.linearCoefficients.\($0.offset)", label: "linear coefficient")
      },
      quadraticMatrix: try quadraticMatrix.enumerated().map { row in
        try row.element.enumerated().map {
          try number(
            $0.element, path: "model.quadraticMatrix.\(row.offset).\($0.offset)",
            label: "quadratic coefficient")
        }
      },
      constraints: try constraints.enumerated().map { row in
        try makeConstraint(row.element, index: row.offset)
      },
      lowerBounds: try variables.enumerated().map {
        try optionalNumber(
          $0.element.lowerBound, path: "model.lowerBounds.\($0.offset)", label: "lower bound")
      },
      upperBounds: try variables.enumerated().map {
        try optionalNumber(
          $0.element.upperBound, path: "model.upperBounds.\($0.offset)", label: "upper bound")
      },
      variableTypes: variables.map(\.type)
    )
  }

  func draftDiagnostics() -> [ValidationDiagnostic] {
    diagnostics(validator: { QuadraticProgramValidator.diagnostics(for: $0) })
  }

  @discardableResult mutating func addVariable() -> UUID {
    var suffix = 1
    let names = Set(variables.map(\.name))
    while names.contains("x\(suffix)") { suffix += 1 }
    let variable = OptimizationVariableDraft(name: "x\(suffix)", upperBound: "10")
    variables.append(variable)
    linearCoefficients.append("0")
    for index in quadraticMatrix.indices { quadraticMatrix[index].append("0") }
    quadraticMatrix.append(Array(repeating: "0", count: variables.count))
    quadraticMatrix[variables.count - 1][variables.count - 1] = sense == .minimize ? "1" : "-1"
    for index in constraints.indices { constraints[index].coefficients.append("0") }
    return variable.id
  }
  mutating func removeVariable(id: UUID) {
    guard variables.count > 1, let index = variables.firstIndex(where: { $0.id == id }) else {
      return
    }
    variables.remove(at: index)
    linearCoefficients.remove(at: index)
    quadraticMatrix.remove(at: index)
    for row in quadraticMatrix.indices { quadraticMatrix[row].remove(at: index) }
    for row in constraints.indices { constraints[row].coefficients.remove(at: index) }
  }
  @discardableResult mutating func addConstraint() -> UUID {
    let row = OptimizationConstraintDraft(
      name: "Constraint \(constraints.count + 1)",
      coefficients: Array(repeating: "0", count: variables.count))
    constraints.append(row)
    return row.id
  }
  mutating func removeConstraint(id: UUID) { constraints.removeAll { $0.id == id } }

  func variablesTable() -> String {
    let rows = variables.indices.map {
      [
        variables[$0].name, variables[$0].type.rawValue, variables[$0].lowerBound,
        variables[$0].upperBound, linearCoefficients[$0],
      ]
    }
    return optimizationTable(
      headers: ["Variable", "Type", "Lower Bound", "Upper Bound", "Linear Coefficient"], rows: rows)
  }
  func quadraticTable() -> String {
    optimizationTable(
      headers: ["Variable"] + variables.map(\.name),
      rows: variables.indices.map { [variables[$0].name] + quadraticMatrix[$0] })
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
      // Duplicate invalid names cannot identify a reorder. Preserve matching
      // positions without giving two displayed rows the same focus identity.
      return variables.indices.contains(index) && variables[index].name == name ? index : nil
    }
    var replacement: [OptimizationVariableDraft] = []
    var linear: [String] = []
    for (index, row) in rows.enumerated() {
      guard row.count == 5 else {
        throw SpreadsheetTransferError.inconsistentColumns(
          expected: 5, actual: row.count, row: index + 1)
      }
      guard let type = VariableType(rawValue: row[1]) else {
        throw SpreadsheetTransferError.invalidValue(row[1], column: "Type", row: index + 1)
      }
      guard !row[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw SpreadsheetTransferError.invalidValue(row[0], column: "Variable", row: index + 1)
      }
      try SpreadsheetTable.requireFinite(row[4], column: "Linear Coefficient", row: index + 1)
      for column in [2, 3] where !row[column].isEmpty {
        try SpreadsheetTable.requireFinite(
          row[column], column: ["Lower Bound", "Upper Bound", "Linear Coefficient"][column - 2],
          row: index + 1)
      }
      replacement.append(
        OptimizationVariableDraft(id: indexes[index].map { variables[$0].id } ?? UUID(), name: row[0], type: type, lowerBound: row[2], upperBound: row[3]))
      linear.append(row[4])
    }
    guard !replacement.isEmpty else { throw SpreadsheetTransferError.emptyClipboard }
    var candidate = self
    candidate.variables = replacement
    candidate.linearCoefficients = linear
    // Preserve both axes when spreadsheet rows reorder existing variables.
    candidate.quadraticMatrix = indexes.enumerated().map { row, oldRow in
      indexes.enumerated().map { column, oldColumn in
        if let oldRow, let oldColumn { return quadraticMatrix[oldRow][oldColumn] }
        return row == column ? (sense == .minimize ? "1" : "-1") : "0"
      }
    }
    candidate.constraints = constraints.map { old in
      var next = old
      next.coefficients = indexes.map { $0.map { old.coefficients[$0] } ?? "0" }
      return next
    }
    // Validate this pasted section independently so another unfinished section
    // cannot prevent repair. QSBCore still validates the resulting whole model.
    candidate.hasImportedDimensionIssue = false
    self = candidate
  }
  mutating func replaceQuadratic(with text: String) throws {
    let rows = try alignedRows(text, leading: "Variable", trailing: [], variables: variables.map(\.name))
    guard rows.count == variables.count else {
      throw SpreadsheetTransferError.inconsistentRows(expected: variables.count, actual: rows.count)
    }
    var matrix: [[String]] = []
    for (index, row) in rows.enumerated() {
      guard row.count == variables.count + 1 else {
        throw SpreadsheetTransferError.inconsistentColumns(
          expected: variables.count + 1, actual: row.count, row: index + 1)
      }
      guard row[0] == variables[index].name else {
        throw SpreadsheetTransferError.invalidValue(row[0], column: "Variable (expected \(variables[index].name))", row: index + 1)
      }
      for value in row.dropFirst() {
        try SpreadsheetTable.requireFinite(value, column: "Quadratic coefficient", row: index + 1)
      }
      matrix.append(Array(row.dropFirst()))
    }
    quadraticMatrix = matrix
  }
  mutating func replaceConstraints(with text: String) throws {
    let rows = try alignedRows(text, leading: "Constraint", trailing: ["Relation", "RHS"], variables: variables.map(\.name))
    var replacement: [OptimizationConstraintDraft] = []
    for (index, row) in rows.enumerated() {
      let expected = variables.count + 3
      guard row.count == expected else {
        throw SpreadsheetTransferError.inconsistentColumns(
          expected: expected, actual: row.count, row: index + 1)
      }
      guard let relation = ConstraintRelation(rawValue: row[variables.count + 1]) else {
        throw SpreadsheetTransferError.invalidValue(
          row[variables.count + 1], column: "Relation", row: index + 1)
      }
      for value in row[1...variables.count] {
        try SpreadsheetTable.requireFinite(value, column: "Coefficient", row: index + 1)
      }
      try SpreadsheetTable.requireFinite(row[variables.count + 2], column: "RHS", row: index + 1)
      guard !row[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw SpreadsheetTransferError.invalidValue(row[0], column: "Constraint", row: index + 1)
      }
      replacement.append(
        OptimizationConstraintDraft(
          name: row[0], coefficients: Array(row[1...variables.count]), relation: relation,
          rhs: row[variables.count + 2]))
    }
    constraints = replacement
  }

  private func makeConstraint(_ value: OptimizationConstraintDraft, index: Int) throws
    -> LinearConstraint
  {
    try required(value.name, path: "model.constraints.\(index).name", label: "a constraint name")
    return LinearConstraint(
      name: value.name,
      coefficients: try value.coefficients.enumerated().map {
        try number(
          $0.element, path: "model.constraints.\(index).coefficients.\($0.offset)",
          label: "constraint coefficient")
      }, relation: value.relation,
      rhs: try number(
        value.rhs, path: "model.constraints.\(index).rhs", label: "constraint right-hand side"))
  }
  private func diagnostics(validator: (QuadraticProgram) -> [ValidationDiagnostic])
    -> [ValidationDiagnostic]
  {
    do { return validator(try makeModel()) } catch let error as OptimizationDraftError {
      return [
        ValidationDiagnostic(
          severity: .error, code: "qp.draft.\(error.path.replacingOccurrences(of: ".", with: "_"))",
          message: error.description, path: error.path)
      ]
    } catch {
      return [
        ValidationDiagnostic(
          severity: .error, code: "qp.draft.invalid", message: error.localizedDescription)
      ]
    }
  }
  private func required(_ value: String, path: String, label: String) throws {
    guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw OptimizationDraftError.emptyField(path: path, label: label)
    }
  }
  private func number(_ value: String, path: String, label: String) throws -> Double {
    guard let result = Double(value), result.isFinite else {
      throw OptimizationDraftError.invalidNumber(path: path, label: label, value: value)
    }
    return result
  }
  private func optionalNumber(_ value: String, path: String, label: String) throws -> Double? {
    value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? nil : try number(value, path: path, label: label)
  }
  private static func format(_ value: Double) -> String { String(value) }
}

private extension Collection {
  subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}

private func alignedRows(_ text: String, leading: String, trailing: [String], variables: [String]) throws -> [[String]] {
    var rows = try SpreadsheetTable(text: text).rows
    if rows.first?.first?.lowercased() == leading.lowercased() {
        let headers = rows.removeFirst()
        let expected = [leading] + variables + trailing
        guard headers == expected else {
            throw SpreadsheetTransferError.invalidValue(headers.joined(separator: ", "), column: "Headers (expected \(expected.joined(separator: ", ")))", row: 1)
        }
    }
    return rows
}
