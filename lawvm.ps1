param(
  [Parameter(Position=0)]
  [ValidateSet("help","version","init-project","eval","selftest","verify-release")]
  [string]$Command = "help",
  [Parameter(Position=1)]
  [string]$Target = ".",
  [string]$Policy = ""
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$Code,[string]$Message){
  [Console]::Error.WriteLine(("LAWVM_CLI_FAIL:{0}: {1}" -f $Code,$Message))
  exit 1
}

function Resolve-UserPath([string]$Path){
  if([string]::IsNullOrWhiteSpace($Path)){ return "" }
  if([System.IO.Path]::IsPathRooted($Path)){ return $Path }
  return (Join-Path (Get-Location).Path $Path)
}

$RepoRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path
$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
if(-not (Test-Path -LiteralPath $PSExe -PathType Leaf)){ Die "MISSING_POWERSHELL_EXE" $PSExe }

if($Command -eq "help"){
  Write-Host "LawVM - deterministic local policy decisions"
  Write-Host ""
  Write-Host "Commands:"
  Write-Host "  .\lawvm.ps1 help"
  Write-Host "  .\lawvm.ps1 version"
  Write-Host "  .\lawvm.ps1 selftest"
  Write-Host "  .\lawvm.ps1 verify-release"
  Write-Host "  .\lawvm.ps1 init-project .\my-policy-project"
  Write-Host "  .\lawvm.ps1 eval .\my-policy-project"
  Write-Host "  .\lawvm.ps1 eval .\my-policy-project\request.json -Policy .\my-policy-project\policy_bundle.json"
  Write-Host ""
  Write-Host "Use LawVM when you need a local allow/deny decision from a policy file and a request file."
  Write-Host "Docs: docs\CLI.md, docs\USAGE.md, docs\THREAT_MODEL.md, docs\WHO_IS_THIS_FOR.md"
  exit 0
}

if($Command -eq "version"){ Write-Host "LAWVM_VERSION 0.1.1-cli"; exit 0 }

if($Command -eq "init-project"){
  $Out = Resolve-UserPath $Target
  if([string]::IsNullOrWhiteSpace($Out)){ Die "EMPTY_TARGET" "init-project requires a target folder" }
  New-Item -ItemType Directory -Force -Path $Out | Out-Null
  $enc = New-Object System.Text.UTF8Encoding($false)
  $policyPath = Join-Path $Out "policy_bundle.json"
  $requestPath = Join-Path $Out "request.json"
  $policyJson = '{"schema":"lawvm.policy_bundle.v1","rules":[{"rule_id":"allow_read","effect":"allow","principal":"user.example","action":"read"},{"rule_id":"deny_delete","effect":"deny","principal":"user.example","action":"delete"}]}' + "`n"
  $requestJson = '{"principal":"user.example","action":"read"}' + "`n"
  [System.IO.File]::WriteAllText($policyPath,$policyJson,$enc)
  [System.IO.File]::WriteAllText($requestPath,$requestJson,$enc)
  Write-Host ("LAWVM_PROJECT_INIT_OK: " + $Out)
  Write-Host ("POLICY: " + $policyPath)
  Write-Host ("REQUEST: " + $requestPath)
  exit 0
}

if($Command -eq "eval"){
  $Eval = Join-Path $RepoRoot "scripts\evaluate_lawvm_v1.ps1"
  if(-not (Test-Path -LiteralPath $Eval -PathType Leaf)){ Die "MISSING_EVAL" $Eval }
  $Req = Resolve-UserPath $Target
  if(-not (Test-Path -LiteralPath $Req -PathType Leaf)){
    if(Test-Path -LiteralPath $Req -PathType Container){
      $candidate = Join-Path $Req "request.json"
      if(Test-Path -LiteralPath $candidate -PathType Leaf){ $Req = $candidate }
      else{ Die "TARGET_IS_DIRECTORY" "Directory targets must contain request.json" }
    }else{ Die "MISSING_REQUEST" $Req }
  }
  $args = @("-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass","-File",$Eval,"-RepoRoot",$RepoRoot,"-RequestPath",$Req)
  if(-not [string]::IsNullOrWhiteSpace($Policy)){
    $PolicyPath = Resolve-UserPath $Policy
    if(-not (Test-Path -LiteralPath $PolicyPath -PathType Leaf)){ Die "MISSING_POLICY" $PolicyPath }
    $args += @("-PolicyPath",$PolicyPath)
  }else{
    $dirPolicy = Join-Path (Split-Path -Parent $Req) "policy_bundle.json"
    if(Test-Path -LiteralPath $dirPolicy -PathType Leaf){ $args += @("-PolicyPath",$dirPolicy) }
  }
  & $PSExe @args
  exit $LASTEXITCODE
}

if($Command -eq "selftest" -or $Command -eq "verify-release"){
  $Runner = Join-Path $RepoRoot "scripts\_scratch\_RUN_lawvm_tier0_v1.ps1"
  if(-not (Test-Path -LiteralPath $Runner -PathType Leaf)){ Die "MISSING_RELEASE_RUNNER" $Runner }
  & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Runner -RepoRoot $RepoRoot
  exit $LASTEXITCODE
}
