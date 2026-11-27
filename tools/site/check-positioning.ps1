#requires -Version 7.0
<#
.SYNOPSIS
    The order gate of the positioning source (S0040): every external surface lists the pillars of docs/SPECIFICATION_POSITIONING.md
    in the document's order, as SITE-REPRESENTATION rules 1 and 2 ask.
.DESCRIPTION
    Sources read here, never the surfaces' prose alone:
      - docs/SPECIFICATION_POSITIONING.md: the pillar ids in the numbered list of its section "The .. pillars" (the order is the
        document's), and the surface files in the table of its section "Surfaces";
      - tools/site/positioning-surfaces.json: per surface file, the scope (a regular expression whose match is the part of the
        file that lists the pillars), the match mode and one anchor phrase per pillar id.
    Checked, per surface: the file is one the document names and the anchors are the document's pillar ids in its order; the
    scope matches; every anchor occurs exactly once in the scope (mode text: the phrase, white space collapsed, so a hard-wrapped
    line still matches; mode line: a whole line); the anchors occur in the order of the pillars. The set of surfaces of the
    document and of the JSON are the same files, each once.
    Findings (every one is fatal; there is no baseline, CHECK-BASELINE is not applicable here):
      source: the document lists no pillar, numbers them out of sequence or repeats an id, or names no surface; the JSON names a
        mode this gate does not know or an empty phrase.
      surfaces: a file the document names has no entry in the JSON, an entry names a file the document does not, or two entries
        name the same file.
      anchors: an entry's pillar ids are not the document's, in its order.
      scope: the scope expression is invalid or matches nothing in the file.
      anchor: a phrase occurs no time or more than once in the scope.
      order: the anchors occur, but not in the document's order.
    The run does not stop at the first finding (CHECK-VERDICT rule 9). The gate makes no request and builds nothing.
.NOTES
    Exit codes: 0 PASS, 1 FAIL (one reason line per finding), 2 COULD NOT VERIFY (a missing or unreadable input, a reason line
    per cause). The verdict line is the last line written, on every path (CHECK-VERDICT rules 1, 5, 11):
      positioning: PASS (<counts>) | positioning: FAIL (<n> finding(s)) | positioning: COULD NOT VERIFY (<what>)
    -Root is the repository root; test-positioning.ps1 points it at throw-away copies.
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$docRel = 'docs/SPECIFICATION_POSITIONING.md'
$cfgRel = 'tools/site/positioning-surfaces.json'

$findings = [System.Collections.Generic.List[string]]::new()
$unverified = [System.Collections.Generic.List[string]]::new()
function Add-Finding([string]$Class, [string]$Message) { $findings.Add("${Class}: $Message") }
function Read-Text([string]$Rel) {
    $path = Join-Path $Root $Rel
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $unverified.Add("$Rel is missing"); return $null }
    return [IO.File]::ReadAllText($path, $utf8)
}
function Stop-Unverified {
    foreach ($r in $unverified) { Write-Output "COULD NOT VERIFY - $r" }
    Write-Output "positioning: COULD NOT VERIFY ($($unverified.Count) input(s) missing or unreadable)"
    exit 2
}

# ---- the sources ----
$doc = Read-Text $docRel
$cfgText = Read-Text $cfgRel
$cfg = $null
if ($null -ne $cfgText) {
    try { $cfg = $cfgText | ConvertFrom-Json } catch { $unverified.Add("$cfgRel is not JSON ($($_.Exception.Message))") }
}
if ($null -ne $cfg -and @($cfg.surfaces).Count -eq 0) { $unverified.Add("$cfgRel lists no surface (a gate that inspects nothing)") }
if ($unverified.Count -gt 0) { Stop-Unverified }

$pillarSection = [regex]::Match($doc, '(?ms)^## (?:\d+\. )?The (?:\w+ )?pillars[ \t]*\r?\n(?<body>.*?)(?=^## |\z)')
$surfaceSection = [regex]::Match($doc, '(?ms)^## (?:\d+\. )?Surfaces[ \t]*\r?\n(?<body>.*?)(?=^## |\z)')
if (-not $pillarSection.Success) { $unverified.Add("$docRel has no section 'The .. pillars'") }
if (-not $surfaceSection.Success) { $unverified.Add("$docRel has no section 'Surfaces'") }
if ($unverified.Count -gt 0) { Stop-Unverified }

$pillars = [System.Collections.Generic.List[string]]::new()
foreach ($m in [regex]::Matches($pillarSection.Groups['body'].Value, '(?m)^(?<n>\d+)\. \*\*(?<id>[a-z][a-z0-9-]*)\*\* - ')) {
    $pillars.Add($m.Groups['id'].Value)
    if ([int]$m.Groups['n'].Value -ne $pillars.Count) { Add-Finding 'source' "$docRel numbers the pillar '$($m.Groups['id'].Value)' as $($m.Groups['n'].Value), its place is $($pillars.Count)" }
}
if ($pillars.Count -eq 0) { Add-Finding 'source' "$docRel lists no pillar in the form '1. **id** - text' (a gate that inspects nothing)" }
foreach ($g in ($pillars | Group-Object | Where-Object { $_.Count -gt 1 })) { Add-Finding 'source' "$docRel repeats the pillar id '$($g.Name)'" }

$docSurfaces = [System.Collections.Generic.List[string]]::new()
foreach ($m in [regex]::Matches($surfaceSection.Groups['body'].Value, '(?m)^\|[^|\r\n]*\|\s*`(?<f>[^`]+)`\s*\|\s*$')) { $docSurfaces.Add($m.Groups['f'].Value) }
if ($docSurfaces.Count -eq 0) { Add-Finding 'source' "$docRel names no surface file in the table of its section 'Surfaces' (a gate that inspects nothing)" }

# ---- the set of surfaces ----
$entries = @($cfg.surfaces)
foreach ($f in $docSurfaces) {
    if (@($entries | Where-Object { $_.file -eq $f }).Count -eq 0) { Add-Finding 'surfaces' "$docRel names $f, $cfgRel has no entry for it" }
}
foreach ($g in ($entries | Group-Object file)) {
    if ($docSurfaces -notcontains $g.Name) { Add-Finding 'surfaces' "$cfgRel has an entry for $($g.Name), $docRel does not name it" }
    if ($g.Count -gt 1) { Add-Finding 'surfaces' "$cfgRel has $($g.Count) entries for $($g.Name)" }
}

# ---- the order on each surface ----
$checked = 0
foreach ($e in $entries) {
    $file = [string]$e.file
    $text = Read-Text $file
    if ($null -eq $text) { continue }
    $mode = [string]$e.match
    if ($mode -ne 'text' -and $mode -ne 'line') { Add-Finding 'source' "$file has the match mode '$mode', the gate knows text and line"; continue }
    $ids = @($e.anchors.PSObject.Properties | ForEach-Object { $_.Name })
    $anchorsOk = ($ids.Count -eq $pillars.Count)
    for ($i = 0; $anchorsOk -and $i -lt $ids.Count; $i++) { if ($ids[$i] -ne $pillars[$i]) { $anchorsOk = $false } }
    if (-not $anchorsOk) {
        Add-Finding 'anchors' "$file has the pillar ids [$($ids -join ', ')], $docRel lists [$($pillars -join ', ')]"
        continue
    }
    $scopeMatch = $null
    try { $scopeMatch = [regex]::Match($text, [string]$e.scope) }
    catch { Add-Finding 'scope' "$file has an invalid scope expression ($($_.Exception.Message))"; continue }
    if (-not $scopeMatch.Success -or $scopeMatch.Length -eq 0) { Add-Finding 'scope' "$file has no text matching the scope /$($e.scope)/"; continue }
    $scope = $scopeMatch.Value
    if ($mode -eq 'text') { $scope = [regex]::Replace($scope, '\s+', ' ') }
    $positions = [System.Collections.Generic.List[int]]::new()
    $located = $true
    foreach ($p in $e.anchors.PSObject.Properties) {
        $phrase = [string]$p.Value
        if ([string]::IsNullOrWhiteSpace($phrase)) { Add-Finding 'source' "$file has an empty phrase for the pillar '$($p.Name)'"; $located = $false; continue }
        if ($mode -eq 'text') { $rx = [regex]::new([regex]::Escape(([regex]::Replace($phrase, '\s+', ' ')))) }
        else { $rx = [regex]::new('(?m)^[ \t]*' + [regex]::Escape($phrase) + '[ \t]*\r?$') }
        $hits = $rx.Matches($scope)
        $checked++
        if ($hits.Count -ne 1) { Add-Finding 'anchor' "$file has $($hits.Count) occurrence(s) of the pillar '$($p.Name)' phrase '$phrase' in its scope, the gate needs exactly one"; $located = $false; continue }
        $positions.Add($hits[0].Index)
    }
    if (-not $located) { continue }
    for ($i = 1; $i -lt $positions.Count; $i++) {
        if ($positions[$i] -le $positions[$i - 1]) {
            Add-Finding 'order' "$file lists '$($pillars[$i])' before '$($pillars[$i - 1])'; $docRel lists them in the order $($pillars -join ', ')"
        }
    }
}

if ($unverified.Count -gt 0) { Stop-Unverified }
foreach ($f in $findings) { Write-Output "FAIL: $f" }
if ($findings.Count -gt 0) { Write-Output "positioning: FAIL ($($findings.Count) finding(s))"; exit 1 }
Write-Output "positioning: PASS ($($pillars.Count) pillar(s) in order on $($entries.Count) surface(s), $checked anchor(s); source $docRel)"
exit 0
