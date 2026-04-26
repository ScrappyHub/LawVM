# LawVM

LawVM is a local deterministic policy decision CLI.

It lets a user define a JSON policy bundle, submit a JSON request, and receive a deterministic allow/deny decision with a stable reason code.

## What users use it for

- local policy checks before automation runs
- governed repo/tool actions
- offline allow/deny decisions
- signed-policy verification experiments
- deterministic evidence-backed selftests

## Quickstart

```powershell
.\lawvm.ps1 selftest
.\lawvm.ps1 eval .\examples\request_allow.json
.\lawvm.ps1 init-project .\my-lawvm-project
.\lawvm.ps1 eval .\my-lawvm-project\request.json -Policy .\my-lawvm-project\policy_bundle.json
```

## Policy example

```json
{
  "schema": "lawvm.policy_bundle.v1",
  "rules": [
    { "rule_id": "allow_read", "effect": "allow", "principal": "user.alec", "action": "read" },
    { "rule_id": "deny_delete", "effect": "deny", "principal": "user.alec", "action": "delete" }
  ]
}
```

## Request example

```json
{
  "principal": "user.alec",
  "action": "read"
}
```

## Output example

```json
{"decision":"ALLOW","reason_code":"RULE_ALLOW"}
```

## Tier-0 proof

Run:

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\_scratch\_RUN_lawvm_tier0_v1.ps1 -RepoRoot .
```

Expected final token:

```
LAWVM_TIER0_FULL_GREEN_OK
```
