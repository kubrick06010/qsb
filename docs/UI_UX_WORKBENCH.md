# QSB Native Workbench: UI/UX Audit and Design Proposal

Status: design reference. UI Phases 1–3E and the M/M/1 and finite-capacity
queue and payoff/Bayesian/zero-sum game editors are implemented incrementally.
Every currently decodable normalized family now has either a specialized
native editor or a guided structured definition surface. Atomic table transfer
with Excel, Numbers, LibreOffice, TSV, and CSV covers the guided fallback and
the specialized LP, Assignment, Transportation, Forecasting, Lot Sizing,
Markov, Payoff, Bayesian, and Zero-Sum editors. Remaining specialization and
live VoiceOver/focus refinement are roadmap items.

This document records the post-Phase-C product audit of `QSBMacApp`. The audit
sections below describe that historical checkpoint; later phase updates near
the end record implemented changes. It
complements `docs/GUI_UX_GUIDELINES.md`: that document defines visual and
interaction quality rules; this document defines the product model, journeys,
navigation, information architecture, and implementation sequence.

## Product thesis

QSB should feel like a native operations-research workbench that happens to
have an unusually strong WinQSB import path. Legacy files are one source of
models, alongside normalized JSON, samples, and future native editors. The
user should primarily think in terms of a model, a run, and a solution—not in
terms of parsers, envelopes, or fixture formats.

The current QSBCore architecture supports this direction well:

- typed family models remain the source of truth;
- validation and solving already produce structured data;
- backend protocols preserve the native/external seam;
- normalized JSON is a stable interchange and fallback boundary;
- family-specific views can remain specialized inside a common shell.

At the original audit checkpoint, the main product gap was that the macOS app
looked and behaved primarily like a JSON editor with a collection of solution
mini-apps. The guided definition surface and New Model family picker close that
baseline gap while family-specific editors continue to replace generic groups
where domain concepts need a stronger interaction.

## Original checkpoint audit

### Launch and empty state

`QSBMacApp` opens a single `WindowGroup` with a default LP sample loaded into
the workspace. The app therefore launches in an editing state rather than an
empty or welcome state. This is useful for a demo, but it hides the important
first choices: open a file, choose a family, or start from a template.

The window has a minimum size of approximately 980×620. There is no explicit
window restoration model, recent documents surface, or first-run orientation.

### Navigation and shell

The shell is a `NavigationSplitView` with only two sidebar destinations:

- Model
- Solution

The sidebar does not expose inputs, validation, run history, diagnostics, or
metadata as separate destinations. The detail pane changes substantially by
family, while the navigation model remains generic. This makes the result
state discoverable only after solving and makes a failed validation feel like
a change to the model pane rather than a first-class result.

The toolbar combines samples, file open/export, backend selection, layout
strategy, validation, LP-specific solve actions, and a generic Solve action.
It is functional but dense. LP/ILP buttons remain visible even when disabled
for another family, and sample loading is mixed with document actions.

The menu bar contains Model and Solve menus. It provides useful keyboard
shortcuts for open, export, LP, ILP, and a few samples, but coverage is not
parallel with the toolbar and there is no general Validate command in the
menu.

### Open and import

The file importer advertises JSON/data content types. `QSBWorkspace.importModel`
first tries normalized JSON detection, then falls back to
`LegacyModelImporter`. Successful legacy imports are normalized before being
shown. Unsupported or malformed files remain in the Model pane with a status
string such as `Import failed: ...`.

This is a strong architectural flow, but the user receives little identity
context beyond a subtitle such as “Normalized inventory JSON · EOQ”. The
restored legacy filename, source format, and import provenance are not
presented as persistent model metadata.

### Model editing and inspection

At the original checkpoint, the normal Model pane was a monospaced editable `TextEditor` containing raw
JSON. This is a good advanced/debugging surface and a weak default editor:

- field-level errors cannot be placed beside an input;
- model identity and assumptions are hidden in JSON;
- changes are not visibly classified as editing versus validated;
- there is no dirty state or save/revert model;
- the LP/ILP and Inventory families now have native typed editors; other
  families still used JSON as their practical editing surface.

Current behavior routes every decodable normalized family to Definition. A
specialized typed editor is used where available; all other families use a
guided structured editor that preserves JSON scalar, list, object, optional,
and matrix types. Repeated compatible data exposes `Paste Table` and `Copy
Table`, with complete-range validation before commit. JSON is a separate
Advanced surface for audit, exchange, and repair.

The first production editor is the LP/ILP editor. It keeps an internal
`LinearProgrammingDraft` only while the user is editing incomplete values, then
converts through one boundary into `LinearProgram`. QSBCore owns semantic
validation and solving. The old LP Entry Mock is no longer part of the product
flow; its concerns were replaced by the native editor without exposing the
simplex unrestricted-variable transformation.

Inventory follows the same boundary with a discriminated `InventoryDraft`:
EOQ, quantity-discount EOQ, newsvendor, lot sizing, and stochastic review have
native editors. Stochastic review uses policy-aware sections because its
parameters are materially different. Discount tiers and
lot-sizing periods are edited as dimensionally safe rows, while QSBCore owns
semantic validation and all derived calculations.

The Network editor applies the same boundary to graph-native variants:
shortest path, minimum spanning tree, maximum flow, and traveling salesperson
use an internal `NetworkDraft` with stable node/arc IDs and UI-only layout
positions. Assignment and transportation now use distinct typed matrix drafts:
Assignment preserves rectangular worker/task cost matrices, while
Transportation preserves source/destination costs plus supply and demand
vectors. Their table editors use the same explicit draft → QSBCore → JSON →
backend boundary, with dimension-safe row and column mutations. Minimum-cost
flow remains an import/JSON surface until a dedicated graph-plus-balances
editor can represent its node balances and automatic solver adjustment without
overloading either editor.

### Validation

Validation is family-aware in the workspace and uses existing QSBCore
validators. Results are encoded into `solutionJSON`, selected into the
Solution pane, and represented by a status string and a JSON document.

This preserves structured diagnostics but makes validation look like a special
kind of solution. The GUI does not currently provide an inline diagnostic list,
click-to-field focus, severity filtering, or a persistent “valid/invalid” state
near the model identity.

### Solve and backend selection

The workspace has family-specific solve methods and a family switch for the
generic Solve action. Native and validate-only backends are selectable in a
segmented toolbar picker. External is not exposed because no external backend
is available; the core path reports an unavailable backend.

This is correct behaviorally but exposes implementation vocabulary too early.
The user sees `Native`/`Validate` rather than a primary “Run model” action with
an optional run configuration. There is also no visible run phase for
validating or solving: state transitions are mostly status strings and pane
selection.

### Results and JSON fallback

`SolutionView` chooses a family-specific visualization when it can decode one
of the known solution documents. Otherwise it shows a monospaced JSON editor.
Several visual views provide a segmented visual/JSON switch. This is a good
fallback strategy and preserves inspectability.

The limitation is hierarchy: summary, visualization, details, assumptions,
diagnostics, backend metadata, and raw JSON are implemented differently by
family. Some views put metadata near the title, some in a lower section, and
some rely on JSON for information not represented visually.

### Error and failure presentation

Malformed JSON, validation failures, unsupported variants, solver errors, and
unavailable backends are generally collapsed into `status` text. The model
pane is reselected after most solve errors. This is simple and robust, but it
does not distinguish:

- input cannot be parsed;
- model parsed but is invalid;
- model is valid but infeasible/unbounded;
- solver does not support this variant;
- requested backend is unavailable;
- run failed after starting.

Those distinctions exist in QSBCore and should become visible in the UI.

## Actual user journeys

### Open an existing legacy model

Current flow:

```text
Launch with LP sample
  -> Open toolbar/menu
  -> choose JSON/data file
  -> try normalized JSON
  -> fallback to LegacyModelImporter
  -> normalize into family JSON
  -> show Model JSON editor
  -> user selects Validate or Solve
  -> show validation JSON or family solution view
  -> optional solution JSON export
```

The flow works, but the import provenance is ephemeral and “open” does not
lead to an explicit model overview.

### Open a normalized model

Current flow:

```text
Open
  -> normalized family detection by typed decoder attempts
  -> show editable JSON
  -> family-specific action enablement
  -> Validate
  -> Solution pane containing validation document
  -> Solve
  -> visual result where implemented, otherwise JSON
```

The family detector is shared in spirit with the CLI but duplicated in the
workspace. No ambiguous normalized schemas are currently known. Sequential
typed detection is acceptable technical debt for now; a future shared
descriptor can remove duplication if a real maintenance or performance issue
appears.

### Create a new model

The original checkpoint had no mature universal creation workflow. The current
New Model sheet groups templates by family and creates either a specialized
typed draft or a guided editable starter. It no longer requires users to find a
sample and then edit normalized JSON.

The required future flow is:

```text
New Model
  -> choose family and variant
  -> create family-native draft state
  -> edit fields/tables
  -> validate through QSBCore
  -> resolve inline and model-level diagnostics
  -> solve through selected run configuration
  -> inspect result
  -> save native normalized JSON / export / preserve draft
```

### Error flow

| Condition | Current behavior | Product requirement |
| --- | --- | --- |
| Malformed input | Status string, Model selected | Explain parse location and offer JSON/source recovery |
| Unsupported legacy artifact | Import status error | Say reference-only/unsupported and preserve source context |
| Invalid normalized model | Validation output in Solution pane | Inline field issues plus diagnostics summary |
| Validation failure | Structured JSON and status | Block Solve and show actionable diagnostics |
| Infeasible/unbounded | Solver error in status | Result state “Failed” with solver diagnostic and model link |
| Solver limitation | Error/status | Explain exactness/scale/unsupported variant |
| Backend unavailable | Status string | Run configuration error with available alternatives |

## Prioritized product issues

### P0 at the original checkpoint — blocks or seriously confuses the core workflow

1. **Model and solution are not distinct enough.** Validation output is stored
   in `solutionJSON`, and the two-pane navigation does not represent model
   definition, run state, diagnostics, and result as separate concepts.
2. **The default editing surface is raw JSON.** Users cannot reliably create or
   repair a model without understanding the normalized schema.
3. **Failure semantics are collapsed into status text.** Parse errors,
   validation errors, infeasibility, unsupported variants, and backend
   availability require different user responses but look similar.
4. **There is no first-class New Model path.** QSB can solve many families but
   cannot coherently guide a user from a family choice to a valid new model.

### P1 — materially harms usability or coherence

1. The toolbar mixes document actions, samples, LP-only actions, backend
   selection, and layout options without a clear hierarchy.
2. Family solution views have inconsistent summary, metadata, diagnostics, and
   JSON fallback placement.
3. Model identity, source/provenance, assumptions, and run context are often
   hidden in JSON or small subtitle/status strings.
4. There is no run history or durable result navigation; a new solve replaces
   the previous solution.
5. Wide fixed tables and horizontal scrolling are common. Several visual views
   are responsive at the demo scale but not clearly designed for long names or
   large instances.
6. Keyboard commands are incomplete and not organized around a consistent
   open/validate/solve/export grammar.
7. Accessibility coverage is strongest in newer visualizations and weaker in
   shell controls, raw JSON editing, tables, and focus transitions.

### P2 — refinement and discoverability

1. Add recent files, templates, search, and family descriptions.
2. Improve status language, timing, option summaries, and exactness labels.
3. Add reduced-motion and text-scaling review to visualization QA.
4. Provide compact inspector summaries for model size, family, backend, and
   diagnostics.

## Proposed product model

The preferred mental model fits the architecture with one adjustment: a Run
must be a first-class object between Model and Solution.

```text
Workspace
├── Model
│   ├── Identity and family
│   ├── Definition / native editor
│   ├── Parameters and assumptions
│   ├── Source and provenance
│   └── Validation state
├── Run
│   ├── Backend and options
│   ├── Validation phase
│   ├── Solve phase
│   ├── Diagnostics
│   └── Run metadata
└── Solution
    ├── Summary
    ├── Domain visualization
    ├── Tables and details
    ├── Assumptions and diagnostics
    ├── Backend / exactness context
    └── Raw JSON
```

QSBCore already supplies the typed Model, ValidationReport, solution
documents, SolverOptions, SolverRunMetadata, and JSON boundaries. The UI needs
an orchestration state model around those types; it does not need a new
mathematical model layer.

## Proposed workbench layout

Use a `NavigationSplitView` as the native macOS shell, with an optional
inspector rather than a permanently fixed three-column layout.

```text
┌──────────────────────────────────────────────────────────────────────┐
│ QSB  [Open] [New]                    Validate   Run ▾   Export ▾      │
├───────────────┬──────────────────────────────────────┬───────────────┤
│ Navigator     │ Workspace                            │ Inspector     │
│               │                                      │               │
│ Model         │ Model identity / editor / summary    │ Properties     │
│  Definition   │                                      │ Diagnostics    │
│  Validation   │ Model or Solution presentation       │ Run config     │
│               │                                      │ Metadata       │
│ Runs          │                                      │               │
│  Current      │                                      │               │
│  Previous     │                                      │               │
│               │                                      │               │
│ Solution      │                                      │               │
│  Summary      │                                      │               │
│  Details      │                                      │               │
│  JSON         │                                      │               │
├───────────────┴──────────────────────────────────────┴───────────────┤
│ ● Valid · QSB Native · last run 0.42 s · 2 variables · 3 constraints │
└──────────────────────────────────────────────────────────────────────┘
```

The inspector should be collapsible. On narrower windows, the navigator and
inspector become navigation destinations/sheets rather than forcing three
columns. The center workspace remains the primary reading and editing area.

### Navigation model

The navigator should be contextual and shallow:

```text
Current Model
  Overview
  Definition
  Validation

Runs
  Current Run
  Previous Runs

Current Solution
  Summary
  Visualization
  Details
  Diagnostics
  JSON
```

Empty and model-only states should omit unavailable sections instead of
showing disabled technical destinations. Family-specific views fill the
Visualization destination without changing the surrounding grammar.

## Shared interaction grammar

### Model state

```text
Empty -> Editing -> Validating -> Valid
                  └────────────> Invalid
```

Editing means a draft has changed since the last successful validation.
Invalid means structured diagnostics contain errors. Warnings do not block a
run but remain visible. The toolbar should show the state with text and icon,
not color alone.

### Run state

```text
Not run -> Validating -> Solving -> Solved
             │             │          │
             └─ Invalid    └─ Failed  └─ Exportable
```

Validate is always available for a recognized model. Solve is disabled for an
invalid model and unavailable for a validate-only backend, with the reason
shown in the inspector. A future Stop action can occupy the same run control
without changing the grammar.

### Primary actions

Use one consistent order:

```text
Open   New   Validate   Run ▾   Save   Export ▾
```

Family-specific options belong in the Run configuration inspector/sheet, not
beside the primary actions. Existing stable shortcuts can retain their
specialized behavior in CLI and menus.

## Family-specific solution audit

| Family/view | Current strengths | Current gaps | Shared pattern to retain |
| --- | --- | --- | --- |
| Scheduling | Responsive Gantt, timeline/JSON switch, machine/job detail | Large schedules require horizontal scrolling; metadata is not a common header | Summary → timeline → operations table → run details |
| Network | Diagram for flow, routes, trees, tours, assignment, transportation; detail rows | Canvas graph and detail hierarchy vary by variant; compact graph reading is difficult | Summary → diagram → connections/details → JSON |
| Forecasting | Charts, residuals, scale control, accessible points, JSON | Method-specific labels and summary layout; long series need navigation | Summary → chart → residuals/table → assumptions |
| Facilities | Layout canvas, zoom, strategy, placements/interactions, JSON | Primarily layout-focused; line balancing/location need equivalent result hierarchy | Summary → domain visual → placements/metrics → run context |
| Inventory | Charts/tables for EOQ, discounts, newsboy, lot sizing, stochastic policies | Many variant-specific sections; common assumptions/run details should be promoted | Summary → policy/cost analysis → tables → assumptions |
| Dynamic Programming | Stages, charts, policy tables, assumptions, JSON | Three variants use different visual structures; common navigation is implicit | Summary → stages/policy → trace/table → assumptions |
| Decision Tree | Rollback tree table, policy cards, metadata, JSON fallback, accessibility labels | Tree is mostly tabular; no shared diagnostics/run section with other views | Summary → tree/policy → node details → run context |
| Queuing | Native definition editors and utilization, flow, congestion, state-probability and cost views for both supported variants; metrics/JSON switch | Large finite state spaces need future filtering; live VoiceOver/focus refinement continues | Summary → capacity/flow → performance/states/costs → assumptions |

Reusable patterns are the surrounding sections, not one universal chart:

- `SolutionHeader` with title, family/variant, result status, and primary metric;
- `SummaryMetrics` for 2–5 key values;
- `PresentationPicker` for Visual/Details/JSON where appropriate;
- `RunDetails` for backend, algorithm, exactness, assumptions, and notes;
- `DiagnosticsList` for warnings/errors;
- `StructuredDetailsTable` with accessible row labels;
- `ScaleControl` only for visualizations that genuinely need it.

## Model editing strategy

LP should be the reference native editor, but its draft must map directly to
the existing `LinearProgram` initializer. The UI state should be a form state
that can produce a typed QSBCore model; it must not become a competing
mathematical representation.

### LP editor proposal

```text
┌──────────────────────────────────────────────────────────────┐
│ Linear Programming                         Draft · Invalid  │
├──────────────────────────────────────────────────────────────┤
│ Model name  [ Production mix                         ]       │
│ Objective   (•) Maximize  ( ) Minimize                      │
├──────────────────────────────────────────────────────────────┤
│ Variables  [+ Add]                                           │
│ Name       Type       Lower bound       Upper bound           │
│ x1         Continuous 0                  ∞                    │
│ x2         Integer    0                  20                   │
│ x3         Binary     0                  1                    │
│ x4         Unrestricted                                  ⚠  │
├──────────────────────────────────────────────────────────────┤
│ Objective coefficients                                       │
│          x1       x2       x3       x4                      │
│          [40]     [30]     [12]     [-5]                    │
├──────────────────────────────────────────────────────────────┤
│ Constraints [+ Add]                                          │
│ C1       [2]      [1]      [0]      [100]   ≤                │
│ C2       [0]      [3]      [4]       [80]   ≥                │
│                                                ⓘ C2 is valid │
├──────────────────────────────────────────────────────────────┤
│ Errors: 1   [Show diagnostics]                 [Validate] [Run]│
└──────────────────────────────────────────────────────────────┘
```

Required behavior:

- continuous, integer, binary, and unrestricted variables are explicit;
- bounds and relation controls are typed, not free-form symbols;
- each field can show a local diagnostic path;
- row/column insertion and deletion preserve dimensions safely;
- validation calls `LinearProgramValidator` through QSBCore;
- raw JSON is a secondary Model/JSON tab, never the only editor;
- Save/export serializes the existing normalized LP/ILP schema.

Other families should use family-native editors built from the same principles:
table editors for networks and schedules, period tables for inventory and
planning, state/transition tables for Markov and dynamic programming, and
payoff/tree editors for decision analysis. The guided structured surface is a
safe baseline for complete model coverage; it does not replace specialized
editors when domain language, dimensions, or gestures materially improve the
task.

## New Model workflow and taxonomy

`File → New Model…` should open a searchable family picker with short
descriptions and optional “Blank” / “Example” choices. Recent families may be
shown above the full list.

```text
New Model
  Search [                         ]
  Recent: Linear Programming · Inventory · Decision Tree

  Optimization
    Linear / Integer Programming
    Goal Programming
    Quadratic Programming
    Nonlinear Programming
  Networks
    Shortest Path · Max Flow · Transportation · Assignment · TSP
  Planning
    Inventory · MRP · Aggregate Planning · Scheduling · Facilities
  Analysis
    Forecasting · Decision Analysis · Markov · Queuing · Simulation
    Quality Control · Acceptance Sampling
```

The taxonomy is a discovery aid, not a new QSBCore family hierarchy. Existing
variants remain authoritative. The picker should show the actual supported
variant after a family is selected and avoid promising an editor that does not
yet exist.

## Validation and diagnostics UX

Preserve `ValidationDiagnostic` exactly and render it in two coordinated
places:

1. Inline, beside the affected editor field when `path` identifies a field.
2. An inspector diagnostics list for all errors, warnings, and model-level
   messages without a field path.

Each row should include severity icon plus text, code in an advanced detail,
and a “Focus” action when a field path can be resolved. Errors block Solve;
warnings do not. A toolbar badge and status bar should summarize counts, for
example `Invalid · 2 errors · 1 warning`.

Diagnostic presentation must not recreate validation rules in SwiftUI. The UI
maps paths and severities to controls; QSBCore remains the owner of meaning.

## Solver and backend UX

Backend selection belongs in a Run configuration inspector or sheet, not in a
permanently prominent segmented control. The primary toolbar action should be
`Run` with the selected configuration visible in its subtitle or inspector.

Recommended terminology:

| Core backend | Default UI label | Advanced detail |
| --- | --- | --- |
| `nativeEducational` | QSB Native | algorithm, exactness, assumptions, scale |
| `validateOnly` | Validate only | no solution will be produced |
| `externalHighPerformance` | External solver | HiGHS for LP/MIP, CNF/TP, aggregate planning, and goal programming when `QSB_HIGHS_PATH` or `PATH` provides it |

The inspector should show supported capabilities before running. An
unavailable external backend should be selectable only as an explicit advanced
choice and should fail with a clear explanation and an alternative action.

## Result explanation UX

Every solution view should use the same section order where applicable:

```text
Summary
Visualization
Details / tables
Diagnostics and assumptions
Run details
JSON
```

`Run details` should expose `SolverRunMetadata` in friendly language:

- backend label;
- algorithm;
- exact / closed-form / heuristic / approximate / fixture-scale;
- assumptions;
- warnings and unsupported features;
- timing and options when the core supplies them.

No generated or AI-written explanation is needed. Existing traces, policies,
rollback values, operations, and tables are the authoritative educational
explanation.

## JSON strategy

JSON remains a first-class interoperability and debugging surface, but it
should be an advanced presentation for ordinary users.

- Model: `Definition` and `JSON` tabs. Definition always presents either a
  specialized native editor or the guided structured fallback.
- Solution: `Summary`, family visualization/details, and `JSON` tab.
- JSON editing is allowed, but edits transition the model to Editing and
  require validation before Solve.
- Invalid JSON remains visible with parse diagnostics and never silently
  replaces the last valid model.
- Export always preserves the existing normalized family schema.

## Accessibility audit

Strengths already present include accessible labels/values on many chart points,
network nodes, layout departments, scheduling operations, and decision-tree
rows. JSON and structured tables provide non-visual alternatives for most
visualizations.

Priority gaps:

- shell toolbar controls need consistent accessibility labels, roles, and
  values for backend, validation state, and run state;
- raw JSON `TextEditor` needs a clear label and a visible alternative summary;
- focus should move to the first diagnostic after validation failure;
- fixed-width grids need VoiceOver row/column context;
- color and chart marks must not be the only distinction;
- segmented visual/JSON controls need stable labels across families;
- keyboard navigation should cover sidebar, inspector, Validate, Run, and
  result sections;
- Validate uses `Command-Shift-V`; `Command-V` remains the native Paste action
  for editable fields and tables;
- review Dynamic Programming, Inventory, and Network canvas alternatives at
  compact sizes;
- add reduced-motion behavior for future animated runs and transitions.

## Responsive behavior

At 1000×700, the current minimum window is viable for the JSON editor and
simple views but is crowded by the toolbar, split navigation, fixed tables,
and inspectors. At 1380×860, the current family visualizations are generally
comfortable and several already adapt between a side detail column and a
stacked layout.

Recommended minimum practical workbench size: approximately 1100×720 for the
full shell, while allowing a narrower single-column editor/result route when
the inspector is closed. The design must support:

- navigator or inspector collapsed independently;
- tables with column prioritization and horizontal scroll only where needed;
- long names wrapped or elided with full-value accessibility text;
- large result tables with native scrolling and search/filter;
- no fixed canvas assumption that all demo fixtures fit.

## Proposed implementation phases

### UI Phase 1 — Workbench shell

- introduce explicit empty, editing, validating, invalid, solving, solved, and
  failed state presentation;
- separate Model, Runs, and Solution navigation context;
- consolidate toolbar/menu actions around Open, New, Validate, Run, Save, and
  Export;
- add optional inspector for identity, diagnostics, run configuration, and
  run details;
- preserve existing family visual views behind the common shell.

### UI Phase 2 — LP editor

- Status: implemented for the initial LP/ILP scope.
- use a typed draft backed by existing QSBCore model initializers;
- support unrestricted, integer, binary, bounds, relations, and inline
  diagnostics;
- validate through QSBCore and provide explicit JSON application;
- run through the existing LP/ILP backends and export unchanged normalized
  JSON.
- copy and paste complete variables/objective and constraint tables through
  Excel, Numbers, LibreOffice, TSV, or CSV, with optional headers and atomic
  failure behavior.
- Remaining refinement includes richer undo/redo, field focus routing, and
  wider editor ergonomics for very large matrices.

### UI Phase 3 — Family editor expansion

Status: Inventory and Network matrix/bipartite editing are implemented. Native
Network editing covers graph variants (shortest path, MST, maximum flow, TSP),
Assignment’s rectangular matrix, and Transportation’s matrix with balances.
Stochastic inventory review and Network CNF now have dedicated native editors.
Stochastic Inventory uses policy-aware form sections and preserves the actual
QSBCore fields through `InventoryStochasticDraft`. CNF uses a separate
balance-aware node/arc table rather than overloading the graph or transportation
drafts; invented capacities remain absent from the model.

Forecasting now has a native editor for all five current QSBCore methods. Its
ordered historical table, regression predictor table, and method-specific
controls convert through `ForecastingDraft` into the existing typed request.
Semantic validation, normalized JSON, and backend routing remain in QSBCore.
The result surface prioritizes actual/fitted/forecast chart series, a forecast
boundary marker, existing fit metrics, residuals, and an accessible structured
value table.

Payoff, Bayesian, and zero-sum game models now have native table editors. They
keep states, evidence likelihoods, strategies, and payoffs aligned when
dimensions change and send typed models through QSBCore validation and
backends. Decision trees have a native node editor with ordered child IDs,
payoffs, and branch probabilities, also using the typed QSBCore model.

Families without a specialized editor now use the guided structured definition
surface instead of raw JSON. It provides typed fields, expandable object rows,
dimension-safe lists and matrices, starter rows for known empty collections,
QSBCore validation, and atomic copy/paste for compatible spreadsheet tables.
The New Model picker exposes guided starters across Optimization, Planning &
Scheduling, Quality, and Simulation.

The specialized spreadsheet checkpoint now covers the remaining dense tables:

- Lot Sizing transfers one row per period with every cost field and integral
  demand;
- Markov transfers one aligned table containing state names, costs, optional
  initial probabilities, and all transition cells;
- Payoff and Bayesian editors transfer states/priors and conditional
  likelihoods, with a separate decision-payoff table where applicable;
- Zero-Sum transfers both strategy axes and the payoff matrix.

Matching headers are exported for round trips. Pasted names, dimensions, and
numeric cells are checked before a typed draft is replaced; semantic model
validation continues through QSBCore.

Aggregate Planning, Project Scheduling, MRP, Simulation, and Bounded Knapsack now also have native definition
editors. Aggregate Planning groups its dense period schema into demand,
production, inventory/sourcing, and workforce views while copying all fields as
one atomic spreadsheet table. Project Scheduling provides CPM and PERT activity
tables with named predecessors and method-specific time/cost fields. MRP splits
item master data, time-phased schedules, and BOM relationships into selectable
sections, with one-item detail editing and a long-form spreadsheet schedule for
large plans. Simulation separates component properties, routes, and
entity-specific service distributions. Bounded Knapsack provides a compact
capacity and item table with atomic spreadsheet transfer. These editors restore focus for new rows,
use macOS undo/redo, retain explicit JSON Apply paths, and have compact/wide
rendering regression coverage.

Goal Programming now has a native Definition editor for variable domains and
bounds, ordered priorities, and linear constraints. Goals move up or down with
identity preserved; spreadsheet pastes retain coefficients when variables are
reordered and reject mismatched coefficient headers. Undo/redo, row focus,
normalized-file import, explicit JSON Apply/export, and compact/wide render
checks are implemented. Runtime VoiceOver and keyboard traversal audits remain
pending.

Goal Programming results now use a native adaptive priority view over the
existing typed solution document. Ordered outcomes, final variables, domains,
bounds, exactness, and backend notes remain available alongside the JSON
fallback, with combined accessibility values for priority and variable cards.

Aggregate Planning results now use a native adaptive plan view over the typed
solution document. It combines stacked production and demand, signed ending
inventory/backorder balances, a horizontally scrollable period table, run
context, accessible chart values, and the normalized JSON fallback.

MRP results now provide an item-selectable native schedule view over the typed
solution document. Requirements, projected inventory, planned receipts and
releases, capacity excess, item parameters, and BOM relationships are available
through accessible charts and time-phased tables alongside normalized JSON.

Acceptance Sampling results now present the typed operating-characteristic
curve, AQL/RQL risks, operating measures, and plan context. Quality Control
results cover all five current variants with control limits and signals,
Pareto frequency/cumulative views, and normal-probability fit details. Both
surfaces keep accessible values and normalized JSON available.

Their Definition surfaces are now native as well. Acceptance Sampling exposes
single and double plan decisions with shared risk and economics fields.
Quality Control switches among five typed, dimension-safe tables and offers
atomic Copy/Paste Table for its observation, subgroup, and category data.

Quadratic Programming now also has a native Definition editor with separate
variable/bound, quadratic-matrix, and linear-constraint sections. Table pastes
are atomic, and variable reordering preserves both matrix axes and constraints.
Normalized file imports use this editor; edits support undo/redo and new-row
focus. Full runtime VoiceOver and keyboard traversal audits remain pending.

Nonlinear Programming now has a native Definition editor for the objective,
variable bounds, and expression constraints. Invalid expressions remain visible
for correction; core diagnostics own expression semantics. Variable and
constraint tables support atomic spreadsheet transfer, edits support undo/redo,
and normalized imports and explicit JSON Apply use the native draft. The
interface explains the approximate native solver and exposes contextual
accessibility labels. Compact/wide render checks cover constraints and invalid
expressions; runtime accessibility and keyboard audits remain pending.

Quadratic and Nonlinear Programming results now use native optimum views with
variable charts and bounds. QP exposes active constraints; NLP exposes the
objective expression, convergence count, maximum violation, and each typed
constraint evaluation. Both retain backend qualification and normalized JSON.

Facility Location now has a native Definition editor for facility coordinates
and the complete directed interaction matrix. Facility IDs scoped by existing/new role preserve both matrix
axes through table reordering and renaming. Atomic spreadsheet transfer,
undo/redo, row focus, normalized import, JSON Apply/export, and compact/wide
render checks are implemented. Runtime accessibility and keyboard audits remain
pending.

Line Balancing now has a native Definition editor for cycle time, time units,
task identity, durations, isolation flags, and successor IDs. Task reordering
retains precedence by ID; deleting a referenced task produces core diagnostics
while preserving successor input for repair or undo. Atomic spreadsheet paste,
undo/redo, row focus, normalized import, JSON Apply/export, and compact/wide
render checks are implemented. The interface documents the isolation flag's
compatibility-only status in the current native solver. Runtime accessibility
and keyboard audits remain pending.

Facility Layout now has a native Definition editor for departments, fixed
flags, grid dimensions, multiple rectangles per department, and directed cost
matrices. Long-form rectangle tables cover all departments by ID. Reordering
preserves geometry and both cost axes. Atomic spreadsheet paste, undo/redo,
row focus, normalized import, JSON Apply/export, and compact/wide valid/invalid
render checks are implemented. All families named in the specialization goal
now have native typed definition editors; runtime accessibility, keyboard,
focus, and large-matrix audits remain pending.

Facility Location and Line Balancing now join Layout with native result views.
The location map shows existing and proposed coordinates plus weighted links;
the line view shows workload, idle capacity, assignments, and precedence.
Accessible values and normalized JSON remain available for both.

PERT/CPM results now have a native critical-path schedule. Earliest activity
bars, latest-finish slack, critical highlighting, timing tables, project
duration, cost, and PERT variance use the typed project solution and retain the
normalized JSON fallback.

Simulation results now provide native queue and server metric charts, tabular
counts, utilization, confidence intervals when present, run settings, and a
component-network summary over the typed solution document. Normalized JSON
remains available beside the accessible metrics view. The Run inspector exposes
an accessible 1-through-100 replication control and forwards the selection to
the shared simulation backend options.

Future priorities with high educational and workflow value:

1. live VoiceOver, focus order, and keyboard traversal refinement for the
   native Decision Tree and Queuing editors. Their compact and wide layouts are
   covered at 1000×700 and 1400×900; M/M/1 validation/run shortcuts and field
   names have also been inspected;
2. remaining family-specific forms where fixtures and validation make the
   editing contract clear.

Network direct manipulation follows the principle that a domain-natural
gesture should complement explicit keyboard and accessibility alternatives.
The graph editor supports double-click node creation, dragging node bodies to
reposition the UI-only layout, Control-click fast connection, a selected-node
visual connection handle, and inline arc-value editing. Explicit Add Node, Add
Arc, Delete, and inspector paths remain available for discoverability and
accessible fallback. Node movement preserves stable identities and solver
semantics; positions are intentionally excluded from normalized JSON.

The dense Network stress fixture remains development/test infrastructure rather
than a production sample. Its verification exposed two non-blocking polish
items for later work: reduce label ambiguity where many arcs cross, and improve
large-graph ergonomics at compact sizes. The existing Workbench Inspector
toolbar toggle is the intended way to close the inspector; Network does not
add a second toggle.

### UI Phase 4 — Refinement

- complete keyboard-first paths and focus restoration;
- VoiceOver and text-scaling audits;
- state restoration and recent models;
- search/filter for large tables and result details;
- compact/wide regression fixtures;
- reduced-motion and larger-instance ergonomics.

## Deliberately deferred at the original audit checkpoint

- no QSBCore, solver, backend, CLI, or JSON redesign;
- no additional external solver integration for non-LP families or direct
  library linkage;
- no conversion of the LP mock into a production editor;
- no universal mathematical editor abstraction;
- no pixel-perfect WinQSB imitation;
- no implementation of the proposed workbench shell in this checkpoint.


## Quality Control data-preservation audit — 2026-10-04

Code review found that selecting another analysis type reset the current table,
losing unfinished edits. The native draft now retains a separate table and
characteristic for each of the five variants in the editing session, while
sharing the title. Variant changes participate in workspace undo/redo. JSON
continues to represent only the active typed analysis.

Malformed p-chart arrays no longer truncate unmatched observations. Jagged
Xbar-R and Pareto tables retain their measurements and show missing cells as
empty input; an empty Xbar-R subgroup no longer constructs an invalid Swift
range. Regression tests cover all five variant transitions, invalid text and
identity retention, direct repair, and workspace undo/redo. Cell focus is keyed
by both row and column; removal and paste choose an editable destination, and
disabled removal controls preserve the table's minimum shape.

The compact and wide rendering check passed after these changes. Runtime
accessibility inspection confirmed the empty workspace and Quality template
selector expose named controls and selected states. The native automation
connection then failed with `Sky Computer Use native pipe closed before
response` when creating the test model, and remained unavailable after a fresh
observation and runtime reset. The separate audit app remained running. This
partial inspection does **not** verify the editor's keyboard traversal or
VoiceOver behavior; those checks remain open for all 13 specialization families.


## Large Facility Layout audit — 2026-10-04

Live validation previously materialized every cell of every rectangle and
multiplied grid dimensions without overflow checking. Validation and both
existing layout solver strategies now use rectangle-union geometry. Small-grid
union and centroid comparisons, legacy fixture objectives, billion-by-billion
geometry, integer boundary inputs, and bounded overlap summaries are covered by
regression tests. Diagnostic overlap summaries intentionally consolidate cells
per department pair and include the shared area.

The native solution canvas also enumerated all row and column grid lines and
allocated an unbounded logical canvas. It now scales large grids into an overview
and samples grid lines, explicitly displaying the interval while keeping exact
ranges in the department table. Tests bound canvas dimensions and line counts
through `Int.max`; compact and wide rendering includes a billion-by-billion
solution. These checks address area-dependent work. Large dense cost matrices,
keyboard traversal, focus restoration, and VoiceOver remain open audit items.

The native automation inventory was available on a retry, but selecting the
running audit app still returned `Sky Computer Use native pipe closed before
response`. No runtime keyboard or VoiceOver result is inferred from rendering
or numeric tests.


Verification for this checkpoint: 337 tests passed (159 macOS app, 169 core,
and 9 portable MPS); `build_and_run.sh --verify` passed and retained the existing
editor process while opening a new one. Verification now requires a new process
so an older running instance cannot hide a launch failure. `git diff --check`
passed, no files were staged, and the SHA256 inventory of all 117 local
`reference/winqsb` files matched the audit baseline.


## Quadratic Programming repair and dense-matrix audit — 2026-10-04

The imported-dimension error flag was permanent, and every section paste tried
to convert the whole draft, so another invalid section prevented repair. QP now
retains extra unnamed coefficients, presents missing numeric cells as empty,
and offers explicit dimension review for displayed type/bound defaults. Name
and coefficient repairs remain required. A complete variable table supplies
reviewed metadata; section pastes check their own structure and values before
committing, with QSBCore still responsible for whole-model semantics.

Large quadratic matrices use a native row picker and groups of at most 12
numeric cells, including the partial final group. Position text and named
headers preserve context; whole-table copy/paste remains available. Small
matrices retain the complete grid. Cells have distinct row/column focus keys;
remove and paste actions select an editable destination. Variable row identities
survive unambiguous reorder, and duplicate invalid names never share an identity.
Tests cover native repair, atomic failed paste, reordering, unique names after
remove/add, and review undo/redo. Compact/wide renders include imported metadata
review, a 40-variable matrix, and its last row/column group.

The native automation app selection again failed with `Sky Computer Use native
pipe closed before response`. Runtime keyboard traversal, VoiceOver, remaining
family matrices, and cross-family focus behavior are not yet verified.


QP checkpoint verification: 341 tests passed (163 macOS app, 169 core, 9
portable MPS); `build_and_run.sh --verify` passed; `git diff --check` was clean.
The 117 reference-file hashes matched the baseline, and nothing was staged.

The next source finding is the analogous permanent imported-dimension flag and
whole-draft paste gate in `GoalProgrammingDraft`. Its native repair path remains
unfinished. Dense facilities matrices and the remaining family keyboard/focus
paths also require audit; the QP improvements do not prove those workflows.


## Goal Programming native repair audit — 2026-10-04

The imported-dimension flag and whole-draft paste gate identified in the QP
checkpoint are now corrected in Goal Programming too. Coefficients beyond named
variables are retained, missing required fields stay empty, and a native review
action accepts displayed types and optional upper-bound defaults. Required lower
bounds and all missing names/coefficients still need repair. Each table validates
its own complete pasted range independently; errors in another section remain
visible and do not prevent repair. Core validation remains authoritative.

Regression tests cover retained priority coefficients, independent table repair,
atomic malformed bounds, stable identities, and review undo/redo. Compact/wide
render checks include the dimension-review surface. Priority movement restores
focus by goal identity, and an empty constraint table selects Add Constraint.

Native inspection now responds for the existing main QSB process and a new
empty audit instance. The failure recurred after dismissing the creation sheet.
A separate harness links the current app/core objects and starts with the Goal
Programming sample to isolate that transition; no runtime result was obtained
because the tool subsequently reported that the Mac was locked and could not be
automatically unlocked. Manual unlock was requested. This evidence does not
establish an editor crash or completed keyboard/VoiceOver testing. Large Goal
Programming/facilities tables and the remaining runtime audit stay open.


The command audit also found two enabled actions claiming Command-N when editing
a network: New Model and Solve Network. The family-specific solve command no
longer claims that shortcut; Command-N remains the creation action and
Command-R remains the shared run action. Runtime confirmation of the command
path is pending manual unlock.


Goal Programming repair checkpoint: 344 tests passed (166 macOS app, 169 core,
9 portable MPS); build/start verification passed; `git diff --check` was clean.
No files were staged and all 117 reference hashes matched the audit baseline.
The goal remains open for dense tables and actual keyboard/VoiceOver verification.

## Facilities dense matrix checkpoint — 2026-10-05

Layout costs and Location interactions now share a native matrix navigator.
Small grids remain visible in full; larger grids select one source and at most
12 destination columns. All cells remain reachable through source and column
selectors, while Copy/Paste Table transfers the full matrix. Source UUIDs survive
spreadsheet reordering and renaming, removal selects a nearby row, and successful
matrix paste requests focus on the first cell. Cell labels include both axis
positions and names.

Location transfer labels now include existing/new role and scoped ID, avoiding
ambiguous rows when names repeat. Unique-name legacy tables remain accepted.
Matrix paste validates its own numeric cells and dimensions without requiring
unfinished geometry or coordinates to be repaired first. Malformed numeric input
is rejected atomically. Core validation still governs complete-model execution.

Specific tests and compact/wide renders cover 35-source tables, first and last
sources, and the final partial destination group. These renders establish static
layout evidence, not runtime keyboard or VoiceOver behavior. Native inspection
was retried and again returned a closed-pipe error before an editor observation.
The interactive audit and other dense family tables remain open.

Verification: 348 tests passed (170 macOS app, 169 core, 9 portable MPS),
build/start verification passed, and `git diff --check` was clean. No files were
staged; all 117 reference file hashes matched the baseline. The goal remains
active because this checkpoint does not complete the full interactive audit.

## Goal Programming dense tables — 2026-10-05

Priority and constraint tables now use the shared matrix navigator when they
exceed 12 rows or variables. Their row metadata and actions remain visible above
the selected coefficients. Priority selection names the current order, and the
selected UUID follows reordering. Parent add/remove/paste actions request row
selection without deliberately stealing name-field focus. The complete small
grid and whole-table spreadsheet transfer remain available.

Compact/wide fixtures exercise first/last rows of 35 priorities and constraints
with 40 variables. A dense-table regression covers complete coefficient
preservation through priority movement, spreadsheet round trips, and undo/redo.
These tests do not establish native focus timing or VoiceOver traversal; those
runtime checks remain required.

Verification: 349 tests passed (171 macOS app, 169 core, 9 portable MPS),
build/start verification passed, and `git diff --check` was clean. No files were
staged; all 117 reference hashes still matched. Static inspection confirmed
selected row metadata and last partial coefficient groups at compact/wide sizes.

Native inspection recovered for the current empty app. Command-N opened the
creation sheet, and the Optimization category and Goal Programming selection
were visible in the accessibility tree. Creating the model again closed the
native inspection pipe; rebinding the app returned the same error. This does not
prove an application crash or successful editor traversal. The goal remains
active for the remaining dense-table and interactive audits.

## Simulation execution state — 2026-10-05

The audit found that synchronous simulation runs blocked the main thread, making
the published Solving state ineffective during long computations. Interactive
Run actions now pass an immutable typed core request to a detached worker and
apply the response on the main actor. A shared UI entry point routes Simulation
through this path; other families retain synchronous execution pending their
migration. The status bar displays progress while solving and exposes the full
status through its accessibility label and tooltip.

Workspace edits, validation, imports, and replacement models invalidate the run
identity. Completion also verifies captured JSON, draft, backend, and replication
options before applying a result. An older run cannot replace a newer result or
surface a stale failure. No solver algorithm moved into views, and invalidating
a response does not claim to cancel already-running computation.

Tests cover pending state, execution away from the main thread, duplicate Run,
replications, stale edited/replaced models, changed options, superseded runs,
stale errors, validation-only, unavailable backends, and worker failure. Static
fixtures include compact/wide solving and failure surfaces. Runtime keyboard,
focus, and VoiceOver evidence remains missing.

macOS diagnostic reports now identify crashes of `SkyComputerUseService` with
`EXC_BREAKPOINT`/`SIGTRAP`, an assertion, and `Array.remove(at:)` in the crashing
stack. This provides evidence of an inspection-service failure alongside the
closed-pipe observations; it does not establish successful QSB interaction or
exclude all independent application issues.

Verification: the full suite passed 354 tests (176 macOS app, 169 core, 9 portable
MPS). After the final status icon and Simulation-specific backend guidance
refinement, all six affected runtime/state and render tests passed again.
Build/start verification passed; `git diff --check` was clean, no files were
staged, and all 117 reference hashes matched the baseline. The goal remains
active for other families' execution, remaining dense forms, and interactive
accessibility/focus audits.

## MRP schedule and repair checkpoint — 2026-10-11

The source audit found whole-model conversion gates in all three spreadsheet
sections. These prevented a valid table from repairing a draft with an unfinished
title or a bad field elsewhere. Each section now checks its own schema and
numeric values atomically; core semantics remain authoritative. Unique item
identifiers and matching BOM relationships keep their row UUIDs. Duplicate item
identifiers and ambiguous schedule labels fail before mutation. A typed pair key
replaces separator-concatenated schedule keys and avoids name collisions.

Schedule editing now displays at most 12 time buckets per group for the selected
item. Adding a bucket reveals its group and creates an unused name; removal
requests nearby row focus. BOM emptiness is explicit, and paste/removal selects
a name field or Add Component when no relationship remains. Section changes
clear obsolete paste errors. Copy/Paste still exchanges the entire plan.

Regression tests cover independent repair with invalid fields retained, atomic
ambiguous-label rejection, separator-bearing names, and copying/removing/repairing
short schedule arrays. Compact/wide fixtures exercise a 35-bucket plan and its
last partial group. This evidence does not complete live keyboard/focus or
VoiceOver checks, or malformed-import dimension review.

Verification: the full suite passed 358 tests (180 macOS app, 169 core, 9 portable
MPS). The ten MRP tests passed again after replacing repeated identity searches
with grouped lookups. Build/start verification passed and `git diff --check` was
clean. No files were staged and Git reported no reference changes. The previous
temporary reference-hash file no longer existed; a fresh 117-file baseline was
saved under the ignored `.build/ui-audit` directory. Historical hash equality
cannot be reasserted from that fresh baseline.

The available tool inventory on this date no longer exposed native Computer Use
inspection. No new interactive keyboard, focus, or VoiceOver verification is
claimed. The goal remains active for the outstanding source and runtime audits.

## MRP imported-dimension repair — 2026-10-11

The next audit found extra schedule cells outside the named bucket extent and
MPS entries without corresponding item rows. The native draft now retains the
maximum extent across all imported vectors, pads missing editable cells, and
exposes extra periods with blank names. Required receipts and MPS quantities
remain blank rather than silently becoming zero; optional blank capacity remains
unbounded. An explicit review action accepts displayed dimensions without
repairing required values and participates in undo/redo.

Orphan MPS vectors become incomplete native items with blank required metadata
and receipts. The displayed LFL policy requires review. Their quantities survive
native renaming and independent spreadsheet repair. Deterministic identifier
ordering avoids dictionary-order-dependent presentation. Core validation and
solution behavior remain unchanged.

Tests cover extra-value preservation, native required-field repair, orphan
reconstruction, normalized JSON round trips, JSON Apply, and review undo/redo.
Compact/wide fixtures include the review banner, incomplete schedule cells,
and orphan metadata. Interactive focus timing, keyboard, and VoiceOver checks
remain unproven; this checkpoint does not close the full goal.

Verification: 361 tests passed (183 macOS app, 169 core, 9 portable MPS),
build/start verification passed, and `git diff --check` was clean. No files were
staged; all 117 reference hashes matched the persisted local audit baseline.
The full goal remains active for remaining family interaction and execution
audits, including actual keyboard, focus, and VoiceOver verification.

## Aggregate Planning native repair — 2026-10-11

The audit found whole-draft validation blocking otherwise valid period-table
repairs, identity replacement on every paste, partial header detection dropping a
headerless period named `Period`, and unsafe imported-vector indexing. Table
replacement now validates its own schema and numbers atomically, retains row
identities only for unambiguous names, and leaves unfinished plan settings intact.
New default names avoid collisions. Addition/paste/removal and draft replacement
have explicit period-focus targets; actual focus timing remains unverified.

Imports retain the maximum extent across every period vector. Extra names and
missing required values remain blank; optional maxima display as unbounded,
subject to explicit dimension review. Acceptance does not fill required cells,
participates in undo/redo, and leaves QSBCore responsible for domain validation.
Tests cover native repair, extra-value preservation, JSON round trips, workspace
JSON Apply, review undo/redo, ambiguous identity, and atomic malformed-table failure.

Compact and wide review renders showed a clipped formulation value. Its caption
now sits above the native picker so the full selection has the available width.
The full suite passed 365 tests (187 macOS app, 169 core, 9 portable MPS) before
that presentation-only correction; the layout test and build/start check were
rerun afterward. Interactive keyboard, focus, and VoiceOver verification, plus
background execution for families other than Simulation, remain open.


## Project Scheduling method and spreadsheet preservation — 2026-10-11

The audit found method switches overwriting CPM normal/crash times and costs and
PERT estimates. Each method is now seeded on its first visit and preserves its
editable fields afterward, including invalid strings. The first PERT-to-CPM seed
uses the core PERT expected time when all estimates are numeric; no mathematical
formula was duplicated in the GUI. Activity identity and predecessor text remain
shared across methods.

Spreadsheet replacement validates its own structure/numbers and can repair rows
while the title or time unit is unfinished. Complete-header matching no longer
drops an activity named `Activity`. Unambiguous trimmed names retain UUIDs and
dormant method fields across reorder; ambiguous/new rows get independent UUIDs.
Native removal targets a neighbor, paste preserves a surviving target, and undo
or replacement repairs an orphaned name-field focus target. Runtime focus timing
is still unproven.

Five regression tests cover method round trips with costs and invalid values,
core-based initial estimates, independent/atomic table repair, dormant fields,
ambiguous names, and workspace undo/redo. Compact/wide render fixtures include
invalid PERT and the restored invalid CPM form. Full verification passed 370
tests (192 macOS app, 169 core, 9 portable MPS), build/start verification passed,
and `git diff --check` was clean. No files were staged; 117 reference hashes
matched the persisted audit baseline.

Computer Use became available again. Cmd-N opened the native creation sheet;
Planning & Scheduling and the PERT/CPM template exposed expected accessible
labels, selection, and Create enabled state. After Create, the native pipe closed.
Rebinding and screenshot inspection also failed. The latest macOS diagnostic,
`SkyComputerUseService-2026-10-11-165006.ips`, identifies that service's
EXC_BREAKPOINT/SIGTRAP and `Array.remove(at:)` assertion. QSB processes remained
present, but this is insufficient to establish the created editor's UI state or
correctness. Editor keyboard/focus and VoiceOver remain unverified. The goal
remains active; source/runtime audits and other-family background execution
remain open.


## Project Scheduling background execution — 2026-10-11

All interactive Run entry points route CPM/PERT through a captured typed core
request outside the main thread. The workspace publishes solving/progress first,
clears prior output, rejects duplicate runs, and accepts results only when the
run identifier, JSON, native draft, and backend still match. Method/model edits,
replacement families, validation, and superseding runs invalidate pending results
and errors. Raw JSON/backend changes are also checked before applying output.
Superseded workers finish; this checkpoint does not claim a cancellation UI.

ProjectSchedulingRunOperation owns worker orchestration only: QSBCore performs
validation, scheduling, expected-time calculations, and normalized serialization.
Invalid required draft strings lead to the existing validation surface; semantic
invalidity produces the worker's core diagnostics. Backend/worker failures remain
explicit run failures. Unavailable external scheduling directs users to QSB Native
or Validate only instead of suggesting HiGHS installation.

Five asynchronous regressions cover CPM and PERT off-main execution, visible
pending state, duplicate rejection, edited methods and replacement families,
changed backend/JSON, validation invalidation, stale errors, newer-run precedence,
validation-only/unavailable/invalid/failure outcomes, and typed solution output.
The combined project/simulation async check passed ten tests. Pending editor and
failure configuration renders cover compact and wide windows; these are static
artifacts, not live keyboard/VoiceOver proof.

Full verification passed 375 tests (197 macOS app, 169 core, 9 portable MPS),
build/start verification passed, and diff checking was clean. No files were
staged; all 117 reference hashes matched the persisted baseline. The goal remains
active for other-family execution and interaction audits; the native inspection
service failure recorded above still prevents editor keyboard/focus/VoiceOver
verification.


## Aggregate Planning and MRP background execution — 2026-10-11

Both families now route interactive Run through immutable core requests outside
the main thread. The workspace exposes solving/progress, clears previous output,
rejects duplicate Run actions, and applies output only for the matching run,
JSON, native draft, and backend. Native edits, family replacement, validation,
changed backend/JSON, and newer runs invalidate stale success or failure output.
Superseded calculations finish; no cancellation UI is claimed.

The workers call core backend validation, solving, and normalized serialization.
Incomplete native fields lead to existing validation; core semantic invalidity
is reported without attempting a solve. Aggregate Planning retains optional
host-provided HiGHS discovery/solving in the worker. MRP's unavailable external
backend now directs users to QSB Native or Validate only.

Five regressions exercise both families: off-main execution and typed output,
pending/duplicate behavior, independent native edits, family replacement and
validation, changed backend/JSON, newer-run precedence, validation-only and
invalid input, unavailable backends, and current/stale worker failures. Combined
planning/project execution checks passed seven tests. Static compact/wide
fixtures include both pending editors/status bars and MRP external failure.

Full verification passed 380 tests (202 macOS app, 169 core, 9 portable MPS),
build/start verification passed, and diff checking was clean. No files were
staged; all 117 reference hashes matched the persisted baseline. Live editor
keyboard, focus, and VoiceOver remain unverified due to the previously recorded
native inspection service failure. Remaining family execution and interaction
audits keep the full goal active.


## Knapsack and Line Balancing independent spreadsheet repair — 2026-10-11

The audit found valid tables blocked by incomplete settings elsewhere and every
paste replacing native row identities. Both tables now validate their own row
structure and fields atomically before replacement. Knapsack checks required
names, integer quantity/resource use, and finite return; Line reuses its typed
row converter for required names, integer IDs/times/successors, and boolean
isolation. Core bounds, duplicates, and precedence semantics remain in QSBCore.

Complete case-insensitive header matching avoids dropping a headerless knapsack
item named `Item`. Unambiguous knapsack names preserve UUIDs across reorder.
Line numeric source IDs preserve UUIDs through rename/reorder, including equivalent
text such as `1` and `01`; duplicate source IDs receive distinct row identities.
Missing successor references remain visible. Paste retains surviving focus,
removal targets a neighbor, and undo/replacement repairs orphaned focus targets.
These source paths do not establish live focus timing or VoiceOver behavior.

Six regressions cover independent repairs, retained settings/identities,
ambiguous rows with core diagnostics, malformed atomic failure, and workspace
undo/redo. The targeted check passed fifteen tests. Static compact/wide fixtures
show incomplete knapsack capacity and line cycle time alongside editable tables.
Full verification passed 386 tests (208 macOS app, 169 core, 9 portable MPS),
build/start verification passed, and diff checking was clean. No files were
staged; all 117 reference hashes matched the persisted baseline. The full goal
remains active for remaining execution/usability audits and actual keyboard,
focus, and VoiceOver verification.


## Knapsack and Facilities background execution — 2026-10-11

Bounded Knapsack, Line Balancing, Facility Location, and Facility Layout now route
interactive Run through captured typed core requests outside the main thread.
Pending state clears prior output and rejects duplicates. Run identifiers, native
drafts, JSON, and backend are checked before applying results. Layout also
captures its initial/pairwise strategy; changing it invalidates pending layout
output while irrelevant strategy changes do not invalidate Location runs.
Validation, model/family edits, replacement, and newer runs reject stale success
and failure output. Superseded workers finish; no cancellation UI is claimed.

The worker adapters delegate validation, algorithms, metadata, and normalized
serialization to QSBCore. Native conversion errors and core-invalid input lead
to Validation; current worker failures remain explicit. Unavailable external
solving now directs users to QSB Native or Validate only for these families.
Other dynamic-programming variants retain their existing synchronous UI route.

Five async regressions exercise all four families, including exact output
agreement with synchronous core routes, off-main execution, pending/duplicate
state, edits/replacement/validation, backend/JSON/strategy changes, validation-only
and unavailable modes, invalid native/core input, stale failures, and newer-run
precedence. Static pending editor/status renders cover compact and wide windows.

Full verification passed 391 tests (213 macOS app, 169 core, 9 portable MPS),
build/start verification passed, and diff checking was clean. No files were
staged; all 117 reference hashes matched the persisted baseline. The full goal
remains active for remaining family execution/usability audits and actual
keyboard/focus/VoiceOver verification. Static renders and process survival do
not close the runtime inspection gap recorded above.


## Remaining specialized-family background execution — 2026-10-11

QP, NLP, Goal Programming, Acceptance Sampling, and Quality Control now route
interactive Run through typed core requests outside the main thread. A common
worker adapter handles backend validation, solving, and normalized output with
family-specific core models/documents. Its workspace snapshot compares JSON,
backend, and native drafts, including invalid strings, imported-dimension state,
and dormant variant fields. Run identifiers reject superseded success/errors.
Pending state clears prior output and rejects duplicate runs. Native/core-invalid
input leads to Validation; current worker failures remain explicit. Superseded
computations finish; no cancellation UI is claimed.

QP and Goal retain existing optional HiGHS discovery in the worker. The QP
unavailable message no longer incorrectly claims its translation is disabled.
NLP, Acceptance Sampling, and QC unavailable guidance selects native/validation
modes. Core/CLI contracts and mathematical algorithms remain unchanged.

Five asynchronous regressions cover all five families, exact output agreement
with synchronous routes, pending/off-main/duplicate behavior, edits/replacement/
validation, backend/JSON changes, current/stale failures, newer-run precedence,
invalid native/core input, all five QC variants, and both sampling plans. Static
pending renders cover compact/wide windows. All thirteen specialized families
named in the goal now route interactive Run to background computation.

Full verification passed 396 tests (218 macOS app, 169 core, 9 portable MPS),
build/start verification passed, and diff checking was clean. No files were
staged; all 117 reference hashes matched the persisted baseline. The goal remains
active: source review found whole-draft dependencies still blocking independent
NLP/QC spreadsheet repair, and actual keyboard/focus/VoiceOver verification is
still missing because of the recorded native inspection service failure.


## Independent NLP and QC spreadsheet repair — 2026-10-11

Pasting a table now validates only that section, allowing repair while metadata
or another NLP section is unfinished. Atomic rejection preserves prior input.
NLP matches full headers and retains uniquely named row identities. QC retains
unique column names and exported observation ordinals, including reordered rows;
duplicates receive new distinct identities. Surviving paste focus is retained.
Regression checks cover incomplete metadata, independent tables, rejected input,
duplicate identifiers, and extreme observation labels. Full suite: 398 tests
(220 app, 169 core, 9 MPS); build/start verification and diff checks pass.
Live keyboard/VoiceOver remains pending after the native inspection service crash.
NLP imported dimension preservation remains open.


## NLP imported bounds retained for review — 2026-10-11

Native import now uses the full extent of names and both bound arrays. Excess
bounds remain visible with empty names; missing bounds display unbounded. An
explicit review action accepts those defaults without bypassing required names,
number conversion, or QSBCore validation. Review supports workspace undo/redo.
Regression tests cover excess/missing bounds, retained row identities, conversion
before/after review, and undo/redo. Compact and wide review screens were rendered;
both renders were visually inspected with no overlap. Full suite passes
400 tests (222 app, 169 core, 9 MPS); build/start verification passes. Diff checking is clean; all 117 reference
hashes match the persisted baseline. Live keyboard/focus/VoiceOver verification
and the remaining source usability audit are still open.


## NLP and QC focus repair — 2026-10-11

NLP now tracks individual variable and constraint fields, including bounds,
expressions, relation pickers, and RHS. Surviving paste targets retain the field;
orphaned targets after identity changes move to the nearest remaining row in
that field. Empty constraints target Add Constraint. QC row/column identity
changes similarly repair orphaned cells, including replacement and undo/redo.
Specific draft checks pass 18 tests; the full suite passes 400 (222 app, 169 core,
9 MPS), including compact/wide rendering. Source inspection confirms the focus
bindings and identity-change observers; actual runtime focus remains unverified.
A fresh native inspection attempt reached the creation sheet, selected NLP, then
failed at Create with “Sky Computer Use native pipe closed before response”.
Remaining source audit: QP/Goal row focus and Facilities identity changes lack
comparable replacement/undo observers. Live keyboard and VoiceOver remain open.
Diff checking is clean; all 117 reference hashes match the persisted baseline.

Build/start verification also passed for the NLP/QC focus changes.


## QP, Goal and Facilities identity-change focus repair — 2026-10-11

A shared row-selection policy retains surviving identities and chooses the nearest
remaining row without creating focus when none existed. QP and Goal observe
variable/constraint/goal identity changes; empty constraints expose their Add action.
QP keeps its focused matrix row and column group visible after variable changes.
Location repairs removed facility targets. Layout retains selected departments
and visible rectangle targets; empty rectangles expose Add Rectangle. Row paste
retains surviving selections. Full suite passes 400 tests (222 app, 169 core, 9 MPS),
including compact/wide layouts. Diff checking is clean; no files are staged and
all 117 reference hashes match the baseline. Actual runtime keyboard/VoiceOver
remains unverified. Remaining source review includes Simulation route/service
focus, MRP BOM focus, and large-matrix paste selection in QP/shared matrix editors.

Build/start verification passed for the QP/Goal/Facilities focus changes.


## Dense matrix, Simulation and MRP focus repair — 2026-10-11

Shared matrix paste requests now keep the selected row/group instead of resetting
to the first cell; row/column changes preserve or repair the focused cell and
reveal its group. QP matrix paste likewise retains a surviving focused cell or
selected row/group. Simulation observes component/route/service changes and keeps
the selected component, repairing removed rows or focusing their Add action when
empty. MRP observes BOM rows and repairs item/bucket targets, revealing the
focused bucket's group. These are source changes; actual focus/VoiceOver remains
unverified. Specific checks pass 21 tests. Full suite passes 400 tests (222 app,
169 core, 9 MPS), including compact/wide renders. Diff checks pass; no files are
staged and all 117 reference hashes match the baseline.
New source finding: Simulation route/service paste still calls whole-draft
conversion and allocates fresh row IDs, blocking independent repair and surviving
row selection. Correcting those transfers remains open before final completion.

Build/start verification passed for the dense matrix/Simulation/MRP focus changes.


## Independent Simulation spreadsheet repair — 2026-10-11

All three Simulation transfers now validate only their own table before atomic
replacement. Full-header recognition preserves reserved-looking names. Unique
component names preserve hidden routes/rules; unique structured source/member
keys retain route/rule identities across reorder and case changes. Ambiguous
source names reject association rather than cloning IDs. Duplicate member rows
receive distinct identities. Core validation remains responsible for graph,
probability, distribution semantics and solving. Regression tests cover unrelated
unfinished sections, header-only clearing, identity/key collisions, repeated rows,
atomic rejected transfers, and workspace undo/redo. Full suite passes 404 tests
(226 app, 169 core, 9 MPS); diff checks pass, no files are staged, and all 117
reference hashes match the persisted baseline. Live keyboard/VoiceOver remains
unverified after the native inspection service failures.


Build/start verification passed for independent Simulation transfers. A fresh
native inspection attempt selected NLP and confirmed with Return (rather than
the previously failing Create click); it also failed with “Sky Computer Use
native pipe closed before response”. Live editor keyboard/VoiceOver verification
is still unavailable through this service.

## Completion audit against the full UI goal — 2026-10-11

Completion is not yet proven. Source, API tests, static renders, and actual native
interaction provide different kinds of evidence; the latter is still missing for
editor keyboard/focus/VoiceOver flows.

| Requirement | Current evidence | Status and remaining verification |
| --- | --- | --- |
| Thirteen typed native editors | `ModelEditorView` routes QP, NLP, Goal, Knapsack, Aggregate, MRP, Project, Layout, Location, Line, Acceptance, QC and Simulation to dedicated views. Each has a corresponding typed draft and draft tests. | Implemented in source; conversion/state tests pass. Live interaction remains unverified. |
| Core ownership and portable architecture | Core model/validator/backend/JSON types are used by typed drafts and background run operations; `QSBCore` contains no SwiftUI, AppKit or ArgumentParser imports. | Source evidence supports separation. This is not a new solver expansion. |
| JSON as advanced interchange | Native editor routing precedes the structured fallback. Draft/workspace tests cover normalized conversion/export and native JSON application/import where available. | API behavior verified; actual file-panel/export interaction remains unverified. |
| Spreadsheet entry and independent repair | Draft tests exercise complete transfers, malformed input, atomic rejection, retained identities, and unfinished fields across table families. Acceptance uses a parameter form rather than a dense table. | Draft API behavior verified. Clipboard buttons and spreadsheet applications still need live end-to-end verification. |
| Explicit editing, invalid, solving, solved and failure states | Draft/workspace tests and asynchronous run tests cover preflight invalidity, pending work, duplicate runs, current/stale success and failures, replacement and backend changes. | State behavior verified at API level. Interactive status announcements remain unverified. |
| Undo/redo without losing invalid input | Family draft tests use workspace replacement and UndoManager; dormant variants and imported dimensions have regressions. | Workspace state verified. Native keyboard Undo/Redo and focus restoration remain unverified. |
| Dense matrix ergonomics | Shared/QP row selection and 12-column groups, matrix navigation tests, dense first/last-page renders, retained whole-table interchange, and bounded Layout canvas metrics. | Source/API/render evidence available. Keyboard traversal and paste selection timing remain unverified. |
| Labels, values and non-visual alternatives | Solution charts/geometry expose labels/values or text alternatives. Knapsack selected-item/trace rows and summary metrics now expose related values as named accessibility elements. | Source improved. Runtime AX tree, VoiceOver order, announcements and control behavior remain unverified. |
| Compact and wide layouts | `renderCompactAndWideUILayouts` renders native editors, invalid/pending examples, dense matrices and result views. Goal and Knapsack solution renders were added to the loop; Layout has separate large-grid solution renders. | Static render gate passes; Goal/Knapsack compact screenshots inspected with no overlap. Resizing a live window remains unverified. |
| UI language understandable to users | Native forms and transfer guidance exist. All thirteen specialized result families now use readable backend/algorithm/exactness labels via SolverMetadataPresentation; original metadata remains in JSON. | Implemented in source and verified with thirteen sample outputs and JSON round trips; actual VoiceOver remains unverified. |
| Family documentation and public status | Family guides and `PORTING_ROADMAP.md` record typed editors, transfers, background execution and the open runtime verification. | Updated; final completion status remains open. |
| Required command and Git/reference gates | Full `swift test`: 406 tests (228 app, 169 core, 9 MPS). Diff checks pass; status including ignored paths inspected, nothing staged; all 117 reference hashes match the persisted baseline. | Passing for this checkpoint. Build/start verification recorded below. |

Native interaction attempts can inspect the empty workbench and creation sheet,
including Cmd-N, template descriptions, selection and enabled Create. Both Create
click and Return confirmation fail with “Sky Computer Use native pipe closed
before response”. These attempts do not prove the editor flows. The goal remains
active while presentation-label work and the missing runtime verification remain.

Build/start verification passed for the Knapsack accessibility and result-render checkpoint.


## Readable result metadata and native inspection blocker — 2026-10-11

The thirteen specialized result families now share app-only display names for
backend, algorithm and exactness. Original normalized metadata is unchanged.
Limited scale does not assert stronger solver guarantees; unknown algorithms use
Custom algorithm with the original identifier retained in JSON. Tests solve all
thirteen sample families to check readable algorithm coverage and verify unknown
metadata interchange. Full suite passes 406 tests (228 app, 169 core, 9 MPS).
Compact/wide result renders pass; Goal's compact result was inspected after the
label change. Build/start verification and diff checks pass. Git status including
ignored paths was inspected; nothing is staged and all 117 reference hashes match.

A generated audit app copied under ignored `.build/ui-audit` with a unique bundle
identifier also reached the creation sheet and selected NLP, then Return failed
with “Sky Computer Use native pipe closed before response”. Rebinding that exact
app path failed too. This removes duplicate bundle identity as a workable remedy.
The audit bundle has not changed source packaging or existing application instances.

The implementation/API/static-render requirements have evidence above. The
remaining required live checks (editor keyboard/focus/VoiceOver, clipboard buttons,
window resize and file/export interaction) are not proven. Repeated native
inspection failures prevent further meaningful interaction verification without
an external service recovery or user-provided runtime evidence. The UI goal must
not be marked complete from source/tests/screenshots alone.
