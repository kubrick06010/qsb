# QSB Academic and Practical Manual — English Edition

This is the complete English counterpart of the Spanish manual, covering the
QSB functionality documented on October 11, 2026. It uses the same chapter
order, model assumptions, mathematical formulations, numerical results,
exercises, and solver limitations.

## Build and read

From the repository root:

```sh
make -C manual english
```

The PDF is written to `manual/build/main-en.pdf`. Use `make -C manual both` to
build both editions. The build supports TeX Live with `latexmk`, or Tectonic;
see the parent [manual README](../README.md) for runtime selection.

## Verify

```sh
python3 manual/verify_examples.py
python3 manual/verify_translation.py
```

The example verifier checks the shared original JSON inputs and expected
results. The translation verifier checks chapter coverage and ordering,
section structure, labels, references, citations, mathematical expressions,
numeric literals, paths, and command blocks. These automated checks complement
independent agent review of technical fidelity and English usage; they do not
prove that a prose translation preserves its meaning.

## Shared examples and identifiers

Both editions use `manual/examples/` and `manual/references.bib`. JSON keys,
application labels, CLI commands, filenames, and data identifiers remain
unchanged. Some example identifiers are Spanish: for instance, `Lanzar` means
“Launch” and `Operativa` means “Operational.” English explanations retain the
identifiers so that readers can compare the manual with actual QSB output.
The English edition uses decimal points in mathematical text.

## Maintaining both editions

English chapters live under `manual/en/chapters/`, with filenames matching
those under `manual/chapters/`. `manual/main-en.tex` provides the English front
matter and includes those chapters. When software behavior or an example
changes, update both editions, verify the examples and translation parity,
compile both PDFs, and inspect the affected pages.

This manual and its examples are original QSB project documentation. They do
not require or reproduce proprietary WinQSB manuals or datasets.

Independent review scopes, resolved findings, and verification results are
recorded in [REVIEW.md](REVIEW.md).

`make -C manual verify` checks bilingual parity before running all examples.
The Swift CI workflow runs this target on macOS and Linux without LaTeX or
proprietary reference fixtures. Five vector diagrams in `manual/figures/` share
the geometry and example data between editions; captions explain their units
and visual conventions. Review diagrams and both captions when changing data.
