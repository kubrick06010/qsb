# Contributing

Thanks for your interest in QSB. The project aims to modernize selected
WinQSB-style operations research workflows with clean-room Swift source,
portable data formats, tests, and documentation.

## Ground Rules

- Keep contributions clean-room and redistributable.
- Do not commit proprietary binaries, manuals, help files, bundled examples, or
  derived copies of third-party reference material.
- Follow the repository safety policy in
  [docs/LEGACY_REFERENCE_POLICY.md](docs/LEGACY_REFERENCE_POLICY.md).
- Keep changes focused and easy to review.
- Add or update tests when behavior changes.

## Development Setup

```sh
swift build
swift test
```

Some compatibility tests require local-only fixtures. If those fixtures are not
available, keep changes covered by source-level or independently authored test
cases.

## Pull Requests

Before opening a pull request:

1. Run `swift test` when possible.
2. Check `git status --short --ignored`.
3. Confirm no local-only reference files are staged.
4. Describe the user-facing behavior changed by the PR.
5. Mention any tests that were skipped and why.

## Issue Reports

Good issues include:

- the command, model family, or app workflow involved;
- the expected behavior;
- the actual behavior;
- relevant error output;
- a minimal redistributable example when possible.

Please do not attach proprietary legacy files to public issues.

