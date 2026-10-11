import Foundation
import QSBCore

struct LineTaskDraft: Identifiable, Equatable, Sendable {
  let id: UUID
  var sourceID: String
  var name: String
  var time: String
  var isolated: Bool
  var successors: String
  init(
    id: UUID = UUID(), sourceID: String, name: String, time: String = "1", isolated: Bool = false,
    successors: String = ""
  ) {
    self.id = id
    self.sourceID = sourceID
    self.name = name
    self.time = time
    self.isolated = isolated
    self.successors = successors
  }
}

struct LineBalancingDraft: Equatable, Sendable {
  var title: String
  var timeUnit: String
  var cycleTime: String
  var tasks: [LineTaskDraft]
  static func blank() -> Self {
    Self(
      LineBalancingProblem(
        title: "New Assembly Line", timeUnit: "minute", cycleTime: 10,
        tasks: [
          LineBalancingTask(id: 1, name: "Task 1", time: 1, isolated: false, successorIDs: [])
        ]))
  }
  init(_ problem: LineBalancingProblem) {
    title = problem.title
    timeUnit = problem.timeUnit
    cycleTime = String(problem.cycleTime)
    tasks = problem.tasks.map {
      LineTaskDraft(
        sourceID: String($0.id), name: $0.name, time: String($0.time), isolated: $0.isolated,
        successors: $0.successorIDs.map(String.init).joined(separator: " "))
    }
  }
  func makeProblem() throws -> LineBalancingProblem {
    try require(title, path: "title", label: "a model title")
    try require(timeUnit, path: "timeUnit", label: "a time unit")
    return LineBalancingProblem(
      title: title, timeUnit: timeUnit, cycleTime: try integer(cycleTime, path: "cycleTime", label: "cycle time"),
      tasks: try tasks.enumerated().map { index, row in
        try makeTask(row, index: index)
      })
  }
  func draftDiagnostics() -> [ValidationDiagnostic] {
    do { return LineBalancingValidator.diagnostics(for: try makeProblem()) } catch let error
      as OptimizationDraftError
    {
      return [
        ValidationDiagnostic(
          severity: .error, code: "line.draft.invalid", message: error.description, path: error.path
        )
      ]
    } catch {
      return [
        ValidationDiagnostic(
          severity: .error, code: "line.draft.invalid", message: String(describing: error))
      ]
    }
  }
  @discardableResult mutating func addTask() -> UUID {
    var number = tasks.count + 1
    while tasks.contains(where: { Int($0.sourceID) == number }) { number += 1 }
    let task = LineTaskDraft(sourceID: String(number), name: "Task \(number)")
    tasks.append(task)
    return task.id
  }
  mutating func removeTask(id: UUID) {
    guard tasks.count > 1 else { return }
    // Keep successor input so a deleted dependency is diagnosed and can be repaired or undone.
    tasks.removeAll { $0.id == id }
  }
  mutating func moveTask(id: UUID, by offset: Int) {
    guard let index = tasks.firstIndex(where: { $0.id == id }),
      tasks.indices.contains(index + offset)
    else { return }
    let row = tasks.remove(at: index)
    tasks.insert(row, at: index + offset)
  }
  func tasksTable() -> String {
    optimizationTable(
      headers: ["ID", "Task", "Time", "Isolated", "Successor IDs"],
      rows: tasks.map {
        [$0.sourceID, $0.name, $0.time, $0.isolated ? "true" : "false", $0.successors]
      })
  }
  mutating func replaceTasks(with text: String) throws {
    var rows = try SpreadsheetTable(text: text).rows
    if rows.first?.map({ $0.lowercased() }) == ["id", "task", "time", "isolated", "successor ids"] { rows.removeFirst() }
    guard !rows.isEmpty else { throw SpreadsheetTransferError.emptyClipboard }
    let existing = Dictionary(grouping: tasks.compactMap { task in
      Int(task.sourceID.trimmingCharacters(in: .whitespacesAndNewlines)).map { ($0, task) }
    }, by: { $0.0 })
    let incoming = Dictionary(grouping: rows, by: { Int(($0.first ?? "").trimmingCharacters(in: .whitespacesAndNewlines)) })
    let values = try rows.enumerated().map { index, row in
      guard row.count == 5 else {
        throw SpreadsheetTransferError.inconsistentColumns(
          expected: 5, actual: row.count, row: index + 1)
      }
      guard ["true", "false"].contains(row[3].lowercased()) else {
        throw SpreadsheetTransferError.invalidValue(
          row[3], column: "Isolated (true/false)", row: index + 1)
      }
      let sourceID = try integer(row[0], path: "tasks.\(index).id", label: "a task ID")
      // Source IDs identify tasks independently of editable names or table position.
      let id = existing[sourceID]?.count == 1 && incoming[sourceID]?.count == 1 ? existing[sourceID]?.first?.1.id : nil
      let task = LineTaskDraft(
        id: id ?? UUID(), sourceID: row[0], name: row[1], time: row[2], isolated: row[3].lowercased() == "true",
        successors: row[4])
      _ = try makeTask(task, index: index)
      return task
    }
    tasks = values
  }
  private func makeTask(_ row: LineTaskDraft, index: Int) throws -> LineBalancingTask {
    try require(row.name, path: "tasks.\(index).name", label: "a task name")
    let successors = try row.successors.split { $0.isWhitespace || $0 == "," || $0 == ";" }
      .enumerated().map {
        try integer(String($0.element), path: "tasks.\(index).successorIDs.\($0.offset)", label: "a successor ID for \(row.name)")
      }
    return LineBalancingTask(
      id: try integer(row.sourceID, path: "tasks.\(index).id", label: "the ID for \(row.name)"), name: row.name,
      time: try integer(row.time, path: "tasks.\(index).time", label: "the duration of \(row.name)"), isolated: row.isolated,
      successorIDs: successors)
  }

  private func integer(_ value: String, path: String, label: String) throws -> Int {
    guard let number = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      throw OptimizationDraftError.invalidInteger(path: path, label: label, value: value)
    }
    return number
  }
  private func require(_ value: String, path: String, label: String) throws {
    guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw OptimizationDraftError.emptyField(path: path, label: label)
    }
  }
}
