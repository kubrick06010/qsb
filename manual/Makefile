TEX = main
BUILD_DIR = build
TECTONIC ?= tectonic

.PHONY: all english both verify verify-translation clean

all:
	@mkdir -p $(BUILD_DIR)/chapters $(BUILD_DIR)/en/chapters
	@if command -v latexmk >/dev/null 2>&1; then \
		latexmk -pdf -interaction=nonstopmode -halt-on-error -file-line-error -outdir=$(BUILD_DIR) $(TEX).tex; \
	elif command -v "$(TECTONIC)" >/dev/null 2>&1; then \
		"$(TECTONIC)" -X compile --untrusted --keep-logs --keep-intermediates --outdir $(BUILD_DIR) $(TEX).tex; \
	elif test -x /Applications/ChatGPT.app/Contents/Resources/tectonic/tectonic; then \
		/Applications/ChatGPT.app/Contents/Resources/tectonic/tectonic -X compile --untrusted --keep-logs --keep-intermediates --outdir $(BUILD_DIR) $(TEX).tex; \
	else \
		echo 'Install latexmk/TeX Live or set TECTONIC to a Tectonic executable.' >&2; \
		exit 1; \
	fi

verify: verify-translation
	python3 verify_examples.py

english:
	$(MAKE) TEX=main-en all

both: all english

verify-translation:
	python3 verify_translation.py

clean:
	rm -f $(BUILD_DIR)/$(TEX).aux $(BUILD_DIR)/$(TEX).bbl $(BUILD_DIR)/$(TEX).blg \
		$(BUILD_DIR)/$(TEX).lof $(BUILD_DIR)/$(TEX).log $(BUILD_DIR)/$(TEX).lot \
		$(BUILD_DIR)/$(TEX).out $(BUILD_DIR)/$(TEX).toc $(BUILD_DIR)/$(TEX).fls \
		$(BUILD_DIR)/$(TEX).fdb_latexmk $(BUILD_DIR)/$(TEX).synctex.gz $(BUILD_DIR)/$(TEX).pdf \
		$(BUILD_DIR)/chapters/*.aux $(BUILD_DIR)/chapters/*.blg $(BUILD_DIR)/chapters/*.bbl \
		$(BUILD_DIR)/en/chapters/*.aux $(BUILD_DIR)/en/chapters/*.blg $(BUILD_DIR)/en/chapters/*.bbl
