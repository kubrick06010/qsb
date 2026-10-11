# Acceptance Sampling

QSB supports both preserved WinQSB binomial acceptance-sampling fixtures:

- `ASA1.AS_`: single sampling with `n = 89`, `c = 2`;
- `ASA2.AS_`: double sampling with `n1 = 40`, `c1 = 1`, `r1 = 5`,
  `n2 = 80`, and cumulative `c2 = 5`.

For double sampling, `n2` is the additional second sample. First-sample defects
at or below `c1` accept the lot, defects at or above `r1` reject it, and values
between those limits continue. After the second sample, the combined defect
count is compared with `c2`.

## Evaluation

The native backend evaluates exact binomial probabilities and publishes:

- a 101-point operating-characteristic curve from 0% to 100% defective;
- actual producer risk at AQL, `1 - P(accept | AQL)`;
- actual consumer risk at RQL, `P(accept | RQL)`;
- average sample number (ASN);
- average total inspection (ATI) under rectifying inspection;
- average outgoing quality (AOQ).

Nominal alpha and beta from the source are preserved separately from the actual
risks produced by the supplied plan. A separate `design-acceptance` command
finds the smallest single-sampling plan meeting requested binomial risk bounds;
the core also exposes exact finite-lot hypergeometric acceptance probability.
The fixture solver does not optimize expected cost or design double-sampling
plans. The preserved fixtures leave inspection-misclassification fields blank;
nonzero inspection errors are not yet modeled.

## CLI and JSON

```sh
qsb solve-acceptance reference/winqsb/ASA1.AS_ --backend native
qsb validate-acceptance reference/winqsb/ASA2.AS_
qsb export-acceptance-json reference/winqsb/ASA2.AS_ > sampling.json
qsb solve-acceptance-json sampling.json --backend native
qsb solve-acceptance-json sampling.json --backend validate
qsb validate-acceptance-json sampling.json
qsb design-acceptance 500 0.01 0.08 0.05 0.10
```

`AcceptanceSamplingBackend` exposes native educational and validation-only
modes. Its external slot can later support standards-driven plan design and
larger finite-lot calculations.

## macOS Workbench

The Definition workspace provides a native typed form for both single and
double plans. Changing the plan type exposes the corresponding decision
limits while retaining shared AQL, RQL, risk, lot, and economic inputs.
Edits support macOS undo/redo, validation remains in `QSBCore`, and normalized
JSON is an explicit advanced interchange and repair surface.

The solution workspace provides a native operating-characteristic view with
AQL and RQL markers, actual and nominal risk summaries, ASN/ATI/AOQ measures,
plan economics, accessible chart points, backend context, and the normalized
JSON fallback. The same presentation accepts both single and double sampling
solution documents.


## Interactive background execution

Native UI Run captures typed core input and executes backend validation, solving,
and normalized output outside the main thread. Pending progress disables duplicate
runs. Draft/model/backend changes, validation, and newer runs prevent stale success
or errors from replacing current state. Incomplete native fields and invalid core
input lead to Validation; current worker failures remain explicit. The workspace
retains invalid strings and dormant variant fields in its comparison of captured
and current input. Superseded workers finish in the background; no cancellation
control is currently provided. Core/CLI contracts and solver behavior are unchanged.
Static pending renders cover compact and wide windows; actual editor keyboard,
focus, and VoiceOver verification remains open.

External solving remains unavailable; the UI directs users to QSB Native or
Validate only.
