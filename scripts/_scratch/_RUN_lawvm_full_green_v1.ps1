param([string]$RepoRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$PS = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"

function Run($p){
  & $PS -NoProfile -ExecutionPolicy Bypass -File $p -RepoRoot $RepoRoot
  if($LASTEXITCODE -ne 0){ throw ("FAIL:"+$p) }
}

Run (Join-Path $RepoRoot "scripts\_selftest_lawvm_v1.ps1")
Run (Join-Path $RepoRoot "scripts\_selftest_lawvm_vectors_v1.ps1")
Run (Join-Path $RepoRoot "scripts\_selftest_lawvm_eval_v1.ps1")
Run (Join-Path $RepoRoot "scripts\_selftest_lawvm_sig_gate_v1.ps1")
Run (Join-Path $RepoRoot "scripts\_selftest_lawvm_sig_positive_v1.ps1")

Write-Host "LAWVM_FULL_GREEN_V1_OK" -ForegroundColor Green