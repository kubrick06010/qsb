import Foundation

public enum LineBalancingValidator {
    public static func diagnostics(for problem: LineBalancingProblem) -> [ValidationDiagnostic] {
        var diagnostics: [ValidationDiagnostic] = []

        if problem.tasks.isEmpty {
            diagnostics.append(error(
                "facilities.lineBalancing.tasks.empty",
                "line balancing requires tasks",
                path: "tasks"
            ))
        }
        if problem.cycleTime <= 0 {
            diagnostics.append(error(
                "facilities.lineBalancing.cycleTime.positive",
                "line balancing requires a positive cycle time",
                path: "cycleTime"
            ))
        }
        if problem.tasks.count > 24 {
            diagnostics.append(warning(
                "facilities.lineBalancing.fixtureScale",
                "native educational line-balancing solver currently supports up to 24 tasks",
                path: "tasks"
            ))
        }

        let taskIDs = problem.tasks.map(\.id)
        if Set(taskIDs).count != taskIDs.count {
            diagnostics.append(error(
                "facilities.lineBalancing.tasks.duplicate",
                "line balancing task ids must be unique",
                path: "tasks"
            ))
        }

        let taskIDSet = Set(taskIDs)
        for task in problem.tasks {
            if task.time < 0 || (problem.cycleTime > 0 && task.time > problem.cycleTime) {
                diagnostics.append(error(
                    "facilities.lineBalancing.taskTime.bounds",
                    "task times must be nonnegative and no greater than cycle time",
                    path: "tasks.\(task.id).time"
                ))
            }
            for successorID in task.successorIDs {
                if successorID == task.id {
                    diagnostics.append(error(
                        "facilities.lineBalancing.successors.self",
                        "line balancing tasks cannot list themselves as successors",
                        path: "tasks.\(task.id).successorIDs"
                    ))
                } else if !taskIDSet.contains(successorID) {
                    diagnostics.append(error(
                        "facilities.lineBalancing.successors.missing",
                        "line balancing successor \(successorID) is missing",
                        path: "tasks.\(task.id).successorIDs"
                    ))
                }
            }
        }

        if diagnostics.contains(where: { $0.severity == .error }) == false,
           hasCycle(problem.tasks) {
            diagnostics.append(error(
                "facilities.lineBalancing.precedence.cycle",
                "line balancing precedence relationships must not contain cycles",
                path: "tasks"
            ))
        }

        guard diagnostics.contains(where: { $0.severity == .error }) == false else {
            return diagnostics
        }

        return diagnostics + [
            ValidationDiagnostic(
                severity: .info,
                code: "facilities.lineBalancing.valid",
                message: "Line balancing model is valid"
            )
        ]
    }

    public static func validate(_ problem: LineBalancingProblem) throws {
        if let diagnostic = diagnostics(for: problem).first(where: { $0.severity == .error }) {
            throw FacilitiesModelError.invalidModel(diagnostic.message)
        }
    }

    private static func hasCycle(_ tasks: [LineBalancingTask]) -> Bool {
        let successorsByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.successorIDs) })
        var visiting: Set<Int> = []
        var visited: Set<Int> = []

        func visit(_ taskID: Int) -> Bool {
            if visiting.contains(taskID) {
                return true
            }
            if visited.contains(taskID) {
                return false
            }

            visiting.insert(taskID)
            for successorID in successorsByID[taskID, default: []] where successorsByID[successorID] != nil {
                if visit(successorID) {
                    return true
                }
            }
            visiting.remove(taskID)
            visited.insert(taskID)
            return false
        }

        for task in tasks where visit(task.id) {
            return true
        }
        return false
    }

    private static func error(_ code: String, _ message: String, path: String?) -> ValidationDiagnostic {
        ValidationDiagnostic(severity: .error, code: code, message: message, path: path)
    }

    private static func warning(_ code: String, _ message: String, path: String?) -> ValidationDiagnostic {
        ValidationDiagnostic(severity: .warning, code: code, message: message, path: path)
    }
}


