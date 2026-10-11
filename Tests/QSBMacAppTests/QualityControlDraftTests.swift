import Foundation
import Testing
import QSBCore
@testable import QSBMacApp

@Test("quality-control drafts round trip every supported analysis")
func qualityControlDraftRoundTrips() throws {
    let models: [QualityControlModelEnvelope] = [
        .cChart(CChartModel(title: "c", characteristic: "defects", counts: [1, 2, 3])),
        .pChart(PChartModel(title: "p", characteristic: "defective", sampleSizes: [100, 120], proportions: [0.02, 0.04])),
        .xbarRChart(XbarRChartModel(title: "x", characteristic: "length", subgroups: [[1, 2, 3], [2, 3, 4]])),
        .pareto(ParetoModel(title: "pareto", categoryNames: ["A", "B"], subgroupCounts: [[3, 2], [4, 1]])),
        .normalProbabilityPlot(NormalProbabilityPlotModel(title: "normal", characteristic: "weight", values: [1, 2, 3, 4]))
    ]
    for model in models { #expect(try QualityControlDraft(model).makeModel() == model) }
}

@Test("quality-control spreadsheet transfer is complete and atomic")
func qualityControlSpreadsheetTransfer() throws {
    let model = QualityControlModelEnvelope.pareto(ParetoModel(title: "pareto", categoryNames: ["A", "B"], subgroupCounts: [[3, 2], [4, 1]]))
    var draft = QualityControlDraft(model)
    let table = draft.tabularText()
    try draft.replaceTable(withTabularText: table)
    #expect(try draft.makeModel() == model)
    let before = draft
    var rows = try SpreadsheetTable(text: table).rows
    rows[1][1] = "invalid"
    #expect(throws: SpreadsheetTransferError.self) { try draft.replaceTable(withTabularText: rows.map { $0.joined(separator: "\t") }.joined(separator: "\n")) }
    #expect(draft == before)
}

@MainActor
@Test("workspace routes native quality-control drafts through validation solving and export")
func qualityControlWorkspaceWorkflow() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.qualityControl)
    #expect(workspace.qualityControlDraft != nil)
    workspace.validateCurrentModel()
    #expect(workspace.modelState == .valid)
    workspace.runCurrentModel()
    #expect(workspace.runState == .solved)
    workspace.beginModelExport()
    #expect(workspace.isExportingModel)
    #expect(try QualityControlJSON.decodeModel(from: Data(workspace.modelJSON.utf8)).title == "Weekly Defect Count")
}

@MainActor
@Test("quality-control invalid fields and undo redo stay in the native draft")
func qualityControlInvalidStateAndUndo() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.qualityControl)
    let original = try #require(workspace.qualityControlDraft)
    var changed = original
    changed.rows[0].values[0] = "invalid"
    let undoManager = UndoManager()
    workspace.replaceQualityControlDraft(changed, undoManager: undoManager, actionName: "Edit Count")
    workspace.validateCurrentModel()
    #expect(workspace.modelState == .invalid)
    #expect(workspace.validationDiagnostics.contains { $0.path?.contains("values") == true })
    undoManager.undo()
    #expect(workspace.qualityControlDraft == original)
    undoManager.redo()
    #expect(workspace.qualityControlDraft == changed)
}

@Test("switching quality-control analyses preserves unfinished tables and identities")
func qualityControlVariantRetention() {
    var draft = QualityControlDraft.blank()
    draft.title = "Shared title"
    let kinds: [QualityControlProblemKind] = [.cChart, .pChart, .xbarRChart, .pareto, .normalProbabilityPlot]
    var tables: [String: [QualityControlRowDraft]] = [:]
    var columns: [String: [QualityControlColumnDraft]] = [:]
    for kind in kinds {
        draft.switchKind(to: kind)
        draft.characteristic = kind.rawValue
        draft.rows[0].values[0] = "unfinished \(kind.rawValue)"
        tables[kind.rawValue] = draft.rows
        columns[kind.rawValue] = draft.columns
    }
    for kind in kinds.reversed() {
        draft.switchKind(to: kind)
        #expect(draft.title == "Shared title")
        #expect(draft.characteristic == kind.rawValue)
        #expect(draft.rows == tables[kind.rawValue])
        #expect(draft.columns == columns[kind.rawValue])
        #expect(draft.draftDiagnostics().contains { $0.severity == .error })
    }
}

@Test("malformed quality-control imports retain values and allow direct repair")
func qualityControlMalformedImports() throws {
    var proportions = QualityControlDraft(.pChart(PChartModel(title: "p", characteristic: "c", sampleSizes: [100, 120], proportions: [0.1])))
    #expect(proportions.rows.map(\.values) == [["100", "0.1"], ["120", ""]])
    #expect(throws: QualityControlDraftError.self) { try proportions.makeModel() }
    proportions.rows[1].values[1] = "0.2"
    #expect(proportions.draftDiagnostics().allSatisfy { $0.severity != .error })
    proportions.addRow()
    #expect(proportions.rows.last?.values == ["100", "0.1"])

    var measurements = QualityControlDraft(.xbarRChart(XbarRChartModel(title: "x", characteristic: "c", subgroups: [[], [1, 2, 3]])))
    #expect(measurements.columns.count == 3)
    #expect(measurements.rows.map(\.values) == [["", "", ""], ["1.0", "2.0", "3.0"]])
    measurements.removeColumn(id: measurements.columns[2].id)
    measurements.rows[0].values = ["4", "5"]
    #expect(measurements.draftDiagnostics().allSatisfy { $0.severity != .error })
    let empty = QualityControlDraft(.xbarRChart(XbarRChartModel(title: "x", characteristic: "c", subgroups: [[]])))
    #expect(empty.columns.isEmpty)
    #expect(throws: QualityControlDraftError.self) { try empty.makeModel() }

    var pareto = QualityControlDraft(.pareto(ParetoModel(title: "p", categoryNames: ["A"], subgroupCounts: [[1, 2], [3]])))
    #expect(pareto.columns.map(\.name) == ["A", ""])
    #expect(pareto.rows.map(\.values) == [["1.0", "2.0"], ["3.0", ""]])
    pareto.columns[1].name = "B"
    pareto.rows[1].values[1] = "4"
    #expect(pareto.draftDiagnostics().allSatisfy { $0.severity != .error })
}

@MainActor
@Test("analysis switches and retained drafts participate in workspace undo redo")
func qualityControlVariantUndo() throws {
    let workspace = QSBWorkspace()
    workspace.loadSample(.qualityControl)
    let original = try #require(workspace.qualityControlDraft)
    var changed = original
    changed.switchKind(to: .pChart)
    changed.rows[0].values[1] = "unfinished"
    let undoManager = UndoManager()
    workspace.replaceQualityControlDraft(changed, undoManager: undoManager, actionName: "Change Analysis")
    undoManager.undo()
    #expect(workspace.qualityControlDraft == original)
    undoManager.redo()
    #expect(workspace.qualityControlDraft == changed)
    var restored = try #require(workspace.qualityControlDraft)
    restored.switchKind(to: .cChart)
    #expect(try restored.makeModel() == original.makeModel())
    restored.switchKind(to: .pChart)
    #expect(restored.rows == changed.rows)
}

@Test("quality-control table repair preserves observations independently of metadata")
func qualityControlIndependentSpreadsheetRepair() throws {
    var draft = QualityControlDraft(.pareto(ParetoModel(title: "p", categoryNames: ["A", "B"], subgroupCounts: [[3, 2], [4, 1]])))
    draft.title = ""
    let rowIDs = draft.rows.map(\.id)
    let columnIDs = draft.columns.map(\.id)
    try draft.replaceTable(withTabularText: "Subgroup\tB\tA\n2\t5\t6\n1\t7\t8")
    #expect(draft.rows.map(\.id) == rowIDs.reversed())
    #expect(draft.columns.map(\.id) == columnIDs.reversed())
    #expect(draft.title.isEmpty)
    let before = draft
    #expect(throws: SpreadsheetTransferError.self) { try draft.replaceTable(withTabularText: "Subgroup\tB\tA\n1\tbad\t8") }
    #expect(draft == before)
    try draft.replaceTable(withTabularText: "Subgroup\tB\tA\n1\t5\t6\n1\t7\t8")
    #expect(draft.rows[0].id != draft.rows[1].id)
    var counts = QualityControlDraft.blank()
    counts.title = ""
    counts.characteristic = ""
    try counts.replaceTable(withTabularText: "Observation\tCount\n1\t3")
    #expect(counts.rows[0].values == ["3"])
    let original = counts
    #expect(throws: QualityControlDraftError.self) { try counts.replaceTable(withTabularText: "Observation\tA\tB\n1\t3\t4") }
    #expect(counts == original)
    try counts.replaceTable(withTabularText: "Observation\tCount\n\(Int.min)\t5")
    #expect(counts.rows[0].values == ["5"])
}
