import SwiftUI

struct MatrixAxisItem: Identifiable {
    let id: UUID
    let label: String
}

/// Presentation and navigation only; typed drafts own conversion and validation.
struct NamedMatrixEditor: View {
    let rows: [MatrixAxisItem]
    let columns: [MatrixAxisItem]
    let accessibilityPrefix: String
    let focusRequest: Int
    let value: (Int, Int) -> Binding<String>
    let sourceTitle: String
    let destinationTitle: String
    let selectedRowRequest: UUID?
    let rowDetails: ((Int) -> AnyView)?
    @State private var navigation: MatrixEditorNavigation
    private struct Cell: Hashable {
        let row: UUID
        let column: UUID
    }
    @FocusState private var focusedCell: Cell?

    init(rows: [MatrixAxisItem], columns: [MatrixAxisItem], accessibilityPrefix: String,
         focusRequest: Int = 0, initialRow: UUID? = nil, initialColumnGroup: Int = 0,
         sourceTitle: String = "Source", destinationTitle: String = "Destinations",
         selectedRowRequest: UUID? = nil, rowDetails: ((Int) -> AnyView)? = nil,
         value: @escaping (Int, Int) -> Binding<String>) {
        self.rows = rows
        self.columns = columns
        self.accessibilityPrefix = accessibilityPrefix
        self.focusRequest = focusRequest
        self.value = value
        self.sourceTitle = sourceTitle
        self.destinationTitle = destinationTitle
        self.selectedRowRequest = selectedRowRequest
        self.rowDetails = rowDetails
        _navigation = State(initialValue: MatrixEditorNavigation(rowID: initialRow, columnGroup: initialColumnGroup))
    }

    var body: some View {
        Group {
            if rows.isEmpty || columns.isEmpty {
                Text("No matrix cells. Add a source and destination first.")
                    .foregroundStyle(.secondary)
            } else if rows.count > 12 || columns.count > 12 {
                pagedEditor
            } else {
                completeGrid
            }
        }
        .onChange(of: rows.map(\.id)) { previous, current in
            navigation.reconcile(previousRows: previous, rows: current, columnCount: columns.count)
            repairFocus(previousRows: previous, previousColumns: columns.map(\.id))
        }
        .onChange(of: columns.map(\.id)) { previous, current in
            navigation.reconcile(previousRows: rows.map(\.id), rows: rows.map(\.id), columnCount: current.count)
            repairFocus(previousRows: rows.map(\.id), previousColumns: previous)
        }
        .onChange(of: focusRequest) { _, _ in
            navigation.reconcile(previousRows: rows.map(\.id), rows: rows.map(\.id), columnCount: columns.count)
            if focusedCell != nil { repairFocus(previousRows: rows.map(\.id), previousColumns: columns.map(\.id)) }
            else { focusSelectedRow() }
        }
        .onChange(of: focusedCell) { _, current in
            if let current { navigation.rowID = current.row }
        }
        .onChange(of: selectedRowRequest) { _, current in
            if let current, rows.contains(where: { $0.id == current }) {
                // Parent row actions reveal metadata without stealing name-field focus.
                navigation.rowID = current
            }
        }
    }

    private var completeGrid: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    heading("From / To", width: 180)
                    ForEach(columns) { heading($0.label, width: 130) }
                }
                ForEach(Array(rows.enumerated()), id: \.element.id) { row, source in
                    HStack(spacing: 8) {
                        Text(source.label).frame(width: 180, alignment: .leading)
                        ForEach(columns.indices, id: \.self) { column in field(row: row, column: column) }
                    }
                }
            }.padding(.bottom, 4)
        }
    }
    private var pagedEditor: some View {
        let row = navigation.rowIndex(in: rows.map(\.id)) ?? 0
        let range = navigation.columns(columnCount: columns.count)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Select a \(sourceTitle.lowercased()) and column group. Copy/Paste Table transfers the entire table.")
                .font(.caption).foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack { navigationControls(row: row) }
                VStack(alignment: .leading) { navigationControls(row: row) }
            }
            if let rowDetails { rowDetails(row) }
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(Array(range), id: \.self) { column in
                        VStack(alignment: .leading, spacing: 4) {
                            heading(columns[column].label, width: 130)
                            field(row: row, column: column)
                        }
                    }
                }.padding(.bottom, 4)
            }
            Text("\(sourceTitle) \(row + 1) of \(rows.count) · columns \(range.lowerBound + 1)–\(range.upperBound) of \(columns.count)")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    @ViewBuilder private func navigationControls(row: Int) -> some View {
        Picker(sourceTitle, selection: Binding(
            get: { rows[row].id },
            set: { navigation.rowID = $0; focusSelectedRow() }
        )) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
                Text("\(index + 1). \(item.label)").tag(item.id)
            }
        }.frame(width: 270).accessibilityLabel("\(accessibilityPrefix) \(sourceTitle.lowercased()) row")
        Button("Previous \(sourceTitle)") {
            navigation.rowID = rows[row - 1].id
            focusSelectedRow()
        }.disabled(row == 0)
        Button("Next \(sourceTitle)") {
            navigation.rowID = rows[row + 1].id
            focusSelectedRow()
        }.disabled(row + 1 == rows.count)
        Picker(destinationTitle, selection: Binding(
            get: { navigation.columns(columnCount: columns.count).lowerBound / MatrixEditorNavigation.columnsPerGroup },
            set: { navigation.columnGroup = $0; focusSelectedRow() }
        )) {
            ForEach(0..<navigation.groupCount(columnCount: columns.count), id: \.self) { group in
                let selection = MatrixEditorNavigation(columnGroup: group).columns(columnCount: columns.count)
                Text("\(selection.lowerBound + 1)–\(selection.upperBound)").tag(group)
            }
        }.frame(width: 220).accessibilityLabel("\(accessibilityPrefix) \(destinationTitle.lowercased()) column group")
    }
    private func heading(_ label: String, width: CGFloat) -> some View {
        Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            .frame(width: width, alignment: .leading)
    }
    private func field(row: Int, column: Int) -> some View {
        TextField("", text: value(row, column)).textFieldStyle(.roundedBorder).frame(width: 130)
            .focused($focusedCell, equals: Cell(row: rows[row].id, column: columns[column].id))
            .accessibilityLabel("\(accessibilityPrefix), \(sourceTitle.lowercased()) row \(row + 1) \(rows[row].label), column \(column + 1) \(columns[column].label)")
    }
    private func repairFocus(previousRows: [UUID], previousColumns: [UUID]) {
        guard let cell = focusedCell else { return }
        guard let row = repairedEditorRowSelection(cell.row, previous: previousRows, current: rows.map(\.id)),
              let column = repairedEditorRowSelection(cell.column, previous: previousColumns, current: columns.map(\.id)),
              let columnIndex = columns.firstIndex(where: { $0.id == column }) else {
            focusedCell = nil
            return
        }
        navigation.rowID = row
        navigation.columnGroup = columnIndex / MatrixEditorNavigation.columnsPerGroup
        focusedCell = Cell(row: row, column: column)
    }
    private func focusSelectedRow() {
        guard let row = navigation.rowIndex(in: rows.map(\.id)),
              let column = navigation.columns(columnCount: columns.count).first else {
            focusedCell = nil
            return
        }
        focusedCell = Cell(row: rows[row].id, column: columns[column].id)
    }
}
