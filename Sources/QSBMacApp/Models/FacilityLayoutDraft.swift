import Foundation
import QSBCore

struct LayoutRectangleDraft: Identifiable, Equatable, Sendable {
  let id: UUID
  var startRow: String
  var startColumn: String
  var endRow: String
  var endColumn: String
  init(
    id: UUID = UUID(), startRow: String = "1", startColumn: String = "1", endRow: String = "1",
    endColumn: String = "1"
  ) {
    self.id = id
    self.startRow = startRow
    self.startColumn = startColumn
    self.endRow = endRow
    self.endColumn = endColumn
  }
}
struct LayoutDepartmentDraft: Identifiable, Equatable, Sendable {
  let id: UUID
  var sourceID: String
  var name: String
  var fixed: Bool
  var rectangles: [LayoutRectangleDraft]
  init(
    id: UUID = UUID(), sourceID: String, name: String, fixed: Bool = false,
    rectangles: [LayoutRectangleDraft] = []
  ) {
    self.id = id
    self.sourceID = sourceID
    self.name = name
    self.fixed = fixed
    self.rectangles = rectangles
  }
  var columnLabel: String { "[\(sourceID)] \(name)" }
}
struct FacilityLayoutDraft: Equatable, Sendable {
  var title: String
  var rowCount: String
  var columnCount: String
  var objective: String
  var departments: [LayoutDepartmentDraft]
  var costs: [[String]]
  private var hasImportedDimensionIssue = false
  static func blank() -> Self {
    Self(
      FacilityLayoutProblem(
        title: "New Facility Layout", rowCount: 1, columnCount: 2, objective: "MIN",
        departments: [
          FacilityLayoutDepartment(
            id: 1, name: "Department 1", fixed: false, flowUnitCosts: [nil, 1],
            initialLayout: [.init(startRow: 1, startColumn: 1, endRow: 1, endColumn: 1)]),
          FacilityLayoutDepartment(
            id: 2, name: "Department 2", fixed: false, flowUnitCosts: [nil, nil],
            initialLayout: [.init(startRow: 1, startColumn: 2, endRow: 1, endColumn: 2)]),
        ]))
  }
  init(_ problem: FacilityLayoutProblem) {
    title = problem.title
    rowCount = String(problem.rowCount)
    columnCount = String(problem.columnCount)
    objective = problem.objective
    departments = problem.departments.map { row in
      LayoutDepartmentDraft(
        sourceID: String(row.id), name: row.name, fixed: row.fixed,
        rectangles: row.initialLayout.map {
          LayoutRectangleDraft(
            startRow: String($0.startRow), startColumn: String($0.startColumn),
            endRow: String($0.endRow), endColumn: String($0.endColumn))
        })
    }
    let n = departments.count
    hasImportedDimensionIssue = problem.departments.contains { $0.flowUnitCosts.count != n }
    costs = problem.departments.map { row in
      (0..<n).map { index in
        guard row.flowUnitCosts.indices.contains(index) else { return "" }
        return row.flowUnitCosts[index].map { String($0) } ?? ""
      }
    }
  }
  func makeProblem() throws -> FacilityLayoutProblem {
    guard !hasImportedDimensionIssue, costs.count == departments.count,
      costs.allSatisfy({ $0.count == departments.count })
    else { throw OptimizationDraftError.dimension(path: "departments") }
    guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw OptimizationDraftError.emptyField(path: "title", label: "a model title")
    }
    return FacilityLayoutProblem(
      title: title, rowCount: try integer(rowCount, "rowCount", "grid rows"),
      columnCount: try integer(columnCount, "columnCount", "grid columns"), objective: objective,
      departments: try departments.enumerated().map { index, department in
        guard !department.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          throw OptimizationDraftError.emptyField(
            path: "departments.\(index).name", label: "a department name")
        }
        return FacilityLayoutDepartment(
          id: try integer(department.sourceID, "departments.\(index).id", "department ID"),
          name: department.name, fixed: department.fixed,
          flowUnitCosts: try costs[index].enumerated().map { column, value in
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
            guard let number = Double(value), number.isFinite else {
              throw OptimizationDraftError.invalidNumber(
                path: "departments.\(index).flowUnitCosts.\(column)", label: "flow/unit cost",
                value: value)
            }
            return number
          },
          initialLayout: try department.rectangles.enumerated().map { offset, rect in
            let path = "departments.\(index).initialLayout.\(offset)"
            return FacilityLayoutRect(
              startRow: try integer(rect.startRow, path + ".startRow", "start row"),
              startColumn: try integer(rect.startColumn, path + ".startColumn", "start column"),
              endRow: try integer(rect.endRow, path + ".endRow", "end row"),
              endColumn: try integer(rect.endColumn, path + ".endColumn", "end column"))
          })
      })
  }
  func draftDiagnostics() -> [ValidationDiagnostic] {
    do { return FacilityLayoutValidator.diagnostics(for: try makeProblem()) } catch let error
      as OptimizationDraftError
    {
      return [
        ValidationDiagnostic(
          severity: .error, code: "layout.draft.invalid", message: error.description,
          path: error.path)
      ]
    } catch {
      return [
        ValidationDiagnostic(
          severity: .error, code: "layout.draft.invalid", message: String(describing: error))
      ]
    }
  }
  @discardableResult mutating func addDepartment() -> UUID {
    var number = departments.count + 1
    while departments.contains(where: { Int($0.sourceID) == number }) { number += 1 }
    let row = LayoutDepartmentDraft(
      sourceID: String(number), name: "Department \(number)", rectangles: [LayoutRectangleDraft()])
    departments.append(row)
    for i in costs.indices { costs[i].append("") }
    costs.append(Array(repeating: "", count: departments.count))
    return row.id
  }
  mutating func removeDepartment(id: UUID) {
    guard departments.count > 1, let index = departments.firstIndex(where: { $0.id == id }) else {
      return
    }
    departments.remove(at: index)
    costs.remove(at: index)
    for i in costs.indices { costs[i].remove(at: index) }
  }
  @discardableResult mutating func addRectangle(departmentID: UUID) -> UUID? {
    guard let i = departments.firstIndex(where: { $0.id == departmentID }) else { return nil }
    let rectangle = LayoutRectangleDraft()
    departments[i].rectangles.append(rectangle)
    return rectangle.id
  }
  mutating func removeRectangle(departmentID: UUID, id: UUID) {
    guard let i = departments.firstIndex(where: { $0.id == departmentID }) else { return }
    departments[i].rectangles.removeAll { $0.id == id }
  }
  func departmentsTable() -> String {
    optimizationTable(
      headers: ["ID", "Department", "Fixed"],
      rows: departments.map { [$0.sourceID, $0.name, $0.fixed ? "true" : "false"] })
  }
  func rectanglesTable() -> String {
    optimizationTable(
      headers: ["Department ID", "Start Row", "Start Column", "End Row", "End Column"],
      rows: departments.flatMap { department in
        department.rectangles.map {
          [department.sourceID, $0.startRow, $0.startColumn, $0.endRow, $0.endColumn]
        }
      })
  }
  func costsTable() -> String {
    optimizationTable(
      headers: ["Department"] + departments.map(\.columnLabel),
      rows: departments.enumerated().map { [$0.element.columnLabel] + costs[$0.offset] })
  }
  mutating func replaceDepartments(with text: String) throws {
    var rows = try SpreadsheetTable(text: text).rows
    if rows.first == ["ID", "Department", "Fixed"] { rows.removeFirst() }
    guard !rows.isEmpty else { throw SpreadsheetTransferError.emptyClipboard }
    let values = try rows.enumerated().map { index, row in
      guard row.count == 3 else {
        throw SpreadsheetTransferError.inconsistentColumns(
          expected: 3, actual: row.count, row: index + 1)
      }
      guard ["true", "false"].contains(row[2].lowercased()) else {
        throw SpreadsheetTransferError.invalidValue(
          row[2], column: "Fixed (true/false)", row: index + 1)
      }
      return LayoutDepartmentDraft(
        sourceID: row[0], name: row[1], fixed: row[2].lowercased() == "true")
    }
    var candidate = self
    let indexes = values.map { value in
      departments.firstIndex { Int($0.sourceID) == Int(value.sourceID) }
    }
    candidate.departments = values.enumerated().map { index, value in
      guard let previous = indexes[index] else { return value }
      return LayoutDepartmentDraft(id: departments[previous].id, sourceID: value.sourceID,
        name: value.name, fixed: value.fixed, rectangles: departments[previous].rectangles)
    }
    // Stable department IDs preserve geometry and both cost axes through spreadsheet reordering.
    candidate.costs = indexes.map { row in
      indexes.map { column in
        if let row, let column { return costs[row][column] }
        return ""
      }
    }
    let model = try candidate.makeProblem()
    if FacilityLayoutValidator.diagnostics(for: model).contains(where: {
      $0.code == "facilities.layout.departments.duplicate"
    }) {
      throw SpreadsheetTransferError.invalidValue("Duplicate IDs", column: "Department ID", row: 1)
    }
    self = candidate
  }
  mutating func replaceRectangles(with text: String) throws {
    var rows = try SpreadsheetTable(text: text).rows
    if rows.first == ["Department ID", "Start Row", "Start Column", "End Row", "End Column"] {
      rows.removeFirst()
    }
    var candidate = self
    for i in candidate.departments.indices { candidate.departments[i].rectangles = [] }
    for (index, row) in rows.enumerated() {
      guard row.count == 5 else {
        throw SpreadsheetTransferError.inconsistentColumns(
          expected: 5, actual: row.count, row: index + 1)
      }
      let matches = candidate.departments.indices.filter { Int(candidate.departments[$0].sourceID) == Int(row[0]) }
      guard Int(row[0]) != nil, matches.count == 1, let department = matches.first
      else {
        throw SpreadsheetTransferError.invalidValue(
          row[0], column: "Unique known department ID", row: index + 1)
      }
      candidate.departments[department].rectangles.append(
        LayoutRectangleDraft(
          startRow: row[1], startColumn: row[2], endRow: row[3], endColumn: row[4]))
    }
    _ = try candidate.makeProblem()
    self = candidate
  }
  mutating func replaceCosts(with text: String) throws {
    var rows = try SpreadsheetTable(text: text).rows
    if rows.first?.first == "Department" {
      guard rows.first == ["Department"] + departments.map(\.columnLabel) else {
        throw SpreadsheetTransferError.invalidValue(
          rows[0].joined(separator: ", "), column: "Headers in current department order", row: 1)
      }
      rows.removeFirst()
    }
    guard rows.count == departments.count else {
      throw SpreadsheetTransferError.inconsistentRows(
        expected: departments.count, actual: rows.count)
    }
    let values = try rows.enumerated().map { index, row in
      guard row.count == departments.count + 1 else {
        throw SpreadsheetTransferError.inconsistentColumns(
          expected: departments.count + 1, actual: row.count, row: index + 1)
      }
      guard row[0] == departments[index].columnLabel else {
        throw SpreadsheetTransferError.invalidValue(
          row[0], column: "Department row label", row: index + 1)
      }
      for (column, value) in row.dropFirst().enumerated() where !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        try SpreadsheetTable.requireFinite(value, column: "Destination \(column + 1)", row: index + 1)
      }
      return Array(row.dropFirst())
    }
    var candidate = self
    candidate.costs = values
    candidate.hasImportedDimensionIssue = false
    // Check the pasted matrix independently so unfinished geometry or coordinates
    // remain repairable. Core validation still gates the complete model.
    self = candidate
  }
  private func integer(_ value: String, _ path: String, _ label: String) throws -> Int {
    guard let number = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      throw OptimizationDraftError.invalidInteger(path: path, label: label, value: value)
    }
    return number
  }
}
