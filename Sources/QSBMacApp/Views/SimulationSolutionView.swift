import Charts
import QSBCore
import SwiftUI

struct SimulationSolutionView: View {
    let document: SimulationSolutionDocument

    private var completionRate: Double {
        guard document.solution.generatedEntities > 0 else { return 0 }
        return Double(document.solution.completedEntities) / Double(document.solution.generatedEntities)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeaderView(
                    title: document.model.title,
                    subtitle: "Discrete-event simulation · \(document.backend.algorithmDisplayName)"
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], alignment: .leading, spacing: 12) {
                    metric("Generated", "\(document.solution.generatedEntities)")
                    metric("Completed", "\(document.solution.completedEntities)")
                    metric("Completion rate", percent(completionRate))
                    metric("Horizon", "\(number(document.solution.horizon)) \(document.model.timeUnit)")
                    metric("Replications", "\(document.solution.replications)")
                    metric("Seed", "\(document.solution.seed)")
                }

                if !document.solution.queueMetrics.isEmpty {
                    queueChart
                    queueTable
                }

                if !document.solution.serverMetrics.isEmpty {
                    serverChart
                    serverTable
                }

                networkSummary
                runContext
            }
            .padding(20)
            .frame(maxWidth: 1140, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var queueChart: some View {
        GroupBox("Queue length") {
            ScrollView(.horizontal) {
                Chart(document.solution.queueMetrics, id: \.name) { queue in
                    BarMark(x: .value("Queue", queue.name), y: .value("Average length", queue.averageLength))
                        .foregroundStyle(Color.blue.gradient)
                        .accessibilityLabel("Queue \(queue.name) average length")
                        .accessibilityValue(number(queue.averageLength))

                    if let interval = document.solution.queueLengthConfidenceIntervals[queue.name] {
                        RuleMark(
                            x: .value("Queue", queue.name),
                            yStart: .value("Lower confidence bound", interval.lower),
                            yEnd: .value("Upper confidence bound", interval.upper)
                        )
                        .foregroundStyle(Color.primary)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .accessibilityLabel("Queue \(queue.name) 95 percent confidence interval")
                        .accessibilityValue("\(number(interval.lower)) to \(number(interval.upper))")
                    }
                }
                .chartYAxisLabel("Average entities")
                .frame(width: max(580, CGFloat(document.solution.queueMetrics.count) * 100), height: 245)
                .padding(.vertical, 8)
            }
        }
    }

    private var queueTable: some View {
        GroupBox("Queue metrics") {
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 8) {
                    GridRow {
                        heading("Queue")
                        heading("Average")
                        heading("Maximum")
                        heading("Entered")
                        heading("Rejected")
                        heading("95% CI")
                    }
                    Divider().gridCellUnsizedAxes(.horizontal)
                    ForEach(document.solution.queueMetrics, id: \.name) { queue in
                        GridRow {
                            Text(queue.name).fontWeight(.semibold)
                            value(number(queue.averageLength))
                            value("\(queue.maximumLength)")
                            value("\(queue.entered)")
                            value("\(queue.rejected)")
                            Text(intervalText(document.solution.queueLengthConfidenceIntervals[queue.name]))
                                .monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Queue \(queue.name)")
                    }
                }
                .padding(4)
            }
        }
    }

    private var serverChart: some View {
        GroupBox("Server utilization") {
            ScrollView(.horizontal) {
                Chart(document.solution.serverMetrics, id: \.name) { server in
                    BarMark(x: .value("Server", server.name), y: .value("Utilization", server.utilization))
                        .foregroundStyle(server.utilization > 0.9 ? Color.orange.gradient : Color.teal.gradient)
                        .accessibilityLabel("Server \(server.name) utilization")
                        .accessibilityValue(percent(server.utilization))

                    if let interval = document.solution.serverUtilizationConfidenceIntervals[server.name] {
                        RuleMark(
                            x: .value("Server", server.name),
                            yStart: .value("Lower confidence bound", interval.lower),
                            yEnd: .value("Upper confidence bound", interval.upper)
                        )
                        .foregroundStyle(Color.primary)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .accessibilityLabel("Server \(server.name) 95 percent confidence interval")
                        .accessibilityValue("\(percent(interval.lower)) to \(percent(interval.upper))")
                    }
                }
                .chartYScale(domain: 0.0...1.0)
                .chartYAxisLabel("Utilization")
                .frame(width: max(580, CGFloat(document.solution.serverMetrics.count) * 100), height: 245)
                .padding(.vertical, 8)
            }
        }
    }

    private var serverTable: some View {
        GroupBox("Server metrics") {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow { heading("Server"); heading("Completed"); heading("Utilization"); heading("95% CI") }
                Divider().gridCellUnsizedAxes(.horizontal)
                ForEach(document.solution.serverMetrics, id: \.name) { server in
                    GridRow {
                        Text(server.name).fontWeight(.semibold)
                        value("\(server.completed)")
                        value(percent(server.utilization))
                        Text(intervalText(document.solution.serverUtilizationConfidenceIntervals[server.name]))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Server \(server.name)")
                }
            }
            .padding(4)
        }
    }

    private var networkSummary: some View {
        GroupBox("Simulation network") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(document.model.components.enumerated()), id: \.offset) { index, component in
                    if index > 0 { Divider() }
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Label(component.name, systemImage: icon(for: component.kind))
                            .font(.headline)
                            .frame(minWidth: 150, alignment: .leading)
                        Text(componentKind(component.kind))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 12)
                        Text(component.routes.isEmpty ? "Terminal" : "→ \(component.routes.map(\.target).joined(separator: ", "))")
                    }
                    .padding(.vertical, 9)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(4)
        }
    }

    private var runContext: some View {
        GroupBox("Run context") {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Backend", value: document.backend.backendDisplayName)
                LabeledContent("Algorithm", value: document.backend.algorithmDisplayName)
                LabeledContent("Exactness", value: document.backend.exactnessDisplayName)
                LabeledContent("Representation", value: document.model.representation.rawValue.capitalized)
                LabeledContent("Warm-up deletion", value: "\(number(document.solution.warmupTime)) \(document.model.timeUnit)")
                ForEach(Array(document.backend.notes.enumerated()), id: \.offset) { _, note in
                    Label(note, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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

    private func heading(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
    }

    private func value(_ text: String) -> some View {
        Text(text).monospacedDigit().frame(minWidth: 72, alignment: .trailing)
    }

    private func intervalText(_ interval: SimulationConfidenceInterval?) -> String {
        guard let interval else { return "—" }
        return "\(number(interval.lower))…\(number(interval.upper))"
    }

    private func icon(for kind: SimulationComponentKind) -> String {
        switch kind {
        case .customer: "person.crop.circle.badge.plus"
        case .queue: "person.3.sequence"
        case .server: "gearshape.2"
        case .gate: "arrow.triangle.branch"
        }
    }

    private func componentKind(_ kind: SimulationComponentKind) -> String {
        switch kind {
        case .customer: "Source"
        case .queue: "Queue"
        case .server: "Server"
        case .gate: "Gate"
        }
    }

    private func number(_ value: Double) -> String {
        let displayValue = abs(value) < 1e-9 ? 0 : value
        return displayValue.formatted(.number.precision(.fractionLength(0...4)))
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0...1)))
    }
}
