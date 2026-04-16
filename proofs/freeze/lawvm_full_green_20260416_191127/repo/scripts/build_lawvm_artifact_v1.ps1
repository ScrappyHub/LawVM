Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path -LiteralPath "C:\dev\lawvm").Path
$ScriptsDir = Join-Path $RepoRoot "scripts"
if(-not (Test-Path -LiteralPath $ScriptsDir -PathType Container)){
  New-Item -ItemType Directory -Force -Path $ScriptsDir | Out-Null
}

function Write-Utf8NoBomLf([string]$Path,[string]$Text){
  $dir = Split-Path -Parent $Path
  if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $t = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path,$t,$enc)
}

function Parse-GateFile([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){
    throw ("PARSEGATE_MISSING: " + $Path)
  }
  $tok = $null
  $err = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tok,[ref]$err)
  $errs = @(@($err))
  if($errs.Count -gt 0){
    $x = $errs[0]
    throw ("PARSE_GATE_FAIL: {0}:{1}:{2}: {3}" -f $Path,$x.Extent.StartLineNumber,$x.Extent.StartColumnNumber,$x.Message)
  }
}

$BuildPath = Join-Path $ScriptsDir "build_lawvm_artifact_v1.ps1"
$txt = @'
param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$OutDir,
  [string]$StampUtc = "2026-02-22T00:00:00Z"
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){
  throw ("LAWVM_BUILD_FAIL: " + $m)
}

function EnsureDir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){
    Die "ENSUREDIR_EMPTY"
  }
  if(-not (Test-Path -LiteralPath $p -PathType Container)){
    New-Item -ItemType Directory -Force -Path $p | Out-Null
  }
}

function Write-Utf8NoBomLf([string]$Path,[string]$Text){
  $dir = Split-Path -Parent $Path
  if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $t = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path,$t,$enc)
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
EnsureDir $OutDir
$OutDir = (Resolve-Path -LiteralPath $OutDir).Path

$PayloadDir = Join-Path $OutDir "payload"
EnsureDir $PayloadDir

$LawTxt = Join-Path $PayloadDir "law.txt"
$LawText = @'
LAWVM minimal machine law artifact
default posture: deny by default
tier: 0
surface: deterministic artifact proof
'@
Write-Utf8NoBomLf $LawTxt $LawText

$PayloadHash = Sha256HexPath $LawTxt

$ArtifactJsonPath = Join-Path $OutDir "artifact.json"
$Artifact = [pscustomobject]@{
  schema = "lawvm.artifact.v1"
  artifact_type = "machine_law_bundle"
  stamp_utc = $StampUtc
  payload_relpath = "payload/law.txt"
  payload_sha256 = $PayloadHash
}
Write-Utf8NoBomLf $ArtifactJsonPath (To-CanonJson $Artifact 32)

$ReceiptPath = Join-Path $RepoRoot "proofs\receipts\lawvm.ndjson"
$Receipt = [pscustomobject]@{
  schema = "lawvm.receipt.v1"
  event = "lawvm.artifact.build.v1"
  stamp_utc = $StampUtc
  repo_root = $RepoRoot
  artifact_dir = $OutDir
  artifact_json_sha256 = (Sha256HexPath $ArtifactJsonPath)
  payload_sha256 = $PayloadHash
}
Append-Receipt $ReceiptPath (To-CanonJson $Receipt 32)

Write-Host ("BUILD_ARTIFACT_OK: " + $OutDir) -ForegroundColor Green
'@

Write-Utf8NoBomLf $BuildPath $txt
Parse-GateFile $BuildPath
Write-Host ("WROTE+PARSE_OK: " + $BuildPath) -ForegroundColor Green