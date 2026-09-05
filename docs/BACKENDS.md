# Solver backends

Every current model family exposes a named backend seam in `QSBCore`.  The
CLI and macOS app select the seam by `SolverBackendKind`; parsers and
normalized JSON never depend on a concrete solver.

## Modes

| Mode | Purpose | Output |
| --- | --- | --- |
| `nativeEducational` | Deterministic Swift implementations for small and fixture-scale models | Structured solution plus run metadata |
| `validateOnly` | Parse and validate a recognized model without solving it | Diagnostics and validity status |
| `externalHighPerformance` | Reserved seam for CBC/CLP, HiGHS, OR-Tools, GLPK, or another host-provided engine | Currently reports unavailable; never silently falls back |

Native solutions identify their algorithm and exactness (`exact`,
`closedForm`, `approximate`, `heuristic`, or `fixtureScale`) in
`SolverRunMetadata`.  This prevents an educational approximation from being
presented as an industrial optimum.

## Selection and diagnostics

The default is native educational solving.  A caller can request validation
without solving:

```bash
swift run qsb solve-json model.json --backend validate
```

If an external backend is requested while no adapter is installed, the CLI
returns a stable, explicit error.  The current host was audited on
2026-08-31: `cbc`, `clp`, `highs`, `glpsol`, `scip`, and `ortools` are not on
`PATH`.  This is an environment dependency, not a parser or native-solver
failure.

## External integration contract

The first supported boundary is LP/MPS export (`qsb export-mps`).  A future
adapter should:

1. validate the typed model;
2. export a temporary MPS/LP file without mutating the source fixture;
3. invoke a configured executable with a bounded time limit;
4. parse the solver's solution into a typed `LinearProgramSolution` (or the
   family-specific solution document);
5. preserve backend metadata, diagnostics, and the original normalized model;
6. return an unavailable/failed status when the executable or output is
   missing rather than falling back invisibly.

External tests should use small deterministic models and skip when the
executable is absent.  Native and validation-only tests remain unconditional
and keep CI portable.

## Backend invariants

- `QSBCore` owns parsing, validation, model structures, and solution data;
- GUI and CLI code only select a backend and present its result;
- backend choice is visible in text and JSON output;
- validation can run without a solver executable;
- normalized JSON stays the interchange/debugging boundary;
- reference fixtures remain immutable and are never used as writable solver
  scratch space.
