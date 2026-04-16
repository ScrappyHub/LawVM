param(
  [Parameter(Mandatory=$true)][string]$RepoRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){
  throw ("LAWVM_ARTIFACT_SELFTEST_FAIL: " + $m)
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
if(-not (Test-Path -LiteralPath $PSExe -PathType Leaf)){
  Die ("MISSING_POWERSHELL_EXE: " + $PSExe)
}

$Build = Join-Path $RepoRoot "scripts\build_lawvm_artifact_v1.ps1"
$Verify = Join-Path $RepoRoot "scripts\verify_lawvm_artifact_v1.ps1"
if(-not (Test-Path -LiteralPath $Build -PathType Leaf)){ Die ("MISSING_BUILD_SCRIPT: " + $Build) }
if(-not (Test-Path -LiteralPath $Verify -PathType Leaf)){ Die ("MISSING_VERIFY_SCRIPT: " + $Verify) }

$ArtPosDir = Join-Path $RepoRoot "test_vectors\artifact\positive"
$ArtNegDir = Join-Path $RepoRoot "test_vectors\artifact\negative"
foreach($d in @($ArtPosDir,$ArtNegDir)){
  if(-not (Test-Path -LiteralPath $d -PathType Container)){
    New-Item -ItemType Directory -Force -Path $d | Out-Null
  }
}

$Pos01 = Join-Path $ArtPosDir "artifact_valid_01"
if(Test-Path -LiteralPath $Pos01){
  Remove-Item -LiteralPath $Pos01 -Recurse -Force
}

Write-Host "LAWVM_ARTIFACT_SELFTEST_START" -ForegroundColor Cyan

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Build -RepoRoot $RepoRoot -OutDir $Pos01 -StampUtc "2026-02-22T00:00:00Z" | Out-Host
& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Verify -RepoRoot $RepoRoot -ArtifactDir $Pos01 -StampUtc "2026-02-22T00:00:00Z" | Out-Host

$Neg01 = Join-Path $ArtNegDir "artifact_bad_hash_01"
if(Test-Path -LiteralPath $Neg01){
  Remove-Item -LiteralPath $Neg01 -Recurse -Force
}
Copy-Item -LiteralPath $Pos01 -Destination $Neg01 -Recurse -Force

$Payload = Join-Path $Neg01 "payload\law.txt"
$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($Payload,"tampered payload`n",$enc)

$out = $null
$failed = $false
try{
  $out = & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Verify -RepoRoot $RepoRoot -ArtifactDir $Neg01 -StampUtc "2026-02-22T00:00:00Z" 2>&1
}catch{
  $failed = $true
  $out = @($_.ToString())
}

$joined = (@($out) -join "`n")
if(-not $failed){
  Die ("NEGATIVE_ARTIFACT_DID_NOT_FAIL: " + $Neg01)
}
if($joined -notmatch [regex]::Escape("PAYLOAD_SHA256_MISMATCH")){
  Die ("NEGATIVE_ARTIFACT_WRONG_TOKEN: " + $joined)
}

Write-Host ("NEGATIVE_ARTIFACT_OK: " + $Neg01 + " token=PAYLOAD_SHA256_MISMATCH") -ForegroundColor Green
Write-Host "LAWVM_ARTIFACT_SELFTEST_OK" -ForegroundColor Green
