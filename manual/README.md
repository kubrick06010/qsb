# Manual académico y práctico de QSB

Manual en español para aprender a formular problemas de investigación de
operaciones y resolverlos con la aplicación macOS o la CLI de QSB. Esta edición
corresponde a las funcionalidades documentadas el 11 de octubre de 2026.

## Leer y compilar

Desde `manual/`:

```sh
make
```

El PDF se genera en `build/main.pdf`. La compilación utiliza `latexmk` con TeX
Live/MacTeX si está disponible; como alternativa utiliza Tectonic, incluido el
runtime de la aplicación local cuando existe. Puede indicarse otro ejecutable:

```sh
make TECTONIC=/ruta/a/tectonic
```

Tectonic puede necesitar acceso a internet en la primera compilación para
obtener los paquetes LaTeX. La bibliografía se procesa durante la compilación.
Todos los archivos generados permanecen en `build/`, ignorado por Git.
`make clean` elimina los productos del manual.

## Edición inglesa

La [edición inglesa](en/README.md) conserva los mismos modelos, ejemplos y
bibliografía. `make english` genera `build/main-en.pdf`; `make both` compila
ambas ediciones. `make verify-translation` comprueba la correspondencia de
estructura, fórmulas, cifras y comandos. Al modificar contenido, actualice
las dos ediciones y revise también el significado del texto.

## Reproducir los ejemplos

Desde la raíz del repositorio:

```sh
python3 manual/verify_examples.py
```

El verificador compila `qsb`, ejecuta cada entrada declarada en
`examples/manifest.json` y comprueba valores esperados mediante punteros JSON.
Las tolerancias permiten diferencias normales de coma flotante. También vuelve
a ejecutar el caso de simulación con semilla fija para comprobar su repetibilidad.
Puede reutilizarse un ejecutable ya construido:

```sh
python3 manual/verify_examples.py --qsb .build/debug/qsb
```

Desde `manual/`, `make verify` comprueba primero la paridad entre ediciones y
después ejecuta todos los ejemplos. El CI ejecuta ese mismo objetivo en macOS
y Linux, sin necesitar LaTeX ni los archivos propietarios de referencia. Los comandos de los
capítulos se ejecutan desde la raíz del repositorio, usando `swift run qsb`.
El backend nativo es suficiente para los ejemplos obligatorios. HiGHS es opcional;
los capítulos explican qué familias admiten el backend externo y qué límites
siguen vigentes.

## Contenido

| Bloque | Capítulos |
| --- | --- |
| Uso y fundamentos | Guía de la aplicación; formulación, validación y trazabilidad |
| Optimización y decisiones | Programación lineal y entera; metas, cuadrática y no lineal; redes; decisiones, juegos y programación dinámica |
| Planificación | Inventarios; secuenciación; CPM/PERT, planificación agregada y MRP; instalaciones y equilibrado de líneas |
| Incertidumbre y calidad | Colas; pronósticos; Markov y simulación; control de calidad y muestreo de aceptación |
| Consulta | Glosario y bibliografía |

Cada capítulo combina fundamentos, supuestos, ejemplos originales, instrucciones
de uso, interpretación, límites del solver y ejercicios. Las garantías del
algoritmo se distinguen de los supuestos del modelo: una fórmula exacta no hace
exacta una predicción del mundo real, y una heurística no certifica optimalidad.

## Fuentes y mantenimiento

- `main.tex`: portada, convenciones, partes y orden del volumen.
- `chapters/`: contenido académico y práctico por familia.
- `examples/`: entradas originales y expectativas de resultados reproducibles.
- `examples/manifest.json`: valores que deben conservar los ejemplos publicados.
- `verify_examples.py`: ejecución y comprobación de los ejemplos.
- `references.bib`: bibliografía académica.
- `figures/`: cinco esquemas TikZ compartidos por las dos ediciones.

La documentación técnica de `../docs/` y el código de `QSBCore` sustentan las
 descripciones del comportamiento. `../docs/PORTING_ROADMAP.md` sigue siendo la
referencia pública del estado del proyecto. Al cambiar un ejemplo, hay que
revisar su interpretación y sus expectativas, ejecutar el verificador, compilar
y revisar las páginas afectadas. No se deben actualizar expectativas solo para
ocultar una discrepancia.

Los ejemplos fueron escritos para QSB y no necesitan `reference/winqsb/`.
El manual no copia ni distribuye manuales, capturas ni datos propietarios del
producto original. La posibilidad de importar archivos propios es una función
de compatibilidad, no una autorización para redistribuirlos.

Los diagramas de ruta más corta, flujo máximo, CPM, PERT y árbol de decisión
representan los mismos datos que sus ejemplos JSON. Sus leyendas explican
unidades, tipos de nodo y trazos, y el texto conserva una descripción completa
para poder interpretar los casos sin depender del dibujo. Al modificar un
ejemplo, revise también su diagrama y las leyendas de ambas ediciones.
