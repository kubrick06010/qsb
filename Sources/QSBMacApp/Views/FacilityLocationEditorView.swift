import QSBCore
import SwiftUI

struct FacilityLocationEditorView: View {
  enum Section: String, CaseIterable, Identifiable {
    case facilities = "Facilities"
    case interactions = "Interactions"
    var id: Self { self }
  }
  @Bindable var workspace: QSBWorkspace
  @Environment(\.undoManager) private var undoManager
  @FocusState private var focusedFacility: UUID?
  @State private var section: Section
  @State private var transferIssue: String?
  @State private var matrixFocusRequest = 0
  init(workspace: QSBWorkspace, initialSection: Section = .facilities,
    initialMatrixRow: UUID? = nil, initialMatrixColumnGroup: Int = 0) {
    self.workspace = workspace
    self.initialMatrixRow = initialMatrixRow
    self.initialMatrixColumnGroup = initialMatrixColumnGroup
    _section = State(initialValue: initialSection)
  }
  private let initialMatrixRow: UUID?
  private let initialMatrixColumnGroup: Int
  private var draft: FacilityLocationDraft? { workspace.facilityLocationDraft }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HeaderView(
        title: workspace.modelTitle,
        subtitle: "Facility Location · \(workspace.modelState.rawValue)")
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
            GroupBox("Location model") {
              VStack(alignment: .leading, spacing: 8) {
                Text("Model title").font(.caption).foregroundStyle(.secondary)
                TextField("Title", text: text(\.title)).accessibilityLabel("Model title")
                Picker("Distance measure", selection: distanceBinding) {
                  Text("Rectilinear").tag(FacilityLocationDistanceMeasure.rectilinear)
                  Text("Squared Euclidean").tag(FacilityLocationDistanceMeasure.squaredEuclidean)
                  Text("Euclidean").tag(FacilityLocationDistanceMeasure.euclidean)
                }
                Picker("Objective", selection: text(\.objective)) {
                  Text("Minimize weighted distance").tag("MIN")
                  if draft.objective != "MIN" {
                    Text("Unsupported imported objective: \(draft.objective)").tag(draft.objective)
                  }
                }.accessibilityLabel("Location objective")
                Text(
                  "The native solver minimizes weighted distance for one new facility. Mark it New and leave its coordinates blank; existing facilities require X and Y."
                )
                .font(.caption).foregroundStyle(.secondary)
              }.padding(8)
            }
            Picker("Definition section", selection: $section) {
              ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).accessibilityLabel("Facility location definition section")
            if section == .facilities { facilities(draft) } else { interactions(draft) }
          }.textFieldStyle(.roundedBorder).padding(20)
            .frame(maxWidth: 1360, alignment: .leading).frame(
              maxWidth: .infinity, alignment: .leading)
        }
      }
    }.navigationTitle("Facility Location Definition")
      .onChange(of: draft?.facilities.map(\.id) ?? []) { previous, current in
        focusedFacility = repairedEditorRowSelection(focusedFacility, previous: previous, current: current)
      }
  }
  private var distanceBinding: Binding<FacilityLocationDistanceMeasure> {
    Binding(
      get: { draft?.distanceMeasure ?? .rectilinear },
      set: { value in update("Change Distance Measure") { $0.distanceMeasure = value } })
  }
  private func facilities(_ draft: FacilityLocationDraft) -> some View {
    GroupBox("Facility coordinates") {
      VStack(alignment: .leading, spacing: 10) {
        ScrollView(.horizontal) {
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
              heading("ID", 70)
              heading("Facility", 200)
              heading("New", 60)
              heading("X", 130)
              heading("Y", 130)
            }
            ForEach(draft.facilities) { facilityRow($0, count: draft.facilities.count) }
          }.padding(.bottom, 4)
        }
        Button("Add Facility", systemImage: "plus") {
          var id: UUID?
          update("Add Facility") { id = $0.addFacility() }
          focusedFacility = id
        }
        SpreadsheetTransferActions(
          subject: "location facilities", issue: transferIssue,
          paste: { paste(matrix: false) },
          copy: { SpreadsheetClipboard.write(draft.facilitiesTable()) })
      }.padding(8)
    }
  }
  private func facilityRow(_ row: LocationFacilityDraft, count: Int) -> some View {
    HStack(spacing: 8) {
      TextField("ID", text: facilityText(row.id, \.sourceID)).frame(width: 70).accessibilityLabel(
        "ID for \(row.name)")
      TextField("Facility", text: facilityText(row.id, \.name)).frame(width: 200)
        .focused($focusedFacility, equals: row.id).accessibilityLabel(
          "Facility \(row.sourceID) name")
      Toggle("New", isOn: isNew(row.id)).labelsHidden().frame(width: 60).accessibilityLabel(
        "\(row.name) is a new facility")
      TextField("X", text: facilityText(row.id, \.x)).frame(width: 130).accessibilityLabel(
        "X coordinate for \(row.name)")
      TextField("Y", text: facilityText(row.id, \.y)).frame(width: 130).accessibilityLabel(
        "Y coordinate for \(row.name)")
      Button {
        remove(row.id)
      } label: {
        Image(systemName: "minus.circle")
      }
      .buttonStyle(.borderless).disabled(count <= 1).accessibilityLabel(
        "Remove facility \(row.name)")
    }
  }
  private func interactions(_ draft: FacilityLocationDraft) -> some View {
    GroupBox("Directed interaction weights") {
      VStack(alignment: .leading, spacing: 10) {
        Text(
          "Rows are sources and columns are destinations. Blank means no interaction; both directions contribute to the placement cost. Use a consistent coordinate unit."
        )
        .font(.caption).foregroundStyle(.secondary)
        NamedMatrixEditor(rows: draft.facilities.map { MatrixAxisItem(id: $0.id, label: $0.columnLabel) },
          columns: draft.facilities.map { MatrixAxisItem(id: $0.id, label: $0.columnLabel) }, accessibilityPrefix: "Interaction",
          focusRequest: matrixFocusRequest, initialRow: initialMatrixRow, initialColumnGroup: initialMatrixColumnGroup, value: interactionText)
        SpreadsheetTransferActions(
          subject: "location interactions", issue: transferIssue,
          paste: { paste(matrix: true) },
          copy: { SpreadsheetClipboard.write(draft.interactionsTable()) })
      }.padding(8)
    }
  }
  @ViewBuilder private func issues(_ draft: FacilityLocationDraft) -> some View {
    let issues = draft.draftDiagnostics().filter { $0.severity != .info }
    if !issues.isEmpty {
      VStack(alignment: .leading, spacing: 4) {
        ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
          Label(issue.message, systemImage: "exclamationmark.triangle").font(.caption)
            .foregroundStyle(issue.severity == .error ? .red : .orange)
        }
      }.accessibilityElement(children: .contain).accessibilityLabel(
        "Facility location input issues")
    }
  }
  private func heading(_ label: String, _ width: CGFloat) -> some View {
    Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(
      width: width, alignment: .leading)
  }
  private func text(_ key: WritableKeyPath<FacilityLocationDraft, String>) -> Binding<String> {
    Binding(
      get: { draft?[keyPath: key] ?? "" },
      set: { value in update("Edit Location Model") { $0[keyPath: key] = value } })
  }
  private func facilityText(_ id: UUID, _ key: WritableKeyPath<LocationFacilityDraft, String>)
    -> Binding<String>
  {
    Binding(
      get: { draft?.facilities.first { $0.id == id }?[keyPath: key] ?? "" },
      set: { value in
        update("Edit Facility") {
          if let index = $0.facilities.firstIndex(where: { $0.id == id }) {
            $0.facilities[index][keyPath: key] = value
          }
        }
      })
  }
  private func isNew(_ id: UUID) -> Binding<Bool> {
    Binding(
      get: { draft?.facilities.first { $0.id == id }?.isNew ?? false },
      set: { value in
        update("Change Facility Role") {
          if let index = $0.facilities.firstIndex(where: { $0.id == id }) {
            $0.facilities[index].isNew = value
          }
        }
      })
  }
  private func interactionText(_ row: Int, _ column: Int) -> Binding<String> {
    Binding(
      get: { draft?.interactions[safe: row]?[safe: column] ?? "" },
      set: { value in
        update("Edit Interaction") {
          if $0.interactions.indices.contains(row), $0.interactions[row].indices.contains(column) {
            $0.interactions[row][column] = value
          }
        }
      })
  }
  private func remove(_ id: UUID) {
    update("Remove Facility") { draft in
      guard draft.facilities.count > 1,
        let index = draft.facilities.firstIndex(where: { $0.id == id })
      else { return }
      draft.removeFacility(id: id)
      focusedFacility = draft.facilities[min(index, draft.facilities.count - 1)].id
    }
  }
  private func update(_ name: String, _ edit: (inout FacilityLocationDraft) -> Void) {
    guard var draft else { return }
    edit(&draft)
    workspace.replaceFacilityLocationDraft(draft, undoManager: undoManager, actionName: name)
  }
  private func paste(matrix: Bool) {
    do {
      let clipboard = try SpreadsheetClipboard.read()
      guard var draft else { return }
      if matrix {
        try draft.replaceInteractions(with: clipboard)
      } else {
        try draft.replaceFacilities(with: clipboard)
      }
      workspace.replaceFacilityLocationDraft(
        draft, undoManager: undoManager, actionName: "Paste Location Table")
      if !matrix && focusedFacility.map({ id in draft.facilities.contains { $0.id == id } }) != true {
        focusedFacility = draft.facilities.first?.id
      }
      else { matrixFocusRequest += 1 }
      transferIssue = nil
    } catch { transferIssue = String(describing: error) }
  }
}

extension Collection {
  fileprivate subscript(safe index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
