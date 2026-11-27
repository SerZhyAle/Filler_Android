#requires -Version 7.0
<#
.SYNOPSIS
    Tests of the language gate check-locales.ps1 and, through it, of render-translations.ps1 (FILLER-0079): the pass case,
    one failing case per finding class and the could-not-verify path, each on a throw-away copy of the tree, judged by the
    gate's exit code, its reason lines and its verdict line.
.DESCRIPTION
    The copy holds only what the gate reads, so a case mutates the copy and never the repository. Every case runs the real
    gate in its own process. A case marked Strings skips the document render. -Filter keeps the cases whose name contains
    the text (a case-insensitive substring), to run in chunks.
.NOTES
    Exit codes: 0 every case passed, 1 a case failed. The last line is `locales-test: PASS (n case(s))` or
    `locales-test: FAIL (n of m case(s))`.
#>
[CmdletBinding()]
param(
    [string]$Filter = ''
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$gate = Join-Path $PSScriptRoot 'check-locales.ps1'
$work = Join-Path ([IO.Path]::GetTempPath()) ('locales-test-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$pristine = Join-Path $work 'pristine'
$utf8 = [System.Text.UTF8Encoding]::new($false)
$linksRel = 'filler-core/src/main/java/com/sza/filler/about/FillerProductLinks.kt'

function Copy-Subset([string]$From, [string]$To) {
    $files = @('tools/locale/locales.json', $linksRel, 'phone/src/main/AndroidManifest.xml', 'wear/src/main/AndroidManifest.xml')
    $files += @(Get-ChildItem -LiteralPath $From -Filter 'README*.md' -File | ForEach-Object { $_.Name })
    $files += @(Get-ChildItem -LiteralPath (Join-Path $From 'docs') -Filter 'INSTALL_TRUST*.md' -File | ForEach-Object { "docs/$($_.Name)" })
    $files += @(Get-ChildItem -LiteralPath (Join-Path $From 'docs/play') -Filter 'PLAY_LISTING*.md' -File | ForEach-Object { "docs/play/$($_.Name)" })
    foreach ($rel in $files) {
        $dst = Join-Path $To $rel
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
        Copy-Item -LiteralPath (Join-Path $From $rel) -Destination $dst -Force
    }
    foreach ($rel in 'site', 'tools/locale/dictionaries') {
        $dst = Join-Path $To $rel
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
        Copy-Item -LiteralPath (Join-Path $From $rel) -Destination $dst -Recurse -Force
    }
    foreach ($m in 'phone', 'wear') {
        foreach ($dir in Get-ChildItem -LiteralPath (Join-Path $From "$m/src/main/res") -Directory | Where-Object { $_.Name -like 'values*' -or $_.Name -eq 'xml' }) {
            $dst = Join-Path $To "$m/src/main/res/$($dir.Name)"
            New-Item -ItemType Directory -Force -Path $dst | Out-Null
            Copy-Item -Path (Join-Path $dir.FullName '*') -Destination $dst -Force
        }
    }
}
function Edit-Text([string]$Tree, [string]$Rel, [string]$Pattern, [string]$Replacement) {
    $path = Join-Path $Tree $Rel
    $old = [IO.File]::ReadAllText($path)
    $new = [regex]::new($Pattern).Replace($old, $Replacement, 1)
    if ($new -ceq $old) { throw "mutation changed nothing in $Rel ($Pattern)" }
    [IO.File]::WriteAllText($path, $new, $utf8)
}

$pass = '^locales: PASS \('
$fail = '^locales: FAIL \(\d+ finding\(s\)\)$'
$unverified = '^locales: COULD NOT VERIFY \('
$deWear = 'wear/src/main/res/values-de/strings_filler.xml'

$cases = @(
    @{ Name = 'pass: the tree as it is'; Exit = 0; Verdict = $pass; Expect = @('13 languages'); Mutate = { param($t) } }
    @{ Name = 'strings: a watch string is missing'; Strings = $true; Exit = 1; Verdict = $fail
       Expect = @('wear/values-de lacks filler_start'); Mutate = { param($t) Edit-Text $t $deWear '(?m)^\s*<string name="filler_start">.*\r?\n' '' } }
    @{ Name = 'strings: a format argument differs'; Strings = $true; Exit = 1; Verdict = $fail
       Expect = @('wear/values-de: filler_progress has the format arguments'); Mutate = { param($t) Edit-Text $t $deWear '(<string name="filler_progress">[^<]*?)%2\$s' '${1}' } }
    @{ Name = 'strings: a bare apostrophe'; Strings = $true; Exit = 1; Verdict = $fail
       Expect = @('wear/values-de: filler_start has an apostrophe'); Mutate = { param($t) Edit-Text $t $deWear '(<string name="filler_start">)' '${1}''' } }
    @{ Name = 'strings: a key English lacks'; Strings = $true; Exit = 1; Verdict = $fail
       Expect = @('wear/values-de adds filler_extra'); Mutate = { param($t) Edit-Text $t $deWear '</resources>' '<string name="filler_extra">x</string></resources>' } }
    @{ Name = 'strings: a folder outside the list'; Strings = $true; Exit = 1; Verdict = $fail
       Expect = @('wear/values-nl carries strings'); Mutate = { param($t) $d = Join-Path $t 'wear/src/main/res/values-nl'; New-Item -ItemType Directory -Force $d | Out-Null; [IO.File]::WriteAllText((Join-Path $d 'strings.xml'), '<resources><string name="a">a</string></resources>') } }
    @{ Name = 'config: a language is not offered'; Strings = $true; Exit = 1; Verdict = $fail
       Expect = @('phone locales_config\.xml lists'); Mutate = { param($t) Edit-Text $t 'phone/src/main/res/xml/locales_config.xml' '(?m)^\s*<locale android:name="ur" />\r?\n' '' } }
    @{ Name = 'config: the manifest does not name it'; Strings = $true; Exit = 1; Verdict = $fail
       Expect = @('wear manifest does not name'); Mutate = { param($t) Edit-Text $t 'wear/src/main/AndroidManifest.xml' 'android:localeConfig="@xml/locales_config"' '' } }
    @{ Name = 'links: a language has no page address'; Strings = $true; Exit = 1; Verdict = $fail
       Expect = @("FillerProductLinks does not answer 'de' with .*index-de\.html"); Mutate = { param($t) Edit-Text $t $linksRel '"de" -> "https://serzhyale\.github\.io/Filler_Android/index-de\.html"' '"de" -> "https://serzhyale.github.io/Filler_Android/"' } }
    @{ Name = 'documents: a rendered page edited by hand'; Exit = 1; Verdict = $fail
       Expect = @('site/index-de\.html differs from its render'); Mutate = { param($t) Edit-Text $t 'site/index-de.html' '</footer>' ' </footer>' } }
    @{ Name = 'documents: a changed English sentence'; Exit = 1; Verdict = $fail
       Expect = @("de: no translation of 'Filler for Android, changed'"); Mutate = { param($t) Edit-Text $t 'README.md' '# Filler for Android' '# Filler for Android, changed' } }
    @{ Name = 'documents: a translation loses a link'; Exit = 1; Verdict = $fail
       Expect = @('de: tags, links or code spans differ'); Mutate = { param($t) Edit-Text $t 'tools/locale/dictionaries/de.json' '(\.": "[^\n]*?)\]\(LICENSE\)' '${1}] LICENSE' } }
    @{ Name = 'unverified: no language list'; Strings = $true; Exit = 2; Verdict = $unverified
       Expect = @('tools/locale/locales\.json is missing'); Mutate = { param($t) Remove-Item -LiteralPath (Join-Path $t 'tools/locale/locales.json') } }
)

$selected = @($cases | Where-Object { $_.Name -like "*$Filter*" })
if ($selected.Count -eq 0) { Write-Output "locales-test: FAIL (0 of 0 case(s): nothing matches '$Filter')"; exit 1 }
$failed = 0
try {
    Copy-Subset $repo $pristine
    $i = 0
    foreach ($case in $selected) {
        $i++
        $tree = Join-Path $work "case$i"
        Copy-Item -LiteralPath $pristine -Destination $tree -Recurse -Force
        & $case.Mutate $tree
        $arguments = @('-NoProfile', '-File', $gate, '-Root', $tree)
        if ($case.Strings) { $arguments += '-SkipDocuments' }
        $out = @(& pwsh @arguments 2>&1 | ForEach-Object { "$_" })
        $code = $LASTEXITCODE
        $problems = @()
        if ($code -ne $case.Exit) { $problems += "exit $code, expected $($case.Exit)" }
        if (($out | Select-Object -Last 1) -notmatch $case.Verdict) { $problems += "last line '$($out | Select-Object -Last 1)'" }
        foreach ($e in $case.Expect) { if (-not ($out -match $e)) { $problems += "no line matches $e" } }
        if ($problems.Count) {
            $failed++
            Write-Output "FAIL $($case.Name): $($problems -join '; ')"
            $out | Select-Object -First 8 | ForEach-Object { Write-Output "    $_" }
        }
        else { Write-Output "ok   $($case.Name)" }
        Remove-Item -LiteralPath $tree -Recurse -Force
    }
}
finally { if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force } }
if ($failed) { Write-Output "locales-test: FAIL ($failed of $($selected.Count) case(s))"; exit 1 }
Write-Output "locales-test: PASS ($($selected.Count) case(s))"
exit 0
