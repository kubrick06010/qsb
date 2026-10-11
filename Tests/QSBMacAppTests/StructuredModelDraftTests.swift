import Foundation
import Testing
import QSBCore
@testable import QSBMacApp

@Test("guided model draft edits typed Goal Programming fields without changing the JSON contract")
func guidedModelDraftEditsGoalProgrammingModel() throws {
    let root = try StructuredModelNode.parse(SampleModels.goalProgrammingJSON)
    let title = try #require(root.child(named: "title"))
    let constraints = try #require(root.child(named: "constraints"))
    let firstConstraint = try #require(constraints.elements.first)
    let rhs = try #require(firstConstraint.child(named: "rhs"))

    title.text = "Edited Goal Program"
    rhs.text = "12.5"

    let encoded = try root.encodedJSON()
    let model = try GoalProgrammingJSON.decodeModel(from: Data(encoded.utf8))
    try GoalProgrammingValidator.validate(model)

    #expect(model.title == "Edited Goal Program")
    #expect(model.constraints.first?.rhs == 12.5)
    #expect(model.variableNames == ["Primary", "Secondary"])
}

@Test("guided model draft preserves optional values, booleans, and matrices")
func guidedModelDraftPreservesJSONValueTypes() throws {
    let root = try StructuredModelNode.parse(
        """
        {
          "enabled": true,
          "matrix": [[1, 2], [3, 4]],
          "optionalLimit": null,
          "title": "Typed values"
        }
        """
    )
    let optionalLimit = try #require(root.child(named: "optionalLimit"))
    optionalLimit.replaceNull(with: .number)
    optionalLimit.text = "7.25"

    let encoded = try root.encodedJSON()
    let object = try #require(
        JSONSerialization.jsonObject(with: Data(encoded.utf8)) as? [String: Any]
    )
    let matrix = try #require(object["matrix"] as? [[NSNumber]])

    #expect((object["enabled"] as? NSNumber)?.boolValue == true)
    #expect((object["optionalLimit"] as? NSNumber)?.doubleValue == 7.25)
    #expect(matrix.map { $0.map(\.intValue) } == [[1, 2], [3, 4]])
}

@Test("guided model changes reset stale results and continue through QSBCore validation")
func guidedModelChangesUseWorkspaceValidationPath() throws {
    let workspace = QSBWorkspace()
    workspace.startNewGuidedModel(from: .goalProgramming)
    #expect(workspace.modelSource == "New · Goal Programming starter")
    #expect(workspace.selectedPane == .model)
    workspace.runCurrentModel()
    #expect(workspace.runState == .solved)

    let root = try StructuredModelNode.parse(workspace.modelJSON)
    let title = try #require(root.child(named: "title"))
    title.text = "Workspace Edit"
    workspace.updateStructuredModelJSON(try root.encodedJSON())

    #expect(workspace.runState == .notRun)
    #expect(workspace.solutionJSON.isEmpty)
    #expect(workspace.currentModelFamily.displayName == "Goal Programming")

    workspace.validateCurrentModel()
    #expect(workspace.modelState == .valid)
    #expect(workspace.validationDiagnostics.contains { $0.code == "goalProgramming.valid" })
}

@Test("guided model draft round trips every current structured fallback sample")
func guidedModelDraftRoundTripsFallbackSamples() throws {
    let samples: [SampleModel] = [
        .facilityLayout,
        .facilityLocation,
        .lineBalancing,
        .boundedKnapsack,
        .simulation,
        .quadraticProgramming,
        .nonlinearProgramming,
        .goalProgramming,
        .aggregatePlanning,
        .materialRequirementsPlanning,
        .acceptanceSampling,
        .qualityControl,
        .projectScheduling
    ]

    for sample in samples {
        let workspace = QSBWorkspace()
        workspace.loadSample(sample)
        let family = workspace.currentModelFamily.displayName
        let root = try StructuredModelNode.parse(workspace.modelJSON)

        workspace.updateStructuredModelJSON(try root.encodedJSON())
        #expect(workspace.currentModelFamily.displayName == family, "Family changed while round-tripping \(sample.label)")

        workspace.validateCurrentModel()
        #expect(workspace.modelState == .valid, "Guided round trip did not validate for \(sample.label)")
    }
}

@Test("guided model copies and pastes spreadsheet rows with optional headers")
func guidedModelTransfersObjectRowsToSpreadsheet() throws {
    let root = try StructuredModelNode.parse(SampleModels.goalProgrammingJSON)
    let constraints = try #require(root.child(named: "constraints"))

    let exported = try constraints.tabularText()
    #expect(exported.hasPrefix("Name\tCoefficients 1\tCoefficients 2\tRelation\tRight-hand side"))

    try constraints.replaceArrayContents(
        withTabularText: """
        Name\tCoefficients 1\tCoefficients 2\tRelation\tRight-hand side
        Capacity A\t1\t2\t<=\t15
        Capacity B\t3\t4\t>=\t5
        """
    )

    let model = try GoalProgrammingJSON.decodeModel(from: Data(root.encodedJSON().utf8))
    #expect(model.constraints.count == 2)
    #expect(model.constraints[0].name == "Capacity A")
    #expect(model.constraints[0].coefficients == [1, 2])
    #expect(model.constraints[0].rhs == 15)
    #expect(model.constraints[1].relation == .greaterThanOrEqual)
}

@Test("guided model pastes rectangular spreadsheet ranges into matrices")
func guidedModelTransfersSpreadsheetMatrix() throws {
    let root = try StructuredModelNode.parse(SampleModels.quadraticProgrammingJSON)
    let matrix = try #require(root.child(named: "quadraticMatrix"))

    try matrix.replaceArrayContents(withTabularText: "1\t0\n0\t2")

    let model = try QuadraticProgrammingJSON.decodeUncheckedModel(from: Data(root.encodedJSON().utf8))
    #expect(model.quadraticMatrix == [[1, 0], [0, 2]])
    #expect(try matrix.tabularText() == "1\t0\n0\t2")
}

@Test("invalid spreadsheet values preserve the previous guided model")
func guidedModelRejectsInvalidSpreadsheetValuesAtomically() throws {
    let root = try StructuredModelNode.parse(SampleModels.goalProgrammingJSON)
    let constraints = try #require(root.child(named: "constraints"))
    let before = try root.encodedJSON()

    #expect(throws: StructuredModelTabularError.self) {
        try constraints.replaceArrayContents(
            withTabularText: "Capacity A\t1\tnot-a-number\t<=\t15"
        )
    }
    #expect(try root.encodedJSON() == before)
}
