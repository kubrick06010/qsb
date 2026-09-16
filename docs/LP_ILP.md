# Linear and Integer Programming

QSB keeps linear-programming models in `QSBCore` and exposes the same model
through the CLI and macOS workbench.  The normalized model contains the
objective sense, variable names, coefficients, relations, bounds, variable
types, and unrestricted-variable flags.  `LinearProgramJSON` is the stable
JSON boundary; decoding validates dimensions and finite values before a solve.

## Supported legacy scope

- Matrix-format and `NormalModel` WinQSB LP files;
- continuous maximization and minimization with `<=`, `>=`, and equality
  constraints;
- nonnegative, bounded, and unrestricted continuous variables;
- integer and binary variables for fixture-scale branch-and-bound.

The preserved fixtures are `reference/winqsb/LP.LP_` and
`reference/winqsb/ILP.LP_`.  Parsing and solving are covered by the
`QSBCoreTests` LP suite.

## Commands

```bash
swift run qsb validate-lp reference/winqsb/LP.LP_
swift run qsb solve-lp reference/winqsb/LP.LP_ [--backend native|validate]
swift run qsb solve-ilp reference/winqsb/ILP.LP_ [--backend native|validate]
swift run qsb export-json reference/winqsb/LP.LP_
swift run qsb export-mps reference/winqsb/LP.LP_
swift run qsb solve-json model.json [--backend native|validate]
```

`export-mps` also accepts a normalized LP/ILP JSON file.  It writes free MPS
with `OBJSENSE`, named rows, bounds, and integer markers.  The output is an
interchange artifact for an optional external solver; QSB does not require a
solver executable to be installed.

## Solver character

The native backend uses a two-phase simplex implementation for continuous
models and a deterministic branch-and-bound implementation for integer and
binary models.  Both are educational and intended for small or
fixture-scale problems.  They are not a replacement for a production MILP
engine.  `validateOnly` runs all structural and semantic checks without
solving.  `externalHighPerformance` remains an explicit unavailable route
until an external executable or library is supplied by the host environment.

LP-backed families (transportation, aggregate planning, goal programming,
and zero-sum games) reuse the same backend seam and can use the MPS exporter
when an external integration is added.

## JSON and compatibility notes

Existing JSON keys remain stable.  Optional bounds/type arrays decode to their
historical defaults, so older normalized files continue to load.  MPS names
are sanitized deterministically for solver compatibility; the native JSON
names are never changed.

The exporter reserves the objective row name and resolves sanitized row/column
name collisions deterministically. Numeric fields preserve finite `Double`
values on decimal round trip, including very small coefficients and values
outside the platform integer range; no solver tolerance is applied during
export. General integer variables without an upper bound receive an explicit
infinite upper bound, avoiding readers that otherwise interpret integer markers
as binary bounds. Continuous and general integer lower bounds are explicit,
including zero.

These interchange cases run in the portable test suite without legacy fixtures
or an installed solver. External-engine acceptance and solution comparisons
remain a separate integration checkpoint. See the
[MPS integrality and bounds reference](https://docs.gurobi.com/projects/optimizer/en/current/reference/fileformats/modelformats.html)
for the marker defaults this export makes explicit.

Known limitations are intentionally explicit: no presolve/cuts, no large-scale
numerical guarantees, no quadratic terms in the LP exporter, and no automatic
external-solver discovery beyond the host's own command environment.
