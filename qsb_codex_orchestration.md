# Codex Orchestration Instructions — QSB Consolidation

Continue `kubrick06010/qsb` from the current worktree state.

Use the current `goal.md` as the source of truth. The previous checkpoint is now complete:

- native Decision Tree inspection view added;
- LP `NormalModel` unrestricted variables fixed using `x = x⁺ - x⁻`;
- regression added for an optimum requiring `x = -5`;
- portable test suite added and public CI now runs it;
- `swift test` passes 121 tests;
- macOS app verification passes at compact and wide sizes;
- `git diff --check` passes.

Do not redo any of that work.

## New checkpoint

**Core Consolidation and Generic CLI Routing**

Proceed in controlled phases. Do not perform a broad rewrite.

## Phase 0 — Audit first

Before modifying code:

1. Inspect the current repository and worktree.
2. Identify all local uncommitted/preexisting changes and preserve them.
3. Reconcile the actual code with `goal.md`.
4. Inspect at minimum:
   - `Sources/QSBCLI/main.swift`
   - `Sources/QSBCore/FacilitiesModel.swift`
   - `Sources/QSBCore/InventoryModel.swift`
   - `Sources/QSBCore/LPModel.swift`
   - `Tests/QSBCoreTests/LegacyCompressedFileTests.swift`
   - shared backend/validation infrastructure.
5. Produce a concrete partition plan showing:
   - proposed files;
   - responsibility of each file;
   - public APIs that must remain unchanged;
   - dependency risks;
   - tests protecting each refactor.

Do not change behavior during this audit.

## Phase A — Structural consolidation

Once the partition plan is clear, implement it incrementally.

### A1. Split `QSBCLI/main.swift`

Target shape should resemble:

```text
Sources/QSBCLI/
  main.swift
  CLI.swift

  Commands/
    LinearProgrammingCommands.swift
    NetworkCommands.swift
    ForecastingCommands.swift
    InventoryCommands.swift
    DynamicProgrammingCommands.swift
    DecisionAnalysisCommands.swift
    QueuingCommands.swift
    SchedulingCommands.swift
    FacilitiesCommands.swift
    ProjectSchedulingCommands.swift
    MarkovCommands.swift
    GoalProgrammingCommands.swift
    AcceptanceSamplingCommands.swift
    QualityControlCommands.swift
    AggregatePlanningCommands.swift
    MRPCommands.swift
    QuadraticProgrammingCommands.swift
    NonlinearProgrammingCommands.swift
    SimulationCommands.swift

  Support/
    ArgumentParsing.swift
    Output.swift
    Diagnostics.swift
```

Exact filenames may differ if the existing code suggests a cleaner split.

Requirements:

- preserve every existing CLI command;
- preserve argument semantics;
- preserve output formats;
- preserve exit codes;
- do not introduce a third-party argument parser yet;
- avoid a new monolithic router elsewhere.

### A2. Split `LegacyCompressedFileTests.swift`

Separate at least:

```text
Tests/QSBCoreTests/
  Legacy/
    LegacyCompressedFileTests.swift
    LegacyFixtureInventoryTests.swift
    LegacyModelImporterTests.swift

  LP/
  Network/
  Forecasting/
  Inventory/
  Facilities/
  ...
```

Move tests by responsibility without weakening coverage.

Preserve:

- all fixture classification tests;
- all 64 verified fixture import checks;
- all 53 reference-only rejection checks;
- portable tests independent of private fixtures.

### A3. Split large QSBCore domain files

Refactor without changing public APIs.

For Facilities, prefer separation around:

```text
Facilities/
  FacilitiesModel.swift
  FacilitiesBackend.swift
  FacilitiesJSON.swift

  LineBalancing/
    Model
    Parser
    Validator
    Solver

  Location/
    Model
    Parser
    Validator
    Solver

  Layout/
    Model
    Parser
    Validator
    Solver
```

Apply the same principle, proportionately, to:

- `InventoryModel.swift`
- `LPModel.swift`

The rule is:

> Model files should mainly contain domain representation, not parser + validation + JSON + solver + backend logic all together.

Do not create new Swift packages. Keep this inside the existing `QSBCore` target.

## Phase A verification

After each meaningful extraction:

```bash
swift test
swift build
git diff --check
```

Also run:

```bash
./script/build_and_run.sh --verify
```

after macOS-facing refactors.

Do not wait until the end to discover breakage.

## Phase B — Infrastructure convergence

Only begin after Phase A is behaviorally stable.

### B1. Validation plumbing

Audit repeated structures such as:

```swift
FooValidationDocument
FooSolutionDocument
FooBackend
NativeEducationalFooBackend
ValidateOnlyFooBackend
FooBackends.backend(for:)
```

Consolidate only genuinely common infrastructure.

Good candidates:

- shared validation document/report wrappers;
- backend resolution errors;
- common JSON encoder configuration;
- shared diagnostics helpers.

Do **not** force all domain backends into one overly generic associated-type protocol if it makes the APIs harder to use.

Keep domain protocols such as:

```swift
LinearProgrammingBackend
NetworkBackend
InventoryBackend
ForecastingBackend
```

unless there is a strong concrete reason to change them.

### B2. Numerical policy

Create a centralized numerical policy, e.g.:

```swift
NumericalDefaults.tolerance
NumericalDefaults.nearZero
```

Then audit hard-coded values such as:

```text
1e-8
1e-9
1e-12
1e-15
```

Use `SolverOptions.tolerance` where it semantically belongs.

Do not blindly replace every epsilon with one global value.

### B3. SolverOptions capability audit

For each backend, document which options are actually honored:

```text
timeLimitSeconds
nodeLimit
tolerance
randomSeed
explain
```

Avoid silently accepting ignored options.

Prefer explicit capability metadata or diagnostics for unsupported options.

### B4. Forecasting OLS

Replace the current OLS path based on:

```text
XᵀX
+
Gaussian elimination
```

with a numerically safer QR-based least-squares implementation.

Requirements:

- preserve existing result schema;
- preserve existing verified WinQSB fixture results within sensible tolerance;
- add tests for:
  - ordinary well-conditioned regression;
  - nearly collinear predictors;
  - rank-deficient design matrix;
- emit a structured diagnostic/error for rank deficiency.

Do not add a heavy numerical dependency unless clearly justified.

## Phase C — Generic CLI routing

Only after structural consolidation and infrastructure convergence are stable.

Implement generic commands consistent with `goal.md`:

```bash
qsb inspect <file>
qsb validate <file>
qsb export-json <file>
qsb solve <file> [--backend native|validate|external]
qsb solve-json <file> [--backend native|validate|external]
```

Requirements:

- use family auto-detection;
- use the same QSBCore import/backend routes as existing commands;
- preserve all existing family-specific commands as compatibility shortcuts;
- family-specific commands should delegate into common routing rather than duplicate solving logic;
- avoid needless command explosion;
- do not remove or rename stable commands.

For unsupported external backends, return a clear backend-unavailable error rather than `nil` or an ambiguous failure.

## Phase D — Documentation and roadmap reconciliation

Update `goal.md` only after implementation status is verified.

Also clean up stale sections where “Desired next improvements” describe work already completed.

Do not erase useful historical verification.

If `goal.md` has become too overloaded, propose a later split into:

```text
GOAL.md
ROADMAP.md
STATUS.md
VERIFICATION.md
```

but do not perform that split unless it is low risk and clearly beneficial within this checkpoint.

## Guardrails

- Preserve clean-room rules.
- Preserve all legacy fixture paths.
- Preserve normalized JSON compatibility unless a versioned migration is unavoidable.
- Keep parsing, validation, and solving out of SwiftUI.
- Do not couple typed models directly to HiGHS, OR-Tools, CBC, CLP, or other future external solvers.
- Do not start external solver integration in this checkpoint.
- Do not replace native educational solvers.
- Preserve deterministic outputs.
- Preserve preexisting local worktree changes.
- Prefer small, reviewable commits/refactors.
- No broad rewrite.
- No speculative abstractions without demonstrated duplication.

## Completion criteria

The checkpoint is complete only when:

1. oversized CLI/test/domain files are substantially decomposed;
2. public APIs remain stable;
3. generic CLI commands route through shared family detection;
4. family-specific commands remain functional;
5. portable CI still runs independently of private WinQSB fixtures;
6. unrestricted LP regression still passes;
7. OLS uses the new numerically safer path;
8. `swift test` passes;
9. macOS build/verification passes;
10. `git diff --check` passes;
11. `goal.md` reflects the actual state.

At the end, report:

- files moved/split;
- APIs changed, if any;
- duplicated infrastructure removed;
- numerical changes;
- generic CLI commands implemented;
- test count;
- verification results;
- anything deliberately deferred.

Proceed in this order:

**audit → structural consolidation → infrastructure convergence → OLS numerical fix → generic CLI → verification → roadmap update.**
