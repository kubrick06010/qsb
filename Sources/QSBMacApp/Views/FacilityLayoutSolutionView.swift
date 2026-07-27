import Foundation
import QSBCore
import SwiftUI

struct FacilityLayoutPresentation {
    let document: FacilitiesSolutionDocument
    let problem: FacilityLayoutProblem

    var solution: FacilityLayoutSolution {
        guard case .layout(let solution) = document.solution else {
            preconditionFailure("FacilityLayoutPresentation requires a layout solution")
        }
        return solution
    }
}

private enum FacilityLayoutDetail: String, CaseIterable, Identifiable {
    case departments = "Departments"
    case moves = "Moves"
    case flows = "Flows"

    var id: String { rawValue }
}

struct FacilityLayoutSolutionView: View {
    let presentation: FacilityLayoutPresentation

    @State private var detail: FacilityLayoutDetail = .departments
    @State private var showGrid = true
    @State private var showTopFlows = false
    @State private var zoom = 1.0

    private var solution: FacilityLayoutSolution {
        presentation.solution
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summary
            Divider()
            controls
            Divider()

            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    if geometry.size.width >= 980 {
                        HStack(alignment: .top, spacing: 0) {
                            layoutCanvas
                                .frame(minWidth: 560, minHeight: 440)
                            Divider()
                            detailPanel
                                .frame(width: 380)
                        }
                        .frame(
                            minWidth: geometry.size.width,
                            minHeight: geometry.size.height,
                            alignment: .topLeading
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            layoutCanvas
                                .frame(minWidth: 560, minHeight: 440)
                            Divider()
                            detailPanel
                                .frame(minWidth: 560)
                        }
                        .frame(
                            minWidth: geometry.size.width,
                            minHeight: geometry.size.height,
                            alignment: .topLeading
                        )
                    }
                }
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.problem.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(sourceLabel) · \(presentation.document.backend.algorithm)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 16)

            metric(value: Self.number(solution.objectiveValue), label: "Load-distance")
            metric(value: "\(solution.placements.count)", label: "Departments")
            metric(value: "\(solution.moves.count)", label: "Moves")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Toggle("Grid", isOn: $showGrid)
                .toggleStyle(.checkbox)
            Toggle("Top flows", isOn: $showTopFlows)
                .toggleStyle(.checkbox)

            Divider()
                .frame(height: 18)

            Label("Scale", systemImage: "arrow.up.left.and.arrow.down.right")
                .font(.callout)
            Slider(value: $zoom, in: 0.65...1.6, step: 0.05)
                .frame(width: 140)
            Text("\(Int((zoom * 100).rounded()))%")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
            Button {
                zoom = 1
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .help("Reset layout scale")

            Spacer()

            Text(exactnessLabel)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    private var layoutCanvas: some View {
        FacilityLayoutCanvas(
            problem: presentation.problem,
            solution: solution,
            showGrid: showGrid,
            showTopFlows: showTopFlows,
            zoom: zoom
        )
        .padding(20)
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Details", selection: $detail) {
                ForEach(FacilityLayoutDetail.allCases) { section in
                    Text(section.rawValue)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(16)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    switch detail {
                    case .departments:
                        departmentRows
                    case .moves:
                        moveRows
                    case .flows:
                        flowRows
                    }
                }
            }

            if let search = solution.search {
                Divider()
                Label(
                    "\(search.evaluatedMoveCount) candidates evaluated · \(Self.number(search.improvement)) improvement",
                    systemImage: "arrow.triangle.swap"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(16)
            }
        }
    }

    private var departmentRows: some View {
        ForEach(solution.placements, id: \.departmentID) { placement in
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(FacilityLayoutPalette.color(for: placement.departmentID))
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(placement.departmentName)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        if placement.fixed {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .help("Fixed department")
                        }
                    }
                    Text(
                        "Centroid \(Self.number(placement.centroidRow)), \(Self.number(placement.centroidColumn))"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text("\(placement.cellCount) cells")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            Divider()
        }
    }

    @ViewBuilder
    private var moveRows: some View {
        if solution.moves.isEmpty {
            emptyDetail(
                title: "No improving swaps",
                message: "This result uses the initial arrangement or the search found no improving move."
            )
        } else {
            ForEach(Array(solution.moves.enumerated()), id: \.offset) { index, move in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(index + 1). \(move.firstDepartmentName) ↔ \(move.secondDepartmentName)")
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text("−\(Self.number(move.improvement))")
                            .font(.callout.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.green)
                    }
                    Text(
                        "\(Self.number(move.objectiveBefore)) → \(Self.number(move.objectiveAfter))"
                    )
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                Divider()
            }
        }
    }

    @ViewBuilder
    private var flowRows: some View {
        if sortedInteractions.isEmpty {
            emptyDetail(
                title: "No positive flows",
                message: "The solution contains no positive department-to-department interactions."
            )
        } else {
            ForEach(sortedInteractions, id: \.id) { flow in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(flow.interaction.fromDepartmentName) → \(flow.interaction.toDepartmentName)")
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        Text(
                            "Weight \(Self.number(flow.interaction.weight)) · Distance \(Self.number(flow.interaction.distance))"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text(Self.number(flow.interaction.weightedDistance))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                Divider()
            }
        }
    }

    private func emptyDetail(title: String, message: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: "rectangle.3.group")
        } description: {
            Text(message)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var sortedInteractions: [FacilityLayoutFlow] {
        solution.interactions
            .enumerated()
            .map { FacilityLayoutFlow(index: $0.offset, interaction: $0.element) }
            .sorted {
                if abs($0.interaction.weightedDistance - $1.interaction.weightedDistance) > 1e-8 {
                    return $0.interaction.weightedDistance > $1.interaction.weightedDistance
                }
                return $0.id < $1.id
            }
    }

    private var sourceLabel: String {
        switch solution.source {
        case "initialLayoutEvaluation": "Initial layout"
        case "pairwiseSwapLocalSearch": "Pairwise swap"
        default: solution.source
        }
    }

    private var exactnessLabel: String {
        switch presentation.document.backend.exactness {
        case .exact: "Exact"
        case .closedForm: "Closed form"
        case .fixtureScale: "Fixture scale"
        case .heuristic: "Heuristic"
        case .approximate: "Approximate"
        }
    }

    fileprivate static func number(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 1e-8 {
            return String(Int(rounded))
        }
        return String(format: "%.2f", value)
    }
}

private struct FacilityLayoutFlow: Identifiable {
    let index: Int
    let interaction: FacilityLayoutInteraction

    var id: String {
        "\(interaction.fromDepartmentID)-\(interaction.toDepartmentID)-\(index)"
    }
}

private struct FacilityLayoutCanvas: View {
    let problem: FacilityLayoutProblem
    let solution: FacilityLayoutSolution
    let showGrid: Bool
    let showTopFlows: Bool
    let zoom: Double

    private var cellSize: CGFloat {
        50 * zoom
    }

    private var canvasWidth: CGFloat {
        CGFloat(problem.columnCount) * cellSize
    }

    private var canvasHeight: CGFloat {
        CGFloat(problem.rowCount) * cellSize
    }

    private var placementByID: [Int: FacilityLayoutPlacement] {
        Dictionary(uniqueKeysWithValues: solution.placements.map { ($0.departmentID, $0) })
    }

    private var visibleFlows: [FacilityLayoutFlow] {
        guard showTopFlows else { return [] }
        return solution.interactions
            .enumerated()
            .map { FacilityLayoutFlow(index: $0.offset, interaction: $0.element) }
            .sorted { $0.interaction.weightedDistance > $1.interaction.weightedDistance }
            .prefix(18)
            .map(\.self)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(.background)

            ForEach(solution.placements, id: \.departmentID) { placement in
                ForEach(Array(placement.rectangles.enumerated()), id: \.offset) { _, rect in
                    departmentRectangle(placement, rect: rect)
                }
            }

            if showGrid {
                grid
            }

            ForEach(visibleFlows) { flow in
                flowLine(flow.interaction)
            }

            ForEach(solution.placements, id: \.departmentID) { placement in
                departmentLabel(placement)
            }
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .overlay {
            Rectangle()
                .stroke(.secondary.opacity(0.5), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var grid: some View {
        Canvas { context, _ in
            var path = Path()
            for column in 0...problem.columnCount {
                let x = CGFloat(column) * cellSize
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: canvasHeight))
            }
            for row in 0...problem.rowCount {
                let y = CGFloat(row) * cellSize
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: canvasWidth, y: y))
            }
            context.stroke(path, with: .color(.secondary.opacity(0.24)), lineWidth: 0.75)
        }
        .allowsHitTesting(false)
    }

    private func departmentRectangle(
        _ placement: FacilityLayoutPlacement,
        rect: FacilityLayoutRect
    ) -> some View {
        let frame = frame(for: rect)
        return RoundedRectangle(cornerRadius: 3)
            .fill(FacilityLayoutPalette.color(for: placement.departmentID).opacity(0.72))
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(
                        placement.fixed ? Color.primary.opacity(0.8) : Color.primary.opacity(0.34),
                        style: StrokeStyle(
                            lineWidth: placement.fixed ? 2 : 1,
                            dash: placement.fixed ? [5, 3] : []
                        )
                    )
            }
            .frame(width: frame.width, height: frame.height)
            .offset(x: frame.minX, y: frame.minY)
            .help(
                "\(placement.departmentName): rows \(rect.startRow)-\(rect.endRow), columns \(rect.startColumn)-\(rect.endColumn)"
            )
    }

    private func departmentLabel(_ placement: FacilityLayoutPlacement) -> some View {
        Text(placement.departmentName)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .padding(.horizontal, 4)
            .frame(width: max(36, cellSize * 1.6))
            .position(centroid(for: placement))
            .allowsHitTesting(false)
            .accessibilityLabel(placement.departmentName)
            .accessibilityValue(
                "\(placement.cellCount) cells, centroid row \(FacilityLayoutSolutionView.number(placement.centroidRow)), column \(FacilityLayoutSolutionView.number(placement.centroidColumn))\(placement.fixed ? ", fixed" : "")"
            )
    }

    private func flowLine(_ interaction: FacilityLayoutInteraction) -> some View {
        let start = placementByID[interaction.fromDepartmentID].map(centroid)
        let end = placementByID[interaction.toDepartmentID].map(centroid)

        return Canvas { context, _ in
            guard let start, let end else { return }
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            context.stroke(
                path,
                with: .color(.primary.opacity(0.42)),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
            )
            context.fill(
                Path(ellipseIn: CGRect(x: end.x - 3, y: end.y - 3, width: 6, height: 6)),
                with: .color(.primary.opacity(0.65))
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func frame(for rect: FacilityLayoutRect) -> CGRect {
        CGRect(
            x: CGFloat(rect.startColumn - 1) * cellSize,
            y: CGFloat(rect.startRow - 1) * cellSize,
            width: CGFloat(rect.endColumn - rect.startColumn + 1) * cellSize,
            height: CGFloat(rect.endRow - rect.startRow + 1) * cellSize
        )
    }

    private func centroid(for placement: FacilityLayoutPlacement) -> CGPoint {
        CGPoint(
            x: (placement.centroidColumn - 0.5) * cellSize,
            y: (placement.centroidRow - 0.5) * cellSize
        )
    }
}

private enum FacilityLayoutPalette {
    static func color(for id: Int) -> Color {
        let colors: [Color] = [
            .blue, .green, .orange, .pink,
            .teal, .purple, .yellow, .indigo,
            .mint, .red
        ]
        return colors[abs(id) % colors.count]
    }
}
