# PERT/CPM Project Scheduling

QSB supports the four preserved WinQSB project-network fixtures in both matrix
and graphic entry formats:

- `CPM.CP_` and `CPMGRAPH.CP_`: deterministic CPM;
- `PERT.CP_` and `PERTGRPH.CP_`: probabilistic three-estimate PERT.

The graphic coordinates stored after the activity table are presentation
metadata. Matrix and graphic fixtures normalize to the same typed project
model and produce the same schedule.

## Models and validation

CPM activities preserve normal/crash times and normal/crash costs. The current
native solver schedules normal times. It does not yet optimize project crashing
or the cost-time tradeoff.

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
```

Normalized workflows:

```sh
qsb export-project-json reference/winqsb/PERT.CP_ > project.json
qsb solve-project-json project.json --backend native
qsb solve-project-json project.json --backend validate
qsb validate-project-json project.json
```

`ProjectSchedulingBackend` exposes `nativeEducational` and `validateOnly` modes
and reserves `externalHighPerformance` for a future large-scale scheduling or
cost-time optimization adapter.
