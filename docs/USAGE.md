# LawVM Usage

## 1. Clone and verify

```powershell
git clone https://github.com/ScrappyHub/LawVM.git
cd LawVM
.\lawvm.ps1 verify-release
```

## 2. Create a policy project

```powershell
.\lawvm.ps1 init-project .\my-policy-project
```

This creates:

- `policy_bundle.json`
- `request.json`

## 3. Evaluate a request

```powershell
.\lawvm.ps1 eval .\my-policy-project
```

Or explicitly:

```powershell
.\lawvm.ps1 eval .\my-policy-project\request.json -Policy .\my-policy-project\policy_bundle.json
```

## Example output

```json
{"decision":"ALLOW","reason_code":"RULE_ALLOW"}
```

## Policy fields

- `schema`: currently `lawvm.policy_bundle.v1`
- `rules`: array of allow/deny rules
- `rule_id`: stable rule name
- `effect`: `allow` or `deny`
- `principal`: optional actor match
- `action`: required action match
- `namespace`: optional scope match

## Request fields

- `principal`: actor asking to do something
- `action`: requested action
- `namespace`: optional scope

## Reason codes

- `RULE_ALLOW`: an allow rule matched
- `RULE_DENY`: a deny rule matched
- `NO_MATCH`: no rule matched, so the result is deny
