import SwiftUI
import QSBCore

struct AcceptanceSamplingEditorView: View {
    @Bindable var workspace: QSBWorkspace
    @Environment(\.undoManager) private var undoManager

    private var draft: AcceptanceSamplingDraft? { workspace.acceptanceSamplingDraft }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(title: workspace.modelTitle, subtitle: "Native acceptance-sampling editor · \(workspace.modelState.rawValue)")
            if let draft {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        actionBar
                        issues(draft)
                        planSection(draft)
                        qualitySection
                        economicsSection
                    }
                    .padding(20)
                    .frame(maxWidth: 1_180, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .navigationTitle("Acceptance Sampling Definition")
    }

    private var actionBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { actionButtons; Spacer(); familyLabel }
            VStack(alignment: .leading, spacing: 8) { HStack(spacing: 10) { actionButtons }; familyLabel }
        }
    }

    @ViewBuilder private var actionButtons: some View {
        Button("Validate", systemImage: "checkmark.seal") { workspace.validateCurrentModel() }
            .keyboardShortcut("v", modifiers: [.command, .shift])
            .accessibilityHint("Checks sampling decisions, risks, quality levels, and economic inputs")
        Button("Run", systemImage: "play.circle") { workspace.startCurrentModelRun() }
            .buttonStyle(.borderedProminent).keyboardShortcut("r", modifiers: [.command])
            .disabled(workspace.modelState == .invalid || workspace.runState == .solving)
            .accessibilityHint("Calculates the operating characteristic and sampling measures")
    }

    private var familyLabel: some View {
        Text(workspace.currentModelFamily.displayName).font(.callout).foregroundStyle(.secondary)
    }

    private func planSection(_ draft: AcceptanceSamplingDraft) -> some View {
        GroupBox("Sampling plan") {
            VStack(alignment: .leading, spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom, spacing: 16) { commonPlanFields(draft) }
                    VStack(alignment: .leading, spacing: 10) { commonPlanFields(draft) }
                }
                if draft.kind == .single {
                    adaptiveFields([
                        ("Sample size", \.sampleSize, 150),
                        ("Acceptance number", \.acceptanceNumber, 170)
                    ])
                } else {
                    adaptiveFields([
                        ("First sample size", \.firstSampleSize, 150),
                        ("First acceptance", \.firstAcceptanceNumber, 150),
                        ("First rejection", \.firstRejectionNumber, 150),
                        ("Second sample size", \.secondSampleSize, 150),
                        ("Cumulative acceptance", \.cumulativeSecondAcceptanceNumber, 180)
                    ])
                }
            }
            .padding(8)
        }
    }

    @ViewBuilder private func commonPlanFields(_ draft: AcceptanceSamplingDraft) -> some View {
        field("Title", keyPath: \.title, width: 330, identifier: "acceptance-title")
        VStack(alignment: .leading, spacing: 4) {
            Text("Plan type").font(.caption).foregroundStyle(.secondary)
            Picker("Plan type", selection: Binding(
                get: { draft.kind },
                set: { kind in update("Change Plan Type") { $0.switchKind(to: kind) } }
            )) {
                Text("Single sample").tag(AcceptanceSamplingPlanKind.single)
                Text("Double sample").tag(AcceptanceSamplingPlanKind.double)
            }
            .labelsHidden().pickerStyle(.segmented).frame(width: 260)
            .accessibilityLabel("Acceptance sampling plan type")
        }
    }

    private var qualitySection: some View {
        GroupBox("Quality levels and risks") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Enter probabilities as decimals between 0 and 1.")
                    .font(.caption).foregroundStyle(.secondary)
                adaptiveFields([
                    ("Acceptable quality level", \.acceptableQualityLevel, 190),
                    ("Rejectable quality level", \.rejectableQualityLevel, 190),
                    ("Producer risk", \.nominalProducerRisk, 150),
                    ("Consumer risk", \.nominalConsumerRisk, 150)
                ])
            }
            .padding(8)
        }
    }

    private var economicsSection: some View {
        GroupBox("Lot and economics") {
            adaptiveFields([
                ("Lot size", \.lotSize, 130),
                ("Sampling cost / unit", \.unitSamplingCost, 170),
                ("Inspection cost / unit", \.unitInspectionCost, 180),
                ("Producer defective cost", \.producerDefectiveCost, 190),
                ("Consumer defective cost", \.consumerDefectiveCost, 190)
            ])
            .padding(8)
        }
    }

    private func adaptiveFields(_ fields: [(String, WritableKeyPath<AcceptanceSamplingDraft, String>, CGFloat)]) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(Array(fields.enumerated()), id: \.offset) { _, fieldSpec in
                    field(fieldSpec.0, keyPath: fieldSpec.1, width: fieldSpec.2)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(fields.enumerated()), id: \.offset) { _, fieldSpec in
                    field(fieldSpec.0, keyPath: fieldSpec.1, width: fieldSpec.2)
                }
            }
        }
    }

    private func field(
        _ label: String,
        keyPath: WritableKeyPath<AcceptanceSamplingDraft, String>,
        width: CGFloat,
        identifier: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: Binding(
                get: { workspace.acceptanceSamplingDraft?[keyPath: keyPath] ?? "" },
                set: { value in update("Edit \(label)") { $0[keyPath: keyPath] = value } }
            ))
            .textFieldStyle(.roundedBorder).frame(width: width)
            .accessibilityLabel(label).accessibilityIdentifier(identifier ?? "acceptance-\(label.lowercased().replacingOccurrences(of: " ", with: "-"))")
        }
    }

    @ViewBuilder private func issues(_ draft: AcceptanceSamplingDraft) -> some View {
        let diagnostics = draft.draftDiagnostics().filter { $0.severity != .info }
        if !diagnostics.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                    Label(diagnostic.message, systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(diagnostic.severity == .error ? .red : .orange)
                }
            }
            .accessibilityElement(children: .contain).accessibilityLabel("Acceptance sampling input issues")
        }
    }

    private func update(_ actionName: String, _ mutation: (inout AcceptanceSamplingDraft) -> Void) {
        guard var next = workspace.acceptanceSamplingDraft else { return }
        mutation(&next)
        workspace.replaceAcceptanceSamplingDraft(next, undoManager: undoManager, actionName: actionName)
    }
}
