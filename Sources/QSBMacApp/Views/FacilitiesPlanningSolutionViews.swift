import Charts
import QSBCore
import SwiftUI

struct FacilityLocationPresentation {
    let document: FacilitiesSolutionDocument
    let problem: FacilityLocationProblem

    var solution: FacilityLocationSolution {
        guard case .location(let solution) = document.solution else {
            preconditionFailure("FacilityLocationPresentation requires a location solution")
        }
        return solution
    }
}

struct LineBalancingPresentation {
    let document: FacilitiesSolutionDocument
    let problem: LineBalancingProblem

    var solution: LineBalancingSolution {
        guard case .lineBalancing(let solution) = document.solution else {
            preconditionFailure("LineBalancingPresentation requires a line-balancing solution")
        }
        return solution
    }
}

struct FacilityLocationSolutionView: View {
    let presentation: FacilityLocationPresentation

    private var solution: FacilityLocationSolution { presentation.solution }

    private var links: [LocationLink] {
        solution.placements.flatMap { placement in
            placement.interactions.compactMap { interaction in
                guard let facility = presentation.problem.existingFacilities.first(where: { $0.id == interaction.existingFacilityID }),
                      let x = facility.x, let y = facility.y else { return nil }
                return LocationLink(
                    id: "\(placement.facilityID)-\(facility.id)",
                    existingName: facility.name,
                    existingX: x,
                    existingY: y,
                    newName: placement.facilityName,
                    newX: placement.x,
                    newY: placement.y,
                    weight: interaction.weight,
                    distance: interaction.distance,
                    weightedDistance: interaction.weightedDistance
                )
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeaderView(
                    title: presentation.problem.title,
                    subtitle: "Facility location · \(presentation.document.backend.algorithmDisplayName)"
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], alignment: .leading, spacing: 12) {
                    metric("Objective", number(solution.objectiveValue))
                    metric("Distance", distanceLabel)
                    metric("New facilities", "\(solution.placements.count)")
                    metric("Exactness", presentation.document.backend.exactnessDisplayName)
                }

                locationChart
                placements
                interactions
                runContext
            }
            .padding(20)
            .frame(maxWidth: 1100, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var locationChart: some View {
        GroupBox("Location map") {
            Chart {
                ForEach(links) { link in
                    LineMark(
                        x: .value("X", link.existingX),
                        y: .value("Y", link.existingY),
                        series: .value("Interaction", link.id)
                    )
                    .foregroundStyle(Color.secondary.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: max(1, min(5, link.weight))))
                    LineMark(
                        x: .value("X", link.newX),
                        y: .value("Y", link.newY),
                        series: .value("Interaction", link.id)
                    )
                    .foregroundStyle(Color.secondary.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: max(1, min(5, link.weight))))
                }

                ForEach(presentation.problem.existingFacilities, id: \.id) { facility in
                    if let x = facility.x, let y = facility.y {
                        PointMark(x: .value("X", x), y: .value("Y", y))
                            .foregroundStyle(Color.blue)
                            .symbolSize(75)
                            .annotation(position: .top) { Text(facility.name).font(.caption) }
                            .accessibilityLabel("Existing facility \(facility.name)")
                            .accessibilityValue("x \(number(x)), y \(number(y))")
                    }
                }

                ForEach(solution.placements, id: \.facilityID) { placement in
                    PointMark(x: .value("X", placement.x), y: .value("Y", placement.y))
                        .foregroundStyle(Color.orange)
                        .symbol(.diamond)
                        .symbolSize(125)
                        .annotation(position: .bottom) { Text(placement.facilityName).font(.caption.weight(.semibold)) }
                        .accessibilityLabel("New facility \(placement.facilityName)")
                        .accessibilityValue("x \(number(placement.x)), y \(number(placement.y))")
                }
            }
            .chartXAxisLabel("X")
            .chartYAxisLabel("Y")
            .frame(height: 330)
            .padding(.vertical, 8)
        }
    }

    private var placements: some View {
        GroupBox("Recommended placements") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(solution.placements, id: \.facilityID) { placement in
                    LabeledContent(placement.facilityName) {
                        Text("(\(number(placement.x)), \(number(placement.y))) · weighted distance \(number(placement.weightedDistance))")
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(4)
        }
    }

    private var interactions: some View {
        GroupBox("Interaction costs") {
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 8) {
                    GridRow { heading("Existing"); heading("New"); heading("Weight"); heading("Distance"); heading("Weighted") }
                    Divider().gridCellUnsizedAxes(.horizontal)
                    ForEach(links) { link in
                        GridRow {
                            Text(link.existingName).fontWeight(.semibold)
                            Text(link.newName)
                            value(link.weight)
                            value(link.distance)
                            value(link.weightedDistance)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(4)
            }
        }
    }

    private var runContext: some View {
        GroupBox("Run context") {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Backend", value: presentation.document.backend.backendDisplayName)
                LabeledContent("Algorithm", value: presentation.document.backend.algorithmDisplayName)
                LabeledContent("Exactness", value: presentation.document.backend.exactnessDisplayName)
                ForEach(Array(presentation.document.backend.notes.enumerated()), id: \.offset) { _, note in
                    Label(note, systemImage: "info.circle").foregroundStyle(.secondary)
                }
            }
            .padding(4)
        }
    }

    private var distanceLabel: String {
        switch solution.distanceMeasure {
        case .rectilinear: "Rectilinear"
        case .squaredEuclidean: "Squared Euclidean"
        case .euclidean: "Euclidean"
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    private func heading(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
    }

    private func value(_ number: Double) -> some View {
        Text(self.number(number)).monospacedDigit().frame(minWidth: 70, alignment: .trailing)
    }

    private func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...4)))
    }
}

struct LineBalancingSolutionView: View {
    let presentation: LineBalancingPresentation

    private var solution: LineBalancingSolution { presentation.solution }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeaderView(
                    title: presentation.problem.title,
                    subtitle: "Line balancing · \(presentation.document.backend.algorithmDisplayName)"
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], alignment: .leading, spacing: 12) {
                    metric("Stations", "\(solution.stationCount)")
                    metric("Cycle time", "\(solution.cycleTime) \(presentation.problem.timeUnit)")
                    metric("Efficiency", percent(solution.efficiency))
                    metric("Balance delay", percent(solution.balanceDelay))
                    metric("Exactness", presentation.document.backend.exactnessDisplayName)
                }

                workloadChart
                stationDetails
                precedence
                runContext
            }
            .padding(20)
            .frame(maxWidth: 1100, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var workloadChart: some View {
        GroupBox("Station load") {
            Chart {
                ForEach(solution.stations, id: \.index) { station in
                    BarMark(
                        xStart: .value("Time", 0),
                        xEnd: .value("Time", station.workload),
                        y: .value("Station", "Station \(station.index)")
                    )
                    .foregroundStyle(by: .value("Capacity", "Workload"))
                    .accessibilityLabel("Station \(station.index) workload")
                    .accessibilityValue("\(station.workload) \(presentation.problem.timeUnit)")

                    BarMark(
                        xStart: .value("Time", station.workload),
                        xEnd: .value("Time", solution.cycleTime),
                        y: .value("Station", "Station \(station.index)")
                    )
                    .foregroundStyle(by: .value("Capacity", "Idle"))
                    .accessibilityLabel("Station \(station.index) idle time")
                    .accessibilityValue("\(station.idleTime) \(presentation.problem.timeUnit)")
                }
            }
            .chartXAxisLabel(presentation.problem.timeUnit.capitalized)
            .frame(height: max(210, CGFloat(solution.stations.count) * 52))
            .padding(.vertical, 8)
        }
    }

    private var stationDetails: some View {
        GroupBox("Station assignments") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(solution.stations.enumerated()), id: \.element.index) { offset, station in
                    if offset > 0 { Divider() }
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        Text("Station \(station.index)").font(.headline).frame(width: 92, alignment: .leading)
                        Text(station.taskNames.joined(separator: ", ")).frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(station.workload) / \(solution.cycleTime)").monospacedDigit()
                    }
                    .padding(.vertical, 9)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Station \(station.index), tasks \(station.taskNames.joined(separator: ", "))")
                    .accessibilityValue("Workload \(station.workload), idle \(station.idleTime) \(presentation.problem.timeUnit)")
                }
            }
            .padding(4)
        }
    }

    private var precedence: some View {
        GroupBox("Task precedence") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(presentation.problem.tasks, id: \.id) { task in
                    let successors = task.successorIDs.compactMap { id in presentation.problem.tasks.first { $0.id == id }?.name }
                    LabeledContent("\(task.name) · \(task.time) \(presentation.problem.timeUnit)", value: successors.isEmpty ? "Final task" : "Before \(successors.joined(separator: ", "))")
                        .accessibilityElement(children: .combine)
                }
            }
            .padding(4)
        }
    }

    private var runContext: some View {
        GroupBox("Run context") {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Backend", value: presentation.document.backend.backendDisplayName)
                LabeledContent("Algorithm", value: presentation.document.backend.algorithmDisplayName)
                LabeledContent("Exactness", value: presentation.document.backend.exactnessDisplayName)
                ForEach(Array(presentation.document.backend.notes.enumerated()), id: \.offset) { _, note in
                    Label(note, systemImage: "info.circle").foregroundStyle(.secondary)
                }
            }
            .padding(4)
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0...1)))
    }
}

private struct LocationLink: Identifiable {
    let id: String
    let existingName: String
    let existingX: Double
    let existingY: Double
    let newName: String
    let newX: Double
    let newY: Double
    let weight: Double
    let distance: Double
    let weightedDistance: Double
}
