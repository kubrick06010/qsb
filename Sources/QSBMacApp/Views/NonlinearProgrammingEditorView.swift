import QSBCore
import SwiftUI

struct NonlinearProgrammingEditorView: View {
  @Bindable var workspace: QSBWorkspace
  @Environment(\.undoManager) private var undoManager
  private enum VariableField: Hashable { case name, lower, upper }
  private enum ConstraintField: Hashable { case name, expression, relation, rhs }
  private enum FieldFocus: Hashable {
    case variable(UUID, VariableField)
    case constraint(UUID, ConstraintField)
    case addConstraint
  }
  @FocusState private var focusedField: FieldFocus?
  @State private var transferIssue: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HeaderView(
        title: workspace.modelTitle,
        subtitle: "Nonlinear Programming · \(workspace.modelState.rawValue)")
      if let draft = workspace.nonlinearProgrammingDraft {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            HStack {
              Button("Validate", systemImage: "checkmark.seal") { workspace.validateCurrentModel() }
                .keyboardShortcut("v", modifiers: [.command, .shift])
              Button("Run", systemImage: "play.circle") { workspace.startCurrentModelRun() }
                .buttonStyle(.borderedProminent).keyboardShortcut("r", modifiers: .command)
                .disabled(workspace.modelState == .invalid || workspace.runState == .solving)
            }
            let diagnostics = draft.draftDiagnostics().filter { $0.severity != .info }
            ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, issue in
              Label(issue.message, systemImage: "exclamationmark.triangle")
                .font(.caption).foregroundStyle(issue.severity == .error ? .red : .orange)
            }
            Text(
              "The native solver searches for an approximate optimum; it does not guarantee a global optimum."
            )
            .font(.caption).foregroundStyle(.secondary)
            GroupBox("Objective") {
              VStack(alignment: .leading, spacing: 10) {
                Text("Model title").font(.caption).foregroundStyle(.secondary)
                TextField("Model title", text: text(\.title)).accessibilityLabel("Model title")
                Picker("Sense", selection: senseBinding) {
                  Text("Minimize").tag(ObjectiveSense.minimize)
                  Text("Maximize").tag(ObjectiveSense.maximize)
                }.pickerStyle(.segmented)
                Text("Objective expression").font(.caption).foregroundStyle(.secondary)
                TextField(
                  "Objective expression", text: text(\.objectiveExpression), axis: .vertical
                )
                .font(.system(.body, design: .monospaced)).accessibilityLabel(
                  "Objective expression")
                Text(
                  "Use named variables, for example (x1 - 3)^2. Supported functions: exp, log, sqrt, sin, cos."
                )
                .font(.caption).foregroundStyle(.secondary)
              }.padding(8)
            }
            GroupBox("Variables and bounds") {
              VStack(alignment: .leading, spacing: 10) {
                if draft.hasImportedDimensionIssue {
                  Text("Imported dimensions need review. All available bounds are retained. Missing variable names are empty and missing bounds display unbounded. Review these values before accepting the displayed dimensions.")
                    .font(.caption).foregroundStyle(.secondary)
                  Button("Accept Displayed Dimensions") {
                    update("Review Imported Dimensions") { $0.confirmImportedDimensions() }
                  }
                  .accessibilityHint("Accepts missing bounds as unbounded. Empty variable names still require repair.")
                }
                Text("Blank bounds mean unbounded. Practical bounds help guide the native search.")
                  .font(.caption).foregroundStyle(.secondary)
                ScrollView(.horizontal) {
                  VStack(alignment: .leading, spacing: 8) {
                    HStack {
                      heading("Variable", 180)
                      heading("Lower bound", 140)
                      heading("Upper bound", 140)
                    }
                    ForEach(draft.variables) { row in
                      HStack {
                        TextField("Name", text: variableText(row.id, \.name)).frame(width: 180)
                          .focused($focusedField, equals: .variable(row.id, .name)).accessibilityLabel(
                            "Variable \(row.name) name")
                        TextField("Lower", text: variableText(row.id, \.lowerBound)).frame(
                          width: 140
                        )
                        .focused($focusedField, equals: .variable(row.id, .lower))
                        .accessibilityLabel("Lower bound for \(row.name)")
                        TextField("Upper", text: variableText(row.id, \.upperBound)).frame(
                          width: 140
                        )
                        .focused($focusedField, equals: .variable(row.id, .upper))
                        .accessibilityLabel("Upper bound for \(row.name)")
                        Button {
                          removeVariable(row.id)
                        } label: {
                          Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless).disabled(draft.variables.count <= 1)
                        .accessibilityLabel("Remove variable \(row.name)")
                      }
                    }
                  }.padding(.bottom, 4)
                }
                Button("Add Variable", systemImage: "plus") {
                  update("Add Variable") { focusedField = .variable($0.addVariable(), .name) }
                }
                SpreadsheetTransferActions(
                  subject: "nonlinear variables", issue: transferIssue,
                  paste: { paste(variables: true) },
                  copy: { SpreadsheetClipboard.write(draft.variablesTable()) })
              }.padding(8)
            }
            GroupBox("Constraints") {
              VStack(alignment: .leading, spacing: 10) {
                if draft.constraints.isEmpty {
                  Text("No constraints. Add a row or paste a constraint table.").foregroundStyle(
                    .secondary)
                }
                ScrollView(.horizontal) {
                  VStack(alignment: .leading, spacing: 8) {
                    HStack {
                      heading("Constraint", 180)
                      heading("Expression", 300)
                      heading("Relation", 100)
                      heading("RHS", 110)
                    }
                    ForEach(draft.constraints) { row in
                      HStack {
                        TextField("Name", text: constraintText(row.id, \.name)).frame(width: 180)
                          .focused($focusedField, equals: .constraint(row.id, .name)).accessibilityLabel(
                            "Constraint \(row.name) name")
                        TextField("Expression", text: constraintText(row.id, \.expression)).frame(
                          width: 300
                        )
                        .focused($focusedField, equals: .constraint(row.id, .expression))
                        .accessibilityLabel("Expression for \(row.name)")
                        Picker("Relation", selection: constraintRelation(row.id)) {
                          Text("≤").tag(NonlinearConstraintRelation.lessThanOrEqual)
                          Text("=").tag(NonlinearConstraintRelation.equal)
                          Text("≥").tag(NonlinearConstraintRelation.greaterThanOrEqual)
                        }.labelsHidden().frame(width: 100)
                          .focused($focusedField, equals: .constraint(row.id, .relation)).accessibilityLabel(
                          "Relation for \(row.name)")
                        TextField("RHS", text: constraintText(row.id, \.rhs)).frame(width: 110)
                          .focused($focusedField, equals: .constraint(row.id, .rhs))
                          .accessibilityLabel("Right hand side for \(row.name)")
                        Button {
                          removeConstraint(row.id)
                        } label: {
                          Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless).accessibilityLabel(
                          "Remove constraint \(row.name)")
                      }
                    }
                  }.padding(.bottom, 4)
                }
                Button("Add Constraint", systemImage: "plus") {
                  update("Add Constraint") { focusedField = .constraint($0.addConstraint(), .name) }
                }
                .focused($focusedField, equals: .addConstraint)
                SpreadsheetTransferActions(
                  subject: "nonlinear constraints", issue: transferIssue,
                  paste: { paste(variables: false) },
                  copy: { SpreadsheetClipboard.write(draft.constraintsTable()) })
              }.padding(8)
            }
          }.textFieldStyle(.roundedBorder).padding(20)
            .frame(maxWidth: 1360, alignment: .leading).frame(
              maxWidth: .infinity, alignment: .leading)
        }
      }
    }.navigationTitle("Nonlinear Programming Definition")
      .onChange(of: workspace.nonlinearProgrammingDraft?.variables.map(\.id) ?? []) { previous, current in
        guard workspace.nonlinearProgrammingDraft != nil else { focusedField = nil; return }
        guard case let .variable(id, field) = focusedField, !current.contains(id) else { return }
        let index = previous.firstIndex(of: id) ?? 0
        focusedField = current.isEmpty ? nil : .variable(current[min(index, current.count - 1)], field)
      }
      .onChange(of: workspace.nonlinearProgrammingDraft?.constraints.map(\.id) ?? []) { previous, current in
        guard workspace.nonlinearProgrammingDraft != nil else { focusedField = nil; return }
        guard case let .constraint(id, field) = focusedField, !current.contains(id) else { return }
        let index = previous.firstIndex(of: id) ?? 0
        focusedField = current.isEmpty ? .addConstraint : .constraint(current[min(index, current.count - 1)], field)
      }
  }

  private func heading(_ label: String, _ width: CGFloat) -> some View {
    Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(
      width: width, alignment: .leading)
  }
  private var senseBinding: Binding<ObjectiveSense> {
    Binding(
      get: { workspace.nonlinearProgrammingDraft?.sense ?? .minimize },
      set: { newValue in update("Edit Sense") { $0.sense = newValue } })
  }
  private func text(_ key: WritableKeyPath<NonlinearProgrammingDraft, String>) -> Binding<String> {
    Binding(
      get: { workspace.nonlinearProgrammingDraft?[keyPath: key] ?? "" },
      set: { newValue in update("Edit Nonlinear Program") { $0[keyPath: key] = newValue } })
  }
  private func variableText(_ id: UUID, _ key: WritableKeyPath<NonlinearVariableDraft, String>)
    -> Binding<String>
  {
    Binding(
      get: {
        workspace.nonlinearProgrammingDraft?.variables.first { $0.id == id }?[keyPath: key] ?? ""
      },
      set: { newValue in
        update("Edit Variable") { draft in
          if let i = draft.variables.firstIndex(where: { $0.id == id }) {
            draft.variables[i][keyPath: key] = newValue
          }
        }
      })
  }
  private func constraintText(_ id: UUID, _ key: WritableKeyPath<NonlinearConstraintDraft, String>)
    -> Binding<String>
  {
    Binding(
      get: {
        workspace.nonlinearProgrammingDraft?.constraints.first { $0.id == id }?[keyPath: key] ?? ""
      },
      set: { newValue in
        update("Edit Constraint") { draft in
          if let i = draft.constraints.firstIndex(where: { $0.id == id }) {
            draft.constraints[i][keyPath: key] = newValue
          }
        }
      })
  }
  private func constraintRelation(_ id: UUID) -> Binding<NonlinearConstraintRelation> {
    Binding(
      get: {
        workspace.nonlinearProgrammingDraft?.constraints.first { $0.id == id }?.relation
          ?? .lessThanOrEqual
      },
      set: { newValue in
        update("Edit Relation") { draft in
          if let i = draft.constraints.firstIndex(where: { $0.id == id }) {
            draft.constraints[i].relation = newValue
          }
        }
      })
  }
  private func removeVariable(_ id: UUID) {
    update("Remove Variable") { draft in
      guard draft.variables.count > 1, let index = draft.variables.firstIndex(where: { $0.id == id }) else { return }
      draft.removeVariable(id: id)
      focusedField = .variable(draft.variables[min(index, draft.variables.count - 1)].id, .name)
    }
  }
  private func removeConstraint(_ id: UUID) {
    update("Remove Constraint") { draft in
      guard let index = draft.constraints.firstIndex(where: { $0.id == id }) else { return }
      draft.removeConstraint(id: id)
      focusedField = draft.constraints.isEmpty ? .addConstraint : .constraint(draft.constraints[min(index, draft.constraints.count - 1)].id, .name)
    }
  }
  private func update(_ action: String, _ edit: (inout NonlinearProgrammingDraft) -> Void) {
    guard var draft = workspace.nonlinearProgrammingDraft else { return }
    edit(&draft)
    workspace.replaceNonlinearProgrammingDraft(draft, undoManager: undoManager, actionName: action)
  }
  private func paste(variables: Bool) {
    do {
      let clipboard = try SpreadsheetClipboard.read()
      guard var draft = workspace.nonlinearProgrammingDraft else { return }
      if variables {
        try draft.replaceVariables(with: clipboard)
      } else {
        try draft.replaceConstraints(with: clipboard)
      }
      workspace.replaceNonlinearProgrammingDraft(
        draft, undoManager: undoManager, actionName: "Paste Table")
      switch focusedField {
      case let .variable(id, _) where variables && draft.variables.contains(where: { $0.id == id }): break
      case let .constraint(id, _) where !variables && draft.constraints.contains(where: { $0.id == id }): break
      default:
        focusedField = variables
          ? draft.variables.first.map { .variable($0.id, .name) }
          : draft.constraints.first.map { .constraint($0.id, .name) } ?? .addConstraint
      }
      transferIssue = nil
    } catch { transferIssue = String(describing: error) }
  }
}
