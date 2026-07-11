# QSB

QSB is a clean-room Swift modernization of WinQSB-style operations research
workflows. It provides a portable core library, a command-line tool, normalized
JSON formats, and a native macOS shell for educational model parsing, solving,
validation, and inspection.

The project can read selected legacy WinQSB model formats from local reference
fixtures, but it does not redistribute the original WinQSB application,
installer payload, help files, manual, or bundled examples.

## Repository Safety

Public commits and remotes must contain only clean-room source code, tests,
documentation, and non-proprietary fixtures.

See [docs/LEGACY_REFERENCE_POLICY.md](https://github.com/kubrick06010/qsb/blob/main/docs/LEGACY_REFERENCE_POLICY.md) for the
working policy before creating or pushing a remote repository.

## Build

```sh
swift build
```

## Test

```sh
swift test
```

Some compatibility tests expect private local fixtures in `reference/winqsb/`.
If those files are absent, run the tests that do not require local-only
compatibility fixtures.

## CLI

```sh
swift run qsb
```

The CLI exposes import, validation, solving, inventory, and JSON export
workflows for supported model families.
