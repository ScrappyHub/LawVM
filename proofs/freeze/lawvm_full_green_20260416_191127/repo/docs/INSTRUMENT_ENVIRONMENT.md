# LAWVM - Instrument Environment

## Required environment

- Windows PowerShell 5.1
- Set-StrictMode -Version Latest
- $ErrorActionPreference = "Stop"
- UTF-8 no BOM, LF line endings
- write -> parse-gate -> child powershell.exe -File

## Repo conventions

- scripts\_scratch contains temporary recovery runners and patchers
- scripts\ contains product-surface scripts
- proofs\receipts contains append-only NDJSON receipts

## Determinism rules

- no interactive body dependence
- no silent mutation claims
- parse-gate before execution
- receipts are explicit artifacts, not implied
