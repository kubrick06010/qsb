import Foundation

public struct RegressionObservation: Codable, Equatable, Sendable {
    public let label: String
    public let dependentValue: Double
    public let independentValues: [Double]

    public init(label: String, dependentValue: Double, independentValues: [Double]) {
        self.label = label
        self.dependentValue = dependentValue
        self.independentValues = independentValues
    }
}

public struct RegressionModel: Codable, Equatable, Sendable {
    public let title: String
    public let dependentVariable: String
    public let independentVariables: [String]
    public let observations: [RegressionObservation]

    public init(
        title: String,
        dependentVariable: String,
        independentVariables: [String],
        observations: [RegressionObservation]
    ) {
        self.title = title
        self.dependentVariable = dependentVariable
        self.independentVariables = independentVariables
        self.observations = observations
    }
}

public struct RegressionPrediction: Codable, Equatable, Sendable {
    public let label: String
    public let actual: Double
    public let predicted: Double
    public let residual: Double
}

public struct RegressionSolution: Codable, Equatable, Sendable {
    public let intercept: Double
    public let coefficients: [String: Double]
    public let sumSquaredErrors: Double
    public let rSquared: Double
    public let predictions: [RegressionPrediction]
}

public struct TimeSeriesObservation: Codable, Equatable, Sendable {
    public let label: String
    public let value: Double

    public init(label: String, value: Double) {
        self.label = label
        self.value = value
    }
}

public struct TimeSeriesModel: Codable, Equatable, Sendable {
    public let title: String
    public let timeUnit: String
    public let valueName: String
    public let observations: [TimeSeriesObservation]

    public init(
        title: String,
        timeUnit: String,
        valueName: String,
        observations: [TimeSeriesObservation]
    ) {
        self.title = title
        self.timeUnit = timeUnit
        self.valueName = valueName
        self.observations = observations
    }
}

public struct TimeSeriesTrendPoint: Codable, Equatable, Sendable {
    public let label: String
    public let actual: Double
    public let fitted: Double
    public let residual: Double
}

public struct TimeSeriesForecast: Codable, Equatable, Sendable {
    public let periodIndex: Int
    public let label: String
    public let value: Double
}

public struct TimeSeriesTrendSolution: Codable, Equatable, Sendable {
    public let intercept: Double
    public let slope: Double
    public let meanActual: Double
    public let meanAbsoluteDeviation: Double
    public let meanSquaredError: Double
    public let meanAbsolutePercentageError: Double?
    public let fittedValues: [TimeSeriesTrendPoint]
    public let forecasts: [TimeSeriesForecast]
}

public struct TimeSeriesMovingAverageSolution: Codable, Equatable, Sendable {
    public let windowSize: Int
    public let meanAbsoluteDeviation: Double
    public let meanSquaredError: Double
    public let meanAbsolutePercentageError: Double?
    public let fittedValues: [TimeSeriesTrendPoint]
    public let forecasts: [TimeSeriesForecast]
}

public struct TimeSeriesExponentialSmoothingSolution: Codable, Equatable, Sendable {
    public let alpha: Double
    public let initialForecast: Double
    public let meanAbsoluteDeviation: Double
    public let meanSquaredError: Double
    public let meanAbsolutePercentageError: Double?
    public let fittedValues: [TimeSeriesTrendPoint]
    public let forecasts: [TimeSeriesForecast]
}

public struct TimeSeriesSeasonalFactor: Codable, Equatable, Sendable {
    public let seasonIndex: Int
    public let factor: Double
}

public struct TimeSeriesSeasonalDecompositionSolution: Codable, Equatable, Sendable {
    public let seasonLength: Int
    public let intercept: Double
    public let slope: Double
    public let meanActual: Double
    public let seasonalFactors: [TimeSeriesSeasonalFactor]
    public let meanAbsoluteDeviation: Double
    public let meanSquaredError: Double
    public let meanAbsolutePercentageError: Double?
    public let fittedValues: [TimeSeriesTrendPoint]
    public let forecasts: [TimeSeriesForecast]
}

public enum ForecastingModelError: Error, CustomStringConvertible {
    case unsupportedFormat
    case unsupportedModel(String)
    case invalidNumericValue(String)
    case invalidModel(String)

    public var description: String {
        switch self {
        case .unsupportedFormat:
            "Unsupported forecasting model format"
        case .unsupportedModel(let detail):
            "Unsupported forecasting model: \(detail)"
        case .invalidNumericValue(let value):
            "Invalid numeric value: \(value)"
        case .invalidModel(let detail):
            "Invalid forecasting model: \(detail)"
        }
    }
}

public enum WinQSBForecastingParser {
    public static func parseTimeSeries(from data: Data) throws -> TimeSeriesModel {
        let lines = try tabularLines(from: data)

        guard let metadata = lines.first,
              metadata.count >= 5,
              metadata[0] == "FC",
              metadata[2] == "0",
              let observationCount = Int(metadata[4]),
              observationCount > 0,
              lines.count >= observationCount + 2
        else {
            throw ForecastingModelError.unsupportedFormat
        }

        let header = lines[1]
        guard header.count >= 2 else {
            throw ForecastingModelError.unsupportedFormat
        }

        let observations = try lines[2..<(2 + observationCount)].map { row in
            guard row.count >= 2 else {
                throw ForecastingModelError.unsupportedFormat
            }
            return TimeSeriesObservation(
                label: row[0],
                value: try parseDouble(row[1])
            )
        }

        return TimeSeriesModel(
            title: metadata[1],
            timeUnit: metadata[3],
            valueName: header[1],
            observations: observations
        )
    }

    public static func parseRegression(from data: Data) throws -> RegressionModel {
        let lines = try tabularLines(from: data)

        guard let metadata = lines.first,
              metadata.count >= 5,
              metadata[0] == "FC",
              metadata[2] == "1",
              let variableColumnCount = Int(metadata[3]),
              let observationCount = Int(metadata[4]),
              variableColumnCount >= 2,
              observationCount > 0,
              lines.count >= observationCount + 2
        else {
            throw ForecastingModelError.unsupportedFormat
        }

        let header = lines[1]
        guard header.count >= variableColumnCount + 1 else {
            throw ForecastingModelError.unsupportedFormat
        }

        let dependentVariable = header[1]
        let independentVariables = Array(header[2...variableColumnCount])
        guard lines.count >= observationCount + 2 else {
            throw ForecastingModelError.unsupportedFormat
        }

        let observations = try lines[2..<(2 + observationCount)].map { row in
            guard row.count >= variableColumnCount + 1 else {
                throw ForecastingModelError.unsupportedFormat
            }
            return RegressionObservation(
                label: row[0],
                dependentValue: try parseDouble(row[1]),
                independentValues: try row[2...variableColumnCount].map(parseDouble)
            )
        }

        return RegressionModel(
            title: metadata[1],
            dependentVariable: dependentVariable,
            independentVariables: independentVariables,
            observations: observations
        )
    }

    private static func tabularLines(from data: Data) throws -> [[String]] {
        guard let text = data.legacyLatin1String else {
            throw ForecastingModelError.unsupportedFormat
        }

        return text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(clean) }
    }

    private static func clean(_ value: Substring) -> String {
        String(value).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseDouble(_ value: String) throws -> Double {
        guard let number = Double(value), number.isFinite else {
            throw ForecastingModelError.invalidNumericValue(value)
        }
        return number
    }
}

private struct TimeSeriesAccuracy {
    let meanAbsoluteDeviation: Double
    let meanSquaredError: Double
    let meanAbsolutePercentageError: Double?
}

private func calculateAccuracy(for points: [TimeSeriesTrendPoint]) -> TimeSeriesAccuracy {
    let count = Double(points.count)
    let meanAbsoluteDeviation = points.reduce(0.0) { partial, point in
        partial + abs(point.residual)
    } / count
    let meanSquaredError = points.reduce(0.0) { partial, point in
        partial + point.residual * point.residual
    } / count
    let nonzeroActuals = points.filter { abs($0.actual) > 1e-12 }
    let meanAbsolutePercentageError = nonzeroActuals.isEmpty ? nil : nonzeroActuals.reduce(0.0) { partial, point in
        partial + abs(point.residual / point.actual)
    } / Double(nonzeroActuals.count) * 100.0

    return TimeSeriesAccuracy(
        meanAbsoluteDeviation: meanAbsoluteDeviation,
        meanSquaredError: meanSquaredError,
        meanAbsolutePercentageError: meanAbsolutePercentageError
    )
}

private func forecastLabel(timeUnit: String, periodIndex: Int) -> String {
    guard !timeUnit.isEmpty else {
        return "\(periodIndex)"
    }
    return "\(timeUnit) \(periodIndex)"
}

private func validateTimeSeriesBasics(_ model: TimeSeriesModel) throws {
    guard !model.valueName.isEmpty else {
        throw ForecastingModelError.invalidModel("time series value name must not be empty")
    }
    guard model.observations.allSatisfy({ !$0.label.isEmpty && $0.value.isFinite }) else {
        throw ForecastingModelError.invalidModel("time series observations must have labels and finite values")
    }
}

public enum TimeSeriesTrendSolver {
    public static func solve(_ model: TimeSeriesModel, periodsAhead: Int = 1) throws -> TimeSeriesTrendSolution {
        try validate(model, periodsAhead: periodsAhead)

        let values = model.observations.map(\.value)
        let count = values.count
        let meanTime = Double(count + 1) / 2.0
        let meanActual = values.reduce(0, +) / Double(count)

        var centeredCrossProduct = 0.0
        var centeredTimeSquares = 0.0
        for index in values.indices {
            let time = Double(index + 1)
            let centeredTime = time - meanTime
            centeredCrossProduct += centeredTime * (values[index] - meanActual)
            centeredTimeSquares += centeredTime * centeredTime
        }

        let slope = centeredCrossProduct / centeredTimeSquares
        let intercept = meanActual - slope * meanTime

        let fittedValues = model.observations.enumerated().map { index, observation in
            let fitted = intercept + slope * Double(index + 1)
            return TimeSeriesTrendPoint(
                label: observation.label,
                actual: observation.value,
                fitted: fitted,
                residual: observation.value - fitted
            )
        }

        let meanAbsoluteDeviation = fittedValues.reduce(0.0) { partial, point in
            partial + abs(point.residual)
        } / Double(count)
        let meanSquaredError = fittedValues.reduce(0.0) { partial, point in
            partial + point.residual * point.residual
        } / Double(count)

        let nonzeroActuals = fittedValues.filter { abs($0.actual) > 1e-12 }
        let meanAbsolutePercentageError = nonzeroActuals.isEmpty ? nil : nonzeroActuals.reduce(0.0) { partial, point in
            partial + abs(point.residual / point.actual)
        } / Double(nonzeroActuals.count) * 100.0

        let forecasts = (1...periodsAhead).map { offset in
            let periodIndex = count + offset
            return TimeSeriesForecast(
                periodIndex: periodIndex,
                label: forecastLabel(timeUnit: model.timeUnit, periodIndex: periodIndex),
                value: intercept + slope * Double(periodIndex)
            )
        }

        return TimeSeriesTrendSolution(
            intercept: intercept,
            slope: slope,
            meanActual: meanActual,
            meanAbsoluteDeviation: meanAbsoluteDeviation,
            meanSquaredError: meanSquaredError,
            meanAbsolutePercentageError: meanAbsolutePercentageError,
            fittedValues: fittedValues,
            forecasts: forecasts
        )
    }

    private static func validate(_ model: TimeSeriesModel, periodsAhead: Int) throws {
        try validateTimeSeriesBasics(model)
        guard model.observations.count >= 2 else {
            throw ForecastingModelError.invalidModel("linear trend requires at least two observations")
        }
        guard periodsAhead > 0 else {
            throw ForecastingModelError.invalidModel("forecast horizon must be positive")
        }
    }
}

public enum TimeSeriesMovingAverageSolver {
    public static func solve(
        _ model: TimeSeriesModel,
        windowSize: Int,
        periodsAhead: Int = 1
    ) throws -> TimeSeriesMovingAverageSolution {
        try validate(model, windowSize: windowSize, periodsAhead: periodsAhead)

        let values = model.observations.map(\.value)
        let fittedValues = (windowSize..<values.count).map { index in
            let fitted = average(values[(index - windowSize)..<index])
            return TimeSeriesTrendPoint(
                label: model.observations[index].label,
                actual: values[index],
                fitted: fitted,
                residual: values[index] - fitted
            )
        }
        let accuracy = calculateAccuracy(for: fittedValues)

        var rollingValues = values
        let forecasts = (1...periodsAhead).map { offset in
            let periodIndex = values.count + offset
            let forecast = average(rollingValues.suffix(windowSize))
            rollingValues.append(forecast)
            return TimeSeriesForecast(
                periodIndex: periodIndex,
                label: forecastLabel(timeUnit: model.timeUnit, periodIndex: periodIndex),
                value: forecast
            )
        }

        return TimeSeriesMovingAverageSolution(
            windowSize: windowSize,
            meanAbsoluteDeviation: accuracy.meanAbsoluteDeviation,
            meanSquaredError: accuracy.meanSquaredError,
            meanAbsolutePercentageError: accuracy.meanAbsolutePercentageError,
            fittedValues: fittedValues,
            forecasts: forecasts
        )
    }

    private static func validate(_ model: TimeSeriesModel, windowSize: Int, periodsAhead: Int) throws {
        try validateTimeSeriesBasics(model)
        guard windowSize > 0 else {
            throw ForecastingModelError.invalidModel("moving average window size must be positive")
        }
        guard model.observations.count > windowSize else {
            throw ForecastingModelError.invalidModel("moving average requires more observations than the window size")
        }
        guard periodsAhead > 0 else {
            throw ForecastingModelError.invalidModel("forecast horizon must be positive")
        }
    }

    private static func average<S: Sequence>(_ values: S) -> Double where S.Element == Double {
        let values = Array(values)
        return values.reduce(0, +) / Double(values.count)
    }
}

public enum TimeSeriesExponentialSmoothingSolver {
    public static func solve(
        _ model: TimeSeriesModel,
        alpha: Double,
        periodsAhead: Int = 1
    ) throws -> TimeSeriesExponentialSmoothingSolution {
        try validate(model, alpha: alpha, periodsAhead: periodsAhead)

        let values = model.observations.map(\.value)
        let initialForecast = values[0]
        var currentForecast = initialForecast
        var fittedValues: [TimeSeriesTrendPoint] = []

        for index in 1..<values.count {
            let actual = values[index]
            fittedValues.append(TimeSeriesTrendPoint(
                label: model.observations[index].label,
                actual: actual,
                fitted: currentForecast,
                residual: actual - currentForecast
            ))
            currentForecast = alpha * actual + (1 - alpha) * currentForecast
        }

        let accuracy = calculateAccuracy(for: fittedValues)
        let forecasts = (1...periodsAhead).map { offset in
            let periodIndex = values.count + offset
            return TimeSeriesForecast(
                periodIndex: periodIndex,
                label: forecastLabel(timeUnit: model.timeUnit, periodIndex: periodIndex),
                value: currentForecast
            )
        }

        return TimeSeriesExponentialSmoothingSolution(
            alpha: alpha,
            initialForecast: initialForecast,
            meanAbsoluteDeviation: accuracy.meanAbsoluteDeviation,
            meanSquaredError: accuracy.meanSquaredError,
            meanAbsolutePercentageError: accuracy.meanAbsolutePercentageError,
            fittedValues: fittedValues,
            forecasts: forecasts
        )
    }

    private static func validate(_ model: TimeSeriesModel, alpha: Double, periodsAhead: Int) throws {
        try validateTimeSeriesBasics(model)
        guard model.observations.count >= 2 else {
            throw ForecastingModelError.invalidModel("exponential smoothing requires at least two observations")
        }
        guard alpha > 0, alpha <= 1, alpha.isFinite else {
            throw ForecastingModelError.invalidModel("exponential smoothing alpha must be in the range (0, 1]")
        }
        guard periodsAhead > 0 else {
            throw ForecastingModelError.invalidModel("forecast horizon must be positive")
        }
    }
}

public enum TimeSeriesSeasonalDecompositionSolver {
    public static func solve(
        _ model: TimeSeriesModel,
        seasonLength: Int,
        periodsAhead: Int = 1
    ) throws -> TimeSeriesSeasonalDecompositionSolution {
        try validate(model, seasonLength: seasonLength, periodsAhead: periodsAhead)

        let values = model.observations.map(\.value)
        let count = values.count
        let meanTime = Double(count + 1) / 2.0
        let meanActual = values.reduce(0, +) / Double(count)

        var centeredCrossProduct = 0.0
        var centeredTimeSquares = 0.0
        for index in values.indices {
            let time = Double(index + 1)
            let centeredTime = time - meanTime
            centeredCrossProduct += centeredTime * (values[index] - meanActual)
            centeredTimeSquares += centeredTime * centeredTime
        }

        let slope = centeredCrossProduct / centeredTimeSquares
        let intercept = meanActual - slope * meanTime
        let trendValues = values.indices.map { index in
            intercept + slope * Double(index + 1)
        }

        var ratioBuckets = Array(repeating: [Double](), count: seasonLength)
        for index in values.indices {
            let trend = trendValues[index]
            guard abs(trend) > 1e-12 else {
                throw ForecastingModelError.invalidModel(
                    "multiplicative seasonal decomposition requires nonzero trend values"
                )
            }
            ratioBuckets[index % seasonLength].append(values[index] / trend)
        }

        let rawSeasonalFactors = ratioBuckets.map { ratios in
            ratios.reduce(0, +) / Double(ratios.count)
        }
        let normalizer = rawSeasonalFactors.reduce(0, +) / Double(seasonLength)
        guard abs(normalizer) > 1e-12, normalizer.isFinite else {
            throw ForecastingModelError.invalidModel("seasonal factors cannot be normalized")
        }

        let seasonalFactors = rawSeasonalFactors.enumerated().map { index, factor in
            TimeSeriesSeasonalFactor(seasonIndex: index + 1, factor: factor / normalizer)
        }

        let fittedValues = model.observations.enumerated().map { index, observation in
            let fitted = trendValues[index] * seasonalFactors[index % seasonLength].factor
            return TimeSeriesTrendPoint(
                label: observation.label,
                actual: observation.value,
                fitted: fitted,
                residual: observation.value - fitted
            )
        }
        let accuracy = calculateAccuracy(for: fittedValues)

        let forecasts = (1...periodsAhead).map { offset in
            let periodIndex = count + offset
            let trend = intercept + slope * Double(periodIndex)
            let factor = seasonalFactors[(periodIndex - 1) % seasonLength].factor
            return TimeSeriesForecast(
                periodIndex: periodIndex,
                label: forecastLabel(timeUnit: model.timeUnit, periodIndex: periodIndex),
                value: trend * factor
            )
        }

        return TimeSeriesSeasonalDecompositionSolution(
            seasonLength: seasonLength,
            intercept: intercept,
            slope: slope,
            meanActual: meanActual,
            seasonalFactors: seasonalFactors,
            meanAbsoluteDeviation: accuracy.meanAbsoluteDeviation,
            meanSquaredError: accuracy.meanSquaredError,
            meanAbsolutePercentageError: accuracy.meanAbsolutePercentageError,
            fittedValues: fittedValues,
            forecasts: forecasts
        )
    }

    private static func validate(_ model: TimeSeriesModel, seasonLength: Int, periodsAhead: Int) throws {
        try validateTimeSeriesBasics(model)
        guard seasonLength > 1 else {
            throw ForecastingModelError.invalidModel("season length must be greater than one")
        }
        guard model.observations.count >= seasonLength * 2 else {
            throw ForecastingModelError.invalidModel(
                "seasonal decomposition requires at least two complete seasons"
            )
        }
        guard periodsAhead > 0 else {
            throw ForecastingModelError.invalidModel("forecast horizon must be positive")
        }
    }
}

public enum RegressionSolver {
    public static func solve(_ model: RegressionModel) throws -> RegressionSolution {
        try validate(model)

        let parameterCount = model.independentVariables.count + 1
        let design = model.observations.map { observation in
            [1.0] + observation.independentValues
        }
        let dependentValues = model.observations.map(\.dependentValue)

        var normalMatrix = Array(
            repeating: Array(repeating: 0.0, count: parameterCount),
            count: parameterCount
        )
        var normalRHS = Array(repeating: 0.0, count: parameterCount)

        for rowIndex in design.indices {
            let row = design[rowIndex]
            for column in 0..<parameterCount {
                normalRHS[column] += row[column] * dependentValues[rowIndex]
                for otherColumn in 0..<parameterCount {
                    normalMatrix[column][otherColumn] += row[column] * row[otherColumn]
                }
            }
        }

        let parameters = try solveLinearSystem(normalMatrix, normalRHS)
        let predictions = model.observations.enumerated().map { index, observation in
            let predicted = zip(design[index], parameters).reduce(0.0) { partial, pair in
                partial + pair.0 * pair.1
            }
            return RegressionPrediction(
                label: observation.label,
                actual: observation.dependentValue,
                predicted: predicted,
                residual: observation.dependentValue - predicted
            )
        }

        let sumSquaredErrors = predictions.reduce(0.0) { partial, prediction in
            partial + prediction.residual * prediction.residual
        }
        let mean = dependentValues.reduce(0, +) / Double(dependentValues.count)
        let totalSumSquares = dependentValues.reduce(0.0) { partial, value in
            let centered = value - mean
            return partial + centered * centered
        }
        let rSquared = totalSumSquares > 1e-12 ? 1 - sumSquaredErrors / totalSumSquares : 1

        let coefficients = Dictionary(uniqueKeysWithValues: model.independentVariables.enumerated().map {
            ($0.element, parameters[$0.offset + 1])
        })

        return RegressionSolution(
            intercept: parameters[0],
            coefficients: coefficients,
            sumSquaredErrors: sumSquaredErrors,
            rSquared: rSquared,
            predictions: predictions
        )
    }

    private static func validate(_ model: RegressionModel) throws {
        guard !model.dependentVariable.isEmpty else {
            throw ForecastingModelError.invalidModel("dependent variable name must not be empty")
        }
        guard !model.independentVariables.isEmpty else {
            throw ForecastingModelError.invalidModel("at least one independent variable is required")
        }
        guard model.observations.count > model.independentVariables.count else {
            throw ForecastingModelError.invalidModel("regression requires more observations than independent variables")
        }
        guard Set(model.independentVariables).count == model.independentVariables.count else {
            throw ForecastingModelError.invalidModel("independent variable names must be unique")
        }

        for observation in model.observations {
            guard observation.dependentValue.isFinite,
                  observation.independentValues.count == model.independentVariables.count,
                  observation.independentValues.allSatisfy(\.isFinite)
            else {
                throw ForecastingModelError.invalidModel("observation dimensions and values must be valid")
            }
        }
    }

    private static func solveLinearSystem(_ matrix: [[Double]], _ rhs: [Double]) throws -> [Double] {
        let count = rhs.count
        var augmented = matrix.enumerated().map { rowIndex, row in
            row + [rhs[rowIndex]]
        }

        for pivotIndex in 0..<count {
            guard let bestRow = (pivotIndex..<count).max(by: {
                abs(augmented[$0][pivotIndex]) < abs(augmented[$1][pivotIndex])
            }), abs(augmented[bestRow][pivotIndex]) > 1e-12 else {
                throw ForecastingModelError.invalidModel("regression design matrix is singular")
            }
            if bestRow != pivotIndex {
                augmented.swapAt(bestRow, pivotIndex)
            }

            let pivot = augmented[pivotIndex][pivotIndex]
            for column in pivotIndex...count {
                augmented[pivotIndex][column] /= pivot
            }

            for row in 0..<count where row != pivotIndex {
                let factor = augmented[row][pivotIndex]
                guard abs(factor) > 1e-15 else { continue }
                for column in pivotIndex...count {
                    augmented[row][column] -= factor * augmented[pivotIndex][column]
                }
            }
        }

        return augmented.map { $0[count] }
    }
}
