# LAWVM

LAWVM is a Tier-0 standalone deterministic instrument.

It is being built as a machine-law execution layer with strict local-first,
reproducible PowerShell workflows and append-only receipts.

## Current state

- Step1 repair path proven
- scripts\self_test_v1.ps1 proven GREEN
- scripts\_selftest_lawvm_v1.ps1 proven GREEN
- proofs\receipts\lawvm.ndjson append path proven

## Quickstart

Run the product selftest runner:

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\_selftest_lawvm_v1.ps1 -RepoRoot .

## Docs

- docs\WHAT_THIS_PROJECT_IS.md
- docs\INSTRUMENT_ENVIRONMENT.md
- docs\DOD_TIER0.md
- docs\WBS.md
