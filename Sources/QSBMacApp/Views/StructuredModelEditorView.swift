import AppKit
import SwiftUI

private struct StructuredModelFamilyNameKey: EnvironmentKey {
    static let defaultValue = ""
}

private extension EnvironmentValues {
    var structuredModelFamilyName: String {
        get { self[StructuredModelFamilyNameKey.self] }
        set { self[StructuredModelFamilyNameKey.self] = newValue }
    }
}

struct StructuredModelEditorView: View {
    @Bindable var workspace: QSBWorkspace
    @State private var root: StructuredModelNode?
    @State private var lastAppliedJSON: String
    @State private var pendingIssue: String?
    @State private var hasPendingEdit = false

    init(workspace: QSBWorkspace) {
        self.workspace = workspace
        _root = State(initialValue: try? StructuredModelNode.parse(workspace.modelJSON))
        _lastAppliedJSON = State(initialValue: workspace.modelJSON)
        _pendingIssue = State(initialValue: nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeaderView(
                    title: workspace.modelTitle,
                    subtitle: "Guided definition · \(workspace.currentModelFamily.displayName)"
                )

                editorNotice

                if let root {
                    if root.kind == .object {
                        StructuredObjectFieldsView(node: root, path: "Model", onChange: modelChanged)
                    } else {
                        StructuredNodeFieldView(
                            label: "Model",
                            contextKey: "model",
                            node: root,
                            path: "Model",
                            onChange: modelChanged
                        )
                    }
                } else {
                    ContentUnavailableView(
                        "Model cannot be shown as a form",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Open Advanced JSON to repair the model representation.")
                    )
                }
            }
            .padding(20)
            .frame(maxWidth: 1180, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .environment(\.structuredModelFamilyName, workspace.currentModelFamily.displayName)
        .navigationTitle("Definition")
    }

    private var editorNotice: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: pendingIssue == nil ? "slider.horizontal.3" : "exclamationmark.triangle.fill")
                    .foregroundStyle(pendingIssue == nil ? Color.accentColor : Color.orange)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(pendingIssue == nil ? "Edit the model with fields, lists, and tables" : "Finish the current edit")
                        .font(.headline)
                    Text(pendingIssue ?? "Valid field changes are saved automatically. Model rules remain owned by QSBCore and are checked when you validate or solve.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Advanced JSON remains available from the sidebar for interchange and troubleshooting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                if hasPendingEdit {
                    Button("Revert Edit") { revertPendingEdit() }
                        .accessibilityHint("Restores the last valid model value")
                }

                Button("Validate") {
                    workspace.validateCurrentModel()
                }
                .buttonStyle(.borderedProminent)
                .disabled(hasPendingEdit)
                .help(hasPendingEdit ? "Finish or revert the invalid edit before validating" : "Validate the current model")
            }
            .padding(4)
        }
    }

    private func modelChanged() {
        guard let root else { return }
        if let issue = root.firstIssue() {
            pendingIssue = issue
            hasPendingEdit = true
            return
        }

        do {
            let json = try root.encodedJSON()
            workspace.updateStructuredModelJSON(json)
            lastAppliedJSON = json
            pendingIssue = nil
            hasPendingEdit = false
        } catch {
            pendingIssue = error.localizedDescription
            hasPendingEdit = true
        }
    }

    private func revertPendingEdit() {
        root = try? StructuredModelNode.parse(lastAppliedJSON)
        pendingIssue = nil
        hasPendingEdit = false
    }
}

private struct StructuredObjectFieldsView: View {
    @Bindable var node: StructuredModelNode
    let path: String
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(node.fields) { field in
                StructuredNodeFieldView(
                    label: StructuredModelNode.displayName(for: field.key),
                    contextKey: field.key,
                    node: field.value,
                    path: "\(path) › \(StructuredModelNode.displayName(for: field.key))",
                    onChange: onChange
                )
            }
        }
    }
}

private struct StructuredNodeFieldView: View {
    let label: String
    let contextKey: String
    @Bindable var node: StructuredModelNode
    let path: String
    let onChange: () -> Void

    var body: some View {
        switch node.kind {
        case .object:
            GroupBox(label) {
                StructuredObjectFieldsView(node: node, path: path, onChange: onChange)
                    .padding(4)
            }
        case .array:
            StructuredArrayFieldView(
                label: label,
                contextKey: contextKey,
                node: node,
                path: path,
                onChange: onChange
            )
        case .string, .number, .boolean, .null:
            GroupBox {
                StructuredScalarFieldView(
                    label: label,
                    contextKey: contextKey,
                    node: node,
                    path: path,
                    showsLabel: true,
                    onChange: onChange
                )
                .padding(4)
            }
        }
    }
}

private struct StructuredArrayFieldView: View {
    let label: String
    let contextKey: String
    @Bindable var node: StructuredModelNode
    let path: String
    let onChange: () -> Void
    @Environment(\.structuredModelFamilyName) private var familyName
    @State private var tabularIssue: String?

    private var scalarElements: Bool {
        node.elements.allSatisfy(\.isScalar)
    }

    private var supportsTabularPaste: Bool {
        node.supportsTabularTransfer || (
            node.elements.isEmpty && StructuredElementFactory.hasTemplate(for: contextKey, familyName: familyName)
        )
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                if node.elements.isEmpty {
                    Text("No entries")
                        .foregroundStyle(.secondary)
                } else if node.isScalarMatrix {
                    StructuredMatrixEditor(node: node, path: path, onChange: onChange)
                } else if scalarElements {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 190), spacing: 10, alignment: .leading)],
                        alignment: .leading,
                        spacing: 10
                    ) {
                        ForEach(Array(node.elements.enumerated()), id: \.element.id) { index, element in
                            HStack(spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24, alignment: .trailing)
                                StructuredScalarFieldView(
                                    label: "\(label) \(index + 1)",
                                    contextKey: contextKey,
                                    node: element,
                                    path: "\(path) › \(index + 1)",
                                    showsLabel: false,
                                    onChange: onChange
                                )
                                Button {
                                    node.elements.removeAll { $0.id == element.id }
                                    onChange()
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Remove \(label) \(index + 1)")
                            }
                        }
                    }
                } else {
                    ForEach(Array(node.elements.enumerated()), id: \.element.id) { index, element in
                        StructuredCollectionItemView(
                            label: itemLabel(index: index, element: element),
                            contextKey: contextKey,
                            node: element,
                            path: "\(path) › \(index + 1)",
                            duplicate: {
                                guard let position = node.elements.firstIndex(where: { $0.id == element.id }) else { return }
                                node.elements.insert(element.clone(), at: position + 1)
                                onChange()
                            },
                            remove: {
                                node.elements.removeAll { $0.id == element.id }
                                onChange()
                            },
                            onChange: onChange
                        )
                    }
                }

                HStack {
                    if node.elements.isEmpty {
                        if StructuredElementFactory.hasTemplate(for: contextKey, familyName: familyName) {
                            Button {
                                appendSuggestedElement()
                            } label: {
                                Label(addLabel, systemImage: "plus")
                            }
                        } else {
                            Menu("Add Entry") {
                                Button("Text") { append(.string) }
                                Button("Number") { append(.number) }
                                Button("True / False") { append(.boolean) }
                                Button("Group") { append(.object) }
                                Button("List") { append(.array) }
                            }
                        }
                    } else {
                        Button {
                            node.appendArrayElement()
                            onChange()
                        } label: {
                            Label(addLabel, systemImage: "plus")
                        }
                        .help("Adds a new entry using the last entry as a starting point")
                    }
                    Spacer()
                    Text("\(node.elements.count) \(node.elements.count == 1 ? "entry" : "entries")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if supportsTabularPaste {
                    Divider()
                    HStack(spacing: 10) {
                        Button {
                            pasteTable()
                        } label: {
                            Label("Paste Table", systemImage: "doc.on.clipboard")
                        }
                        .help("Paste a rectangular range copied from Excel, Numbers, LibreOffice, TSV, or CSV. A header row is optional.")
                        .accessibilityHint("Imports rows and columns from the clipboard after checking their types")

                        Button {
                            copyTable()
                        } label: {
                            Label("Copy Table", systemImage: "doc.on.doc")
                        }
                        .disabled(node.elements.isEmpty || !node.supportsTabularTransfer)
                        .help("Copy this section as tab-separated text for a spreadsheet")

                        Text("Excel, Numbers, LibreOffice, TSV, or CSV · headers optional")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let tabularIssue {
                        Label(tabularIssue, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel("Table import error: \(tabularIssue)")
                    }
                }
            }
            .padding(4)
        } label: {
            HStack {
                Text(label)
                Text("\(node.elements.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func itemLabel(index: Int, element: StructuredModelNode) -> String {
        if let summary = element.itemSummary {
            return "\(index + 1). \(summary)"
        }
        return "\(label) \(index + 1)"
    }

    private var addLabel: String {
        let singular = label.hasSuffix("s") ? String(label.dropLast()) : "Entry"
        return "Add \(singular)"
    }

    private func append(_ kind: StructuredModelNode.ValueKind) {
        node.appendArrayElement(kind: kind)
        onChange()
    }

    private func appendSuggestedElement() {
        guard let element = StructuredElementFactory.make(for: contextKey, familyName: familyName) else { return }
        node.elements.append(element)
        onChange()
    }

    private func pasteTable() {
        guard let clipboardText = NSPasteboard.general.string(forType: .string) else {
            tabularIssue = StructuredModelTabularError.emptyClipboard.description
            return
        }

        let previousElements = node.elements.map { $0.clone() }
        if node.elements.isEmpty,
           let template = StructuredElementFactory.make(for: contextKey, familyName: familyName) {
            node.elements.append(template)
        }

        do {
            try node.replaceArrayContents(withTabularText: clipboardText)
            tabularIssue = nil
            onChange()
        } catch {
            node.elements = previousElements
            tabularIssue = String(describing: error)
        }
    }

    private func copyTable() {
        do {
            let text = try node.tabularText()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            tabularIssue = nil
        } catch {
            tabularIssue = String(describing: error)
        }
    }
}

private struct StructuredCollectionItemView: View {
    let label: String
    let contextKey: String
    @Bindable var node: StructuredModelNode
    let path: String
    let duplicate: () -> Void
    let remove: () -> Void
    let onChange: () -> Void
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                switch node.kind {
                case .object:
                    StructuredObjectFieldsView(node: node, path: path, onChange: onChange)
                case .array:
                    StructuredArrayFieldView(
                        label: label,
                        contextKey: contextKey,
                        node: node,
                        path: path,
                        onChange: onChange
                    )
                case .string, .number, .boolean, .null:
                    StructuredScalarFieldView(
                        label: label,
                        contextKey: contextKey,
                        node: node,
                        path: path,
                        showsLabel: false,
                        onChange: onChange
                    )
                }

                HStack {
                    Button("Duplicate", action: duplicate)
                    Button("Remove", role: .destructive, action: remove)
                    Spacer()
                }
            }
            .padding(.top, 8)
        } label: {
            Text(label).fontWeight(.semibold)
        }
        .padding(10)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct StructuredMatrixEditor: View {
    @Bindable var node: StructuredModelNode
    let path: String
    let onChange: () -> Void

    private var columnCount: Int {
        node.elements.map(\.elements.count).max() ?? 0
    }

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    Text("Row").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(0..<columnCount, id: \.self) { column in
                        Text("\(column + 1)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 92)
                    }
                    Text("").frame(width: 28)
                }

                ForEach(Array(node.elements.enumerated()), id: \.element.id) { rowIndex, row in
                    GridRow {
                        Text("\(rowIndex + 1)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 32, alignment: .trailing)

                        ForEach(Array(row.elements.enumerated()), id: \.element.id) { columnIndex, cell in
                            StructuredScalarFieldView(
                                label: "Row \(rowIndex + 1), column \(columnIndex + 1)",
                                contextKey: "matrixValue",
                                node: cell,
                                path: "\(path) › Row \(rowIndex + 1) › Column \(columnIndex + 1)",
                                showsLabel: false,
                                fixedWidth: 92,
                                onChange: onChange
                            )
                        }

                        if row.elements.count < columnCount {
                            ForEach(row.elements.count..<columnCount, id: \.self) { _ in
                                Text("—").foregroundStyle(.tertiary).frame(width: 92)
                            }
                        }

                        Button {
                            node.elements.removeAll { $0.id == row.id }
                            onChange()
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove matrix row \(rowIndex + 1)")
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct StructuredScalarFieldView: View {
    let label: String
    let contextKey: String
    @Bindable var node: StructuredModelNode
    let path: String
    var showsLabel: Bool
    var fixedWidth: CGFloat?
    let onChange: () -> Void

    init(
        label: String,
        contextKey: String,
        node: StructuredModelNode,
        path: String,
        showsLabel: Bool,
        fixedWidth: CGFloat? = nil,
        onChange: @escaping () -> Void
    ) {
        self.label = label
        self.contextKey = contextKey
        self.node = node
        self.path = path
        self.showsLabel = showsLabel
        self.fixedWidth = fixedWidth
        self.onChange = onChange
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if showsLabel {
                Text(label)
                    .frame(minWidth: 150, idealWidth: 190, alignment: .leading)
            }

            if isSchemaIdentifier {
                Text(node.text)
                    .font(.body.monospaced())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
                    .accessibilityLabel(label)
                    .accessibilityValue(node.text)
            } else {
                scalarControl
            }
        }
    }

    @ViewBuilder
    private var scalarControl: some View {
        switch node.kind {
        case .string:
            if let options = enumOptions {
                Picker(label, selection: $node.text) {
                    ForEach(options, id: \.self) { option in
                        Text(option.capitalized).tag(option)
                    }
                }
                .labelsHidden()
                .onChange(of: node.text) { _, _ in onChange() }
                .accessibilityLabel(path)
                .frame(width: fixedWidth ?? 180)
            } else {
                TextField(label, text: $node.text)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: node.text) { _, _ in onChange() }
                    .accessibilityLabel(path)
                    .frame(width: fixedWidth)
            }
        case .number:
            TextField(label, text: $node.text)
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .font(.body.monospacedDigit())
                .onChange(of: node.text) { _, _ in onChange() }
                .accessibilityLabel(path)
                .frame(width: fixedWidth ?? 150)
        case .boolean:
            Toggle(label, isOn: $node.booleanValue)
                .labelsHidden()
                .onChange(of: node.booleanValue) { _, _ in onChange() }
                .accessibilityLabel(path)
        case .null:
            HStack {
                Text("Not set").foregroundStyle(.secondary)
                Menu("Set Value") {
                    Button("Number") { replaceNull(with: .number) }
                    Button("Text") { replaceNull(with: .string) }
                    Button("True / False") { replaceNull(with: .boolean) }
                }
                .accessibilityLabel("Set \(path)")
            }
        case .object, .array:
            EmptyView()
        }
    }

    private var isSchemaIdentifier: Bool {
        node.kind == .string && ["kind", "representation"].contains(contextKey)
    }

    private var enumOptions: [String]? {
        switch contextKey {
        case "relation": ["<=", "=", ">="]
        case "sense", "objectiveSense": ["minimize", "maximize"]
        case "variableType", "variableTypes": ["continuous", "integer", "binary"]
        default: nil
        }
    }

    private func replaceNull(with kind: StructuredModelNode.ValueKind) {
        node.replaceNull(with: kind)
        onChange()
    }
}

private enum StructuredElementFactory {
    static func hasTemplate(for key: String, familyName: String) -> Bool {
        make(for: key, familyName: familyName) != nil
    }

    static func make(for key: String, familyName: String) -> StructuredModelNode? {
        switch key {
        case "constraints":
            if familyName == "Nonlinear Programming" {
                return object([
                    ("name", string("Constraint")),
                    ("expression", string("x")),
                    ("relation", string("<=")),
                    ("rhs", number("0"))
                ])
            }
            return object([
                ("name", string("Constraint")),
                ("coefficients", array([number("0")])),
                ("relation", string("<=")),
                ("rhs", number("0"))
            ])
        case "goals":
            return object([
                ("name", string("Goal")),
                ("sense", string("maximize")),
                ("coefficients", array([number("0")]))
            ])
        case "routes":
            return object([
                ("probability", number("1")),
                ("target", string("")),
                ("transferTime", number("0"))
            ])
        case "serviceRules":
            return object([
                ("distribution", object([
                    ("kind", string("constant")),
                    ("parameters", array([number("1")]))
                ])),
                ("entityType", string(""))
            ])
        case "predecessors", "variableNames", "states", "periodNames":
            return string("")
        case "variableTypes":
            return string("continuous")
        case "lowerBounds", "linearCoefficients", "objectiveCoefficients", "coefficients", "demand":
            return number("0")
        case "upperBounds", "maximumBackorder", "maximumInventory", "maximumSubcontracting", "maximumWorkforce":
            return StructuredModelNode(kind: .null)
        default:
            return nil
        }
    }

    private static func object(_ fields: [(String, StructuredModelNode)]) -> StructuredModelNode {
        StructuredModelNode(
            kind: .object,
            fields: fields.map { StructuredModelNode.Field(key: $0.0, value: $0.1) }
        )
    }

    private static func array(_ elements: [StructuredModelNode]) -> StructuredModelNode {
        StructuredModelNode(kind: .array, elements: elements)
    }

    private static func string(_ value: String) -> StructuredModelNode {
        StructuredModelNode(kind: .string, text: value)
    }

    private static func number(_ value: String) -> StructuredModelNode {
        StructuredModelNode(kind: .number, text: value)
    }
}
