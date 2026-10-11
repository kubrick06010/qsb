# Quadratic Programming

QSBCore supports all three preserved WinQSB quadratic fixtures:

- `QP.QP_`: continuous `MatrixFormat` quadratic maximization;
- `QPNORMAL.QP_`: continuous `NormalModel` with a cross-product term;
- `IQP.QP_`: diagonal integer quadratic maximization.

Both legacy formats normalize to `QuadraticProgram`, whose objective is
`x^T Q x + c^T x`. The model reuses the shared linear constraint, objective
sense, variable type, and bound concepts.

## Solver Character

For strictly concave maximization or strictly convex minimization with
continuous variables, the native backend enumerates fixture-scale active sets,
solves their KKT systems, filters for primal feasibility, and selects the global
objective optimum. This path is marked `exact`.

The native integer path supports nonnegative, diagonal, concave maximization
with at most four variables. It finds a feasible incumbent, derives finite
bounds from the separable objective, and enumerates all integer points inside
those bounds. It is marked `fixtureScale`. General MIQP, indefinite QP, and
large active-set models need a separate future solver assessment.

## Optional HiGHS backend

HiGHS is a candidate for continuous convex minimization and concave
maximization. Its [supported problem classes](https://github.com/ERGO-Code/HiGHS/blob/master/docs/src/index.md)
exclude mixed-integer QP. The installed HiGHS 1.15.1 executable also rejects
a model containing both a Hessian and a binary variable with “Cannot solve
MIQP problems with HiGHS.” The `IQP.QP_` fixture therefore keeps its native
backend; general MIQP needs a different external engine.

`QuadraticProgramMPSExporter` now writes a dedicated free-MPS `QUADOBJ` section
for continuous, strictly convex/concave models. QSBCore's objective is
`x^T Q x + c^T x`, while HiGHS represents the quadratic part as
`0.5 x^T H x`; export writes the lower triangle of `H = 2Q`, including each
cross term once. It preserves objective sense, normalized variable names,
signed or free bounds, and linear constraints. The optional
`HiGHSQuadraticProgrammingBackend` discovers the host executable through
`QSB_HIGHS_PATH` or `PATH`, parses typed statuses and primal values, verifies
the reconstructed objective and feasibility, and derives active constraints.
No solver binary is bundled or linked into QSBCore.

HiGHS 1.15.1 was checked against the two preserved continuous fixtures, a
cross-term model with a binding constraint, and a zero-row QP. In the latter
case HiGHS can write an optimal solution yet exit with status 1; the adapter
accepts that narrow combination after validating the complete solution.
Portable fake-executable tests cover status handling, malformed output,
options, and rejection of nonzero exits for constrained QP. General MIQP stays
unsupported by HiGHS and requires a different engine. The
[HiGHS C API](https://ergo-code.github.io/HiGHS/dev/interfaces/c_api/)
also accepts triangular Hessians, but the process boundary keeps the package
portable.

## CLI

```text
qsb solve-qp <legacy-qp-file> [--backend native|validate|external]
qsb validate-qp <legacy-qp-file>
qsb export-qp-json <legacy-qp-file>
qsb solve-qp-json <quadratic-program-json-file> [--backend native|validate|external]
qsb validate-qp-json <quadratic-program-json-file>
```

Solution documents contain backend metadata, objective value, named variable
values, and the active constraints at the optimum.

## macOS Workbench

The native Definition editor separates variables and bounds, the quadratic
matrix, and linear constraints into selectable tables. Copy/Paste Table uses
TSV compatible with Excel, Numbers, and LibreOffice; each paste is atomic.
Reordering existing variables in the variable table also reorders both matrix
axes and constraint coefficients by variable name. Matrix headers and row names
must match the current variable order, so a paste cannot silently change the
meaning of coefficients. Invalid numeric input remains editable with diagnostics.

New rows receive keyboard focus, edits participate in macOS undo/redo, and
normalized JSON remains available through explicit Apply and export actions.
Imported normalized files open the same native editor. Imported inconsistent
dimensions produce diagnostics rather than an indexing failure. All available
coefficients are retained, even when there are more coefficients than named
variables; missing names and coefficients stay empty for direct repair.
`Use Displayed Dimensions` explicitly accepts displayed Continuous types and
unbounded bounds where imported metadata is absent. It does not fill missing
coefficients or names and participates in undo/redo. Replacing the complete
variable table also explicitly supplies the reviewed metadata.

Each pasted section is checked independently for its own structure and numeric
values. An invalid field in another section no longer prevents a valid table
from being pasted to repair the model. Whole-model semantic validation remains
in `QSBCore`. Variable identities survive unambiguous name-based reordering;
ambiguous duplicate names retain positional identities and remain subject to
core diagnostics.

Matrices with more than 12 variables use a row selector, Previous/Next Row, and
column groups of up to 12 cells. The row name, column headers, and position
summary remain visible while editing. Copy/Paste Table still transfers the
**entire** matrix. Small matrices retain the complete grid. Numeric cells expose
row and column identities to focus and accessibility, and add/remove/paste
routes select a nearby editable field. Compact/wide rendering covers a
40-variable model including its final row and partial final column group.
Runtime VoiceOver and keyboard traversal verification remains pending.

The solution workspace provides a native optimum view with objective and sense
summaries, an accessible variable chart, domain and bound cards, active
constraints and bounds, backend exactness, and normalized JSON fallback. A
future contour view can build on the same typed document for one- and
two-variable teaching models.


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

QP retains optional HiGHS discovery through the core backend. Unavailable-backend
guidance now correctly describes host discovery rather than claiming the QP
translation is disabled. Supported QP scope remains defined by core validation.


## Selection after table replacement

Native row focus now retains surviving identities and repairs removed targets to
the nearest remaining row after replacement or undo/redo. Spreadsheet row paste
retains a surviving row target. The QP matrix keeps the focused row/column visible
when variable identities change; Layout retains a surviving selected department
and provides an Add Rectangle focus target after removing the last rectangle.
These are source-level improvements; live keyboard/VoiceOver remains unverified.
Large-matrix paste selection is still under audit.
