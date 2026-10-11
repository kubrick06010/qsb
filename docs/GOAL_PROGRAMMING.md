# Goal Programming

QSB supports all three preserved WinQSB goal-programming fixtures:

- `GP.GP_`: continuous matrix format;
- `GPNORMAL.GP_`: the equivalent continuous normal-model format;
- `IGP.GP_`: integer matrix format with explicit deviation variables.

The parser reuses the established WinQSB LP parser for every priority row and
requires all resulting views to share variables, constraints, bounds, and
domains. Blank matrix coefficients normalize to zero. This keeps algebraic
parsing consistent between LP and Goal Programming.

## Lexicographic semantics

Goals are preemptive and ordered as stored in the file. The native backend:

1. optimizes the first goal;
2. adds an equality fixing that optimum;
3. optimizes the next goal;
4. repeats until all priorities are fixed.

It does not replace priorities with arbitrary weighted sums. Mixed minimize and
maximize goals are supported.

`externalHighPerformance` uses a host-provided HiGHS executable for each
priority LP or MIP. QSBCore still owns lexicographic fixing, deviation presolve,
and typed goal outcomes, so external execution does not change the model or
JSON contract. The native backend remains the deterministic default.

For the continuous sample, both source formats produce:

```text
G1 = 114
G2 = 574
A = 16, B = 14, C = 36
```

The integer fixture produces `G1 = 0`, `G2 = 295`, `X1 = 4`, and `X2 = 3`.

## Integer presolve

The integer educational path is characterized as `fixtureScale`. It accepts an
integral LP relaxation immediately and derives finite bounds before invoking
the shared branch-and-bound backend for fractional priorities. Paired `nN/pN`
deviation variables are relaxed only when integral equality coefficients and
right-hand sides prove their residuals integral; decision variables retain
their source integral domains.

## CLI and JSON

```sh
qsb solve-goal reference/winqsb/GP.GP_ --backend native
qsb solve-goal reference/winqsb/GP.GP_ --backend external
qsb validate-goal reference/winqsb/IGP.GP_
qsb export-goal-json reference/winqsb/GPNORMAL.GP_ > goal.json
qsb solve-goal-json goal.json --backend native
qsb solve-goal-json goal.json --backend validate
qsb validate-goal-json goal.json
```

`GoalProgrammingBackend` exposes native educational, validation-only, and
optional HiGHS-backed modes. When no `highs` executable is discovered, an
external request returns an explicit unavailable error.

## macOS Workbench

The native Definition editor separates variables/bounds, ordered priorities,
and linear constraints. Each goal has a name, objective sense, and coefficients;
move-up and move-down controls change its lexicographic priority while retaining
row identity. Invalid entries remain editable with shared core diagnostics.

Copy/Paste Table works with Excel, Numbers, and LibreOffice. Variable table
reordering preserves goal and constraint coefficients by variable name. Goal
and constraint table headers must match the current variable order. Each paste
is atomic; a header-only constraint table clears the constraints. Edits and
priority moves support macOS undo/redo. New rows, removal, and paste restore
focus to an available row. Normalized file import, explicit JSON Apply, and
export use the same typed draft. Compact/wide render checks cover all sections
and invalid input; full runtime accessibility and keyboard audits remain open.

Malformed imported dimensions retain all available goal and constraint
coefficients, including coefficients beyond the named variables. Missing names,
required lower bounds, and coefficients remain empty until repaired. The native
`Use Displayed Dimensions` action reviews displayed Continuous types and
unbounded upper bounds; it does not invent required data and supports undo/redo.
Replacing the complete variable table also supplies reviewed metadata. Each
section paste validates its own structure, names, types, and numeric entries
before committing, so an invalid field in another section cannot block repair.
QSBCore continues to own whole-model semantic validation. Variable identities
survive unambiguous name-based reordering; ambiguous names keep positional
identities and remain diagnosable.

Priority moves select the moved goal's name field, and deleting or pasting the
last constraint selects Add Constraint. Empty goal/constraint tables explain how
to add or paste rows. These focus routes are implemented; runtime keyboard and
VoiceOver confirmation is still required.

Priority and constraint tables with more than 12 rows or variables use a native
row selector and groups of at most 12 variable coefficients. The selected row's
name, sense or relation/RHS, and row actions remain alongside its coefficients.
Priority labels include the current order; moving a goal preserves its row
identity. Adding, removing, and pasting rows request the corresponding name-field
selection. Small tables retain the complete grid. Copy/Paste Table transfers all
rows and columns regardless of the selected group. Static compact/wide fixtures
exercise 35 priorities/constraints and 40 variables, including the last row and
last partial coefficient group. Runtime focus and VoiceOver confirmation remain
open.

QSBMacApp decodes the same `GoalProgrammingSolutionDocument` produced by the
shared backend and presents an adaptive Priorities/JSON result surface. The
native view shows ordered goal outcomes, final decision-variable values and
bounds, model dimensions, exactness, backend metadata, and solver notes. Each
priority and variable card includes a combined accessibility label and value.

The sample route is covered by a typed workbench test. A regression test also
guards the two-phase simplex transition used by lexicographic fixing: an
artificial variable may not re-enter the feasible solution after an earlier
priority has been fixed.


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

The optional HiGHS backend remains available through core discovery.


## Selection after table replacement

Native row focus now retains surviving identities and repairs removed targets to
the nearest remaining row after replacement or undo/redo. Spreadsheet row paste
retains a surviving row target. The QP matrix keeps the focused row/column visible
when variable identities change; Layout retains a surviving selected department
and provides an Add Rectangle focus target after removing the last rectangle.
These are source-level improvements; live keyboard/VoiceOver remains unverified.
Large-matrix paste selection is still under audit.
