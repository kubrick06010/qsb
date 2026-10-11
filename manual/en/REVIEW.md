# English edition review

Edition: 11 October 2026. English source: `../main-en.tex` and `chapters/`.
Spanish source: `../main.tex` and `../chapters/`. This records an agent review,
not a human editorial certification.

## Independent bilingual review

Each reviewer read the complete assigned English chapters alongside the Spanish
originals and reviewed chapters translated by another agent. Checks covered
completeness, mathematical meaning, numerical results, assumptions, solver
limits, CLI commands, application instructions, exercises, and English terminology.

| Reviewer | Independently reviewed chapters |
| --- | --- |
| `en_planning` | 02, 03, 10 |
| `en_usage` | 04, 08, 11, 12; English front matter and edition README |
| `en_optimization` | 05, 06, 07, 13, 14 |
| `en_stochastic` | 00, 01, 09, 15; all 30 glossary definitions |

No substantive omissions or mathematical/result discrepancies were reported.
The following findings were resolved:

- Simulation interface section names now match the implemented `Components`,
  `Routes`, and `Service Rules` labels. Spanish identifiers in example data
  remain unchanged and receive English glosses.
- Queueing prose uses “an infinite customer population.”
- JSON instructions explicitly refer to applying JSON when describing failure.
- Scheduling prose preserves the original identifier count. The routing boundary uses
  `V(\text{destino})` in Spanish and `V(\text{destination})` in English;
  explanatory text is reviewed semantically.
- A paragraph break in the linear-programming input description removes an
  overfull line without changing content.

## Reproducible verification

- `python3 manual/verify_translation.py`: 16 chapters, 512 mathematical
  expressions, and 38 command blocks pass structural/technical parity.
- `python3 manual/verify_examples.py --qsb .build/debug/qsb`: 53 inputs,
  57 scenarios, and 130 result expectations pass, including seeded replication.
- `make -C manual english`: successful Tectonic build with resolved citations
  and cross-references and no overfull text boxes.
- All 67 A4 pages rendered and visually inspected; detailed inspections include
  linear-programming output, queueing formulas/tables, and simulation workflow.
  Extracted word bounds contain no text outside page boundaries.
- `git diff --check`: passes. Generated products remain under ignored `build/`.

Structural checks cannot establish prose equivalence on their own. Both editions
must be updated and reviewed together after changes to documented behavior.

## Diagram and CI follow-up

Five shared TikZ diagrams were independently reviewed by `en_planning` against
`plan_spp.json`, `plan_maxflow.json`, `plan_cpm.json`, `plan_pert.json`, and
`dec_tree.json`. All arcs, values, precedence relations, probabilities, local
payoffs, highlighted paths/policy, and bilingual captions match those examples.
The manual verifier also checks matching shared inputs and missing diagram files.

`make -C manual verify` passes locally with both parity and all 130 result checks.
The Swift workflow runs that target in its macOS/Linux matrix; hosted CI has not
been run in this local session. Both updated PDFs have 67 pages. The Spanish
p-chart paragraph has no underfull-line warning. Remaining minor underfull page
warnings and an English inline-identifier justification warning do not indicate
clipping; diagrams and surrounding pages receive a visual layout review.
