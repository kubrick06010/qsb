import Charts
import Foundation
import QSBCore
import SwiftUI

struct QueuingSolutionView: View {
    let document: QueuingSolutionDocument

    private var metrics: QueuingPerformanceMetrics { document.metrics }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summary
            Divider()

            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 24) {
                        utilizationSection
                        performanceSection
                        if !document.stateProbabilities.isEmpty {
                            stateProbabilitySection
                        }
                        if let cost = document.cost {
                            costSection(cost)
                        }
                        runContext
                    }
                    .padding(18)
                    .frame(width: max(720, geometry.size.width), alignment: .topLeading)
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
            Text("\(document.notation) · \(document.backend.algorithm)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var summaryMetrics: some View {
        HStack(spacing: 24) {
            summaryMetric(percent(metrics.utilization), label: "Utilization")
            summaryMetric(number(metrics.averageNumberInSystem), label: "In system")
            summaryMetric(duration(metrics.averageTimeInSystem), label: "Time in system")
        }
    }

    private func summaryMetric(_ value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private var utilizationSection: some View {
        section(
            title: "Capacity and flow",
            subtitle: "Arrival throughput and use of the available service capacity."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Server utilization", systemImage: "gauge.with.dots.needle.67percent")
                        .font(.headline)
                    Spacer()
                    Text(percent(metrics.utilization))
                        .font(.headline.monospacedDigit())
                }
                ProgressView(value: min(max(metrics.utilization, 0), 1))
                    .accessibilityLabel("Server utilization")
                    .accessibilityValue(percent(metrics.utilization))

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 190), alignment: .leading)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    metricCard("Arrival rate", rate(metrics.arrivalRate), symbol: "arrow.right")
                    metricCard("Effective arrival rate", rate(metrics.effectiveArrivalRate), symbol: "arrow.right.to.line")
                    metricCard("Service rate per server", rate(metrics.serviceRatePerServer), symbol: "person.fill.checkmark")
                    metricCard("Servers", "\(metrics.servers)", symbol: "person.2")
                    if let capacity = metrics.systemCapacity {
                        metricCard("System capacity", "\(capacity)", symbol: "rectangle.stack")
                    }
                    metricCard("Blocking probability", percent(metrics.blockingProbability), symbol: "hand.raised")
                }
            }
        }
    }

    private var performanceSection: some View {
        section(
            title: "Queue performance",
            subtitle: "Steady-state customer counts and waiting times."
        ) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 190), alignment: .leading)],
                alignment: .leading,
                spacing: 10
            ) {
                metricCard("Average in system (L)", number(metrics.averageNumberInSystem), symbol: "person.3")
                metricCard("Average waiting (Lq)", number(metrics.averageNumberInQueue), symbol: "person.2")
                metricCard("Average in service", number(metrics.averageNumberBeingServed), symbol: "person.fill.checkmark")
                metricCard("Time in system (W)", duration(metrics.averageTimeInSystem), symbol: "clock")
                metricCard("Waiting time (Wq)", duration(metrics.averageTimeInQueue), symbol: "clock.badge.exclamationmark")
                metricCard("System empty", percent(metrics.probabilitySystemEmpty), symbol: "tray")
            }
        }
    }

    private var stateProbabilitySection: some View {
        section(
            title: "State probabilities",
            subtitle: "Probability of observing each number of customers in the finite system."
        ) {
            Chart(Array(document.stateProbabilities.enumerated()), id: \.offset) { state, probability in
                BarMark(
                    x: .value("Customers", state),
                    y: .value("Probability", probability)
                )
                .foregroundStyle(state == document.stateProbabilities.count - 1 ? Color.orange : Color.blue)
                .accessibilityLabel("\(state) customers")
                .accessibilityValue(percent(probability))
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let probability = value.as(Double.self) {
                            Text(percent(probability))
                        }
                    }
                }
            }
            .frame(height: 240)
        }
    }

    private func costSection(_ cost: QueuingCostMetrics) -> some View {
        let items = costItems(cost)
        return section(
            title: "Cost breakdown",
            subtitle: "Expected recurring cost per \(document.timeUnit)."
        ) {
            Chart(items) { item in
                BarMark(
                    x: .value("Cost", item.value),
                    y: .value("Component", item.label)
                )
                .foregroundStyle(item.color)
                .accessibilityLabel(item.label)
                .accessibilityValue(number(item.value))
            }
            .chartXAxis {
                AxisMarks {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .frame(height: max(180, CGFloat(items.count) * 34))

            HStack {
                Text("Total cost")
                    .font(.headline)
                Spacer()
                Text("\(number(cost.totalCost)) per \(document.timeUnit)")
                    .font(.headline.monospacedDigit())
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var runContext: some View {
        section(
            title: "Assumptions and run context",
            subtitle: "\(document.backend.exactness.rawValue) · \(document.backend.backendKind.rawValue)"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(document.assumptions, id: \.self) { assumption in
                    Label(assumption, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
                ForEach(document.backend.notes, id: \.self) { note in
                    Label(note, systemImage: "gearshape")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func metricCard(_ label: String, _ value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }

    private func section<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.title3.weight(.semibold))
                Text(subtitle).font(.callout).foregroundStyle(.secondary)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rate(_ value: Double) -> String {
        "\(number(value)) per \(document.timeUnit)"
    }

    private func duration(_ value: Double) -> String {
        "\(number(value)) \(document.timeUnit)"
    }

    private func number(_ value: Double) -> String {
        let rounded = value.rounded()
        return abs(value - rounded) < 1e-8 ? String(Int(rounded)) : String(format: "%.3f", value)
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private func costItems(_ cost: QueuingCostMetrics) -> [QueueCostItem] {
        [
            QueueCostItem(label: "Busy servers", value: cost.busyServerCost, color: .blue),
            QueueCostItem(label: "Idle servers", value: cost.idleServerCost, color: .cyan),
            QueueCostItem(label: "Waiting customers", value: cost.customerWaitingCost, color: .orange),
            QueueCostItem(label: "Customers in service", value: cost.customerBeingServedCost, color: .green),
            QueueCostItem(label: "Blocked customers", value: cost.blockedCustomerCost, color: .red),
            QueueCostItem(label: "Queue capacity", value: cost.capacityCost, color: .purple)
        ].filter { abs($0.value) > 1e-12 }
    }
}

private struct QueueCostItem: Identifiable {
    let label: String
    let value: Double
    let color: Color

    var id: String { label }
}
