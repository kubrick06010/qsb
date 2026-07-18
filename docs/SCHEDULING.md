# Scheduling

QSBCore supports the preserved WinQSB flow-shop and job-shop model variants.
Both variants share a discriminated `SchedulingModelEnvelope`, structured
validation, native educational and validation-only backends, and a common
`SchedulingSolutionDocument`.

## Legacy And JSON Workflows

```sh
swift run qsb import-legacy-json reference/winqsb/FLOWSHOP.JO_
swift run qsb export-scheduling-json reference/winqsb/JOBSHOP.JO_
swift run qsb solve-scheduling-json model.json --backend native
swift run qsb validate-scheduling-json model.json
```

The legacy importer expands SZDD data, detects the scheduling family, parses
the concrete variant, and emits normalized model JSON. Existing
`solve-flowshop`, `solve-jobshop`, and family-specific JSON commands remain
available as stable shortcuts.

## Solution Document

`SchedulingSolutionDocument` records:

- model kind, title, time unit, makespan, and job sequence;
- backend kind, algorithm, exactness, and explanatory notes;
- every operation's job, machine, start, finish, duration, and preceding idle
  time;
- machine-oriented timelines with ready and completion times.

`SchedulingModelJSON.decodeSolution` provides the typed decoder used by the
macOS workbench. The same document remains available as normalized JSON for CLI
scripts and export.

## macOS Gantt View

QSBMacApp recognizes a scheduling solution document and defaults to a native
Gantt timeline. Each row represents a machine, each colored bar represents a
job operation, and gaps expose machine idle time. The view includes:

- flow-shop and job-shop support through the same typed document;
- makespan, machine, job, backend, and time-unit context;
- a responsive time axis and adjustable horizontal scale;
- operation tooltips and accessibility labels;
- a Timeline/JSON segmented control so normalized output remains the universal
  fallback.

The Gantt view is a presentation-only SwiftUI component. Parsing, validation,
solving, and timeline construction remain in QSBCore.

## Solver Character

- Flow shop uses exact permutation search for preserved fixture-scale models.
- Job shop uses exact fixture-scale branch and bound with dominance pruning.
- Both native implementations are educational and deterministic; they do not
  claim industrial-scale scheduling performance.
- `validateOnly` produces diagnostics without solving.
- `externalHighPerformance` remains an explicit future backend seam.
