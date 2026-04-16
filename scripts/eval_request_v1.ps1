Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$RequestJsonPath,
  [switch]$VerifyPolicySig
)

. (Join-Path $PSScriptRoot "_lib_lawvm_v1.ps1")

if($VerifyPolicySig){
  $ok = LAWVM-VerifyPolicySig $RepoRoot
  if(-not $ok){ throw "LAWVM_FAIL: VerifyPolicySig requested but policies/policy_bundle.sig missing." }
}

$raw = LAWVM-ReadUtf8 $RequestJsonPath
$req = $raw | ConvertFrom-Json -Depth 64
if($req.schema -ne "lawvm.request.v1"){ throw ("LAWVM_FAIL: bad request schema: " + $req.schema) }

$dec = LAWVM-Evaluate -RepoRoot $RepoRoot -Req $req

$receipt = @{
  schema="lawvm.receipt.v1"
  kind="policy_decision"
  created_utc=(Get-Date).ToUniversalTime().ToString("o")
  request_sha256=LAWVM-Sha256HexPath $RequestJsonPath
  policy_sha256=$dec.policy_sha256
  decision=$dec.decision
  principal=$dec.principal
  action=$dec.action
  namespace=$dec.namespace
  allow_rules=$dec.allow_rules
  deny_rules=$dec.deny_rules
}
LAWVM-AppendReceipt -RepoRoot $RepoRoot -Receipt $receipt

Write-Output (LAWVM-ToCanonJson $dec 64)
