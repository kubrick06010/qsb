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
warnings: 1
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

Layout solution documents also open in a native responsive facility view. The
canvas renders the normalized grid and department rectangles, distinguishes
fixed departments, optionally overlays the highest-impact flows, and supports
independent grid visibility and scale controls. A segmented detail inspector
lists department centroids and areas, applied pairwise swaps, or the full
load-distance interaction breakdown. Initial and improved solutions use the
same presentation, with backend exactness, search counts, and objective
improvement kept visible. The Layout/JSON selector preserves the normalized
solution document as the universal fallback.

Location also has a native Definition editor for IDs, names, existing/new roles,
coordinates, distance measure, objective, and the complete directed interaction
matrix. New-facility coordinates may remain blank. Unsupported models remain
editable with core diagnostics; native solving still supports minimization and
one new facility. Copy/Paste Table is compatible with Excel, Numbers, and
LibreOffice, and each paste is atomic. Reordering or renaming existing facilities
by ID and existing/new role retains both interaction axes. Legacy files number
existing and new facilities independently. Core validation rejects duplicate
facility IDs within each role;
facility table paste rejects ambiguous duplicate IDs before applying changes. Matrix headers and row names must match the
current facility order; blank cells retain nullable interactions. Explicit matrix
paste can repair malformed imported interaction dimensions.

The editor supports undo/redo, focus after add/remove/paste, normalized file
import, JSON Apply, and envelope export. Compact/wide render checks cover
facilities, interactions, and invalid coordinates. Full runtime VoiceOver and
keyboard traversal audits remain open.

Line Balancing task-table repair is independent of unfinished title, time unit,
or cycle time. It validates only the pasted row names, integer IDs/times and
successor lists, and boolean isolation flags before committing. Full headers are
case-insensitive. Unambiguous numeric source IDs preserve row identity across
rename/reorder (including equivalent text such as `1` and `01`); duplicate IDs
receive distinct row identities and remain core diagnostics. Missing references
remain visible for repair. Paste retains a surviving focus target, and undo or
replacement chooses a nearby surviving name field. Actual keyboard/focus timing
and VoiceOver verification remain open.

Line Balancing also has a native Definition editor for cycle time, time unit,
task IDs, durations, isolation flags, and immediate successor IDs. Successor
lists accept spaces, commas, or semicolons; spreadsheet export uses spaces to
keep each list in a single cell. Task reordering retains IDs and precedence.
Removing a referenced task preserves successor input so core validation reports
missing dependencies and undo can restore the task. Isolation flags remain in
the normalized model for compatibility; the current native solver uses task
times and precedence without enforcing separate stations from those flags.

Task table transfer is atomic and supports Excel, Numbers, and LibreOffice.
The editor supports undo/redo, focus after add/remove/reorder/paste, normalized
file import, explicit JSON Apply, and envelope export. Compact/wide render checks
cover valid and invalid input. Full runtime accessibility and keyboard audits
remain open.

Layout also has a native Definition editor for grid dimensions, departments,
fixed flags, cell rectangles, and directed flow/unit costs. One department may
occupy multiple rectangles, edited through a department selector. The rectangle
spreadsheet table covers all departments with an explicit department ID per row.
Department reordering preserves geometry and both cost axes by ID. Cost table
headers and row labels include IDs and names and must match the current order.
Rectangle paste rejects unknown or ambiguous department IDs. All table pastes
are atomic, and nullable costs survive JSON round trips.

Edits support undo/redo and row focus after add/remove/paste. Normalized file
imports and explicit JSON Apply open this editor; export and both existing
solving strategies use the shared facilities envelope and backend. Compact/wide
render checks include every section and invalid geometry. Runtime VoiceOver,
keyboard traversal, and large-matrix audits remain pending.

Location and line-balancing solution documents also have native result views.
Location renders existing and proposed coordinates, weighted interaction links,
placement details, and distance contributions. Line balancing renders station
workload versus idle capacity, task assignments, precedence context, efficiency,
and balance delay. Both views expose accessible chart and row values, adapt to
compact widths, and retain the normalized JSON fallback.

`FacilitiesModelJSON.decodeSolutionDocument` is the shared typed decoder used by
the workbench. SwiftUI combines that document with the currently loaded
`FacilityLayoutProblem` only for title and grid dimensions; all placements,
flows, moves, centroids, and objective values come from the QSBCore solution.


### Large layout geometry and overview

Layout validation and centroid evaluation compute rectangle unions by row bands,
merging column intervals without enumerating individual cells. Repeated or
intersecting rectangles belonging to the same department count each cell once.
The existing initial evaluation and pairwise-swap strategies retain their
semantics; their results remain verified against the legacy fixture.

Grid dimensions must be positive and their product must fit in Swift `Int`.
Oversized products produce `facilities.layout.grid.overflow` instead of an
arithmetic trap. Invalid rectangle bounds are diagnosed before geometry is
computed. Overlap diagnostics now report one representative cell and the total
shared cell count per department pair, rather than one diagnostic per shared
cell. Fixed-area overlaps remain warnings; movable-area overlaps remain errors.

The native result canvas fits large grids into a bounded overview and draws at
most 122 grid lines per axis. A visible note identifies the coarser grid spacing;
exact department ranges, areas, and centroids remain available in the detail
table and normalized JSON. Small fixture grids retain their per-cell grid and
per-cell detail. This bounds rendering by rectangle and department complexity,
not by the numeric area of the grid; very large numbers of rectangles or dense
flow matrices still need separate interaction and performance auditing.

### Dense matrix editing and spreadsheet repair

The native Layout costs and Location interactions editors show the complete
grid for up to 12 sources and destinations. Larger tables offer source selection,
Previous/Next Source, and destination groups of at most 12 columns. Copy/Paste
Table always transfers the entire matrix. Source identity survives spreadsheet
reordering, and removal selects a nearby source; pasted matrices select the first
cell. Cells expose source and destination positions and labels to accessibility.

Location matrix labels include role and scoped ID, such as `Existing [1] Site`
and `New [1] Site`, so repeated names remain unambiguous. Older tables containing
only names remain accepted when names are unique. Matrix pastes validate their
own shape and finite numeric values atomically, allowing repair while another
section has unfinished geometry or coordinates. Empty nullable cells retain
their existing meaning. QSBCore still validates the complete model before solving.

Regression tests cover matrix navigation, boundary groups, independent repair,
repeated-name round trips, malformed input rejection, and stable row identities.
Compact/wide render fixtures include 35-source matrices and their last partial
column group. Live keyboard and VoiceOver verification remain pending.


## Interactive execution

Line Balancing, Facility Location, and Facility Layout capture typed core models
and compute validation, solving, and normalized output outside the main thread.
Pending progress disables duplicate Run actions. Draft/model/backend changes,
validation, and newer runs invalidate stale results and errors. Layout also
captures its chosen initial or pairwise-swap strategy; changing it prevents an
old strategy's result from appearing current. The strategy is irrelevant to
Location and Line Balancing runs.

Incomplete native fields and invalid core input lead to Validation. Current
worker failures remain explicit, and unavailable external solving directs users
to QSB Native or Validate only. Superseded workers finish; no cancellation control
is currently provided. CLI/core APIs and solver contracts remain unchanged.
Static pending layouts cover compact and wide windows; actual keyboard, focus,
and VoiceOver verification remains open.


## Selection after table replacement

Native row focus now retains surviving identities and repairs removed targets to
the nearest remaining row after replacement or undo/redo. Spreadsheet row paste
retains a surviving row target. The QP matrix keeps the focused row/column visible
when variable identities change; Layout retains a surviving selected department
and provides an Add Rectangle focus target after removing the last rectangle.
These are source-level improvements; live keyboard/VoiceOver remains unverified.
Large-matrix paste selection is still under audit.
