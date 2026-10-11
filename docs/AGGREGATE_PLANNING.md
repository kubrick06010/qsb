# Aggregate Planning

QSBCore supports all three preserved WinQSB Aggregate Planning fixtures:

- `APLP.AP_`: workforce and capacity planning using the legacy LP method;
- `APSIMPLE.AP_`: workforce and capacity planning using the legacy simple method;
- `APTRP.AP_`: fixed-capacity planning using the legacy transportation method.

The parser normalizes the three tabular payloads into one period-based model.
The native educational backend builds a continuous linear program with demand,
inventory/backorder, regular time, overtime, subcontracting, and optional
workforce/hiring/dismissal balances. It delegates that program through the
shared `LinearProgrammingBackend` seam.

The optional `externalHighPerformance` backend uses a host-provided HiGHS
executable for that same normalized LP and reconstructs the typed period
solution. Discovery checks `QSB_HIGHS_PATH` and then `PATH`; the native backend
remains the default and planning quantities stay continuous.

Legacy row labels must be unique after trimming surrounding whitespace and
ignoring case. Duplicate labels return an explicit parser error, including when
their values agree. Period counts exceeding the supplied header are rejected
before allocating period vectors.

## CLI

```text
qsb solve-aggregate <legacy-ap-file> [--backend native|validate|external]
qsb validate-aggregate <legacy-ap-file>
qsb export-aggregate-json <legacy-ap-file>
qsb solve-aggregate-json <aggregate-planning-model-json-file> [--backend native|validate|external]
qsb validate-aggregate-json <aggregate-planning-model-json-file>
```

Solution JSON includes backend metadata, total cost, and period rows containing
workforce changes, production sources, ending inventory/backorder, and unused
regular capacity.

## macOS Workbench

Interactive Run captures the typed plan and computes core validation, solution,
and normalized output outside the main thread. Progress is visible while solving;
duplicate runs are rejected. Draft edits, replacement models, validation, changed
backend/JSON, or a newer run prevent stale results and errors from replacing
current state. Incomplete native fields lead to Validation, and semantic invalidity
is reported by the core worker. Superseded calculations finish in the background;
no cancellation control is currently provided. Live keyboard and VoiceOver
verification remains open, as recorded in the UI workbench audit.

Aggregate Planning retains its optional host-provided HiGHS backend through the
core backend protocol. Backend discovery and solving run in the worker.

The definition workspace provides a native period editor split into demand,
production-cost, inventory/sourcing, and workforce field groups. This keeps
compact windows usable while preserving every normalized period vector. A
single `Copy Table` export contains all 20 named columns; `Paste Table` accepts
the same range from Excel, Numbers, LibreOffice, TSV, or CSV and commits only
after validation of the pasted table's structure and finite numeric cells. A valid
table can repair periods while plan settings still contain incomplete values.
Whole-header matching allows a headerless period named `Period`. Existing row
identities survive reorder when names are unambiguous; duplicate names receive
distinct identities. Blank maximum cells preserve unbounded values. Period
addition selects an unused default name and restores focus to it; removal targets
a neighboring period. Paste and edits use
the macOS undo manager. `QSBCore` remains responsible for bounds, capacity, and
model semantics.

Imported JSON vectors with unequal lengths remain editable: the native draft
retains the longest vector, shows unnamed extra periods, and leaves missing
required numeric cells blank. Missing optional maxima display as unbounded and
require review. `Use Displayed Dimensions` explicitly accepts the visible extent
and participates in undo/redo; required names and cells still need repair before
validation succeeds. QSBCore retains model validation and solver ownership.
Changing formulation or capacity basis keeps all native period fields and the
stored initial-workforce text available when returning to workforce-based capacity.

The solution workspace provides a native plan view with:

- total cost, period count, demand, and exactness summaries;
- stacked regular, overtime, and subcontracted production with demand overlaid;
- ending inventory and backorder charts, with backorders shown below zero;
- a scrollable period table covering capacity, production, workforce changes,
  inventory, and backorders; and
- backend, algorithm, exactness, and continuous-domain context.

Charts and tables expose accessibility labels, adapt their summary layout to
compact windows, and keep normalized solution JSON available from the same
result surface.

## Solver Character

The formulation and simplex result are exact for the normalized continuous LP.
The HiGHS route solves the same LP through the external backend seam. Workforce
and production quantities are continuous; integer workforce planning is not
implied. Both routes preserve the legacy parser and normalized JSON schema.
