param(
  [Parameter(Position=0)]
  [ValidateSet("help","version","init-project","eval","check","guard","selftest","verify-release")]
  [string]$Command = "help",
  [Parameter(Position=1)]
  [string]$Target = ".",
  [string]$Policy = "",
  [string]$Principal = "",
  [string]$Action = "",
  [string]$Namespace = "",
  [string]$Then = ""
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

function Invoke-Eval([string]$Req,[string]$Pol){
  $Eval = Join-Path $RepoRoot "scripts\evaluate_lawvm_v1.ps1"
  if(-not (Test-Path -LiteralPath $Eval -PathType Leaf)){ Die "MISSING_EVAL" $Eval }
  $args = @("-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass","-File",$Eval,"-RepoRoot",$RepoRoot,"-RequestPath",$Req)
  if(-not [string]::IsNullOrWhiteSpace($Pol)){ $args += @("-PolicyPath",$Pol) }
  $out = & $PSExe @args 2>&1
  $code = $LASTEXITCODE
  return @{ ExitCode = $code; Text = (@($out) -join "`n") }
}

$RepoRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path
$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
if(-not (Test-Path -LiteralPath $PSExe -PathType Leaf)){ Die "MISSING_POWERSHELL_EXE" $PSExe }

if($Command -eq "help"){
  Write-Host "LawVM - deterministic local policy decisions"
  Write-Host ""
  Write-Host "Core commands:"
  Write-Host "  .\lawvm.ps1 verify-release"
  Write-Host "  .\lawvm.ps1 init-project .\my-policy-project"
  Write-Host "  .\lawvm.ps1 eval .\my-policy-project"
  Write-Host ""
  Write-Host "Action gate commands:"
  Write-Host "  .\lawvm.ps1 check -Principal user.example -Action read -Policy .\my-policy-project\policy_bundle.json"
  Write-Host "  .\lawvm.ps1 check -Principal agent.local -Action write -Namespace repo.secrets -Policy .\examples\policies\protect-secrets.json"
  Write-Host "  .\lawvm.ps1 guard -Principal user.example -Action read -Policy .\my-policy-project\policy_bundle.json -Then ""echo allowed"""
  Write-Host ""
  Write-Host "Purpose: put LawVM before scripts, tools, agents, releases, or automations so policy decides before action happens."
  exit 0
}

if($Command -eq "version"){ Write-Host "LAWVM_VERSION 0.1.2-action-gate"; exit 0 }

if($Command -eq "init-project"){
  $Out = Resolve-UserPath $Target
  if([string]::IsNullOrWhiteSpace($Out)){ Die "EMPTY_TARGET" "init-project requires a target folder" }
  New-Item -ItemType Directory -Force -Path $Out | Out-Null
  $policyPath = Join-Path $Out "policy_bundle.json"
  $requestPath = Join-Path $Out "request.json"
  Write-Utf8NoBomLf $policyPath '{"schema":"lawvm.policy_bundle.v1","rules":[{"rule_id":"allow_read","effect":"allow","principal":"user.example","action":"read"},{"rule_id":"deny_delete","effect":"deny","principal":"user.example","action":"delete"}]}'
  Write-Utf8NoBomLf $requestPath '{"principal":"user.example","action":"read"}'
  Write-Host ("LAWVM_PROJECT_INIT_OK: " + $Out)
  Write-Host ("POLICY: " + $policyPath)
  Write-Host ("REQUEST: " + $requestPath)
  exit 0
}

if($Command -eq "eval"){
  $Req = Resolve-UserPath $Target
  if(-not (Test-Path -LiteralPath $Req -PathType Leaf)){
    if(Test-Path -LiteralPath $Req -PathType Container){
      $candidate = Join-Path $Req "request.json"
      if(Test-Path -LiteralPath $candidate -PathType Leaf){ $Req = $candidate }
      else{ Die "TARGET_IS_DIRECTORY" "Directory targets must contain request.json" }
    }else{ Die "MISSING_REQUEST" $Req }
  }
  $Pol = ""
  if(-not [string]::IsNullOrWhiteSpace($Policy)){
    $Pol = Resolve-UserPath $Policy
    if(-not (Test-Path -LiteralPath $Pol -PathType Leaf)){ Die "MISSING_POLICY" $Pol }
  }else{
    $dirPolicy = Join-Path (Split-Path -Parent $Req) "policy_bundle.json"
    if(Test-Path -LiteralPath $dirPolicy -PathType Leaf){ $Pol = $dirPolicy }
  }
  $result = Invoke-Eval $Req $Pol
  Write-Output $result.Text
  exit $result.ExitCode
}

if($Command -eq "check" -or $Command -eq "guard"){
  if([string]::IsNullOrWhiteSpace($Action)){ Die "MISSING_ACTION" "Use -Action <name>" }
  if([string]::IsNullOrWhiteSpace($Principal)){ $Principal = ("user." + [Environment]::UserName) }
  $Pol = ""
  if(-not [string]::IsNullOrWhiteSpace($Policy)){
    $Pol = Resolve-UserPath $Policy
  }else{
    $Pol = Join-Path $RepoRoot "examples\policy_bundle.json"
  }
  if(-not (Test-Path -LiteralPath $Pol -PathType Leaf)){ Die "MISSING_POLICY" $Pol }
  $TmpDir = Join-Path $RepoRoot "proofs\_tmp"
  New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null
  $Req = Join-Path $TmpDir ("lawvm_check_" + ([Guid]::NewGuid().ToString("N")) + ".json")
  $json = '{"principal":"' + ($Principal.Replace("\","\\").Replace("""","\""")) + '","action":"' + ($Action.Replace("\","\\").Replace("""","\""")) + '"'
  if(-not [string]::IsNullOrWhiteSpace($Namespace)){ $json += ',"namespace":"' + ($Namespace.Replace("\","\\").Replace("""","\""")) + '"' }
  $json += '}'
  Write-Utf8NoBomLf $Req $json
  $result = Invoke-Eval $Req $Pol
  Remove-Item -LiteralPath $Req -Force -ErrorAction SilentlyContinue
  Write-Output $result.Text
  if($result.ExitCode -ne 0){ exit $result.ExitCode }
  $decision = ""
  try{ $decision = [string](($result.Text | ConvertFrom-Json).decision) }catch{ Die "BAD_EVAL_OUTPUT" $result.Text }
  if($Command -eq "check"){
    if($decision -eq "ALLOW"){ exit 0 }
    exit 2
  }
  if($decision -ne "ALLOW"){ exit 2 }
  if([string]::IsNullOrWhiteSpace($Then)){ Die "MISSING_THEN" "guard requires -Then <command> when allowed" }
  & cmd.exe /c $Then
  exit $LASTEXITCODE
}

if($Command -eq "selftest" -or $Command -eq "verify-release"){
  $Runner = Join-Path $RepoRoot "scripts\_scratch\_RUN_lawvm_tier0_v1.ps1"
  if(-not (Test-Path -LiteralPath $Runner -PathType Leaf)){ Die "MISSING_RELEASE_RUNNER" $Runner }
  & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Runner -RepoRoot $RepoRoot
  exit $LASTEXITCODE
}
