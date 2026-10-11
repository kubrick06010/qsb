import Foundation
import QSBCore

enum ProjectSchedulingDraftError: Error, Equatable, CustomStringConvertible {
    case emptyField(path: String, label: String)
    case invalidNumber(path: String, label: String, value: String)

    var path: String {
        switch self {
        case .emptyField(let path, _), .invalidNumber(let path, _, _): path
        }
    }

    var description: String {
        switch self {
        case .emptyField(_, let label):
            "Enter \(label)."
        case .invalidNumber(_, let label, let value):
            "Enter a finite number for \(label) (received ‘\(value)’)."
        }
    }
}

struct ProjectActivityDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var predecessors: String
    var normalTime: String
    var crashTime: String
    var normalCost: String
    var crashCost: String
    var optimisticTime: String
    var mostLikelyTime: String
    var pessimisticTime: String

    init(
        id: UUID = UUID(),
        name: String,
        predecessors: String = "",
        normalTime: String = "1",
        crashTime: String = "1",
        normalCost: String = "0",
        crashCost: String = "0",
        optimisticTime: String = "1",
        mostLikelyTime: String = "1",
        pessimisticTime: String = "1"
    ) {
        self.id = id
        self.name = name
        self.predecessors = predecessors
        self.normalTime = normalTime
        self.crashTime = crashTime
        self.normalCost = normalCost
        self.crashCost = crashCost
        self.optimisticTime = optimisticTime
        self.mostLikelyTime = mostLikelyTime
        self.pessimisticTime = pessimisticTime
    }
}

struct ProjectSchedulingDraft: Equatable, Sendable {
    var kind: ProjectSchedulingProblemKind
    var title: String
    var timeUnit: String
    var activities: [ProjectActivityDraft]
    private var hasVisitedCPM: Bool
    private var hasVisitedPERT: Bool

    private init(
        kind: ProjectSchedulingProblemKind,
        title: String,
        timeUnit: String,
        activities: [ProjectActivityDraft]
    ) {
        self.kind = kind
        self.title = title
        self.timeUnit = timeUnit
        self.activities = activities
        hasVisitedCPM = kind == .deterministicCPM
        hasVisitedPERT = kind == .probabilisticPERT
    }

    static func blank(_ kind: ProjectSchedulingProblemKind = .deterministicCPM) -> Self {
        Self(
            kind: kind,
            title: kind == .deterministicCPM ? "New CPM Project" : "New PERT Project",
            timeUnit: "day",
            activities: [ProjectActivityDraft(name: "Activity 1")]
        )
    }

    init(_ envelope: ProjectSchedulingModelEnvelope) {
        hasVisitedCPM = envelope.kind == .deterministicCPM
        hasVisitedPERT = envelope.kind == .probabilisticPERT
        switch envelope {
        case .cpm(let project):
            kind = .deterministicCPM
            title = project.title
            timeUnit = project.timeUnit
            activities = project.activities.map { activity in
                ProjectActivityDraft(
                    name: activity.name,
                    predecessors: activity.predecessors.joined(separator: ", "),
                    normalTime: String(activity.normalTime),
                    crashTime: String(activity.crashTime),
                    normalCost: String(activity.normalCost),
                    crashCost: String(activity.crashCost),
                    optimisticTime: String(activity.normalTime),
                    mostLikelyTime: String(activity.normalTime),
                    pessimisticTime: String(activity.normalTime)
                )
            }
        case .pert(let project):
            kind = .probabilisticPERT
            title = project.title
            timeUnit = project.timeUnit
            activities = project.activities.map { activity in
                ProjectActivityDraft(
                    name: activity.name,
                    predecessors: activity.predecessors.joined(separator: ", "),
                    normalTime: String(activity.expectedTime),
                    crashTime: String(activity.expectedTime),
                    optimisticTime: String(activity.optimisticTime),
                    mostLikelyTime: String(activity.mostLikelyTime),
                    pessimisticTime: String(activity.pessimisticTime)
                )
            }
        }
    }

    func makeModel() throws -> ProjectSchedulingModelEnvelope {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectSchedulingDraftError.emptyField(path: "model.title", label: "a project title")
        }
        guard !timeUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectSchedulingDraftError.emptyField(path: "model.timeUnit", label: "a time unit")
        }

        switch kind {
        case .deterministicCPM:
            return .cpm(CPMProject(
                title: title,
                timeUnit: timeUnit,
                activities: try activities.enumerated().map { index, activity in
                    try requireName(activity, index: index)
                    return CPMActivity(
                        name: activity.name.trimmingCharacters(in: .whitespacesAndNewlines),
                        predecessors: predecessorNames(activity.predecessors),
                        normalTime: try number(activity.normalTime, label: "normal time", path: path(index, "normalTime")),
                        crashTime: try number(activity.crashTime, label: "crash time", path: path(index, "crashTime")),
                        normalCost: try number(activity.normalCost, label: "normal cost", path: path(index, "normalCost")),
                        crashCost: try number(activity.crashCost, label: "crash cost", path: path(index, "crashCost"))
                    )
                }
            ))
        case .probabilisticPERT:
            return .pert(PERTProject(
                title: title,
                timeUnit: timeUnit,
                activities: try activities.enumerated().map { index, activity in
                    try requireName(activity, index: index)
                    return PERTActivity(
                        name: activity.name.trimmingCharacters(in: .whitespacesAndNewlines),
                        predecessors: predecessorNames(activity.predecessors),
                        optimisticTime: try number(activity.optimisticTime, label: "optimistic time", path: path(index, "optimisticTime")),
                        mostLikelyTime: try number(activity.mostLikelyTime, label: "most likely time", path: path(index, "mostLikelyTime")),
                        pessimisticTime: try number(activity.pessimisticTime, label: "pessimistic time", path: path(index, "pessimisticTime"))
                    )
                }
            ))
        }
    }

    func draftDiagnostics() -> [ValidationDiagnostic] {
        do {
            return ProjectSchedulingValidator.diagnostics(for: try makeModel())
        } catch let error as ProjectSchedulingDraftError {
            return [ValidationDiagnostic(
                severity: .error,
                code: "project.draft.\(error.path.replacingOccurrences(of: ".", with: "_"))",
                message: error.description,
                path: error.path
            )]
        } catch {
            return [ValidationDiagnostic(severity: .error, code: "project.draft.invalid", message: error.localizedDescription)]
        }
    }

    mutating func changeKind(to newKind: ProjectSchedulingProblemKind) {
        guard kind != newKind else { return }
        // Seed the other formulation once; subsequent switches preserve both sets
        // of editable strings, including incomplete input and CPM crash costs.
        if newKind == .probabilisticPERT && !hasVisitedPERT {
            for index in activities.indices {
                let normal = activities[index].normalTime
                activities[index].optimisticTime = normal
                activities[index].mostLikelyTime = normal
                activities[index].pessimisticTime = normal
            }
            hasVisitedPERT = true
        } else if newKind == .deterministicCPM && !hasVisitedCPM {
            for index in activities.indices {
                let estimate = Self.cpmSeedTime(activities[index])
                activities[index].normalTime = estimate
                activities[index].crashTime = estimate
            }
            hasVisitedCPM = true
        }
        kind = newKind
    }

    @discardableResult
    mutating func addActivity() -> UUID {
        let activity = ProjectActivityDraft(name: uniqueActivityName())
        activities.append(activity)
        return activity.id
    }

    mutating func removeActivity(id: UUID) {
        guard activities.count > 1 else { return }
        activities.removeAll { $0.id == id }
    }

    func tabularText() -> String {
        let header: [String]
        let rows: [[String]]
        switch kind {
        case .deterministicCPM:
            header = ["Activity", "Predecessors", "Normal Time", "Crash Time", "Normal Cost", "Crash Cost"]
            rows = activities.map { [$0.name, $0.predecessors, $0.normalTime, $0.crashTime, $0.normalCost, $0.crashCost] }
        case .probabilisticPERT:
            header = ["Activity", "Predecessors", "Optimistic Time", "Most Likely Time", "Pessimistic Time"]
            rows = activities.map { [$0.name, $0.predecessors, $0.optimisticTime, $0.mostLikelyTime, $0.pessimisticTime] }
        }
        return ([header] + rows).map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }

    mutating func replaceActivities(withTabularText text: String) throws {
        var rows = try SpreadsheetTable(text: text).rows
        let expected = kind == .deterministicCPM ? 6 : 5
        if rows.first?.map({ $0.lowercased() }) == tableHeaders.map({ $0.lowercased() }) { rows.removeFirst() }
        guard !rows.isEmpty else { throw SpreadsheetTransferError.emptyClipboard }

        let existing = Dictionary(grouping: activities, by: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) })
        let incoming = Dictionary(grouping: rows, by: { ($0.first ?? "").trimmingCharacters(in: .whitespacesAndNewlines) })
        var replacement: [ProjectActivityDraft] = []
        for (index, values) in rows.enumerated() {
            let row = index + 1
            guard values.count == expected else {
                throw SpreadsheetTransferError.inconsistentColumns(expected: expected, actual: values.count, row: row)
            }
            guard !values[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SpreadsheetTransferError.invalidValue(values[0], column: "Activity", row: row)
            }
            for column in 2..<expected {
                try SpreadsheetTable.requireFinite(values[column], column: tableHeaders[column], row: row)
            }
            let name = values[0].trimmingCharacters(in: .whitespacesAndNewlines)
            // Only an unambiguous name can carry identity and the hidden formulation.
            let previous = existing[name]?.count == 1 && incoming[name]?.count == 1 ? existing[name]?.first : nil
            var activity = previous ?? ProjectActivityDraft(name: values[0])
            activity.name = values[0]
            activity.predecessors = values[1]
            if kind == .deterministicCPM {
                activity.normalTime = values[2]
                activity.crashTime = values[3]
                activity.normalCost = values[4]
                activity.crashCost = values[5]
                if previous == nil {
                    activity.optimisticTime = values[2]
                    activity.mostLikelyTime = values[2]
                    activity.pessimisticTime = values[2]
                }
            } else {
                activity.optimisticTime = values[2]
                activity.mostLikelyTime = values[3]
                activity.pessimisticTime = values[4]
                if previous == nil {
                    let estimate = Self.cpmSeedTime(activity)
                    activity.normalTime = estimate
                    activity.crashTime = estimate
                }
            }
            replacement.append(activity)
        }
        activities = replacement
    }

    private static func cpmSeedTime(_ activity: ProjectActivityDraft) -> String {
        guard let optimistic = Double(activity.optimisticTime), optimistic.isFinite,
              let likely = Double(activity.mostLikelyTime), likely.isFinite,
              let pessimistic = Double(activity.pessimisticTime), pessimistic.isFinite else {
            return activity.mostLikelyTime
        }
        return String(PERTActivity(name: activity.name, predecessors: [],
            optimisticTime: optimistic, mostLikelyTime: likely, pessimisticTime: pessimistic).expectedTime)
    }

    private var tableHeaders: [String] {
        kind == .deterministicCPM
            ? ["Activity", "Predecessors", "Normal Time", "Crash Time", "Normal Cost", "Crash Cost"]
            : ["Activity", "Predecessors", "Optimistic Time", "Most Likely Time", "Pessimistic Time"]
    }

    private func uniqueActivityName() -> String {
        let existing = Set(activities.map { $0.name })
        var index = activities.count + 1
        while existing.contains("Activity \(index)") { index += 1 }
        return "Activity \(index)"
    }

    private func requireName(_ activity: ProjectActivityDraft, index: Int) throws {
        guard !activity.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectSchedulingDraftError.emptyField(path: path(index, "name"), label: "an activity name")
        }
    }

    private func predecessorNames(_ text: String) -> [String] {
        text.split(separator: ",", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func number(_ text: String, label: String, path: String) throws -> Double {
        guard let value = Double(text), value.isFinite else {
            throw ProjectSchedulingDraftError.invalidNumber(path: path, label: label, value: text)
        }
        return value
    }

    private func path(_ index: Int, _ field: String) -> String {
        "model.activities.\(index).\(field)"
    }
}
