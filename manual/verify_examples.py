#!/usr/bin/env python3
"""Verify the manual's independently specified numerical expectations."""

import argparse
import json
import math
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
EXAMPLES = ROOT / "manual" / "examples"


def value_at(document, pointer):
    value = document
    for component in pointer.lstrip("/").split("/"):
        component = component.replace("~1", "/").replace("~0", "~")
        value = value[int(component)] if isinstance(value, list) else value[component]
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--qsb", type=Path, help="Use an existing qsb executable")
    args = parser.parse_args()
    if args.qsb:
        binary = args.qsb.resolve()
    else:
        subprocess.run(["swift", "build", "--product", "qsb"], cwd=ROOT, check=True)
        directory = subprocess.check_output(
            ["swift", "build", "--show-bin-path"], cwd=ROOT, text=True
        ).strip()
        binary = Path(directory) / "qsb"

    manifest = json.loads((EXAMPLES / "manifest.json").read_text())
    source_files = {
        path.name for path in EXAMPLES.glob("*.json")
        if path.name != "manifest.json"
        and not path.stem.endswith(("_solution", "_validation"))
    }
    declared = [case["file"] for case in manifest["examples"]]
    if len(declared) != len(set(declared)) or set(declared) != source_files:
        raise ValueError(
            "The manifest must cover every input example exactly once; "
            f"missing={sorted(source_files - set(declared))}, "
            f"unexpected={sorted(set(declared) - source_files)}"
        )

    count = 0
    cases = manifest["examples"] + manifest.get("scenarios", [])
    for case in cases:
        source = EXAMPLES / case["file"]
        validation = subprocess.run([str(binary), "validate", str(source)], cwd=ROOT,
                                    capture_output=True, text=True, check=True)
        report = json.loads(validation.stdout)
        if report.get("isValid") is False or any(
            diagnostic["severity"] == "error" for diagnostic in report["diagnostics"]
        ):
            raise AssertionError(f"Invalid manual input: {source.name}")
        command = [str(binary), *case.get("command", ["solve-json"])]
        if "arguments" in case:
            command.extend(case["arguments"])
        else:
            command.append(str(source))
            command.extend(case.get("options", []))
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, check=True)
        output = json.loads(result.stdout)
        if not case["checks"]:
            raise ValueError(f"No result checks for {source.name}")
        for check in case["checks"]:
            actual = value_at(output, check["path"])
            expected = check["value"]
            if isinstance(expected, (int, float)) and not isinstance(expected, bool):
                matches = (
                    isinstance(actual, (int, float)) and not isinstance(actual, bool)
                    and math.isfinite(actual)
                    and math.isclose(actual, expected,
                                     rel_tol=check.get("relativeTolerance", 1e-8),
                                     abs_tol=check.get("absoluteTolerance", 1e-8))
                )
            else:
                matches = actual == expected
            if not matches:
                raise AssertionError(
                    f"{source.name} {check['path']}: expected {expected!r}, got {actual!r}"
                )
            count += 1
        if case.get("repeat", False):
            repeated = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, check=True)
            if json.loads(repeated.stdout) != output:
                raise AssertionError(f"Seeded result is not reproducible: {source.name}")
        label = case.get("name", source.name)
        print(f"OK {label}: {len(case['checks'])} checks")
    print(f"Verified {len(declared)} examples, {len(cases)} scenarios and {count} result checks.")


if __name__ == "__main__":
    main()
