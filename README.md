# LawVM

LawVM is a deterministic local policy decision CLI and action gate.

It lets you define a JSON policy bundle, submit a JSON request or direct action check, and receive a reproducible allow/deny decision with a stable reason code.

## Quickstart

```powershell
git clone https://github.com/ScrappyHub/LawVM.git
cd LawVM
.\lawvm.ps1 verify-release
.\lawvm.ps1 init-project .\my-policy-project
.\lawvm.ps1 eval .\my-policy-project
```

## Action gate

```powershell
.\lawvm.ps1 check -Principal user.example -Action read -Policy .\my-policy-project\policy_bundle.json
.\lawvm.ps1 guard -Principal user.example -Action read -Policy .\my-policy-project\policy_bundle.json -Then "echo allowed"
```

## Protect secrets example

```powershell
.\lawvm.ps1 check -Principal agent.local -Action write -Namespace repo.secrets -Policy .\examples\policies\protect-secrets.json
```

Expected output:

```json
{"decision":"DENY","reason_code":"RULE_DENY"}
```

## What it is for

LawVM is for local policy checks before scripts, tools, automations, releases, or AI-assisted actions continue.

It answers:

> Given this policy and this requested action, should the action be allowed?

## Docs

- `docs/CLI.md`
- `docs/USAGE.md`
- `docs/ACTION_GATE.md`
- `docs/WHO_IS_THIS_FOR.md`
- `docs/THREAT_MODEL.md`
