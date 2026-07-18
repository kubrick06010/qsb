# Nonlinear Programming

QSBCore supports all three preserved WinQSB nonlinear-programming fixtures:

- `reference/winqsb/NLP1.NL_`: one-variable unconstrained minimization;
- `reference/winqsb/NLP2.NL_`: bounded multivariable minimization;
- `reference/winqsb/NLP3.NL_`: constrained exponential maximization.

The clean-room parser reads the legacy title, objective sense, expressions,
variable bounds, and named constraints. Expressions support arithmetic,
parentheses, powers, implicit multiplication, and `exp`, `log`, `sqrt`, `sin`,
and `cos`. Variable matching is case-insensitive while preserving legacy names.

## CLI And JSON

```bash
qsb solve-nlp reference/winqsb/NLP1.NL_ --backend native
qsb validate-nlp reference/winqsb/NLP3.NL_
qsb export-nlp-json reference/winqsb/NLP2.NL_
qsb solve-nlp-json model.json --backend native
qsb validate-nlp-json model.json
```

The normalized model stores the objective expression, ordered variable names,
nullable lower and upper bounds, constraints, and whether strict legacy
inequalities were normalized. Solution documents include backend metadata,
named variable values, objective value, constraint evaluations, maximum
violation, and iteration/evaluation count.

## Solver Character

`nativeEducational` is deterministic and approximate. It uses expression
automatic differentiation, bounded multistart gradient search, and progressive
constraint penalties. A low-dimensional equality-manifold search handles the
preserved two-variable constrained fixture. It is suitable for small teaching
models, but does not guarantee a global optimum for general nonlinear programs.

Legacy strict inequalities are solved as non-strict boundaries and produce a
structured warning. Native solving is limited to four variables. The
`validateOnly` backend parses and diagnoses without solving;
`externalHighPerformance` remains an explicit future integration point.
