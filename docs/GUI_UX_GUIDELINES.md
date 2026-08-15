# QSB GUI and UX Guidelines

This document defines the product and interaction rules for the native QSB
macOS workbench. It applies to model entry, import, validation, solving,
inspection, export, and family-specific visualizations.

The goal is not to reproduce WinQSB pixel for pixel. The goal is to make
operations-research models understandable, editable, verifiable, and teachable
on a modern Mac while preserving the same typed model and solver behavior used
by `QSBCore` and the CLI.

## Reference Principles

QSB adopts these references as design inputs:

- [Apple Human Interface Guidelines: Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/)
  for desktop ergonomics, menus, resizable windows, keyboard workflows,
  density, and personalization.
- [Apple Human Interface Guidelines: Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables)
  for editable, sortable, resizable, selectable tabular data.
- [Apple Human Interface Guidelines: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility/)
  and [SwiftUI accessibility fundamentals](https://developer.apple.com/documentation/swiftui/accessibility-fundamentals)
  for VoiceOver, keyboard, appearance, labels, values, and alternate input.
- [SwiftUI `Form`](https://developer.apple.com/documentation/swiftui/form) for
  platform-appropriate grouping of data-entry controls on macOS.
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/) for input assistance, error
  identification, labels, suggestions, status messages, keyboard access, and
  error prevention. WCAG is used as a practical accessibility benchmark even
  though QSB is a native macOS app rather than a website.

These references guide decisions; they do not override the clean-room,
portable-core, or fixture-preservation rules in the project roadmap.

## Product Mental Model

Every model workflow should make this sequence visible:

1. Choose or import a model family.
2. Enter or inspect the model data.
3. Validate the model.
4. Resolve validation issues.
5. Choose a backend and solve, or export as validate-only.
6. Inspect the solution and its assumptions.
7. Export the model or solution.

The interface should never make the user guess whether they are editing model
data, changing solver options, or inspecting derived results.

Use these nouns consistently:

- **Model**: user-provided structure and parameters.
- **Validation**: structural and semantic checks before solving.
- **Backend**: the selected solving or validation strategy.
- **Solution**: computed values, objective, diagnostics, assumptions, and trace.
- **Reference**: imported legacy material or preserved fixture context.

## Information Architecture

The main window should use a stable macOS split layout:

- a lightweight sidebar for model/workspace navigation;
- a primary editor or inspection surface;
- an optional inspector for context, assumptions, diagnostics, and selection;
- a persistent status area for validation and solve state.

Prefer fewer, wider desktop surfaces over deeply nested modal navigation. Use a
sheet or separate window for creation when the task needs a clear commit/cancel
boundary. Keep the JSON editor available as an advanced fallback, not as the
default experience for new users.

The main workspace should distinguish at least these modes:

- `Edit`: change model inputs;
- `Validate`: understand and resolve issues;
- `Solve`: select backend/options and run;
- `Solution`: inspect results, assumptions, and educational traces;
- `JSON`: inspect or edit the normalized representation.

## Native Model Entry

Family-specific editors are the preferred long-term input layer. They should
produce the same normalized request types consumed by the CLI and `QSBCore`.

### Shared editor structure

Each editor should provide:

- a model name and family header;
- a short description of what the model represents;
- a progressive form for essential inputs first;
- editable tables for repeated data;
- add, remove, reorder, duplicate, and paste-from-spreadsheet actions where
  they are meaningful;
- explicit units, signs, bounds, and relation operators;
- an assumptions section for defaults and interpretation;
- inline validation plus a summary of all issues;
- `Validate`, `Solve`, `Export`, and `Cancel` actions with predictable placement;
- an unsaved-change indicator and reversible editing where practical.

Do not expose raw JSON fields as the primary form unless the family has no
reasonable structured editor yet.

### LP and ILP

Use a matrix editor with:

- variable names as editable column headers;
- constraint names as editable row labels;
- objective direction and coefficients in a dedicated objective row;
- relation operators (`<=`, `=`, `>=`) in their own column;
- right-hand sides in a dedicated column;
- lower and upper bounds in a variable-properties inspector;
- variable type (`continuous`, `integer`, `binary`) as an explicit control;
- keyboard navigation and spreadsheet-style copy/paste.

### Networks

Offer both a table and diagram representation. The table is authoritative for
exact values; the diagram is for orientation and selection. Make source,
destination, capacity, cost, distance, and direction explicit by network kind.

### Inventory, forecasting, queues, and scheduling

Use period- or entity-oriented tables with visible units and a compact summary
of the active policy or assumptions. Avoid forcing users to infer whether a
number is demand, stock, time, probability, capacity, or cost.

### Decision analysis and Markov models

Use tree/state editors with an equivalent tabular representation. Every node or
transition must have a stable name, an editable value, and a visible semantic
type. Never make color the only distinction between chance, decision, and
terminal nodes.

## Validation and Error Handling

Validation is part of the editor, not an afterthought or a blocking alert.

- Validate incrementally where possible, and run a complete validation before
  solving or exporting.
- Identify the exact field, row, column, node, or transition in error.
- Explain the problem in plain language and state how to correct it.
- Preserve the entered value while marking it invalid.
- Offer a correction or default only when it is unambiguous.
- Show a concise issue summary with severity and navigation to each issue.
- Do not use color alone to communicate error, warning, or success.
- Never discard invalid or unsaved data without an explicit confirmation.
- Treat solver infeasibility and unsupported variants as structured diagnostics,
  not generic “Something went wrong” alerts.

Before a destructive or irreversible action, provide a review or confirmation
step. For model creation, prefer a reversible draft followed by explicit
`Create Model` or `Save`.

## Controls and Desktop Interaction

- Use native `Form`, `Table`, `List`, `Grid`, `Picker`, `Stepper`, and `TextField`
  controls when they express the task well.
- Keep important actions available from both the toolbar/menu and keyboard.
- Use familiar symbols from SF Symbols inside icon buttons and provide tooltips
  for unfamiliar controls.
- Make row and column selection stable and obvious.
- Let users resize table columns and sort where ordering has meaning.
- Support undo/redo for model edits as the implementation matures.
- Support paste of rectangular numeric data into compatible tables.
- Do not hide core actions behind custom gestures.
- Use sheets for focused creation or confirmation, not for the whole workbench.
- Support window resizing and compact widths without clipping labels or values.

## Accessibility and Inclusion

Accessibility is a product requirement, not a finishing pass.

- Every custom control and visualization must expose an accessibility label and
  value that names the model entity and its current value.
- Provide a non-visual equivalent for every diagram, chart, color encoding, or
  drag interaction.
- Keep full keyboard navigation possible through forms, tables, menus, and
  validation issues.
- Respect system appearance, text size, reduced motion, and contrast settings.
- Use semantic colors and pair them with text, symbols, or position.
- Test representative flows with VoiceOver, keyboard-only navigation, and
  Accessibility Inspector.
- Do not auto-dismiss important validation or status messages.

## Educational Clarity

QSB is also a teaching and inspection tool. A solution view should make clear:

- what was solved;
- which backend and algorithm were used;
- whether the result is exact, closed-form, heuristic, approximate, or
  fixture-scale;
- what assumptions were made;
- how the result follows from the model;
- which values are inputs and which are derived.

Prefer a compact summary plus expandable detail over an undifferentiated wall
of numbers. Preserve the JSON solution view for auditability and automation.

## Engineering Boundary

UI code may collect state, present diagnostics, and map typed values to
controls. It must not parse legacy files, implement solver algorithms, or
duplicate validation rules. New behavior belongs in `QSBCore` first when it is
domain behavior; the GUI then consumes the typed model, diagnostics, and
solution document.

Every new editor should have:

- a normalized model/request path;
- validation coverage;
- a UI state model that can represent empty, editing, invalid, solving,
  solved, and failed states;
- compact and wide layout checks;
- keyboard and accessibility checks;
- a JSON fallback or export path.

## Review Checklist

Before merging a GUI or editor change, verify:

- Can a first-time user identify what to enter without reading the source?
- Are units, bounds, signs, and defaults visible?
- Can the user correct an error without losing data?
- Can the user complete the workflow without a mouse?
- Is every important action available from a familiar control or menu?
- Does the layout remain usable at compact and wide window sizes?
- Are model, validation, backend, and solution concepts clearly separated?
- Does the UI consume `QSBCore` rather than reimplementing its rules?
- Are accessibility labels, values, and non-visual alternatives present?
- Are tests, docs, and roadmap notes updated with the behavior?

