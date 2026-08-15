import Foundation

public enum FacilityLocationValidator {
    public static func diagnostics(for problem: FacilityLocationProblem) -> [ValidationDiagnostic] {
        var diagnostics: [ValidationDiagnostic] = []

        if problem.facilities.isEmpty {
            diagnostics.append(error(
                "facilities.location.facilities.empty",
                "facility location facilities must not be empty",
                path: "facilities"
            ))
        }
        if problem.objective != "MIN" {
            diagnostics.append(error(
                "facilities.location.objective.unsupported",
                "facility location currently supports minimization only",
                path: "objective"
            ))
        }
        if problem.newFacilities.count != 1 {
            diagnostics.append(error(
                "facilities.location.newFacilities.count",
                "facility location currently supports exactly one new facility",
                path: "facilities"
            ))
        }
        if problem.existingFacilities.isEmpty {
            diagnostics.append(error(
                "facilities.location.existingFacilities.empty",
                "facility location requires existing facilities",
                path: "facilities"
            ))
        }

        let facilityNames = problem.facilities.map(\.name)
        if Set(facilityNames).count != facilityNames.count {
            diagnostics.append(error(
                "facilities.location.facilities.duplicate",
                "facility location facility names must be unique",
                path: "facilities"
            ))
        }

        let totalFacilityCount = problem.facilities.count
        for facility in problem.facilities {
            if facility.interactionCosts.count != totalFacilityCount {
                diagnostics.append(error(
                    "facilities.location.interactions.dimension",
                    "facility location interaction rows must match facility count",
                    path: "facilities.\(facility.name).interactionCosts"
                ))
            }

            if !facility.isNew {
                if facility.x == nil || facility.y == nil {
                    diagnostics.append(error(
                        "facilities.location.coordinates.required",
                        "existing facilities require coordinates",
                        path: "facilities.\(facility.name)"
                    ))
                } else if facility.x?.isFinite == false || facility.y?.isFinite == false {
                    diagnostics.append(error(
                        "facilities.location.coordinates.finite",
                        "existing facility coordinates must be finite",
                        path: "facilities.\(facility.name)"
                    ))
                }
            }

            for (index, value) in facility.interactionCosts.enumerated() where (value ?? 0) < 0 || value?.isFinite == false {
                diagnostics.append(error(
                    "facilities.location.interactions.nonnegative",
                    "facility location interaction weights must be finite and nonnegative",
                    path: interactionPath(problem: problem, facility: facility, index: index)
                ))
            }
        }

        if let newIndex = problem.facilities.firstIndex(where: \.isNew),
           problem.facilities[newIndex].interactionCosts.count == totalFacilityCount {
            var hasPositiveInteraction = false
            for existingIndex in problem.facilities.indices where !problem.facilities[existingIndex].isNew {
                guard problem.facilities[existingIndex].interactionCosts.count == totalFacilityCount else {
                    continue
                }
                let forwardWeight = problem.facilities[newIndex].interactionCosts[existingIndex] ?? 0
                let reverseWeight = problem.facilities[existingIndex].interactionCosts[newIndex] ?? 0
                if forwardWeight + reverseWeight > 0 {
                    hasPositiveInteraction = true
                }
            }
            if !hasPositiveInteraction, !problem.existingFacilities.isEmpty {
                diagnostics.append(error(
                    "facilities.location.interactions.positive",
                    "facility location requires at least one positive interaction with the new facility",
                    path: "facilities"
                ))
            }
        }

        guard diagnostics.contains(where: { $0.severity == .error }) == false else {
            return diagnostics
        }

        return diagnostics + [
            ValidationDiagnostic(
                severity: .info,
                code: "facilities.location.valid",
                message: "Facility location model is valid"
            )
        ]
    }

    public static func validate(_ problem: FacilityLocationProblem) throws {
        if let diagnostic = diagnostics(for: problem).first(where: { $0.severity == .error }) {
            throw FacilitiesModelError.invalidModel(diagnostic.message)
        }
    }

    private static func error(_ code: String, _ message: String, path: String?) -> ValidationDiagnostic {
        ValidationDiagnostic(severity: .error, code: code, message: message, path: path)
    }

    private static func interactionPath(
        problem: FacilityLocationProblem,
        facility: FacilityLocationFacility,
        index: Int
    ) -> String {
        guard index < problem.facilities.count else {
            return "facilities.\(facility.name).interactionCosts.\(index)"
        }
        return "facilities.\(facility.name).interactionCosts.\(problem.facilities[index].name)"
    }
}


