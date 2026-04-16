param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$StampUtc = "2026-02-22T00:00:00Z"
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){
  throw ("LAWVM_SELFTEST_FAIL: " + $m)
}

function EnsureDir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){
    Die "ENSUREDIR_EMPTY"
  }
  if(-not (Test-Path -LiteralPath $p -PathType Container)){
    New-Item -ItemType Directory -Force -Path $p | Out-Null
  }
}

function Append-Receipt([string]$Path,[string]$Line){
  $enc = New-Object System.Text.UTF8Encoding($false)
  $dir = Split-Path -Parent $Path
  if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  if(-not $Line.EndsWith("`n")){
    $Line += "`n"
  }
  [System.IO.File]::AppendAllText($Path,$Line,$enc)
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){
    Die ("RECEIPT_APPEND_FAILED: " + $Path)
  }
}

function JsonEscape([string]$s){
  if($null -eq $s){
    return ""
  }
  $bs = [string][char]92
  $dq = [string][char]34
  $r = $s.Replace($bs,($bs + $bs))
  $r = $r.Replace($dq,($bs + $dq))
  $r = $r.Replace("`r","\r").Replace("`n","\n").Replace("`t","\t")
  return $r
}

Write-Host "LAWVM_SELFTEST_RUNNER_V1_START" -ForegroundColor Cyan

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

$SelfV1 = Join-Path $RepoRoot "scripts\self_test_v1.ps1"
if(-not (Test-Path -LiteralPath $SelfV1 -PathType Leaf)){
  Die ("MISSING: " + $SelfV1)
}

$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
if(-not (Test-Path -LiteralPath $PSExe -PathType Leaf)){
  Die ("MISSING_POWERSHELL_EXE: " + $PSExe)
}

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $SelfV1 -RepoRoot $RepoRoot | Out-Host

Write-Host "LAWVM_SELFTEST_RUNNER_V1_OK" -ForegroundColor Green

$RcptPath = Join-Path $RepoRoot "proofs\receipts\lawvm.ndjson"
$dq = [string][char]34
$line = '{' +
  $dq + 'schema' + $dq + ':' + $dq + 'lawvm.receipt.v1' + $dq + ',' +
  $dq + 'event' + $dq + ':' + $dq + 'lawvm.selftest.v1' + $dq + ',' +
  $dq + 'stamp_utc' + $dq + ':' + $dq + (JsonEscape $StampUtc) + $dq + ',' +
  $dq + 'repo_root' + $dq + ':' + $dq + (JsonEscape $RepoRoot) + $dq +
'}'

Append-Receipt $RcptPath $line
Write-Host ("RECEIPT_APPENDED: " + $RcptPath) -ForegroundColor Green
Write-Host "LAWVM_SELFTEST_RUNNER_V1_DONE" -ForegroundColor Green
