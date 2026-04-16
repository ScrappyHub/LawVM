# LAWVM - Tier-0 Definition of Done

LAWVM Tier-0 is DONE when all of the following are true:

1. A deterministic product selftest runner is GREEN on a clean run.
2. Product scripts parse-gate successfully under PowerShell 5.1.
3. Receipts append deterministically to proofs\receipts\lawvm.ndjson.
4. Public repo surface exists:
   - README.md
   - LICENSE
   - docs\WHAT_THIS_PROJECT_IS.md
   - docs\INSTRUMENT_ENVIRONMENT.md
   - docs\DOD_TIER0.md
   - docs\WBS.md
5. At least one positive and two negative golden vectors exist and are asserted by a deterministic harness.
6. Minimal LAWVM artifact build/verify behavior is proven and receipt-backed.
