import SwiftUI
import QSBCore

struct ProjectSchedulingEditorView: View {
    @Bindable var workspace: QSBWorkspace
    @Environment(\.undoManager) private var undoManager
    @FocusState private var focusedActivityID: UUID?
    @State private var transferIssue: String?

    private var draft: ProjectSchedulingDraft? { workspace.projectSchedulingDraft }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(
                title: workspace.modelTitle,
                subtitle: "Native PERT / CPM editor · \(workspace.modelState.rawValue)"
            )
            if let draft {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 16) {
                        actionBar
                        issues(draft)
                        modelSection(draft)
                        activitiesSection(draft)
                    }
                    .padding(20)
                    .frame(maxWidth: 1_260, alignment: .topLeading)
                }
            }
        }
        .navigationTitle("Project Scheduling Definition")
        .onChange(of: draft?.activities.map(\.id) ?? []) { previous, current in
            guard let focusedActivityID, !current.contains(focusedActivityID) else { return }
            let index = previous.firstIndex(of: focusedActivityID) ?? 0
            self.focusedActivityID = current.isEmpty ? nil : current[min(index, current.count - 1)]
        }
        .onChange(of: draft?.kind) { _, _ in transferIssue = nil }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button("Validate", systemImage: "checkmark.seal") { workspace.validateCurrentModel() }
                .keyboardShortcut("v", modifiers: [.command, .shift])
                .accessibilityHint("Checks activity values and the precedence graph")
            Button("Run", systemImage: "play.circle") { workspace.startCurrentModelRun() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(workspace.modelState == .invalid || workspace.runState == .solving)
                .accessibilityHint("Calculates the critical path using the selected backend")
            Spacer()
            Text(workspace.currentModelFamily.displayName)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func modelSection(_ draft: ProjectSchedulingDraft) -> some View {
        GroupBox("Project") {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { projectFields(draft) }
                VStack(alignment: .leading, spacing: 10) { projectFields(draft) }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private func projectFields(_ draft: ProjectSchedulingDraft) -> some View {
        labeledField("Title", text: binding(
            get: { $0.title }, set: { $0.title = $1 }, action: "Edit Project Title"
        ), width: 300, id: "project-title")
        labeledField("Time unit", text: binding(
            get: { $0.timeUnit }, set: { $0.timeUnit = $1 }, action: "Edit Time Unit"
        ), width: 130, id: "project-time-unit")
        Picker("Method", selection: Binding(
            get: { draft.kind.rawValue },
            set: { rawValue in
                guard let kind = ProjectSchedulingProblemKind(rawValue: rawValue) else { return }
                update("Change Scheduling Method") { $0.changeKind(to: kind) }
            }
        )) {
            Text("CPM").tag(ProjectSchedulingProblemKind.deterministicCPM.rawValue)
            Text("PERT").tag(ProjectSchedulingProblemKind.probabilisticPERT.rawValue)
        }
        .pickerStyle(.segmented)
        .frame(width: 190)
        .accessibilityLabel("Scheduling method")
        .accessibilityValue(draft.kind == .deterministicCPM ? "CPM" : "PERT")
    }

    private func activitiesSection(_ draft: ProjectSchedulingDraft) -> some View {
        GroupBox(draft.kind == .deterministicCPM ? "CPM activities" : "PERT activities") {
            VStack(alignment: .leading, spacing: 10) {
                Text("List predecessor activity names separated by commas. Names must be unique and the precedence graph must not contain cycles.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Switching methods keeps each method’s times and costs. Copy Table exports the currently selected method.")
                    .font(.caption).foregroundStyle(.secondary)
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 8) {
                        activityHeader(draft.kind)
                        ForEach(draft.activities) { activity in
                            activityRow(activity, kind: draft.kind)
                        }
                    }
                    .padding(.bottom, 4)
                }
                HStack(spacing: 10) {
                    Button("Add Activity", systemImage: "plus") {
                        var newID: UUID?
                        update("Add Activity") { newID = $0.addActivity() }
                        focusedActivityID = newID
                    }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .accessibilityHint("Adds an activity and moves keyboard focus to its name")
                    SpreadsheetTransferActions(
                        subject: draft.kind == .deterministicCPM ? "CPM activities" : "PERT activities",
                        issue: transferIssue,
                        paste: pasteActivities,
                        copy: copyActivities
                    )
                }
            }
            .padding(8)
        }
    }

    private func activityHeader(_ kind: ProjectSchedulingProblemKind) -> some View {
        HStack(spacing: 8) {
            header("Activity", width: 150)
            header("Predecessors", width: 180)
            if kind == .deterministicCPM {
                header("Normal time", width: 105)
                header("Crash time", width: 105)
                header("Normal cost", width: 105)
                header("Crash cost", width: 105)
            } else {
                header("Optimistic", width: 105)
                header("Most likely", width: 105)
                header("Pessimistic", width: 105)
            }
            Color.clear.frame(width: 28, height: 1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    private func activityRow(_ activity: ProjectActivityDraft, kind: ProjectSchedulingProblemKind) -> some View {
        HStack(spacing: 8) {
            rowField("Activity name", activityID: activity.id, keyPath: \.name, width: 150, focusID: activity.id)
            rowField("Predecessors for \(activity.name)", activityID: activity.id, keyPath: \.predecessors, width: 180)
            if kind == .deterministicCPM {
                rowField("Normal time for \(activity.name)", activityID: activity.id, keyPath: \.normalTime, width: 105)
                rowField("Crash time for \(activity.name)", activityID: activity.id, keyPath: \.crashTime, width: 105)
                rowField("Normal cost for \(activity.name)", activityID: activity.id, keyPath: \.normalCost, width: 105)
                rowField("Crash cost for \(activity.name)", activityID: activity.id, keyPath: \.crashCost, width: 105)
            } else {
                rowField("Optimistic time for \(activity.name)", activityID: activity.id, keyPath: \.optimisticTime, width: 105)
                rowField("Most likely time for \(activity.name)", activityID: activity.id, keyPath: \.mostLikelyTime, width: 105)
                rowField("Pessimistic time for \(activity.name)", activityID: activity.id, keyPath: \.pessimisticTime, width: 105)
            }
            Button {
                guard let activities = draft?.activities,
                      let index = activities.firstIndex(where: { $0.id == activity.id }), activities.count > 1 else { return }
                let nextID = activities[index == activities.count - 1 ? index - 1 : index + 1].id
                update("Remove Activity") { $0.removeActivity(id: activity.id) }
                focusedActivityID = nextID
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .disabled((draft?.activities.count ?? 0) <= 1)
            .accessibilityLabel("Remove activity \(activity.name)")
        }
    }

    @ViewBuilder
    private func rowField(
        _ label: String,
        activityID: UUID,
        keyPath: WritableKeyPath<ProjectActivityDraft, String>,
        width: CGFloat,
        focusID: UUID? = nil
    ) -> some View {
        let field = TextField(label, text: Binding(
            get: {
                workspace.projectSchedulingDraft?.activities.first(where: { $0.id == activityID })?[keyPath: keyPath] ?? ""
            },
            set: { value in
                update("Edit Activity") { draft in
                    guard let index = draft.activities.firstIndex(where: { $0.id == activityID }) else { return }
                    draft.activities[index][keyPath: keyPath] = value
                }
            }
        ))
        .textFieldStyle(.roundedBorder)
        .frame(width: width)
        .accessibilityLabel(label)
        .accessibilityIdentifier("project-activity-\(activityID.uuidString)-\(String(describing: keyPath))")
        if let focusID {
            field.focused($focusedActivityID, equals: focusID)
        } else {
            field
        }
    }

    @ViewBuilder
    private func issues(_ draft: ProjectSchedulingDraft) -> some View {
        let diagnostics = draft.draftDiagnostics().filter { $0.severity != .info }
        if !diagnostics.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                    Label(diagnostic.message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(diagnostic.severity == .error ? .red : .orange)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Project input issues")
        }
    }

    private func labeledField(_ label: String, text: Binding<String>, width: CGFloat, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
                .frame(width: width)
                .accessibilityLabel(label)
                .accessibilityIdentifier(id)
        }
    }

    private func header(_ text: String, width: CGFloat) -> some View {
        Text(text).frame(width: width, alignment: .leading)
    }

    private func binding(
        get: @escaping (ProjectSchedulingDraft) -> String,
        set: @escaping (inout ProjectSchedulingDraft, String) -> Void,
        action: String
    ) -> Binding<String> {
        Binding(
            get: { workspace.projectSchedulingDraft.map(get) ?? "" },
            set: { value in update(action) { set(&$0, value) } }
        )
    }

    private func update(_ actionName: String, _ mutation: (inout ProjectSchedulingDraft) -> Void) {
        guard var next = workspace.projectSchedulingDraft else { return }
        mutation(&next)
        workspace.replaceProjectSchedulingDraft(next, undoManager: undoManager, actionName: actionName)
    }

    private func pasteActivities() {
        do {
            var next = try requireDraft()
            try next.replaceActivities(withTabularText: SpreadsheetClipboard.read())
            workspace.replaceProjectSchedulingDraft(next, undoManager: undoManager, actionName: "Paste Activities")
            if !next.activities.contains(where: { $0.id == focusedActivityID }) {
                focusedActivityID = next.activities.first?.id
            }
            transferIssue = nil
        } catch {
            transferIssue = String(describing: error)
        }
    }

    private func copyActivities() {
        guard let draft else { return }
        SpreadsheetClipboard.write(draft.tabularText())
        transferIssue = nil
    }

    private func requireDraft() throws -> ProjectSchedulingDraft {
        guard let draft else { throw SpreadsheetTransferError.emptyClipboard }
        return draft
    }
}
