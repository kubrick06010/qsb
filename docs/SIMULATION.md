# Simulation

QSBCore supports all four preserved WinQSB simulation fixtures:

- `reference/winqsb/QSS1.QS_`: two exponential-service servers;
- `reference/winqsb/QSS2.QS_`: two constant-service servers;
- `reference/winqsb/QSS3.QS_`: matrix-format assembly network;
- `reference/winqsb/QSSGRAPH.QS_`: graphic-format form of the assembly network.

The clean-room parser normalizes Matrix and Graphic payloads into one component
network. Components represent customer/entity sources, queues, servers, and
gates; routes preserve optional probabilities and transfer times. Supported
distributions are constant, exponential, normal, uniform, and triangular.

## CLI And JSON

```bash
qsb solve-simulation reference/winqsb/QSS1.QS_ --backend native
qsb validate-simulation reference/winqsb/QSSGRAPH.QS_
qsb export-simulation-json reference/winqsb/QSS3.QS_
qsb solve-simulation-json model.json --backend native
qsb solve-simulation-json model.json --backend native --replications 3
qsb validate-simulation-json model.json
```

Normalized model JSON records the original representation, time unit,
components, routes, queue rules and capacities, arrival and batch
distributions, and entity-specific service rules. Solution documents contain
backend metadata, horizon and seed, generated/completed totals, queue lengths
and rejections, and server completion/utilization metrics.

`SimulationJSON.decodeSolution` provides the matching typed read boundary for
frontends and round trips.

## Solver Character

`nativeEducational` is a fixture-scale, seeded discrete-event simulator. It
models finite FIFO queues, alternate servers, probabilistic routing, transfer
times, typed entities, and assembly synchronization. The default run is one
1,000-time-unit replication with seed 1, making CLI and regression results
deterministic. `--replications N` runs independently seeded replications and
reports aggregate metrics plus normal-approximation 95% intervals for queue
length and server utilization when `N > 1`.

Results are stochastic estimates, not exact queueing solutions. The native
backend currently reports no warm-up deletion or interactive event trace.
`validateOnly` checks network structure without running it, while
`externalHighPerformance` remains an explicit future integration point.

## macOS Workbench

The definition workspace provides a native component-network editor organized
into Components, Routes, and Service Rules. Sources expose arrival and batch
distributions, queues expose discipline and capacity, servers expose
entity-specific service distributions, and every component keeps optional
input/output rules and attributes. Component renames update route targets,
component deletion removes dangling routes, and new components, routes, and
rules restore keyboard focus. Edits participate in macOS undo/redo.

Each section can exchange one complete named table with Excel, Numbers,
LibreOffice, TSV, or CSV. Distribution parameters remain separate typed values
in the form and use space-separated values in spreadsheet cells. A paste is
parsed and checked in full before it replaces components, routes, or service
rules. Network references, route probabilities, source requirements, queue
capacity, and server semantics continue through `SimulationValidator` in
`QSBCore`; normalized JSON remains the advanced interchange and repair surface.

The solution workspace provides native simulation metrics for generated and
completed entities, completion rate, horizon, seed and replication count.
Queue length/rejection and server completion/utilization charts and tables show
95% confidence intervals when replicated output contains them. The component
network and run assumptions remain visible, chart and table values are
accessible, and normalized JSON stays available as the audit fallback. The Run
inspector selects 1 through 100 replications and passes that choice through the
shared backend options boundary.

### Interactive execution

Simulation runs started from the editor, toolbar, overview, Run inspector, or
shared Run command execute an immutable `SolverRequest<SimulationModel>` on a
background task. The workspace publishes `Solving` and a status-bar progress
indicator before computing, keeps the interface responsive, and rejects a second
Run while one is pending. Core backend selection, validation, simulation, and
solution encoding remain unchanged. The synchronous workspace method remains
available for existing deterministic tests; other model families still need
their own background-execution migration.

Editing, validating, importing, or replacing the model invalidates pending
results. Changes to backend or replication options also prevent an older result
from being applied. Stale successes and errors cannot overwrite the new draft,
status, or selected pane. Invalidating a result does not stop computation already
running in the core solver; no cancellation control is claimed.

Tests exercise visible pending state, off-main-thread computation, duplicate-run
prevention, replication forwarding, stale results/errors, validation-only,
unavailable backends, and worker failure. Compact/wide static render fixtures
include solving and failure states. Interactive VoiceOver/focus testing remains
required.


## Row focus after edits

Identity changes repair focused rows to a surviving or nearest remaining target.
Simulation routes/service rules and MRP BOM use their Add action when no rows
remain. MRP repairs removed item and schedule-bucket targets and reveals the
bucket's column group. Runtime keyboard/VoiceOver behavior remains unverified.


## Independent spreadsheet repair

Component, route, and service-rule tables validate their own shape and cells before
replacing a section atomically. An unfinished title, time unit, or another section
does not block repair. Header recognition compares the complete header so names
such as Source and Server remain valid data rows. Component names retain hidden
routes/rules only when the old and new names are unambiguous. Unique source/target
or server/entity pairs retain route/rule identities across reorder and case changes;
ambiguous pairs receive distinct fresh identities. Ambiguous source/server names
are rejected rather than assigning one row to multiple components. Header-only
route and rule tables clear that section. Graph, probability, distribution semantics,
and solver validation remain in QSBCore. Undo/redo preserves the complete draft.
