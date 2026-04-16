param(
  [Parameter(Mandatory=$true)][string]$RepoRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){ throw ("LAWVM_STEP1_FAIL: " + $m) }
function EnsureDir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ Die "ENSUREDIR_EMPTY" }
  if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function Write-Utf8NoBomLf([string]$Path,[string]$Text){
  $dir = Split-Path -Parent $Path
  if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $t = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path,$t,$enc)
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ Die ("WRITE_FAILED: " + $Path) }
}

function Parse-GateFile([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ Die ("PARSEGATE_MISSING: " + $Path) }
  $tok=$null; $err=$null
  [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tok,[ref]$err)
  $errs=@(@($err))
  if($errs.Count -gt 0){
    $x=$errs[0]
    Die ("PARSE_GATE_FAIL: {0}:{1}:{2}: {3}" -f $Path,$x.Extent.StartLineNumber,$x.Extent.StartColumnNumber,$x.Message)
  }
}

# Capture param before cleaning poisoned vars
$InputRepoRoot = $RepoRoot
Remove-Variable PacketsPsm1, FsPsm1, Need, n, L, fixText, patchBody, selfText, selfPath, SelfPath, SelfText -ErrorAction SilentlyContinue

$RepoRoot = (Resolve-Path -LiteralPath $InputRepoRoot).Path
$ScriptsDir = Join-Path $RepoRoot "scripts"
EnsureDir $ScriptsDir

# Write scripts\self_test_v1.ps1 deterministically (NO interpolation)
$SelfPath = Join-Path $ScriptsDir "self_test_v1.ps1"
$S = New-Object System.Collections.Generic.List[string]
[void]$S.Add('param(')
[void]$S.Add('  [Parameter(Mandatory=$true)][string]$RepoRoot')
[void]$S.Add(')')
[void]$S.Add('Set-StrictMode -Version Latest')
[void]$S.Add('$ErrorActionPreference = "Stop"')
[void]$S.Add('')
[void]$S.Add('Write-Host "LAWVM_SELFTEST_V1_START" -ForegroundColor Cyan')
[void]$S.Add('$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path')
[void]$S.Add('$ScriptsDir = Join-Path $RepoRoot "scripts"')
[void]$S.Add('if(-not (Test-Path -LiteralPath $ScriptsDir -PathType Container)){ throw ("MISSING_DIR: " + $ScriptsDir) }')
[void]$S.Add('Write-Host "SELF_TEST_OK" -ForegroundColor Cyan')
$selfText = (@($S.ToArray()) -join "`n")
Write-Utf8NoBomLf $SelfPath $selfText
Parse-GateFile $SelfPath
Write-Host ("WROTE+PARSE_OK: " + $SelfPath) -ForegroundColor Green

# Run selftest via child powershell.exe deterministically
$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
if(-not (Test-Path -LiteralPath $PSExe -PathType Leaf)){ Die ("MISSING_POWERSHELL_EXE: " + $PSExe) }
& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $SelfPath -RepoRoot $RepoRoot | Out-Host

Write-Host "LAWVM_STEP1_GREEN_OK" -ForegroundColor Green
