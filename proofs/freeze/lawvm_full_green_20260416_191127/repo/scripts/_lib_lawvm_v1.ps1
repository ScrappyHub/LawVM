Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function LAWVM-Die([string]$m){ throw ("LAWVM_FAIL: " + $m) }

function LAWVM-EnsureDir([string]$p){
  if(-not (Test-Path -LiteralPath $p -PathType Container)){
    New-Item -ItemType Directory -Force -Path $p | Out-Null
  }
}

function LAWVM-WriteUtf8NoBomLf([string]$Path,[string]$Text){
  $dir = Split-Path -Parent $Path
  if($dir){ LAWVM-EnsureDir $dir }
  $t = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path,$t,$enc)
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ LAWVM-Die ("WRITE_FAILED: " + $Path) }
}

function LAWVM-ReadUtf8([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ LAWVM-Die ("MISSING_FILE: " + $Path) }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::ReadAllText($Path,$enc)
}

function LAWVM-Sha256HexBytes([byte[]]$Bytes){
  if($null -eq $Bytes){ $Bytes = @() }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { ($sha.ComputeHash([byte[]]$Bytes) | ForEach-Object { $_.ToString("x2") }) -join "" }
  finally { $sha.Dispose() }
}

function LAWVM-Sha256HexPath([string]$Path){
  LAWVM-Sha256HexBytes ([System.IO.File]::ReadAllBytes($Path))
}

function LAWVM-JsonCanon([object]$Obj){
  if($null -eq $Obj){ return $null }

  if($Obj -is [string] -or $Obj -is [bool] -or
     $Obj -is [int] -or $Obj -is [long] -or
     $Obj -is [double] -or $Obj -is [decimal]) { return $Obj }

  if($Obj -is [System.Collections.IDictionary]){
    $h = [ordered]@{}
    foreach($k in ($Obj.Keys | ForEach-Object { [string]$_ } | Sort-Object)){
      $h[$k] = LAWVM-JsonCanon $Obj[$k]
    }
    return $h
  }

  if($Obj -is [psobject]){
    $props = @($Obj.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' -or $_.MemberType -eq 'Property' })
    if($props.Count -gt 0){
      $h = [ordered]@{}
      foreach($n in ($props.Name | Sort-Object)){
        $h[$n] = LAWVM-JsonCanon $Obj.$n
      }
      return $h
    }
  }

  if($Obj -is [System.Collections.IEnumerable]){
    $arr = @()
    foreach($x in $Obj){ $arr += ,(LAWVM-JsonCanon $x) }
    return $arr
  }

  return $Obj
}

function LAWVM-ToCanonJson([object]$Obj,[int]$Depth=64){
  $canon = LAWVM-JsonCanon $Obj
  ($canon | ConvertTo-Json -Depth $Depth -Compress)
}

function LAWVM-ValidatePrincipal([string]$Principal){
  if([string]::IsNullOrWhiteSpace($Principal)){ LAWVM-Die "Principal empty" }
  if($Principal -notmatch '^single-tenant\/[a-z0-9._-]+\/authority\/[a-z0-9._-]+$'){
    LAWVM-Die ("Principal invalid: " + $Principal)
  }
}

function LAWVM-ValidateNamespace([string]$Namespace){
  if([string]::IsNullOrWhiteSpace($Namespace)){ LAWVM-Die "Namespace empty" }
  if($Namespace -notmatch '^[a-z0-9][a-z0-9\/._-]*$'){ LAWVM-Die ("Namespace invalid: " + $Namespace) }
}

function LAWVM-PTrust([string]$r){ Join-Path $r "proofs\trust\trust_bundle.json" }
function LAWVM-PAllowed([string]$r){ Join-Path $r "proofs\trust\allowed_signers" }
function LAWVM-PReceipts([string]$r){ Join-Path $r "proofs\receipts\neverlost.ndjson" }
function LAWVM-PPolicy([string]$r){ Join-Path $r "policies\policy_bundle.json" }
function LAWVM-PPolicySig([string]$r){ Join-Path $r "policies\policy_bundle.sig" }

function LAWVM-LoadTrust([string]$Path){
  $raw = LAWVM-ReadUtf8 $Path
  $o = $raw | ConvertFrom-Json -Depth 64
  if($o.schema -ne "trust_bundle.v1"){ LAWVM-Die ("Bad trust bundle schema: " + $o.schema) }
  if(-not $o.principals){ LAWVM-Die "trust_bundle principals missing" }
  $o
}

function LAWVM-WriteAllowedSigners([string]$RepoRoot){
  $tb = LAWVM-LoadTrust (LAWVM-PTrust $RepoRoot)
  $lines = @()
  foreach($p in ($tb.principals | Sort-Object principal)){
    $principal = [string]$p.principal
    $keyId     = [string]$p.key_id
    $pub       = [string]$p.public_key_openssh
    if([string]::IsNullOrWhiteSpace($principal) -or [string]::IsNullOrWhiteSpace($keyId) -or [string]::IsNullOrWhiteSpace($pub)){
      LAWVM-Die "trust_bundle principal entry missing required fields"
    }
    LAWVM-ValidatePrincipal $principal
    $lines += ($principal + " " + $pub + " # key_id=" + $keyId)
  }
  $out = ($lines -join "`n") + "`n"
  $path = LAWVM-PAllowed $RepoRoot
  LAWVM-WriteUtf8NoBomLf $path $out
  $path
}

function LAWVM-AppendReceipt([string]$RepoRoot,[hashtable]$Receipt){
  $p = LAWVM-PReceipts $RepoRoot
  LAWVM-EnsureDir (Split-Path -Parent $p)
  $line = LAWVM-ToCanonJson $Receipt
  $enc = New-Object System.Text.UTF8Encoding($false)
  $bytes = $enc.GetBytes($line + "`n")
  $fs = [System.IO.File]::Open($p,[System.IO.FileMode]::Append,[System.IO.FileAccess]::Write,[System.IO.FileShare]::Read)
  try { $fs.Write($bytes,0,$bytes.Length) } finally { $fs.Dispose() }
}

function LAWVM-LoadPolicy([string]$Path){
  $raw = LAWVM-ReadUtf8 $Path
  $o = $raw | ConvertFrom-Json -Depth 128
  if($o.schema -ne "lawvm.policy_bundle.v1"){ LAWVM-Die ("Bad policy schema: " + $o.schema) }
  if(-not $o.rules){ LAWVM-Die "policy rules missing" }
  $o
}

function LAWVM-MatchRule([object]$Req,[object]$Rule){
  if($null -eq $Rule.match){ return $false }
  $m = $Rule.match
  if($m.principal_exact){
    if([string]$Req.principal -ne [string]$m.principal_exact){ return $false }
  }
  if($m.namespace_exact){
    if([string]$Req.namespace -ne [string]$m.namespace_exact){ return $false }
  }
  if($m.action_in){
    $ok = $false
    foreach($a in $m.action_in){
      if([string]$Req.action -eq [string]$a){ $ok = $true; break }
    }
    if(-not $ok){ return $false }
  }
  if($m.attrs_all){
    foreach($p in $m.attrs_all.PSObject.Properties){
      $k = [string]$p.Name
      $v = $p.Value
      if(-not ($Req.attrs.PSObject.Properties.Name -contains $k)){ return $false }
      if([string]$Req.attrs.$k -ne [string]$v){ return $false }
    }
  }
  return $true
}

function LAWVM-Evaluate([string]$RepoRoot,[object]$Req){
  LAWVM-ValidatePrincipal ([string]$Req.principal)
  LAWVM-ValidateNamespace ([string]$Req.namespace)

  $policyPath = LAWVM-PPolicy $RepoRoot
  $pol = LAWVM-LoadPolicy $policyPath

  $allowHits = @()
  $denyHits  = @()

  $rules = @($pol.rules | Sort-Object rule_id)
  foreach($r in $rules){
    if(-not $r.rule_id){ LAWVM-Die "Rule missing rule_id" }
    $eff = [string]$r.effect
    if($eff -ne "allow" -and $eff -ne "deny"){ LAWVM-Die ("Rule effect invalid: " + [string]$r.rule_id) }
    if(LAWVM-MatchRule -Req $Req -Rule $r){
      if($eff -eq "deny"){ $denyHits += ,([string]$r.rule_id) } else { $allowHits += ,([string]$r.rule_id) }
    }
  }

  $decision = "deny"
  if($denyHits.Count -gt 0){ $decision = "deny" }
  elseif($allowHits.Count -gt 0){ $decision = "allow" }
  else { $decision = "deny" }

  [pscustomobject]@{
    schema        = "lawvm.decision.v1"
    decision      = $decision
    principal     = [string]$Req.principal
    action        = [string]$Req.action
    namespace     = [string]$Req.namespace
    allow_rules   = $allowHits
    deny_rules    = $denyHits
    evaluated_utc = (Get-Date).ToUniversalTime().ToString("o")
    policy_sha256 = LAWVM-Sha256HexPath $policyPath
  }
}

function LAWVM-RequireSshKeygen(){
  $c = Get-Command ssh-keygen -ErrorAction SilentlyContinue
  if(-not $c){ LAWVM-Die "Missing ssh-keygen in PATH" }
}

function LAWVM-VerifyPolicySig([string]$RepoRoot){
  $bundle = LAWVM-PPolicy $RepoRoot
  $sig = LAWVM-PPolicySig $RepoRoot
  if(-not (Test-Path -LiteralPath $sig -PathType Leaf)){ return $false }

  LAWVM-RequireSshKeygen
  $allowed = LAWVM-PAllowed $RepoRoot
  if(-not (Test-Path -LiteralPath $allowed -PathType Leaf)){
    LAWVM-WriteAllowedSigners $RepoRoot | Out-Null
  }

  $pol = LAWVM-LoadPolicy $bundle
  $principal = [string]$pol.signer_principal
  $ns = "lawvm/policy-bundle"
  LAWVM-ValidatePrincipal $principal
  LAWVM-ValidateNamespace $ns

  & ssh-keygen -Y verify -f $allowed -I $principal -n $ns -s $sig $bundle | Out-Null
  return $true
}
