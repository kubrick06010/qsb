import Charts
import QSBCore
import SwiftUI

struct ProjectSchedulingSolutionView: View {
    let document: ProjectSchedulingSolutionDocument

    private var timeUnit: String {
        switch document.model {
        case .cpm(let project): project.timeUnit
        case .pert(let project): project.timeUnit
        }
    }

    private var chartWidth: CGFloat {
        max(680, CGFloat(document.solution.activityTimings.count) * 64)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeaderView(
                    title: document.model.title,
                    subtitle: "\(kindLabel) · \(document.backend.algorithmDisplayName)"
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 12)], alignment: .leading, spacing: 12) {
                    metric("Project duration", "\(number(document.solution.projectDuration)) \(timeUnit)")
                    metric("Activities", "\(document.solution.activityTimings.count)")
                    metric("Critical activities", "\(document.solution.criticalActivities.count)")
                    if let deviation = document.solution.projectStandardDeviation {
                        metric("PERT standard deviation", number(deviation))
                    }
                    if let cost = document.solution.totalNormalCost {
                        metric("Normal cost", number(cost))
                    }
                    metric("Exactness", document.backend.exactnessDisplayName)
                }

                scheduleChart
                activityTable
                criticalPath
                runContext
            }
            .padding(20)
            .frame(maxWidth: 1160, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var scheduleChart: some View {
        GroupBox("Earliest schedule and slack") {
            ScrollView(.horizontal) {
                Chart {
                    ForEach(document.solution.activityTimings, id: \.name) { timing in
                        if timing.slack > 1e-9 {
                            BarMark(
                                xStart: .value("Earliest finish", timing.earliestFinish),
                                xEnd: .value("Latest finish", timing.latestFinish),
                                y: .value("Activity", timing.name)
                            )
                            .foregroundStyle(Color.secondary.opacity(0.3))
                            .accessibilityLabel("Activity \(timing.name) slack")
                            .accessibilityValue("\(number(timing.slack)) \(timeUnit)")
                        }

                        BarMark(
                            xStart: .value("Earliest start", timing.earliestStart),
                            xEnd: .value("Earliest finish", timing.earliestFinish),
                            y: .value("Activity", timing.name)
                        )
                        .foregroundStyle(timing.isCritical ? Color.red.gradient : Color.blue.gradient)
                        .accessibilityLabel("Activity \(timing.name)\(timing.isCritical ? ", critical" : "")")
                        .accessibilityValue("starts \(number(timing.earliestStart)), finishes \(number(timing.earliestFinish)), slack \(number(timing.slack)) \(timeUnit)")
                    }

                    RuleMark(x: .value("Project duration", document.solution.projectDuration))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                .chartXAxisLabel(timeUnit.capitalized)
                .frame(width: chartWidth, height: max(260, CGFloat(document.solution.activityTimings.count) * 42))
                .padding(.vertical, 8)
            }
            .accessibilityLabel("Activity schedule; critical activities are highlighted")
        }
    }

    private var activityTable: some View {
        GroupBox("Activity timings") {
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                    GridRow {
                        heading("Activity")
                        heading("Duration")
                        heading("ES")
                        heading("EF")
                        heading("LS")
                        heading("LF")
                        heading("Slack")
                        heading("Critical")
                    }
                    Divider().gridCellUnsizedAxes(.horizontal)
                    ForEach(document.solution.activityTimings, id: \.name) { timing in
                        GridRow {
                            Text(timing.name).fontWeight(.semibold)
                            value(timing.duration)
                            value(timing.earliestStart)
                            value(timing.earliestFinish)
                            value(timing.latestStart)
                            value(timing.latestFinish)
                            value(timing.slack)
                            Image(systemName: timing.isCritical ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(timing.isCritical ? Color.red : Color.secondary)
                                .accessibilityLabel(timing.isCritical ? "Critical" : "Not critical")
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Activity \(timing.name)")
                    }
                }
                .padding(4)
            }
        }
    }

    private var criticalPath: some View {
        GroupBox("Critical path") {
            if document.solution.criticalActivities.isEmpty {
                Text("No critical activities")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Array(document.solution.criticalActivities.enumerated()), id: \.offset) { index, activity in
                            if index > 0 {
                                Image(systemName: "arrow.right").foregroundStyle(.secondary).accessibilityHidden(true)
                            }
                            Text(activity)
                                .font(.headline)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.red.opacity(0.12), in: Capsule())
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Critical activities: \(document.solution.criticalActivities.joined(separator: ", "))")
                    .padding(4)
                }
            }
        }
    }

    private var runContext: some View {
        GroupBox("Run context") {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Backend", value: document.backend.backendDisplayName)
                LabeledContent("Algorithm", value: document.backend.algorithmDisplayName)
                LabeledContent("Exactness", value: document.backend.exactnessDisplayName)
                if let variance = document.solution.projectVariance {
                    LabeledContent("Critical-path variance", value: number(variance))
                }
                ForEach(Array(document.backend.notes.enumerated()), id: \.offset) { _, note in
                    Label(note, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(4)
        }
    }

    private var kindLabel: String {
        switch document.model.kind {
        case .deterministicCPM: "Critical Path Method"
        case .probabilisticPERT: "PERT"
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
        Text(self.number(number)).monospacedDigit().frame(minWidth: 56, alignment: .trailing)
    }

    private func number(_ value: Double) -> String {
        let displayValue = abs(value) < 1e-9 ? 0 : value
        return displayValue.formatted(.number.precision(.fractionLength(0...4)))
    }
}
