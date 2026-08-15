import SwiftUI
import QSBCore

struct LinearProgrammingEditorView: View {
    @Bindable var workspace: QSBWorkspace

    private var draft: LinearProgrammingDraft? { workspace.lpDraft }

    var body: some View {
        Group {
            if draft == nil {
                ContentUnavailableView("No LP draft", systemImage: "doc.badge.plus", description: Text("Choose New or open a Linear / Integer Programming model."))
            } else {
                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 20) {
                        editorHeader
                        modelSection
                        variablesSection
                        constraintsSection
                    }
                    .padding(24)
                    .frame(minWidth: 900, alignment: .leading)
                }
            }
        }
        .navigationTitle("LP Editor")
    }

    private var editorHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Linear / Integer Programming")
                        .font(.title2.weight(.semibold))
                    Text("Native editor · \(workspace.modelState.rawValue)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack {
                Button("Validate") { workspace.validateCurrentModel() }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                    .help("Validate model (⌘⇧V)")
                Button(workspace.lpDraft?.variables.contains(where: { $0.type != .continuous }) == true ? "Run ILP" : "Run LP") {
                    workspace.runCurrentModel()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .buttonStyle(.borderedProminent)
                .disabled(workspace.modelState == .invalid || workspace.runState == .solving)
                Spacer()
            }
        }
    }

    private var modelSection: some View {
        GroupBox("Model") {
            HStack(spacing: 18) {
                LabeledContent("Name") {
                    TextField("Model name", text: titleBinding)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280)
                }
                Picker("Objective", selection: senseBinding) {
                    Text("Maximize").tag(ObjectiveSense.maximize)
                    Text("Minimize").tag(ObjectiveSense.minimize)
                }
                .pickerStyle(.segmented)
                .frame(width: 190)
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    private var variablesSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Variables and objective")
                        .font(.headline)
                    Button { workspace.updateLPDraft { $0.addVariable() } } label: {
                        Label("Add Variable", systemImage: "plus")
                    }
                    .accessibilityLabel("Add variable")
                    Spacer()
                }
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 7) {
                    GridRow {
                        Text("Name"); Text("Objective"); Text("Type"); Text("Lower"); Text("Upper"); Text("Unrestricted"); Text("")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    ForEach(Array(workspace.lpDraft?.variables.indices ?? (0..<0)), id: \.self) { index in
                        variableRow(index: index)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func variableRow(index: Int) -> some View {
        let variable = workspace.lpDraft?.variables[index]
        return GridRow {
            TextField("x", text: variableBinding(index, keyPath: \.name))
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
                .accessibilityLabel("Variable \(index + 1) name")
            TextField("0", text: objectiveBinding(index))
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
                .accessibilityLabel("Objective coefficient for variable \(index + 1)")
            Picker("Type", selection: variableTypeBinding(index)) {
                Text("Continuous").tag(VariableType.continuous)
                Text("Integer").tag(VariableType.integer)
                Text("Binary").tag(VariableType.binary)
            }
            .labelsHidden()
            .frame(width: 120)
            TextField("0", text: variableBinding(index, keyPath: \.lowerBound))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .disabled(variable?.unrestricted == true)
                .accessibilityLabel("Lower bound for variable \(index + 1)")
            upperBoundEditor(index: index, variable: variable)
            Toggle("Unrestricted", isOn: unrestrictedBinding(index))
                .labelsHidden()
                .accessibilityLabel("Unrestricted variable \(index + 1)")
            Button(role: .destructive) { workspace.updateLPDraft { $0.removeVariable(at: index) } } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .disabled((workspace.lpDraft?.variables.count ?? 0) <= 1)
            .accessibilityLabel("Remove variable \(index + 1)")
        }
        .overlay(alignment: .bottomLeading) {
            if let diagnostic = inlineDiagnostic(for: variable?.name, index: index, prefix: "variables") {
                Text(diagnostic.message).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private func upperBoundEditor(index: Int, variable: LPDraftVariable?) -> some View {
        HStack(spacing: 4) {
            Toggle("Unbounded", isOn: Binding(
                get: { if case .unbounded = variable?.upperBound { return true }; return false },
                set: { value in
                    workspace.updateLPDraft { draft in
                        draft.variables[index].upperBound = value ? .unbounded : .value("0")
                    }
                }
            ))
            .labelsHidden()
            .accessibilityLabel("Unbounded upper bound for variable \(index + 1)")
            if case .value = variable?.upperBound {
                TextField("∞", text: upperBoundBinding(index))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
            } else {
                Text("∞").foregroundStyle(.secondary).frame(width: 70)
            }
        }
    }

    private var constraintsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Constraints").font(.headline)
                    Button { workspace.updateLPDraft { $0.addConstraint() } } label: {
                        Label("Add Constraint", systemImage: "plus")
                    }
                    .accessibilityLabel("Add constraint")
                    Spacer()
                }
                if let draft {
                    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 7) {
                        GridRow {
                            Text("Name")
                            ForEach(draft.variables, id: \.name) { variable in Text(variable.name) }
                            Text("Relation"); Text("RHS"); Text("")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        ForEach(draft.constraints.indices, id: \.self) { index in
                            constraintRow(index: index, variableCount: draft.variables.count)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func constraintRow(index: Int, variableCount: Int) -> some View {
        GridRow {
            TextField("C\(index + 1)", text: constraintNameBinding(index))
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
                .accessibilityLabel("Constraint \(index + 1) name")
            ForEach(0..<variableCount, id: \.self) { column in
                TextField("0", text: coefficientBinding(row: index, column: column))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .accessibilityLabel("Coefficient \(column + 1) for constraint \(index + 1)")
            }
            Picker("Relation", selection: constraintRelationBinding(index)) {
                Text("≤").tag(ConstraintRelation.lessThanOrEqual)
                Text("=").tag(ConstraintRelation.equal)
                Text("≥").tag(ConstraintRelation.greaterThanOrEqual)
            }
            .labelsHidden()
            .frame(width: 72)
            TextField("0", text: constraintRHSBinding(index))
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
                .accessibilityLabel("Right hand side for constraint \(index + 1)")
            Button(role: .destructive) { workspace.updateLPDraft { $0.removeConstraint(at: index) } } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove constraint \(index + 1)")
        }
    }

    private var titleBinding: Binding<String> {
        Binding(get: { workspace.lpDraft?.title ?? "" }, set: { value in workspace.updateLPDraft { $0.title = value } })
    }

    private var senseBinding: Binding<ObjectiveSense> {
        Binding(get: { workspace.lpDraft?.sense ?? .maximize }, set: { value in workspace.updateLPDraft { $0.sense = value } })
    }

    private func variableBinding(_ index: Int, keyPath: WritableKeyPath<LPDraftVariable, String>) -> Binding<String> {
        Binding(get: { workspace.lpDraft?.variables[index][keyPath: keyPath] ?? "" }, set: { value in workspace.updateLPDraft { $0.variables[index][keyPath: keyPath] = value } })
    }

    private func objectiveBinding(_ index: Int) -> Binding<String> {
        Binding(get: { workspace.lpDraft?.objectiveCoefficients[index] ?? "" }, set: { value in workspace.updateLPDraft { $0.objectiveCoefficients[index] = value } })
    }

    private func upperBoundBinding(_ index: Int) -> Binding<String> {
        Binding(get: { if case .value(let value) = workspace.lpDraft?.variables[index].upperBound { return value }; return "" }, set: { value in workspace.updateLPDraft { $0.variables[index].upperBound = .value(value) } })
    }

    private func variableTypeBinding(_ index: Int) -> Binding<VariableType> {
        Binding(get: { workspace.lpDraft?.variables[index].type ?? .continuous }, set: { value in workspace.updateLPDraft { $0.variables[index].type = value; if value == .binary { $0.variables[index].lowerBound = "0"; $0.variables[index].upperBound = .value("1") } } })
    }

    private func unrestrictedBinding(_ index: Int) -> Binding<Bool> {
        Binding(get: { workspace.lpDraft?.variables[index].unrestricted ?? false }, set: { value in workspace.updateLPDraft { $0.variables[index].unrestricted = value; if value { $0.variables[index].type = .continuous } } })
    }

    private func constraintNameBinding(_ index: Int) -> Binding<String> {
        Binding(get: { workspace.lpDraft?.constraints[index].name ?? "" }, set: { value in workspace.updateLPDraft { $0.constraints[index].name = value } })
    }

    private func coefficientBinding(row: Int, column: Int) -> Binding<String> {
        Binding(get: { workspace.lpDraft?.constraints[row].coefficients[column] ?? "" }, set: { value in workspace.updateLPDraft { $0.constraints[row].coefficients[column] = value } })
    }

    private func constraintRelationBinding(_ index: Int) -> Binding<ConstraintRelation> {
        Binding(get: { workspace.lpDraft?.constraints[index].relation ?? .lessThanOrEqual }, set: { value in workspace.updateLPDraft { $0.constraints[index].relation = value } })
    }

    private func constraintRHSBinding(_ index: Int) -> Binding<String> {
        Binding(get: { workspace.lpDraft?.constraints[index].rhs ?? "" }, set: { value in workspace.updateLPDraft { $0.constraints[index].rhs = value } })
    }

    private func inlineDiagnostic(for name: String?, index: Int, prefix: String) -> ValidationDiagnostic? {
        workspace.validationDiagnostics.first { diagnostic in
            diagnostic.path?.contains("\(prefix).\(index)") == true || (name != nil && diagnostic.path?.contains(name!) == true)
        }
    }
}
