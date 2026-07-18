# Markov Processes

QSB supports both preserved WinQSB finite-state Markov fixtures:

- `MKP1.MK_`, with an initial probability distribution;
- `MKP2.MK_`, without an initial distribution.

The parser follows WinQSB's row-vector convention:

```text
S(t + 1) = S(t) P
```

Blank transition cells are zero. State labels, the row-stochastic transition
matrix, optional initial probabilities, and state costs are preserved in a
portable `MarkovChainModel`.

## Analysis

The native educational backend solves the stationary equations
`pi P = pi`, replacing one dependent equation with `sum(pi) = 1`. It reports
the stationary probabilities and long-run expected state cost.

When the source model contains initial probabilities, the backend also performs
forward propagation for the requested number of periods and reports each
period's distribution and expected cost. The normalized request defaults to ten
periods. If the source omits initial probabilities, the transient result is
empty rather than assuming an arbitrary starting distribution.

The native linear-system method requires a unique stationary distribution and
reports an explicit error when that system is singular.

## Validation

Structured diagnostics cover:

- unique, nonempty state names;
- square matrix dimensions;
- finite probabilities in `[0, 1]`;
- transition rows summing to one;
- optional initial probabilities summing to one;
- state-cost dimensions and finite values;
- a nonnegative transient horizon.

## CLI

```sh
qsb solve-markov reference/winqsb/MKP1.MK_ --backend native
qsb validate-markov reference/winqsb/MKP2.MK_
qsb export-markov-json reference/winqsb/MKP1.MK_ > markov.json
qsb solve-markov-json markov.json --backend native
qsb solve-markov-json markov.json --backend validate
qsb validate-markov-json markov.json
```

`MarkovBackend` exposes `nativeEducational` and `validateOnly`; the
`externalHighPerformance` slot remains available for future sparse or large
state-space integrations.
