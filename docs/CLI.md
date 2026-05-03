# LawVM CLI

LawVM is a deterministic local policy decision CLI.

It reads a policy bundle and a request, then returns an allow or deny decision with a stable reason code.

## Commands

```powershell
.\lawvm.ps1 help
.\lawvm.ps1 version
.\lawvm.ps1 selftest
.\lawvm.ps1 verify-release
.\lawvm.ps1 init-project .\my-policy-project
.\lawvm.ps1 eval .\my-policy-project
.\lawvm.ps1 eval .\my-policy-project\request.json -Policy .\my-policy-project\policy_bundle.json
```

## Public proof command

Use this before trusting a local copy:

```powershell
.\lawvm.ps1 verify-release
```

Expected final token:

```text
LAWVM_TIER0_FULL_GREEN_OK
```

The token is an internal proof marker. Public docs should describe it as the release verification success token.
