# Material Requirements Planning

QSBCore supports the preserved `reference/winqsb/QSB.MR_` fixture as a typed,
multi-level MRP model. The parser covers:

- Item Master fields, lead times, costs, lot rules, safety stock, and on-hand inventory;
- bill-of-material parent/component relationships and usage quantities;
- master production schedule demand;
- overdue and twelve named weekly buckets;
- overdue and period scheduled receipts;
- finite or unlimited item capacity.

MPS, Inventory, and Capacity rows must have nonempty, unique item identifiers
within each section. Duplicate rows are rejected with an error identifying the
item and section. BOM components accept an item identifier alone (usage one) or
`identifier/quantity`, with a nonempty identifier and a finite, positive quantity.
Malformed components and duplicate rows return parser errors rather than
terminating the importing process.

The native backend processes parents before components and adds each parent's
planned order releases to component gross requirements. It supports the five
rules present in the fixture: lot-for-lot (LFL), economic order quantity (EOQ),
least unit cost (LUC), least total cost (LTC), and part-period balancing (PPB).

## CLI

```text
qsb solve-mrp <legacy-mrp-file> [--backend native|validate]
qsb validate-mrp <legacy-mrp-file>
qsb export-mrp-json <legacy-mrp-file>
qsb solve-mrp-json <mrp-model-json-file> [--backend native|validate]
qsb validate-mrp-json <mrp-model-json-file>
```

Solution documents contain chart/table-ready arrays for gross and net
requirements, scheduled receipts, projected on-hand inventory, planned order
receipts and releases, and capacity excess.

## macOS Workbench

Interactive Run captures the typed plan and computes core validation, solution,
and normalized output outside the main thread. Progress is visible while solving;
duplicate runs are rejected. Draft edits, replacement models, validation, changed
backend/JSON, or a newer run prevent stale results and errors from replacing
current state. Incomplete native fields lead to Validation, and semantic invalidity
is reported by the core worker. Superseded calculations finish in the background;
no cancellation control is currently provided. Live keyboard and VoiceOver
verification remains open, as recorded in the UI workbench audit.

MRP external solving remains unavailable; the UI directs users to QSB Native or
Validate only.

The definition workspace provides a native editor organized into Item Master,
Schedules, and Bill of Materials sections. Item identity, policy, demand,
inventory, and cost fields are edited one item at a time so large models remain
usable at compact window sizes. Time buckets are dimension-safe: adding or
removing a bucket updates scheduled receipts, capacity, and any master
production schedule for every item. Renaming an item updates BOM references,
and edits participate in macOS undo/redo with focus restored to newly created
items, buckets, and component rows.

Each section has an atomic spreadsheet path. Item Master and BOM use named
tables, while Schedules uses one long-form row per item and bucket with
scheduled receipt, optional capacity, and optional MPS values. `Copy Table` and
`Paste Table` exchange TSV/CSV ranges with Excel, Numbers, and LibreOffice; a
range is checked completely before it replaces the draft. Structural and
numeric conversion stays in the typed app draft, while item references, BOM
cycles, schedule dimensions, and planning semantics remain in `QSBCore`.

### Schedule navigation and independent repair

Plans with more than 12 time buckets show groups of at most 12 periods for the
selected item. The period selector and Previous/Next Periods controls expose
every group; Copy/Paste Table still transfers all items and periods. Adding a
bucket selects its group and creates an unused name. Removing a bucket requests
focus on a nearby period, and removing an item selects a nearby item. Empty BOMs
explain how to add or paste relationships. Focus routes remain subject to live
keyboard and VoiceOver verification.

Each pasted section validates its own schema and numeric fields atomically.
An unfinished title, item property, or another section no longer prevents repair
of a valid item master, schedule, or BOM table. Existing unique item identifiers
and matching BOM relationships retain their row identities. Duplicate item
identifiers are rejected before replacing the item master; schedule paste requires
unique, nonempty item and bucket labels. Compound keys preserve names containing
separator characters without aliasing another item/period pair. Semantic BOM
references and planning rules still pass through core validation.

Short imported schedule arrays can be copied and edited without indexing traps;
missing cells in named buckets are exported blank and remain invalid until
required receipts are repaired. Optional blank capacity keeps its unbounded
meaning. A mixed MPS range retains the existing convention of filling blank MPS
cells with zero, while an entirely blank MPS range disables that item's MPS.
Compact/wide fixtures cover 35 periods and the final partial group. This
checkpoint does not complete live accessibility auditing.

### Imported dimensions and orphan MPS repair

The native draft retains the largest period extent across bucket names,
scheduled receipts, capacity, and every MPS vector. Short arrays are padded for
editing; extra values remain visible in additional periods with empty names.
Missing required receipts and MPS quantities stay empty and fail conversion
until repaired. Blank capacity displays its unbounded meaning. An explicit
Use Displayed Dimensions action accepts the displayed shape and optional
capacity defaults; it does not fill missing required values or names.

MPS keys without an item are preserved as additional incomplete native items,
ordered by identifier. Their required metadata and receipts remain blank;
the lot-sizing rule initially displays LFL for review. Users can provide the
missing item data, rename the item, or explicitly remove it in the native editor.
This preserves orphan quantities without silently inventing a complete item.
Spreadsheet repairs retain these items' identities and full MPS values.

Dimension acceptance participates in workspace undo/redo. Regression tests cover
retained extra cells, required-value repair, orphan-item reconstruction, JSON
round trips, and JSON Apply/validation/undo. Compact/wide fixtures include the
review banner, incomplete schedules, and an orphan item. Live keyboard and
VoiceOver verification remain required.

The solution workspace provides an item-selectable native schedule view. It
shows gross requirements and projected inventory, planned receipt/release
timing, every time-phased schedule row, capacity excess, item planning
parameters, and the normalized bill of materials. Chart marks and table rows
carry accessibility values, wide schedules scroll horizontally, and normalized
solution JSON remains available beside the native presentation.

## Solver Character

The explosion and inventory balances are deterministic. LFL and EOQ use their
stated formulas; LUC, LTC, and PPB use classical forward heuristics and the
solution is therefore marked `heuristic`. Finite-capacity excess is reported by
bucket but is not automatically rescheduled or leveled. A future finite-capacity
or external backend can reuse the normalized model without changing the legacy
parser.


## Row focus after edits

Identity changes repair focused rows to a surviving or nearest remaining target.
Simulation routes/service rules and MRP BOM use their Add action when no rows
remain. MRP repairs removed item and schedule-bucket targets and reveals the
bucket's column group. Runtime keyboard/VoiceOver behavior remains unverified.
