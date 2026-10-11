# PERT/CPM Project Scheduling

QSB supports the four preserved WinQSB project-network fixtures in both matrix
and graphic entry formats:

- `CPM.CP_` and `CPMGRAPH.CP_`: deterministic CPM;
- `PERT.CP_` and `PERTGRPH.CP_`: probabilistic three-estimate PERT.

The graphic coordinates stored after the activity table are presentation
metadata. Matrix and graphic fixtures normalize to the same typed project
model and produce the same schedule.

## Models and validation

CPM activities preserve normal/crash times and normal/crash costs. The normal
schedule uses normal times. A separate native LP workflow minimizes incremental
crash cost for a requested project deadline. It uses continuous activity times
and is fixture-scale because the number of network paths can grow quickly.

PERT activities preserve optimistic, most-likely, and pessimistic times. The
native solver uses:

```text
expected time = (optimistic + 4 * most likely + pessimistic) / 6
variance = ((pessimistic - optimistic) / 6)^2
```

Structured validation checks unique nonempty activity names, predecessor
references, self-dependencies, acyclic precedence, finite nonnegative values,
CPM crash/normal ordering, and PERT estimate ordering.

## Solving

The native educational backend performs exact forward and backward passes on
the activity DAG. Solution JSON contains duration and variance, earliest and
latest times, slack, critical flags, the critical activity list, and project
duration. PERT also reports critical-path variance and standard deviation.

For the preserved examples:

- CPM duration is `34`, with critical activities `C,F,J,L`;
- PERT expected duration is `33.833333`, with the same critical activities;
- PERT critical-path variance is `1.361111`.

```sh
qsb solve-cpm reference/winqsb/CPM.CP_ --backend native
qsb validate-cpm reference/winqsb/CPMGRAPH.CP_
qsb solve-pert reference/winqsb/PERT.CP_ --backend native
qsb validate-pert reference/winqsb/PERTGRPH.CP_
qsb solve-cpm-crash reference/winqsb/CPM.CP_ 30 --backend native
```

Normalized workflows:

```sh
qsb export-project-json reference/winqsb/PERT.CP_ > project.json
qsb export-project-json reference/winqsb/CPM.CP_ > cpm.json
qsb solve-project-json project.json --backend native
qsb solve-project-json project.json --backend validate
qsb validate-project-json project.json
qsb solve-cpm-crash-json cpm.json 30 --backend native
```

`ProjectSchedulingBackend` exposes `nativeEducational` and `validateOnly` modes
and reserves `externalHighPerformance` for a future large-scale scheduling or
cost-time optimization adapter.

## macOS Workbench

The definition workspace provides a native CPM/PERT activity editor. It keeps
activity identity stable while names, comma-separated predecessors, CPM
time/cost values, or PERT three-point estimates are edited. Adding an activity
moves focus to its name, edits participate in macOS undo/redo, and method
changes seed the other formulation on its first visit and retain both sets of
editable times and CPM costs thereafter, including unfinished input. CPM-to-PERT
seeding copies normal time into the three estimates; PERT-to-CPM seeding uses the
core expected time when all estimates are numeric. Subsequent edits in one
method do not overwrite the other method’s retained values. `Copy Table` and `Paste Table` exchange
named TSV/CSV ranges with Excel, Numbers, and LibreOffice; the entire range is
validated structurally and numerically before it replaces the activity table.
This repair works while the title or time unit remains incomplete. Full-header
matching allows headerless activities named `Activity`. Paste preserves identity
and dormant method fields only for unambiguous matching activity names; new rows
receive independent identities and seeded counterpart times. Removal targets a
neighboring activity, and draft replacement restores a surviving focus target.
Semantic precedence, cycle, and time
validation remains in `QSBCore`.

Interactive Run captures the current typed model and computes core validation,
scheduling, and normalized output outside the main thread. A pending run exposes
progress and disables duplicate Run actions. Editing/replacing the model, changing
method or backend, applying another validation, or starting a newer run prevents
stale results and errors from replacing the current workspace. Invalid native
fields lead to Validation; semantic invalidity is checked by QSBCore in the worker.
External scheduling remains unavailable and the UI directs users to QSB Native
or Validate only. Superseded computations finish in the background; no cancellation
control is currently provided. Synchronous CLI/core APIs retain their contracts.
Live editor keyboard and VoiceOver verification remains pending because native
inspection fails after Create, as recorded in the UI workbench audit.

The solution workspace provides a native CPM/PERT schedule view with project
duration, critical activities, PERT variance when applicable, earliest and
latest timing bars, visible slack, a time-phased activity table, normal cost,
backend exactness, accessible chart values, and the normalized JSON fallback.
The same typed presentation covers deterministic CPM and probabilistic PERT.
