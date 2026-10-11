import QSBCore
import SwiftUI

struct FacilityLayoutEditorView: View {
  enum Section: String, CaseIterable, Identifiable {
    case departments = "Departments"
    case rectangles = "Cell Rectangles"
    case costs = "Flow Costs"
    var id: Self { self }
  }
  @Bindable var workspace: QSBWorkspace
  @Environment(\.undoManager) private var undoManager
  @State private var section: Section
  @State private var selectedDepartment: UUID?
  @State private var transferIssue: String?
  @State private var matrixFocusRequest = 0
  @FocusState private var focusedRow: UUID?
  @FocusState private var focusedAddRectangle: Bool
  init(workspace: QSBWorkspace, initialSection: Section = .departments,
    initialMatrixRow: UUID? = nil, initialMatrixColumnGroup: Int = 0) {
    self.workspace = workspace
    self.initialMatrixRow = initialMatrixRow
    self.initialMatrixColumnGroup = initialMatrixColumnGroup
    _section = State(initialValue: initialSection)
  }
  private let initialMatrixRow: UUID?
  private let initialMatrixColumnGroup: Int
  private var draft: FacilityLayoutDraft? { workspace.facilityLayoutDraft }
  private var departmentID: UUID? {
    if let selectedDepartment,
      draft?.departments.contains(where: { $0.id == selectedDepartment }) == true
    {
      return selectedDepartment
    }
    return draft?.departments.first?.id
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HeaderView(
        title: workspace.modelTitle, subtitle: "Facility Layout · \(workspace.modelState.rawValue)")
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
            GroupBox("Layout grid") {
              VStack(alignment: .leading, spacing: 10) {
                Text("Model title").font(.caption).foregroundStyle(.secondary)
                TextField("Title", text: text(\.title)).accessibilityLabel("Model title")
                ViewThatFits(in: .horizontal) {
                  HStack(alignment: .bottom, spacing: 16) { gridFields }
                  VStack(alignment: .leading, spacing: 10) { gridFields }
                }
                Picker("Objective", selection: text(\.objective)) {
                  Text("Minimize load-distance").tag("MIN")
                  if draft.objective != "MIN" {
                    Text("Unsupported imported objective: \(draft.objective)").tag(draft.objective)
                  }
                }
                Text(
                  "Grid cells start at row 1, column 1. Rectangle end coordinates are inclusive. The Run inspector selects initial evaluation or pairwise swaps."
                )
                .font(.caption).foregroundStyle(.secondary)
              }.padding(8)
            }
            Picker("Definition section", selection: $section) {
              ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).accessibilityLabel("Facility layout definition section")
            sectionBody(draft)
          }.textFieldStyle(.roundedBorder).padding(20)
            .frame(maxWidth: 1360, alignment: .leading).frame(
              maxWidth: .infinity, alignment: .leading)
        }
      }
    }.navigationTitle("Facility Layout Definition")
      .onChange(of: draft?.departments ?? []) { previous, current in
        let previousIDs = previous.map(\.id)
        let currentIDs = current.map(\.id)
        selectedDepartment = repairedEditorRowSelection(selectedDepartment, previous: previousIDs, current: currentIDs)
        guard let focusedRow else { return }
        if currentIDs.contains(focusedRow) { return }
        if previousIDs.contains(focusedRow) {
          self.focusedRow = repairedEditorRowSelection(focusedRow, previous: previousIDs, current: currentIDs)
        } else if section == .rectangles {
          let previousDepartment = previous.first { $0.id == departmentID }
            ?? previous.first { $0.rectangles.contains { $0.id == focusedRow } }
          let previousRectangles = previousDepartment?.rectangles.map(\.id) ?? []
          let visibleRectangles = current.first { $0.id == departmentID }?.rectangles.map(\.id) ?? []
          self.focusedRow = repairedEditorRowSelection(focusedRow, previous: previousRectangles, current: visibleRectangles)
          focusedAddRectangle = visibleRectangles.isEmpty && departmentID != nil && section == .rectangles
        }
      }
      .onChange(of: departmentID) { _, _ in
        guard section == .rectangles, let focusedRow else { return }
        let visibleRectangles = draft?.departments.first { $0.id == departmentID }?.rectangles.map(\.id) ?? []
        self.focusedRow = repairedEditorRowSelection(focusedRow, previous: [], current: visibleRectangles)
        focusedAddRectangle = visibleRectangles.isEmpty && departmentID != nil
      }
  }
  @ViewBuilder private var gridFields: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Grid rows").font(.caption).foregroundStyle(.secondary)
      TextField("Rows", text: text(\.rowCount)).frame(width: 140).accessibilityLabel("Grid rows")
    }
    VStack(alignment: .leading, spacing: 4) {
      Text("Grid columns").font(.caption).foregroundStyle(.secondary)
      TextField("Columns", text: text(\.columnCount)).frame(width: 140).accessibilityLabel(
        "Grid columns")
    }
  }
  @ViewBuilder private func sectionBody(_ draft: FacilityLayoutDraft) -> some View {
    switch section {
    case .departments: departments(draft)
    case .rectangles: rectangles(draft)
    case .costs: costs(draft)
    }
  }
  private func departments(_ draft: FacilityLayoutDraft) -> some View {
    GroupBox("Departments") {
      VStack(alignment: .leading, spacing: 10) {
        Text(
          "Fixed departments retain their position during pairwise swaps. Department IDs preserve rectangles and cost coefficients when pasted in a different order."
        )
        .font(.caption).foregroundStyle(.secondary)
        ScrollView(.horizontal) {
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
              heading("ID", 70)
              heading("Department", 220)
              heading("Fixed", 70)
              heading("Rectangles", 100)
            }
            ForEach(draft.departments) { row in
              HStack(spacing: 8) {
                TextField("ID", text: departmentText(row.id, \.sourceID)).frame(width: 70)
                  .accessibilityLabel("ID for \(row.name)")
                TextField("Department", text: departmentText(row.id, \.name)).frame(width: 220)
                  .focused($focusedRow, equals: row.id).accessibilityLabel(
                    "Department \(row.sourceID) name")
                Toggle("Fixed", isOn: fixed(row.id)).labelsHidden().frame(width: 70)
                  .accessibilityLabel("\(row.name) has a fixed location")
                Text(String(row.rectangles.count)).frame(width: 100).accessibilityLabel(
                  "\(row.name) has \(row.rectangles.count) rectangles")
                Button("Edit Cells") {
                  selectedDepartment = row.id
                  section = .rectangles
                }
                .accessibilityLabel("Edit cell rectangles for \(row.name)")
                Button {
                  removeDepartment(row.id)
                } label: {
                  Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless).disabled(draft.departments.count <= 1).accessibilityLabel(
                  "Remove department \(row.name)")
              }
            }
          }.padding(.bottom, 4)
        }
        Button("Add Department", systemImage: "plus") {
          var id: UUID?
          update("Add Department") { id = $0.addDepartment() }
          focusedRow = id
        }
        transfer(draft, section: .departments)
      }.padding(8)
    }
  }
  private func rectangles(_ draft: FacilityLayoutDraft) -> some View {
    GroupBox("Department cell rectangles") {
      VStack(alignment: .leading, spacing: 10) {
        Picker(
          "Department", selection: Binding(get: { departmentID }, set: { selectedDepartment = $0 })
        ) {
          ForEach(draft.departments) { Text($0.columnLabel).tag(Optional($0.id)) }
        }.accessibilityLabel("Department whose rectangles are being edited")
        if let id = departmentID, let department = draft.departments.first(where: { $0.id == id }) {
          if department.rectangles.isEmpty {
            Text("No rectangles. Add a rectangle or paste the full cell table.").foregroundStyle(
              .secondary)
          }
          ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 8) {
              HStack(spacing: 8) {
                heading("Start row", 120)
                heading("Start column", 120)
                heading("End row", 120)
                heading("End column", 120)
              }
              ForEach(Array(department.rectangles.enumerated()), id: \.element.id) { index, rect in
                HStack(spacing: 8) {
                  rectangleField(
                    "Start row", department: department, rect: rect, index: index, key: \.startRow
                  )
                  .focused($focusedRow, equals: rect.id)
                  rectangleField(
                    "Start column", department: department, rect: rect, index: index,
                    key: \.startColumn)
                  rectangleField(
                    "End row", department: department, rect: rect, index: index, key: \.endRow)
                  rectangleField(
                    "End column", department: department, rect: rect, index: index, key: \.endColumn
                  )
                  Button {
                    removeRectangle(department: id, rect: rect.id)
                  } label: {
                    Image(systemName: "minus.circle")
                  }
                  .buttonStyle(.borderless).accessibilityLabel(
                    "Remove rectangle \(index + 1) from \(department.name)")
                }
              }
            }.padding(.bottom, 4)
          }
          Button("Add Rectangle", systemImage: "plus") {
            update("Add Rectangle") { focusedRow = $0.addRectangle(departmentID: id) }
          }.focused($focusedAddRectangle)
        }
        Text(
          "Copy/Paste Table transfers rectangles for all departments, using department IDs. Pasting replaces the full rectangle table."
        )
        .font(.caption).foregroundStyle(.secondary)
        transfer(draft, section: .rectangles)
      }.padding(8)
    }
  }
  private func rectangleField(
    _ label: String, department: LayoutDepartmentDraft, rect: LayoutRectangleDraft, index: Int,
    key: WritableKeyPath<LayoutRectangleDraft, String>
  ) -> some View {
    TextField(label, text: rectangleText(department.id, rect.id, key)).frame(width: 120)
      .accessibilityLabel("\(label) of rectangle \(index + 1) in \(department.name)")
  }
  private func costs(_ draft: FacilityLayoutDraft) -> some View {
    GroupBox("Directed flow / unit costs") {
      VStack(alignment: .leading, spacing: 10) {
        Text(
          "Rows are sources, columns are destinations. Blank cells preserve missing interactions. Enter flow multiplied by unit cost in each cell."
        )
        .font(.caption).foregroundStyle(.secondary)
        NamedMatrixEditor(rows: draft.departments.map { MatrixAxisItem(id: $0.id, label: $0.columnLabel) },
          columns: draft.departments.map { MatrixAxisItem(id: $0.id, label: $0.columnLabel) }, accessibilityPrefix: "Flow/unit cost",
          focusRequest: matrixFocusRequest, initialRow: initialMatrixRow, initialColumnGroup: initialMatrixColumnGroup, value: costText)
        transfer(draft, section: .costs)
      }.padding(8)
    }
  }
  private func transfer(_ draft: FacilityLayoutDraft, section: Section) -> some View {
    SpreadsheetTransferActions(
      subject: "layout \(section.rawValue.lowercased())", issue: transferIssue,
      paste: { paste(section) },
      copy: {
        let table: String
        switch section {
        case .departments: table = draft.departmentsTable()
        case .rectangles: table = draft.rectanglesTable()
        case .costs: table = draft.costsTable()
        }
        SpreadsheetClipboard.write(table)
      })
  }
  @ViewBuilder private func issues(_ draft: FacilityLayoutDraft) -> some View {
    let issues = draft.draftDiagnostics().filter { $0.severity != .info }
    if !issues.isEmpty {
      VStack(alignment: .leading, spacing: 4) {
        ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
          Label(issue.message, systemImage: "exclamationmark.triangle").font(.caption)
            .foregroundStyle(issue.severity == .error ? .red : .orange)
        }
      }.accessibilityElement(children: .contain).accessibilityLabel("Facility layout input issues")
    }
  }
  private func heading(_ label: String, _ width: CGFloat) -> some View {
    Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(
      width: width, alignment: .leading)
  }
  private func text(_ key: WritableKeyPath<FacilityLayoutDraft, String>) -> Binding<String> {
    Binding(
      get: { draft?[keyPath: key] ?? "" },
      set: { value in update("Edit Layout Grid") { $0[keyPath: key] = value } })
  }
  private func departmentText(_ id: UUID, _ key: WritableKeyPath<LayoutDepartmentDraft, String>)
    -> Binding<String>
  {
    Binding(
      get: { draft?.departments.first { $0.id == id }?[keyPath: key] ?? "" },
      set: { value in
        update("Edit Department") {
          if let i = $0.departments.firstIndex(where: { $0.id == id }) {
            $0.departments[i][keyPath: key] = value
          }
        }
      })
  }
  private func fixed(_ id: UUID) -> Binding<Bool> {
    Binding(
      get: { draft?.departments.first { $0.id == id }?.fixed ?? false },
      set: { value in
        update("Change Fixed Department") {
          if let i = $0.departments.firstIndex(where: { $0.id == id }) {
            $0.departments[i].fixed = value
          }
        }
      })
  }
  private func rectangleText(
    _ department: UUID, _ rect: UUID, _ key: WritableKeyPath<LayoutRectangleDraft, String>
  ) -> Binding<String> {
    Binding(
      get: {
        draft?.departments.first { $0.id == department }?.rectangles.first { $0.id == rect }?[
          keyPath: key] ?? ""
      },
      set: { value in
        update("Edit Rectangle") {
          if let i = $0.departments.firstIndex(where: { $0.id == department }),
            let r = $0.departments[i].rectangles.firstIndex(where: { $0.id == rect })
          {
            $0.departments[i].rectangles[r][keyPath: key] = value
          }
        }
      })
  }
  private func costText(_ row: Int, _ column: Int) -> Binding<String> {
    Binding(
      get: { draft?.costs[safe: row]?[safe: column] ?? "" },
      set: { value in
        update("Edit Flow Cost") {
          if $0.costs.indices.contains(row), $0.costs[row].indices.contains(column) {
            $0.costs[row][column] = value
          }
        }
      })
  }
  private func removeDepartment(_ id: UUID) {
    update("Remove Department") { draft in
      guard draft.departments.count > 1,
        let i = draft.departments.firstIndex(where: { $0.id == id })
      else { return }
      draft.removeDepartment(id: id)
      focusedRow = draft.departments[min(i, draft.departments.count - 1)].id
    }
  }
  private func removeRectangle(department: UUID, rect: UUID) {
    update("Remove Rectangle") { draft in
      guard let i = draft.departments.firstIndex(where: { $0.id == department }),
        let r = draft.departments[i].rectangles.firstIndex(where: { $0.id == rect })
      else { return }
      draft.removeRectangle(departmentID: department, id: rect)
      focusedAddRectangle = draft.departments[i].rectangles.isEmpty
      focusedRow =
        draft.departments[i].rectangles.isEmpty
        ? nil
        : draft.departments[i].rectangles[min(r, draft.departments[i].rectangles.count - 1)].id
    }
  }
  private func update(_ name: String, _ edit: (inout FacilityLayoutDraft) -> Void) {
    guard var draft else { return }
    edit(&draft)
    workspace.replaceFacilityLayoutDraft(draft, undoManager: undoManager, actionName: name)
  }
  private func paste(_ section: Section) {
    do {
      let clipboard = try SpreadsheetClipboard.read()
      guard var draft else { return }
      switch section {
      case .departments: try draft.replaceDepartments(with: clipboard)
      case .rectangles: try draft.replaceRectangles(with: clipboard)
      case .costs: try draft.replaceCosts(with: clipboard)
      }
      workspace.replaceFacilityLayoutDraft(
        draft, undoManager: undoManager, actionName: "Paste Layout Table")
      if selectedDepartment.map({ id in draft.departments.contains { $0.id == id } }) != true {
        selectedDepartment = draft.departments.first?.id
      }
      let visibleRows = section == .rectangles
        ? draft.departments.first { $0.id == selectedDepartment }?.rectangles.map(\.id) ?? []
        : draft.departments.map(\.id)
      if section != .costs && focusedRow.map({ visibleRows.contains($0) }) != true { focusedRow = visibleRows.first }
      focusedAddRectangle = section == .rectangles && visibleRows.isEmpty && selectedDepartment != nil
      if section == .costs { matrixFocusRequest += 1 }
      transferIssue = nil
    } catch { transferIssue = String(describing: error) }
  }
}
extension Collection {
  fileprivate subscript(safe index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
