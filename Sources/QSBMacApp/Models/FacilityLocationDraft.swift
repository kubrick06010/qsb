import Foundation
import QSBCore

struct LocationFacilityDraft: Identifiable, Equatable, Sendable {
  let id: UUID
  var sourceID: String
  var name: String
  var isNew: Bool
  var x: String
  var y: String
  init(
    id: UUID = UUID(), sourceID: String, name: String, isNew: Bool, x: String = "", y: String = ""
  ) {
    self.id = id
    self.sourceID = sourceID
    self.name = name
    self.isNew = isNew
    self.x = x
    self.y = y
  }
  var columnLabel: String { "\(isNew ? "New" : "Existing") [\(sourceID)] \(name)" }

}

struct FacilityLocationDraft: Equatable, Sendable {
  var title: String
  var distanceMeasure: FacilityLocationDistanceMeasure
  var objective: String
  var facilities: [LocationFacilityDraft]
  var interactions: [[String]]
  private var hasImportedDimensionIssue = false

  static func blank() -> Self {
    Self(
      FacilityLocationProblem(
        title: "New Facility Location", distanceMeasure: .rectilinear, objective: "MIN",
        facilities: [
          FacilityLocationFacility(
            id: 1, name: "Existing 1", isNew: false, x: 0, y: 0, interactionCosts: [nil, 1]),
          FacilityLocationFacility(
            id: 2, name: "New Facility", isNew: true, x: nil, y: nil, interactionCosts: [nil, nil]),
        ]))
  }
  init(_ problem: FacilityLocationProblem) {
    title = problem.title
    distanceMeasure = problem.distanceMeasure
    objective = problem.objective
    facilities = problem.facilities.map {
      LocationFacilityDraft(
        sourceID: String($0.id), name: $0.name, isNew: $0.isNew,
        x: $0.x.map { String($0) } ?? "", y: $0.y.map { String($0) } ?? "")
    }
    let n = facilities.count
    hasImportedDimensionIssue = problem.facilities.contains { $0.interactionCosts.count != n }
    interactions = problem.facilities.map { row in
      (0..<n).map { index in
        guard row.interactionCosts.indices.contains(index) else { return "" }
        return row.interactionCosts[index].map { String($0) } ?? ""
      }
    }
  }
  func makeProblem() throws -> FacilityLocationProblem {
    guard !hasImportedDimensionIssue, interactions.count == facilities.count,
      interactions.allSatisfy({ $0.count == facilities.count })
    else { throw OptimizationDraftError.dimension(path: "facilities") }
    guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw OptimizationDraftError.emptyField(path: "title", label: "a model title")
    }
    return FacilityLocationProblem(
      title: title, distanceMeasure: distanceMeasure, objective: objective,
      facilities: try facilities.enumerated().map { index, row in
        guard let sourceID = Int(row.sourceID) else {
          throw OptimizationDraftError.invalidNumber(
            path: "facilities.\(index).id", label: "facility ID", value: row.sourceID)
        }
        guard !row.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          throw OptimizationDraftError.emptyField(
            path: "facilities.\(index).name", label: "a facility name")
        }
        return FacilityLocationFacility(
          id: sourceID, name: row.name, isNew: row.isNew,
          x: try number(row.x, path: "facilities.\(index).x"),
          y: try number(row.y, path: "facilities.\(index).y"),
          interactionCosts: try interactions[index].enumerated().map {
            try number($0.element, path: "facilities.\(index).interactionCosts.\($0.offset)")
          })
      })
  }
  func draftDiagnostics() -> [ValidationDiagnostic] {
    do { return FacilityLocationValidator.diagnostics(for: try makeProblem()) } catch let error
      as OptimizationDraftError
    {
      return [
        ValidationDiagnostic(
          severity: .error, code: "location.draft.invalid", message: error.description,
          path: error.path)
      ]
    } catch {
      return [
        ValidationDiagnostic(
          severity: .error, code: "location.draft.invalid", message: String(describing: error))
      ]
    }
  }
  @discardableResult mutating func addFacility() -> UUID {
    var number = facilities.count + 1
    while facilities.contains(where: {
      $0.sourceID == String(number) || $0.name == "Facility \(number)"
    }) { number += 1 }
    let row = LocationFacilityDraft(
      sourceID: String(number), name: "Facility \(number)", isNew: false, x: "0", y: "0")
    facilities.append(row)
    for index in interactions.indices { interactions[index].append("") }
    interactions.append(Array(repeating: "", count: facilities.count))
    return row.id
  }
  mutating func removeFacility(id: UUID) {
    guard facilities.count > 1, let index = facilities.firstIndex(where: { $0.id == id }) else {
      return
    }
    facilities.remove(at: index)
    interactions.remove(at: index)
    for row in interactions.indices { interactions[row].remove(at: index) }
  }
  func facilitiesTable() -> String {
    optimizationTable(
      headers: ["ID", "Facility", "New", "X", "Y"],
      rows: facilities.map { [$0.sourceID, $0.name, $0.isNew ? "true" : "false", $0.x, $0.y] })
  }
  func interactionsTable() -> String {
    optimizationTable(
      headers: ["Facility"] + facilities.map(\.columnLabel),
      rows: facilities.enumerated().map { [$0.element.columnLabel] + interactions[$0.offset] })
  }
  mutating func replaceFacilities(with text: String) throws {
    var rows = try SpreadsheetTable(text: text).rows
    if rows.first == ["ID", "Facility", "New", "X", "Y"] { rows.removeFirst() }
    guard !rows.isEmpty else { throw SpreadsheetTransferError.emptyClipboard }
    let values = try rows.enumerated().map { index, row in
      guard row.count == 5 else {
        throw SpreadsheetTransferError.inconsistentColumns(
          expected: 5, actual: row.count, row: index + 1)
      }
      guard ["true", "false"].contains(row[2].lowercased()) else {
        throw SpreadsheetTransferError.invalidValue(
          row[2], column: "New (true/false)", row: index + 1)
      }
      return LocationFacilityDraft(
        sourceID: row[0], name: row[1], isNew: row[2].lowercased() == "true", x: row[3], y: row[4])
    }
    var candidate = self
    // Names retain row identity when roles change; scoped IDs retain it when names change.
    let indices = values.map { value in
      (facilities.filter { $0.name == value.name }.count == 1 && values.filter { $0.name == value.name }.count == 1
        ? facilities.firstIndex { $0.name == value.name } : nil)
        ?? facilities.firstIndex { Int($0.sourceID) == Int(value.sourceID) && $0.isNew == value.isNew }
    }
    candidate.facilities = values.enumerated().map { index, value in
      LocationFacilityDraft(id: indices[index].map { facilities[$0].id } ?? value.id,
        sourceID: value.sourceID, name: value.name, isNew: value.isNew, x: value.x, y: value.y)
    }
    // Facility IDs scoped by existing/new role carry both matrix axes across spreadsheet reordering and renaming.
    candidate.interactions = indices.map { row in
      indices.map { column in
        if let row, let column { return interactions[row][column] }
        return ""
      }
    }
    let problem = try candidate.makeProblem()
    if let diagnostic = FacilityLocationValidator.diagnostics(for: problem).first(where: { $0.code == "facilities.location.ids.duplicate" }) {
      throw SpreadsheetTransferError.invalidValue(diagnostic.message, column: "Facility IDs", row: 1)
    }
    self = candidate
  }
  mutating func replaceInteractions(with text: String) throws {
    var rows = try SpreadsheetTable(text: text).rows
    let names = facilities.map(\.name)
    let labels = facilities.map(\.columnLabel)
    let uniqueNames = Set(names).count == names.count
    var rowLabels = labels
    if rows.first?.first == "Facility" {
      if uniqueNames, rows.first == ["Facility"] + names { rowLabels = names }
      guard rows.first == ["Facility"] + rowLabels else {
        throw SpreadsheetTransferError.invalidValue(
          rows[0].joined(separator: ", "), column: "Headers in current facility order (include role and ID when names repeat)", row: 1)
      }
      rows.removeFirst()
    }
    guard rows.count == facilities.count else {
      throw SpreadsheetTransferError.inconsistentRows(
        expected: facilities.count, actual: rows.count)
    }
    let values = try rows.enumerated().map { index, row in
      guard row.count == facilities.count + 1 else {
        throw SpreadsheetTransferError.inconsistentColumns(
          expected: facilities.count + 1, actual: row.count, row: index + 1)
      }
      guard row[0] == rowLabels[index] || (uniqueNames && row[0] == names[index]) else {
        throw SpreadsheetTransferError.invalidValue(
          row[0], column: "Facility row name", row: index + 1)
      }
      for (column, value) in row.dropFirst().enumerated() where !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        try SpreadsheetTable.requireFinite(value, column: "Destination \(column + 1)", row: index + 1)
      }
      return Array(row.dropFirst())
    }
    var candidate = self
    candidate.interactions = values
    candidate.hasImportedDimensionIssue = false
    // Check the pasted matrix independently so unfinished geometry or coordinates
    // remain repairable. Core validation still gates the complete model.
    self = candidate
  }
  private func number(_ value: String, path: String) throws -> Double? {
    guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    guard let number = Double(value), number.isFinite else {
      throw OptimizationDraftError.invalidNumber(
        path: path, label: "coordinate or interaction weight", value: value)
    }
    return number
  }
}
