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

The optional `externalHighPerformance` backend uses a host-provided HiGHS
executable for that same normalized LP and reconstructs the typed period
solution. Discovery checks `QSB_HIGHS_PATH` and then `PATH`; the native backend
remains the default and planning quantities stay continuous.

Legacy row labels must be unique after trimming surrounding whitespace and
ignoring case. Duplicate labels return an explicit parser error, including when
their values agree. Period counts exceeding the supplied header are rejected
before allocating period vectors.

## CLI

```text
qsb solve-aggregate <legacy-ap-file> [--backend native|validate|external]
qsb validate-aggregate <legacy-ap-file>
qsb export-aggregate-json <legacy-ap-file>
qsb solve-aggregate-json <aggregate-planning-model-json-file> [--backend native|validate|external]
qsb validate-aggregate-json <aggregate-planning-model-json-file>
```

Solution JSON includes backend metadata, total cost, and period rows containing
workforce changes, production sources, ending inventory/backorder, and unused
regular capacity.

## Solver Character

The formulation and simplex result are exact for the normalized continuous LP.
The HiGHS route solves the same LP through the external backend seam. Workforce
and production quantities are continuous; integer workforce planning is not
implied. Both routes preserve the legacy parser and normalized JSON schema.
