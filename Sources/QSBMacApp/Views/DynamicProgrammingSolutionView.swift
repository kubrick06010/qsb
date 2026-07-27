import Charts
import Foundation
import QSBCore
import SwiftUI

struct DynamicProgrammingSolutionView: View {
    let document: DynamicProgrammingSolutionDocument

    private var presentation: DynamicProgrammingPresentation {
        DynamicProgrammingPresentation(document: document)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summary
            Divider()

            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 24) {
                        resultAnalysis
                        policyTrace
                        runContext
                    }
                    .padding(18)
                    .frame(
                        width: max(presentation.minimumContentWidth, geometry.size.width),
                        alignment: .topLeading
                    )
                    .frame(minHeight: geometry.size.height, alignment: .topLeading)
                }
            }
        }
    }

    private var summary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 24) {
                summaryTitle
                Spacer(minLength: 16)
                summaryMetrics
            }

            VStack(alignment: .leading, spacing: 10) {
                summaryTitle
                summaryMetrics
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var summaryTitle: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(document.title)
                .font(.headline)
                .lineLimit(1)
            Text("\(presentation.kindLabel) - \(document.backend.algorithm)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var summaryMetrics: some View {
        HStack(spacing: 24) {
            ForEach(presentation.summaryMetrics) { item in
                VStack(alignment: .trailing, spacing: 1) {
                    Text(item.value)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                    Text(item.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder
    private var resultAnalysis: some View {
        switch document.solution {
        case .boundedKnapsack(let solution, _):
            knapsackAnalysis(solution)
        case .stagecoach(let solution, let trace):
            stagecoachAnalysis(solution, trace: trace)
        case .productionInventory(let solution, _):
            productionInventoryAnalysis(solution)
        }
    }

    private func knapsackAnalysis(_ solution: KnapsackSolution) -> some View {
        section(
            title: "Optimal selection",
            subtitle: "Selected quantities, capacity use, and return contribution."
        ) {
            if solution.selections.isEmpty {
                ContentUnavailableView(
                    "No selected items",
                    systemImage: "shippingbox",
                    description: Text("The optimal policy leaves the knapsack empty.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                Chart(Array(solution.selections.enumerated()), id: \.offset) { _, selection in
                    BarMark(
                        x: .value("Return", selection.returnValue),
                        y: .value("Item", selection.item)
                    )
                    .foregroundStyle(Color.blue)
                    .accessibilityLabel(selection.item)
                    .accessibilityValue(
                        "Quantity \(selection.quantity), return \(DynamicProgrammingPresentation.number(selection.returnValue))"
                    )
                }
                .chartXAxis {
                    AxisMarks {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .frame(height: max(150, CGFloat(solution.selections.count) * 52))

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Text("Item")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Quantity")
                            .frame(width: 90, alignment: .trailing)
                        Text("Capacity")
                            .frame(width: 100, alignment: .trailing)
                        Text("Return")
                            .frame(width: 100, alignment: .trailing)
                    }
                    .tableHeaderStyle()

                    ForEach(Array(solution.selections.enumerated()), id: \.offset) { _, selection in
                        HStack(spacing: 12) {
                            Text(selection.item)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(selection.quantity)")
                                .frame(width: 90, alignment: .trailing)
                            Text("\(selection.capacityUsed)")
                                .frame(width: 100, alignment: .trailing)
                            Text(DynamicProgrammingPresentation.number(selection.returnValue))
                                .frame(width: 100, alignment: .trailing)
                        }
                        .tableRowStyle()
                    }
                }
            }
        }
    }

    private func stagecoachAnalysis(
        _ solution: StagecoachSolution,
        trace: [DynamicProgrammingTraceStep]
    ) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            section(
                title: "Optimal route",
                subtitle: "\(solution.source) to \(solution.sink) at minimum total cost."
            ) {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(Array(solution.path.enumerated()), id: \.offset) { index, node in
                            Text(node)
                                .font(.body.weight(.medium))
                                .lineLimit(1)
                                .accessibilityLabel("Route stop \(index + 1), \(node)")

                            if index < solution.path.count - 1 {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            section(
                title: "Arc costs",
                subtitle: "Local cost contributed by each transition in the selected route."
            ) {
                Chart(Array(trace.enumerated()), id: \.offset) { index, step in
                    BarMark(
                        x: .value("Arc", "\(index + 1)"),
                        y: .value("Cost", step.value)
                    )
                    .foregroundStyle(Color.orange)
                    .accessibilityLabel("\(step.state) to \(step.nextState ?? "")")
                    .accessibilityValue(DynamicProgrammingPresentation.number(step.value))
                }
                .chartYAxis {
                    AxisMarks(position: .leading) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .frame(height: 220)
            }
        }
    }

    private func productionInventoryAnalysis(
        _ solution: ProductionInventorySolution
    ) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            section(
                title: "Production policy",
                subtitle: "Demand, production, and ending inventory by stage."
            ) {
                Chart {
                    ForEach(Array(solution.decisions.enumerated()), id: \.offset) { _, decision in
                        BarMark(
                            x: .value("Period", decision.period),
                            y: .value("Quantity", decision.demand)
                        )
                        .foregroundStyle(by: .value("Series", "Demand"))
                        .position(by: .value("Series", "Demand"))

                        BarMark(
                            x: .value("Period", decision.period),
                            y: .value("Quantity", decision.productionQuantity)
                        )
                        .foregroundStyle(by: .value("Series", "Production"))
                        .position(by: .value("Series", "Production"))

                        LineMark(
                            x: .value("Period", decision.period),
                            y: .value("Ending inventory", decision.endingInventory),
                            series: .value("Series", "Ending inventory")
                        )
                        .foregroundStyle(by: .value("Series", "Ending inventory"))
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Period", decision.period),
                            y: .value("Ending inventory", decision.endingInventory)
                        )
                        .foregroundStyle(by: .value("Series", "Ending inventory"))
                        .symbolSize(30)
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading)
                .chartYAxis {
                    AxisMarks(position: .leading) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .frame(height: 260)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        Text("Period")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Begin")
                            .frame(width: 75, alignment: .trailing)
                        Text("Produce")
                            .frame(width: 80, alignment: .trailing)
                        Text("Demand")
                            .frame(width: 75, alignment: .trailing)
                        Text("End")
                            .frame(width: 75, alignment: .trailing)
                        Text("Cost")
                            .frame(width: 100, alignment: .trailing)
                    }
                    .tableHeaderStyle()

                    ForEach(Array(solution.decisions.enumerated()), id: \.offset) { _, decision in
                        HStack(spacing: 10) {
                            Text(decision.period)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(decision.beginningInventory)")
                                .frame(width: 75, alignment: .trailing)
                            Text("\(decision.productionQuantity)")
                                .frame(width: 80, alignment: .trailing)
                            Text("\(decision.demand)")
                                .frame(width: 75, alignment: .trailing)
                            Text("\(decision.endingInventory)")
                                .frame(width: 75, alignment: .trailing)
                            Text(DynamicProgrammingPresentation.number(decision.cost))
                                .fontWeight(.semibold)
                                .frame(width: 100, alignment: .trailing)
                        }
                        .tableRowStyle()
                    }
                }
            }
        }
    }

    private var policyTrace: some View {
        section(
            title: "Policy trace",
            subtitle: "Reconstructed stage, state, action, transition, and local value."
        ) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Text("Stage")
                        .frame(width: 150, alignment: .leading)
                    Text("State")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Action")
                        .frame(width: 150, alignment: .leading)
                    Text("Next state")
                        .frame(width: 170, alignment: .leading)
                    Text("Value")
                        .frame(width: 90, alignment: .trailing)
                }
                .tableHeaderStyle()

                ForEach(Array(document.solution.trace.enumerated()), id: \.offset) { _, step in
                    HStack(spacing: 12) {
                        Text(step.stage)
                            .frame(width: 150, alignment: .leading)
                            .lineLimit(1)
                        Text(step.state)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                        Text(step.action)
                            .frame(width: 150, alignment: .leading)
                            .lineLimit(1)
                        Text(step.nextState ?? "-")
                            .frame(width: 170, alignment: .leading)
                            .lineLimit(1)
                        Text(DynamicProgrammingPresentation.number(step.value))
                            .frame(width: 90, alignment: .trailing)
                    }
                    .tableRowStyle()
                }
            }
        }
    }

    private var runContext: some View {
        section(
            title: "Run context",
            subtitle: presentation.exactnessLabel
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(document.assumptions.enumerated()), id: \.offset) { _, assumption in
                    Label(assumption, systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func section<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content()
        }
    }
}

private struct DynamicProgrammingPresentation {
    let document: DynamicProgrammingSolutionDocument

    var kindLabel: String {
        switch document.solution.kind {
        case .boundedKnapsack: "Bounded Knapsack"
        case .stagecoach: "Stagecoach"
        case .productionInventory: "Production / Inventory"
        }
    }

    var exactnessLabel: String {
        switch document.backend.exactness {
        case .exact: "Exact"
        case .closedForm: "Closed form"
        case .fixtureScale: "Fixture scale"
        case .heuristic: "Heuristic"
        case .approximate: "Approximate"
        }
    }

    var summaryMetrics: [DynamicProgrammingMetric] {
        switch document.solution {
        case .boundedKnapsack(let solution, _):
            [
                metric("Total return", solution.totalReturn),
                DynamicProgrammingMetric(label: "Capacity used", value: "\(solution.capacityUsed)"),
                DynamicProgrammingMetric(label: "Selections", value: "\(solution.selections.count)")
            ]
        case .stagecoach(let solution, _):
            [
                metric("Total cost", solution.totalCost),
                DynamicProgrammingMetric(label: "Stops", value: "\(solution.path.count)"),
                DynamicProgrammingMetric(label: "Transitions", value: "\(max(0, solution.path.count - 1))")
            ]
        case .productionInventory(let solution, _):
            [
                metric("Total cost", solution.totalCost),
                DynamicProgrammingMetric(label: "Periods", value: "\(solution.decisions.count)"),
                DynamicProgrammingMetric(
                    label: "Production",
                    value: "\(solution.decisions.reduce(0) { $0 + $1.productionQuantity })"
                )
            ]
        }
    }

    var minimumContentWidth: CGFloat {
        switch document.solution {
        case .productionInventory(let solution, _):
            max(820, CGFloat(solution.decisions.count) * 125)
        default:
            820
        }
    }

    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func metric(_ label: String, _ value: Double) -> DynamicProgrammingMetric {
        DynamicProgrammingMetric(label: label, value: Self.number(value))
    }
}

private struct DynamicProgrammingMetric: Identifiable {
    let label: String
    let value: String
    var id: String { label }
}

private extension View {
    func tableHeaderStyle() -> some View {
        self
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.quaternary.opacity(0.35))
    }

    func tableRowStyle() -> some View {
        self
            .font(.callout.monospacedDigit())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) {
                Divider()
            }
    }
}
