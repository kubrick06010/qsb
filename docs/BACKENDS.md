# Solver backends

Every current model family exposes a named backend seam in `QSBCore`.  The
CLI and macOS app select the seam by `SolverBackendKind`; parsers and
normalized JSON never depend on a concrete solver.

## Modes

| Mode | Purpose | Output |
| --- | --- | --- |
| `nativeEducational` | Deterministic Swift implementations for small and fixture-scale models | Structured solution plus run metadata |
| `validateOnly` | Parse and validate a recognized model without solving it | Diagnostics and validity status |
| `externalHighPerformance` | Host-provided high-performance engine; HiGHS for LP/MIP and LP-backed network/planning families | Structured solution when discovered; explicit unavailable status otherwise |

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

If an external backend is requested while no compatible executable is
installed, the CLI returns a stable, explicit error.  This is an environment
dependency, not a parser or native-solver failure.

## HiGHS LP/MIP adapter and family translations

`externalHighPerformance` is implemented for `LinearProgram` through the
standalone [HiGHS](https://github.com/ERGO-Code/HiGHS) executable.  HiGHS is
an open-source MIT-licensed solver for LP and mixed-integer models.  QSB does
not bundle the executable or link QSBCore to C++; the host installs and owns
the solver version.

Discovery checks `QSB_HIGHS_PATH` first and then searches `PATH` for `highs`.
The configured value may be an executable path, an installation directory, or
the command name:

```bash
QSB_HIGHS_PATH=/opt/highs/bin/highs swift run qsb solve-lp reference/winqsb/LP.LP_ --backend external
PATH=/opt/highs/bin:$PATH swift run qsb solve-ilp reference/winqsb/ILP.LP_ --backend external
```

The adapter validates the normalized model, writes a temporary free-MPS model,
invokes HiGHS with a temporary options file, parses the primal solution, and
maps sanitized MPS names back to the original JSON names.  Temporary files
and HiGHS logs are removed after the run.  Missing executables, nonzero exits,
infeasible/unbounded statuses, and malformed solution files are surfaced as
typed errors; QSB never falls back to the native backend silently.

The adapter covers LP and MIP models exposed as `LinearProgram`. The same
boundary now powers these typed family backends:

- `HiGHSNetworkBackend` translates minimum-cost flow (`CNF`) and balanced
  transportation (`TP`) and leaves graph-only variants native-only;
- `HiGHSAggregatePlanningBackend` translates the normalized continuous
  planning formulation;
- `HiGHSGoalProgrammingBackend` invokes HiGHS for each preemptive priority,
  preserving QSBCore's integer presolve and typed outcomes.

Family registries discover these wrappers only when the host executable is
available. Quadratic programming remains explicitly unavailable externally
while its quadratic interchange boundary is evaluated in
`docs/QUADRATIC_PROGRAMMING.md`; no quadratic term is silently discarded.

## External integration contract

The supported LP boundary is MPS export (`qsb export-mps`) plus the HiGHS
command-line adapter.  Any future adapter should:

1. validate the typed model;
2. export a temporary MPS/LP file without mutating the source fixture;
3. invoke a configured executable with a bounded time limit;
4. parse the solver's solution into a typed `LinearProgramSolution` (or the
   family-specific solution document);
5. preserve backend metadata, diagnostics, and the original normalized model;
6. return an unavailable/failed status when the executable or output is
   missing rather than falling back invisibly.

External tests use small deterministic models and skip the installed-engine
check when `highs` is absent. Injected backend tests exercise each typed family
translation without a binary; injected-executable tests remain portable;
native and validation-only tests are unconditional.

## Backend invariants

- `QSBCore` owns parsing, validation, model structures, and solution data;
- GUI and CLI code only select a backend and present its result;
- backend choice is visible in text and JSON output;
- validation can run without a solver executable;
- normalized JSON stays the interchange/debugging boundary;
- reference fixtures remain immutable and are never used as writable solver
  scratch space.
