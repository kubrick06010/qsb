# Simulation

QSBCore supports all four preserved WinQSB simulation fixtures:

- `reference/winqsb/QSS1.QS_`: two exponential-service servers;
- `reference/winqsb/QSS2.QS_`: two constant-service servers;
- `reference/winqsb/QSS3.QS_`: matrix-format assembly network;
- `reference/winqsb/QSSGRAPH.QS_`: graphic-format form of the assembly network.

The clean-room parser normalizes Matrix and Graphic payloads into one component
network. Components represent customer/entity sources, queues, servers, and
gates; routes preserve optional probabilities and transfer times. Supported
distributions are constant, exponential, normal, uniform, and triangular.

## CLI And JSON

```bash
qsb solve-simulation reference/winqsb/QSS1.QS_ --backend native
qsb validate-simulation reference/winqsb/QSSGRAPH.QS_
qsb export-simulation-json reference/winqsb/QSS3.QS_
qsb solve-simulation-json model.json --backend native
qsb validate-simulation-json model.json
```

Normalized model JSON records the original representation, time unit,
components, routes, queue rules and capacities, arrival and batch
distributions, and entity-specific service rules. Solution documents contain
backend metadata, horizon and seed, generated/completed totals, queue lengths
and rejections, and server completion/utilization metrics.

## Solver Character

`nativeEducational` is a fixture-scale, seeded discrete-event simulator. It
models finite FIFO queues, alternate servers, probabilistic routing, transfer
times, typed entities, and assembly synchronization. The default run is one
1,000-time-unit replication with seed 1, making CLI and regression results
deterministic.

Results are stochastic estimates, not exact queueing solutions. The native
backend currently reports no warm-up deletion, replications, or confidence
intervals. `validateOnly` checks network structure without running it, while
`externalHighPerformance` remains an explicit future integration point.
