import Charts
import Foundation
import QSBCore
import SwiftUI

struct ForecastingSolutionView: View {
    let document: ForecastingSolutionDocument

    @State private var showActual = true
    @State private var showFitted = true
    @State private var showForecast = true
    @State private var showResiduals = true
    @State private var zoom = 1.0

    private var presentation: ForecastingChartPresentation {
        ForecastingChartPresentation(document: document)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summary
            Divider()
            controls
            Divider()

            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 18) {
                        seriesChart

                        if showResiduals, !presentation.residuals.isEmpty {
                            residualChart
                        }

                        details
                    }
                    .padding(18)
                    .frame(
                        width: chartWidth(viewportWidth: geometry.size.width),
                        alignment: .topLeading
                    )
                    .frame(minHeight: geometry.size.height, alignment: .topLeading)
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
                Text("\(presentation.methodLabel) · \(document.backend.algorithm)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 16)

            metric(value: "\(presentation.actual.count)", label: "Observations")
            metric(value: "\(presentation.fitted.count)", label: presentation.fittedLabel)
            metric(value: "\(presentation.forecast.count)", label: "Forecasts")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Toggle("Actual", isOn: $showActual)
                .toggleStyle(.checkbox)
            Toggle(presentation.fittedLabel, isOn: $showFitted)
                .toggleStyle(.checkbox)
            Toggle("Forecast", isOn: $showForecast)
                .toggleStyle(.checkbox)
                .disabled(presentation.forecast.isEmpty)
            Toggle("Residuals", isOn: $showResiduals)
                .toggleStyle(.checkbox)
                .disabled(presentation.residuals.isEmpty)

            Divider()
                .frame(height: 18)

            Label("Scale", systemImage: "arrow.left.and.right")
                .font(.callout)
            Slider(value: $zoom, in: 0.75...2.0, step: 0.05)
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
            .help("Reset chart scale")

            Spacer()

            Text(presentation.exactnessLabel)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    private var seriesChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(presentation.valueName)
                    .font(.headline)
                Spacer()
                seriesLegend
            }

            Chart {
                if showActual {
                    ForEach(presentation.actual) { point in
                        LineMark(
                            x: .value("Period", point.index),
                            y: .value(presentation.valueName, point.value),
                            series: .value("Series", "Actual")
                        )
                        .foregroundStyle(Color.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Period", point.index),
                            y: .value(presentation.valueName, point.value)
                        )
                        .foregroundStyle(Color.blue)
                        .symbolSize(28)
                        .accessibilityLabel("Actual, \(point.label)")
                        .accessibilityValue(ForecastingChartPresentation.number(point.value))
                    }
                }

                if showFitted {
                    ForEach(presentation.fitted) { point in
                        LineMark(
                            x: .value("Period", point.index),
                            y: .value(presentation.fittedLabel, point.value),
                            series: .value("Series", presentation.fittedLabel)
                        )
                        .foregroundStyle(Color.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Period", point.index),
                            y: .value(presentation.fittedLabel, point.value)
                        )
                        .foregroundStyle(Color.orange)
                        .symbolSize(20)
                        .accessibilityLabel("\(presentation.fittedLabel), \(point.label)")
                        .accessibilityValue(ForecastingChartPresentation.number(point.value))
                    }
                }

                if showForecast {
                    ForEach(presentation.forecastLine) { point in
                        LineMark(
                            x: .value("Period", point.index),
                            y: .value("Forecast", point.value),
                            series: .value("Series", "Forecast")
                        )
                        .foregroundStyle(Color.green)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, dash: [7, 4]))
                    }

                    ForEach(presentation.forecast) { point in
                        PointMark(
                            x: .value("Period", point.index),
                            y: .value("Forecast", point.value)
                        )
                        .foregroundStyle(Color.green)
                        .symbolSize(40)
                        .accessibilityLabel("Forecast, \(point.label)")
                        .accessibilityValue(ForecastingChartPresentation.number(point.value))
                    }
                }
            }
            .chartXAxis { chartXAxis }
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .frame(height: 300)
        }
    }

    private var residualChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Residuals")
                .font(.headline)

            Chart {
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(Color.secondary.opacity(0.6))

                ForEach(presentation.residuals) { point in
                    AreaMark(
                        x: .value("Period", point.index),
                        yStart: .value("Zero", 0),
                        yEnd: .value("Residual", point.value)
                    )
                    .foregroundStyle(Color.teal.opacity(0.16))

                    LineMark(
                        x: .value("Period", point.index),
                        y: .value("Residual", point.value),
                        series: .value("Series", "Residual")
                    )
                    .foregroundStyle(Color.teal)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))

                    PointMark(
                        x: .value("Period", point.index),
                        y: .value("Residual", point.value)
                    )
                    .foregroundStyle(point.value >= 0 ? Color.teal : Color.red)
                    .symbolSize(28)
                    .accessibilityLabel("Residual, \(point.label)")
                    .accessibilityValue(ForecastingChartPresentation.number(point.value))
                }
            }
            .chartXAxis { chartXAxis }
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .frame(height: 145)
        }
    }

    @AxisContentBuilder
    private var chartXAxis: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: min(12, max(4, presentation.allLabels.count)))) { value in
            AxisGridLine()
            AxisTick()
            AxisValueLabel {
                if let index = value.as(Int.self) {
                    Text(presentation.label(for: index))
                        .lineLimit(1)
                }
            }
        }
    }

    private var seriesLegend: some View {
        HStack(spacing: 14) {
            if showActual {
                legendItem("Actual", color: .blue, dashed: false)
            }
            if showFitted {
                legendItem(presentation.fittedLabel, color: .orange, dashed: false)
            }
            if showForecast, !presentation.forecast.isEmpty {
                legendItem("Forecast", color: .green, dashed: true)
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Text("Model summary")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), alignment: .leading)], alignment: .leading, spacing: 12) {
                ForEach(presentation.details) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.value)
                            .font(.body.weight(.medium).monospacedDigit())
                            .lineLimit(1)
                        Text(item.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func legendItem(_ label: String, color: Color, dashed: Bool) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(color)
                .frame(width: 22, height: dashed ? 2 : 3)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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

    private func chartWidth(viewportWidth: CGFloat) -> CGFloat {
        let pointWidth = CGFloat(max(presentation.allLabels.count, 1)) * 46
        return max(720, max(pointWidth, viewportWidth - 36)) * zoom
    }
}

private struct ForecastingChartPresentation {
    let methodLabel: String
    let valueName: String
    let fittedLabel: String
    let exactnessLabel: String
    let actual: [ForecastChartPoint]
    let fitted: [ForecastChartPoint]
    let forecast: [ForecastChartPoint]
    let residuals: [ForecastChartPoint]
    let details: [ForecastDetail]

    var forecastLine: [ForecastChartPoint] {
        guard let lastFitted = fitted.last, !forecast.isEmpty else { return forecast }
        return [lastFitted] + forecast
    }

    var allLabels: [Int: String] {
        Dictionary(uniqueKeysWithValues: (actual + forecast).map { ($0.index, $0.label) })
    }

    func label(for index: Int) -> String {
        allLabels[index] ?? "\(index)"
    }

    init(document: ForecastingSolutionDocument) {
        methodLabel = Self.methodName(document.request.method)
        exactnessLabel = document.backend.exactness.displayName

        switch (document.request.model, document.solution) {
        case (.timeSeries(let model), .linearTrend(let solution)):
            valueName = model.valueName
            fittedLabel = "Fitted"
            (actual, fitted, forecast, residuals) = Self.timeSeries(
                model: model,
                fitted: solution.fittedValues,
                forecasts: solution.forecasts
            )
            details = Self.accuracyDetails(
                mad: solution.meanAbsoluteDeviation,
                mse: solution.meanSquaredError,
                mape: solution.meanAbsolutePercentageError
            ) + [
                ForecastDetail(label: "Intercept", value: Self.number(solution.intercept)),
                ForecastDetail(label: "Slope", value: Self.number(solution.slope)),
                ForecastDetail(label: "Mean actual", value: Self.number(solution.meanActual))
            ]

        case (.timeSeries(let model), .movingAverage(let solution)):
            valueName = model.valueName
            fittedLabel = "Fitted"
            (actual, fitted, forecast, residuals) = Self.timeSeries(model: model, fitted: solution.fittedValues, forecasts: solution.forecasts)
            details = Self.accuracyDetails(mad: solution.meanAbsoluteDeviation, mse: solution.meanSquaredError, mape: solution.meanAbsolutePercentageError) + [
                ForecastDetail(label: "Window size", value: "\(solution.windowSize)")
            ]

        case (.timeSeries(let model), .exponentialSmoothing(let solution)):
            valueName = model.valueName
            fittedLabel = "Fitted"
            (actual, fitted, forecast, residuals) = Self.timeSeries(model: model, fitted: solution.fittedValues, forecasts: solution.forecasts)
            details = Self.accuracyDetails(mad: solution.meanAbsoluteDeviation, mse: solution.meanSquaredError, mape: solution.meanAbsolutePercentageError) + [
                ForecastDetail(label: "Alpha", value: Self.number(solution.alpha)),
                ForecastDetail(label: "Initial forecast", value: Self.number(solution.initialForecast))
            ]

        case (.timeSeries(let model), .multiplicativeSeasonalDecomposition(let solution)):
            valueName = model.valueName
            fittedLabel = "Fitted"
            (actual, fitted, forecast, residuals) = Self.timeSeries(model: model, fitted: solution.fittedValues, forecasts: solution.forecasts)
            details = Self.accuracyDetails(mad: solution.meanAbsoluteDeviation, mse: solution.meanSquaredError, mape: solution.meanAbsolutePercentageError) + [
                ForecastDetail(label: "Season length", value: "\(solution.seasonLength)"),
                ForecastDetail(label: "Intercept", value: Self.number(solution.intercept)),
                ForecastDetail(label: "Slope", value: Self.number(solution.slope))
            ] + solution.seasonalFactors.map {
                ForecastDetail(label: "Season \($0.seasonIndex) factor", value: Self.number($0.factor))
            }

        case (.regression(let model), .ordinaryLeastSquares(let solution)):
            valueName = model.dependentVariable
            fittedLabel = "Predicted"
            actual = solution.predictions.enumerated().map { index, point in
                ForecastChartPoint(index: index + 1, label: point.label, value: point.actual)
            }
            fitted = solution.predictions.enumerated().map { index, point in
                ForecastChartPoint(index: index + 1, label: point.label, value: point.predicted)
            }
            forecast = []
            residuals = solution.predictions.enumerated().map { index, point in
                ForecastChartPoint(index: index + 1, label: point.label, value: point.residual)
            }
            details = [
                ForecastDetail(label: "R²", value: Self.number(solution.rSquared)),
                ForecastDetail(label: "Sum squared errors", value: Self.number(solution.sumSquaredErrors)),
                ForecastDetail(label: "Intercept", value: Self.number(solution.intercept))
            ] + solution.coefficients.sorted { $0.key < $1.key }.map {
                ForecastDetail(label: $0.key, value: Self.number($0.value))
            }

        default:
            valueName = "Value"
            fittedLabel = "Fitted"
            actual = []
            fitted = []
            forecast = []
            residuals = []
            details = [ForecastDetail(label: "Status", value: "Model/solution mismatch")]
        }
    }

    private static func timeSeries(
        model: TimeSeriesModel,
        fitted fittedValues: [TimeSeriesTrendPoint],
        forecasts: [TimeSeriesForecast]
    ) -> ([ForecastChartPoint], [ForecastChartPoint], [ForecastChartPoint], [ForecastChartPoint]) {
        let actual = model.observations.enumerated().map { index, point in
            ForecastChartPoint(index: index + 1, label: point.label, value: point.value)
        }
        let fittedOffset = max(0, model.observations.count - fittedValues.count)
        let fitted = fittedValues.enumerated().map { index, point in
            ForecastChartPoint(index: fittedOffset + index + 1, label: point.label, value: point.fitted)
        }
        let residuals = fittedValues.enumerated().map { index, point in
            ForecastChartPoint(index: fittedOffset + index + 1, label: point.label, value: point.residual)
        }
        let forecast = forecasts.map {
            ForecastChartPoint(index: $0.periodIndex, label: $0.label, value: $0.value)
        }
        return (actual, fitted, forecast, residuals)
    }

    private static func accuracyDetails(mad: Double, mse: Double, mape: Double?) -> [ForecastDetail] {
        var result = [
            ForecastDetail(label: "Mean absolute deviation", value: number(mad)),
            ForecastDetail(label: "Mean squared error", value: number(mse))
        ]
        if let mape {
            result.append(ForecastDetail(label: "Mean absolute percentage error", value: "\(number(mape))%"))
        }
        return result
    }

    private static func methodName(_ method: ForecastingMethod) -> String {
        switch method {
        case .linearTrend: "Linear trend"
        case .movingAverage: "Moving average"
        case .exponentialSmoothing: "Exponential smoothing"
        case .multiplicativeSeasonalDecomposition: "Seasonal decomposition"
        case .ordinaryLeastSquares: "Ordinary least squares"
        }
    }

    static func number(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 1e-8 { return String(Int(rounded)) }
        return String(format: "%.3f", value)
    }
}

private struct ForecastChartPoint: Identifiable {
    let index: Int
    let label: String
    let value: Double

    var id: Int { index }
}

private struct ForecastDetail: Identifiable {
    let label: String
    let value: String

    var id: String { "\(label):\(value)" }
}

private extension SolverExactness {
    var displayName: String {
        switch self {
        case .exact: "Exact"
        case .closedForm: "Closed form"
        case .fixtureScale: "Fixture scale"
        case .heuristic: "Heuristic"
        case .approximate: "Approximate"
        }
    }
}
