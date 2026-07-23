# QSB Porting Roadmap

This project is a clean-room modernization and compatibility replacement for the WinQSB application payload preserved in `reference/winqsb`.

The original WinQSB files are Windows 3.x / Visual Basic 3 binaries, help files, installer resources, manuals, and sample model files. They are reference artifacts, not source code.

The project should be understood as:

> A modern, native, portable operations research workbench that can read legacy WinQSB models, normalize them into open formats, solve them through transparent educational solvers or future external backends, and expose the same core through CLI and macOS GUI interfaces.

## Executive Direction

Do not reinvent mature optimization ecosystems unnecessarily.

Instead:

- preserve and understand WinQSB file formats;
- convert legacy models into typed Swift models and normalized JSON;
- provide simple native solvers where educational transparency and fixture-scale reproducibility matter;
- prepare external solver backends for large-scale or hard optimization problems;
- keep parsing, validation, solving, and UI layers separated;
- continue using legacy WinQSB samples as compatibility fixtures.

The project's defensible value is not "another LP solver." The value is:

- WinQSB compatibility;
- clean-room preservation;
- modern JSON/text interchange;
- portable command-line workflows;
- native macOS experience;
- solver-backend flexibility;
- educational explainability.

## Non-Negotiable Design Principles

1. **Clean-room implementation**
   - Do not decompile, modify, or reuse original WinQSB program code.
   - Use legacy files as fixtures, examples, and expected-behavior references only.

2. **Core before GUI**
   - `QSBCore` is the source of truth.
   - `qsb` CLI and `QSBMacApp` must call the same core.
   - No business logic should live only in the GUI.

3. **Open normalized formats**
   - Every supported family should move toward normalized JSON export.
   - JSON should be stable enough for tests, scripting, future GUI screens, and possible web/spreadsheet bridges.

4. **Fixture-driven compatibility**
   - Legacy files under `reference/winqsb` must remain stable test inputs.
   - Test names, docs, and examples should preserve fixture paths.
   - Each new parser or solver should be verified against one or more fixtures where possible.

5. **Backend abstraction**
   - Native educational solvers are good for transparency and small examples.
   - External high-performance backends should be possible later without rewriting parsers or UI.
   - The model layer must not depend directly on a single solver implementation.

6. **Explicit solver character**
   - Every solver should document whether it is exact, heuristic, approximate, fixture-scale, educational, or external-backed.
   - Do not imply industrial-grade performance where only textbook-scale coverage exists.

7. **Structured diagnostics**
   - Parser, validation, solver, and CLI errors should be explicit and testable.
   - Diagnostics should be useful in both CLI and GUI contexts.

## Target Architecture

```text
reference/winqsb
      |
      v
Legacy Discovery / Decompression / Classification
      |
      v
Family-Specific Parsers
      |
      v
Typed Swift Models  <---->  Normalized JSON
      |
      v
Validation Layer
      |
      v
Solver Backend Protocols
      |              |              |
      v              v              v
nativeEducational   validateOnly    externalHighPerformance
      |
      v
Structured Solution Models
      |
      v
CLI / macOS GUI / future frontends
```

## Proposed Module Boundaries

### `QSBCore`

Responsibilities:

- legacy file decoding and decompression utilities;
- file family detection;
- typed model definitions;
- parsers;
- validators;
- normalized JSON encoders/decoders;
- native educational solvers;
- solver backend protocols;
- structured solution models;
- domain-level diagnostics.

Must not depend on:

- SwiftUI;
- AppKit;
- GUI state;
- command-line argument parsing;
- macOS-only UI assumptions.

### `qsb`

Responsibilities:

- command-line argument parsing;
- invoking `QSBCore` workflows;
- printing human-readable summaries;
- printing JSON output;
- returning stable process exit codes;
- exposing inspect, validate, export, and solve commands.

Should prefer:

- generic commands where practical;
- family-specific shortcuts where already stable;
- explicit backend flags once backend abstraction exists.

### `QSBMacApp`

Responsibilities:

- open/import legacy files;
- edit or view normalized JSON;
- display validation diagnostics;
- invoke solve actions through `QSBCore`;
- show structured solution output;
- eventually provide family-specific visual editors and visualizations.

Should not:

- implement separate parsing logic;
- implement separate solving logic;
- require GUI-only paths for workflows that can be tested through CLI.

## Backend Architecture Proposal

Introduce explicit backend abstractions before adding too many more solvers.

### Core Types

Suggested conceptual types:

```swift
public enum SolverBackendKind: String, Codable, CaseIterable {
    case nativeEducational
    case validateOnly
    case externalHighPerformance
}

public struct SolverRequest<Model> {
    public var model: Model
    public var backend: SolverBackendKind
    public var options: SolverOptions
}

public struct SolverOptions: Codable, Equatable {
    public var timeLimitSeconds: Double?
    public var nodeLimit: Int?
    public var tolerance: Double?
    public var randomSeed: Int?
    public var explain: Bool
}

public protocol ModelSolver {
    associatedtype Model
    associatedtype Solution

    var backendKind: SolverBackendKind { get }
    var capabilities: SolverCapabilities { get }

    func validate(_ model: Model) throws -> [ValidationDiagnostic]
    func solve(_ request: SolverRequest<Model>) throws -> Solution
}
```

This exact API does not need to be adopted verbatim. Contributors may use
whatever languages, libraries, tools, or development environments best fit the
integration, provided that the architectural intent is preserved:

- solver choice is explicit;
- validation is separated from solving;
- native and external backends can share model structures;
- solution output remains structured.

### Backend Modes

#### `nativeEducational`

Purpose:

- default current behavior;
- deterministic;
- pure Swift;
- inspectable;
- good for tests and textbook examples.

Examples:

- two-phase simplex for small LPs;
- branch-and-bound for small ILPs;
- Dijkstra/Kruskal/Edmonds-Karp;
- EOQ/newsboy closed forms;
- M/M/1 closed forms;
- dynamic programming fixtures;
- flow-shop/job-shop fixture-scale exact solvers.

#### `validateOnly`

Purpose:

- support recognized model families before solving is implemented;
- provide useful parser and semantic diagnostics;
- enable JSON export/import round-trips;
- avoid blocking compatibility work on solver completeness.

Expected behavior:

- parse legacy file;
- build typed model;
- run validation;
- return diagnostics and model metadata;
- do not pretend to solve.

#### `externalHighPerformance`

Purpose:

- future integration path for mature solvers;
- large or hard optimization instances;
- industrial-grade MILP, CP-SAT, routing, scheduling, and network optimization.

Candidate external engines:

- CBC/CLP for LP/MILP;
- HiGHS for LP/MIP/QP-style optimization if integrated later;
- OR-Tools for routing, flows, assignment, scheduling, and CP-SAT;
- GLPK where licensing and deployment are acceptable;
- command-line LP/MPS exporters if direct library linking is undesirable.

Immediate rule:

- Do not make external backends mandatory yet.
- Design the seam now so they can be added later.

## Current Implementation Inventory

### Package and Project Infrastructure

Implemented:

- SwiftPM package;
- `QSBCore` library;
- `qsb` command-line executable;
- `QSBMacApp` SwiftUI shell;
- project-local `script/build_and_run.sh`;
- a repeatable developer or CI action for staging and launching the SwiftPM GUI
  as an `.app` bundle;
- normalized LP/ILP, network, facilities, inventory, and dynamic-programming
  JSON detection in the macOS shell;
- facilities solve/validate support in `QSBMacApp` through the same named
  `FacilitiesBackend` used by CLI workflows, including contextual initial and
  pairwise-swap layout strategies;
- inventory and dynamic-programming solve/validate support in `QSBMacApp`
  through the same `InventoryBackend` and `DynamicProgrammingBackend` used by
  CLI workflows, with runnable EOQ and bounded-knapsack samples;
- legacy WinQSB reference organization under `reference/winqsb`;
- foundational backend and validation diagnostic types in `QSBCore`;
- `swift test` verification with 118 passing tests as of 2026-07-16.

Next:

- ensure package boundaries remain clean;
- keep GUI logic thin;
- add backend abstractions in `QSBCore`;
- add common validation and diagnostics utilities.

### Legacy File Handling

Implemented:

- expansion for legacy Microsoft `SZDD` compressed files;
- preservation of binaries, help files, sample models, installer resources, and bundled manual as fixtures;
- JSON fixture inventory/classification through `LegacyFixtureInventory` and
  `qsb inventory-fixtures`, including restored filenames, compression metadata,
  family, role, support status, supported commands, and notes.
- typed import routing through `LegacyModelImporter`, shared by
  `qsb import-legacy-json` and QSBMacApp, for expansion, family detection,
  parsing, and normalized JSON conversion;
- exhaustive import verification for all 64 current model fixtures, with all 53
  executable, help, installer, manual, and runtime artifacts rejected as
  reference-only.

Next:

- maintain fixture classification as more model families become verified;
- use the inventory output to prioritize remaining sample families;
- add deeper content-level classification for partially supported families where useful.

### LP/ILP

Implemented:

- parser for WinQSB LP matrix-format files;
- parser support for WinQSB `MatrixFormat` and `NormalModel` LP files;
- parsing for lower bounds, upper bounds, and variable types;
- two-phase simplex solver for continuous LP relaxations with maximization, minimization, `<=`, `>=`, and equality constraints;
- branch-and-bound solver for integer and binary LP variables;
- normalized JSON import/export for LP/ILP models;
- normalized JSON solution output;
- normalized JSON schema reference in `docs/NORMALIZED_JSON.md`;
- dimension validation for objectives, bounds, types, and coefficient rows;
- semantic validation for duplicate variable names, finite numeric values, nonnegative lower bounds, ordered bounds, and binary bounds;
- named `LinearProgrammingBackend` seam with `NativeEducationalLinearProgrammingBackend`
  and `ValidateOnlyLinearProgrammingBackend`;
- explicit CLI error formatting;
- CLI commands: `inspect`, `solve-lp`, `solve-ilp`, `export-json`, `solve-json`, and `solve-json-ilp`.
- LP/ILP validation diagnostics exposed through `validate-lp`, `validate-json`,
  and `--backend native|validate` on LP/ILP solve commands.

Recommended next:

- route any remaining LP-backed families through named backend seams where useful;
- prepare optional MPS/LP export for external solvers;
- avoid adding advanced MILP features directly into the native solver unless needed for WinQSB fixture compatibility;
- document solver limitations clearly.

Acceptance criteria for next LP/ILP refactor:

- existing commands still work;
- existing tests still pass;
- backend choice is visible in CLI output;
- validation can run without solving;
- JSON output remains stable or versioned.

### Network Models

Implemented:

- minimum-cost network flow/transshipment (`CNF`) parser and LP-backed solver
  for `reference/winqsb/NETFLOW.NE_`, including explicit dummy-balance
  diagnostics and a regression against the manual's 7900 objective;
- shortest path (`SPP`) parser and Dijkstra solver with `qsb solve-spp`;
- minimum spanning tree (`MST`) parser and Kruskal solver with `qsb solve-mst`;
- max flow (`MFP`) parser and Edmonds-Karp solver with `qsb solve-maxflow`;
- traveling salesperson (`TSP`) parser and exact dynamic programming solver with `qsb solve-tsp`;
- assignment (`AP`) parser and Hungarian-style solver with `qsb solve-assignment`;
- transportation (`TP`) parser and LP-backed solver routed through the named
  `LinearProgrammingBackend` seam with `qsb solve-transport`, plus structured
  validation diagnostics with `qsb validate-transport`;
- normalized JSON import/export and JSON solution output for supported network models;
- named `NetworkBackend` seam with native educational and validation-only
  implementations across all seven variants;
- structured validators, family-specific validation commands, and generic
  `validate-network-json` output;
- enriched solution documents with model, discriminated solution, backend
  algorithm, exactness, and assumptions, shared by CLI and macOS;
- CLI commands: `export-network-json`, `solve-network-json`, and
  `validate-network-json`.

Recommended next:

- consider `externalHighPerformance` hooks for larger TSP/routing/assignment variants;
- add family-specific macOS diagrams and editors beyond normalized JSON.

### Forecasting

Implemented:

- legacy WinQSB multiple regression (`FC ... 1`) parser and ordinary least squares solver with `qsb solve-regression`;
- legacy WinQSB time-series forecasting (`FC ... 0`) parser and least-squares linear trend solver with `qsb solve-timeseries`;
- simple moving-average solver with `qsb solve-moving-average`;
- simple exponential-smoothing solver with `qsb solve-exp-smoothing`;
- multiplicative seasonal decomposition with `qsb solve-seasonal`;
- verified fixture support for `reference/winqsb/SALES.FC_`.
- normalized `ForecastingRequest` and discriminated solution documents for all
  five methods, including fitted values, residuals, metrics, forecasts, and
  backend metadata;
- public structured validation and a named `ForecastingBackend` seam with
  native educational and validation-only implementations;
- generic `export-forecast-json`, `solve-forecast-json`, and
  `validate-forecast-json` CLI workflows.
- normalized forecasting request detection, import, validation, and solving in
  the macOS workbench through the same `ForecastingBackend` used by the CLI;
- a runnable Linear Trend Forecast GUI sample with an explicit forecast horizon.

Recommended next:

- add an explicit pre-solve rank diagnostic for degenerate regression design
  matrices (the native solver currently reports singularity during solving);
- document which results are expected to match WinQSB and which are modern educational approximations;
- support validation-only for unimplemented forecasting variants.

### Inventory

Implemented:

- legacy WinQSB EOQ (`ITS ... 0 0`) parser and solver with `qsb solve-eoq`;
- all-units quantity discount EOQ (`ITS ... 1 1`) parser and solver with `qsb solve-discount-eoq`;
- newsboy inventory (`ITS ... 2 2`) parser and normal-demand newsvendor solver with `qsb solve-newsboy`;
- finite-horizon lot sizing (`ITS ... 3`) parser and dynamic programming solver with `qsb solve-lot-sizing`;
- all four preserved stochastic modes (`ITS ... 4` through `7`) covering
  continuous `(Q,r)`, continuous order-up-to, periodic fixed-interval, and
  periodic optional-replenishment policies;
- normal-demand loss-function approximations, service/safety metrics, expected
  shortage and annual cost breakdowns, with explicit approximate metadata;
- public structured validators and a named `InventoryBackend` seam with native
  educational and validation-only implementations across all eight variants;
- `--backend native|validate` on legacy solve commands plus explicit
  `validate-eoq`, `validate-discount-eoq`, `validate-newsboy`, and
  `validate-lot-sizing` commands;
- normalized discriminated model and solution envelopes with backend metadata,
  assumptions, typed solutions, and validation documents through
  `export-inventory-json`, `solve-inventory-json`, and
  `validate-inventory-json`.

Recommended next:

- add richer family-specific inventory presentation beyond normalized JSON;
- add empirical or non-normal lead-time demand through a future external backend;
- add simulation-based validation of service levels and shortage costs.

### Dynamic Programming

Implemented:

- bounded knapsack (`DP ... KS`) parser and solver with `qsb solve-knapsack`;
- stagecoach shortest-route (`DP ... SC`) parser and solver with `qsb solve-stagecoach`;
- production/inventory planning (`DP ... PIS`) parser and solver with `qsb solve-prod-inventory`.
- public structured validators and a named `DynamicProgrammingBackend` seam
  with native educational and validation-only implementations;
- `--backend native|validate` on legacy solve commands plus explicit family
  validation commands;
- normalized discriminated model/solution JSON through `export-dp-json`,
  `solve-dp-json`, and `validate-dp-json`;
- educational policy traces standardized around stages, states, actions,
  transitions, and values for all three supported variants.

Recommended next:

- deepen value-function traces beyond the reconstructed optimal policy when an
  explicit explain option is added;
- use validation-only for DP variants where the parser can recognize the model but solver is incomplete.

### Scheduling

Implemented:

- flow-shop scheduling (`SCH ... -1`) parser and exact fixture-scale makespan solver with `qsb solve-flowshop`;
- job-shop scheduling (`SCH ... 0`) parser and exact fixture-scale makespan solver with `qsb solve-jobshop`;
- structured scheduling validation diagnostics and `--backend native|validate`
  support for flow-shop and job-shop commands;
- named `SchedulingBackend` seam with `NativeEducationalSchedulingBackend`
  and `ValidateOnlySchedulingBackend`;
- Gantt-friendly `SchedulingSolutionDocument` JSON through
  `qsb solve-flowshop-json` and `qsb solve-jobshop-json`;
- verified support for `reference/winqsb/FLOWSHOP.JO_` and `reference/winqsb/JOBSHOP.JO_`.

Recommended next:

- prepare future OR-Tools CP-SAT or other constraint-programming backend integration;
- add broader impossible-schedule diagnostics where applicable.

### Facilities and Workflow

Implemented:

- assembly line balancing (`FLL ... LINE BALANCING`) parser, validation diagnostics, normalized model/solution JSON, and exact fixture-scale station minimization solver with `qsb solve-line-balancing`, `qsb solve-line-balancing-json`, and generic `qsb solve-facilities-json`;
- single-new-facility location (`FLL ... LOCATION`) parser, validation diagnostics, normalized model/solution JSON, and continuous weighted-distance solver with `qsb solve-location`, `qsb solve-location-json`, and generic `qsb solve-facilities-json`;
- facility layout (`FLL ... LAYOUT`) parser, validation diagnostics, normalized model/solution JSON, initial-layout load-distance evaluation, and fixture-scale pairwise-swap local search with `qsb solve-layout`, `qsb solve-layout-json`, and generic `qsb solve-facilities-json`;
- named `FacilitiesBackend` seam with native educational and validation-only implementations, typed and generic-envelope solving, layout strategy selection, and backend-owned run metadata;
- all legacy, family-specific JSON, and generic facilities-envelope CLI solve paths routed through the same `FacilitiesBackend` selected in `QSBCore`;
- verified support for `reference/winqsb/LINEBAL.FL_`, `reference/winqsb/LOCATION.FL_`, and `reference/winqsb/LAYOUT.FL_`.

Next priority:

- add remaining facilities/workflow fixtures beyond the bundled line, location, and layout examples;
- broaden layout improvement beyond same-size pairwise swaps only when model scope is clear;
- extend layout solution JSON with richer move/improvement data for future heuristics;
- continue documenting assumptions and warnings for fixed aisles, blocked cells, and overlapping layout regions.

Potential layout output fields:

- departments/workcenters;
- coordinates;
- dimensions;
- adjacency or closeness ratings;
- material flows;
- distance matrix;
- cost matrix;
- objective value;
- proposed layout positions;
- warnings/assumptions.

### Decision Analysis

Implemented:

- payoff tables (`DA ... PT`) with prior/posterior EV, EVSI, and EVPI through `qsb solve-payoff`;
- Bayesian analysis (`DA ... BA`) with posterior probabilities through `qsb solve-bayesian`;
- decision trees (`DA ... DT`) with rollback analysis through `qsb solve-decision-tree`;
- zero-sum games (`DA ... ZS`) solved through the shared LP core and named
  `LinearProgrammingBackend` seam with `qsb solve-game`, plus structured
  validation diagnostics with `qsb validate-game`.
- named `DecisionAnalysisBackend` seam spanning all four variants, with native
  educational and validation-only implementations;
- normalized discriminated model and solution documents preserving posterior
  tables, EVSI/EVPI, full tree structure, rollback values, policy decisions,
  and mixed strategies;
- generic `export-decision-json`, `solve-decision-json`, and
  `validate-decision-json` workflows plus structured family validation commands.
- macOS workbench detection, import, validation, and solving for all four
  normalized variants through the same backend, with payoff and decision-tree
  samples.

Recommended next:

- add family-specific macOS tables and tree visualization beyond the normalized
  JSON workbench;
- retain the LP backend seam for mixed strategies when external LP backends arrive.

### Queuing

Implemented:

- M/M/1 queues (`QA ... 0`) with closed-form performance and cost metrics through `qsb solve-mm1`;
- finite-capacity multi-server queue (`QA ... 1`) parser and mean-rate birth-death approximation through `qsb solve-finite-queue`;
- structured `MM1QueueValidator` and `FiniteCapacityQueueValidator` diagnostics for rates, stability, servers, capacity, distributions, batch size, and costs;
- named `QueuingBackend` seam with native educational and validation-only implementations, exposed by `--backend native|validate` and explicit validate commands;
- normalized `QueuingSolutionDocument` output through `qsb solve-mm1-json` and `qsb solve-finite-queue-json`, including backend metadata, notation, assumptions, common performance metrics, state probabilities, and normalized costs;
- verified support for `reference/winqsb/QUEUE1.QA_` and `reference/winqsb/QUEUE2.QA_`.

Recommended next:

- add normalized model JSON import/export in addition to solution JSON;
- classify and validate additional recognized WinQSB queue variants before solving them;
- add a future simulation or external queue backend for distributions that the mean-rate birth-death approximation does not model faithfully;
- add richer diagnostics for finite-population, bulk-arrival, and non-exponential interarrival variants.

## Roadmap Phases

### Phase 0 — Preservation and Orientation

Status: substantially complete.

Goals:

- collect WinQSB payload under `reference/winqsb`;
- keep original binaries/manual/sample files as fixtures;
- identify file extensions and model families;
- create SwiftPM package and initial CLI.

Done:

- reference fixture structure exists;
- SwiftPM package exists;
- CLI exists;
- macOS shell exists;
- SZDD expansion exists.

### Phase 1 — LP/ILP Foundation

Status: implemented and verified for current supported scope.

Goals:

- implement LP/ILP parsers;
- implement small educational LP/ILP solvers;
- define normalized JSON model and solution formats;
- create CLI workflows;
- establish validation and tests.

Done:

- LP/ILP parsing;
- simplex;
- branch-and-bound;
- JSON import/export;
- CLI commands;
- validation;
- GUI shell support for JSON editing and solving.

Next refinement:

- backend abstraction;
- validation-only command paths;
- optional external solver export/integration seam.

### Phase 2 — Multi-Family Coverage

Status: implemented and exhaustively verified for the current preserved payload.

Goals:

- expand beyond LP/ILP;
- prioritize fixtures with clear file formats and algorithmic boundaries;
- preserve compatibility while building normalized model families.

Implemented families:

- networks;
- forecasting;
- inventory;
- dynamic programming;
- decision analysis;
- queuing;
- scheduling;
- facilities.
- PERT/CPM project scheduling.
- Markov processes.
- goal programming.
- acceptance sampling.

### PERT/CPM

Implemented:

- deterministic CPM and three-estimate PERT parsers for matrix and graphic
  fixtures;
- normalized discriminated model, solution, and validation JSON;
- exact DAG forward/backward scheduling with earliest/latest times, slack, and
  critical activities;
- PERT expected times, activity variances, critical-path variance, and standard
  deviation;
- named `ProjectSchedulingBackend` with native educational and validation-only
  modes;
- legacy and JSON CLI solve/validate/export workflows;
- verified coverage for all four preserved PERT/CPM fixtures.

Recommended next:

- add CPM crash-cost/time tradeoff optimization without changing the normal-time
  critical-path command;
- add project-network and Gantt-style views to the macOS workbench;
- consider a future external scheduling backend for larger project networks.

### Markov Processes

Implemented:

- parser coverage for both preserved finite-state `MKP` fixtures;
- normalized model/request, solution, and validation JSON;
- exact stationary linear-system analysis and optional transient propagation;
- expected state costs for stationary and transient distributions;
- structured stochastic-matrix and initial-distribution validation;
- named `MarkovBackend` with native educational and validation-only modes;
- legacy and JSON CLI solve/validate/export workflows.

Recommended next:

- add communicating-class diagnostics for reducible chains before solving;
- add a state-transition matrix/editor and probability chart to the macOS app;
- reserve external integration for sparse or very large state spaces.

### Goal Programming

Implemented:

- matrix and normal-model parsing through shared LP parser semantics;
- continuous and integer goal-program fixtures;
- ordered preemptive lexicographic optimization through
  `LinearProgrammingBackend`;
- structured validation, normalized model/solution JSON, and backend metadata;
- native educational and validation-only `GoalProgrammingBackend` modes;
- legacy and JSON CLI solve/validate/export workflows;
- verified coverage for all three preserved Goal Programming fixtures.

Recommended next:

- route a future external LP/MIP backend through the existing seam for larger
  integer goal programs;
- add priority/outcome tables to the macOS workbench;
- retain explicit `fixtureScale` characterization for native integer solving.

### Acceptance Sampling

Implemented:

- single and double binomial plan parsers for both preserved fixtures;
- exact OC probabilities, actual producer/consumer risks, ASN, ATI, and AOQ;
- normalized model/solution/validation JSON with diagram-ready OC points;
- structured validation and a named `AcceptanceSamplingBackend` with native
  educational and validation-only modes;
- legacy and JSON CLI solve/validate/export workflows;
- `qsb expand` for complete non-mutating SZDD payload inspection.

Recommended next:

- add automatic plan design and hypergeometric finite-lot evaluation;
- model nonzero inspection-classification errors if fixtures become available;
- add OC/AOQ charts to the macOS workbench.

### Quality Control

Implemented:

- parsers for all five preserved c-chart, p-chart, Xbar-R, Pareto, and normal
  probability plot fixtures;
- classical three-sigma control limits, standard Xbar-R constants, descending
  Pareto aggregation, and Blom-score normal probability fitting;
- structured validation and a named `QualityControlBackend` with native
  educational and validation-only modes;
- normalized model, solution, and validation JSON with chart-ready points;
- legacy and JSON CLI solve/validate/export workflows.

Recommended next:

- preserve cause/action/comment metadata in an optional normalized extension;
- evaluate configured Western Electric run rules;
- add control-chart and Pareto visualizations to the macOS workbench.

### Aggregate Planning

Implemented:

- normalized parsing for all three preserved simple, LP, and transportation
  aggregate-planning fixtures;
- period demand, workforce, capacity, hiring/dismissal, overtime,
  subcontracting, inventory, safety-stock, and backorder semantics;
- an exact continuous LP formulation routed through `LinearProgrammingBackend`;
- structured validation and a named `AggregatePlanningBackend` with native
  educational and validation-only modes;
- normalized model/solution/validation JSON and complete legacy/JSON CLI flows.

Recommended next:

- expose optional integer workforce domains through an external MIP backend;
- add period tables and stacked production/inventory charts to the macOS app;
- compare additional historical outputs if more aggregate fixtures are found.

### Material Requirements Planning

Implemented:

- complete Item Master, BOM, MPS, inventory, scheduled-receipt, and capacity
  parsing for the preserved MRP fixture;
- explicit overdue plus twelve-period normalized scheduling buckets;
- deterministic multi-level explosion from parent planned releases to component
  gross requirements;
- LFL, EOQ, LUC, LTC, and PPB lot-sizing behavior;
- capacity-excess reporting, structured validation, normalized JSON, and a
  named native educational/validation-only backend seam;
- complete legacy and JSON CLI solve/validate/export workflows.

Recommended next:

- add finite-capacity rescheduling or an external planning backend;
- add pegging records that trace each component requirement to its parent;
- add BOM and time-phased schedule views to the macOS workbench.

### Quadratic Programming

Implemented:

- MatrixFormat and NormalModel parsers normalized to one symmetric quadratic
  objective representation with shared linear constraints and bounds;
- exact active-set KKT enumeration for strictly convex/concave continuous QP;
- mathematically bounded fixture-scale enumeration for supported diagonal IQP;
- structured curvature, dimension, bound, and integer-scope diagnostics;
- named native educational/validation-only backend modes, normalized JSON, and
  complete legacy/JSON CLI workflows for all three preserved fixtures.

Recommended next:

- route general convex QP and MIQP to HiGHS or another external backend;
- add contour/objective and active-constraint views to the macOS workbench;
- retain explicit rejection of indefinite native models rather than returning
  an unqualified local optimum.

### Nonlinear Programming

Implemented:

- parser coverage for all three preserved `.NL_` fixtures;
- case-insensitive expression parsing with arithmetic, powers, implicit
  multiplication, and common elementary functions;
- automatic differentiation plus deterministic bounded multistart and
  progressive-penalty optimization;
- a low-dimensional equality-manifold search for the preserved constrained
  fixture;
- structured diagnostics, normalized model/solution JSON, complete legacy and
  JSON CLI workflows, and native educational/validation-only backend modes.

Solver character and next refinement:

- native results are approximate and general global optimality is not
  guaranteed;
- strict legacy inequalities normalize to non-strict boundaries with a warning;
- native solving is limited to four variables;
- route larger or harder NLP models to a future external high-performance
  backend and add objective/constraint visualization to the macOS workbench.

### Simulation

Implemented:

- parser coverage for all four preserved `.QS_` fixtures in Matrix and Graphic
  representations;
- a shared typed component network for sources, queues, servers, routes,
  capacities, entity types, and distributions;
- deterministic-seed discrete-event execution with finite FIFO queues,
  alternate servers, transfers, routing, and assembly synchronization;
- structured diagnostics, normalized model/solution JSON, complete legacy and
  JSON CLI workflows, and native educational/validation-only backend modes.

Solver character and next refinement:

- native output is a stochastic estimate from one seeded replication;
- warm-up deletion, repeated runs, confidence intervals, gate behavior beyond
  the preserved payload, and interactive event traces remain future work;
- Simulation import, validation, solving, sample loading, and structured metric
  output are available in the macOS workbench through the existing backend seam;
- next add richer queue/server metric views and configurable replication options.

Next refinement:

- standardize JSON outputs across families;
- add family-level docs;
- increase fixture discovery and classification;
- avoid command explosion by considering generic routing commands.

### Phase 3 — Backend Abstraction

Status: implemented for every current QSBCore family.

Goals:

- introduce solver backend protocols;
- preserve existing native behavior;
- allow `validateOnly` mode;
- prepare `externalHighPerformance` integration;
- record backend metadata in solution output.

Completed scope:

1. All 19 current family registries expose native educational, validate-only,
   and explicit unavailable external-high-performance routing.
2. Solution documents record backend algorithm and exactness metadata.
3. CLI backend flags preserve native defaults and legacy command behavior.
4. Validation-only and normalized JSON workflows are available across current
   model families.

Acceptance criteria:

- `swift test` passes;
- current CLI commands still work;
- LP/ILP, scheduling, queuing, inventory, and facilities CLI output report backend used where applicable;
- validation-only can be invoked for LP/ILP, scheduling, queuing, inventory, and facilities;
- docs explain native vs external backend strategy.

### Phase 4 — Facilities/Layout Continuation

Status: implemented and exhaustively classified for the current preserved
payload.

Goals:

- continue remaining facilities/workflow fixtures;
- prioritize layout models;
- parse and validate before solving;
- produce diagram-ready normalized outputs.

Completed evidence:

1. The current payload contains exactly three model fixtures:
   `LINEBAL.FL_`, `LOCATION.FL_`, and `LAYOUT.FL_`.
2. All three have parser, validation, normalized JSON, backend, CLI, and
   regression-test coverage.
3. `FLL.EX_` and `FLLHELP.HL_` are explicitly classified as reference-only
   executable/help artifacts, not models.
4. An exhaustive inventory test fails if the preserved Facilities payload
   gains an unclassified artifact.
5. Layout solution JSON carries diagram-ready placements, distances, flows,
   objective contributions, and optional local-search metadata.

Reopen this phase when additional clean-room Facilities fixtures are added to
`reference/winqsb`.

### Phase 5 — GUI Evolution

Status: all normalized QSBCore model families and direct legacy-file imports are
routed through the shell; deeper family-specific UX remains pending.

Implemented in the current shell:

- normalized JSON import/edit/export and solution export;
- direct legacy model import through the shared QSBCore `LegacyModelImporter`;
- model-family detection for every normalized QSBCore model/request envelope;
- native educational and validation-only backend selection;
- facilities validation and structured solution JSON through `FacilitiesBackend`;
- contextual initial/pairwise strategy selection for facility-layout models;
- a runnable Facility Layout sample and native menu/toolbar actions.
- inventory and dynamic-programming validation/solve actions through the same
  named core backends, with runnable EOQ and Bounded Knapsack samples.
- one contextual solve action that routes all normalized families through their
  shared core backend, plus QP, NLP, Markov, Goal Programming, and Simulation
  samples.
- a native responsive scheduling Gantt view for flow-shop and job-shop solution
  documents, with Timeline/JSON switching, adjustable scale, machine rows,
  operation accessibility labels, and backend/makespan context.
- a native responsive network solution view for all seven variants, with
  deterministic circular and bipartite diagrams, active route/flow/tour/tree or
  allocation highlighting, structured detail rows, adjustable scale,
  accessibility labels, backend context, and Diagram/JSON switching.
- a native responsive forecasting chart for all five methods, with actual,
  fitted/predicted, forecast, and signed residual series, method parameters and
  fit metrics, visibility/scale controls, accessibility values, backend
  context, and Chart/JSON switching.

Goals:

- keep GUI as a thin wrapper over `QSBCore`;
- support opening legacy files;
- show parsed model metadata;
- show normalized JSON;
- show validation diagnostics;
- solve through selected backend;
- display family-specific solution views.

GUI milestones:

1. File open/import for legacy models: implemented.
2. Model family detection display: implemented.
3. JSON editor/viewer with validation: implemented.
4. Solve panel with backend selector: implemented.
5. Solution JSON viewer: implemented.
6. Family-specific visualizations: ongoing.
   - LP tables;
   - network paths/flows/tours: implemented;
   - forecasting charts: implemented;
   - inventory cost breakdowns;
   - DP stage tables;
   - decision trees;
   - queue metrics;
   - scheduling Gantt charts: implemented;
   - facilities layouts.

Next priority:

- add inventory cost-breakdown and facilities-layout views from the existing
  typed solution documents;
- retain the JSON solution view as a fallback and keep all transformations in
  QSBCore or thin presentation adapters.

### Phase 6 — External Solver Integration

Status: future.

Goals:

- add optional high-performance backends without making them mandatory;
- start with export-based integration if library linking is too complex;
- keep native educational solvers as deterministic defaults.

Candidate sequence:

1. Add LP/MPS export for LP/ILP.
2. Add a command-line external solver adapter if available locally.
3. Parse external solution output back into structured solution models.
4. Add backend metadata and warnings.
5. Add tests using small models and skip external tests when solver is absent.
6. Consider direct library integration only after CLI/export path is stable.

Potential integrations:

- CBC/CLP for LP/MILP;
- HiGHS for LP/MIP where appropriate;
- OR-Tools for CP-SAT scheduling/routing/network variants;
- GLPK if deployment/licensing constraints are acceptable.

## Command-Line Direction

Existing commands should remain stable.

Current commands include:

```bash
swift run qsb inspect <file>
swift run qsb inventory-fixtures <reference-directory>
swift run qsb solve-lp <file> [--backend native|validate]
swift run qsb solve-ilp <file> [--backend native|validate]
swift run qsb validate-lp <file>
swift run qsb export-json <file>
swift run qsb solve-json <json-file> [--backend native|validate]
swift run qsb solve-json-ilp <json-file> [--backend native|validate]
swift run qsb validate-json <json-file>
swift run qsb solve-spp <file>
swift run qsb solve-mst <file>
swift run qsb solve-maxflow <file>
swift run qsb solve-tsp <file>
swift run qsb solve-assignment <file>
swift run qsb solve-transport <file> [--backend native|validate]
swift run qsb validate-transport <file>
swift run qsb export-network-json <file>
swift run qsb solve-network-json <json-file>
swift run qsb solve-regression <file>
swift run qsb solve-timeseries <file> <periods>
swift run qsb solve-moving-average <file> <window> <periods>
swift run qsb solve-exp-smoothing <file> <alpha> <periods>
swift run qsb solve-seasonal <file> <season-length> <periods>
swift run qsb solve-eoq <file>
swift run qsb solve-discount-eoq <file>
swift run qsb solve-newsboy <file>
swift run qsb solve-lot-sizing <file>
swift run qsb solve-knapsack <file>
swift run qsb solve-stagecoach <file>
swift run qsb solve-prod-inventory <file>
swift run qsb solve-flowshop <file>
swift run qsb solve-flowshop-json <file> [--backend native|validate]
swift run qsb solve-jobshop <file>
swift run qsb solve-jobshop-json <file> [--backend native|validate]
swift run qsb export-facilities-json <file>
swift run qsb validate-facilities-json <json-file>
swift run qsb solve-facilities-json <json-file> [--backend native|validate] [--layout-strategy initial|pairwise-swap]
swift run qsb solve-line-balancing <file> [--backend native|validate]
swift run qsb validate-line-balancing <file>
swift run qsb export-line-balancing-json <file>
swift run qsb solve-line-balancing-json <json-file> [--backend native|validate]
swift run qsb solve-location <file> [--backend native|validate]
swift run qsb validate-location <file>
swift run qsb export-location-json <file>
swift run qsb solve-location-json <json-file> [--backend native|validate]
swift run qsb solve-layout <file> [--backend native|validate] [--layout-strategy initial|pairwise-swap]
swift run qsb validate-layout <file>
swift run qsb export-layout-json <file>
swift run qsb solve-layout-json <json-file> [--backend native|validate] [--layout-strategy initial|pairwise-swap]
swift run qsb solve-payoff <file>
swift run qsb solve-bayesian <file>
swift run qsb solve-decision-tree <file>
swift run qsb solve-game <file> [--backend native|validate]
swift run qsb validate-game <file>
swift run qsb solve-mm1 <file> [--backend native|validate]
swift run qsb solve-mm1-json <file> [--backend native|validate]
swift run qsb validate-mm1 <file>
swift run qsb solve-finite-queue <file> [--backend native|validate]
swift run qsb solve-finite-queue-json <file> [--backend native|validate]
swift run qsb validate-finite-queue <file>
```

Future generic direction:

```bash
swift run qsb inspect <legacy-file>
swift run qsb validate <legacy-file>
swift run qsb export-json <legacy-file> [--family auto|lp|network|forecasting|inventory|dp|scheduling|facilities|decision|queue]
swift run qsb solve <legacy-file> [--family auto] [--backend native|validate|external] [--json]
swift run qsb solve-json <json-file> [--backend native|validate|external] [--json]
swift run qsb compare-fixture <legacy-file> [--expected <json-or-snapshot>]
```

Do not remove existing commands just to pursue generic elegance. Prefer backward compatibility.

## JSON and Schema Direction

Each family should move toward:

- normalized model JSON;
- normalized solution JSON;
- schema documentation;
- examples from fixtures;
- round-trip tests where feasible.

Every solution JSON should ideally include:

```json
{
  "family": "...",
  "modelName": "...",
  "source": {
    "kind": "legacyWinQSB",
    "path": "reference/winqsb/..."
  },
  "backend": {
    "kind": "nativeEducational",
    "algorithm": "...",
    "exactness": "exact|heuristic|approximate|closedForm|fixtureScale"
  },
  "status": "optimal|feasible|infeasible|unbounded|invalid|unsupported|error",
  "objective": {},
  "solution": {},
  "diagnostics": []
}
```

Use schema versioning if backward-incompatible changes become necessary.

## Diagnostics Direction

Standardize diagnostics across families.

Suggested diagnostic fields:

```swift
public struct ValidationDiagnostic: Codable, Equatable {
    public var severity: DiagnosticSeverity
    public var code: String
    public var message: String
    public var fieldPath: String?
    public var sourceLocation: SourceLocation?
}
```

Suggested severities:

- `info`;
- `warning`;
- `error`;
- `unsupported`.

Examples:

- invalid bound ordering;
- non-finite coefficient;
- duplicate variable name;
- probability sum not equal to one;
- negative service rate;
- unsupported model variant;
- insufficient periods for forecasting;
- missing facility coordinates;
- scheduling operation references nonexistent machine.

## Testing Strategy

Every new model variant should aim for four test layers:

1. **Discovery/classification**
   - The fixture is recognized as a family and variant.

2. **Parsing**
   - Legacy file becomes a typed model.

3. **Validation/JSON**
   - Model validates or produces expected diagnostics.
   - Model exports to JSON.
   - JSON can be read back without semantic loss where supported.

4. **Solving**
   - Native educational solver returns deterministic expected output, or
   - validate-only returns expected unsupported diagnostics, or
   - external backend test is skipped unless backend is available.

Snapshot testing may be useful for stable JSON outputs, but avoid brittle formatting if semantic comparisons are available.

## Documentation Strategy

Keep docs close to the implementation.

Recommended docs:

- `docs/NORMALIZED_JSON.md` for shared JSON conventions;
- family-specific docs such as:
  - `docs/LP_ILP.md`;
  - `docs/NETWORK_MODELS.md`;
  - `docs/FORECASTING.md`;
  - `docs/INVENTORY.md`;
  - `docs/DYNAMIC_PROGRAMMING.md`;
  - `docs/SCHEDULING.md`;
  - `docs/FACILITIES.md`;
  - `docs/DECISION_ANALYSIS.md`;
  - `docs/QUEUING.md`;
  - `docs/BACKENDS.md`.

Each family doc should include:

- supported legacy variants;
- fixture files;
- CLI commands;
- JSON model shape;
- JSON solution shape;
- solver algorithm;
- assumptions and limitations;
- known unsupported variants;
- next planned work.

## Current Verified Commands and Expected Results

As of 2026-07-16:

```bash
swift test
```

passes 118 tests on macOS and in the official Swift 6.0 Linux container.

Backend/validation commands:

```bash
swift run qsb validate-lp reference/winqsb/LP.LP_
# status = valid
# backend = validateOnly

swift run qsb solve-lp reference/winqsb/LP.LP_ --backend native
# objective = 3780
# backend = nativeEducational

swift run qsb solve-json <exported LP JSON> --backend validate
# status = valid
# backend = validateOnly

swift run qsb validate-flowshop reference/winqsb/FLOWSHOP.JO_
# status = valid
# backend = validateOnly

swift run qsb solve-jobshop reference/winqsb/JOBSHOP.JO_ --backend validate
# status = valid
# backend = validateOnly

swift run qsb validate-transport reference/winqsb/TRNSPORT.NE_
# status = valid
# backend = validateOnly

swift run qsb solve-transport reference/winqsb/TRNSPORT.NE_ --backend validate
# status = valid
# backend = validateOnly

swift run qsb validate-game reference/winqsb/GAME.DA_
# status = valid
# backend = validateOnly

swift run qsb solve-game reference/winqsb/GAME.DA_ --backend validate
# status = valid
# backend = validateOnly

swift run qsb validate-mm1 reference/winqsb/QUEUE1.QA_
# status = valid
# backend = validateOnly

swift run qsb solve-finite-queue reference/winqsb/QUEUE2.QA_ --backend validate
# status = valid
# backend = validateOnly
# warning = service distribution approximated by its mean rate

swift run qsb validate-line-balancing reference/winqsb/LINEBAL.FL_
# status = valid
# backend = validateOnly

swift run qsb solve-line-balancing reference/winqsb/LINEBAL.FL_ --backend validate
# status = valid
# backend = validateOnly

swift run qsb validate-location reference/winqsb/LOCATION.FL_
# status = valid
# backend = validateOnly

swift run qsb solve-location reference/winqsb/LOCATION.FL_ --backend validate
# status = valid
# backend = validateOnly

swift run qsb validate-layout reference/winqsb/LAYOUT.FL_
# status = valid
# backend = validateOnly
# warnings = 3 fixed-overlap warnings
```

Verified fixture commands:

```bash
swift run qsb solve-timeseries reference/winqsb/SALES.FC_ 2
# month 25 = 560.409420
# month 26 = 568.265507

swift run qsb solve-moving-average reference/winqsb/SALES.FC_ 3 2
# month 25 = 561.666667
# month 26 = 565.555556

swift run qsb solve-exp-smoothing reference/winqsb/SALES.FC_ 0.3 2
# month 25 = 542.070830
# month 26 = 542.070830

swift run qsb solve-seasonal reference/winqsb/SALES.FC_ 12 2
# month 25 = 588.425665
# month 26 = 574.297443

swift run qsb solve-lot-sizing reference/winqsb/LOTSIZE.IT_
# total cost = 907.500000

swift run qsb solve-finite-queue reference/winqsb/QUEUE2.QA_
# effective arrival rate = 1.882245
# total cost = 339.093837

swift run qsb solve-decision-tree reference/winqsb/DTREE.DA_
# expected value = 57213.215998
# policy: Favorable -> Advertise; Unfavorable -> Pricing; Neutral -> Pricing

swift run qsb solve-game reference/winqsb/GAME.DA_ --backend native
# value = 10.265525
# backend = nativeEducational

swift run qsb solve-flowshop reference/winqsb/FLOWSHOP.JO_ --backend native
# makespan = 213
# sequence: Job 4 -> Job 2 -> Job 5 -> Job 1 -> Job 3

swift run qsb solve-jobshop reference/winqsb/JOBSHOP.JO_ --backend native
# makespan = 34
# machine completion times = 27, 33, 30, 34, 32

swift run qsb solve-transport reference/winqsb/TRNSPORT.NE_ --backend native
# total cost = 3350
# backend = nativeEducational

swift run qsb solve-line-balancing reference/winqsb/LINEBAL.FL_ --backend native
# stations = 5
# efficiency = 0.953333
# backend = nativeEducational

swift run qsb solve-location reference/winqsb/LOCATION.FL_ --backend native
# NF1 at (5.538462, 7.653846)
# objective value = 2008.692308
# backend = nativeEducational

swift run qsb export-facilities-json reference/winqsb/LOCATION.FL_
# emits FacilitiesModelEnvelope JSON
# kind = location

swift run qsb validate-facilities-json <exported facilities JSON>
# emits FacilitiesValidationDocument JSON
# kind = location
# backend = validateOnly
# isValid = true

swift run qsb solve-facilities-json <exported facilities JSON> --backend validate
# status = valid
# backend = validateOnly

swift run qsb solve-facilities-json <exported facilities JSON> --backend native
# emits FacilitiesSolutionEnvelope JSON
# kind = location
# backend algorithm = weightedCentroid
# backend exactness = closedForm
# objectiveValue = 2008.6923076923076

swift run qsb export-location-json reference/winqsb/LOCATION.FL_
# emits normalized FacilityLocationProblem JSON

swift run qsb solve-location-json <exported location JSON> --backend validate
# status = valid
# backend = validateOnly

swift run qsb solve-location-json <exported location JSON> --backend native
# emits FacilityLocationSolution JSON
# objectiveValue = 2008.6923076923076

swift run qsb export-line-balancing-json reference/winqsb/LINEBAL.FL_
# emits normalized LineBalancingProblem JSON

swift run qsb solve-line-balancing-json <exported line-balancing JSON> --backend validate
# status = valid
# backend = validateOnly

swift run qsb solve-line-balancing-json <exported line-balancing JSON> --backend native
# emits LineBalancingSolution JSON
# stationCount = 5
# efficiency = 0.9533333333333334

swift run qsb export-facilities-json reference/winqsb/LINEBAL.FL_
# emits FacilitiesModelEnvelope JSON
# kind = lineBalancing

swift run qsb solve-facilities-json <exported facilities JSON> --backend native
# emits FacilitiesSolutionEnvelope JSON
# kind = lineBalancing
# backend algorithm = bitmaskDynamicProgramming
# backend exactness = fixtureScale
# stationCount = 5

swift run qsb solve-layout reference/winqsb/LAYOUT.FL_ --backend native
# objective value = 53552
# source = initialLayoutEvaluation

swift run qsb export-layout-json reference/winqsb/LAYOUT.FL_
# emits normalized FacilityLayoutProblem JSON

swift run qsb solve-layout-json <exported layout JSON> --backend validate
# status = valid
# backend = validateOnly

swift run qsb solve-layout-json <exported layout JSON> --backend native
# emits FacilityLayoutSolution JSON
# objectiveValue = 53552
# source = initialLayoutEvaluation

swift run qsb solve-layout reference/winqsb/LAYOUT.FL_ --backend native --layout-strategy pairwise-swap
# objective value = 48948
# initial objective value = 53552
# applied pairwise same-size swaps = 6

swift run qsb solve-layout-json <exported layout JSON> --backend native --layout-strategy pairwise-swap
# emits FacilityLayoutSolution JSON with search and moves
# objectiveValue = 48948
# source = pairwiseSwapLocalSearch

swift run qsb export-facilities-json reference/winqsb/LAYOUT.FL_
# emits FacilitiesModelEnvelope JSON
# kind = layout

swift run qsb solve-facilities-json <exported facilities JSON> --backend native --layout-strategy pairwise-swap
# emits FacilitiesSolutionEnvelope JSON
# kind = layout
# backend algorithm = pairwiseSameSizeSwapLocalSearch
# backend exactness = heuristic
# objectiveValue = 48948
# source = pairwiseSwapLocalSearch
```

## Immediate Contributor Task List

Recommended next tasks for contributors, in order:

1. Read this roadmap and the relevant project documentation before modifying code.
2. Run `swift test` to establish baseline.
3. Inspect current solver organization in `QSBCore`.
4. Keep extending backend metadata beyond LP/ILP and scheduling where it clarifies solver behavior.
5. Add validation-only paths to additional families.
6. Add tests for backend selection in more command families.
7. Use `qsb inventory-fixtures reference/winqsb` to choose the next partially supported family or fixture.
8. Continue facilities/workflow fixture discovery beyond the current layout baseline.
9. For each new facilities/layout fixture, implement classification, parsing, validation, JSON export, and only then solving.
10. Keep the macOS GUI compiling, but do not let GUI refactors block core/CLI progress.
11. Update the relevant project documentation and this roadmap after each meaningful milestone.

## Suggested Commit Boundaries

Prefer small commits:

1. Backend type definitions and docs.
2. LP/ILP backend refactor with no behavior change.
3. CLI backend flag support.
4. Validation-only command support.
5. Facilities fixture classification.
6. Facilities/layout parser.
7. Facilities/layout JSON and validation.
8. Facilities/layout solver or unsupported diagnostic.
9. GUI wiring if needed.
10. Documentation and roadmap update.

## Definition of Done for a New Family or Variant

A family or variant is not complete until it has:

- fixture discovery or a documented reason why no fixture exists;
- parser implementation;
- validation diagnostics;
- normalized JSON model output;
- solution JSON output or explicit unsupported/validate-only status;
- deterministic CLI behavior;
- tests under `swift test`;
- documentation entry;
- roadmap update;
- clear solver characterization: exact, heuristic, approximate, closed-form, fixture-scale, educational, or external-backed.

## Key Warning for Future Work

Avoid the trap of expanding solver implementations faster than compatibility, validation, and schema quality.

The safest order is:

1. preserve fixture;
2. classify fixture;
3. parse fixture;
4. validate model;
5. export normalized JSON;
6. add native educational solver only when scope is clear;
7. add external backend only behind a protocol;
8. add GUI visualization after CLI behavior is stable.

This order keeps the project from becoming an unmaintainable collection of partial algorithms.
