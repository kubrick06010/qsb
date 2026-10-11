import QSBCore
import SwiftUI

struct GoalProgrammingEditorView: View {
  enum Section: String, CaseIterable, Identifiable {
    case variables = "Variables"
    case goals = "Priorities"
    case constraints = "Constraints"
    var id: Self { self }
  }
  @Bindable var workspace: QSBWorkspace
  @Environment(\.undoManager) private var undoManager
  @FocusState private var focusedVariableID: UUID?
  @FocusState private var focusedConstraintID: UUID?
  @FocusState private var focusedEmptyConstraintAction: Bool
  @State private var section: Section
  private let initialMatrixRow: UUID?
  private let initialMatrixColumnGroup: Int
  @State private var transferIssue: String?

  init(workspace: QSBWorkspace, initialSection: Section = .variables,
       initialMatrixRow: UUID? = nil, initialMatrixColumnGroup: Int = 0) {
    self.workspace = workspace
    self.initialMatrixRow = initialMatrixRow
    self.initialMatrixColumnGroup = initialMatrixColumnGroup
    _section = State(initialValue: initialSection)
  }
  private var draft: GoalProgrammingDraft? { workspace.goalProgrammingDraft }

  private var editorContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      HeaderView(
        title: workspace.modelTitle,
        subtitle: "Native goal-programming editor · \(workspace.modelState.rawValue)")
      if let draft {
        ScrollView(.vertical) {
          VStack(alignment: .leading, spacing: 16) {
            actionBar
            issues(draft)
            settings
            sectionPicker
            sectionBody(draft)
          }
          .padding(20).frame(maxWidth: 1_360, alignment: .topLeading).frame(
            maxWidth: .infinity, alignment: .topLeading)
        }
      }
    }
  }

  private var variableIDs: [UUID] { draft?.variables.map(\.id) ?? [] }
  private var constraintIDs: [UUID] { draft?.constraints.map(\.id) ?? [] }
  private var goalIDs: [UUID] { draft?.goals.map(\.id) ?? [] }

  var body: some View {
    editorContent.navigationTitle("Goal Programming Definition")
      .onChange(of: section) { _, _ in transferIssue = nil }
      .onChange(of: variableIDs) { previous, current in
        focusedVariableID = repairedEditorRowSelection(focusedVariableID, previous: previous, current: current)
      }
      .onChange(of: constraintIDs) { previous, current in
        let hadFocus = focusedConstraintID != nil
        focusedConstraintID = repairedEditorRowSelection(focusedConstraintID, previous: previous, current: current)
        if hadFocus { focusedEmptyConstraintAction = current.isEmpty && draft != nil && section == .constraints }
      }
      .onChange(of: goalIDs) { previous, current in
        focusedGoalID = repairedEditorRowSelection(focusedGoalID, previous: previous, current: current)
      }
  }

  private var actionBar: some View {
    ViewThatFits(in: .horizontal) {
      HStack {
        buttons
        Spacer()
        Text("Goal Programming").foregroundStyle(.secondary)
      }
      VStack(alignment: .leading) {
        HStack { buttons }
        Text("Goal Programming").foregroundStyle(.secondary)
      }
    }
  }
  @ViewBuilder private var buttons: some View {
    Button("Validate", systemImage: "checkmark.seal") { workspace.validateCurrentModel() }
      .keyboardShortcut("v", modifiers: [.command, .shift])
    Button("Run", systemImage: "play.circle") { workspace.startCurrentModelRun() }.buttonStyle(
      .borderedProminent
    ).keyboardShortcut("r", modifiers: [.command]).disabled(
      workspace.modelState == .invalid || workspace.runState == .solving)
  }
  private var settings: some View {
    GroupBox("Model") {
      VStack(alignment: .leading, spacing: 8) {
        labeled("Title", text: binding(\.title, "Edit Title"), width: 330)
        Text(
          "Goals are optimized in priority order. Each later goal preserves earlier optimum values."
        )
        .font(.caption).foregroundStyle(.secondary)
      }.padding(8)
    }
  }
  private var sectionPicker: some View {
    Picker("Definition section", selection: $section) {
      ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
    }.pickerStyle(.segmented).accessibilityLabel("Goal programming definition section")
  }
  @ViewBuilder private func sectionBody(_ draft: GoalProgrammingDraft) -> some View {
    switch section {
    case .variables: variables(draft)
    case .goals: goals(draft)
    case .constraints: constraints(draft)
    }
  }

  private func variables(_ draft: GoalProgrammingDraft) -> some View {
    GroupBox("Variables and bounds") {
      VStack(alignment: .leading, spacing: 10) {
        if draft.hasImportedDimensionIssue {
          VStack(alignment: .leading, spacing: 6) {
            Text("Imported dimensions need review. Available coefficients are retained; missing names, lower bounds, and coefficients are empty. Missing types display Continuous and missing upper bounds display unbounded. Review these defaults before accepting the displayed dimensions.")
              .font(.caption)
            Button("Use Displayed Dimensions") {
              update("Review Imported Dimensions") { $0.confirmImportedDimensions() }
            }
            .accessibilityHint("Accepts displayed types and optional upper bounds. Required lower bounds, names, and coefficients still need correction.")
          }
        }
        Text(
          "Lower bounds are required; a blank upper bound means unbounded. Variable names label goal and constraint coefficients."
        )
        .font(.caption).foregroundStyle(.secondary)
        ScrollView(.horizontal) {
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
              header("Variable", 180)
              header("Type", 130)
              header("Lower", 110)
              header("Upper", 110)
              Color.clear.frame(width: 28)
            }
            ForEach(Array(draft.variables.enumerated()), id: \.element.id) { i, v in
              variableRow(v, index: i, count: draft.variables.count)
            }
          }.padding(.bottom, 4)
        }
        actions(
          subject: "goal variables", addTitle: "Add Variable",
          add: {
            var id: UUID?
            update("Add Variable") { id = $0.addVariable() }
            focusedVariableID = id
          }, paste: pasteVariables, copy: { SpreadsheetClipboard.write(draft.variablesTable()) })
      }.padding(8)
    }
  }
  private func variableRow(_ variable: OptimizationVariableDraft, index: Int, count: Int)
    -> some View
  {
    HStack(spacing: 8) {
      TextField("Variable", text: variableText(variable.id, \.name)).textFieldStyle(.roundedBorder)
        .frame(width: 180).focused($focusedVariableID, equals: variable.id).accessibilityLabel(
          "Variable \(index+1) name")
      Picker("Type", selection: variableType(variable.id)) {
        Text("Continuous").tag(VariableType.continuous)
        Text("Integer").tag(VariableType.integer)
        Text("Binary").tag(VariableType.binary)
      }.labelsHidden().frame(width: 130).accessibilityLabel("Variable \(index+1) type")
      TextField("", text: variableText(variable.id, \.lowerBound)).frame(width: 110)
        .accessibilityLabel("Variable \(index+1) lower bound")
      TextField("", text: variableText(variable.id, \.upperBound)).frame(width: 110)
        .accessibilityLabel("Variable \(index+1) upper bound")
      Button {
        removeVariable(variable.id)
      } label: {
        Image(systemName: "minus.circle")
      }.buttonStyle(.borderless).disabled(count <= 1).accessibilityLabel(
        "Remove variable \(variable.name)")
    }
  }

  @FocusState private var focusedGoalID: UUID?
  private func goals(_ draft: GoalProgrammingDraft) -> some View {
    GroupBox("Ordered goal priorities") {
      VStack(alignment: .leading, spacing: 10) {
        if draft.goals.isEmpty {
          Text("No priorities. Add a goal or paste a priority table.").font(.caption).foregroundStyle(.secondary)
        }
        if draft.goals.count > 12 || draft.variables.count > 12 {
          NamedMatrixEditor(
            rows: draft.goals.enumerated().map { MatrixAxisItem(id: $0.element.id, label: "Priority \($0.offset + 1): \($0.element.name)") },
            columns: draft.variables.map { MatrixAxisItem(id: $0.id, label: $0.name) },
            accessibilityPrefix: "Goal coefficient", initialRow: initialMatrixRow,
            initialColumnGroup: initialMatrixColumnGroup, sourceTitle: "Goal", destinationTitle: "Variables",
            selectedRowRequest: focusedGoalID,
            rowDetails: { row in AnyView(ScrollView(.horizontal) {
              VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                  header("Priority", 60)
                  header("Goal", 170)
                  header("Sense", 160)
                }
                goalRow(draft.goals[row], index: row, draft: draft, includeCoefficients: false)
              }
            }) }, value: { row, column in goalCoefficient(draft.goals[row].id, column) })
        } else {
        ScrollView(.horizontal) {
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
              header("Priority", 60)
              header("Goal", 170)
              header("Sense", 160)
              ForEach(draft.variables) { header($0.name, 90) }
            }
            ForEach(Array(draft.goals.enumerated()), id: \.element.id) { index, goal in
              goalRow(goal, index: index, draft: draft)
            }
          }.padding(.bottom, 4)
        }
        }
        actions(
          subject: "goal priorities", addTitle: "Add Goal",
          add: {
            var id: UUID?
            update("Add Goal") { id = $0.addGoal() }
            focusedGoalID = id
          }, paste: pasteGoals, copy: { SpreadsheetClipboard.write(draft.goalsTable()) })
      }.padding(8)
    }
  }
  private func goalRow(_ goal: GoalDraft, index: Int, draft: GoalProgrammingDraft, includeCoefficients: Bool = true) -> some View {
    HStack(spacing: 6) {
      Text(String(index + 1)).frame(width: 60).accessibilityLabel("Priority \(index + 1)")
      TextField("Goal", text: goalText(goal.id)).frame(width: 170)
        .focused($focusedGoalID, equals: goal.id).accessibilityLabel(
          "Priority \(index + 1) goal name")
      Picker("Sense", selection: goalSense(goal.id)) {
        Text("Minimize").tag(ObjectiveSense.minimize)
        Text("Maximize").tag(ObjectiveSense.maximize)
      }.labelsHidden().frame(width: 160).accessibilityLabel("Sense for \(goal.name)")
      if includeCoefficients {
      ForEach(draft.variables.indices, id: \.self) { column in
        TextField("", text: goalCoefficient(goal.id, column)).frame(width: 90)
          .accessibilityLabel("Coefficient for \(draft.variables[column].name) in \(goal.name)")
      }
      }
      Button {
        update("Move Goal Earlier") { $0.moveGoal(id: goal.id, by: -1) }
        focusedGoalID = goal.id
      } label: {
        Image(systemName: "arrow.up")
      }
      .disabled(index == 0).accessibilityLabel("Move \(goal.name) earlier")
      Button {
        update("Move Goal Later") { $0.moveGoal(id: goal.id, by: 1) }
        focusedGoalID = goal.id
      } label: {
        Image(systemName: "arrow.down")
      }
      .disabled(index == draft.goals.count - 1).accessibilityLabel("Move \(goal.name) later")
      Button {
        removeGoal(goal.id)
      } label: {
        Image(systemName: "minus.circle")
      }
      .disabled(draft.goals.count <= 1).accessibilityLabel("Remove goal \(goal.name)")
    }.textFieldStyle(.roundedBorder)
  }

  private func constraints(_ draft: GoalProgrammingDraft) -> some View {
    GroupBox("Linear constraints") {
      VStack(alignment: .leading, spacing: 10) {
        if draft.constraints.isEmpty {
          Text("No linear constraints. Add a constraint or paste a constraint table.").font(.caption).foregroundStyle(.secondary)
        }
        if draft.constraints.count > 12 || draft.variables.count > 12 {
          NamedMatrixEditor(
            rows: draft.constraints.map { MatrixAxisItem(id: $0.id, label: $0.name) },
            columns: draft.variables.map { MatrixAxisItem(id: $0.id, label: $0.name) },
            accessibilityPrefix: "Constraint coefficient", initialRow: initialMatrixRow,
            initialColumnGroup: initialMatrixColumnGroup, sourceTitle: "Constraint", destinationTitle: "Variables",
            selectedRowRequest: focusedConstraintID,
            rowDetails: { row in AnyView(ScrollView(.horizontal) {
              VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                  header("Constraint", 170)
                  header("Relation", 100)
                  header("RHS", 110)
                }
                constraintRow(draft.constraints[row], draft: draft, includeCoefficients: false)
              }
            }) }, value: { row, column in constraintCoefficient(draft.constraints[row].id, column) })
        } else {
        ScrollView(.horizontal) {
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
              header("Constraint", 170)
              ForEach(draft.variables) { header($0.name, 90) }
              header("Relation", 100)
              header("RHS", 110)
              Color.clear.frame(width: 28)
            }
            ForEach(draft.constraints) { constraintRow($0, draft: draft) }
          }.padding(.bottom, 4)
        }
        }
        actions(
          subject: "goal constraints", addTitle: "Add Constraint",
          add: {
            var id: UUID?
            update("Add Constraint") { id = $0.addConstraint() }
            focusedConstraintID = id
          }, paste: pasteConstraints, copy: { SpreadsheetClipboard.write(draft.constraintsTable()) }
        )
      }.padding(8)
    }
  }
  private func constraintRow(_ c: OptimizationConstraintDraft, draft: GoalProgrammingDraft, includeCoefficients: Bool = true)
    -> some View
  {
    HStack(spacing: 6) {
      TextField("Constraint", text: constraintText(c.id, \.name)).textFieldStyle(.roundedBorder)
        .frame(width: 170).focused($focusedConstraintID, equals: c.id).accessibilityLabel(
          "Constraint \(draft.constraints.firstIndex(where: { $0.id == c.id }).map { $0 + 1 } ?? 1) name"
        )
      if includeCoefficients {
      ForEach(draft.variables.indices, id: \.self) { i in
        TextField("", text: constraintCoefficient(c.id, i)).frame(width: 90).accessibilityLabel(
          "Coefficient for \(draft.variables[i].name) in \(c.name)")
      }
      }
      Picker("Relation", selection: constraintRelation(c.id)) {
        Text("≤").tag(ConstraintRelation.lessThanOrEqual)
        Text("=").tag(ConstraintRelation.equal)
        Text("≥").tag(ConstraintRelation.greaterThanOrEqual)
      }.labelsHidden().frame(width: 100).accessibilityLabel("Relation for \(c.name)")
      TextField("", text: constraintText(c.id, \.rhs)).frame(width: 110).accessibilityLabel(
        "Right hand side for \(c.name)")
      Button {
        removeConstraint(c.id)
      } label: {
        Image(systemName: "minus.circle")
      }.buttonStyle(.borderless).accessibilityLabel("Remove constraint \(c.name)")
    }
  }

  @ViewBuilder private func issues(_ draft: GoalProgrammingDraft) -> some View {
    let ds = draft.draftDiagnostics().filter { $0.severity != .info }
    if !ds.isEmpty {
      VStack(alignment: .leading, spacing: 4) {
        ForEach(Array(ds.enumerated()), id: \.offset) { _, d in
          Label(d.message, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(
            d.severity == .error ? .red : .orange)
        }
      }.accessibilityElement(children: .contain).accessibilityLabel(
        "Goal programming input issues")
    }
  }
  private func actions(
    subject: String, addTitle: String, add: @escaping () -> Void, paste: @escaping () -> Void,
    copy: @escaping () -> Void
  ) -> some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: 10) {
        addAction(addTitle, action: add)
        SpreadsheetTransferActions(subject: subject, issue: transferIssue, paste: paste, copy: copy)
      }
      VStack(alignment: .leading, spacing: 10) {
        addAction(addTitle, action: add)
        SpreadsheetTransferActions(subject: subject, issue: transferIssue, paste: paste, copy: copy)
      }
    }
  }
  @ViewBuilder private func addAction(_ title: String, action: @escaping () -> Void) -> some View {
    if title == "Add Constraint" {
      Button(title, systemImage: "plus", action: action).focused($focusedEmptyConstraintAction)
    } else {
      Button(title, systemImage: "plus", action: action)
    }
  }
  private func header(_ value: String, _ width: CGFloat) -> some View {
    Text(value).font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(
      width: width, alignment: .leading)
  }
  private func labeled(_ label: String, text: Binding<String>, width: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label).font(.caption).foregroundStyle(.secondary)
      TextField(label, text: text).frame(width: width).accessibilityLabel(label)
    }
  }
  private func binding(_ kp: WritableKeyPath<GoalProgrammingDraft, String>, _ action: String)
    -> Binding<String>
  {
    Binding(
      get: { workspace.goalProgrammingDraft?[keyPath: kp] ?? "" },
      set: { v in update(action) { $0[keyPath: kp] = v } })
  }
  private func variableText(_ id: UUID, _ kp: WritableKeyPath<OptimizationVariableDraft, String>)
    -> Binding<String>
  {
    Binding(
      get: {
        workspace.goalProgrammingDraft?.variables.first { $0.id == id }?[keyPath: kp] ?? ""
      },
      set: { v in
        update("Edit Variable") {
          if let i = $0.variables.firstIndex(where: { $0.id == id }) {
            $0.variables[i][keyPath: kp] = v
          }
        }
      })
  }
  private func variableType(_ id: UUID) -> Binding<VariableType> {
    Binding(
      get: {
        workspace.goalProgrammingDraft?.variables.first { $0.id == id }?.type ?? .continuous
      },
      set: { v in
        update("Change Variable Type") {
          if let i = $0.variables.firstIndex(where: { $0.id == id }) { $0.variables[i].type = v }
        }
      })
  }
  private func goalText(_ id: UUID) -> Binding<String> {
    Binding(
      get: { draft?.goals.first { $0.id == id }?.name ?? "" },
      set: { value in
        update("Edit Goal") {
          if let i = $0.goals.firstIndex(where: { $0.id == id }) { $0.goals[i].name = value }
        }
      })
  }
  private func goalSense(_ id: UUID) -> Binding<ObjectiveSense> {
    Binding(
      get: { draft?.goals.first { $0.id == id }?.sense ?? .minimize },
      set: { value in
        update("Edit Goal Sense") {
          if let i = $0.goals.firstIndex(where: { $0.id == id }) { $0.goals[i].sense = value }
        }
      })
  }
  private func goalCoefficient(_ id: UUID, _ column: Int) -> Binding<String> {
    Binding(
      get: { draft?.goals.first { $0.id == id }?.coefficients[safe: column] ?? "" },
      set: { value in
        update("Edit Goal Coefficient") {
          if let i = $0.goals.firstIndex(where: { $0.id == id }),
            $0.goals[i].coefficients.indices.contains(column)
          {
            $0.goals[i].coefficients[column] = value
          }
        }
      })
  }
  private func constraintText(
    _ id: UUID, _ kp: WritableKeyPath<OptimizationConstraintDraft, String>
  ) -> Binding<String> {
    Binding(
      get: {
        workspace.goalProgrammingDraft?.constraints.first { $0.id == id }?[keyPath: kp] ?? ""
      },
      set: { v in
        update("Edit Constraint") {
          if let i = $0.constraints.firstIndex(where: { $0.id == id }) {
            $0.constraints[i][keyPath: kp] = v
          }
        }
      })
  }
  private func constraintCoefficient(_ id: UUID, _ column: Int) -> Binding<String> {
    Binding(
      get: {
        workspace.goalProgrammingDraft?.constraints.first { $0.id == id }?.coefficients[
          safe: column] ?? ""
      },
      set: { v in
        update("Edit Constraint Coefficient") {
          if let i = $0.constraints.firstIndex(where: { $0.id == id }),
            $0.constraints[i].coefficients.indices.contains(column)
          {
            $0.constraints[i].coefficients[column] = v
          }
        }
      })
  }
  private func constraintRelation(_ id: UUID) -> Binding<ConstraintRelation> {
    Binding(
      get: {
        workspace.goalProgrammingDraft?.constraints.first { $0.id == id }?.relation
          ?? .lessThanOrEqual
      },
      set: { v in
        update("Change Constraint Relation") {
          if let i = $0.constraints.firstIndex(where: { $0.id == id }) {
            $0.constraints[i].relation = v
          }
        }
      })
  }
  private func removeVariable(_ id: UUID) {
    update("Remove Variable") { draft in
      guard draft.variables.count > 1, let index = draft.variables.firstIndex(where: { $0.id == id }) else { return }
      draft.removeVariable(id: id)
      focusedVariableID = draft.variables[min(index, draft.variables.count - 1)].id
    }
  }
  private func removeGoal(_ id: UUID) {
    update("Remove Goal") { draft in
      guard draft.goals.count > 1, let index = draft.goals.firstIndex(where: { $0.id == id }) else { return }
      draft.removeGoal(id: id)
      focusedGoalID = draft.goals[min(index, draft.goals.count - 1)].id
    }
  }
  private func removeConstraint(_ id: UUID) {
    update("Remove Constraint") { draft in
      guard let index = draft.constraints.firstIndex(where: { $0.id == id }) else { return }
      draft.removeConstraint(id: id)
      focusedConstraintID = draft.constraints.isEmpty ? nil : draft.constraints[min(index, draft.constraints.count - 1)].id
      focusedEmptyConstraintAction = draft.constraints.isEmpty
    }
  }
  private func update(_ name: String, _ mutation: (inout GoalProgrammingDraft) -> Void) {
    guard var next = workspace.goalProgrammingDraft else { return }
    mutation(&next)
    workspace.replaceGoalProgrammingDraft(next, undoManager: undoManager, actionName: name)
  }
  private func pasteVariables() {
    do {
      guard var next = draft else { throw SpreadsheetTransferError.emptyClipboard }
      try next.replaceVariables(with: SpreadsheetClipboard.read())
      workspace.replaceGoalProgrammingDraft(
        next, undoManager: undoManager, actionName: "Paste Variables")
      if focusedVariableID.map({ id in next.variables.contains { $0.id == id } }) != true {
        focusedVariableID = next.variables.first?.id
      }
      transferIssue = nil
    } catch { transferIssue = String(describing: error) }
  }
  private func pasteGoals() {
    do {
      guard var next = draft else { throw SpreadsheetTransferError.emptyClipboard }
      try next.replaceGoals(with: SpreadsheetClipboard.read())
      workspace.replaceGoalProgrammingDraft(
        next, undoManager: undoManager, actionName: "Paste Goals")
      if focusedGoalID.map({ id in next.goals.contains { $0.id == id } }) != true {
        focusedGoalID = next.goals.first?.id
      }
      transferIssue = nil
    } catch { transferIssue = String(describing: error) }
  }
  private func pasteConstraints() {
    do {
      guard var next = draft else { throw SpreadsheetTransferError.emptyClipboard }
      try next.replaceConstraints(with: SpreadsheetClipboard.read())
      workspace.replaceGoalProgrammingDraft(
        next, undoManager: undoManager, actionName: "Paste Constraints")
      if focusedConstraintID.map({ id in next.constraints.contains { $0.id == id } }) != true {
        focusedConstraintID = next.constraints.first?.id
      }
      focusedEmptyConstraintAction = next.constraints.isEmpty
      transferIssue = nil
    } catch { transferIssue = String(describing: error) }
  }
}

extension Collection {
  fileprivate subscript(safe index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
