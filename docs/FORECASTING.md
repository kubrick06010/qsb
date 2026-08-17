# Forecasting

The forecasting module supports legacy WinQSB time-series and multiple linear
regression files.

The normalized workflow uses `ForecastingRequest`: it combines a reusable
time-series or regression model with the selected method and its parameters.
`ForecastingBackend` provides `nativeEducational` and `validateOnly` modes;
`externalHighPerformance` is reserved for future integrations. Structured
solutions retain fitted values, residuals, accuracy metrics, forecasts, method
parameters, and backend metadata.

```sh
qsb export-forecast-json reference/winqsb/SALES.FC_ trend 2 > forecast.json
qsb solve-forecast-json forecast.json --backend native
qsb validate-forecast-json forecast.json
```

Supported input:

- Legacy WinQSB `FC ... 0 ...` univariate time-series files.
- Legacy WinQSB `FC ... 1 ...` regression files.
- Compressed `SZDD` fixtures such as `reference/winqsb/SALES.FC_`.
- Compressed `SZDD` fixtures such as `reference/winqsb/LINEREG.FC_`.
- One dependent variable and one or more independent variables.

For time series, the core supports least-squares linear trend, simple moving
average, simple exponential smoothing, and multiplicative seasonal
decomposition. Each method reports fitted values, residuals, MAD, MSE, MAPE,
and one or more future forecasts.

Run:

```sh
qsb solve-timeseries reference/winqsb/SALES.FC_ 2
qsb solve-moving-average reference/winqsb/SALES.FC_ 3 2
qsb solve-exp-smoothing reference/winqsb/SALES.FC_ 0.3 2
qsb solve-seasonal reference/winqsb/SALES.FC_ 12 2
```

Linear trend example output:

```text
Sales
timeUnit: month
value: Historical Data
method: linearTrend
intercept: 364.007246
slope: 7.856087
meanActual: 462.208333
mad: 19.660399
mse: 763.505864
mape: 4.756017
...
month 25: forecast 560.409420
month 26: forecast 568.265507
```

Moving average example output:

```text
Sales
timeUnit: month
value: Historical Data
method: movingAverage
windowSize: 3
mad: 27.333333
mse: 1038.126984
mape: 5.787622
...
month 25: forecast 561.666667
month 26: forecast 565.555556
```

Exponential smoothing example output:

```text
Sales
timeUnit: month
value: Historical Data
method: exponentialSmoothing
alpha: 0.300000
initialForecast: 398
mad: 33.065444
mse: 1584.054282
mape: 7.548063
...
month 25: forecast 542.070830
month 26: forecast 542.070830
```

Seasonal decomposition example output:

```text
Sales
timeUnit: month
value: Historical Data
method: multiplicativeSeasonalDecomposition
seasonLength: 12
intercept: 364.007246
slope: 7.856087
meanActual: 462.208333
seasonalFactors:
season 1: 1.049992
season 2: 1.010615
...
mad: 13.815134
mse: 356.955914
mape: 3.256968
...
month 25: forecast 588.425665
month 26: forecast 574.297443
```

For regression, the solver uses ordinary least squares with an intercept term.

Run:

```sh
qsb solve-regression reference/winqsb/LINEREG.FC_
```

Example output:

```text
QSB P.320
dependent: Utility
intercept: -79.740163
Temperature: 3.121079
Insulation: -1.169119
sse: 945.092894
rSquared: 0.903620
```

## macOS Workbench Charts

QSBMacApp decodes the same `ForecastingSolutionDocument` emitted by the shared
backend and offers a native Chart/JSON presentation for every supported method.

- Linear trend, moving average, exponential smoothing, and multiplicative
  seasonal decomposition show actual, fitted, and future forecast series on a
  common time axis.
- Ordinary least squares shows actual and predicted dependent values by
  observation.
- A signed residual area/line view shares the observation axis and distinguishes
  negative residual points.
- The model summary displays MAD, MSE, MAPE, trend/smoothing/seasonal parameters,
  or OLS R-squared, SSE, intercept, and coefficients as applicable.
- Visibility checkboxes and horizontal scale controls support both compact and
  wide windows; the normalized JSON document remains available at all times.
- The native Forecasting definition editor supports all five methods with a
  discriminated app-internal draft, ordered historical rows, typed method
  parameters, explicit forecast horizon controls where supported, and a
  structured accessible values table.
- Normalized and legacy imports populate the same editor. JSON is an explicit
  advanced surface and Apply JSON updates the draft only after decoding
  succeeds.
- The historical-data editor supports standard macOS Command-V plain-text
  paste from Excel, Numbers, and other tabular applications. One numeric
  column replaces values in order; two tab-separated columns replace period
  labels and values. The complete paste is parsed and validated atomically,
  with malformed or extra-column input rejected without partial mutation.

Swift Charts is used only to present typed results. Parsing, validation,
forecasting, regression, and metric calculation remain in QSBCore behind
`ForecastingBackend`.
