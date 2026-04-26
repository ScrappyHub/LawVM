param([Parameter(Mandatory=$true)][string]$RepoRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
function Die([string]$m){ throw ("LAWVM_EVAL_SELFTEST_FAIL:" + $m) }
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
$Eval = Join-Path $RepoRoot "scripts\evaluate_lawvm_v1.ps1"
$Policy = Join-Path $RepoRoot "examples\policy_bundle.json"
$Allow = Join-Path $RepoRoot "examples\request_allow.json"
$Deny = Join-Path $RepoRoot "examples\request_deny.json"
$NoMatch = Join-Path $RepoRoot "examples\request_nomatch.json"
Write-Host "LAWVM_EVAL_SELFTEST_START" -ForegroundColor Cyan
$a = & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Eval -RepoRoot $RepoRoot -RequestPath $Allow -PolicyPath $Policy 2>&1
if($LASTEXITCODE -ne 0){ @($a)|Out-Host; Die "CHILD_FAIL_ALLOW" }
if((@($a)-join "`n") -notmatch [regex]::Escape('"decision":"ALLOW"')){ Die "ALLOW_CASE" }
Write-Host "ALLOW_CASE_OK" -ForegroundColor Green
$d = & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Eval -RepoRoot $RepoRoot -RequestPath $Deny -PolicyPath $Policy 2>&1
if($LASTEXITCODE -ne 0){ @($d)|Out-Host; Die "CHILD_FAIL_DENY" }
if((@($d)-join "`n") -notmatch [regex]::Escape('"reason_code":"RULE_DENY"')){ Die "DENY_CASE" }
Write-Host "DENY_CASE_OK" -ForegroundColor Green
$n = & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Eval -RepoRoot $RepoRoot -RequestPath $NoMatch -PolicyPath $Policy 2>&1
if($LASTEXITCODE -ne 0){ @($n)|Out-Host; Die "CHILD_FAIL_NOMATCH" }
if((@($n)-join "`n") -notmatch [regex]::Escape('"reason_code":"NO_MATCH"')){ Die "NO_MATCH_CASE" }
Write-Host "NO_MATCH_CASE_OK" -ForegroundColor Green
Write-Host "LAWVM_EVAL_SELFTEST_OK" -ForegroundColor Green
