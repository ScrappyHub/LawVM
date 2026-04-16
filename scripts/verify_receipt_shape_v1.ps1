param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$ReceiptPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){
  throw ("LAWVM_VERIFY_RECEIPT_FAIL: " + $m)
}

function Read-Utf8([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){
    Die ("MISSING_FILE: " + $Path)
  }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::ReadAllText($Path,$enc)
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$ReceiptPath = (Resolve-Path -LiteralPath $ReceiptPath).Path

$raw = Read-Utf8 $ReceiptPath
$obj = $raw | ConvertFrom-Json

$propNames = @($obj.PSObject.Properties | ForEach-Object { $_.Name })

if(-not ($propNames -contains "schema")){
  Die "MISSING_SCHEMA"
}
if(-not ($propNames -contains "event")){
  Die "MISSING_EVENT"
}
if(-not ($propNames -contains "stamp_utc")){
  Die "MISSING_STAMP_UTC"
}
if(-not ($propNames -contains "repo_root")){
  Die "MISSING_REPO_ROOT"
}

if([string]$obj.schema -ne "lawvm.receipt.v1"){
  Die ("BAD_SCHEMA: " + [string]$obj.schema)
}

if([string]$obj.event -ne "lawvm.selftest.v1"){
  Die ("BAD_EVENT: " + [string]$obj.event)
}

if([string]::IsNullOrWhiteSpace([string]$obj.stamp_utc)){
  Die "MISSING_STAMP_UTC"
}

if([string]$obj.stamp_utc -notmatch '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'){
  Die ("BAD_STAMP_UTC: " + [string]$obj.stamp_utc)
}

if([string]::IsNullOrWhiteSpace([string]$obj.repo_root)){
  Die "MISSING_REPO_ROOT"
}

$allowed = @("schema","event","stamp_utc","repo_root")
foreach($n in $propNames){
  if(-not ($allowed -contains $n)){
    Die ("EXTRA_FIELD: " + $n)
  }
}

Write-Host ("VERIFY_RECEIPT_OK: " + $ReceiptPath) -ForegroundColor Green
