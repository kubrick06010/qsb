import Foundation
import Observation
import QSBCore

@Observable
final class QSBWorkspace {
    var selectedPane: WorkspacePane? = .model
    var modelJSON: String
    var solutionJSON: String = ""
    var status: String = "Ready"
    var lastResultLabel: String?
    var selectedBackend: SolverBackendKind = .nativeEducational
    var selectedLayoutStrategy: FacilityLayoutSolvingStrategy = .initial
    var isImportingModel = false
    var isExportingModel = false
    var isExportingSolution = false

    init(modelJSON: String = SampleModels.linearProgramJSON) {
        self.modelJSON = modelJSON
    }

    func solve(_ mode: SolveMode) {
        do {
            let modelData = Data(modelJSON.utf8)
            let program = try LinearProgramJSON.decodeProgram(from: modelData)
            guard let solver = LinearProgrammingBackends.backend(for: selectedBackend) else {
                solutionJSON = ""
                status = "External backend is not available yet"
                selectedPane = .model
                return
            }
            guard solver.capabilities.solves else {
                try showValidationReport(solver.validationReport(for: program), source: mode.label)
                return
            }

            let solution = try solver.solve(
                program,
                mode: mode == .relaxation ? .continuous : .integer
            )

            let output = try LinearProgramJSON.encodeSolution(solution)
            solutionJSON = String(decoding: output, as: UTF8.self)
            status = "\(mode.label) solved with \(selectedBackend.rawValue): objective \(format(solution.objectiveValue))"
            lastResultLabel = mode.label
            selectedPane = .solution
        } catch {
            solutionJSON = ""
            status = "Error: \(Self.message(for: error))"
            selectedPane = .model
        }
    }

    func solveNetwork() {
        do {
            let modelData = Data(modelJSON.utf8)
            let model = try NetworkModelJSON.decodeModel(from: modelData)
            if selectedBackend == .validateOnly {
                let report = ValidationReport(diagnostics: [
                    ValidationDiagnostic(
                        severity: .info,
                        code: "network.valid",
                        message: "Network model JSON decoded successfully"
                    )
                ])
                try showValidationReport(report, source: model.kind.rawValue)
                return
            }
            if selectedBackend == .externalHighPerformance {
                solutionJSON = ""
                status = "External backend is not available yet"
                selectedPane = .model
                return
            }
            let solution = try solveNetworkModel(model)
            let output = try NetworkModelJSON.encodeSolution(solution)
            solutionJSON = String(decoding: output, as: UTF8.self)
            status = "\(model.kind.rawValue) solved with \(selectedBackend.rawValue): \(solution.summary(format: format))"
            lastResultLabel = "\(model.kind.rawValue) Solution"
            selectedPane = .solution
        } catch {
            solutionJSON = ""
            status = "Error: \(Self.message(for: error))"
            selectedPane = .model
        }
    }

    func solveFacilities() {
        do {
            let data = Data(modelJSON.utf8)
            let envelope = try FacilitiesModelJSON.decodeUncheckedModel(from: data)
            guard let solver = FacilitiesBackends.backend(for: selectedBackend) else {
                solutionJSON = ""
                status = "External backend is not available yet"
                selectedPane = .model
                return
            }
            guard solver.capabilities.solves else {
                try showFacilitiesValidationReport(
                    solver.validationReport(for: envelope),
                    kind: envelope.kind
                )
                return
            }

            let solution = try solver.solve(
                envelope,
                layoutStrategy: selectedLayoutStrategy
            )
            let document = FacilitiesSolutionDocument(
                backend: solver.runMetadata(
                    for: envelope,
                    layoutStrategy: selectedLayoutStrategy
                ),
                solution: solution
            )
            let output = try FacilitiesModelJSON.encodeSolutionDocument(document)
            solutionJSON = String(decoding: output, as: UTF8.self)
            status = "\(envelope.kind.displayName) solved with \(selectedBackend.rawValue): \(solution.summary(format: format))"
            lastResultLabel = "\(envelope.kind.displayName) Solution"
            selectedPane = .solution
        } catch {
            solutionJSON = ""
            status = "Error: \(Self.message(for: error))"
            selectedPane = .model
        }
    }

    func validateCurrentModel() {
        do {
            let data = Data(modelJSON.utf8)
            do {
                let program = try LinearProgramJSON.decodeProgram(from: data)
                try validate(program: program, source: "LP/ILP JSON")
            } catch {
                do {
                    _ = try NetworkModelJSON.decodeModel(from: data)
                    let report = ValidationReport(diagnostics: [
                        ValidationDiagnostic(
                            severity: .info,
                            code: "network.valid",
                            message: "Network model JSON decoded successfully"
                        )
                    ])
                    try showValidationReport(report, source: "Network JSON")
                } catch {
                    let envelope = try FacilitiesModelJSON.decodeUncheckedModel(from: data)
                    let backend = ValidateOnlyFacilitiesBackend()
                    try showFacilitiesValidationReport(
                        backend.validationReport(for: envelope),
                        kind: envelope.kind
                    )
                }
            }
        } catch {
            solutionJSON = ""
            status = "Validation failed: \(Self.message(for: error))"
            selectedPane = .model
        }
    }

    func loadSample(_ sample: SampleModel) {
        switch sample {
        case .linearProgram:
            modelJSON = SampleModels.linearProgramJSON
        case .integerProgram:
            modelJSON = SampleModels.integerProgramJSON
        case .travelingSalesperson:
            modelJSON = SampleModels.travelingSalespersonJSON
        case .facilityLayout:
            modelJSON = SampleModels.facilityLayoutJSON
        }
        solutionJSON = ""
        lastResultLabel = nil
        status = "Loaded sample model"
        selectedPane = .model
    }

    func importModel(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            try validateSupportedModel(data)
            modelJSON = String(decoding: data, as: UTF8.self)
            solutionJSON = ""
            lastResultLabel = nil
            status = "Imported \(url.lastPathComponent)"
            selectedPane = .model
        } catch {
            status = "Import failed: \(Self.message(for: error))"
            selectedPane = .model
        }
    }

    func recordExportResult(_ result: Result<URL, Error>, label: String) {
        switch result {
        case .success(let url):
            status = "Exported \(label) to \(url.lastPathComponent)"
        case .failure(let error):
            status = "Export failed: \(Self.message(for: error))"
        }
    }

    private func validateSupportedModel(_ data: Data) throws {
        do {
            _ = try LinearProgramJSON.decodeProgram(from: data)
        } catch {
            do {
                _ = try NetworkModelJSON.decodeModel(from: data)
            } catch {
                _ = try FacilitiesModelJSON.decodeModel(from: data)
            }
        }
    }

    private func solveNetworkModel(_ model: NetworkModelEnvelope) throws -> NetworkSolutionEnvelope {
        switch model {
        case .shortestPath(let network):
            return .shortestPath(try ShortestPathSolver.solve(network))
        case .minimumSpanningTree(let network):
            return .minimumSpanningTree(try MinimumSpanningTreeSolver.solve(network))
        case .maxFlow(let network):
            return .maxFlow(try MaxFlowSolver.solve(network))
        case .travelingSalesperson(let problem):
            return .travelingSalesperson(try TravelingSalespersonSolver.solve(problem))
        case .assignment(let problem):
            return .assignment(try AssignmentSolver.solve(problem))
        case .transportation(let problem):
            return .transportation(try TransportationSolver.solve(problem))
        }
    }

    private func validate(program: LinearProgram, source: String) throws {
        let report = ValidationReport(diagnostics: LinearProgramValidator.diagnostics(for: program))
        try showValidationReport(report, source: source)
    }

    private func showValidationReport(_ report: ValidationReport, source: String) throws {
        let output = try Self.jsonEncoder.encode(report)
        solutionJSON = String(decoding: output, as: UTF8.self)
        let errorCount = report.diagnostics.filter { $0.severity == .error }.count
        status = report.isValid
            ? "\(source) is valid"
            : "\(source) has \(errorCount) validation error(s)"
        lastResultLabel = "\(source) Validation"
        selectedPane = .solution
    }

    private func showFacilitiesValidationReport(
        _ report: ValidationReport,
        kind: FacilitiesProblemKind
    ) throws {
        let document = FacilitiesValidationDocument(
            kind: kind,
            backend: report.backend,
            diagnostics: report.diagnostics
        )
        let output = try FacilitiesModelJSON.encodeValidation(document)
        solutionJSON = String(decoding: output, as: UTF8.self)
        let errorCount = report.diagnostics.filter { $0.severity == .error }.count
        status = report.isValid
            ? "\(kind.displayName) is valid"
            : "\(kind.displayName) has \(errorCount) validation error(s)"
        lastResultLabel = "\(kind.displayName) Validation"
        selectedPane = .solution
    }

    var currentModelFamily: WorkspaceModelFamily {
        let data = Data(modelJSON.utf8)
        if (try? LinearProgramJSON.decodeProgram(from: data)) != nil {
            return .linearProgramming
        }
        if (try? NetworkModelJSON.decodeModel(from: data)) != nil {
            return .network
        }
        if let envelope = try? FacilitiesModelJSON.decodeUncheckedModel(from: data) {
            return .facilities(envelope.kind)
        }
        return .unknown
    }

    var isFacilityLayoutModel: Bool {
        guard case .facilities(.layout) = currentModelFamily else {
            return false
        }
        return true
    }

    var isLinearProgrammingModel: Bool {
        guard case .linearProgramming = currentModelFamily else {
            return false
        }
        return true
    }

    var isNetworkModel: Bool {
        guard case .network = currentModelFamily else {
            return false
        }
        return true
    }

    var isFacilitiesModel: Bool {
        guard case .facilities = currentModelFamily else {
            return false
        }
        return true
    }

    var solutionSubtitle: String {
        lastResultLabel ?? "No solve or validation has run"
    }

    var modelDocument: JSONTextDocument {
        JSONTextDocument(text: modelJSON)
    }

    var solutionDocument: JSONTextDocument {
        JSONTextDocument(text: solutionJSON.isEmpty ? "{}" : solutionJSON)
    }

    private func format(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 1e-8 {
            return String(Int(rounded))
        }
        return String(format: "%.6f", value)
    }

    private static func message(for error: Error) -> String {
        switch error {
        case let error as LinearProgramError:
            return error.description
        case let error as NetworkModelError:
            return error.description
        case let error as FacilitiesModelError:
            return error.description
        case let error as DecodingError:
            return "Invalid JSON model: \(error)"
        default:
            return String(describing: error)
        }
    }

    private static var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension FacilitiesProblemKind {
    var displayName: String {
        switch self {
        case .lineBalancing:
            "Line Balancing"
        case .location:
            "Facility Location"
        case .layout:
            "Facility Layout"
        }
    }
}

private extension FacilitiesSolutionEnvelope {
    func summary(format: (Double) -> String) -> String {
        switch self {
        case .lineBalancing(let solution):
            "\(solution.stationCount) stations, efficiency \(format(solution.efficiency))"
        case .location(let solution):
            "objective \(format(solution.objectiveValue))"
        case .layout(let solution):
            if let search = solution.search {
                "objective \(format(solution.objectiveValue)), improvement \(format(search.improvement))"
            } else {
                "objective \(format(solution.objectiveValue))"
            }
        }
    }
}

private extension NetworkSolutionEnvelope {
    func summary(format: (Double) -> String) -> String {
        switch self {
        case .shortestPath(let solution):
            return "cost \(format(solution.totalCost))"
        case .minimumSpanningTree(let solution):
            return "cost \(format(solution.totalCost))"
        case .maxFlow(let solution):
            return "flow \(format(solution.maxFlow))"
        case .travelingSalesperson(let solution):
            return "cost \(format(solution.totalCost))"
        case .assignment(let solution):
            return "cost \(format(solution.totalCost))"
        case .transportation(let solution):
            return "cost \(format(solution.totalCost))"
        }
    }
}
