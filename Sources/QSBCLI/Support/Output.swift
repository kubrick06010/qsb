import Foundation
import QSBCore

extension QSBCLI {
    static func printError(_ message: String) {
        write("qsb: error: \(message)", to: .standardError)
    }

    static func write(_ message: String, to handle: FileHandle) {
        handle.write(Data((message + "\n").utf8))
    }

    static func userFacingMessage(for error: Error) -> String {
        switch error {
        case let error as LinearProgramError: return error.description
        case let error as LegacyCompressionError: return error.description
        case let error as NetworkModelError: return error.description
        case let error as ForecastingModelError: return error.description
        case let error as InventoryModelError: return error.description
        case let error as DynamicProgrammingModelError: return error.description
        case let error as DecisionAnalysisModelError: return error.description
        case let error as QueuingModelError: return error.description
        case let error as SchedulingModelError: return error.description
        case let error as QualityControlError: return error.description
        case let error as AggregatePlanningError: return error.description
        case let error as MaterialRequirementsPlanningError: return error.description
        case let error as QuadraticProgrammingError: return error.description
        case let error as NonlinearProgrammingError: return error.description
        case let error as SimulationError: return error.description
        case let error as FacilitiesModelError: return error.description
        case let error as DecodingError: return "Invalid model JSON: \(describe(error))"
        case let error as EncodingError: return "Could not encode JSON: \(describe(error))"
        case let error as CocoaError where error.code == .fileReadNoSuchFile: return "File not found"
        default: return String(describing: error)
        }
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch(let type, let context): return "expected \(type) at \(codingPath(context.codingPath))"
        case .valueNotFound(let type, let context): return "missing value for \(type) at \(codingPath(context.codingPath))"
        case .keyNotFound(let key, let context): return "missing key '\(key.stringValue)' at \(codingPath(context.codingPath))"
        case .dataCorrupted(let context): return context.debugDescription
        @unknown default: return String(describing: error)
        }
    }

    private static func describe(_ error: EncodingError) -> String {
        switch error {
        case .invalidValue(_, let context): return context.debugDescription
        @unknown default: return String(describing: error)
        }
    }

    private static func codingPath(_ path: [CodingKey]) -> String {
        guard !path.isEmpty else { return "<root>" }
        return path.map(\.stringValue).joined(separator: ".")
    }
}
