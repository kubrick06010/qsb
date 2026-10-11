import QSBCore
import SwiftUI

struct LineBalancingEditorView: View {
  @Bindable var workspace: QSBWorkspace
  @Environment(\.undoManager) private var undoManager
  @FocusState private var focusedTask: UUID?
  @State private var transferIssue: String?
  private var draft: LineBalancingDraft? { workspace.lineBalancingDraft }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HeaderView(
        title: workspace.modelTitle, subtitle: "Line Balancing · \(workspace.modelState.rawValue)")
      if let draft {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            HStack {
              Button("Validate", systemImage: "checkmark.seal") { workspace.validateCurrentModel() }
                .keyboardShortcut("v", modifiers: [.command, .shift])
              Button("Run", systemImage: "play.circle") { workspace.startCurrentModelRun() }
                .buttonStyle(.borderedProminent).keyboardShortcut("r", modifiers: .command)
                .disabled(workspace.modelState == .invalid || workspace.runState == .solving)
            }
            issues(draft)
            GroupBox("Assembly line") {
              VStack(alignment: .leading, spacing: 10) {
                Text("Model title").font(.caption).foregroundStyle(.secondary)
                TextField("Title", text: text(\.title)).accessibilityLabel("Model title")
                ViewThatFits(in: .horizontal) {
                  HStack(alignment: .bottom, spacing: 16) { timeFields }
                  VStack(alignment: .leading, spacing: 10) { timeFields }
                }
                Text(
                  "The native solver minimizes station count for up to 24 tasks. Use integer task times and cycle time in the same unit."
                )
                .font(.caption).foregroundStyle(.secondary)
              }.padding(8)
            }
            taskTable(draft)
          }.textFieldStyle(.roundedBorder).padding(20)
            .frame(maxWidth: 1360, alignment: .leading).frame(
              maxWidth: .infinity, alignment: .leading)
        }
      }
    }.navigationTitle("Line Balancing Definition")
      .onChange(of: draft?.tasks.map(\.id) ?? []) { previous, current in
        guard let focusedTask, !current.contains(focusedTask) else { return }
        let index = previous.firstIndex(of: focusedTask) ?? 0
        self.focusedTask = current.isEmpty ? nil : current[min(index, current.count - 1)]
      }
  }
  @ViewBuilder private var timeFields: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Time unit").font(.caption).foregroundStyle(.secondary)
      TextField("Time unit", text: text(\.timeUnit)).frame(width: 180).accessibilityLabel(
        "Time unit")
    }
    VStack(alignment: .leading, spacing: 4) {
      Text("Cycle time").font(.caption).foregroundStyle(.secondary)
      TextField("Cycle time", text: text(\.cycleTime)).frame(width: 140).accessibilityLabel(
        "Cycle time in \(draft?.timeUnit ?? "time units")")
    }
  }
  private func taskTable(_ draft: LineBalancingDraft) -> some View {
    GroupBox("Tasks and precedence") {
      VStack(alignment: .leading, spacing: 10) {
        Text(
          "Successor IDs identify tasks that must follow this task. Separate IDs with spaces, commas, or semicolons; blank means no successors. The isolation flag is preserved for compatibility; the current native assignment uses task times and precedence."
        )
        .font(.caption).foregroundStyle(.secondary)
        ScrollView(.horizontal) {
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
              heading("ID", 70)
              heading("Task", 200)
              heading("Time (\(draft.timeUnit))", 130)
              heading("Isolated", 70)
              heading("Successor IDs", 240)
            }
            ForEach(Array(draft.tasks.enumerated()), id: \.element.id) { index, row in
              taskRow(row, index: index, draft: draft)
            }
          }.padding(.bottom, 4)
        }
        Button("Add Task", systemImage: "plus") {
          var id: UUID?
          update("Add Task") { id = $0.addTask() }
          focusedTask = id
        }
        SpreadsheetTransferActions(
          subject: "line-balancing tasks", issue: transferIssue,
          paste: paste, copy: { SpreadsheetClipboard.write(draft.tasksTable()) })
      }.padding(8)
    }
  }
  private func taskRow(_ row: LineTaskDraft, index: Int, draft: LineBalancingDraft) -> some View {
    HStack(spacing: 8) {
      TextField("ID", text: taskText(row.id, \.sourceID)).frame(width: 70).accessibilityLabel(
        "ID for \(row.name)")
      TextField("Task", text: taskText(row.id, \.name)).frame(width: 200)
        .focused($focusedTask, equals: row.id).accessibilityLabel("Task \(row.sourceID) name")
      TextField("Time", text: taskText(row.id, \.time)).frame(width: 130)
        .accessibilityLabel("Duration of \(row.name) in \(draft.timeUnit)")
      Toggle("Isolated", isOn: isolated(row.id)).labelsHidden().frame(width: 70)
        .accessibilityLabel("Isolation flag for \(row.name)")
      TextField("Successor IDs", text: taskText(row.id, \.successors)).frame(width: 240)
        .accessibilityLabel("Successor IDs for \(row.name)")
      Button {
        move(row.id, by: -1)
      } label: {
        Image(systemName: "arrow.up")
      }
      .disabled(index == 0).accessibilityLabel("Move \(row.name) earlier in table")
      Button {
        move(row.id, by: 1)
      } label: {
        Image(systemName: "arrow.down")
      }
      .disabled(index == draft.tasks.count - 1).accessibilityLabel(
        "Move \(row.name) later in table")
      Button {
        remove(row.id)
      } label: {
        Image(systemName: "minus.circle")
      }
      .buttonStyle(.borderless).disabled(draft.tasks.count <= 1).accessibilityLabel(
        "Remove task \(row.name)")
    }
  }
  @ViewBuilder private func issues(_ draft: LineBalancingDraft) -> some View {
    let issues = draft.draftDiagnostics().filter { $0.severity != .info }
    if !issues.isEmpty {
      VStack(alignment: .leading, spacing: 4) {
        ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
          Label(issue.message, systemImage: "exclamationmark.triangle").font(.caption)
            .foregroundStyle(issue.severity == .error ? .red : .orange)
        }
      }.accessibilityElement(children: .contain).accessibilityLabel("Line balancing input issues")
    }
  }
  private func heading(_ label: String, _ width: CGFloat) -> some View {
    Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(
      width: width, alignment: .leading)
  }
  private func text(_ key: WritableKeyPath<LineBalancingDraft, String>) -> Binding<String> {
    Binding(
      get: { draft?[keyPath: key] ?? "" },
      set: { value in update("Edit Assembly Line") { $0[keyPath: key] = value } })
  }
  private func taskText(_ id: UUID, _ key: WritableKeyPath<LineTaskDraft, String>) -> Binding<
    String
  > {
    Binding(
      get: { draft?.tasks.first { $0.id == id }?[keyPath: key] ?? "" },
      set: { value in
        update("Edit Task") {
          if let index = $0.tasks.firstIndex(where: { $0.id == id }) {
            $0.tasks[index][keyPath: key] = value
          }
        }
      })
  }
  private func isolated(_ id: UUID) -> Binding<Bool> {
    Binding(
      get: { draft?.tasks.first { $0.id == id }?.isolated ?? false },
      set: { value in
        update("Change Task Isolation") {
          if let index = $0.tasks.firstIndex(where: { $0.id == id }) {
            $0.tasks[index].isolated = value
          }
        }
      })
  }
  private func move(_ id: UUID, by offset: Int) {
    update("Reorder Tasks") { $0.moveTask(id: id, by: offset) }
    focusedTask = id
  }
  private func remove(_ id: UUID) {
    update("Remove Task") { draft in
      guard draft.tasks.count > 1, let index = draft.tasks.firstIndex(where: { $0.id == id }) else {
        return
      }
      draft.removeTask(id: id)
      focusedTask = draft.tasks[min(index, draft.tasks.count - 1)].id
    }
  }
  private func update(_ name: String, _ edit: (inout LineBalancingDraft) -> Void) {
    guard var draft else { return }
    edit(&draft)
    workspace.replaceLineBalancingDraft(draft, undoManager: undoManager, actionName: name)
  }
  private func paste() {
    do {
      let clipboard = try SpreadsheetClipboard.read()
      guard var draft else { return }
      try draft.replaceTasks(with: clipboard)
      workspace.replaceLineBalancingDraft(
        draft, undoManager: undoManager, actionName: "Paste Task Table")
      if !draft.tasks.contains(where: { $0.id == focusedTask }) { focusedTask = draft.tasks.first?.id }
      transferIssue = nil
    } catch { transferIssue = String(describing: error) }
  }
}
