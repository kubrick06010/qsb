# Manual academico de QSB

Este directorio contiene el manual LaTeX vivo de investigacion de operaciones
acompanado por QSB.

## Compilar

Desde este directorio:

```sh
make
```

La maquina local debe tener una distribucion TeX con `pdflatex` y `bibtex`, o
`latexmk`. Los artefactos de compilacion se limpian con:

```sh
make clean
```

## Estructura editorial

- `main.tex`: portada, indices, convenciones y orden academico del volumen.
- `chapters/`: capitulos teoricos y aplicados por familia de modelos.
- `examples/`: instancias normalizadas usadas por QSB y citadas en el manual.
- `references.bib`: bibliografia academica en BibTeX.

Cada ampliacion deberia conservar la doble lectura del manual: fundamentos
establecidos del campo y reproduccion computacional con QSB.
