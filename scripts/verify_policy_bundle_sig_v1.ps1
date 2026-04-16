param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$PolicyPath = "",
  [string]$SigPath = "",
  [string]$AllowedSignersPath = "",
  [string]$Namespace = "lawvm/policy-bundle",
  [string]$Principal = "*"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){
  throw ("POLICY_SIG_INVALID:" + $m)
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

if([string]::IsNullOrWhiteSpace($PolicyPath)){
  $PolicyPath = Join-Path $RepoRoot "policies\policy_bundle.json"
}else{
  $PolicyPath = (Resolve-Path -LiteralPath $PolicyPath).Path
}

if([string]::IsNullOrWhiteSpace($SigPath)){
  $SigPath = Join-Path $RepoRoot "policies\policy_bundle.sig"
}else{
  $SigPath = (Resolve-Path -LiteralPath $SigPath).Path
}

if([string]::IsNullOrWhiteSpace($AllowedSignersPath)){
  $AllowedSignersPath = Join-Path $RepoRoot "proofs\trust\allowed_signers"
}else{
  $AllowedSignersPath = (Resolve-Path -LiteralPath $AllowedSignersPath).Path
}

if(-not (Test-Path -LiteralPath $PolicyPath -PathType Leaf)){
  Die "MISSING_POLICY"
}

if(-not (Test-Path -LiteralPath $SigPath -PathType Leaf)){
  Die "MISSING_SIG"
}

if(-not (Test-Path -LiteralPath $AllowedSignersPath -PathType Leaf)){
  Die "MISSING_ALLOWED_SIGNERS"
}

$ssh = Join-Path $env:WINDIR "System32\OpenSSH\ssh-keygen.exe"
if(-not (Test-Path -LiteralPath $ssh -PathType Leaf)){
  Die "MISSING_SSH_KEYGEN"
}

$outFile = Join-Path $env:TEMP "lawvm_verify_sig.stdout.txt"
$errFile = Join-Path $env:TEMP "lawvm_verify_sig.stderr.txt"

if(Test-Path -LiteralPath $outFile){ Remove-Item -LiteralPath $outFile -Force }
if(Test-Path -LiteralPath $errFile){ Remove-Item -LiteralPath $errFile -Force }

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $ssh
$psi.Arguments = ('-Y verify -f "{0}" -I "{1}" -n "{2}" -s "{3}"' -f $AllowedSignersPath,$Principal,$Namespace,$SigPath)
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.CreateNoWindow = $true

$p = New-Object System.Diagnostics.Process
$p.StartInfo = $psi
[void]$p.Start()

$policyText = [System.IO.File]::ReadAllText($PolicyPath, (New-Object System.Text.UTF8Encoding($false)))
$p.StandardInput.Write($policyText)
$p.StandardInput.Close()

$stdout = $p.StandardOutput.ReadToEnd()
$stderr = $p.StandardError.ReadToEnd()
$p.WaitForExit()

$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outFile,$stdout,$enc)
[System.IO.File]::WriteAllText($errFile,$stderr,$enc)

if($p.ExitCode -ne 0){
  $msg = $stderr.Trim()
  if([string]::IsNullOrWhiteSpace($msg)){ $msg = $stdout.Trim() }
  if([string]::IsNullOrWhiteSpace($msg)){ $msg = "SIG_VERIFY_FAIL" }
  Die ("SIG_VERIFY_FAIL:" + $msg)
}

Write-Host "POLICY_SIG_VERIFY_OK" -ForegroundColor Green
