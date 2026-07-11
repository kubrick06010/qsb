# Facilities

The facilities module supports legacy WinQSB location, line-balancing, and
layout fixtures.

All three families use the named `FacilitiesBackend` interface in `QSBCore`.
`NativeEducationalFacilitiesBackend` validates and solves models, while
`ValidateOnlyFacilitiesBackend` returns the same structured diagnostics without
solving. `FacilitiesBackends` reserves the selection point for a future
`externalHighPerformance` implementation. Legacy, family-specific JSON, and
generic facilities-envelope CLI workflows all route through this interface.

Supported input:

- Legacy WinQSB `FLL ... LINE BALANCING ...` files.
- Legacy WinQSB `FLL ... LOCATION ...` files with one new facility.
- Legacy WinQSB `FLL ... LAYOUT ...` files with grid cell locations.
- Compressed `SZDD` fixtures such as `reference/winqsb/LINEBAL.FL_`.
- Compressed `SZDD` fixtures such as `reference/winqsb/LOCATION.FL_`.
- Compressed `SZDD` fixtures such as `reference/winqsb/LAYOUT.FL_`.
- Task times, isolated-task flags, and immediate successor relationships.
- A fixed cycle time.
- Existing facility coordinates and flow/unit-cost interactions to the new
  facility.
- Department flow/unit-cost matrices and initial layout cell rectangles.

The location solver supports the bundled single-new-facility fixture. It uses
weighted medians for rectilinear distance, weighted centroids for squared
Euclidean distance, and Weiszfeld iteration for Euclidean distance. The
`LOCATION.FL_` fixture uses distance-measure code `2`, matching the original
binary label for squared Euclidean distance. Location supports
`nativeEducational` and `validateOnly` backends.

The line-balancing solver uses exact bitmask dynamic programming for
fixture-scale assembly line balancing. It minimizes station count, then reports
station workloads, idle time, line efficiency, and balance delay. The current
exact solver rejects instances with more than 24 tasks. Validation reports that
fixture-scale limit as a warning before native solve enforces it.

The layout backend evaluates the bundled initial layout by default. It parses
department rectangles, fixed departments, and flow/unit-cost values, then reports
centroid-based rectilinear load-distance for the starting arrangement. It also
supports a fixture-scale educational `pairwise-swap` strategy that repeatedly
swaps non-fixed departments with the same cell count when the swap improves the
load-distance objective.
The `LAYOUT.FL_` fixture includes a fixed aisle/cross area that shares three
cells with one department; validation reports those as warnings while still
accepting the official fixture.

Run:

```sh
qsb validate-location reference/winqsb/LOCATION.FL_
qsb solve-location reference/winqsb/LOCATION.FL_ --backend native
qsb export-facilities-json reference/winqsb/LOCATION.FL_ > facilities-location.json
qsb validate-facilities-json facilities-location.json
qsb solve-facilities-json facilities-location.json --backend native
qsb export-location-json reference/winqsb/LOCATION.FL_ > location.json
qsb solve-location-json location.json --backend native
qsb validate-line-balancing reference/winqsb/LINEBAL.FL_
qsb solve-line-balancing reference/winqsb/LINEBAL.FL_ --backend native
qsb export-line-balancing-json reference/winqsb/LINEBAL.FL_ > line-balancing.json
qsb solve-line-balancing-json line-balancing.json --backend native
qsb validate-layout reference/winqsb/LAYOUT.FL_
qsb solve-layout reference/winqsb/LAYOUT.FL_ --backend native
qsb solve-layout reference/winqsb/LAYOUT.FL_ --backend native --layout-strategy pairwise-swap
qsb export-layout-json reference/winqsb/LAYOUT.FL_ > layout.json
qsb solve-layout-json layout.json --backend native --layout-strategy pairwise-swap
```

Location example output:

```text
Location Example 1
backend: nativeEducational
distanceMeasure: squaredEuclidean
objective: MIN
objectiveValue: 2008.692308
NF1: x 5.538462, y 7.653846, weightedDistance 2008.692308
to F1: weight 8, distance 49.563609, weightedDistance 396.508876
...
to F5: weight 3, distance 214.640533, weightedDistance 643.921598
```

Example output:

```text
Line Balancing Example
backend: nativeEducational
timeUnit: minute
cycleTime: 30
totalTaskTime: 143
stationCount: 5
efficiency: 0.953333
balanceDelay: 0.046667
station 1: tasks 1, 2, 4, 6, 12, workload 30, idle 0
...
station 5: tasks 17, 19, 20, 21, workload 24, idle 6
```

Facilities validation examples include:

```text
Location Example 1
backend: validateOnly
modelType: facilityLocation
status: valid
existingFacilities: 5
newFacilities: 1

Line Balancing Example
backend: validateOnly
modelType: lineBalancing
status: valid
tasks: 21
totalTaskTime: 143
```

Layout validation example output:

```text
Shopping Center Layout
backend: validateOnly
modelType: facilityLayout
status: valid
grid: 9x13
departments: 17
fixedDepartments: 1
warnings: 3
```

Layout native example output:

```text
Shopping Center Layout
backend: nativeEducational
objective: MIN
source: initialLayoutEvaluation
grid: 9x13
objectiveValue: 53552
departments: 17
interactions: 240
```

Layout pairwise-swap example output:

```text
Shopping Center Layout
backend: nativeEducational
source: pairwiseSwapLocalSearch
objectiveValue: 48948
layoutStrategy: pairwiseSwap
initialObjectiveValue: 53552
improvement: 4604
evaluatedMoves: 735
appliedMoves: 6
move: swap D <-> G, objective 53552 -> 51665, improvement 1887
...
```

`qsb export-layout-json` emits the normalized `FacilityLayoutProblem` model.
`qsb solve-layout-json` reads that model and emits a JSON
`FacilityLayoutSolution` with `objective`, `objectiveValue`, `source`,
`search`, `moves`, `placements`, and `interactions`, which is suitable for
future GUI layout visualization work.

Location and line-balancing have the same normalized JSON flow:
`qsb export-location-json` and `qsb export-line-balancing-json` emit model JSON;
`qsb solve-location-json` and `qsb solve-line-balancing-json` read those models
and emit `FacilityLocationSolution` or `LineBalancingSolution` JSON.

`qsb export-facilities-json` emits a generic facilities envelope with `kind` and
`model` fields for line-balancing, location, or layout fixtures.
`qsb validate-facilities-json` reads that envelope and emits a JSON
`FacilitiesValidationDocument` with `kind`, `backend`, `isValid`, and
`diagnostics`.
`qsb solve-facilities-json` reads that envelope and emits a matching `kind` plus
`backend` and `solution` envelope, which is the preferred shape for generic
import/solve workflows. Backend metadata records the native algorithm and
whether it is closed-form, fixture-scale, heuristic, or approximate. Those
metadata values are supplied by the selected `FacilitiesBackend`, keeping
algorithm identity out of the CLI layer.

## macOS Workbench

`QSBMacApp` accepts the same generic `FacilitiesModelEnvelope` JSON used by the
CLI. The workbench detects line-balancing, location, and layout envelopes,
shows the detected family in the model header, and routes solve or validation
through `FacilitiesBackends` in `QSBCore`.

For layout models, the toolbar exposes contextual `Initial` and `Pairwise`
strategy controls. The bundled Facility Layout sample demonstrates both paths:
initial evaluation produces objective `88`, while pairwise-swap local search
produces objective `52` with improvement `36`. The Validate backend emits a
`FacilitiesValidationDocument` instead of solving. Model and result JSON remain
importable/exportable through the existing document controls.
