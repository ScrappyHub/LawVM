# LAWVM - Receipts

LAWVM receipts are append-only NDJSON lines written to:

- proofs\receipts\lawvm.ndjson

## Current locked receipt

Schema name:

- lawvm.receipt.v1

Current event types:

- lawvm.selftest.v1

## Canonical fields

Required fields:

- schema
- event
- stamp_utc
- repo_root

## Current validation rules

- schema must equal lawvm.receipt.v1
- event must equal lawvm.selftest.v1
- stamp_utc must be UTC in the form YYYY-MM-DDTHH:MM:SSZ
- repo_root must be a non-empty string
- no extra fields allowed in the current locked schema

## Tier-0 note

This schema is intentionally minimal.
Future receipt variants may be added, but Tier-0 validation for the current selftest line must remain deterministic and stable.
