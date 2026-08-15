# Decision Analysis

The decision analysis module supports legacy WinQSB payoff tables with prior
probabilities and indicator likelihoods. It also supports standalone Bayesian
posterior analysis, decision trees, and legacy zero-sum game payoff matrices.

Supported input:

- Legacy WinQSB `DA ... PT ...` payoff table files.
- Compressed `SZDD` fixtures such as `reference/winqsb/PAYOFF.DA_`.
- Prior probabilities by state.
- Indicator likelihoods by state.
- Decision payoff rows by state.

The solver computes expected value by decision under the prior distribution,
Bayesian posterior probabilities for each indicator, the best decision by
indicator, expected value with sample information, expected value of sample
information, expected value with perfect information, and EVPI.

Run:

```sh
qsb solve-payoff reference/winqsb/PAYOFF.DA_
qsb validate-payoff reference/winqsb/PAYOFF.DA_
```

Example output:

```text
QSB P.277
bestPriorDecision: Pricing
bestPriorExpectedValue: 56300
expectedValueWithSampleInformation: 57170
expectedValueOfSampleInformation: 870
expectedValueWithPerfectInformation: 59500
expectedValueOfPerfectInformation: 3200
Favorable: probability 0.330000, best Advertise, value 65454.545455
```

## Bayesian Analysis

Supported input:

- Legacy WinQSB `DA ... BA ...` Bayesian analysis files.
- Compressed `SZDD` fixtures such as `reference/winqsb/BAYESIAN.DA_`.
- Prior probabilities by state.
- Outcome likelihoods by state.

The solver computes each outcome probability and posterior state probabilities.

Run:

```sh
qsb solve-bayesian reference/winqsb/BAYESIAN.DA_
qsb validate-bayesian reference/winqsb/BAYESIAN.DA_
```

Example output:

```text
QSB P.272
Favorable: probability 0.330000
  High: 0.363636
  Medium: 0.454545
  Low: 0.181818
```

## Decision Trees

Supported input:

- Legacy WinQSB `DA ... DT ...` decision tree files.
- Compressed `SZDD` fixtures such as `reference/winqsb/DTREE.DA_`.
- Decision nodes, chance nodes, terminal payoffs, and probabilities stored on
  child rows.

The solver performs rollback analysis. Decision nodes choose the child with the
largest expected value; chance nodes compute expected value from outgoing
probabilities. Because bundled legacy probabilities are sometimes rounded and
sum to `0.99`, chance-node probabilities are normalized before computing each
expected value.

Run:

```sh
qsb solve-decision-tree reference/winqsb/DTREE.DA_
qsb validate-decision-tree reference/winqsb/DTREE.DA_
```

Example output:

```text
QSB P.283
root: 1
expectedValue: 57213.215998
Favorable: choose Advertise, value 65454.545455
Unfavorable: choose Pricing, value 51252.525253
Neutral: choose Pricing, value 55170
```

## Zero-Sum Games

Supported input:

- Legacy WinQSB `DA ... ZS ...` zero-sum game files.
- Compressed `SZDD` fixtures such as `reference/winqsb/GAME.DA_`.
- A payoff matrix for player 1, with player 2 minimizing that payoff.

The native educational backend formulates the row and column player
mixed-strategy problems as LPs and solves them through the shared
`LinearProgrammingBackend` seam. The validation backend checks strategy names,
payoff matrix dimensions, and finite payoff values without solving.

Run:

```sh
qsb solve-game reference/winqsb/GAME.DA_ --backend native
qsb validate-game reference/winqsb/GAME.DA_
```

Native example output:

```text
Marketing Game
backend: nativeEducational
value: 10.265525
rowStrategy:
Strategy1-1: 0
Strategy1-2: 0.173825
Strategy1-3: 0
Strategy1-4: 0.389147
Strategy1-5: 0.437028
columnStrategy:
Strategy2-1: 0.515670
Strategy2-2: 0.342716
Strategy2-3: 0
Strategy2-4: 0.141613
```

Validation example output:

```text
Marketing Game
backend: validateOnly
modelType: zeroSumGame
status: valid
rowStrategies: 5
columnStrategies: 4
```

## Normalized JSON and Backends

All four variants share a discriminated `DecisionAnalysisModelEnvelope` with
`kind` values `payoff`, `bayesian`, `decisionTree`, and `zeroSumGame`.
`DecisionAnalysisSolutionDocument` retains the original model, a typed solution,
and backend algorithm/exactness metadata. Validation output contains the kind,
backend, validity flag, and structured diagnostics.

```sh
qsb export-decision-json reference/winqsb/DTREE.DA_ > decision.json
qsb solve-decision-json decision.json --backend native > solution.json
qsb solve-decision-json decision.json --backend validate > validation.json
qsb validate-decision-json decision.json
```

The native backend uses expected-value/information analysis, Bayes' rule,
decision-tree rollback, or LP-backed mixed strategies as appropriate. Rounded
legacy chance probabilities that have a positive sum other than one produce a
warning and are normalized consistently with the rollback solver.

The macOS workbench imports the same normalized envelopes, detects all four
variants, validates or solves through the selected backend, and emits these same
solution and validation documents. Its Samples menu includes compact Payoff
Analysis and Decision Tree models for exercising EVSI/EVPI and rollback/policy
workflows.

Decision-tree solution documents open in a native inspection view that shows the
rollback value at every node, the recommended policy at decision nodes, chance
probabilities, terminal payoffs, backend exactness metadata, and the original
normalized JSON as a fallback presentation.
