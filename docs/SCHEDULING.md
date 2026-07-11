# Scheduling

The scheduling module supports legacy WinQSB flow-shop and job-shop fixtures.

Supported input:

- Legacy WinQSB `SCH ... -1` flow-shop files.
- Legacy WinQSB `SCH ... 0` job-shop files.
- Compressed `SZDD` fixtures such as `reference/winqsb/FLOWSHOP.JO_`.
- Compressed `SZDD` fixtures such as `reference/winqsb/JOBSHOP.JO_`.
- Jobs with ordered operations encoded as `duration/machine`.
- Machine rows used by each operation.

The flow-shop solver enumerates all job permutations for small flow-shop
instances and chooses the schedule with the minimum makespan. The job-shop
solver uses exact fixture-scale branch and bound over left-shifted operation
dispatch decisions, with dominance pruning for matching progress states.
Both current solvers run behind the shared `SchedulingBackend` seam as
`nativeEducational` backends intended for bundled fixture-scale examples. The
`validateOnly` backend parses the legacy fixture and checks machine IDs, job
IDs, routing, operation counts, and processing times without solving.

Run:

```sh
qsb solve-flowshop reference/winqsb/FLOWSHOP.JO_ --backend native
qsb solve-flowshop-json reference/winqsb/FLOWSHOP.JO_ --backend native
qsb solve-jobshop reference/winqsb/JOBSHOP.JO_ --backend native
qsb solve-jobshop-json reference/winqsb/JOBSHOP.JO_ --backend native
qsb validate-flowshop reference/winqsb/FLOWSHOP.JO_
qsb validate-jobshop reference/winqsb/JOBSHOP.JO_
```

Example output:

```text
QS P.602
backend: nativeEducational
timeUnit: minute
makespan: 213
sequence: Job 4 -> Job 2 -> Job 5 -> Job 1 -> Job 3
machineCompletionTimes: 119, 179, 206, 213
Job 4: M1 0-13, M2 13-35, M3 35-49, M4 49-62, complete 62
...
Job 3: M1 96-119, M2 137-179, M3 179-206, M4 207-213, complete 213
```

Job-shop example output:

```text
QS P.616
backend: nativeEducational
timeUnit: minute
makespan: 34
machineCompletionTimes: 27, 33, 30, 34, 32
dispatchOrder:
Job 1 op 1: M3 0-2
...
Job 5: op 1 M5 0-5, op 2 M3 14-21, op 3 M1 21-24, op 4 M2 24-30, op 5 M4 30-34, complete 34
```

Validation example output:

```text
QS P.616
backend: validateOnly
source: reference/winqsb/JOBSHOP.JO_
modelType: jobShop
status: valid
jobs: 5
machines: 5
errors: 0
warnings: 0
info: scheduling.jobShop.valid - Job shop model is valid
```

Scheduling solution JSON is intended for future Gantt-style GUI views and
automation. `qsb solve-flowshop-json` and `qsb solve-jobshop-json` emit a
`SchedulingSolutionDocument` with:

- `kind`: `flowShop` or `jobShop`.
- `backend`: backend kind, algorithm, exactness, and notes.
- `makespan`, `jobSequence`, and `machineCompletionTimes`.
- `operations`: flat operation records with job, operation index, machine,
  start, finish, duration, idle-before, and sequence index.
- `machineTimelines`: per-machine Gantt lanes with ready time, completion time,
  and operations.
