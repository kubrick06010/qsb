# Legacy Reference Policy

This repository is a clean-room Swift project. It may use original WinQSB files
as private local behavior references, but those files are not project source and
must not be committed or pushed.

## Local-Only Files

Keep all original WinQSB artifacts under:

```sh
reference/winqsb/
```

That directory is ignored by Git. Treat everything inside it as local-only,
including:

- application binaries and compressed executables;
- installer resources and runtime DLLs;
- help files and manuals;
- bundled model examples and sample data;
- files derived by decompressing or extracting the original payload.

## Public Repository Rules

Before creating a remote or pushing a branch:

1. Run `git status --short --ignored`.
2. Confirm `reference/winqsb/` appears only as ignored content.
3. Run `git ls-files | rg '(^|/)winqsb|^reference/'`.
4. Confirm no proprietary WinQSB payload is tracked.
5. Push only clean-room Swift source, docs, scripts, and non-proprietary tests.

Small fixtures may be committed only when they are independently authored for
this project or otherwise clearly redistributable. Do not copy bytes, text,
tables, screenshots, manuals, or decompressed samples from the original WinQSB
distribution into committed fixtures.

## Test Expectations

Compatibility tests may read private local fixtures from `reference/winqsb/`.
That is acceptable for local development, but remote CI should either provide
licensed private fixtures through a secure channel or skip fixture-dependent
tests.

Use `qsb inspect <file>` for metadata and a bounded preview. Use
`qsb expand <file>` to stream the complete clean-room SZDD expansion to standard
output when format analysis needs fields beyond that preview. Neither command
modifies the source fixture.

Use `qsb import-legacy-json <file>` to parse a supported legacy model and stream
its normalized JSON. The shared importer reads fixtures in place and never
renames, rewrites, expands beside, or otherwise mutates files under
`reference/winqsb/`. Executables, help, installer, manual, and runtime files are
classified and rejected as reference-only artifacts.
