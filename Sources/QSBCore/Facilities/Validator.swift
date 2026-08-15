import Foundation

public enum FacilityLayoutValidator {
    public static func diagnostics(for problem: FacilityLayoutProblem) -> [ValidationDiagnostic] {
        var diagnostics: [ValidationDiagnostic] = []

        if problem.departments.isEmpty {
            diagnostics.append(error(
                "facilities.layout.departments.empty",
                "facility layout departments must not be empty",
                path: "departments"
            ))
        }
        if problem.rowCount <= 0 || problem.columnCount <= 0 {
            diagnostics.append(error(
                "facilities.layout.grid.positive",
                "facility layout grid dimensions must be positive",
                path: "grid"
            ))
        }
        if problem.objective != "MIN" {
            diagnostics.append(error(
                "facilities.layout.objective.unsupported",
                "facility layout currently supports minimization only",
                path: "objective"
            ))
        }

        let departmentIDs = problem.departments.map(\.id)
        if Set(departmentIDs).count != departmentIDs.count {
            diagnostics.append(error(
                "facilities.layout.departments.duplicate",
                "facility layout department ids must be unique",
                path: "departments"
            ))
        }

        for department in problem.departments {
            if department.flowUnitCosts.count != problem.departments.count {
                diagnostics.append(error(
                    "facilities.layout.flow.dimension",
                    "facility layout flow/unit-cost rows must match department count",
                    path: "departments.\(department.name).flowUnitCosts"
                ))
            }
            for (index, value) in department.flowUnitCosts.enumerated() where (value ?? 0) < 0 || value?.isFinite == false {
                diagnostics.append(error(
                    "facilities.layout.flow.nonnegative",
                    "facility layout flow/unit-cost values must be finite and nonnegative",
                    path: flowPath(problem: problem, department: department, index: index)
                ))
            }
            if department.initialLayout.isEmpty {
                diagnostics.append(error(
                    "facilities.layout.initial.empty",
                    "facility layout departments must have initial cell locations",
                    path: "departments.\(department.name).initialLayout"
                ))
            }
            for rect in department.initialLayout {
                if rect.startRow <= 0 || rect.startColumn <= 0 ||
                    rect.endRow > problem.rowCount || rect.endColumn > problem.columnCount ||
                    rect.startRow > rect.endRow || rect.startColumn > rect.endColumn {
                    diagnostics.append(error(
                        "facilities.layout.initial.bounds",
                        "facility layout cell locations must be inside the layout grid",
                        path: "departments.\(department.name).initialLayout"
                    ))
                }
            }
        }

        var occupied: [FacilityLayoutCell: FacilityLayoutDepartment] = [:]
        for department in problem.departments {
            for cell in layoutCells(in: department.initialLayout).sorted() {
                guard cell.row >= 1, cell.row <= problem.rowCount, cell.column >= 1, cell.column <= problem.columnCount else {
                    continue
                }
                if let owner = occupied[cell], owner.id != department.id {
                    if owner.fixed || department.fixed {
                        diagnostics.append(warning(
                            "facilities.layout.initial.fixedOverlap",
                            "facility layout cell (\(cell.row),\(cell.column)) is shared by fixed area \(owner.fixed ? owner.name : department.name)",
                            path: "departments.\(department.name).initialLayout"
                        ))
                    } else {
                        diagnostics.append(error(
                            "facilities.layout.initial.overlap",
                            "facility layout cell (\(cell.row),\(cell.column)) is assigned to both \(owner.name) and \(department.name)",
                            path: "departments.\(department.name).initialLayout"
                        ))
                    }
                } else {
                    occupied[cell] = department
                }
            }
        }

        let gridCellCount = max(0, problem.rowCount * problem.columnCount)
        if gridCellCount > 0, occupied.count != gridCellCount {
            diagnostics.append(warning(
                "facilities.layout.initial.coverage",
                "facility layout initial cells cover \(occupied.count) of \(gridCellCount) grid cells",
                path: "departments.initialLayout"
            ))
        }

        guard diagnostics.contains(where: { $0.severity == .error }) == false else {
            return diagnostics
        }

        return diagnostics + [
            ValidationDiagnostic(
                severity: .info,
                code: "facilities.layout.valid",
                message: "Facility layout model is valid"
            )
        ]
    }

    public static func validate(_ problem: FacilityLayoutProblem) throws {
        if let diagnostic = diagnostics(for: problem).first(where: { $0.severity == .error }) {
            throw FacilitiesModelError.invalidModel(diagnostic.message)
        }
    }

    private static func error(_ code: String, _ message: String, path: String?) -> ValidationDiagnostic {
        ValidationDiagnostic(severity: .error, code: code, message: message, path: path)
    }

    private static func warning(_ code: String, _ message: String, path: String?) -> ValidationDiagnostic {
        ValidationDiagnostic(severity: .warning, code: code, message: message, path: path)
    }

    private static func flowPath(
        problem: FacilityLayoutProblem,
        department: FacilityLayoutDepartment,
        index: Int
    ) -> String {
        guard index < problem.departments.count else {
            return "departments.\(department.name).flowUnitCosts.\(index)"
        }
        return "departments.\(department.name).flowUnitCosts.\(problem.departments[index].name)"
    }
}


