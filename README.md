# QSB

QSB is a clean-room Swift modernization of WinQSB-style operations research
workflows. It provides a portable core library, a command-line tool, normalized
JSON formats, and a native macOS shell for educational model parsing, solving,
validation, and inspection.

The project can read selected legacy WinQSB model formats from local reference
fixtures, but it does not redistribute the original WinQSB application,
installer payload, help files, manual, or bundled examples.

## Repository Safety

Original WinQSB files are copyrighted third-party artifacts and must remain
local. They are intentionally ignored under:

```sh
reference/winqsb/
```

Use that path only for private compatibility testing on machines where the
files are already legally available. Public commits and remotes must contain
only clean-room source code, tests, documentation, and non-proprietary fixtures.

See [docs/LEGACY_REFERENCE_POLICY.md](docs/LEGACY_REFERENCE_POLICY.md) for the
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
If those files are absent, run the source-level and generated-fixture tests that
do not require the private reference payload.

## CLI

```sh
swift run qsb
```

The CLI exposes import, validation, solving, inventory, and JSON export
workflows for supported model families.
