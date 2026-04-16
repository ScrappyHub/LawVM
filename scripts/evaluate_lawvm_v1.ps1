param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$RequestPath,
  [string]$PolicyPath = "",
  [string]$SigPath = "",
  [string]$AllowedSignersPath = "",
  [string]$Namespace = "lawvm/policy-bundle"
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){
  throw ("LAWVM_EVAL_FAIL: " + $m)
}

function Read-Utf8([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){
    Die ("MISSING_FILE: " + $Path)
  }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::ReadAllText($Path,$enc)
}

function Emit-Decision([string]$Decision,[string]$Reason){
  Write-Output ('{"decision":"' + $Decision + '","reason_code":"' + $Reason + '"}')
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$RequestPath = (Resolve-Path -LiteralPath $RequestPath).Path

$VerifySig = Join-Path $RepoRoot "scripts\verify_policy_bundle_sig_v1.ps1"
if(-not (Test-Path -LiteralPath $VerifySig -PathType Leaf)){
  Die ("MISSING_VERIFY_SIG_SCRIPT: " + $VerifySig)
}

$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
if(-not (Test-Path -LiteralPath $PSExe -PathType Leaf)){
  Die ("MISSING_POWERSHELL_EXE: " + $PSExe)
}

$verifyArgs = New-Object System.Collections.Generic.List[string]
[void]$verifyArgs.Add("-NoProfile")
[void]$verifyArgs.Add("-NonInteractive")
[void]$verifyArgs.Add("-ExecutionPolicy")
[void]$verifyArgs.Add("Bypass")
[void]$verifyArgs.Add("-File")
[void]$verifyArgs.Add($VerifySig)
[void]$verifyArgs.Add("-RepoRoot")
[void]$verifyArgs.Add($RepoRoot)

if(-not [string]::IsNullOrWhiteSpace($PolicyPath)){
  [void]$verifyArgs.Add("-PolicyPath")
  [void]$verifyArgs.Add($PolicyPath)
}
if(-not [string]::IsNullOrWhiteSpace($SigPath)){
  [void]$verifyArgs.Add("-SigPath")
  [void]$verifyArgs.Add($SigPath)
}
if(-not [string]::IsNullOrWhiteSpace($AllowedSignersPath)){
  [void]$verifyArgs.Add("-AllowedSignersPath")
  [void]$verifyArgs.Add($AllowedSignersPath)
}
if(-not [string]::IsNullOrWhiteSpace($Namespace)){
  [void]$verifyArgs.Add("-Namespace")
  [void]$verifyArgs.Add($Namespace)
}

$doVerify = $false
if(
  -not [string]::IsNullOrWhiteSpace($SigPath) -or
  -not [string]::IsNullOrWhiteSpace($AllowedSignersPath)
){
  $doVerify = $true
}

if($doVerify){
  $outFile = Join-Path $env:TEMP "lawvm_eval_verify_stdout.txt"
  $errFile = Join-Path $env:TEMP "lawvm_eval_verify_stderr.txt"

  if(Test-Path -LiteralPath $outFile){ Remove-Item -LiteralPath $outFile -Force }
  if(Test-Path -LiteralPath $errFile){ Remove-Item -LiteralPath $errFile -Force }

  $proc = Start-Process -FilePath $PSExe `
    -ArgumentList @($verifyArgs.ToArray()) `
    -Wait `
    -PassThru `
    -NoNewWindow `
    -RedirectStandardOutput $outFile `
    -RedirectStandardError $errFile

  if($proc.ExitCode -ne 0){
    Emit-Decision "DENY" "POLICY_SIG_INVALID"
    return
  }
}

$policyResolved = $PolicyPath
if([string]::IsNullOrWhiteSpace($policyResolved)){
  $policyResolved = Join-Path $RepoRoot "policies\policy_bundle.json"
}
$policyResolved = (Resolve-Path -LiteralPath $policyResolved).Path

$policy = (Read-Utf8 $policyResolved) | ConvertFrom-Json
$request = (Read-Utf8 $RequestPath) | ConvertFrom-Json

$matched = $false
$decision = "DENY"
$reason = "NO_MATCH"

foreach($rule in @($policy.rules)){
  $rulePrincipal = [string]$rule.principal
  $ruleAction = [string]$rule.action
  $ruleNamespace = [string]$rule.namespace
  $ruleEffect = [string]$rule.effect

  if(
    $rulePrincipal -eq [string]$request.principal -and
    $ruleAction -eq [string]$request.action -and
    $ruleNamespace -eq [string]$request.namespace
  ){
    $matched = $true

    if($ruleEffect -eq "deny"){
      $decision = "DENY"
      $reason = "RULE_DENY"
      break
    }

    if($ruleEffect -eq "allow"){
      $decision = "ALLOW"
      $reason = "RULE_ALLOW"
    }
  }
}

if(-not $matched){
  $decision = "DENY"
  $reason = "NO_MATCH"
}

Emit-Decision $decision $reason
