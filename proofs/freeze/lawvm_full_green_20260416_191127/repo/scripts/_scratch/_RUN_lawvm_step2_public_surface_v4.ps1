param(
  [Parameter(Mandatory=`$true)][string]$RepoRoot,
  [string]$StampUtc = "2026-02-22T00:00:00Z"
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){ throw ("LAWVM_STEP2_FAIL: " + $m) }
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
$DocsDir    = Join-Path $RepoRoot "docs"
$ScriptsDir = Join-Path $RepoRoot "scripts"
$RcptDir    = Join-Path $RepoRoot "proofs\receipts"
EnsureDir $DocsDir
EnsureDir $ScriptsDir
EnsureDir $RcptDir

$SelfV1 = Join-Path $ScriptsDir "self_test_v1.ps1"
if(-not (Test-Path -LiteralPath $SelfV1 -PathType Leaf)){ Die ("MISSING_STEP1_SELFTEST: " + $SelfV1) }

$ReadmePath = Join-Path $RepoRoot "README.md"
$r = New-Object System.Collections.Generic.List[string]
[void]$r.Add("# LAWVM")
[void]$r.Add("")
[void]$r.Add("Quickstart: powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\_selftest_lawvm_v1.ps1 -RepoRoot .")
$rText = (@($r.ToArray()) -join "`n")
Write-Utf8NoBomLf $ReadmePath $rText
Write-Host ("WROTE: " + $ReadmePath) -ForegroundColor Green

$SelfRunner = Join-Path $ScriptsDir "_selftest_lawvm_v1.ps1"
$sr = New-Object System.Collections.Generic.List[string]
[void]$sr.Add("param(")
[void]$sr.Add("  [Parameter(Mandatory=`$true)][string]`$RepoRoot,")
[void]$sr.Add("  [string]`$StampUtc = ""2026-02-22T00:00:00Z""")
[void]$sr.Add(")")
[void]$sr.Add("Set-StrictMode -Version Latest")
[void]$sr.Add("`$ErrorActionPreference = ""Stop""")
[void]$sr.Add("")
[void]$sr.Add("function Die([string]`$m){ throw (""LAWVM_SELFTEST_FAIL: "" + `$m) }")
[void]$sr.Add("function Append-Receipt([string]`$Path,[string]`$Line){ `$enc=New-Object System.Text.UTF8Encoding(`$false); `$dir=Split-Path -Parent `$Path; if(`$dir -and -not (Test-Path -LiteralPath `$dir -PathType Container)){ New-Item -ItemType Directory -Force -Path `$dir | Out-Null }; if(-not `$Line.EndsWith(""`n"")){ `$Line += ""`n"" }; [System.IO.File]::AppendAllText(`$Path,`$Line,`$enc); if(-not (Test-Path -LiteralPath `$Path -PathType Leaf)){ Die (""RECEIPT_APPEND_FAILED: "" + `$Path) } }")
[void]$sr.Add("")
[void]$sr.Add("function JsonEscape([string]`$s){")
[void]$sr.Add("  if(`$null -eq `$s){ return """" }")
[void]$sr.Add("  `$bs = [string][char]92")
[void]$sr.Add("  `$dq = [string][char]34")
[void]$sr.Add("  `$r = `$s.Replace(`$bs, (`$bs + `$bs))")
[void]$sr.Add("  `$r = `$r.Replace(`$dq, (`$bs + `$dq))")
[void]$sr.Add("  `$r = `$r.Replace(""`r"",""\r"").Replace(""`n"",""\n"").Replace(""`t"",""\t"")")
[void]$sr.Add("  return `$r")
[void]$sr.Add("}")
[void]$sr.Add("")
[void]$sr.Add("Write-Host ""LAWVM_SELFTEST_RUNNER_V1_START"" -ForegroundColor Cyan")
[void]$sr.Add("`$RepoRoot = (Resolve-Path -LiteralPath `$RepoRoot).Path")
[void]$sr.Add("`$SelfV1 = Join-Path `$RepoRoot ""scripts\self_test_v1.ps1""")
[void]$sr.Add("if(-not (Test-Path -LiteralPath `$SelfV1 -PathType Leaf)){ Die (""MISSING: "" + `$SelfV1) }")
[void]$sr.Add("`$PSExe = Join-Path `$env:WINDIR ""System32\WindowsPowerShell\v1.0\powershell.exe""")
[void]$sr.Add("if(-not (Test-Path -LiteralPath `$PSExe -PathType Leaf)){ Die (""MISSING_POWERSHELL_EXE: "" + `$PSExe) }")
[void]$sr.Add("& `$PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `$SelfV1 -RepoRoot `$RepoRoot | Out-Host")
[void]$sr.Add("Write-Host ""LAWVM_SELFTEST_RUNNER_V1_OK"" -ForegroundColor Green")
[void]$sr.Add("")
[void]$sr.Add("`$RcptPath = Join-Path `$RepoRoot ""proofs\receipts\lawvm.ndjson""")
[void]$sr.Add("`$dq = [string][char]34")
[void]$sr.Add("`$line = ""{"" + `$dq + ""schema"" + `$dq + "":"" + `$dq + ""lawvm.receipt.v1"" + `$dq + "","" + `$dq + ""event"" + `$dq + "":"" + `$dq + ""lawvm.selftest.v1"" + `$dq + "","" + `$dq + ""stamp_utc"" + `$dq + "":"" + `$dq + (JsonEscape `$StampUtc) + `$dq + "","" + `$dq + ""repo_root"" + `$dq + "":"" + `$dq + (JsonEscape `$RepoRoot) + `$dq + ""}""")
[void]$sr.Add("Append-Receipt `$RcptPath `$line")
[void]$sr.Add("Write-Host (""RECEIPT_APPENDED: "" + `$RcptPath) -ForegroundColor Green")
[void]$sr.Add("Write-Host ""LAWVM_SELFTEST_RUNNER_V1_DONE"" -ForegroundColor Green")
$srText = (@($sr.ToArray()) -join "`n")
Write-Utf8NoBomLf $SelfRunner $srText
Parse-GateFile $SelfRunner
Write-Host ("WROTE+PARSE_OK: " + $SelfRunner) -ForegroundColor Green
Parse-GateFile $SelfV1
Write-Host ("PARSE_OK: " + $SelfV1) -ForegroundColor Green
$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
if(-not (Test-Path -LiteralPath $PSExe -PathType Leaf)){ Die ("MISSING_POWERSHELL_EXE: " + $PSExe) }
& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $SelfRunner -RepoRoot $RepoRoot -StampUtc $StampUtc | Out-Host
Write-Host "LAWVM_STEP2_GREEN_OK" -ForegroundColor Green
