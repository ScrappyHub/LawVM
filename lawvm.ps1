param(
  [Parameter(Mandatory=$true)]
  [ValidateSet("help","version","init-project","eval","selftest")]
  [string]$Command,
  [string]$Target = ".",
  [string]$Policy = ""
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){ throw ("LAWVM_CLI_FAIL:" + $m) }

$RepoRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path
$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
if(-not (Test-Path -LiteralPath $PSExe -PathType Leaf)){ Die "MISSING_POWERSHELL_EXE" }

if($Command -eq "help"){
  Write-Host "LAWVM CLI"
  Write-Host "  .\lawvm.ps1 selftest"
  Write-Host "  .\lawvm.ps1 init-project .\my-project"
  Write-Host "  .\lawvm.ps1 eval .\examples\request_allow.json"
  Write-Host "  .\lawvm.ps1 eval .\my-project\request.json -Policy .\my-project\policy_bundle.json"
  exit 0
}

if($Command -eq "version"){ Write-Host "LAWVM_VERSION 0.1.0-tier0"; exit 0 }

if($Command -eq "init-project"){
  $Out = $Target
  if(-not [System.IO.Path]::IsPathRooted($Out)){ $Out = Join-Path (Get-Location).Path $Out }
  New-Item -ItemType Directory -Force -Path $Out | Out-Null
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText((Join-Path $Out "policy_bundle.json"),'{"schema":"lawvm.policy_bundle.v1","rules":[{"rule_id":"allow_read","effect":"allow","principal":"user.example","action":"read"},{"rule_id":"deny_delete","effect":"deny","principal":"user.example","action":"delete"}]}' + "`n",$enc)
  [System.IO.File]::WriteAllText((Join-Path $Out "request.json"),'{"principal":"user.example","action":"read"}' + "`n",$enc)
  Write-Host ("LAWVM_PROJECT_INIT_OK: " + $Out)
  exit 0
}

if($Command -eq "eval"){
  $Eval = Join-Path $RepoRoot "scripts\evaluate_lawvm_v1.ps1"
  if(-not (Test-Path -LiteralPath $Eval -PathType Leaf)){ Die "MISSING_EVAL" }
  $Req = $Target
  if(-not [System.IO.Path]::IsPathRooted($Req)){ $Req = Join-Path (Get-Location).Path $Req }
  $args = @("-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass","-File",$Eval,"-RepoRoot",$RepoRoot,"-RequestPath",$Req)
  if(-not [string]::IsNullOrWhiteSpace($Policy)){
    if(-not [System.IO.Path]::IsPathRooted($Policy)){ $Policy = Join-Path (Get-Location).Path $Policy }
    $args += @("-PolicyPath",$Policy)
  }
  & $PSExe @args
  exit $LASTEXITCODE
}

if($Command -eq "selftest"){
  $Runner = Join-Path $RepoRoot "scripts\_scratch\_RUN_lawvm_tier0_v1.ps1"
  if(-not (Test-Path -LiteralPath $Runner -PathType Leaf)){ Die "MISSING_TIER0_RUNNER" }
  & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Runner -RepoRoot $RepoRoot
  exit $LASTEXITCODE
}
