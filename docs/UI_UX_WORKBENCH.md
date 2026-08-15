# QSB Native Workbench: UI/UX Audit and Design Proposal

Status: design proposal, not an implementation plan committed to code yet.

This document records the post-Phase-C product audit of `QSBMacApp`. It
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

The main product gap is not solver capability. It is that the macOS app still
looks and behaves primarily like a JSON editor with a collection of solution
mini-apps.

## Current-state audit

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

The normal Model pane is a monospaced editable `TextEditor` containing raw
JSON. This is a good advanced/debugging surface and a weak default editor:

- field-level errors cannot be placed beside an input;
- model identity and assumptions are hidden in JSON;
- changes are not visibly classified as editing versus validated;
- there is no dirty state or save/revert model;
- the LP/ILP family now has a native typed editor; other families still use
  JSON as their practical editing surface.

The first production editor is the LP/ILP editor. It keeps an internal
`LinearProgrammingDraft` only while the user is editing incomplete values, then
converts through one boundary into `LinearProgram`. QSBCore owns semantic
validation and solving. The old LP Entry Mock is no longer part of the product
flow; its concerns were replaced by the native editor without exposing the
simplex unrestricted-variable transformation.

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

There is no mature universal creation workflow. The LP Entry Mock is a sheet
opened from the Samples menu, not a model-creation route. Other families have
samples but no native editor.

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

### P0 — blocks or seriously confuses the core workflow

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
payoff/tree editors for decision analysis. There should be no universal form
schema that erases domain concepts.

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
| `externalHighPerformance` | External solver | Future / unavailable until configured |

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

- Model: `Definition` and `JSON` tabs, with native editing as the default once
  a family editor exists.
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
- Remaining refinement includes richer undo/redo, field focus routing, and
  wider editor ergonomics for very large matrices.

### UI Phase 3 — Family editor expansion

Prioritize structured editors with high educational and workflow value:

1. Network and scheduling tables;
2. Inventory and planning period tables;
3. Decision analysis/payoff/tree editors;
4. Forecasting and Markov data editors;
5. remaining family-specific forms where fixtures and validation make the
   editing contract clear.

### UI Phase 4 — Refinement

- complete keyboard-first paths and focus restoration;
- VoiceOver and text-scaling audits;
- state restoration and recent models;
- search/filter for large tables and result details;
- compact/wide regression fixtures;
- reduced-motion and larger-instance ergonomics.

## Deliberately deferred

- no QSBCore, solver, backend, CLI, or JSON redesign;
- no external solver integration;
- no conversion of the LP mock into a production editor;
- no universal mathematical editor abstraction;
- no pixel-perfect WinQSB imitation;
- no implementation of the proposed workbench shell in this checkpoint.
