import Foundation
import QSBCore
import Testing
@testable import QSBMacApp

@Test("matrix navigation preserves source identity through reorder and chooses a nearby source after removal")
func matrixSourceIdentityAndRemoval() {
    let rows = [UUID(), UUID(), UUID()]
    var navigation = MatrixEditorNavigation(rowID: rows[2], columnGroup: 3)
    navigation.reconcile(previousRows: rows, rows: rows.reversed(), columnCount: 40)
    #expect(navigation.rowIndex(in: rows.reversed()) == 0)
    navigation.reconcile(previousRows: rows.reversed(), rows: [rows[1], rows[0]], columnCount: 13)
    #expect(navigation.rowID == rows[1])
    #expect(navigation.columns(columnCount: 13) == 12..<13)
    navigation.reconcile(previousRows: [rows[1], rows[0]], rows: [], columnCount: 0)
    #expect(navigation.rowID == nil)
    #expect(navigation.rowIndex(in: []) == nil)
    #expect(navigation.columns(columnCount: 0).isEmpty)
}

@Test("matrix destination groups cover all columns including boundary and invalid selections")
func matrixColumnGroupsAndBoundaries() {
    for count in [1, 12, 13, 24, 25, 40] {
        let navigation = MatrixEditorNavigation()
        let groups = (0..<navigation.groupCount(columnCount: count)).flatMap {
            Array(MatrixEditorNavigation(columnGroup: $0).columns(columnCount: count))
        }
        #expect(groups == Array(0..<count))
    }
    #expect(MatrixEditorNavigation(columnGroup: -2).columns(columnCount: 25) == 0..<12)
    #expect(MatrixEditorNavigation(columnGroup: Int.max).columns(columnCount: 25) == 24..<25)
    let last = MatrixEditorNavigation(columnGroup: Int.max).columns(columnCount: Int.max)
    #expect(last.upperBound == Int.max)
    #expect(last.count <= MatrixEditorNavigation.columnsPerGroup)
}

@Test("facilities matrix pastes repair independently and retain nullable cells")
func facilitiesIndependentMatrixRepair() throws {
    var layout = FacilityLayoutDraft.blank()
    layout.rowCount = "unfinished"
    let table = layout.costsTable()
    try layout.replaceCosts(with: table)
    #expect(layout.rowCount == "unfinished")
    #expect(layout.draftDiagnostics().contains { $0.severity == .error })
    let before = layout
    var rows = try SpreadsheetTable(text: table).rows
    rows[1][1] = "bad"
    #expect(throws: SpreadsheetTransferError.self) {
        try layout.replaceCosts(with: rows.map { $0.joined(separator: "\t") }.joined(separator: "\n"))
    }
    #expect(layout == before)

    var location = FacilityLocationDraft.blank()
    location.facilities[0].x = "unfinished"
    let interactions = location.interactionsTable()
    try location.replaceInteractions(with: interactions)
    #expect(location.facilities[0].x == "unfinished")
    #expect(location.draftDiagnostics().contains { $0.severity == .error })
}

@Test("location matrix labels distinguish equal names across scoped roles and accept unique legacy names")
func locationMatrixScopedLabels() throws {
    let problem = FacilityLocationProblem(title: "Shared names", distanceMeasure: .squaredEuclidean, objective: "MIN", facilities: [
        FacilityLocationFacility(id: 1, name: "Site", isNew: false, x: 0, y: 0, interactionCosts: [nil, 3]),
        FacilityLocationFacility(id: 1, name: "Site", isNew: true, x: nil, y: nil, interactionCosts: [5, nil])
    ])
    var draft = FacilityLocationDraft(problem)
    let table = draft.interactionsTable()
    #expect(table.contains("Existing [1] Site"))
    #expect(table.contains("New [1] Site"))
    try draft.replaceInteractions(with: table)
    #expect(try draft.makeProblem() == problem)
    let before = draft
    #expect(throws: SpreadsheetTransferError.self) {
        try draft.replaceInteractions(with: "Facility\tSite\tSite\nSite\t\t3\nSite\t5\t")
    }
    #expect(draft == before)
    draft.facilities[1].name = "New Site"
    try draft.replaceInteractions(with: "Facility\tSite\tNew Site\nSite\t\t7\nNew Site\t9\t")
    #expect(try draft.makeProblem().facilities.map(\.interactionCosts) == [[nil, 7], [9, nil]])
}
