# Network Models

The first network module is shortest path (`SPP`) support for legacy WinQSB
network matrix files. Minimum spanning tree (`MST`) support uses the same matrix
parser and treats costs as undirected edges.

All supported network models can also be exported to normalized JSON with
`qsb export-network-json <legacy-network-file>` and solved from JSON with
`qsb solve-network-json <network-model-json-file> --backend native`. A shared
`NetworkBackend` provides native educational and validation-only workflows for
all seven variants; `validate-network-json` validates without solving.

Structured solution documents retain the normalized model and solution plus
backend algorithm, exactness, and assumptions. Algorithms are Dijkstra,
Kruskal, Edmonds-Karp, fixture-scale exact Held-Karp dynamic programming,
rectangular Hungarian matching, and continuous LP-backed minimum-cost flow and
transportation.

## Minimum-Cost Network Flow

Legacy `NET ... CNF ...` transshipment files are parsed into nodes, directed
cost arcs, and separate supply/demand values for every node. The native backend
formulates flow conservation as a continuous LP through the shared
`LinearProgrammingBackend`.

WinQSB's preserved `NETFLOW.NE_` example has 100 more units of demand than
supply. The normalized model preserves those original values; validation emits
`network.CNF.balance.automatic`, and solving adds an explicit zero-cost dummy
supply adjustment recorded in solution JSON. This reproduces the manual's
reference objective of 7900.

```sh
qsb solve-netflow reference/winqsb/NETFLOW.NE_ --backend native
qsb validate-netflow reference/winqsb/NETFLOW.NE_
```

## Shortest Path

Supported input:

- Legacy WinQSB `NET ... SPP ... Matrix ...` files.
- Compressed `SZDD` fixtures such as `reference/winqsb/SHTPATH.NE_`.
- Directed nonnegative arc costs from the WinQSB adjacency matrix.

Current convention:

- Source defaults to the first node in the file.
- Sink defaults to the last node in the file.

Run:

```sh
qsb solve-spp reference/winqsb/SHTPATH.NE_
qsb validate-spp reference/winqsb/SHTPATH.NE_
```

Example output:

```text
SPP
source: Node1
sink: Node10
totalCost: 29
path: Node1 -> Node2 -> Node5 -> Node9 -> Node10
```

## Minimum Spanning Tree

Supported input:

- Legacy WinQSB `NET ... MST ... Matrix` or `Graphic` files with matrix rows.
- Compressed `SZDD` fixtures such as `reference/winqsb/SPANTREE.NE_`.
- Nonnegative edge costs. Directed/asymmetric matrix entries are folded into
  undirected edges using the lowest cost for each node pair.

Run:

```sh
qsb solve-mst reference/winqsb/SPANTREE.NE_
qsb validate-mst reference/winqsb/SPANTREE.NE_
```

Example output:

```text
MST
totalCost: 68
Node1 -- Node2: 2
Node1 -- Node4: 6
Node2 -- Node5: 7
Node4 -- Node6: 7
Node7 -- Node8: 8
Node1 -- Node3: 9
Node4 -- Node7: 9
Node9 -- Node10: 9
Node5 -- Node9: 11
```

## Max Flow

Supported input:

- Legacy WinQSB `NET ... MFP ... Matrix` files.
- Compressed `SZDD` fixtures such as `reference/winqsb/MAXFLOW.NE_`.
- Directed nonnegative capacities from the WinQSB adjacency matrix.

Current convention:

- Source defaults to the first node in the file.
- Sink defaults to the last node in the file.

Run:

```sh
qsb solve-maxflow reference/winqsb/MAXFLOW.NE_
qsb validate-maxflow reference/winqsb/MAXFLOW.NE_
```

Example output:

```text
MFP
source: Node1
sink: Node7
maxFlow: 30
```

## Traveling Salesperson

Supported input:

- Legacy WinQSB `NET ... TSP ... Matrix` or `Graphic` files with matrix rows.
- Compressed `SZDD` fixtures such as `reference/winqsb/TSP.NE_`.
- Directed or asymmetric nonnegative arc costs. Blank matrix cells are treated
  as missing arcs.

The current solver uses an exact dynamic-programming Hamiltonian-cycle search,
starting and ending at the first node in the file by default.

Run:

```sh
qsb solve-tsp reference/winqsb/TSP.NE_
qsb validate-tsp reference/winqsb/TSP.NE_
```

Example output:

```text
TSP
source: LA
totalCost: 1130
tour: LA -> HOU -> NY -> CMH -> DAL -> DEV -> LA
```

## Assignment

Supported input:

- Legacy WinQSB `NET ... AP ... Matrix` files.
- Compressed `SZDD` fixtures such as `reference/winqsb/ASSIMENT.NE_`.
- Rectangular cost matrices with at least as many tasks as workers.

The solver uses a Hungarian-style minimum-cost matching algorithm for rectangular
models with at least as many tasks as workers.

Run:

```sh
qsb solve-assignment reference/winqsb/ASSIMENT.NE_
qsb validate-assignment reference/winqsb/ASSIMENT.NE_
```

Example output:

```text
AP
totalCost: 20
John -> B: 6
Peter -> C: 3
Toshi -> A: 2
Rudy -> D: 9
```

## Transportation

Supported input:

- Legacy WinQSB `NET ... TP ... Matrix` files.
- Compressed `SZDD` fixtures such as `reference/winqsb/TRNSPORT.NE_`.
- Balanced transportation models where total supply equals total demand.

The native educational backend formulates the transportation problem as a
continuous LP and solves it through the shared `LinearProgrammingBackend` seam.
The validation backend checks dimensions, finite nonnegative values, unique
labels, and total supply-demand balance without solving.

Run:

```sh
qsb solve-transport reference/winqsb/TRNSPORT.NE_ --backend native
qsb validate-transport reference/winqsb/TRNSPORT.NE_
```

Native example output:

```text
TP
backend: nativeEducational
totalCost: 3350
Boston -> Tampa: 50 @ 5
Boston -> Miami: 50 @ 6
Denver -> Miami: 200 @ 6
Austin -> Dallas: 200 @ 2
Austin -> Kansas: 100 @ 5
Austin -> Tampa: 100 @ 7
```

Validation example output:

```text
TP
backend: validateOnly
modelType: transportation
status: valid
origins: 3
destinations: 4
totalSupply: 700
totalDemand: 700
```

The macOS workbench uses the same backend and decodes the same structured
`NetworkSolutionDocument` emitted by CLI workflows. All seven variants open in
a native Diagram/JSON solution surface:

- shortest path, spanning tree, maximum flow, TSP, and minimum-cost flow use a
  deterministic circular network layout;
- assignment and transportation use bipartite layouts with collision-safe
  internal node identifiers;
- active route, tree, tour, flow, assignment, or shipment connections are
  highlighted, while the complete model can be revealed with the
  `All connections` control;
- the detail pane preserves exact costs, capacities, quantities, and dummy
  balance adjustments from the typed solution document.

Diagram scaling and compact/wide scrolling are presentation concerns only.
Parsing, validation, and solving remain in QSBCore behind `NetworkBackend`, and
normalized JSON remains the universal fallback. Future network modules should
keep using separate model and solver types behind this family-level seam.
