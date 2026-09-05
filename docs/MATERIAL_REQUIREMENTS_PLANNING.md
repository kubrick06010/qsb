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

## Solver Character

The explosion and inventory balances are deterministic. LFL and EOQ use their
stated formulas; LUC, LTC, and PPB use classical forward heuristics and the
solution is therefore marked `heuristic`. Finite-capacity excess is reported by
bucket but is not automatically rescheduled or leveled. A future finite-capacity
or external backend can reuse the normalized model without changing the legacy
parser.
