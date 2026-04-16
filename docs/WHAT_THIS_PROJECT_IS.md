# LAWVM - What This Project Is (to spec)

LAWVM is a Tier-0 standalone deterministic machine-law instrument.

Its purpose is to become the execution layer for governed machine decisions,
with reproducible local workflows, explicit receipts, and strict deterministic
artifact behavior.

## Tier-0 scope

- deterministic PowerShell 5.1 workflows
- write-to-disk, parse-gate, then child powershell.exe -File execution
- append-only receipt production
- local-first operation
- no hidden state dependence

## Tier-0 non-scope

- no remote policy authority
- no network distribution requirements
- no ecosystem integrations until standalone determinism is proven
- no claims of full VM artifact packing/verifying yet unless separately proven

## Current proved surface

- minimal self_test_v1.ps1 is GREEN
- product selftest runner _selftest_lawvm_v1.ps1 is GREEN
- lawvm.ndjson append path is GREEN
