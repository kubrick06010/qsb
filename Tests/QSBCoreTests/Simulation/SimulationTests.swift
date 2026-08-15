import Foundation
import Testing
@testable import QSBCore

@Test func roundTripsAndValidatesSimulationBackends() throws {
    let model = try legacySimulation("QSS3.QS_")
    #expect(try SimulationJSON.decodeModel(from: SimulationJSON.encodeModel(model)) == model)
    let native = NativeEducationalSimulationBackend()
    let solution = try native.solve(model, options: SolverOptions(timeLimitSeconds: 100, randomSeed: 3))
    let solutionJSON = try SimulationJSON.encodeSolution(native.solutionDocument(for: model, solution: solution))
    #expect(String(decoding: solutionJSON, as: UTF8.self).contains("seededDiscreteEventSimulation"))
    #expect(ValidateOnlySimulationBackend().validationReport(for: model).isValid)
    #expect(SimulationBackends.backend(for: .externalHighPerformance) == nil)
    #expect(throws: SimulationError.self) { _ = try ValidateOnlySimulationBackend().solve(model) }
}
@Test func parsesAndSimulatesEquivalentWinQSSAssemblyRepresentations() throws {
    let matrix = try legacySimulation("QSS3.QS_")
    let graphic = try legacySimulation("QSSGRAPH.QS_")
    #expect(matrix.representation == .matrix)
    #expect(graphic.representation == .graphic)
    #expect(matrix.components.count == 13)
    #expect(graphic.components.count == 13)
    #expect(Set(matrix.components.map { $0.name.lowercased() }) == Set(graphic.components.map { $0.name.lowercased() }))
    let matrixSolution = try DiscreteEventSimulationSolver.solve(matrix, horizon: 200, seed: 11)
    let graphicSolution = try DiscreteEventSimulationSolver.solve(graphic, horizon: 200, seed: 11)
    #expect(matrixSolution.serverMetrics.first { $0.name == "Station 5" }?.completed ?? 0 > 0)
    #expect(graphicSolution.serverMetrics.first { $0.name == "Station 5" }?.completed ?? 0 > 0)
}
