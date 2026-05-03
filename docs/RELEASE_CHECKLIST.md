# LawVM Release Checklist

Before publishing a release:

```powershell
.\lawvm.ps1 verify-release
git grep -n "OPENSSH PRIVATE KEY" -- .
git status --short
```

Do not commit:

- `secrets/`
- private signing keys
- temporary smoke projects
- local-only receipts unless intentionally part of proof evidence

Public release language:

- use “release verification”
- use “deterministic policy CLI”
- use “selftest”
- avoid internal maturity labels in public marketing
