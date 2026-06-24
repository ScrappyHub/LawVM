# LawVM Decision Receipts

LawVM writes append-only local decision receipts for `check` and `guard` commands.

Receipt path:

```text
proofs\receipts\lawvm.decisions.ndjson
```

Each receipt records:

- schema
- event
- UTC timestamp
- mode: check or guard
- principal
- action
- namespace
- decision
- reason code
- policy SHA-256
- request SHA-256

Show recent receipts:

```powershell
.\lawvm.ps1 receipts
```

This gives developers local evidence of what LawVM decided before a script, automation, or agent action continued.
