import Foundation

public enum LineBalancingSolver {
    private struct SearchNode {
        let previousMask: Int
        let stationMask: Int
    }

    public static func solve(_ problem: LineBalancingProblem) throws -> LineBalancingSolution {
        try validate(problem)

        let tasks = problem.tasks.sorted { $0.id < $1.id }
        let taskCount = tasks.count
        let fullMask = (1 << taskCount) - 1
        let totalTaskTime = tasks.reduce(0) { $0 + $1.time }
        let predecessors = predecessorMasks(for: tasks)
        var workloadCache: [Int: Int] = [0: 0]
        var parent: [Int: SearchNode] = [:]
        var distance: [Int: Int] = [0: 0]
        var queue = [0]
        var queueIndex = 0

        while queueIndex < queue.count, distance[fullMask] == nil {
            let assignedMask = queue[queueIndex]
            queueIndex += 1

            let stationMasks = feasibleStationMasks(
                assignedMask: assignedMask,
                fullMask: fullMask,
                tasks: tasks,
                predecessors: predecessors,
                cycleTime: problem.cycleTime,
                workloadCache: &workloadCache
            )

            for stationMask in stationMasks {
                let nextMask = assignedMask | stationMask
                guard distance[nextMask] == nil else {
                    continue
                }
                distance[nextMask] = (distance[assignedMask] ?? 0) + 1
                parent[nextMask] = SearchNode(previousMask: assignedMask, stationMask: stationMask)
                queue.append(nextMask)
            }
        }

        guard let stationCount = distance[fullMask] else {
            throw FacilitiesModelError.invalidModel("line balancing problem has no feasible station assignment")
        }

        var masks: [Int] = []
        var currentMask = fullMask
        while currentMask != 0 {
            guard let node = parent[currentMask] else {
                throw FacilitiesModelError.invalidModel("line balancing solution path could not be reconstructed")
            }
            masks.append(node.stationMask)
            currentMask = node.previousMask
        }
        masks.reverse()

        let stations = masks.enumerated().map { offset, mask in
            let stationTasks = tasks.enumerated()
                .filter { mask & (1 << $0.offset) != 0 }
                .map(\.element)
            let workload = stationTasks.reduce(0) { $0 + $1.time }
            return LineBalancingStation(
                index: offset + 1,
                taskIDs: stationTasks.map(\.id),
                taskNames: stationTasks.map(\.name),
                workload: workload,
                idleTime: problem.cycleTime - workload
            )
        }

        let efficiency = Double(totalTaskTime) / Double(stationCount * problem.cycleTime)
        return LineBalancingSolution(
            stationCount: stationCount,
            totalTaskTime: totalTaskTime,
            cycleTime: problem.cycleTime,
            efficiency: efficiency,
            balanceDelay: 1 - efficiency,
            stations: stations
        )
    }

    private static func validate(_ problem: LineBalancingProblem) throws {
        try LineBalancingValidator.validate(problem)
        guard problem.tasks.count <= 24 else {
            throw FacilitiesModelError.invalidModel("exact line balancing solver currently supports up to 24 tasks")
        }
    }

    private static func predecessorMasks(for tasks: [LineBalancingTask]) -> [Int] {
        let indexByID = Dictionary(uniqueKeysWithValues: tasks.enumerated().map { ($0.element.id, $0.offset) })
        var predecessors = Array(repeating: 0, count: tasks.count)
        for task in tasks {
            guard let predecessorIndex = indexByID[task.id] else { continue }
            for successorID in task.successorIDs {
                guard let successorIndex = indexByID[successorID] else { continue }
                predecessors[successorIndex] |= 1 << predecessorIndex
            }
        }
        return predecessors
    }

    private static func feasibleStationMasks(
        assignedMask: Int,
        fullMask: Int,
        tasks: [LineBalancingTask],
        predecessors: [Int],
        cycleTime: Int,
        workloadCache: inout [Int: Int]
    ) -> [Int] {
        let remainingTaskIndices = tasks.indices.filter { assignedMask & (1 << $0) == 0 }
        var candidates: [Int] = []

        func search(_ itemIndex: Int, _ mask: Int, _ workload: Int) {
            guard workload <= cycleTime else {
                return
            }
            if itemIndex == remainingTaskIndices.count {
                guard mask != 0 else { return }
                for taskIndex in tasks.indices where mask & (1 << taskIndex) != 0 {
                    guard predecessors[taskIndex] & ~(assignedMask | mask) == 0 else {
                        return
                    }
                }
                candidates.append(mask)
                workloadCache[mask] = workload
                return
            }

            let taskIndex = remainingTaskIndices[itemIndex]
            search(itemIndex + 1, mask, workload)
            search(itemIndex + 1, mask | (1 << taskIndex), workload + tasks[taskIndex].time)
        }

        search(0, 0, 0)

        let uniqueCandidates = Array(Set(candidates))
        var maximal: [Int] = []
        for candidate in uniqueCandidates.sorted(by: { left, right in
            let leftWorkload = workloadCache[left] ?? 0
            let rightWorkload = workloadCache[right] ?? 0
            if leftWorkload != rightWorkload {
                return leftWorkload > rightWorkload
            }
            return left > right
        }) {
            if !maximal.contains(where: { (candidate | $0) == $0 }) {
                maximal.append(candidate)
            }
        }
        return maximal
    }
}


