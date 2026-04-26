param(
  [Parameter(Mandatory=$true)][string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){
  throw ("LAWVM_PATCH_FAIL: " + $m)
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
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){
    Die ("WRITE_FAILED: " + $Path)
  }
}

function Parse-GateFile([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){
    Die ("PARSEGATE_MISSING: " + $Path)
  }
  $tok = $null
  $err = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tok,[ref]$err)
  $errs = @(@($err))
  if($errs.Count -gt 0){
    $x = $errs[0]
    Die ("PARSE_GATE_FAIL: {0}:{1}:{2}: {3}" -f $Path,$x.Extent.StartLineNumber,$x.Extent.StartColumnNumber,$x.Message)
  }
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$ScriptsDir = Join-Path $RepoRoot "scripts"
$ScratchDir = Join-Path $ScriptsDir "_scratch"
$ExamplesDir = Join-Path $RepoRoot "examples"

foreach($d in @($ScriptsDir,$ScratchDir,$ExamplesDir)){
  if(-not (Test-Path -LiteralPath $d -PathType Container)){
    New-Item -ItemType Directory -Force -Path $d | Out-Null
  }
}

$EvalSelfPath = Join-Path $ScriptsDir "_selftest_lawvm_eval_v1.ps1"
$FullGreenPath = Join-Path $ScratchDir "_RUN_lawvm_full_green_v1.ps1"

$EvalSelfText = @'
param(
  [Parameter(Mandatory=$true)][string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){
  throw ("LAWVM_EVAL_SELFTEST_FAIL:" + $m)
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

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
$Eval = Join-Path $RepoRoot "scripts\evaluate_lawvm_v1.ps1"

if(-not (Test-Path -LiteralPath $PSExe -PathType Leaf)){
  Die "MISSING_POWERSHELL_EXE"
}
if(-not (Test-Path -LiteralPath $Eval -PathType Leaf)){
  Die "MISSING_EVAL"
}

$Examples = Join-Path $RepoRoot "examples"
if(-not (Test-Path -LiteralPath $Examples -PathType Container)){
  New-Item -ItemType Directory -Force -Path $Examples | Out-Null
}

$PolicyPath = Join-Path $Examples "policy_bundle.json"
$PolicyText = @'
{
  "schema": "lawvm.policy_bundle.v1",
  "rules": [
    {
      "rule_id": "allow_read",
      "effect": "allow",
      "principal": "user.alec",
      "action": "read"
    },
    {
      "rule_id": "deny_delete",
      "effect": "deny",
      "principal": "user.alec",
      "action": "delete"
    }
  ]
}
