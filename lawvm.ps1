param(
  [Parameter(Position=0)]
  [ValidateSet("help","version","init-project","eval","check","guard","receipts","selftest","verify-release")]
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
  if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $t = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path,$t,$enc)
}

function JsonEscape([string]$s){
  if($null -eq $s){ return "" }
  $bs = [string][char]92
  $dq = [string][char]34
  $r = $s.Replace($bs,($bs+$bs)).Replace($dq,($bs+$dq))
  $r = $r.Replace("`r","\r").Replace("`n","\n").Replace("`t","\t")
  return $r
}

function Sha256HexPath([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ return "" }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $fs = [System.IO.File]::OpenRead($Path)
  try{
    $h = $sha.ComputeHash($fs)
    return (($h | ForEach-Object { $_.ToString("x2") }) -join "")
  } finally {
    $fs.Dispose()
    $sha.Dispose()
  }
}

function Append-DecisionReceipt([string]$PolicyPath,[string]$RequestPath,[string]$Decision,[string]$ReasonCode,[string]$Principal,[string]$Action,[string]$Namespace,[string]$Mode){
  $ReceiptPath = Join-Path $RepoRoot "proofs\receipts\lawvm.decisions.ndjson"
  $dir = Split-Path -Parent $ReceiptPath
  if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $stamp = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
  $line = "{""schema"":""lawvm.decision.receipt.v1"",""event"":""lawvm.decision"",""stamp_utc"":""" + $stamp + """,""mode"":""" + (JsonEscape $Mode) + """,""principal"":""" + (JsonEscape $Principal) + """,""action"":""" + (JsonEscape $Action) + """,""namespace"":""" + (JsonEscape $Namespace) + """,""decision"":""" + (JsonEscape $Decision) + """,""reason_code"":""" + (JsonEscape $ReasonCode) + """,""policy_sha256"":""" + (Sha256HexPath $PolicyPath) + """,""request_sha256"":""" + (Sha256HexPath $RequestPath) + """}"
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::AppendAllText($ReceiptPath,($line + "`n"),$enc)
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
  Write-Host "LawVM - deterministic local policy decisions and action gates"
  Write-Host ""
  Write-Host "Commands:"
  Write-Host "  .\lawvm.ps1 verify-release"
  Write-Host "  .\lawvm.ps1 init-project .\my-policy-project"
  Write-Host "  .\lawvm.ps1 eval .\my-policy-project"
  Write-Host "  .\lawvm.ps1 check -Principal user.example -Action read -Policy .\my-policy-project\policy_bundle.json"
  Write-Host "  .\lawvm.ps1 guard -Principal user.example -Action read -Policy .\my-policy-project\policy_bundle.json -Then ""echo allowed"""
  Write-Host "  .\lawvm.ps1 receipts"
  exit 0
}

if($Command -eq "version"){ Write-Host "LAWVM_VERSION 0.1.3-decision-receipts"; exit 0 }

if($Command -eq "receipts"){
  $ReceiptPath = Join-Path $RepoRoot "proofs\receipts\lawvm.decisions.ndjson"
  if(Test-Path -LiteralPath $ReceiptPath -PathType Leaf){ Write-Host $ReceiptPath; Get-Content -LiteralPath $ReceiptPath -Tail 20 }
  else{ Write-Host ("NO_DECISION_RECEIPTS_YET: " + $ReceiptPath) }
  exit 0
}

if($Command -eq "init-project"){
  $Out = Resolve-UserPath $Target
  if([string]::IsNullOrWhiteSpace($Out)){ Die "EMPTY_TARGET" "init-project requires a target folder" }
  New-Item -ItemType Directory -Force -Path $Out | Out-Null
  Write-Utf8NoBomLf (Join-Path $Out "policy_bundle.json") '{"schema":"lawvm.policy_bundle.v1","rules":[{"rule_id":"allow_read","effect":"allow","principal":"user.example","action":"read"},{"rule_id":"deny_delete","effect":"deny","principal":"user.example","action":"delete"}]}'
  Write-Utf8NoBomLf (Join-Path $Out "request.json") '{"principal":"user.example","action":"read"}'
  Write-Host ("LAWVM_PROJECT_INIT_OK: " + $Out)
  exit 0
}

if($Command -eq "eval"){
  $Req = Resolve-UserPath $Target
  if(-not (Test-Path -LiteralPath $Req -PathType Leaf)){
    if(Test-Path -LiteralPath $Req -PathType Container){
      $candidate = Join-Path $Req "request.json"
      if(Test-Path -LiteralPath $candidate -PathType Leaf){ $Req = $candidate } else{ Die "TARGET_IS_DIRECTORY" "Directory targets must contain request.json" }
    }else{ Die "MISSING_REQUEST" $Req }
  }
  $Pol = ""
  if(-not [string]::IsNullOrWhiteSpace($Policy)){ $Pol = Resolve-UserPath $Policy }
  else{ $dirPolicy = Join-Path (Split-Path -Parent $Req) "policy_bundle.json"; if(Test-Path -LiteralPath $dirPolicy -PathType Leaf){ $Pol = $dirPolicy } }
  if(-not [string]::IsNullOrWhiteSpace($Pol) -and -not (Test-Path -LiteralPath $Pol -PathType Leaf)){ Die "MISSING_POLICY" $Pol }
  $result = Invoke-Eval $Req $Pol
  Write-Output $result.Text
  exit $result.ExitCode
}

if($Command -eq "check" -or $Command -eq "guard"){
  if([string]::IsNullOrWhiteSpace($Action)){ Die "MISSING_ACTION" "Use -Action <name>" }
  if([string]::IsNullOrWhiteSpace($Principal)){ $Principal = ("user." + [Environment]::UserName) }
  if(-not [string]::IsNullOrWhiteSpace($Policy)){ $Pol = Resolve-UserPath $Policy } else{ $Pol = Join-Path $RepoRoot "examples\policy_bundle.json" }
  if(-not (Test-Path -LiteralPath $Pol -PathType Leaf)){ Die "MISSING_POLICY" $Pol }
  $TmpDir = Join-Path $RepoRoot "proofs\_tmp"
  New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null
  $Req = Join-Path $TmpDir ("lawvm_check_" + ([Guid]::NewGuid().ToString("N")) + ".json")
  $json = "{""principal"":""" + (JsonEscape $Principal) + """,""action"":""" + (JsonEscape $Action) + """"
  if(-not [string]::IsNullOrWhiteSpace($Namespace)){ $json += ",""namespace"":""" + (JsonEscape $Namespace) + """" }
  $json += "}"
  Write-Utf8NoBomLf $Req $json
  $result = Invoke-Eval $Req $Pol
  Write-Output $result.Text
  if($result.ExitCode -ne 0){ Remove-Item -LiteralPath $Req -Force -ErrorAction SilentlyContinue; exit $result.ExitCode }
  try{
    $parsed = $result.Text | ConvertFrom-Json
    $decision = [string]$parsed.decision
    $reasonCode = [string]$parsed.reason_code
  }catch{
    Remove-Item -LiteralPath $Req -Force -ErrorAction SilentlyContinue
    Die "BAD_EVAL_OUTPUT" $result.Text
  }
  Append-DecisionReceipt $Pol $Req $decision $reasonCode $Principal $Action $Namespace $Command
  Remove-Item -LiteralPath $Req -Force -ErrorAction SilentlyContinue
  if($Command -eq "check"){ if($decision -eq "ALLOW"){ exit 0 }; exit 2 }
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
