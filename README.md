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
swift run qsb inspect <file>
swift run qsb validate <file>
swift run qsb export-json <legacy-file>
swift run qsb solve <legacy-file> [--backend native|validate|external]
swift run qsb solve-json <json-file> [--backend native|validate|external]
```

These generic commands route through the existing QSBCore import, validation,
normalized JSON, and family-specific backend layers. Family-specific commands
remain available as stable shortcuts for established workflows. See the
[porting roadmap](docs/PORTING_ROADMAP.md) for the broader command inventory.

Legacy WinQSB fixtures are local-only and are not required for the portable
core tests. When present locally, they can be used with the commands above.

## Roadmap and Contributions

QSB is an open project and welcomes developers who want to help extend it.
Please review the [porting roadmap](docs/PORTING_ROADMAP.md) and contribute
new model families, solver capabilities, macOS workflows, tests, and
documentation as the project continues to grow. See [CONTRIBUTING.md](CONTRIBUTING.md)
for the clean-room rules and development workflow.
