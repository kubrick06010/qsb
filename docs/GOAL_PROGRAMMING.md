# Goal Programming

QSB supports all three preserved WinQSB goal-programming fixtures:

- `GP.GP_`: continuous matrix format;
- `GPNORMAL.GP_`: the equivalent continuous normal-model format;
- `IGP.GP_`: integer matrix format with explicit deviation variables.

The parser reuses the established WinQSB LP parser for every priority row and
requires all resulting views to share variables, constraints, bounds, and
domains. Blank matrix coefficients normalize to zero. This keeps algebraic
parsing consistent between LP and Goal Programming.

## Lexicographic semantics

Goals are preemptive and ordered as stored in the file. The native backend:

1. optimizes the first goal;
2. adds an equality fixing that optimum;
3. optimizes the next goal;
4. repeats until all priorities are fixed.

It does not replace priorities with arbitrary weighted sums. Mixed minimize and
maximize goals are supported.

For the continuous sample, both source formats produce:

```text
G1 = 114
G2 = 574
A = 16, B = 14, C = 36
```

The integer fixture produces `G1 = 0`, `G2 = 295`, `X1 = 4`, and `X2 = 3`.

## Integer presolve

The integer educational path is characterized as `fixtureScale`. It accepts an
integral LP relaxation immediately and derives finite bounds before invoking
the shared branch-and-bound backend for fractional priorities. Paired `nN/pN`
deviation variables are relaxed only when integral equality coefficients and
right-hand sides prove their residuals integral; decision variables retain
their source integral domains.

## CLI and JSON

```sh
qsb solve-goal reference/winqsb/GP.GP_ --backend native
qsb validate-goal reference/winqsb/IGP.GP_
qsb export-goal-json reference/winqsb/GPNORMAL.GP_ > goal.json
qsb solve-goal-json goal.json --backend native
qsb solve-goal-json goal.json --backend validate
qsb validate-goal-json goal.json
```

`GoalProgrammingBackend` exposes native educational and validation-only modes.
The external slot is reserved for future high-performance LP/MIP adapters.
