param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$StampUtc = "2026-02-22T00:00:00Z"
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){ throw ("LAWVM_FIX_FAIL: " + $m) }
function EnsureDir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "ENSUREDIR_EMPTY" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
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
  if($errs.Count -gt 0){ $x=$errs[0]; Die ("PARSE_GATE_FAIL: {0}:{1}:{2}: {3}" -f $Path,$x.Extent.StartLineNumber,$x.Extent.StartColumnNumber,$x.Message) }
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$ScriptsDir = Join-Path $RepoRoot "scripts"
EnsureDir $ScriptsDir
$OutPath = Join-Path $ScriptsDir "_selftest_lawvm_v1.ps1"

$sr = New-Object System.Collections.Generic.List[string]
[void]$sr.Add("param(")
[void]$sr.Add("  [Parameter(Mandatory=`$true)][string]`$RepoRoot,")
[void]$sr.Add("  [string]`$StampUtc = ""2026-02-22T00:00:00Z""")
[void]$sr.Add(")")
[void]$sr.Add("Set-StrictMode -Version Latest")
[void]$sr.Add("`$ErrorActionPreference = ""Stop""")
[void]$sr.Add("Write-Host ""LAWVM_SELFTEST_RUNNER_V1_START"" -ForegroundColor Cyan")
[void]$sr.Add("`$RepoRoot = (Resolve-Path -LiteralPath `$RepoRoot).Path")
[void]$sr.Add("`$SelfV1 = Join-Path `$RepoRoot ""scripts\self_test_v1.ps1""")
[void]$sr.Add("if(-not (Test-Path -LiteralPath `$SelfV1 -PathType Leaf)){ throw (""MISSING: "" + `$SelfV1) }")
[void]$sr.Add("Write-Host ""LAWVM_SELFTEST_RUNNER_V1_OK"" -ForegroundColor Green")
$txt = (@($sr.ToArray()) -join "`n")
Write-Utf8NoBomLf $OutPath $txt
Parse-GateFile $OutPath
Write-Host ("FIXED+PARSE_OK: " + $OutPath) -ForegroundColor Green
