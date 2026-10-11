# Quality Control

QSBCore supports all five preserved WinQSB Quality Control fixtures:

- `C_CHART.QC_`: three-sigma c chart for defect counts;
- `P_CHART.QC_`: three-sigma p chart with per-subgroup sample sizes;
- `VARIABLE.QC_`: Xbar-R charts using standard constants for subgroup sizes 2 through 10;
- `PARETO.QC_`: descending defect-category totals and cumulative percentages;
- `PROBPLOT.QC_`: Blom normal scores with least-squares fit and correlation.

The native backend is deterministic and educational. The c, p, Xbar-R, and
Pareto calculations are exact implementations of their stated formulas. The
normal probability plot is marked approximate because it uses an inverse-normal
approximation and a plotting-position convention.

## CLI

```text
qsb solve-quality <legacy-qc-file> [--backend native|validate]
qsb validate-quality <legacy-qc-file>
qsb export-quality-json <legacy-qc-file>
qsb solve-quality-json <quality-control-model-json-file> [--backend native|validate]
qsb validate-quality-json <quality-control-model-json-file>
```

The normalized format uses tagged model and solution envelopes with kinds
`cChart`, `pChart`, `xbarRChart`, `pareto`, and `normalProbabilityPlot`.
Solution documents include backend metadata and chart-ready point arrays.

## macOS Workbench

The Definition workspace provides one native table editor for all five model
variants. c and p charts use observation rows, Xbar-R uses dimension-safe
subgroup measurements, Pareto uses editable category columns, and normal
probability plots use a measurement list. Complete tables can be copied to or
pasted atomically from Excel, Numbers, LibreOffice, TSV, or CSV. New rows
receive keyboard focus, edits support macOS undo/redo, semantic validation
remains in `QSBCore`, and normalized JSON stays available explicitly.

Changing the analysis type retains each variant's unfinished table, category
names, and characteristic during the current editing session, including invalid
text. The title is shared. Undo/redo also restores variant changes. Only the
active variant is encoded in normalized model JSON; opening another model or
applying JSON begins a new editing session. Missing imported observations and
measurements remain visible as empty, invalid cells rather than being truncated
or replaced with invented numeric values.

Each numeric cell has a distinct keyboard focus identity and contextual
accessibility label. Add, remove, and successful paste actions select a nearby
editable cell. Full runtime keyboard and VoiceOver verification remains pending.

The solution workspace renders every current typed result:

- c, p, and Xbar-R control charts with center and control limits, highlighted
  out-of-limit points, and Western Electric signal details;
- Pareto frequency, cumulative-share charts, and category table; and
- normal probability points, fitted line, and distribution summary.

Chart points and signal groups expose accessibility values. The layout uses
adaptive summaries and horizontal chart scrolling where observations require
more width, while normalized solution JSON remains available.

## Current Limits

The backend reports points outside three-sigma control limits and fixed
Western Electric two-of-three, four-of-five, and eight-on-one-side signals.
Run-rule configuration and legacy cause/action/comment metadata are not yet
represented in normalized models. The parser reads the original fixtures
without modifying files under `reference/winqsb`.


## Interactive background execution

Native UI Run captures typed core input and executes backend validation, solving,
and normalized output outside the main thread. Pending progress disables duplicate
runs. Draft/model/backend changes, validation, and newer runs prevent stale success
or errors from replacing current state. Incomplete native fields and invalid core
input lead to Validation; current worker failures remain explicit. The workspace
retains invalid strings and dormant variant fields in its comparison of captured
and current input. Superseded workers finish in the background; no cancellation
control is currently provided. Core/CLI contracts and solver behavior are unchanged.
Static pending renders cover compact and wide windows; actual editor keyboard,
focus, and VoiceOver verification remains open.

External solving remains unavailable; the UI directs users to QSB Native or
Validate only.

## Spreadsheet repair

A table can be repaired while the title or characteristic is unfinished. Paste
checks the active analysis's table shape and numeric cells atomically; statistical
validation remains in QSBCore. Unique existing column names retain identities.
Unique exported observation/subgroup numbers identify existing rows across
spreadsheet reordering. Repeated or unfamiliar labels create distinct new rows.
Paste retains the selected cell when its row and column survive. Dormant analysis
tables remain preserved; runtime keyboard and VoiceOver verification is pending.


## Keyboard focus repair

Observation and column identity changes repair an orphaned selection to the
nearest remaining row or column, including replacement and undo/redo. Surviving
cells retain their identity. Runtime keyboard and VoiceOver behavior remains
unverified after the native inspection service failure.
