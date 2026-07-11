# Normalized JSON

`qsb export-json` converts supported legacy WinQSB LP files into a stable JSON
model. `qsb solve-json` and `qsb solve-json-ilp` read the same format.

Network models use a tagged JSON envelope through `qsb export-network-json` and
`qsb solve-network-json`. The macOS shell can also import, edit, solve, and
export these normalized network JSON files.

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
