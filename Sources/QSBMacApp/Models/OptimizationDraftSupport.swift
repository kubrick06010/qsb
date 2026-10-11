import Foundation
import QSBCore

enum OptimizationDraftError: Error, Equatable, CustomStringConvertible {
  case emptyField(path: String, label: String)
  case invalidNumber(path: String, label: String, value: String)
  case invalidInteger(path: String, label: String, value: String)
  case invalidType(path: String, value: String)
  case dimension(path: String)

  var path: String {
    switch self {
    case .emptyField(let path, _), .invalidNumber(let path, _, _), .invalidInteger(let path, _, _), .invalidType(let path, _),
      .dimension(let path):
      path
    }
  }
  var description: String {
    switch self {
    case .emptyField(_, let label): "Enter \(label)."
    case .invalidNumber(_, let label, let value):
      "Enter a finite number for \(label) (received ‘\(value)’)."
    case .invalidInteger(_, let label, let value):
      "Enter a whole number for \(label) (received ‘\(value)’)."
    case .invalidType(_, let value): "‘\(value)’ is not a supported variable type."
    case .dimension: "The variable, coefficient, and matrix dimensions are inconsistent."
    }
  }
}

struct OptimizationVariableDraft: Identifiable, Equatable, Sendable {
  let id: UUID
  var name: String
  var type: VariableType
  var lowerBound: String
  var upperBound: String
  init(
    id: UUID = UUID(), name: String, type: VariableType = .continuous, lowerBound: String = "0",
    upperBound: String = ""
  ) {
    self.id = id
    self.name = name
    self.type = type
    self.lowerBound = lowerBound
    self.upperBound = upperBound
  }
}

struct OptimizationConstraintDraft: Identifiable, Equatable, Sendable {
  let id: UUID
  var name: String
  var coefficients: [String]
  var relation: ConstraintRelation
  var rhs: String
  init(
    id: UUID = UUID(), name: String, coefficients: [String],
    relation: ConstraintRelation = .lessThanOrEqual, rhs: String = "0"
  ) {
    self.id = id
    self.name = name
    self.coefficients = coefficients
    self.relation = relation
    self.rhs = rhs
  }
}

func optimizationTable(headers: [String], rows: [[String]]) -> String {
  ([headers] + rows).map { $0.joined(separator: "\t") }.joined(separator: "\n")
}
func optimizationDataRows(_ text: String, header: String) throws -> [[String]] {
  var rows = try SpreadsheetTable(text: text).rows
  if rows.first?.first?.lowercased() == header { rows.removeFirst() }
  guard !rows.isEmpty else { throw SpreadsheetTransferError.emptyClipboard }
  return rows
}
