import Charts
import QSBCore
import SwiftUI

struct QualityControlSolutionView: View {
    let document: QualityControlSolutionDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeaderView(
                    title: document.model.title,
                    subtitle: "\(kindLabel) · \(document.backend.algorithmDisplayName)"
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 12)], alignment: .leading, spacing: 12) {
                    metric("Analysis", kindLabel)
                    metric("Observations", "\(observationCount)")
                    metric("Signals", "\(signalCount)")
                    metric("Exactness", document.backend.exactnessDisplayName)
                }

                solutionContent
                runContext
            }
            .padding(20)
            .frame(maxWidth: 1160, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var solutionContent: some View {
        switch document.solution {
        case .cChart(let solution):
            controlChart(title: "Defect count control chart", solution: solution)
            signalDetails(solution)
        case .pChart(let solution):
            controlChart(title: "Fraction defective control chart", solution: solution)
            signalDetails(solution)
        case .xbarRChart(let solution):
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], alignment: .leading, spacing: 12) {
                metric("Grand mean", number(solution.grandMean))
                metric("Average range", number(solution.averageRange))
            }
            controlChart(title: "Subgroup means", solution: solution.meanChart)
            controlChart(title: "Subgroup ranges", solution: solution.rangeChart)
            signalDetails(solution.meanChart, prefix: "Mean chart")
            signalDetails(solution.rangeChart, prefix: "Range chart")
        case .pareto(let solution):
            paretoCharts(solution)
            paretoTable(solution)
        case .normalProbabilityPlot(let solution):
            probabilityPlot(solution)
            probabilitySummary(solution)
        }
    }

    private func controlChart(title: String, solution: ControlChartSolution) -> some View {
        GroupBox(title) {
            ScrollView(.horizontal) {
                Chart {
                    ForEach(Array(solution.points.enumerated()), id: \.offset) { _, point in
                        LineMark(
                            x: .value("Observation", point.index),
                            y: .value("Value", point.value),
                            series: .value("Series", "Observed")
                        )
                        .foregroundStyle(Color.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(x: .value("Observation", point.index), y: .value("Value", point.value))
                            .foregroundStyle(point.isOutsideLimits ? Color.red : Color.blue)
                            .symbolSize(point.isOutsideLimits ? 60 : 30)
                            .accessibilityLabel("Observation \(point.index)\(point.isOutsideLimits ? ", outside control limits" : "")")
                            .accessibilityValue(number(point.value))

                        LineMark(
                            x: .value("Observation", point.index),
                            y: .value("Center line", point.centerLine),
                            series: .value("Series", "Center")
                        )
                        .foregroundStyle(Color.green)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))

                        LineMark(
                            x: .value("Observation", point.index),
                            y: .value("Upper control limit", point.upperControlLimit),
                            series: .value("Series", "UCL")
                        )
                        .foregroundStyle(Color.red)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))

                        LineMark(
                            x: .value("Observation", point.index),
                            y: .value("Lower control limit", point.lowerControlLimit),
                            series: .value("Series", "LCL")
                        )
                        .foregroundStyle(Color.red)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    }
                }
                .chartXAxisLabel("Observation")
                .frame(width: max(650, CGFloat(solution.points.count) * 58), height: 290)
                .padding(.vertical, 8)
            }
            .accessibilityLabel(title)
        }
    }

    private func signalDetails(_ solution: ControlChartSolution, prefix: String? = nil) -> some View {
        GroupBox(prefix.map { "\($0) signals" } ?? "Control signals") {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Outside limits", value: indexList(solution.outsideLimitIndexes))
                if solution.westernElectricViolations.isEmpty {
                    LabeledContent("Western Electric rules", value: "No signals")
                } else {
                    ForEach(Array(solution.westernElectricViolations.enumerated()), id: \.offset) { _, violation in
                        LabeledContent(ruleLabel(violation.rule), value: indexList(violation.indexes))
                    }
                }
            }
            .padding(4)
        }
    }

    private func paretoCharts(_ solution: ParetoSolution) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Defect frequency") {
                Chart {
                    ForEach(Array(solution.categories.enumerated()), id: \.offset) { _, category in
                        BarMark(x: .value("Category", category.name), y: .value("Count", category.count))
                            .foregroundStyle(Color.blue.gradient)
                            .accessibilityLabel(category.name)
                            .accessibilityValue("\(number(category.count)) defects")
                    }
                }
                .chartYAxisLabel("Count")
                .frame(height: 270)
                .padding(.vertical, 8)
            }

            GroupBox("Cumulative share") {
                Chart {
                    ForEach(Array(solution.categories.enumerated()), id: \.offset) { _, category in
                        LineMark(x: .value("Category", category.name), y: .value("Cumulative share", category.cumulativePercentage))
                            .foregroundStyle(Color.orange)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                        PointMark(x: .value("Category", category.name), y: .value("Cumulative share", category.cumulativePercentage))
                            .foregroundStyle(Color.orange)
                            .accessibilityLabel("Cumulative share through \(category.name)")
                            .accessibilityValue(percent(category.cumulativePercentage))
                    }
                    RuleMark(y: .value("Eighty percent", 0.8))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                .chartYScale(domain: 0.0...1.0)
                .chartYAxisLabel("Cumulative share")
                .frame(height: 210)
                .padding(.vertical, 8)
            }
        }
    }

    private func paretoTable(_ solution: ParetoSolution) -> some View {
        GroupBox("Pareto categories") {
            Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 8) {
                GridRow { heading("Category"); heading("Count"); heading("Share"); heading("Cumulative") }
                Divider().gridCellUnsizedAxes(.horizontal)
                ForEach(Array(solution.categories.enumerated()), id: \.offset) { _, category in
                    GridRow {
                        Text(category.name).fontWeight(.semibold)
                        value(number(category.count))
                        value(percent(category.percentage))
                        value(percent(category.cumulativePercentage))
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(4)
        }
    }

    private func probabilityPlot(_ solution: NormalProbabilityPlotSolution) -> some View {
        GroupBox("Normal probability plot") {
            Chart {
                ForEach(Array(solution.points.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value("Normal score", point.normalScore),
                        y: .value("Fitted value", point.fittedValue)
                    )
                    .foregroundStyle(Color.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    PointMark(x: .value("Normal score", point.normalScore), y: .value("Observed value", point.value))
                        .foregroundStyle(Color.blue)
                        .symbolSize(34)
                        .accessibilityLabel("Rank \(point.rank)")
                        .accessibilityValue("Observed \(number(point.value)), fitted \(number(point.fittedValue))")
                }
            }
            .chartXAxisLabel("Normal score")
            .chartYAxisLabel("Observed value")
            .frame(height: 310)
            .padding(.vertical, 8)
        }
    }

    private func probabilitySummary(_ solution: NormalProbabilityPlotSolution) -> some View {
        GroupBox("Distribution summary") {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Mean", value: number(solution.mean))
                LabeledContent("Sample standard deviation", value: number(solution.sampleStandardDeviation))
                LabeledContent("Fit", value: "y = \(number(solution.intercept)) + \(number(solution.slope))z")
                LabeledContent("Correlation", value: number(solution.correlation))
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
        switch document.solution.kind {
        case .cChart: "c chart"
        case .pChart: "p chart"
        case .xbarRChart: "X-bar and R charts"
        case .pareto: "Pareto analysis"
        case .normalProbabilityPlot: "Normal probability plot"
        }
    }

    private var observationCount: Int {
        switch document.solution {
        case .cChart(let value), .pChart(let value): value.points.count
        case .xbarRChart(let value): value.meanChart.points.count
        case .pareto(let value): value.categories.count
        case .normalProbabilityPlot(let value): value.points.count
        }
    }

    private var signalCount: Int {
        switch document.solution {
        case .cChart(let value), .pChart(let value): chartSignalCount(value)
        case .xbarRChart(let value): chartSignalCount(value.meanChart) + chartSignalCount(value.rangeChart)
        case .pareto, .normalProbabilityPlot: 0
        }
    }

    private func chartSignalCount(_ solution: ControlChartSolution) -> Int {
        Set(solution.outsideLimitIndexes + solution.westernElectricViolations.flatMap(\.indexes)).count
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

    private func indexList(_ indexes: [Int]) -> String {
        indexes.isEmpty ? "None" : indexes.map(String.init).joined(separator: ", ")
    }

    private func ruleLabel(_ rule: String) -> String {
        switch rule {
        case "twoOfThreeBeyondTwoSigma": "Two of three beyond 2σ"
        case "fourOfFiveBeyondOneSigma": "Four of five beyond 1σ"
        case "eightOnOneSide": "Eight on one side"
        default: rule
        }
    }

    private func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...4)))
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0...2)))
    }
}
