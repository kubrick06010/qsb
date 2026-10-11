import Foundation
import QSBCore
import Testing
@testable import QSBMacApp

@MainActor
@Test("All thirteen specialized model samples have readable result algorithm names")
func specializedResultMetadataPresentation() throws {
    struct MetadataDocument: Decodable { let backend: SolverRunMetadata }
    let samples: [SampleModel] = [.quadraticProgramming, .nonlinearProgramming, .goalProgramming,
        .boundedKnapsack, .aggregatePlanning, .materialRequirementsPlanning, .projectScheduling,
        .facilityLayout, .facilityLocation, .lineBalancing, .acceptanceSampling, .qualityControl, .simulation]
    for sample in samples {
        let workspace = QSBWorkspace()
        workspace.loadSample(sample)
        workspace.runCurrentModel()
        #expect(workspace.runState == .solved)
        let metadata = try JSONDecoder().decode(MetadataDocument.self, from: Data(workspace.solutionJSON.utf8)).backend
        #expect(metadata.backendDisplayName == "QSB Native")
        #expect(metadata.algorithmDisplayName != "Custom algorithm")
        #expect(metadata.algorithmDisplayName != metadata.algorithm)
    }
}

@Test("Metadata labels retain unknown identifiers and do not claim stronger exactness")
func resultMetadataLabelsPreserveInterchange() throws {
    let metadata = SolverRunMetadata(backendKind: .externalHighPerformance,
        algorithm: "vendorSpecificMethod", exactness: .fixtureScale, notes: ["Scale restriction"])
    #expect(metadata.backendDisplayName == "External solver")
    #expect(metadata.algorithmDisplayName == "Custom algorithm")
    #expect(metadata.exactnessDisplayName == "Limited scale")
    let decoded = try JSONDecoder().decode(SolverRunMetadata.self, from: JSONEncoder().encode(metadata))
    #expect(decoded == metadata)
    #expect(decoded.algorithm == "vendorSpecificMethod")
    for exactness in [SolverExactness.exact, .closedForm, .heuristic, .approximate] {
        let value = SolverRunMetadata(backendKind: .validateOnly, algorithm: "validationOnly", exactness: exactness)
        #expect(value.backendDisplayName == "Validate only")
        #expect(value.algorithmDisplayName == "Validation only")
        #expect(!value.exactnessDisplayName.isEmpty)
    }
}
