param(
  [Parameter(Mandatory=$true)][string]$RepoRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_lib_lawvm_v1.ps1")

function Die([string]$m){ throw ("LAWVM_VERIFY_FAIL: " + $m) }

$ok = LAWVM-VerifyPolicySig $RepoRoot
if(-not $ok){ Die "policy_bundle.sig missing or not verifiable" }

Write-Output "VERIFY_OK"
