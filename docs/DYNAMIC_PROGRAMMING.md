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

The view does not recompute policies or parse trace strings. It renders the
typed result and trace supplied by `QSBCore`, keeps exactness and assumptions
visible, and retains the normalized solution through the Stages/JSON selector.
