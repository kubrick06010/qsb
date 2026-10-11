import QSBCore
import SwiftUI

struct QuadraticProgrammingEditorView: View {
  enum Section: String, CaseIterable, Identifiable {
    case variables = "Variables"
    case matrix = "Quadratic Matrix"
    case constraints = "Constraints"
    var id: Self { self }
  }
  @Bindable var workspace: QSBWorkspace
  @Environment(\.undoManager) private var undoManager
  @FocusState private var focusedVariableID: UUID?
  @FocusState private var focusedConstraintID: UUID?
  @FocusState private var focusedEmptyConstraintAction: Bool
  private struct MatrixCell: Hashable {
    let row: UUID
    let column: UUID
  }
  @FocusState private var focusedMatrixCell: MatrixCell?
  @State private var selectedMatrixRow: UUID?
  @State private var matrixColumnGroup = 0
  @State private var section: Section
  @State private var transferIssue: String?

  init(workspace: QSBWorkspace, initialSection: Section = .variables,
    initialMatrixRow: UUID? = nil, initialMatrixColumnGroup: Int = 0) {
    self.workspace = workspace
    _section = State(initialValue: initialSection)
    _selectedMatrixRow = State(initialValue: initialMatrixRow)
    _matrixColumnGroup = State(initialValue: initialMatrixColumnGroup)
  }
  private var draft: QuadraticProgrammingDraft? { workspace.quadraticProgrammingDraft }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HeaderView(
        title: workspace.modelTitle,
        subtitle: "Native quadratic-programming editor · \(workspace.modelState.rawValue)")
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
    }.navigationTitle("Quadratic Programming Definition")
      .onChange(of: section) { _, _ in transferIssue = nil }
      .onChange(of: draft?.variables.map(\.id) ?? []) { previous, current in
        focusedVariableID = repairedEditorRowSelection(focusedVariableID, previous: previous, current: current)
        selectedMatrixRow = repairedEditorRowSelection(selectedMatrixRow, previous: previous, current: current)
        matrixColumnGroup = min(matrixColumnGroup, max(0, (current.count - 1) / 12))
        if let cell = focusedMatrixCell,
           let row = repairedEditorRowSelection(cell.row, previous: previous, current: current),
           let column = repairedEditorRowSelection(cell.column, previous: previous, current: current) {
          focusedMatrixCell = MatrixCell(row: row, column: column)
          selectedMatrixRow = row
          if let columnIndex = current.firstIndex(of: column) { matrixColumnGroup = columnIndex / 12 }
        } else { focusedMatrixCell = nil }
      }
      .onChange(of: draft?.constraints.map(\.id) ?? []) { previous, current in
        let hadFocus = focusedConstraintID != nil
        focusedConstraintID = repairedEditorRowSelection(focusedConstraintID, previous: previous, current: current)
        if hadFocus { focusedEmptyConstraintAction = current.isEmpty && draft != nil && section == .constraints }
      }
  }

  private var actionBar: some View {
    ViewThatFits(in: .horizontal) {
      HStack {
        buttons
        Spacer()
        Text("Quadratic Programming").foregroundStyle(.secondary)
      }
      VStack(alignment: .leading) {
        HStack { buttons }
        Text("Quadratic Programming").foregroundStyle(.secondary)
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
    GroupBox("Objective") {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .bottom, spacing: 16) { settingsFields }
        VStack(alignment: .leading, spacing: 10) { settingsFields }
      }.padding(8)
    }
  }
  @ViewBuilder private var settingsFields: some View {
    labeled("Title", text: binding(\.title, "Edit Title"), width: 330)
    VStack(alignment: .leading, spacing: 4) {
      Text("Sense").font(.caption).foregroundStyle(.secondary)
      Picker(
        "Sense",
        selection: Binding(
          get: { draft?.sense ?? .minimize },
          set: { v in update("Change Objective Sense") { $0.sense = v } })
      ) {
        Text("Minimize").tag(ObjectiveSense.minimize)
        Text("Maximize").tag(ObjectiveSense.maximize)
      }.labelsHidden().pickerStyle(.segmented).frame(width: 200).accessibilityLabel(
        "Objective sense")
    }
  }
  private var sectionPicker: some View {
    Picker("Definition section", selection: $section) {
      ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
    }.pickerStyle(.segmented).accessibilityLabel("Quadratic programming definition section")
  }
  @ViewBuilder private func sectionBody(_ draft: QuadraticProgrammingDraft) -> some View {
    switch section {
    case .variables: variables(draft)
    case .matrix: matrix(draft)
    case .constraints: constraints(draft)
    }
  }

  private func variables(_ draft: QuadraticProgrammingDraft) -> some View {
    GroupBox("Variables and linear objective") {
      VStack(alignment: .leading, spacing: 10) {
        if draft.hasImportedDimensionIssue {
          VStack(alignment: .leading, spacing: 6) {
            Text("Imported dimensions need review. Available coefficients are retained; missing cells and names are empty. Missing types display Continuous and missing bounds display unbounded. Review these defaults before accepting the displayed dimensions.")
              .font(.caption)
            Button("Use Displayed Dimensions") {
              update("Review Imported Dimensions") { $0.confirmImportedDimensions() }
            }
            .accessibilityHint("Accepts displayed type and bound defaults. Missing names and coefficients still require correction.")
          }
        }
        Text("Blank bounds mean unbounded. Variable names also label matrix rows and columns.")
          .font(.caption).foregroundStyle(.secondary)
        ScrollView(.horizontal) {
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
              header("Variable", 180)
              header("Type", 130)
              header("Lower", 110)
              header("Upper", 110)
              header("Linear", 120)
              Color.clear.frame(width: 28)
            }
            ForEach(Array(draft.variables.enumerated()), id: \.element.id) { i, v in
              variableRow(v, index: i, count: draft.variables.count)
            }
          }.padding(.bottom, 4)
        }
        actions(
          subject: "quadratic variables", addTitle: "Add Variable",
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
      TextField("", text: linearText(index)).frame(width: 120).accessibilityLabel(
        "Linear coefficient for \(variable.name)")
      Button {
        removeVariable(variable.id)
      } label: {
        Image(systemName: "minus.circle")
      }.buttonStyle(.borderless).disabled(count <= 1).accessibilityLabel(
        "Remove variable \(variable.name)")
    }
  }

  private func matrix(_ draft: QuadraticProgrammingDraft) -> some View {
    GroupBox("Quadratic matrix") {
      VStack(alignment: .leading, spacing: 10) {
        Text(
          "The matrix is Q in xᵀQx. It must remain symmetric; horizontal scrolling supports large models."
        ).font(.caption).foregroundStyle(.secondary)
        if draft.variables.count > 12 {
          pagedMatrix(draft)
        } else {
          ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 6) {
              HStack(spacing: 6) {
                header("Variable", 120)
                ForEach(draft.variables) { header($0.name, 100) }
              }
              ForEach(Array(draft.variables.enumerated()), id: \.element.id) { row, v in
                HStack(spacing: 6) {
                  Text(v.name).frame(width: 120, alignment: .leading)
                  ForEach(draft.variables.indices, id: \.self) { column in
                    TextField("", text: matrixText(row, column)).textFieldStyle(.roundedBorder).frame(
                      width: 100
                    ).focused($focusedMatrixCell, equals: MatrixCell(row: v.id, column: draft.variables[column].id))
                    .accessibilityLabel(
                      "Quadratic coefficient, row \(row + 1) \(v.name), column \(column + 1) \(draft.variables[column].name)")
                  }
                }
              }
            }.padding(.bottom, 4)
          }
        }
        SpreadsheetTransferActions(
          subject: "quadratic matrix", issue: transferIssue, paste: pasteMatrix,
          copy: { SpreadsheetClipboard.write(draft.quadraticTable()) })
      }.padding(8)
    }
  }

  private func pagedMatrix(_ draft: QuadraticProgrammingDraft) -> some View {
    let rowIndex = draft.variables.firstIndex { $0.id == selectedMatrixRow } ?? 0
    let row = draft.variables[rowIndex]
    let groups = (draft.variables.count + 11) / 12
    let group = min(max(0, matrixColumnGroup), groups - 1)
    let columns = (group * 12)..<min((group + 1) * 12, draft.variables.count)
    return VStack(alignment: .leading, spacing: 10) {
      Text("Select a row and a column group to edit this large matrix. Copy/Paste Table transfers the entire matrix.")
        .font(.caption).foregroundStyle(.secondary)
      ViewThatFits(in: .horizontal) {
        HStack { matrixNavigation(draft, rowIndex: rowIndex, group: group, groups: groups) }
        VStack(alignment: .leading) { matrixNavigation(draft, rowIndex: rowIndex, group: group, groups: groups) }
      }
      ScrollView(.horizontal) {
        HStack(alignment: .top, spacing: 8) {
          ForEach(Array(columns), id: \.self) { column in
            VStack(alignment: .leading, spacing: 4) {
              header(draft.variables[column].name, 100)
              TextField("", text: matrixText(rowIndex, column))
                .textFieldStyle(.roundedBorder).frame(width: 100)
                .focused($focusedMatrixCell, equals: MatrixCell(row: row.id, column: draft.variables[column].id))
                .accessibilityLabel("Quadratic coefficient, row \(rowIndex + 1) \(row.name), column \(column + 1) \(draft.variables[column].name)")
            }
          }
        }.padding(.bottom, 4)
      }
      Text("Row \(rowIndex + 1) of \(draft.variables.count) · columns \(columns.lowerBound + 1)–\(columns.upperBound) of \(draft.variables.count)")
        .font(.caption).foregroundStyle(.secondary)
    }
  }
  @ViewBuilder private func matrixNavigation(_ draft: QuadraticProgrammingDraft, rowIndex: Int, group: Int, groups: Int) -> some View {
    Picker("Matrix row", selection: Binding(
      get: { draft.variables[rowIndex].id },
      set: { selectedMatrixRow = $0; focusMatrixRow(draft, rowID: $0, group: group) }
    )) {
      ForEach(draft.variables) { Text($0.name).tag($0.id) }
    }.frame(width: 240).accessibilityLabel("Quadratic matrix row")
    Button("Previous Row") {
      selectedMatrixRow = draft.variables[rowIndex - 1].id
      focusMatrixRow(draft, rowID: draft.variables[rowIndex - 1].id, group: group)
    }.disabled(rowIndex == 0)
    Button("Next Row") {
      selectedMatrixRow = draft.variables[rowIndex + 1].id
      focusMatrixRow(draft, rowID: draft.variables[rowIndex + 1].id, group: group)
    }.disabled(rowIndex + 1 == draft.variables.count)
    Picker("Columns", selection: Binding(
      get: { group },
      set: { matrixColumnGroup = $0; focusMatrixRow(draft, rowID: draft.variables[rowIndex].id, group: $0) }
    )) {
      ForEach(0..<groups, id: \.self) { index in
        Text("\(index * 12 + 1)–\(min((index + 1) * 12, draft.variables.count))").tag(index)
      }
    }.frame(width: 180).accessibilityLabel("Quadratic matrix column group")
  }
  private func focusMatrixRow(_ draft: QuadraticProgrammingDraft, rowID: UUID, group: Int) {
    let column = min(max(0, group * 12), draft.variables.count - 1)
    focusedMatrixCell = MatrixCell(row: rowID, column: draft.variables[column].id)
  }

  private func constraints(_ draft: QuadraticProgrammingDraft) -> some View {
    GroupBox("Linear constraints") {
      VStack(alignment: .leading, spacing: 10) {
        if draft.constraints.isEmpty {
          Text("No linear constraints. Add a constraint or paste a constraint table.")
            .font(.caption).foregroundStyle(.secondary)
        }
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
        actions(
          subject: "quadratic constraints", addTitle: "Add Constraint",
          add: {
            var id: UUID?
            update("Add Constraint") { id = $0.addConstraint() }
            focusedConstraintID = id
          }, paste: pasteConstraints, copy: { SpreadsheetClipboard.write(draft.constraintsTable()) }
        )
      }.padding(8)
    }
  }
  private func constraintRow(_ c: OptimizationConstraintDraft, draft: QuadraticProgrammingDraft)
    -> some View
  {
    HStack(spacing: 6) {
      TextField("Constraint", text: constraintText(c.id, \.name)).textFieldStyle(.roundedBorder)
        .frame(width: 170).focused($focusedConstraintID, equals: c.id).accessibilityLabel(
          "Constraint \(draft.constraints.firstIndex(where: { $0.id == c.id }).map { $0 + 1 } ?? 1) name")
      ForEach(draft.variables.indices, id: \.self) { i in
        TextField("", text: constraintCoefficient(c.id, i)).frame(width: 90).accessibilityLabel(
          "Coefficient for \(draft.variables[i].name) in \(c.name)")
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

  @ViewBuilder private func issues(_ draft: QuadraticProgrammingDraft) -> some View {
    let ds = draft.draftDiagnostics().filter { $0.severity != .info }
    if !ds.isEmpty {
      VStack(alignment: .leading, spacing: 4) {
        ForEach(Array(ds.enumerated()), id: \.offset) { _, d in
          Label(d.message, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(
            d.severity == .error ? .red : .orange)
        }
      }.accessibilityElement(children: .contain).accessibilityLabel(
        "Quadratic programming input issues")
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
  private func binding(_ kp: WritableKeyPath<QuadraticProgrammingDraft, String>, _ action: String)
    -> Binding<String>
  {
    Binding(
      get: { workspace.quadraticProgrammingDraft?[keyPath: kp] ?? "" },
      set: { v in update(action) { $0[keyPath: kp] = v } })
  }
  private func variableText(_ id: UUID, _ kp: WritableKeyPath<OptimizationVariableDraft, String>)
    -> Binding<String>
  {
    Binding(
      get: {
        workspace.quadraticProgrammingDraft?.variables.first { $0.id == id }?[keyPath: kp] ?? ""
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
        workspace.quadraticProgrammingDraft?.variables.first { $0.id == id }?.type ?? .continuous
      },
      set: { v in
        update("Change Variable Type") {
          if let i = $0.variables.firstIndex(where: { $0.id == id }) { $0.variables[i].type = v }
        }
      })
  }
  private func linearText(_ i: Int) -> Binding<String> {
    Binding(
      get: { workspace.quadraticProgrammingDraft?.linearCoefficients[safe: i] ?? "" },
      set: { v in
        update("Edit Linear Coefficient") {
          if $0.linearCoefficients.indices.contains(i) { $0.linearCoefficients[i] = v }
        }
      })
  }
  private func matrixText(_ r: Int, _ c: Int) -> Binding<String> {
    Binding(
      get: { workspace.quadraticProgrammingDraft?.quadraticMatrix[safe: r]?[safe: c] ?? "" },
      set: { v in
        update("Edit Quadratic Matrix") {
          if $0.quadraticMatrix.indices.contains(r), $0.quadraticMatrix[r].indices.contains(c) {
            $0.quadraticMatrix[r][c] = v
          }
        }
      })
  }
  private func constraintText(
    _ id: UUID, _ kp: WritableKeyPath<OptimizationConstraintDraft, String>
  ) -> Binding<String> {
    Binding(
      get: {
        workspace.quadraticProgrammingDraft?.constraints.first { $0.id == id }?[keyPath: kp] ?? ""
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
        workspace.quadraticProgrammingDraft?.constraints.first { $0.id == id }?.coefficients[
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
        workspace.quadraticProgrammingDraft?.constraints.first { $0.id == id }?.relation
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
  private func update(_ name: String, _ mutation: (inout QuadraticProgrammingDraft) -> Void) {
    guard var next = workspace.quadraticProgrammingDraft else { return }
    mutation(&next)
    workspace.replaceQuadraticProgrammingDraft(next, undoManager: undoManager, actionName: name)
  }
  private func removeVariable(_ id: UUID) {
    guard let current = draft, let index = current.variables.firstIndex(where: { $0.id == id }) else { return }
    update("Remove Variable") { $0.removeVariable(id: id) }
    if let next = draft, !next.variables.isEmpty {
      focusedVariableID = next.variables[min(index, next.variables.count - 1)].id
    }
  }
  private func removeConstraint(_ id: UUID) {
    guard let current = draft, let index = current.constraints.firstIndex(where: { $0.id == id }) else { return }
    update("Remove Constraint") { $0.removeConstraint(id: id) }
    if let next = draft, !next.constraints.isEmpty {
      focusedConstraintID = next.constraints[min(index, next.constraints.count - 1)].id
    } else {
      focusedConstraintID = nil
      focusedEmptyConstraintAction = true
    }
  }
  private func pasteVariables() {
    do {
      guard var next = draft else { throw SpreadsheetTransferError.emptyClipboard }
      try next.replaceVariables(with: SpreadsheetClipboard.read())
      workspace.replaceQuadraticProgrammingDraft(
        next, undoManager: undoManager, actionName: "Paste Variables")
      if focusedVariableID.map({ id in next.variables.contains { $0.id == id } }) != true {
        focusedVariableID = next.variables.first?.id
      }
      transferIssue = nil
    } catch { transferIssue = String(describing: error) }
  }
  private func pasteMatrix() {
    do {
      guard var next = draft else { throw SpreadsheetTransferError.emptyClipboard }
      try next.replaceQuadratic(with: SpreadsheetClipboard.read())
      workspace.replaceQuadraticProgrammingDraft(
        next, undoManager: undoManager, actionName: "Paste Quadratic Matrix")
      if let cell = focusedMatrixCell,
         next.variables.contains(where: { $0.id == cell.row }),
         let column = next.variables.firstIndex(where: { $0.id == cell.column }) {
        selectedMatrixRow = cell.row
        matrixColumnGroup = column / MatrixEditorNavigation.columnsPerGroup
      } else if let row = next.variables.first(where: { $0.id == selectedMatrixRow }) ?? next.variables.first {
        selectedMatrixRow = row.id
        matrixColumnGroup = min(matrixColumnGroup, max(0, (next.variables.count - 1) / MatrixEditorNavigation.columnsPerGroup))
        focusMatrixRow(next, rowID: row.id, group: matrixColumnGroup)
      }
      transferIssue = nil
    } catch { transferIssue = String(describing: error) }
  }
  private func pasteConstraints() {
    do {
      guard var next = draft else { throw SpreadsheetTransferError.emptyClipboard }
      try next.replaceConstraints(with: SpreadsheetClipboard.read())
      workspace.replaceQuadraticProgrammingDraft(
        next, undoManager: undoManager, actionName: "Paste Constraints")
      if focusedConstraintID.map({ id in next.constraints.contains { $0.id == id } }) != true {
        focusedConstraintID = next.constraints.first?.id
      }
      focusedEmptyConstraintAction = next.constraints.isEmpty
      transferIssue = nil
    } catch { transferIssue = String(describing: error) }
  }
}

private extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}
