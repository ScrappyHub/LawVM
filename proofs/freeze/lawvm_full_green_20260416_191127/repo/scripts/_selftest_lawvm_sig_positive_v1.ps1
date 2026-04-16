param(
  [Parameter(Mandatory=$true)][string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){
  throw ("LAWVM_SIG_POS_FAIL:" + $m)
}

function EnsureDir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ Die "ENSUREDIR_EMPTY" }
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

function Read-Utf8([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){
    Die ("MISSING_FILE: " + $Path)
  }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::ReadAllText($Path,$enc)
}

function Invoke-NativeDeterministic([string]$Exe,[string]$Arguments,[string]$StdoutPath,[string]$StderrPath,[string]$StdinPath){
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $Exe
  $psi.Arguments = $Arguments
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.RedirectStandardInput = $false
  $psi.CreateNoWindow = $true

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  [void]$p.Start()
  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()

  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($StdoutPath,$stdout,$enc)
  [System.IO.File]::WriteAllText($StderrPath,$stderr,$enc)

  return $p.ExitCode
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$Ssh = Join-Path $env:WINDIR "System32\OpenSSH\ssh-keygen.exe"
if(-not (Test-Path -LiteralPath $Ssh -PathType Leaf)){
  Die "MISSING_SSH_KEYGEN"
}

$Work = Join-Path $RepoRoot "test_vectors\sig_positive_v1"
if(Test-Path -LiteralPath $Work){
  Remove-Item -LiteralPath $Work -Recurse -Force
}
EnsureDir $Work

$Key = Join-Path $Work "signer_ed25519"
$Pub = $Key + ".pub"
$Policy = Join-Path $Work "policy.json"
$SigGenerated = $Policy + ".sig"
$Allowed = Join-Path $Work "allowed_signers"

$keyOut = Join-Path $Work "_keygen.stdout.txt"
$keyErr = Join-Path $Work "_keygen.stderr.txt"
$signOut = Join-Path $Work "_sign.stdout.txt"
$signErr = Join-Path $Work "_sign.stderr.txt"

$keyArgs = '-q -t ed25519 -N "" -f "' + $Key + '"'
$keyExit = Invoke-NativeDeterministic -Exe $Ssh -Arguments $keyArgs -StdoutPath $keyOut -StderrPath $keyErr -StdinPath ""
if($keyExit -ne 0){
  Die ("KEYGEN:" + (Read-Utf8 $keyErr).Trim())
}

if(-not (Test-Path -LiteralPath $Key -PathType Leaf)){ Die "MISSING_PRIVATE_KEY" }
if(-not (Test-Path -LiteralPath $Pub -PathType Leaf)){ Die "MISSING_PUBLIC_KEY" }

$policyText = '{"schema":"lawvm.policy_bundle.v1","rules":[{"rule_id":"allow-docs","effect":"allow","principal":"user.alec","action":"read","namespace":"docs"}]}'
Write-Utf8NoBomLf $Policy $policyText

$pubText = Read-Utf8 $Pub
$pubLine = ($pubText -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
if([string]::IsNullOrWhiteSpace($pubLine)){ Die "EMPTY_PUBKEY" }

$allowedLine = 'lawvm_selftest namespaces="lawvm/policy-bundle" ' + $pubLine
Write-Utf8NoBomLf $Allowed $allowedLine

$signArgs = '-Y sign -f "' + $Key + '" -n lawvm/policy-bundle "' + $Policy + '"'
$signExit = Invoke-NativeDeterministic -Exe $Ssh -Arguments $signArgs -StdoutPath $signOut -StderrPath $signErr -StdinPath ""
if($signExit -ne 0){
  Die ("SIGN:" + (Read-Utf8 $signErr).Trim())
}

if(-not (Test-Path -LiteralPath $SigGenerated -PathType Leaf)){
  Die "MISSING_GENERATED_SIG"
}

$Verify = Join-Path $RepoRoot "scripts\verify_policy_bundle_sig_v1.ps1"
$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
if(-not (Test-Path -LiteralPath $Verify -PathType Leaf)){ Die "MISSING_VERIFY_SCRIPT" }
if(-not (Test-Path -LiteralPath $PSExe -PathType Leaf)){ Die "MISSING_POWERSHELL_EXE" }

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Verify `
  -RepoRoot $RepoRoot `
  -PolicyPath $Policy `
  -SigPath $SigGenerated `
  -AllowedSignersPath $Allowed `
  -Namespace "lawvm/policy-bundle" -Principal "lawvm_selftest" | Out-Host

if($LASTEXITCODE -ne 0){
  Die "VERIFY"
}

Write-Host "LAWVM_SIG_POSITIVE_SELFTEST_OK" -ForegroundColor Green
