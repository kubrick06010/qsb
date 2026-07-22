import QSBCore
import SwiftUI

struct SchedulingGanttView: View {
    let document: SchedulingSolutionDocument

    @State private var zoom = 1.0
    @State private var viewportWidth: CGFloat = 0

    private let machineLabelWidth: CGFloat = 142
    private let rowHeight: CGFloat = 54
    private let barHeight: CGFloat = 32

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summary
            Divider()
            scaleControls
            Divider()

            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 0) {
                        timeAxis

                        ForEach(Array(document.machineTimelines.enumerated()), id: \.element.machineID) { index, timeline in
                            machineRow(timeline, index: index)
                        }

                        legend
                    }
                    .padding(16)
                    .frame(
                        minWidth: geometry.size.width,
                        minHeight: geometry.size.height,
                        alignment: .topLeading
                    )
                }
                .onAppear {
                    viewportWidth = geometry.size.width
                }
                .onChange(of: geometry.size.width) { _, width in
                    viewportWidth = width
                }
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 3) {
                Text(document.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(kindLabel) · \(document.backend.algorithm)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 16)

            metric(value: "\(document.makespan)", label: "Makespan")
            metric(value: "\(document.machineTimelines.count)", label: "Machines")
            metric(value: "\(jobs.count)", label: "Jobs")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var scaleControls: some View {
        HStack(spacing: 10) {
            Label("Timeline scale", systemImage: "arrow.left.and.right")
                .font(.callout)

            Slider(value: $zoom, in: 0.7...2.0, step: 0.1)
                .frame(width: 180)

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
            .help("Reset timeline scale")

            Spacer()

            Text("Time unit: \(document.timeUnit)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    private var timeAxis: some View {
        HStack(spacing: 0) {
            Text("Machine")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: machineLabelWidth, alignment: .leading)

            ZStack(alignment: .topLeading) {
                ForEach(tickValues, id: \.self) { tick in
                    Text("\(tick)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 44)
                        .offset(x: tickLabelOffset(for: tick))
                }
            }
            .frame(width: timelineWidth, height: 26, alignment: .topLeading)
        }
    }

    private func machineRow(
        _ timeline: SchedulingMachineTimeline,
        index: Int
    ) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeline.machineName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text("Complete \(timeline.completionTime)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(width: machineLabelWidth, height: rowHeight, alignment: .leading)

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.primary.opacity(index.isMultiple(of: 2) ? 0.025 : 0.05))

                if timeline.readyTime > 0 {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: xPosition(for: timeline.readyTime))
                }

                ForEach(tickValues, id: \.self) { tick in
                    Rectangle()
                        .fill(Color.secondary.opacity(tick == 0 ? 0.28 : 0.14))
                        .frame(width: 1, height: rowHeight)
                        .offset(x: xPosition(for: tick))
                }

                ForEach(timeline.operations, id: \.sequenceIndex) { operation in
                    operationBar(operation)
                }
            }
            .frame(width: timelineWidth, height: rowHeight, alignment: .topLeading)
        }
        .accessibilityElement(children: .contain)
    }

    private func operationBar(_ operation: SchedulingGanttOperation) -> some View {
        let width = max(3, xPosition(for: operation.duration))
        return RoundedRectangle(cornerRadius: 4)
            .fill(color(for: operation.jobID))
            .overlay {
                Text(operation.jobName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 4)
            }
            .frame(width: width, height: barHeight)
            .offset(
                x: xPosition(for: operation.start),
                y: (rowHeight - barHeight) / 2
            )
            .help("\(operation.jobName), \(operation.machineName): \(operation.start)-\(operation.finish)")
            .accessibilityLabel("\(operation.jobName) on \(operation.machineName)")
            .accessibilityValue("Starts at \(operation.start), finishes at \(operation.finish)")
    }

    private var legend: some View {
        HStack(spacing: 16) {
            Text("Jobs")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(jobs, id: \.id) { job in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: job.id))
                        .frame(width: 11, height: 11)
                    Text(job.name)
                        .font(.caption)
                }
            }
        }
        .padding(.top, 14)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var kindLabel: String {
        switch document.kind {
        case .flowShop: "Flow shop"
        case .jobShop: "Job shop"
        }
    }

    private var jobs: [(id: Int, name: String)] {
        document.operations.reduce(into: [Int: String]()) { result, operation in
            result[operation.jobID] = operation.jobName
        }
            .map { (id: $0.key, name: $0.value) }
            .sorted { $0.id < $1.id }
    }

    private var timelineWidth: CGFloat {
        let contentWidth = CGFloat(max(document.makespan, 1)) * 4
        let visibleWidth = viewportWidth - machineLabelWidth - 32
        return max(680, max(contentWidth, visibleWidth)) * zoom
    }

    private var tickValues: [Int] {
        let makespan = max(document.makespan, 1)
        let targetIntervals = max(4, min(12, Int(timelineWidth / 90)))
        let roughStep = Double(makespan) / Double(targetIntervals)
        let magnitude = pow(10, floor(log10(max(roughStep, 1))))
        let normalized = roughStep / magnitude
        let multiplier: Double = normalized <= 1 ? 1 : normalized <= 2 ? 2 : normalized <= 5 ? 5 : 10
        let step = max(1, Int(multiplier * magnitude))
        var values = Array(stride(from: 0, through: makespan, by: step))
        if values.last != makespan {
            values.append(makespan)
        }
        return values
    }

    private func xPosition(for value: Int) -> CGFloat {
        CGFloat(value) / CGFloat(max(document.makespan, 1)) * timelineWidth
    }

    private func tickLabelOffset(for value: Int) -> CGFloat {
        min(max(0, xPosition(for: value) - 22), timelineWidth - 44)
    }

    private func color(for jobID: Int) -> Color {
        Self.palette[abs(jobID % Self.palette.count)]
    }

    private static let palette: [Color] = [
        .blue, .orange, .green, .purple, .pink, .teal, .indigo, .red
    ]
}
