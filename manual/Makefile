TEX = main

.PHONY: all clean

all:
	@if command -v latexmk >/dev/null 2>&1; then \
		latexmk -pdf -interaction=nonstopmode -file-line-error $(TEX).tex; \
	else \
		pdflatex -interaction=nonstopmode -file-line-error $(TEX).tex && \
		bibtex $(TEX) && \
		pdflatex -interaction=nonstopmode -file-line-error $(TEX).tex && \
		pdflatex -interaction=nonstopmode -file-line-error $(TEX).tex; \
	fi

clean:
	rm -f $(TEX).aux $(TEX).bbl $(TEX).blg $(TEX).idx $(TEX).ilg \
		$(TEX).ind $(TEX).lof $(TEX).log $(TEX).lot $(TEX).out \
		$(TEX).toc $(TEX).fls $(TEX).fdb_latexmk $(TEX).pdf
