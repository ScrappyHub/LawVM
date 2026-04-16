param(
  [Parameter(Mandatory=$true)][string]$RepoRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "LAWVM_SELFTEST_V1_START" -ForegroundColor Cyan
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$ScriptsDir = Join-Path $RepoRoot "scripts"
if(-not (Test-Path -LiteralPath $ScriptsDir -PathType Container)){ throw ("MISSING_DIR: " + $ScriptsDir) }
Write-Host "SELF_TEST_OK" -ForegroundColor Cyan
