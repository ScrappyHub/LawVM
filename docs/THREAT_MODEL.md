# LawVM Threat Model

## What LawVM protects against

- accidental policy drift by keeping policy checks local and explicit
- ambiguous automation decisions
- hidden allow/deny logic buried in scripts
- unsigned or missing policy signature paths in the signature selftests
- request actions that do not match policy rules

## Current guarantees

- local CLI execution
- deterministic allow/deny output for the supported rule format
- default deny when no rule matches
- deny overrides allow when a deny rule matches
- stable reason codes
- release verification command for local proof

## Current non-goals

- not a network authorization server
- not a full identity provider
- not a sandbox
- not a malware or exploit detector
- not a substitute for OS permissions
- not a replacement for legal/compliance review

## Trust boundary

LawVM trusts the local files you give it:

- policy bundle JSON
- request JSON
- local scripts in the checked-out repo

If an attacker can modify the LawVM scripts or policy file, they can affect decisions. Use git history, release tags, and `verify-release` before relying on a checkout.

## Safe use pattern

1. Clone from the official repo.
2. Run `.\lawvm.ps1 verify-release`.
3. Keep policy files in source control.
4. Review policy changes like code changes.
5. Use stable reason codes in automation.
