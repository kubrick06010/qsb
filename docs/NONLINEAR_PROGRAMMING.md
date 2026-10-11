# Nonlinear Programming

QSBCore supports all three preserved WinQSB nonlinear-programming fixtures:

- `reference/winqsb/NLP1.NL_`: one-variable unconstrained minimization;
- `reference/winqsb/NLP2.NL_`: bounded multivariable minimization;
- `reference/winqsb/NLP3.NL_`: constrained exponential maximization.

The clean-room parser reads the legacy title, objective sense, expressions,
variable bounds, and named constraints. Expressions support arithmetic,
parentheses, powers, implicit multiplication, and `exp`, `log`, `sqrt`, `sin`,
and `cos`. Variable matching is case-insensitive while preserving legacy names.

## CLI And JSON

```bash
qsb solve-nlp reference/winqsb/NLP1.NL_ --backend native
qsb validate-nlp reference/winqsb/NLP3.NL_
qsb export-nlp-json reference/winqsb/NLP2.NL_
qsb solve-nlp-json model.json --backend native
qsb validate-nlp-json model.json
```

The normalized model stores the objective expression, ordered variable names,
nullable lower and upper bounds, constraints, and whether strict legacy
inequalities were normalized. Solution documents include backend metadata,
named variable values, objective value, constraint evaluations, maximum
violation, and iteration/evaluation count.

## Solver Character

`nativeEducational` is deterministic and approximate. It uses expression
automatic differentiation, bounded multistart gradient search, and progressive
constraint penalties. A low-dimensional equality-manifold search handles the
preserved two-variable constrained fixture. It is suitable for small teaching
models, but does not guarantee a global optimum for general nonlinear programs.

Legacy strict inequalities are solved as non-strict boundaries and produce a
structured warning. Native solving is limited to four variables. The
`validateOnly` backend parses and diagnoses without solving;
`externalHighPerformance` remains an explicit future integration point.

## macOS Workbench

The native Definition editor exposes the objective expression, objective sense,
variables with nullable bounds, and named expression constraints. Expressions
stay editable when invalid, with diagnostics from `QSBCore`. The interface
shows the native solver's approximate character and does not require JSON for
model entry. New rows receive focus and edits support macOS undo/redo.

Copy/Paste Table transfers variable/bound rows and constraint expressions to
and from Excel, Numbers, and LibreOffice. Each paste either applies the entire
table or retains the previous draft. A header-only constraint table clears the
constraints. Explicit variable table replacement can repair malformed imported
bound dimensions. Normalized file import, JSON Apply, and export use this same
typed draft. Compact and wide render checks include constraints and invalid
expressions; full runtime VoiceOver and keyboard traversal audits remain pending.

The solution workspace presents the objective expression, candidate objective
and variable values, bounds, iteration count, maximum violation, per-constraint
evaluations, exactness and solver assumptions. Values and constraint rows expose
accessibility text, adapt to compact widths, and retain normalized JSON as the
audit and export view.


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

Variables and constraints can be pasted independently while the title, objective,
or other table contains unfinished input. Each paste checks its own required fields,
column count, relations, and numeric cells before replacing anything. Expression
semantics remain in QSBCore validation. Full header matching prevents a variable
named `Variable` from being mistaken for a header. Unique existing names retain
row identities across reordering; duplicate names receive distinct identities.
An empty constraint table is supported. Paste retains the selected row when it
survives; runtime keyboard and VoiceOver verification remains pending.


## Imported dimensions

The native draft retains all imported variable names and lower/upper bounds,
including bounds beyond the named variables. Missing names remain empty. Missing
bounds display unbounded, with an explicit dimension review action before model
conversion. Accepting the displayed dimensions is undoable and does not bypass
required names, numeric conversion, or core validation. Replacing the entire
variable table also supplies an explicit complete bound row for each variable.


## Keyboard focus

Each variable name/bound and constraint name/expression/relation/right-hand side
has a distinct focus target. Replacing or undoing rows retains a surviving target
or chooses the nearest remaining row in the same field. Removing the last
constraint moves focus to Add Constraint. Runtime keyboard and VoiceOver checks
remain pending because the native inspection service fails during model creation.
