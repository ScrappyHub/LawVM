param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$StampUtc = "2026-02-22T00:00:00Z"
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){ throw ("LAWVM_STEP2_FAIL: " + $m) }

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

function JsonEscape([string]$s){
  if($null -eq $s){ return "" }
  $r = $s.Replace("\","\\")
  $r = $r.Replace("`"","\""`"")
  $r = $r.Replace("`r","\r").Replace("`n","\n").Replace("`t","\t")
  return $r
}

function Append-Receipt([string]$Path,[string]$Line){
  $enc = New-Object System.Text.UTF8Encoding($false)
  $dir = Split-Path -Parent $Path
  if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  if(-not $Line.EndsWith("`n")){ $Line += "`n" }
  [System.IO.File]::AppendAllText($Path,$Line,$enc)
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ Die ("RECEIPT_APPEND_FAILED: " + $Path) }
}

# Capture param before cleaning poisoned vars
$InputRepoRoot = $RepoRoot
Remove-Variable PacketsPsm1, FsPsm1, Need, n, L, fixText, patchBody, selfText, selfPath, SelfPath, SelfText, P, S, e, d, b, r -ErrorAction SilentlyContinue

$RepoRoot = (Resolve-Path -LiteralPath $InputRepoRoot).Path
$DocsDir    = Join-Path $RepoRoot "docs"
$ScriptsDir = Join-Path $RepoRoot "scripts"
$ProofsDir  = Join-Path $RepoRoot "proofs"
$RcptDir    = Join-Path $ProofsDir "receipts"
EnsureDir $DocsDir
EnsureDir $ScriptsDir
EnsureDir $RcptDir

# Require Step1 selftest
$SelfV1 = Join-Path $ScriptsDir "self_test_v1.ps1"
if(-not (Test-Path -LiteralPath $SelfV1 -PathType Leaf)){ Die ("MISSING_STEP1_SELFTEST: " + $SelfV1) }

# .gitignore
$GitIgnore = Join-Path $RepoRoot ".gitignore"
$gi = New-Object System.Collections.Generic.List[string]
[void]$gi.Add("# LAWVM .gitignore (minimal)")
[void]$gi.Add("proofs/_tmp/")
[void]$gi.Add("**/*.user")
[void]$gi.Add("**/*.suo")
[void]$gi.Add("**/*.tmp")
[void]$gi.Add("**/Thumbs.db")
[void]$gi.Add("**/.DS_Store")
$giText = (@($gi.ToArray()) -join "`n")
Write-Utf8NoBomLf $GitIgnore $giText
Write-Host ("WROTE: " + $GitIgnore) -ForegroundColor Green

# LICENSE (MIT)
$LicPath = Join-Path $RepoRoot "LICENSE"
$lic = New-Object System.Collections.Generic.List[string]
[void]$lic.Add("MIT License")
[void]$lic.Add("")
[void]$lic.Add("Copyright (c) 2026")
[void]$lic.Add("")
[void]$lic.Add("Permission is hereby granted, free of charge, to any person obtaining a copy")
[void]$lic.Add("of this software and associated documentation files (the ""Software""), to deal")
[void]$lic.Add("in the Software without restriction, including without limitation the rights")
[void]$lic.Add("to use, copy, modify, merge, publish, distribute, sublicense, and/or sell")
[void]$lic.Add("copies of the Software, and to permit persons to whom the Software is")
[void]$lic.Add("furnished to do so, subject to the following conditions:")
[void]$lic.Add("")
[void]$lic.Add("The above copyright notice and this permission notice shall be included in all")
[void]$lic.Add("copies or substantial portions of the Software.")
[void]$lic.Add("")
[void]$lic.Add("THE SOFTWARE IS PROVIDED ""AS IS"", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR")
[void]$lic.Add("IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,")
[void]$lic.Add("FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE")
[void]$lic.Add("AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER")
[void]$lic.Add("LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,")
[void]$lic.Add("OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE")
[void]$lic.Add("SOFTWARE.")
$licText = (@($lic.ToArray()) -join "`n")
Write-Utf8NoBomLf $LicPath $licText
Write-Host ("WROTE: " + $LicPath) -ForegroundColor Green

# docs/WHAT_THIS_PROJECT_IS.md
$WhatPath = Join-Path $DocsDir "WHAT_THIS_PROJECT_IS.md"
$w = New-Object System.Collections.Generic.List[string]
[void]$w.Add("# LAWVM - What This Project Is (to spec)")
[void]$w.Add("")
[void]$w.Add("LAWVM is a Tier-0 standalone deterministic instrument for building, packaging, and verifying a policy-governed virtual machine artifact as a reproducible evidence bundle.")
[void]$w.Add("")
[void]$w.Add("Scope (Tier-0):")
[void]$w.Add("- Deterministic scripts (PS5.1, StrictMode Latest) that produce byte-stable artifacts")
[void]$w.Add("- Write -> parse-gate -> run discipline; no interactive-state reliance")
[void]$w.Add("- Append-only receipts proving exactly what was generated and verified")
[void]$w.Add("")
[void]$w.Add("Non-scope (Tier-0):")
[void]$w.Add("- No network distribution, no policy authority, no remote attestation")
[void]$w.Add("- No ecosystem integrations until LAWVM proves standalone determinism")
[void]$w.Add("")
[void]$w.Add("LAWVM must be safe-by-default and deterministic: the same inputs produce byte-identical outputs and receipts across machines.")
$wText = (@($w.ToArray()) -join "`n")
Write-Utf8NoBomLf $WhatPath $wText
Write-Host ("WROTE: " + $WhatPath) -ForegroundColor Green

# docs/INSTRUMENT_ENVIRONMENT.md
$EnvPath = Join-Path $DocsDir "INSTRUMENT_ENVIRONMENT.md"
$e = New-Object System.Collections.Generic.List[string]
[void]$e.Add("# LAWVM - Instrument Environment")
[void]$e.Add("")
[void]$e.Add("Required:")
[void]$e.Add("- Windows PowerShell 5.1")
[void]$e.Add("- Set-StrictMode -Version Latest")
[void]$e.Add("- Deterministic file writes: UTF-8 (no BOM), LF line endings")
[void]$e.Add("- Run scripts via child: powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File")
[void]$e.Add("")
[void]$e.Add("Repo conventions:")
[void]$e.Add("- scripts\\_scratch: patchers/runners (not product surface)")
[void]$e.Add("- scripts\\: parse-gated product scripts")
[void]$e.Add("- proofs\\receipts: append-only NDJSON receipts")
$eText = (@($e.ToArray()) -join "`n")
Write-Utf8NoBomLf $EnvPath $eText
Write-Host ("WROTE: " + $EnvPath) -ForegroundColor Green

# docs/DOD_TIER0.md
$DodPath = Join-Path $DocsDir "DOD_TIER0.md"
$d = New-Object System.Collections.Generic.List[string]
[void]$d.Add("# LAWVM - Tier-0 Definition of Done (DoD)")
[void]$d.Add("")
[void]$d.Add("- Deterministic selftest runner exists and is GREEN on a clean run")
[void]$d.Add("- Golden vectors exist (at least 1 positive + 2 negative) with deterministic PASS/FAIL")
[void]$d.Add("- All product scripts are parse-gated and PS5.1 StrictMode Latest safe")
[void]$d.Add("- Receipts are append-only and reproducible from the same inputs")
[void]$d.Add("- Public repo surface exists: README, LICENSE, docs, stable directory layout")
$dText = (@($d.ToArray()) -join "`n")
Write-Utf8NoBomLf $DodPath $dText
Write-Host ("WROTE: " + $DodPath) -ForegroundColor Green

# docs/WBS.md
$WbsPath = Join-Path $DocsDir "WBS.md"
$b = New-Object System.Collections.Generic.List[string]
[void]$b.Add("# LAWVM - WBS (deterministic snapshot)")
[void]$b.Add("")
[void]$b.Add("- DONE: Step-1 repair runner + minimal selftest (scripts/self_test_v1.ps1) proven GREEN")
[void]$b.Add("- NEXT: Step-2 public surface + receipts + Tier-0 selftest runner")
[void]$b.Add("- NEXT: Lock receipt schema (schemas/lawvm.receipt.v1.json) + docs/RECEIPTS.md")
[void]$b.Add("- NEXT: Add golden vectors (positive/negative) + deterministic verifier harness")
[void]$b.Add("- NEXT: Build/pack/verify minimal LAWVM artifact pipeline (Tier-0 minimal)")
$bText = (@($b.ToArray()) -join "`n")
Write-Utf8NoBomLf $WbsPath $bText
Write-Host ("WROTE: " + $WbsPath) -ForegroundColor Green

# README.md
$ReadmePath = Join-Path $RepoRoot "README.md"
$r = New-Object System.Collections.Generic.List[string]
[void]$r.Add("# LAWVM")
[void]$r.Add("")
[void]$r.Add("LAWVM is a Tier-0 standalone deterministic instrument. No ecosystem integrations until standalone determinism is proven.")
[void]$r.Add("")
[void]$r.Add("## Quickstart")
[void]$r.Add("```powershell")
[void]$r.Add("powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\_selftest_lawvm_v1.ps1 -RepoRoot .")
[void]$r.Add("```")
[void]$r.Add("")
[void]$r.Add("## Docs")
[void]$r.Add("- docs/WHAT_THIS_PROJECT_IS.md")
[void]$r.Add("- docs/INSTRUMENT_ENVIRONMENT.md")
[void]$r.Add("- docs/DOD_TIER0.md")
[void]$r.Add("- docs/WBS.md")
$rText = (@($r.ToArray()) -join "`n")
Write-Utf8NoBomLf $ReadmePath $rText
Write-Host ("WROTE: " + $ReadmePath) -ForegroundColor Green

# scripts/_selftest_lawvm_v1.ps1 (product surface)
$SelfRunner = Join-Path $ScriptsDir "_selftest_lawvm_v1.ps1"
$sr = New-Object System.Collections.Generic.List[string]
[void]$sr.Add("param(")
[void]$sr.Add("  [Parameter(Mandatory=$true)][string]`$RepoRoot,")
[void]$sr.Add("  [string]`$StampUtc = ""2026-02-22T00:00:00Z""")
[void]$sr.Add(")")
[void]$sr.Add("Set-StrictMode -Version Latest")
[void]$sr.Add("`$ErrorActionPreference = ""Stop""")
[void]$sr.Add("")
[void]$sr.Add("function Die([string]`$m){ throw (""LAWVM_SELFTEST_FAIL: "" + `$m) }")
[void]$sr.Add("function Append-Receipt([string]`$Path,[string]`$Line){ `$enc=New-Object System.Text.UTF8Encoding(`$false); `$dir=Split-Path -Parent `$Path; if(`$dir -and -not (Test-Path -LiteralPath `$dir -PathType Container)){ New-Item -ItemType Directory -Force -Path `$dir | Out-Null }; if(-not `$Line.EndsWith(""`n"")){ `$Line += ""`n"" }; [System.IO.File]::AppendAllText(`$Path,`$Line,`$enc); if(-not (Test-Path -LiteralPath `$Path -PathType Leaf)){ Die (""RECEIPT_APPEND_FAILED: "" + `$Path) } }")
[void]$sr.Add("function JsonEscape([string]`$s){ if(`$null -eq `$s){ return """" }; `$r=`$s.Replace(""\"",""\\""); `$r=`$r.Replace(""""",""\"""""); `$r=`$r.Replace(""`r"",""\r"").Replace(""`n"",""\n"").Replace(""`t"",""\t""); return `$r }")
[void]$sr.Add("")
[void]$sr.Add('Write-Host "LAWVM_SELFTEST_RUNNER_V1_START" -ForegroundColor Cyan')
[void]$sr.Add('$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path')
[void]$sr.Add('$SelfV1 = Join-Path $RepoRoot "scripts\self_test_v1.ps1"' )
[void]$sr.Add('if(-not (Test-Path -LiteralPath $SelfV1 -PathType Leaf)){ Die ("MISSING: " + $SelfV1) }')
[void]$sr.Add('$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"' )
[void]$sr.Add('if(-not (Test-Path -LiteralPath $PSExe -PathType Leaf)){ Die ("MISSING_POWERSHELL_EXE: " + $PSExe) }')
[void]$sr.Add('& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $SelfV1 -RepoRoot $RepoRoot | Out-Host')
[void]$sr.Add('Write-Host "LAWVM_SELFTEST_RUNNER_V1_OK" -ForegroundColor Green')
[void]$sr.Add("")
[void]$sr.Add('$RcptPath = Join-Path $RepoRoot "proofs\receipts\lawvm.ndjson"' )
[void]$sr.Add('$line = "{""schema"":""lawvm.receipt.v1"",""event"":""lawvm.selftest.v1"",""stamp_utc"":""" + (JsonEscape $StampUtc) + """,""repo_root"":""" + (JsonEscape $RepoRoot) + """}"' )
[void]$sr.Add('Append-Receipt $RcptPath $line')
[void]$sr.Add('Write-Host ("RECEIPT_APPENDED: " + $RcptPath) -ForegroundColor Green')

$srText = (@($sr.ToArray()) -join "`n")
Write-Utf8NoBomLf $SelfRunner $srText
Parse-GateFile $SelfRunner
Write-Host ("WROTE+PARSE_OK: " + $SelfRunner) -ForegroundColor Green

# Parse-gate Step1 selftest too
Parse-GateFile $SelfV1
Write-Host ("PARSE_OK: " + $SelfV1) -ForegroundColor Green

# Run product selftest runner via child powershell.exe
$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
if(-not (Test-Path -LiteralPath $PSExe -PathType Leaf)){ Die ("MISSING_POWERSHELL_EXE: " + $PSExe) }
& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $SelfRunner -RepoRoot $RepoRoot -StampUtc $StampUtc | Out-Host

Write-Host "LAWVM_STEP2_GREEN_OK" -ForegroundColor Green
