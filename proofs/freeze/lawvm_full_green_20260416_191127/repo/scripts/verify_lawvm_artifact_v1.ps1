param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$ArtifactDir,
  [string]$StampUtc = "2026-02-22T00:00:00Z"
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){
  throw ("LAWVM_VERIFY_ARTIFACT_FAIL: " + $m)
}

function Sha256HexPath([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){
    Die ("MISSING_FILE: " + $Path)
  }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $fs = [System.IO.File]::OpenRead($Path)
  try{
    $h = $sha.ComputeHash($fs)
    ($h | ForEach-Object { $_.ToString("x2") }) -join ""
  } finally {
    $fs.Dispose()
    $sha.Dispose()
  }
}

function JsonCanon([object]$Obj){
  if($null -eq $Obj){ return $null }

  if($Obj -is [string] -or $Obj -is [bool] -or
     $Obj -is [int] -or $Obj -is [long] -or
     $Obj -is [double] -or $Obj -is [decimal]){
    return $Obj
  }

  if($Obj -is [System.Collections.IDictionary]){
    $h = [ordered]@{}
    foreach($k in ($Obj.Keys | ForEach-Object { [string]$_ } | Sort-Object)){
      $h[$k] = JsonCanon $Obj[$k]
    }
    return $h
  }

  if($Obj -is [psobject]){
    $props = @($Obj.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' -or $_.MemberType -eq 'Property' })
    if($props.Count -gt 0){
      $h = [ordered]@{}
      foreach($n in ($props.Name | Sort-Object)){
        $h[$n] = JsonCanon $Obj.$n
      }
      return $h
    }
  }

  if($Obj -is [System.Collections.IEnumerable]){
    $arr = @()
    foreach($x in $Obj){
      $arr += ,(JsonCanon $x)
    }
    return $arr
  }

  return $Obj
}

function To-CanonJson([object]$Obj,[int]$Depth=32){
  $canon = JsonCanon $Obj
  ($canon | ConvertTo-Json -Depth $Depth -Compress)
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
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$ArtifactDir = (Resolve-Path -LiteralPath $ArtifactDir).Path

$ArtifactJsonPath = Join-Path $ArtifactDir "artifact.json"
if(-not (Test-Path -LiteralPath $ArtifactJsonPath -PathType Leaf)){
  Die ("MISSING_ARTIFACT_JSON: " + $ArtifactJsonPath)
}

$enc = New-Object System.Text.UTF8Encoding($false)
$raw = [System.IO.File]::ReadAllText($ArtifactJsonPath,$enc)
$obj = $raw | ConvertFrom-Json

$propNames = @($obj.PSObject.Properties | ForEach-Object { $_.Name })
foreach($need in @("schema","artifact_type","stamp_utc","payload_relpath","payload_sha256")){
  if(-not ($propNames -contains $need)){
    Die ("MISSING_FIELD: " + $need)
  }
}

if([string]$obj.schema -ne "lawvm.artifact.v1"){
  Die ("BAD_SCHEMA: " + [string]$obj.schema)
}

if([string]$obj.artifact_type -ne "machine_law_bundle"){
  Die ("BAD_ARTIFACT_TYPE: " + [string]$obj.artifact_type)
}

$allowed = @("schema","artifact_type","stamp_utc","payload_relpath","payload_sha256")
foreach($n in $propNames){
  if(-not ($allowed -contains $n)){
    Die ("EXTRA_FIELD: " + $n)
  }
}

$rel = [string]$obj.payload_relpath
if([string]::IsNullOrWhiteSpace($rel)){
  Die "EMPTY_PAYLOAD_RELPATH"
}

$PayloadPath = Join-Path $ArtifactDir ($rel.Replace('/','\'))
if(-not (Test-Path -LiteralPath $PayloadPath -PathType Leaf)){
  Die ("MISSING_PAYLOAD: " + $PayloadPath)
}

$actual = Sha256HexPath $PayloadPath
$expected = [string]$obj.payload_sha256
if($actual -ne $expected){
  Die ("PAYLOAD_SHA256_MISMATCH: expected=" + $expected + " actual=" + $actual)
}

$ReceiptPath = Join-Path $RepoRoot "proofs\receipts\lawvm.ndjson"
$Receipt = [pscustomobject]@{
  schema = "lawvm.receipt.v1"
  event = "lawvm.artifact.verify.v1"
  stamp_utc = $StampUtc
  repo_root = $RepoRoot
  artifact_dir = $ArtifactDir
  artifact_json_sha256 = (Sha256HexPath $ArtifactJsonPath)
  payload_sha256 = $actual
}
Append-Receipt $ReceiptPath (To-CanonJson $Receipt 32)

Write-Host ("VERIFY_ARTIFACT_OK: " + $ArtifactDir) -ForegroundColor Green
