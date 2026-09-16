# Quadratic Programming

QSBCore supports all three preserved WinQSB quadratic fixtures:

- `QP.QP_`: continuous `MatrixFormat` quadratic maximization;
- `QPNORMAL.QP_`: continuous `NormalModel` with a cross-product term;
- `IQP.QP_`: diagonal integer quadratic maximization.

Both legacy formats normalize to `QuadraticProgram`, whose objective is
`x^T Q x + c^T x`. The model reuses the shared linear constraint, objective
sense, variable type, and bound concepts.

## Solver Character

For strictly concave maximization or strictly convex minimization with
continuous variables, the native backend enumerates fixture-scale active sets,
solves their KKT systems, filters for primal feasibility, and selects the global
objective optimum. This path is marked `exact`.

The native integer path supports nonnegative, diagonal, concave maximization
with at most four variables. It finds a feasible incumbent, derives finite
bounds from the separable objective, and enumerates all integer points inside
those bounds. It is marked `fixtureScale`. General MIQP, indefinite QP, and
large active-set models belong behind the future external backend seam.

## HiGHS translation assessment

HiGHS is a candidate for the general convex QP and MIQP path, but the current
external boundary is deliberately a `LinearProgram` plus free MPS. A quadratic
objective needs a QP-capable interchange section or a direct solver API to
preserve the symmetric matrix, cross-term convention (`x^T Q x`), objective
sense, and integer domains. The existing linear exporter cannot carry those
terms, and dropping them or silently linearizing them would change the model.

For this milestone
`QuadraticProgrammingBackends.backend(for: .externalHighPerformance)` remains
unavailable and the CLI reports that state explicitly. The next QP checkpoint
should compare a dedicated QP-capable HiGHS export with its direct API, then
add typed status/solution mapping and curvature/integer-scope tests before
enabling the registry.

## CLI

```text
qsb solve-qp <legacy-qp-file> [--backend native|validate]
qsb validate-qp <legacy-qp-file>
qsb export-qp-json <legacy-qp-file>
qsb solve-qp-json <quadratic-program-json-file> [--backend native|validate]
qsb validate-qp-json <quadratic-program-json-file>
```

Solution documents contain backend metadata, objective value, named variable
values, and the active constraints at the optimum.
