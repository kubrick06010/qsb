# Network Models

The first network module is shortest path (`SPP`) support for legacy WinQSB
network matrix files. Minimum spanning tree (`MST`) support uses the same matrix
parser and treats costs as undirected edges.

All supported network models can also be exported to normalized JSON with
`qsb export-network-json <legacy-network-file>` and solved from JSON with
`qsb solve-network-json <network-model-json-file>`.

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

Future network modules should keep using separate model and solver types for
related WinQSB workflows.
