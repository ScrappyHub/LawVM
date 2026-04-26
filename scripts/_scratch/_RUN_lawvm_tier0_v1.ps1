param([Parameter(Mandatory=$true)][string]$RepoRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
function Die([string]$m){ throw ("LAWVM_TIER0_FAIL:" + $m) }
function Parse-GateFile([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ Die ("MISSING:" + $Path) }
  $tok=$null;$err=$null
  [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tok,[ref]$err)
  if(@($err).Count -gt 0){ $e=@($err)[0]; Die ("PARSE:" + $Path + ":" + $e.Message) }
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
$scripts = @(
  (Join-Path $RepoRoot "lawvm.ps1"),
  (Join-Path $RepoRoot "scripts\evaluate_lawvm_v1.ps1"),
  (Join-Path $RepoRoot "scripts\self_test_v1.ps1"),
  (Join-Path $RepoRoot "scripts\_selftest_lawvm_v1.ps1"),
  (Join-Path $RepoRoot "scripts\_selftest_lawvm_vectors_v1.ps1"),
  (Join-Path $RepoRoot "scripts\_selftest_lawvm_eval_v1.ps1"),
  (Join-Path $RepoRoot "scripts\_selftest_lawvm_sig_gate_v1.ps1"),
  (Join-Path $RepoRoot "scripts\_selftest_lawvm_sig_positive_v1.ps1")
)
foreach($s in $scripts){ Parse-GateFile $s; Write-Host ("PARSE_OK: " + $s) -ForegroundColor Green }
Write-Host "LAWVM_TIER0_START" -ForegroundColor Cyan
$run = @(
  (Join-Path $RepoRoot "scripts\_selftest_lawvm_v1.ps1"),
  (Join-Path $RepoRoot "scripts\_selftest_lawvm_vectors_v1.ps1"),
  (Join-Path $RepoRoot "scripts\_selftest_lawvm_eval_v1.ps1"),
  (Join-Path $RepoRoot "scripts\_selftest_lawvm_sig_gate_v1.ps1"),
  (Join-Path $RepoRoot "scripts\_selftest_lawvm_sig_positive_v1.ps1")
)
foreach($r in $run){
  & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $r -RepoRoot $RepoRoot | Out-Host
  if($LASTEXITCODE -ne 0){ Die ("CHILD_FAIL:" + $r + ":exit=" + $LASTEXITCODE) }
}
& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "lawvm.ps1") -Command eval -Target (Join-Path $RepoRoot "examples\request_allow.json") | Out-Host
if($LASTEXITCODE -ne 0){ Die "CLI_EVAL_FAIL" }
Write-Host "LAWVM_TIER0_FULL_GREEN_OK" -ForegroundColor Green
