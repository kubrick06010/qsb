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
risks produced by the supplied plan. Economic inputs are also preserved, but
the current solver does not claim automatic plan design or expected-cost
optimization. The preserved fixtures leave inspection-misclassification fields
blank; nonzero inspection errors are not yet modeled.

## CLI and JSON

```sh
qsb solve-acceptance reference/winqsb/ASA1.AS_ --backend native
qsb validate-acceptance reference/winqsb/ASA2.AS_
qsb export-acceptance-json reference/winqsb/ASA2.AS_ > sampling.json
qsb solve-acceptance-json sampling.json --backend native
qsb solve-acceptance-json sampling.json --backend validate
qsb validate-acceptance-json sampling.json
```

`AcceptanceSamplingBackend` exposes native educational and validation-only
modes. Its external slot can later support standards-driven plan design or
larger hypergeometric calculations.
