param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$RequestPath,
  [string]$PolicyPath = ""
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){ throw ("LAWVM_EVAL_FAIL:" + $m) }

function Read-Utf8([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ Die ("MISSING_FILE:" + $Path) }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::ReadAllText($Path,$enc)
}

function Has-Prop([object]$Obj,[string]$Name){
  if($null -eq $Obj){ return $false }
  return (@($Obj.PSObject.Properties | ForEach-Object { $_.Name }) -contains $Name)
}

function Get-Str([object]$Obj,[string]$Name){
  if(Has-Prop $Obj $Name){
    $v = $Obj.PSObject.Properties[$Name].Value
    if($null -ne $v){ return [string]$v }
  }
  return ""
}

function Emit([string]$Decision,[string]$ReasonCode){
  Write-Output ('{"decision":"' + $Decision + '","reason_code":"' + $ReasonCode + '"}')
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$RequestPath = (Resolve-Path -LiteralPath $RequestPath).Path
if([string]::IsNullOrWhiteSpace($PolicyPath)){
  $PolicyPath = Join-Path $RepoRoot "examples\policy_bundle.json"
}
$PolicyPath = (Resolve-Path -LiteralPath $PolicyPath).Path

$policy = (Read-Utf8 $PolicyPath) | ConvertFrom-Json
$request = (Read-Utf8 $RequestPath) | ConvertFrom-Json

$reqPrincipal = Get-Str $request "principal"
$reqAction = Get-Str $request "action"
$reqNamespace = Get-Str $request "namespace"

if([string]::IsNullOrWhiteSpace($reqAction)){ Die "MISSING_ACTION" }

$matched = $false
$decision = "DENY"
$reason = "NO_MATCH"

foreach($rule in @($policy.rules)){
  $effect = Get-Str $rule "effect"
  $action = Get-Str $rule "action"
  $principal = Get-Str $rule "principal"
  $namespace = Get-Str $rule "namespace"

  if([string]::IsNullOrWhiteSpace($action)){ continue }
  if($action -ne $reqAction){ continue }

  if((-not [string]::IsNullOrWhiteSpace($principal)) -and ($principal -ne $reqPrincipal)){ continue }
  if((-not [string]::IsNullOrWhiteSpace($namespace)) -and ($namespace -ne $reqNamespace)){ continue }

  $matched = $true
  if($effect -eq "deny"){ Emit "DENY" "RULE_DENY"; return }
  if($effect -eq "allow"){ $decision = "ALLOW"; $reason = "RULE_ALLOW" }
}

if(-not $matched){ Emit "DENY" "NO_MATCH"; return }
Emit $decision $reason
