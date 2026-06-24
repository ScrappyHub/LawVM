# LawVM Action Gate

LawVM v0.1.2 adds direct action-gate commands.

## Check an action

```powershell
.\lawvm.ps1 check -Principal user.example -Action read -Policy .\my-policy-project\policy_bundle.json
```

Allowed output:

```json
{"decision":"ALLOW","reason_code":"RULE_ALLOW"}
```

Denied output:

```json
{"decision":"DENY","reason_code":"RULE_DENY"}
```

Exit codes:

- `0`: allowed
- `2`: denied by policy
- `1`: CLI or evaluation error

## Guard a command

```powershell
.\lawvm.ps1 guard -Principal user.example -Action read -Policy .\my-policy-project\policy_bundle.json -Then "echo allowed"
```

If policy allows the action, LawVM runs the command.
If policy denies the action, LawVM does not run the command and exits `2`.

## Protect secrets example

```powershell
.\lawvm.ps1 check -Principal agent.local -Action write -Namespace repo.secrets -Policy .\examples\policies\protect-secrets.json
```

Expected result:

```json
{"decision":"DENY","reason_code":"RULE_DENY"}
```

## What this means

LawVM can now sit in front of scripts, release commands, agents, and automations.
The tool asks policy first, then either allows the action or blocks it.
