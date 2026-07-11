import SwiftUI
import QSBCore

enum WorkspacePane: String, CaseIterable, Identifiable {
    case model
    case solution

    var id: String { rawValue }

    var title: String {
        switch self {
        case .model:
            "Model"
        case .solution:
            "Solution"
        }
    }

    var systemImage: String {
        switch self {
        case .model:
            "doc.text"
        case .solution:
            "function"
        }
    }
}

enum SolveMode {
    case relaxation
    case integer

    var label: String {
        switch self {
        case .relaxation:
            "LP Relaxation"
        case .integer:
            "ILP"
        }
    }
}

enum WorkspaceModelFamily {
    case linearProgramming
    case network
    case facilities(FacilitiesProblemKind)
    case unknown

    var editorSubtitle: String {
        switch self {
        case .linearProgramming:
            "Normalized LP/ILP JSON"
        case .network:
            "Normalized network JSON"
        case .facilities(let kind):
            "Normalized facilities JSON · \(kind.displayName)"
        case .unknown:
            "Normalized model JSON"
        }
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

enum SampleModel {
    case linearProgram
    case integerProgram
    case travelingSalesperson
    case facilityLayout
}
