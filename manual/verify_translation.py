#!/usr/bin/env python3
"""Check structural and technical parity between the Spanish and English editions.

These checks complement independent language and technical review; they cannot
establish that prose preserves its meaning.
"""

from collections import Counter
from pathlib import Path
import re


MANUAL = Path(__file__).resolve().parent
MATH = re.compile(r"\\\[(.*?)\\\]|\\\((.*?)\\\)|(?<!\\)\$(.*?)(?<!\\)\$", re.S)
LISTINGS = re.compile(r"\\begin\{lstlisting\}(?:\[[^\]]*\])?(.*?)\\end\{lstlisting\}", re.S)
STRUCTURE = re.compile(r"\\(chapter|section|subsection|subsubsection|item|begin|end)\b(?:\{([^}]+)\})?")


def normalize_math(value):
    value = value.replace("{,}", ".")
    # Language-specific explanatory text can change inside an equation; the
    # surrounding operators and variables must stay in the same order.
    value = re.sub(r"\\text\{[^{}]*\}", r"\\text{WORDS}", value)
    value = re.sub(r"\\(?:quad|qquad|thinspace|displaystyle)\b|\\[,;! ]", "", value)
    return re.sub(r"\s+", "", value)


def equations(text):
    return [normalize_math(next(v for v in match.groups() if v is not None))
            for match in MATH.finditer(text)]


def structure(text):
    return [(kind, argument if kind in ("begin", "end") else "")
            for kind, argument in STRUCTURE.findall(text)]


def tokens(text, name):
    return re.findall(r"\\" + name + r"\{([^{}]+)\}", text)


def command_blocks(text):
    return [re.sub(r"\s+", " ", value).strip() for value in LISTINGS.findall(text)]


def numbers(text):
    text = text.replace("{,}", ".")
    return Counter(re.findall(r"\d+(?:\.\d+)?", text))


def main():
    spanish = MANUAL / "chapters"
    english = MANUAL / "en" / "chapters"
    originals = sorted(spanish.glob("*.tex"))
    if {p.name for p in originals} != {p.name for p in english.glob("*.tex")}:
        raise AssertionError("Each Spanish chapter must have exactly one English counterpart")
    errors = []
    totals = Counter()
    for original in originals:
        left = original.read_text()
        right = (english / original.name).read_text()
        checks = {
            "section and environment structure": (structure(left), structure(right)),
            "labels": (tokens(left, "label"), tokens(right, "label")),
            "cross-references": (tokens(left, "ref"), tokens(right, "ref")),
            "citations": (tokens(left, "cite"), tokens(right, "cite")),
            "shared figure inputs": (tokens(left, "input"), tokens(right, "input")),
            "paths": (Counter(tokens(left, "path")), Counter(tokens(right, "path"))),
            "command blocks": (command_blocks(left), command_blocks(right)),
            "equations": (equations(left), equations(right)),
            "numeric literals": (numbers(left), numbers(right)),
        }
        for name, (before, after) in checks.items():
            if before != after:
                errors.append(f"{original.name}: {name} differ")
        if "\\textquestiondown" in right or "\\textexclamdown" in right:
            errors.append(f"{original.name}: Spanish opening punctuation remains")
        for shared in tokens(right, "input"):
            if not (MANUAL / (shared + ".tex")).is_file():
                errors.append(f"{original.name}: missing shared input {shared}")
        totals["equations"] += len(equations(left))
        totals["command blocks"] += len(command_blocks(left))
        print(f"Checked {original.name}")

    left_includes = tokens((MANUAL / "main.tex").read_text(), "include")
    right_includes = tokens((MANUAL / "main-en.tex").read_text(), "include")
    if ["en/" + value for value in left_includes] != right_includes:
        errors.append("The chapter inclusion order differs between editions")
    if errors:
        raise AssertionError("\n".join(errors))
    print(f"Parity verified for {len(originals)} chapters, {totals['equations']} equations "
          f"and {totals['command blocks']} command blocks.")


if __name__ == "__main__":
    main()
