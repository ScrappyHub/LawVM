# LawVM

LawVM is a deterministic local policy decision CLI.

It lets you define a JSON policy bundle, submit a JSON request, and receive a reproducible allow/deny decision with a stable reason code.

## Quickstart

```powershell
git clone https://github.com/ScrappyHub/LawVM.git
cd LawVM
.\lawvm.ps1 verify-release
.\lawvm.ps1 init-project .\my-policy-project
.\lawvm.ps1 eval .\my-policy-project
```

## Example output

```json
{"decision":"ALLOW","reason_code":"RULE_ALLOW"}
```

## What it is for

LawVM is for local policy checks before scripts, tools, automations, or AI-assisted actions continue.

It answers:

> Given this policy and this request, should this action be allowed?

## Docs

- `docs/CLI.md`
- `docs/USAGE.md`
- `docs/WHO_IS_THIS_FOR.md`
- `docs/THREAT_MODEL.md`
- `docs/RELEASE_CHECKLIST.md`
