# QSB Engineering Guidance

These instructions apply to all work in this repository. They complement
`CONTRIBUTING.md`, `docs/LEGACY_REFERENCE_POLICY.md`, and
`docs/PORTING_ROADMAP.md`. The roadmap is the public project-status source of
truth; any local `goal.md` remains private working context.

## Project Intent

QSB is a clean-room, portable modernization of WinQSB-style operations
research workflows. Preserve the compatibility value while keeping the core
usable from SwiftPM, the CLI, the macOS app, tests, and future frontends.

## Architecture Rules

- Keep `QSBCore` independent of SwiftUI, AppKit, CLI argument parsing, and
  macOS-only assumptions.
- Put parsing, normalization, validation, solver behavior, backend selection,
  and solution structures in `QSBCore`.
- Keep `qsb` responsible for command parsing, process exit codes, and text/JSON
  presentation.
- Keep `QSBMacApp` a thin typed client of `QSBCore`. Do not duplicate parsers,
  formulas, validation rules, or solver algorithms in views or stores.
- Preserve normalized JSON as a stable interchange and debugging boundary.
- Keep native educational solvers deterministic and explicitly characterize
  exactness, scale, and limitations.
- Add external high-performance integrations behind backend protocols; never
  couple model parsing directly to an external solver.

## Clean-Room and Fixture Safety

- Treat `reference/winqsb` as immutable reference material. Do not modify,
  rename, reformat, or stage it unless the task explicitly changes fixture
  organization and the change is reviewed.
- Do not commit proprietary binaries, manuals, help files, installers, or
  derived copies of legacy material.
- Preserve fixture paths in tests and documentation.
- Keep local-only reference payloads out of public commits.
- Use legacy files as behavior and compatibility references, never as source
  code.

## Implementation Workflow

1. Read the relevant roadmap, family documentation, and nearby code.
2. Establish the baseline with `swift test` or the narrowest relevant test.
3. Identify the layer that owns the behavior before editing.
4. Implement the smallest coherent change using existing patterns.
5. Add or update tests for parsing, validation, JSON round trips, backend
   selection, CLI behavior, and UI state as applicable.
6. Update family documentation and the roadmap for meaningful milestones.
7. Run `git diff --check`, inspect `git status --short --ignored`, and verify
   that no reference material is staged.

Do not use broad staging commands in a mixed worktree. Stage explicit paths.
Keep unrelated user changes intact.

## Swift and SwiftUI Practices

- Prefer value types and small focused types.
- Keep files named after their primary type and split large views before they
  become mixed model/store/view modules.
- Make state ownership explicit and use the narrowest appropriate SwiftUI
  state mechanism.
- Prefer native macOS controls and system-adaptive colors/materials.
- Follow `docs/GUI_UX_GUIDELINES.md` for editor and visualization work.
- Keep UI states explicit: empty, editing, invalid, validating, solving,
  solved, and failed.
- Add accessibility labels and values to custom controls and visualizations.
- Preserve keyboard paths and non-visual alternatives for important actions.
- Avoid force unwraps and hidden global mutable state in production paths.
- Use comments only for non-obvious decisions or compatibility constraints.

## Code Comments

Comments should primarily explain why, not merely what the code does. Add
comments for non-obvious mathematical transformations, numerical-stability
decisions, legacy or WinQSB compatibility constraints, parsing quirks,
solver assumptions or limitations, maintenance-sensitive invariants,
deliberate deviations from simpler implementations, macOS or SwiftUI
gesture-precedence and coordinate-space decisions, accessibility or AX
workarounds, and compatibility bridges or intentionally temporary
architectural compromises.

Avoid comments that restate obvious code, narrate every function, justify dead
code, preserve obsolete history, or compensate for unclear naming. Prefer
nearby comments over large prose blocks. For public APIs, use Swift
documentation comments (`///`) when callers need semantics, units,
invariants, ownership, or limitations. Comments inside tests are reserved for
non-obvious regressions, important legacy edge cases, or otherwise arbitrary
expected values; descriptive test names should carry the rest.

A non-obvious mathematical transformation, compatibility workaround, or
architectural invariant should be understandable from the code and its nearby
comments without requiring the maintainer to reconstruct the reason from Git
history.

## Testing Standards

For core behavior, prefer tests that cover:

- valid and malformed legacy inputs;
- structured validation diagnostics;
- normalized JSON encode/decode round trips;
- backend selection and unavailable-backend behavior;
- deterministic solver results and exactness metadata;
- CLI exit codes and output where the command contract changes.

For GUI behavior, verify when relevant:

- compact and wide macOS windows;
- empty, invalid, solving, solved, and failure states;
- keyboard navigation and primary shortcuts;
- accessibility labels and values;
- JSON fallback and export behavior;
- no clipping, overlap, or accidental loss of input.

Use the repository's existing commands first:

```sh
swift test
./script/build_and_run.sh --verify
git diff --check
```

If a check cannot run because local fixtures or a platform tool is unavailable,
record the limitation clearly rather than weakening the test.

## Documentation and Change Scope

- Document public model families, input assumptions, solver character, and
  normalized JSON behavior.
- Update `docs/PORTING_ROADMAP.md` only when a checkpoint or roadmap status
  genuinely changes.
- Keep pull requests narrow, with a readable description of user-facing
  behavior and validation performed.
- Never hide a behavior change behind a refactor-only description.

## Git and Review Safety

- Inspect status and diff before staging.
- Never reset, checkout, or delete user changes without explicit permission.
- Use explicit branch and commit scopes.
- Do not push reference fixtures, local manuals, generated bundles, or secrets.
- Before merging, require passing relevant checks and confirm the PR scope.

## Definition of Done

A change is complete when its owning layer is correct, the relevant tests pass,
the behavior is documented, the UI remains accessible and usable at supported
sizes, and the working tree contains no accidental reference or generated
artifacts in the proposed change.
