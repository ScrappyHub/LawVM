Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$PrivateKeyPath
)

. (Join-Path $PSScriptRoot "_lib_lawvm_v1.ps1")

function Die([string]$m){ throw ("LAWVM_SIGN_FAIL: " + $m) }

$ssh = Get-Command ssh-keygen -ErrorAction SilentlyContinue
if(-not $ssh){ Die "Missing ssh-keygen in PATH" }

$bundle = LAWVM-PPolicy $RepoRoot
if(-not (Test-Path -LiteralPath $bundle -PathType Leaf)){ Die ("Missing policy bundle: " + $bundle) }

$pol = LAWVM-LoadPolicy $bundle
$principal = [string]$pol.signer_principal
LAWVM-ValidatePrincipal $principal

$ns = "lawvm/policy-bundle"
LAWVM-ValidateNamespace $ns

if(-not (Test-Path -LiteralPath $PrivateKeyPath -PathType Leaf)){ Die ("Missing PrivateKeyPath: " + $PrivateKeyPath) }

$sig = LAWVM-PPolicySig $RepoRoot

# ssh-keygen -Y sign -f <key> -I <principal> -n <namespace> <file>
& ssh-keygen -Y sign -f $PrivateKeyPath -I $principal -n $ns $bundle | Out-Null

# ssh-keygen writes <file>.sig in the same dir
$expectedSig = ($bundle + ".sig")
if(-not (Test-Path -LiteralPath $expectedSig -PathType Leaf)){ Die ("Expected sig missing: " + $expectedSig) }

Move-Item -LiteralPath $expectedSig -Destination $sig -Force

Write-Output ("SIG_OK: " + $sig)
