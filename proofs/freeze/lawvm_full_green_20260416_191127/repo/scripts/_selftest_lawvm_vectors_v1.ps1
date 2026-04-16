param(
  [Parameter(Mandatory=$true)][string]$RepoRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){
  throw ("LAWVM_VECTOR_SELFTEST_FAIL: " + $m)
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
if(-not (Test-Path -LiteralPath $PSExe -PathType Leaf)){
  Die ("MISSING_POWERSHELL_EXE: " + $PSExe)
}

$Verifier = Join-Path $RepoRoot "scripts\verify_receipt_shape_v1.ps1"
if(-not (Test-Path -LiteralPath $Verifier -PathType Leaf)){
  Die ("MISSING_VERIFIER: " + $Verifier)
}

$Pos = @(
  (Join-Path $RepoRoot "test_vectors\positive\receipt_valid_01.json")
)

$Neg = @(
  @{ Path = (Join-Path $RepoRoot "test_vectors\negative\receipt_invalid_missing_repo_root_01.json"); Token = "MISSING_REPO_ROOT" },
  @{ Path = (Join-Path $RepoRoot "test_vectors\negative\receipt_invalid_bad_event_01.json"); Token = "BAD_EVENT" },
  @{ Path = (Join-Path $RepoRoot "test_vectors\negative\receipt_invalid_extra_field_01.json"); Token = "EXTRA_FIELD" }
)

Write-Host "LAWVM_VECTOR_SELFTEST_START" -ForegroundColor Cyan

foreach($p in $Pos){
  & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Verifier -RepoRoot $RepoRoot -ReceiptPath $p | Out-Host
}

foreach($n in $Neg){
  $path = [string]$n.Path
  $token = [string]$n.Token

  $out = $null
  $failed = $false

  try{
    $out = & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Verifier -RepoRoot $RepoRoot -ReceiptPath $path 2>&1
  }catch{
    $failed = $true
    $out = @($_.ToString())
  }

  $joined = (@($out) -join "`n")
  if(-not $failed){
    Die ("NEGATIVE_VECTOR_DID_NOT_FAIL: " + $path)
  }
  if($joined -notmatch [regex]::Escape($token)){
    Die ("NEGATIVE_VECTOR_WRONG_TOKEN: path=" + $path + " expected=" + $token + " got=" + $joined)
  }

  Write-Host ("NEGATIVE_VECTOR_OK: " + $path + " token=" + $token) -ForegroundColor Green
}

Write-Host "LAWVM_VECTOR_SELFTEST_OK" -ForegroundColor Green
