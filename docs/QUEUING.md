# Queuing

The queuing module supports legacy WinQSB M/M/1 queue files and a
finite-capacity multi-server queue fixture through the shared `QSBCore`
validation and backend architecture.

Supported input:

- Legacy WinQSB `QA ... 0` M/M/1 files.
- Compressed `SZDD` fixtures such as `reference/winqsb/QUEUE1.QA_`.
- One server, infinite queue capacity, and infinite customer population.
- Optional busy server, idle server, customer waiting, and customer service
  cost rates.

The solver computes utilization, probability the system is empty, average
number in system, average number in queue, average time in system, average time
in queue, and an optional cost breakdown.

Run:

```sh
qsb validate-mm1 reference/winqsb/QUEUE1.QA_
qsb solve-mm1 reference/winqsb/QUEUE1.QA_ --backend native
qsb solve-mm1 reference/winqsb/QUEUE1.QA_ --backend validate
qsb solve-mm1-json reference/winqsb/QUEUE1.QA_ --backend native
```

Omitting `--backend` preserves the original native text workflow. The
`validate` backend parses the fixture and emits structured diagnostics without
solving it. `externalHighPerformance` is reserved by the backend seam but is
not available yet.

Example output:

```text
Sample M/M/1 Problem
timeUnit: hour
utilization: 0.666667
averageNumberInSystem: 2
averageNumberInQueue: 1.333333
averageTimeInSystem: 1
averageTimeInQueue: 0.666667
cost.total: 300
```

## Finite-Capacity Queues

Supported input:

- Legacy WinQSB `QA ... 1` finite-capacity queue files.
- Compressed `SZDD` fixtures such as `reference/winqsb/QUEUE2.QA_`.
- Constant batch size of 1, no finite customer population, exponential
  interarrival time, mean service time, server count, and maximum waiting space.
- Optional busy server, idle server, customer waiting, customer service,
  balked-customer, and queue-capacity cost rates.

The solver uses a finite-capacity birth-death approximation with the mean
arrival and service rates. Customers arriving when the system is full are
counted as balked. For the bundled `QUEUE2.QA_` fixture, the service-time
distribution is labeled normal, so the solver uses its mean service time as the
per-server service-rate basis.

Run:

```sh
qsb validate-finite-queue reference/winqsb/QUEUE2.QA_
qsb solve-finite-queue reference/winqsb/QUEUE2.QA_ --backend native
qsb solve-finite-queue reference/winqsb/QUEUE2.QA_ --backend validate
qsb solve-finite-queue-json reference/winqsb/QUEUE2.QA_ --backend native
```

Example output:

```text
Queuing Sample Problem 2
timeUnit: hour
servers: 2
queueCapacity: 3
effectiveArrivalRate: 1.882245
probabilitySystemFull: 0.058878
averageNumberInSystem: 1.740570
averageNumberInQueue: 0.485741
averageTimeInSystem: 0.924731
cost.total: 339.093837
```

## Validation

`MM1QueueValidator` and `FiniteCapacityQueueValidator` return shared
`ValidationDiagnostic` values suitable for the CLI, tests, and future GUI
views. Current diagnostics cover:

- finite positive arrival/service timing inputs;
- M/M/1 steady-state stability (`arrivalRate < serviceRate`);
- positive server count and nonnegative waiting capacity;
- unit batch arrivals and exponential interarrival requirements for the native
  finite-capacity solver;
- finite, nonnegative cost inputs;
- warnings for saturated offered load and non-exponential service distributions
  handled through the mean-rate approximation.

## Backend and JSON Contract

`QueuingBackend` has named `NativeEducationalQueuingBackend` and
`ValidateOnlyQueuingBackend` implementations. The native M/M/1 algorithm is
reported as `mm1ClosedForm` with exactness `closedForm`. The finite-capacity
algorithm is reported as `finiteCapacityBirthDeath` with exactness
`approximate`.

Both JSON commands emit a `QueuingSolutionDocument` containing:

- problem `kind`, Kendall-style `notation`, assumptions, title, and time unit;
- backend kind, algorithm, exactness, and notes;
- a common metrics object with arrival/effective arrival rates, service rate,
  servers, optional system capacity, utilization, empty/blocking probabilities,
  L, Lq, customers being served, W, and Wq;
- state probabilities where the finite-state model provides them;
- a normalized optional cost breakdown.
