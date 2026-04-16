param(
  [Parameter(Mandatory=$true)][string]$RepoRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){
  throw ("LAWVM_EVAL_SELFTEST_FAIL:" + $m)
}

function Write-Utf8NoBomLf([string]$Path,[string]$Text){
  $dir = Split-Path -Parent $Path
  if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $t = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path,$t,$enc)
}

function Get-LastJsonObject([string[]]$Lines){
  $trimmed = @($Lines | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  for($i = $trimmed.Count - 1; $i -ge 0; $i--){
    $line = $trimmed[$i].Trim()
    if($line.StartsWith('{') -and $line.EndsWith('}')){
      return ($line | ConvertFrom-Json)
    }
  }
  Die "NO_JSON_OBJECT_FOUND"
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
if(-not (Test-Path -LiteralPath $PSExe -PathType Leaf)){
  Die "MISSING_POWERSHELL_EXE"
}

$Eval = Join-Path $RepoRoot "scripts\evaluate_lawvm_v1.ps1"
if(-not (Test-Path -LiteralPath $Eval -PathType Leaf)){
  Die "MISSING_EVAL_SCRIPT"
}

$Tmp = Join-Path $RepoRoot "test_vectors\eval_runtime"
if(Test-Path -LiteralPath $Tmp){
  Remove-Item -LiteralPath $Tmp -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null

$enc = New-Object System.Text.UTF8Encoding($false)

$PolicyAllow = Join-Path $Tmp "policy_allow.json"
$PolicyAllowText = '{"schema":"lawvm.policy_bundle.v1","rules":[{"rule_id":"a1","effect":"allow","principal":"user.alec","action":"read","namespace":"docs"}]}'
Write-Utf8NoBomLf $PolicyAllow $PolicyAllowText

$PolicyDeny = Join-Path $Tmp "policy_deny.json"
$PolicyDenyText = '{"schema":"lawvm.policy_bundle.v1","rules":[{"rule_id":"d1","effect":"deny","principal":"user.alec","action":"read","namespace":"docs"}]}'
Write-Utf8NoBomLf $PolicyDeny $PolicyDenyText

$ReqAllow = Join-Path $Tmp "req_allow.json"
$ReqAllowText = '{"principal":"user.alec","action":"read","namespace":"docs"}'
Write-Utf8NoBomLf $ReqAllow $ReqAllowText

$ReqMiss = Join-Path $Tmp "req_miss.json"
$ReqMissText = '{"principal":"user.alec","action":"write","namespace":"docs"}'
Write-Utf8NoBomLf $ReqMiss $ReqMissText

Write-Host "LAWVM_EVAL_SELFTEST_START" -ForegroundColor Cyan

$allowOut = & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Eval -RepoRoot $RepoRoot -PolicyPath $PolicyAllow -RequestPath $ReqAllow 2>&1
if($LASTEXITCODE -ne 0){
  Die "CHILD_FAIL:allow"
}
$allowJson = Get-LastJsonObject @($allowOut)
if([string]$allowJson.decision -ne "ALLOW"){
  Die "ALLOW"
}
if([string]$allowJson.reason_code -ne "RULE_ALLOW"){
  Die "ALLOW_REASON"
}
Write-Host "ALLOW_CASE_OK" -ForegroundColor Green

$denyOut = & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Eval -RepoRoot $RepoRoot -PolicyPath $PolicyDeny -RequestPath $ReqAllow 2>&1
if($LASTEXITCODE -ne 0){
  Die "CHILD_FAIL:deny"
}
$denyJson = Get-LastJsonObject @($denyOut)
if([string]$denyJson.decision -ne "DENY"){
  Die "DENY"
}
if([string]$denyJson.reason_code -ne "RULE_DENY"){
  Die "DENY_REASON"
}
Write-Host "DENY_CASE_OK" -ForegroundColor Green

$missOut = & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Eval -RepoRoot $RepoRoot -PolicyPath $PolicyAllow -RequestPath $ReqMiss 2>&1
if($LASTEXITCODE -ne 0){
  Die "CHILD_FAIL:miss"
}
$missJson = Get-LastJsonObject @($missOut)
if([string]$missJson.decision -ne "DENY"){
  Die "NO_MATCH_DECISION"
}
if([string]$missJson.reason_code -ne "NO_MATCH"){
  Die "NO_MATCH_REASON"
}
Write-Host "NO_MATCH_CASE_OK" -ForegroundColor Green

Write-Host "LAWVM_EVAL_SELFTEST_OK" -ForegroundColor Green
