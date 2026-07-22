# Aggregate Planning

QSBCore supports all three preserved WinQSB Aggregate Planning fixtures:

- `APLP.AP_`: workforce and capacity planning using the legacy LP method;
- `APSIMPLE.AP_`: workforce and capacity planning using the legacy simple method;
- `APTRP.AP_`: fixed-capacity planning using the legacy transportation method.

The parser normalizes the three tabular payloads into one period-based model.
The native educational backend builds a continuous linear program with demand,
inventory/backorder, regular time, overtime, subcontracting, and optional
workforce/hiring/dismissal balances. It delegates that program through the
shared `LinearProgrammingBackend` seam.

## CLI

```text
qsb solve-aggregate <legacy-ap-file> [--backend native|validate]
qsb validate-aggregate <legacy-ap-file>
qsb export-aggregate-json <legacy-ap-file>
qsb solve-aggregate-json <aggregate-planning-model-json-file> [--backend native|validate]
qsb validate-aggregate-json <aggregate-planning-model-json-file>
```

Solution JSON includes backend metadata, total cost, and period rows containing
workforce changes, production sources, ending inventory/backorder, and unused
regular capacity.

## Solver Character

The formulation and simplex result are exact for the normalized continuous LP.
Workforce and production quantities are continuous; integer workforce planning
is not implied. A future external LP/MIP backend can reuse the same model and
formulation without changing the legacy parser or JSON schema.
