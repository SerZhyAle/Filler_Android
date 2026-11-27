#requires -Version 7.0
<#
.SYNOPSIS
    Tests of the positioning order gate check-positioning.ps1 (S0040): the pass case, one failing case per finding class and the
    could-not-verify paths, each on a throw-away copy of the tree, judged by the gate's exit code, its reason lines and its
    verdict line.
.DESCRIPTION
    The copy holds only what the gate reads (the positioning document, the anchors file, the site, the README and the listing
    sources), so a case mutates the copy and never the repository. Every case runs the real gate in its own process.
    -Filter keeps the cases whose name contains the text (a case-insensitive substring), to run in chunks.
.NOTES
    Exit codes: 0 every case passed, 1 a case failed. The last line is `positioning-test: PASS (n case(s))` or
    `positioning-test: FAIL (n of m case(s))`.
#>
[CmdletBinding()]
param(
    [string]$Filter = ''
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$gate = Join-Path $PSScriptRoot 'check-positioning.ps1'
$work = Join-Path ([IO.Path]::GetTempPath()) ('positioning-test-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$pristine = Join-Path $work 'pristine'
$utf8 = [System.Text.UTF8Encoding]::new($false)

function Copy-Subset([string]$From, [string]$To) {
    foreach ($rel in 'docs/SPECIFICATION_POSITIONING.md', 'tools/site/positioning-surfaces.json', 'site', 'README.md', 'docs/play') {
        $dst = Join-Path $To $rel
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
        Copy-Item -LiteralPath (Join-Path $From $rel) -Destination $dst -Recurse -Force
    }
}
function Edit-Text([string]$Tree, [string]$Rel, [string]$Pattern, [string]$Replacement) {
    $path = Join-Path $Tree $Rel
    $old = [IO.File]::ReadAllText($path)
    $new = [regex]::Replace($old, $Pattern, $Replacement)
    if ($new -ceq $old) { throw "mutation changed nothing in $Rel ($Pattern)" }
    [IO.File]::WriteAllText($path, $new, $utf8)
}
# swap two lines of a file by way of a temporary word, so each edit changes the file and no phrase occurs twice at the end
function Swap-Lines([string]$Tree, [string]$Rel, [string]$A, [string]$B) {
    Edit-Text $Tree $Rel ('(?m)^' + [regex]::Escape($A) + '$') 'TEMPSWAPWORD'
    Edit-Text $Tree $Rel ('(?m)^' + [regex]::Escape($B) + '$') $A
    Edit-Text $Tree $Rel '(?m)^TEMPSWAPWORD$' $B
}

$pass = '^positioning: PASS \('
$fail = '^positioning: FAIL \(\d+ finding\(s\)\)$'
$unverified = '^positioning: COULD NOT VERIFY \('
$doc = 'docs/SPECIFICATION_POSITIONING.md'
$cfg = 'tools/site/positioning-surfaces.json'

$cases = @(
    @{ Name = 'pass: the tree as it is'; Exit = 0; Verdict = $pass; Expect = @('5 pillar\(s\) in order on 7 surface\(s\), 35 anchor\(s\)'); Mutate = { param($t) } }
    @{ Name = 'order: the Ukrainian listing lists the schedule before the clean-up'; Exit = 1; Verdict = $fail
       Expect = @("order: docs/play/PLAY_LISTING-uk\.md lists 'schedule' before 'cleanup'")
       Mutate = { param($t) Swap-Lines $t 'docs/play/PLAY_LISTING-uk.md' 'Прибирання завжди' 'За розкладом' } }
    @{ Name = 'order: the README opening lists the watch before the schedule'; Exit = 1; Verdict = $fail
       Expect = @("order: README\.md lists 'watch' before 'schedule'")
       Mutate = { param($t) Edit-Text $t 'README.md' 'covers the Android app and the Wear OS app\.' 'covers the Android app and the watch app.'; Edit-Text $t 'README.md' '^(# Filler for Android)' '${1} for the Wear OS app' } }
    @{ Name = 'anchor: a landing card is renamed'; Exit = 1; Verdict = $fail
       Expect = @('anchor: site/index\.html has 0 occurrence\(s\) of the pillar ''watch'' phrase')
       Mutate = { param($t) Edit-Text $t 'site/index.html' '<h3>Fill from a watch</h3>' '<h3>Fill from a wrist</h3>' } }
    @{ Name = 'anchor: a README phrase occurs twice'; Exit = 1; Verdict = $fail
       Expect = @('anchor: README\.md has 2 occurrence\(s\) of the pillar ''watch'' phrase')
       Mutate = { param($t) Edit-Text $t 'README.md' '^(# Filler for Android)' '${1} Wear OS app' } }
    @{ Name = 'anchor: a listing heading is not a whole line'; Exit = 1; Verdict = $fail
       Expect = @('anchor: docs/play/PLAY_LISTING\.md has 0 occurrence\(s\) of the pillar ''schedule'' phrase')
       Mutate = { param($t) Edit-Text $t 'docs/play/PLAY_LISTING.md' '(?m)^On a schedule$' 'On a schedule now' } }
    @{ Name = 'anchors: the document reorders the pillars, the surfaces do not'; Exit = 1; Verdict = $fail
       Expect = @('anchors: site/index\.html has the pillar ids \[choose, follow, cleanup, schedule, watch\], docs/SPECIFICATION_POSITIONING\.md lists \[choose, cleanup, follow, schedule, watch\]')
       Mutate = { param($t)
           Edit-Text $t $doc '(?m)^2\. \*\*follow\*\*' '2. **TEMPID**'
           Edit-Text $t $doc '(?m)^3\. \*\*cleanup\*\*' '3. **follow**'
           Edit-Text $t $doc '(?m)^2\. \*\*TEMPID\*\*' '2. **cleanup**' } }
    @{ Name = 'surfaces: the document names a file with no entry'; Exit = 1; Verdict = $fail
       Expect = @('surfaces: docs/SPECIFICATION_POSITIONING\.md names site/extra\.html')
       Mutate = { param($t) Edit-Text $t $doc '(?m)^(\| Play listing, Ukrainian \| `docs/play/PLAY_LISTING-uk\.md` \|)$' ('${1}' + "`n" + '| Extra | `site/extra.html` |') } }
    @{ Name = 'surfaces: an entry names a file the document dropped'; Exit = 1; Verdict = $fail
       Expect = @('surfaces: tools/site/positioning-surfaces\.json has an entry for README\.md')
       Mutate = { param($t) Edit-Text $t $doc '(?m)^\| README opening[^\r\n]*\r?\n' '' } }
    @{ Name = 'scope: the scope matches nothing'; Exit = 1; Verdict = $fail
       Expect = @('scope: site/index-uk\.html has no text matching the scope')
       Mutate = { param($t) Edit-Text $t 'site/index-uk.html' '<section aria-labelledby="what-title">' '<section aria-labelledby="what-x">' } }
    @{ Name = 'source: the document lists no pillar in the form'; Exit = 1; Verdict = $fail
       Expect = @('source: docs/SPECIFICATION_POSITIONING\.md lists no pillar')
       Mutate = { param($t) Edit-Text $t $doc '(?m)^(\d)\. \*\*' '${1}) **' } }
    @{ Name = 'source: a pillar is numbered out of sequence'; Exit = 1; Verdict = $fail
       Expect = @("source: docs/SPECIFICATION_POSITIONING\.md numbers the pillar 'schedule' as 5, its place is 4")
       Mutate = { param($t) Edit-Text $t $doc '(?m)^4\. \*\*schedule\*\*' '5. **schedule**' } }
    @{ Name = 'source: an unknown match mode'; Exit = 1; Verdict = $fail
       Expect = @("source: docs/play/PLAY_LISTING\.md has the match mode 'word'")
       Mutate = { param($t) Edit-Text $t $cfg '"match": "line"' '"match": "word"' } }
    @{ Name = 'unverified: the anchors file is missing'; Exit = 2; Verdict = $unverified
       Expect = @('COULD NOT VERIFY - tools/site/positioning-surfaces\.json is missing'); Mutate = { param($t) Remove-Item -LiteralPath (Join-Path $t $cfg) } }
    @{ Name = 'unverified: a surface file is missing'; Exit = 2; Verdict = $unverified
       Expect = @('COULD NOT VERIFY - site/index-ru\.html is missing'); Mutate = { param($t) Remove-Item -LiteralPath (Join-Path $t 'site/index-ru.html') } }
    @{ Name = 'unverified: the anchors file is no JSON'; Exit = 2; Verdict = $unverified
       Expect = @('COULD NOT VERIFY - tools/site/positioning-surfaces\.json is not JSON'); Mutate = { param($t) [IO.File]::WriteAllText((Join-Path $t $cfg), '{ "surfaces": [', $utf8) } }
)

if ($Filter) { $cases = @($cases | Where-Object { $_.Name -like "*$Filter*" }) }
if ($cases.Count -eq 0) { Write-Output "positioning-test: FAIL (no case matches '$Filter')"; exit 1 }

New-Item -ItemType Directory -Force -Path $pristine | Out-Null
Copy-Subset $repo $pristine
$failed = 0
try {
    foreach ($case in $cases) {
        $tree = Join-Path $work ([Guid]::NewGuid().ToString('N').Substring(0, 8))
        Copy-Item -LiteralPath $pristine -Destination $tree -Recurse -Force
        $problems = [System.Collections.Generic.List[string]]::new()
        try { & $case.Mutate $tree }
        catch { $problems.Add("the mutation failed: $($_.Exception.Message)") }
        if ($problems.Count -eq 0) {
            $out = @(& pwsh -NoProfile -File $gate -Root $tree 2>&1 | ForEach-Object { "$_" })
            $code = $LASTEXITCODE
            if ($code -ne $case.Exit) { $problems.Add("exit $code, expected $($case.Exit)") }
            $last = @($out | Where-Object { $_.Trim() -ne '' }) | Select-Object -Last 1
            if ($last -notmatch $case.Verdict) { $problems.Add("verdict line '$last' does not match $($case.Verdict)") }
            foreach ($rx in $case.Expect) {
                if (-not @($out | Where-Object { $_ -match $rx }).Count) { $problems.Add("no output line matches /$rx/") }
            }
            if ($problems.Count -gt 0) { foreach ($l in $out) { $problems.Add("  gate: $l") } }
        }
        if ($problems.Count -eq 0) { Write-Output "ok   $($case.Name)" }
        else {
            $failed++
            Write-Output "FAIL $($case.Name)"
            foreach ($p in $problems) { Write-Output "     $p" }
        }
    }
}
finally { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
if ($failed -gt 0) { Write-Output "positioning-test: FAIL ($failed of $($cases.Count) case(s))"; exit 1 }
Write-Output "positioning-test: PASS ($($cases.Count) case(s))"
exit 0
