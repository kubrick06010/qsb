# Normalized JSON

`qsb import-legacy-json <legacy-model-file>` is the generic conversion path for
all supported WinQSB model families. It expands SZDD input when needed, detects
the family from the restored legacy file type, parses the typed model in
`QSBCore`, and writes the family's normalized JSON to standard output.
QSBMacApp uses the same `LegacyModelImporter` route when opening a legacy model,
then loads the resulting JSON into the existing editor and solver workflow.

For forecasting files, generic import selects a runnable default request:
linear trend with a one-period horizon for time series, and ordinary least
squares for regression. Users can edit the normalized request to choose another
time-series method or parameters.

`qsb export-json` converts supported legacy WinQSB LP files into a stable JSON
model. `qsb solve-json` and `qsb solve-json-ilp` read the same format.

Network models use a tagged JSON envelope through `qsb export-network-json` and
`qsb solve-network-json`. The macOS shell can also import, edit, solve, and
export these normalized network JSON files.

PERT/CPM project models use a tagged `ProjectSchedulingModelEnvelope` with
historical kinds `CPM` and `PERT`. `qsb export-project-json` emits the model;
`solve-project-json` emits the model, backend metadata, and diagram-ready
activity timings; `validate-project-json` emits structured diagnostics.

Markov workflows use a `MarkovAnalysisRequest` containing the normalized chain
and transient horizon. `MarkovSolutionDocument` records backend metadata,
stationary probabilities and cost, plus period results when an initial
distribution exists. The commands are `export-markov-json`,
`solve-markov-json`, and `validate-markov-json`.

Goal Programming uses a `GoalProgram` with ordered goal rows plus the shared LP
constraint, bound, and variable-domain structures. `GoalProgrammingSolution`
records each lexicographic priority outcome and final variable values. Use
`export-goal-json`, `solve-goal-json`, and `validate-goal-json`.

Acceptance Sampling uses a tagged single/double model envelope. Solution JSON
contains actual AQL/RQL risks, plan metrics, and a diagram-ready OC curve. Use
`export-acceptance-json`, `solve-acceptance-json`, and
`validate-acceptance-json`.

Quality Control uses tagged model and solution envelopes for c, p, Xbar-R,
Pareto, and normal-probability-plot workflows. Control-chart solutions contain
per-point limits and outside-limit flags; Pareto and probability solutions
contain chart-ready series. Use `export-quality-json`, `solve-quality-json`,
and `validate-quality-json`.

Aggregate Planning uses a period-vector model shared by the legacy simple, LP,
and transportation methods. Solution documents contain backend metadata, total
cost, and period-level workforce, production, inventory, and backorder values.
Use `export-aggregate-json`, `solve-aggregate-json`, and
`validate-aggregate-json`.

Material Requirements Planning uses item, BOM, and MPS structures plus an
explicit `Overdue` bucket followed by the planning periods. Solution schedules
provide gross/net requirements, projected inventory, planned receipts/releases,
and capacity excess for every item and bucket. Use `export-mrp-json`,
`solve-mrp-json`, and `validate-mrp-json`.

Inventory `stochasticReview` models add a policy discriminator for continuous
fixed-order-quantity, continuous order-up-to, periodic fixed-interval, and
periodic optional-replenishment systems. Their typed solution contains service,
safety-stock, protection-period, expected-shortage, and cost metrics while
retaining the existing generic inventory JSON commands.

Quadratic Programming models encode a symmetric `quadraticMatrix` for the
objective `x^T Q x`, linear objective coefficients, shared linear constraints,
bounds, and variable domains. Solution JSON records active-set or integer
enumeration metadata, the objective, named values, and active constraints. Use
`export-qp-json`, `solve-qp-json`, and `validate-qp-json`.

Nonlinear Programming models preserve the objective and constraint expressions,
ordered variable names, nullable bounds, objective sense, and strict-inequality
normalization marker. Solution JSON contains backend metadata, named values,
constraint evaluations, maximum violation, and iteration/evaluation count. Use
`export-nlp-json`, `solve-nlp-json`, and `validate-nlp-json`.

Simulation models normalize Matrix and Graphic component networks into sources,
queues, servers, routes, capacities, and arrival/batch/service distributions.
Solution JSON records the deterministic seed and horizon plus throughput, queue,
rejection, completion, and utilization metrics. Use `export-simulation-json`,
`solve-simulation-json`, and `validate-simulation-json`.

Scheduling models use a `kind` discriminator (`flowShop` or `jobShop`) and a
typed `model` payload. Solutions retain Gantt-ready operations and machine
timelines. Use `export-scheduling-json`, `solve-scheduling-json`, and
`validate-scheduling-json`. The older family-specific `*-json` commands remain
legacy-input solution exporters.

Queuing models use a `kind` discriminator (`mm1` or `finiteCapacity`) and a
typed `model` payload. Common solutions include assumptions, utilization,
throughput, waiting metrics, state probabilities, and costs. Use
`export-queuing-json`, `solve-queuing-json`, and `validate-queuing-json`.

## LP/ILP Model Object

Required fields:

- `title`: string.
- `sense`: `"maximize"` or `"minimize"`.
- `variableNames`: array of strings.
- `objectiveCoefficients`: array of numbers, one per variable.
- `constraints`: array of constraint objects.
- `lowerBounds`: array of numbers, one per variable.
- `upperBounds`: array of numbers or `null`, one per variable.
- `variableTypes`: array containing `"continuous"`, `"integer"`, or `"binary"`,
  one per variable.

Constraint fields:

- `name`: string.
- `coefficients`: array of numbers, one per variable.
- `relation`: `"<="`, `">="`, or `"="`.
- `rhs`: number.

All coefficient arrays use the same order as `variableNames`.

The decoder validates that:

- `variableNames` is nonempty and contains unique, nonempty names.
- Objective coefficients, bounds, variable types, and each constraint
  coefficient row all have the same length as `variableNames`.
- Objective coefficients, constraint coefficients, RHS values, and bounds are
  finite numbers.
- Lower bounds are nonnegative.
- Upper bounds, when present, are greater than or equal to lower bounds.
- Binary variable bounds stay within `[0, 1]`.

## Example

```json
{
  "title": "ILP Sample Problem",
  "sense": "minimize",
  "variableNames": ["X1", "X2"],
  "objectiveCoefficients": [2.5, 2],
  "constraints": [
    {
      "name": "C1",
      "coefficients": [6, 3],
      "relation": ">=",
      "rhs": 200
    },
    {
      "name": "C2",
      "coefficients": [3, 5],
      "relation": ">=",
      "rhs": 180
    }
  ],
  "lowerBounds": [0, 0],
  "upperBounds": [null, null],
  "variableTypes": ["integer", "integer"]
}
```

## Commands

Export a legacy WinQSB LP file:

```sh
qsb export-json reference/winqsb/ILP.LP_ > model.json
```

Solve the continuous relaxation:

```sh
qsb solve-json model.json
```

Solve integer and binary variables with branch-and-bound:

```sh
qsb solve-json-ilp model.json
```

Solution output is JSON:

```json
{
  "objectiveValue": 101,
  "variableValues": {
    "X1": 22,
    "X2": 23
  }
}
```

## Network Model Envelope

Supported network JSON uses a top-level `kind` and typed `model` object:

```json
{
  "kind": "TSP",
  "model": {
    "title": "TSP",
    "nodes": ["LA", "DEV", "HOU"],
    "arcs": [
      { "from": "LA", "to": "DEV", "cost": 100 }
    ]
  }
}
```

Supported `kind` values:

- `CNF`: minimum-cost network flow/transshipment.
- `SPP`: shortest path.
- `MST`: minimum spanning tree.
- `MFP`: max flow.
- `TSP`: traveling salesperson.
- `AP`: assignment.
- `TP`: transportation.

Export any supported legacy WinQSB network file:

```sh
qsb export-network-json reference/winqsb/TSP.NE_ > network.json
```

Solve a normalized network model:

```sh
qsb solve-network-json network.json
```

Network solution output is a tagged JSON envelope:

```json
{
  "kind": "TSP",
  "solution": {
    "source": "LA",
    "totalCost": 1130,
    "tour": ["LA", "HOU", "NY", "CMH", "DAL", "DEV", "LA"]
  }
}
```

## Queuing Solution JSON

Queuing solution JSON uses one common document for M/M/1 and finite-capacity
models:

```sh
qsb solve-mm1-json reference/winqsb/QUEUE1.QA_ --backend native > mm1-solution.json
qsb solve-finite-queue-json reference/winqsb/QUEUE2.QA_ --backend native > finite-queue-solution.json
```

`QueuingSolutionDocument` records `kind`, backend metadata, title, time unit,
Kendall-style `notation`, explicit assumptions, normalized performance metrics,
state probabilities, and an optional normalized cost breakdown. Common metrics
include arrival and effective arrival rates, service rate per server, server and
capacity counts, utilization, empty and blocking probabilities, L, Lq, W, Wq,
and average customers being served.

The M/M/1 document reports algorithm `mm1ClosedForm` and exactness
`closedForm`. The finite-capacity document reports
`finiteCapacityBirthDeath` and exactness `approximate`; this distinction is
important for `QUEUE2.QA_`, whose service distribution is Normal and is reduced
to its mean service rate by the native backend.

## Scheduling Solution JSON

Scheduling solution JSON is emitted by the native backend for legacy flow-shop
and job-shop fixtures:

```sh
qsb solve-flowshop-json reference/winqsb/FLOWSHOP.JO_ --backend native > flowshop-solution.json
qsb solve-jobshop-json reference/winqsb/JOBSHOP.JO_ --backend native > jobshop-solution.json
```

The output is a `SchedulingSolutionDocument` with:

- `kind`: `flowShop` or `jobShop`.
- `backend`: backend kind, algorithm, exactness, and notes.
- `title`, `timeUnit`, `makespan`, `jobSequence`, and
  `machineCompletionTimes`.
- `operations`: flat Gantt records with job ID/name, operation index, machine
  ID/name, start, finish, duration, idle-before, and sequence index.
- `machineTimelines`: per-machine lanes with ready time, completion time, and
  operations.

A shortened excerpt:

```json
{
  "kind": "flowShop",
  "backend": {
    "backendKind": "nativeEducational",
    "algorithm": "flowShopPermutationSearch",
    "exactness": "fixtureScale",
    "notes": []
  },
  "makespan": 213,
  "operations": [
    {
      "jobID": 4,
      "jobName": "Job 4",
      "operationIndex": 1,
      "machineID": 1,
      "machineName": "Machine 1",
      "start": 0,
      "finish": 13,
      "duration": 13,
      "idleBefore": 0,
      "sequenceIndex": 1
    }
  ]
}
```

## Inventory Model and Solution Envelopes

Inventory uses a discriminated model envelope so one schema can represent all
currently supported variants:

```json
{
  "kind": "lotSizing",
  "model": {
    "title": "Inventory Problem",
    "timeUnit": "month",
    "periods": []
  }
}
```

Supported `kind` values are `eoq`, `quantityDiscountEOQ`, `newsboy`, and
`lotSizing`. The payload under `model` is the corresponding strongly typed
model. Export, validate, and solve with:

```sh
qsb export-inventory-json reference/winqsb/LOTSIZE.IT_ > inventory.json
qsb validate-inventory-json inventory.json
qsb solve-inventory-json inventory.json --backend native > inventory-solution.json
```

An `InventorySolutionDocument` contains:

- `kind`, `title`, and `timeUnit`;
- `backend` with backend kind, algorithm, exactness, and notes;
- `assumptions` describing the educational model boundary;
- `solution`, encoded as the typed solution for the selected kind.

Validation-only output contains `kind`, `backend`, `isValid`, and structured
`diagnostics`. `solve-inventory-json --backend validate` emits the same
validation document without invoking a solver.

## Forecasting Requests and Solutions

Forecasting JSON separates the reusable model from method parameters. A
`ForecastingRequest` contains `model`, `method`, `periodsAhead`, and optional
`windowSize`, `alpha`, or `seasonLength`. Model kinds are `timeSeries` and
`regression`; supported methods are `linearTrend`, `movingAverage`,
`exponentialSmoothing`, `multiplicativeSeasonalDecomposition`, and
`ordinaryLeastSquares`.

```sh
qsb export-forecast-json <legacy-fc-file> <trend|moving-average|exp-smoothing|seasonal|regression> [parameter] [periods-ahead]
qsb solve-forecast-json <forecasting-request-json-file> [--backend native|validate]
qsb validate-forecast-json <forecasting-request-json-file>
```

Solution documents include the original request, backend metadata, and a
method-discriminated result with fitted values, residuals, metrics, and future
forecasts where applicable.

## Network Solution Documents

Network model envelopes retain the historical kind codes `CNF`, `SPP`, `MST`,
`MFP`, `TSP`, `AP`, and `TP`. The enriched `NetworkSolutionDocument` contains the
original model, the existing discriminated path/tree/flow/tour/assignment/
shipment solution, and explicit backend algorithm and exactness metadata.

```sh
qsb export-network-json <legacy-network-file>
qsb solve-network-json <network-model-json-file> [--backend native|validate]
qsb validate-network-json <network-model-json-file>
```

Validation documents contain `kind`, `backend`, `isValid`, and structured
diagnostics for labels, endpoints, dimensions, finite nonnegative arc values,
assignment cardinality, TSP native limits, and transportation balance.

## Decision-Analysis Model Envelopes

Decision-analysis JSON uses `kind` plus `model` for payoff tables, Bayesian
analysis, decision trees, and zero-sum games. Solution documents preserve the
input model and discriminated solution, including posterior tables, EVSI/EVPI,
rollback node values and policy decisions, or mixed strategies.

```sh
qsb export-decision-json <legacy-da-file>
qsb solve-decision-json <decision-analysis-model-json-file> [--backend native|validate]
qsb validate-decision-json <decision-analysis-model-json-file>
```

Validation diagnostics cover probability distributions, dimensions, names,
tree references and node semantics. Rounded positive chance distributions are
reported as warnings and normalized during rollback.

## Dynamic-Programming Model Envelopes

Dynamic-programming JSON uses a discriminated envelope shared by bounded
knapsack, stagecoach, and production/inventory planning:

```json
{
  "kind": "boundedKnapsack",
  "model": {
    "title": "QSB P.112",
    "capacity": 20,
    "items": []
  }
}
```

Supported `kind` values are `boundedKnapsack`, `stagecoach`, and
`productionInventory`. Solution documents contain `backend`, `assumptions`,
and a discriminated `solution` with `result` plus educational `trace` rows.
Each trace row records `stage`, `state`, `action`, optional `nextState`, and
`value`. Validation documents contain `kind`, `backend`, `isValid`, and
structured `diagnostics`.

```sh
qsb export-dp-json <legacy-dp-file>
qsb solve-dp-json <dynamic-programming-model-json-file> [--backend native|validate]
qsb validate-dp-json <dynamic-programming-model-json-file>
```

## Facility Location and Line Balancing

Facilities JSON supports both family-specific commands and a generic facilities
envelope. The generic model envelope uses top-level `kind` and `model` fields;
the generic solution envelope uses `kind`, `backend`, and `solution`.

```json
{
  "kind": "location",
  "model": {
    "title": "Location Example 1"
  }
}
```

Supported facilities `kind` values:

- `lineBalancing`.
- `location`.
- `layout`.

Export and solve any supported legacy `FLL` fixture through the generic
envelope:

```sh
qsb export-facilities-json reference/winqsb/LOCATION.FL_ > facilities.json
qsb validate-facilities-json facilities.json > facilities-validation.json
qsb solve-facilities-json facilities.json --backend native > facilities-solution.json
```

Generic facilities validation JSON includes:

- `kind`: `lineBalancing`, `location`, or `layout`.
- `backend`: `validateOnly`.
- `isValid`: boolean validity summary.
- `diagnostics`: structured validation diagnostics with severity, code,
  message, and optional path.

Generic facilities solution envelopes include backend metadata:

- `backendKind`: currently `nativeEducational` for native solves.
- `algorithm`: the native method used, such as `weightedCentroid`,
  `bitmaskDynamicProgramming`, or `pairwiseSameSizeSwapLocalSearch`.
- `exactness`: one of `exact`, `heuristic`, `approximate`, `closedForm`, or
  `fixtureScale`.
- `notes`: short caveats for fixture-scale or iterative methods.

Family-specific commands mirror the legacy facilities commands while keeping
model and solution JSON separate.

Export and solve the bundled single-new-facility location fixture:

```sh
qsb export-location-json reference/winqsb/LOCATION.FL_ > location.json
qsb solve-location-json location.json --backend native > location-solution.json
```

`FacilityLocationSolution` JSON includes:

- `distanceMeasure`: `rectilinear`, `squaredEuclidean`, or `euclidean`.
- `objectiveValue`: weighted distance for the placed new facility.
- `placements`: new facility coordinates plus per-existing-facility
  interaction distances and weighted distances.

Export and solve the bundled assembly line-balancing fixture:

```sh
qsb export-line-balancing-json reference/winqsb/LINEBAL.FL_ > line-balancing.json
qsb solve-line-balancing-json line-balancing.json --backend native > line-balancing-solution.json
```

`LineBalancingSolution` JSON includes:

- `stationCount`, `totalTaskTime`, `cycleTime`, `efficiency`, and
  `balanceDelay`.
- `stations`: station index, task IDs, task names, workload, and idle time.

The validate-only backend can be used on either normalized model:

```sh
qsb solve-location-json location.json --backend validate
qsb solve-line-balancing-json line-balancing.json --backend validate
```

## Facility Layout Model and Solution

Facility layout JSON stores the parsed `FLL ... LAYOUT` model as a normalized
`FacilityLayoutProblem`. It includes the grid, departments, initial placements,
fixed departments, and flow/unit-cost interactions.

Export the bundled WinQSB layout fixture:

```sh
qsb export-layout-json reference/winqsb/LAYOUT.FL_ > layout.json
```

Solve a normalized layout model with the default initial-layout evaluation:

```sh
qsb solve-layout-json layout.json --backend native > layout-solution.json
```

Run the fixture-scale educational pairwise-swap heuristic:

```sh
qsb solve-layout-json layout.json --backend native --layout-strategy pairwise-swap > layout-solution.json
```

The default native layout backend evaluates the initial arrangement. The optional
`pairwise-swap` strategy repeatedly swaps non-fixed departments with the same
cell count when the swap improves centroid-based rectilinear load-distance.
Solution JSON includes:

- `objective`: the legacy objective code, currently `"MIN"`.
- `objectiveValue`: the centroid-based rectilinear load-distance value.
- `source`: `"initialLayoutEvaluation"` or `"pairwiseSwapLocalSearch"`.
- `search`: strategy, evaluated move count, applied move count, initial value,
  final value, and improvement when a search strategy is used.
- `moves`: applied pairwise swaps with before/after rectangles and improvement.
- `placements`: department rectangles and centroids for rendering.
- `interactions`: nonzero flow/unit-cost/distance/load records.

The validate-only backend can be used on the same normalized model:

```sh
qsb solve-layout-json layout.json --backend validate
```
