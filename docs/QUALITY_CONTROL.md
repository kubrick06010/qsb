# Quality Control

QSBCore supports all five preserved WinQSB Quality Control fixtures:

- `C_CHART.QC_`: three-sigma c chart for defect counts;
- `P_CHART.QC_`: three-sigma p chart with per-subgroup sample sizes;
- `VARIABLE.QC_`: Xbar-R charts using standard constants for subgroup sizes 2 through 10;
- `PARETO.QC_`: descending defect-category totals and cumulative percentages;
- `PROBPLOT.QC_`: Blom normal scores with least-squares fit and correlation.

The native backend is deterministic and educational. The c, p, Xbar-R, and
Pareto calculations are exact implementations of their stated formulas. The
normal probability plot is marked approximate because it uses an inverse-normal
approximation and a plotting-position convention.

## CLI

```text
qsb solve-quality <legacy-qc-file> [--backend native|validate]
qsb validate-quality <legacy-qc-file>
qsb export-quality-json <legacy-qc-file>
qsb solve-quality-json <quality-control-model-json-file> [--backend native|validate]
qsb validate-quality-json <quality-control-model-json-file>
```

The normalized format uses tagged model and solution envelopes with kinds
`cChart`, `pChart`, `xbarRChart`, `pareto`, and `normalProbabilityPlot`.
Solution documents include backend metadata and chart-ready point arrays.

## Current Limits

The backend reports points outside three-sigma control limits. Western Electric
run-rule configuration and legacy cause/action/comment metadata are not yet
evaluated or represented in normalized models. The parser reads the original
fixtures without modifying files under `reference/winqsb`.
