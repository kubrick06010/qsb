# Dynamic Programming

The first dynamic programming modules support legacy WinQSB bounded knapsack,
stagecoach shortest-route, and production/inventory planning files.

All three variants share `DynamicProgrammingModelEnvelope`, structured
validators, and the `DynamicProgrammingBackend` seam. The available backend
modes are `nativeEducational` and `validateOnly`; `externalHighPerformance` is
reserved and currently unavailable.

Common workflows:

```sh
qsb solve-knapsack reference/winqsb/KNAPSACK.DP_ --backend native
qsb validate-stagecoach reference/winqsb/STAGE.DP_
qsb export-dp-json reference/winqsb/PRODINVT.DP_ > model.json
qsb solve-dp-json model.json --backend native
qsb validate-dp-json model.json
```

Normalized solution documents include backend algorithm/exactness metadata,
model assumptions, the typed result, and a policy trace. Every trace row names
a stage, state, action, optional next state, and local value.

Supported input:

- Legacy WinQSB `DP ... KS ...` knapsack files.
- Compressed `SZDD` fixtures such as `reference/winqsb/KNAPSACK.DP_`.
- Integer item availability, integer capacity requirements, and linear return
  functions such as `8a`.

The solver uses bounded dynamic programming and returns the best total return,
capacity used, and selected item quantities.

Run:

```sh
qsb solve-knapsack reference/winqsb/KNAPSACK.DP_ [--backend native|validate]
```

Example output:

```text
QSB P.112
capacity: 20
totalReturn: 31
capacityUsed: 20
B: 2, capacity 12, return 20
C: 1, capacity 3, return 4
D: 1, capacity 5, return 7
```

## Stagecoach

Supported input:

- Legacy WinQSB `DP ... SC ...` stagecoach files.
- Compressed `SZDD` fixtures such as `reference/winqsb/STAGE.DP_`.
- Directed acyclic cost matrices from source node to sink node.

The solver uses dynamic programming over the node order and returns the minimum
cost route.

Run:

```sh
qsb solve-stagecoach reference/winqsb/STAGE.DP_ [--backend native|validate]
```

Example output:

```text
QSB 119
source: Node1
sink: Node10
totalCost: 19
path: Node1 -> Node3 -> Node5 -> Node8 -> Node10
```

## Production/Inventory

Supported input:

- Legacy WinQSB `DP ... PIS ...` production/inventory files.
- Compressed `SZDD` fixtures such as `reference/winqsb/PRODINVT.DP_`.
- Integer period demand, production capacity, storage capacity, setup cost, and
  linear production/holding cost functions such as `300P+100H`.

The solver uses backward dynamic programming over inventory states and returns
the minimum-cost production plan.

Run:

```sh
qsb solve-prod-inventory reference/winqsb/PRODINVT.DP_ [--backend native|validate]
```

Example output:

```text
QSB P.116
totalCost: 7080
January: begin 0, produce 5, demand 4, end 1, cost 2100
February: begin 1, produce 4, demand 5, end 0, cost 1730
March: begin 0, produce 3, demand 3, end 0, cost 1250
April: begin 0, produce 4, demand 4, end 0, cost 2000
```

## macOS Workbench

`QSBMacApp` decodes the same `DynamicProgrammingSolutionDocument` emitted by
the backend and presents each supported result natively:

- bounded knapsack selection return bars and quantity/capacity table;
- Stagecoach route sequence and local arc-cost chart;
- production/inventory demand, production, ending-inventory series, and period
  table;
- the common policy trace with stage, state, action, next state, and local
  value for every variant.

Bounded Knapsack also has a native definition editor. Capacity and item limits,
resource use, and return values are edited as typed fields, while the complete
item table can be copied to or pasted from Excel, Numbers, LibreOffice, TSV,
or CSV. Table repair works while the title or capacity remains incomplete.
Complete-header matching accepts a headerless item named `Item`; unambiguous
matching names retain row identities across reorder, and duplicate names remain
core validation errors with distinct row identities. Required names, integer
quantities/capacities, and finite returns are checked atomically for the pasted
range. Paste retains a surviving focus target; removal targets a neighbor and
undo/replacement repairs orphaned name-field focus. Live focus timing remains
unverified. Validation remains in `QSBCore`, undo/redo preserves
the typed draft, and normalized JSON remains available as the advanced
interchange and repair surface.

Bounded Knapsack interactive Run captures the typed request and executes core
validation, solving, and normalized output outside the main thread. Pending
progress disables duplicate runs. Draft/model/backend changes, validation, and
newer runs prevent stale results or errors from replacing current state.
Incomplete native fields and invalid core bounds lead to Validation; current
worker failures remain explicit. External solving is unavailable, with guidance
to use QSB Native or Validate only. Superseded workers finish in the background;
no cancellation control is currently provided. Other dynamic-programming variants
retain their existing synchronous UI path.

The view does not recompute policies or parse trace strings. It renders the
typed result and trace supplied by `QSBCore`, keeps exactness and assumptions
visible, and retains the normalized solution through the Stages/JSON selector.


## Native result accessibility

The Knapsack result exposes named summary metrics and selected-item rows with
quantity, capacity use and return. Policy trace rows expose stage, state, action,
next state and value as related accessible content. The chart retains named marks
and the table provides the text alternative. Compact/wide result renders are
covered; live VoiceOver and keyboard verification remains pending.
