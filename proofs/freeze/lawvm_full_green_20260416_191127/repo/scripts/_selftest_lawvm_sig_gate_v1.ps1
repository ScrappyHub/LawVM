param(
  [Parameter(Mandatory=$true)][string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){
  throw ("LAWVM_SIG_GATE_SELFTEST_FAIL:" + $m)
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"

if(-not (Test-Path -LiteralPath $PSExe -PathType Leaf)){
  Die "MISSING_POWERSHELL_EXE"
}

$VerifySig = Join-Path $RepoRoot "scripts\verify_policy_bundle_sig_v1.ps1"
if(-not (Test-Path -LiteralPath $VerifySig -PathType Leaf)){
  Die "MISSING_VERIFY_SIG_SCRIPT"
}

Write-Host "LAWVM_SIG_GATE_SELFTEST_START" -ForegroundColor Cyan

$outFile = Join-Path $env:TEMP "lawvm_sig_gate_selftest_stdout.txt"
$errFile = Join-Path $env:TEMP "lawvm_sig_gate_selftest_stderr.txt"

if(Test-Path -LiteralPath $outFile){ Remove-Item -LiteralPath $outFile -Force }
if(Test-Path -LiteralPath $errFile){ Remove-Item -LiteralPath $errFile -Force }

$proc = Start-Process -FilePath $PSExe `
  -ArgumentList @(
    "-NoProfile",
    "-NonInteractive",
    "-ExecutionPolicy","Bypass",
    "-File",$VerifySig,
    "-RepoRoot",$RepoRoot
  ) `
  -Wait `
  -PassThru `
  -NoNewWindow `
  -RedirectStandardOutput $outFile `
  -RedirectStandardError $errFile

$stdout = ""
$stderr = ""

if(Test-Path -LiteralPath $outFile){
  $stdout = [System.IO.File]::ReadAllText($outFile)
}
if(Test-Path -LiteralPath $errFile){
  $stderr = [System.IO.File]::ReadAllText($errFile)
}

$joined = (($stdout + "`n" + $stderr).Trim())

if($proc.ExitCode -eq 0){
  Die "NEGATIVE_CASE_DID_NOT_FAIL"
}

if($joined -notmatch [regex]::Escape("POLICY_SIG_INVALID:MISSING_SIG")){
  Die ("WRONG_TOKEN:" + $joined)
}

Write-Host "POLICY_SIG_INVALID_CASE_OK" -ForegroundColor Green
Write-Host "LAWVM_SIG_GATE_SELFTEST_OK" -ForegroundColor Green
