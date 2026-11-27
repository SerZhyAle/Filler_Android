#requires -Version 7.0
<#
.SYNOPSIS
    The facts gate of the site (S0039): the facts the pages and the store texts type by hand, compared with their sources, as
    SITE-REPRESENTATION rule 3 asks and rule 12 follows.
.DESCRIPTION
    Sources of truth read here, never the pages:
      - the <uses-permission> elements of phone/src/main/AndroidManifest.xml and wear/src/main/AndroidManifest.xml (an element
        marked tools:node="remove" is not declared); the count per app, and that neither declares INTERNET;
      - the values* folders of phone/src/main/res and wear/src/main/res: a language folder (values-<lang>, values-<lang>-r<REGION>,
        values-b+<lang>+...) is a locale and the folder values is the default one; any other qualifier (notround, night, ..) is
        not. The phone app's count is the interface languages of the Android app; the watch app's locales are a subset of it;
      - publishedApplicationId in phone/build.gradle.kts and wear/build.gradle.kts (equal);
      - the <loc> entries of site/sitemap.xml: the count of pages.
    Statements compared (each is a regular expression over a named block of a named file, in the page's own language; the
    number is a digit string or a number word of that language, and an unknown word is a finding):
      permissions: the landing group "Privacy and permissions" and privacy section 5 in en, ru and uk, docs/play/PLAY_DATA_SAFETY.md
        and the SITE-REPRESENTATION pointer, against the two manifests;
      languages: the interface-language sentence of the three landing pages and the three listing sources against the phone
        app's locales;
      pages: the counts of pages in the SITE-STRUCTURE pointer against the sitemap - all its pages, and those of the
        primary language, which the search threshold counts;
      app-id: every com.sza.* identifier typed in site/*.html, README.md and docs/play/*.md, every Play link and the Play link
        of tools/site/check-site.ps1, against publishedApplicationId; the id written in <code> on each landing page.
    Scope (FILLER-0071, REPO-LAYOUT 0.12 rule 8): the five patterns that read the two SITE-* contract pointers are
      local-only, and the pointer files are gitignored. The default scope declares them like any other input, so a fresh
      clone without them is exit 2 (CHECK-VERDICT rule 13: a skipped declared input is could-not-verify). -Scope public
      drops them from this run's declaration and says so; the CI composition of .github/workflows/pages.yml runs it.
    Findings (every one is fatal; there is no baseline, CHECK-BASELINE is not applicable here):
      source: the two applicationIds differ; a watch locale the phone app lacks; INTERNET declared; a manifest declares no
        permission or no locale folder exists (a gate that inspects nothing).
      permissions, languages, pages, app-id: a statement missing, the wrong number of statements, a number word the table does
        not know, or a number that is not the source's.
    The run does not stop at the first finding (CHECK-VERDICT rule 9). The gate makes no request and builds nothing.
.NOTES
    Exit codes: 0 PASS, 1 FAIL (one reason line per finding), 2 COULD NOT VERIFY (a missing or unreadable input, a reason line
    per cause). The verdict line is the last line written, on every path (CHECK-VERDICT rules 1, 5, 11):
      site-facts: PASS (<counts>) | site-facts: FAIL (<n> finding(s)) | site-facts: COULD NOT VERIFY (<what>)
    -Root is the repository root; test-site-facts.ps1 points it at throw-away copies.
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [ValidateSet('all', 'public')]
    [string]$Scope = 'all'
)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$androidNs = 'http://schemas.android.com/apk/res/android'
$toolsNs = 'http://schemas.android.com/tools'

$findings = [System.Collections.Generic.List[string]]::new()
$unverified = [System.Collections.Generic.List[string]]::new()
function Add-Finding([string]$Class, [string]$Message) { $findings.Add("${Class}: $Message") }
function Read-Text([string]$Rel) {
    $path = Join-Path $Root $Rel
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $unverified.Add("$Rel is missing"); return $null }
    return [IO.File]::ReadAllText($path, $utf8)
}
function Get-Permissions([string]$Rel) {
    $text = Read-Text $Rel
    if ($null -eq $text) { return $null }
    try { $x = [xml]$text } catch { $unverified.Add("$Rel is not XML ($($_.Exception.Message))"); return $null }
    return @($x.SelectNodes('/manifest/*') | Where-Object { $_.LocalName -like 'uses-permission*' } | ForEach-Object {
            [pscustomobject]@{ Name = $_.GetAttribute('name', $androidNs); Removed = ($_.GetAttribute('node', $toolsNs) -eq 'remove') }
        })
}
function Get-Locales([string]$ResRel) {
    $dir = Join-Path $Root $ResRel
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { $unverified.Add("$ResRel is missing"); return $null }
    $set = [System.Collections.Generic.List[string]]::new()
    foreach ($d in Get-ChildItem -LiteralPath $dir -Directory) {
        if ($d.Name -eq 'values') { $set.Add('default'); continue }
        if ($d.Name -match '^values-((?:[a-z]{2,3}(?:-r[A-Z]{2})?)|(?:b\+[A-Za-z]{2,3}(?:\+[A-Za-z0-9]+)*))$') { $set.Add($Matches[1]) }
    }
    return , $set.ToArray()
}
function Get-AppId([string]$Rel) {
    $text = Read-Text $Rel
    if ($null -eq $text) { return $null }
    $m = [regex]::Match($text, 'val\s+publishedApplicationId\s*=\s*"([^"]+)"')
    if (-not $m.Success) { $unverified.Add("$Rel declares no publishedApplicationId"); return $null }
    return $m.Groups[1].Value
}

# ---- the sources ----
$phonePerms = Get-Permissions 'phone/src/main/AndroidManifest.xml'
$wearPerms = Get-Permissions 'wear/src/main/AndroidManifest.xml'
$phoneLocales = Get-Locales 'phone/src/main/res'
$wearLocales = Get-Locales 'wear/src/main/res'
$phoneId = Get-AppId 'phone/build.gradle.kts'
$wearId = Get-AppId 'wear/build.gradle.kts'
$sitemap = Read-Text 'site/sitemap.xml'
$sitemapPages = if ($null -ne $sitemap) { [regex]::Matches($sitemap, '<loc>([^<]+)</loc>').Count } else { $null }
# a locale variant carries the suffix -<code>; the pages of the primary language carry none (SITE-STRUCTURE section 9 item C)
$primaryPages = if ($null -ne $sitemap) { @([regex]::Matches($sitemap, '<loc>([^<]+)</loc>') | Where-Object { $_.Groups[1].Value -notmatch '-[a-z]{2}\.html$' }).Count } else { $null }
if ($unverified.Count -gt 0) {
    foreach ($r in $unverified) { Write-Output "COULD NOT VERIFY - $r" }
    Write-Output "site-facts: COULD NOT VERIFY ($($unverified.Count) input(s) missing or unreadable)"
    exit 2
}
$declared = @{ phone = @($phonePerms | Where-Object { -not $_.Removed }); wear = @($wearPerms | Where-Object { -not $_.Removed }) }
if ($declared.phone.Count -eq 0) { Add-Finding 'source' 'phone/src/main/AndroidManifest.xml declares no permission (a count of zero would make every statement wrong, and the gate would read nothing)' }
if ($declared.wear.Count -eq 0) { Add-Finding 'source' 'wear/src/main/AndroidManifest.xml declares no permission' }
foreach ($m in @(@('phone', $declared.phone), @('wear', $declared.wear))) {
    foreach ($p in $m[1]) { if ($p.Name -match '(^|\.)INTERNET$') { Add-Finding 'source' "$($m[0]) manifest declares $($p.Name); the pages say Filler has no internet access" } }
}
if ($phoneLocales.Count -eq 0) { Add-Finding 'source' 'phone/src/main/res has no values folder' }
$phoneSet = @($phoneLocales | Where-Object { $_ -ne 'default' })
foreach ($l in @($wearLocales | Where-Object { $_ -ne 'default' })) {
    if ($phoneSet -notcontains $l) { Add-Finding 'source' "the watch app has the locale $l, which the phone app lacks (the watch fans out to the phone's locales)" }
}
if ($phoneId -ne $wearId) { Add-Finding 'source' "publishedApplicationId is '$phoneId' in phone and '$wearId' in wear (the Wear Data Layer routes by it; they stay identical)" }
$appId = $phoneId
$sourceValues = @{
    phonePermissions = $declared.phone.Count
    watchPermissions = $declared.wear.Count
    phoneLocales     = $phoneLocales.Count
    sitemapPages     = $sitemapPages
    primaryPages     = $primaryPages
}

# ---- the statements ----
$numberWords = @{
    en = @{ one = 1; two = 2; three = 3; four = 4; five = 5; six = 6; seven = 7; eight = 8; nine = 9; ten = 10 }
    ru = @{ 'один' = 1; 'одного' = 1; 'два' = 2; 'двух' = 2; 'три' = 3; 'трёх' = 3; 'четыре' = 4; 'четырёх' = 4; 'пять' = 5; 'пяти' = 5
        'шесть' = 6; 'шести' = 6; 'семь' = 7; 'семи' = 7; 'восемь' = 8; 'восьми' = 8; 'девять' = 9; 'девяти' = 9; 'десять' = 10; 'десяти' = 10 }
    uk = @{ 'один' = 1; 'одного' = 1; 'два' = 2; 'двох' = 2; 'три' = 3; 'трьох' = 3; 'чотири' = 4; 'чотирьох' = 4; "п'ять" = 5; "п'яти" = 5
        'шість' = 6; 'шести' = 6; 'сім' = 7; 'семи' = 7; 'вісім' = 8; 'восьми' = 8; "дев'ять" = 9; "дев'яти" = 9; 'десять' = 10; 'десяти' = 10 }
}
function ConvertTo-Number([string]$Word, [string]$Lang) {
    $w = $Word.Trim().ToLowerInvariant().Replace([string][char]0x2019, "'")
    if ($w -match '^\d+$') { return [int]$w }
    if ($numberWords[$Lang].ContainsKey($w)) { return [int]$numberWords[$Lang][$w] }
    return $null
}
$privacyBlockRx = '<h2 id="permissions">[\s\S]*?(?=<h2)'
$landingPrivacyRx = '<details class="sec" id="privacy">[\s\S]*?</details>'
$perm = @('phonePermissions', 'watchPermissions')
$claims = @(
    @{ Class = 'permissions'; File = 'site/index.html'; Lang = 'en'; Block = $landingPrivacyRx; Rx = 'app asks for (\w+)'; Expect = $perm }
    @{ Class = 'permissions'; File = 'site/index-ru.html'; Lang = 'ru'; Block = $landingPrivacyRx; Rx = 'запрашивает (\S+)'; Expect = $perm }
    @{ Class = 'permissions'; File = 'site/index-uk.html'; Lang = 'uk'; Block = $landingPrivacyRx; Rx = 'запитує (\S+)'; Expect = $perm }
    @{ Class = 'permissions'; File = 'site/privacy.html'; Lang = 'en'; Block = $privacyBlockRx; Rx = 'app asks for (\w+) permissions'; Expect = $perm }
    @{ Class = 'permissions'; File = 'site/privacy.html'; Lang = 'en'; Block = $privacyBlockRx; Rx = 'None of the (\w+) gives'; Expect = $perm }
    @{ Class = 'permissions'; File = 'site/privacy-ru.html'; Lang = 'ru'; Block = $privacyBlockRx; Rx = 'запрашивает (\S+) разрешени'; Expect = $perm }
    @{ Class = 'permissions'; File = 'site/privacy-ru.html'; Lang = 'ru'; Block = $privacyBlockRx; Rx = 'Ни одно из (\S+) не'; Expect = $perm }
    @{ Class = 'permissions'; File = 'site/privacy-uk.html'; Lang = 'uk'; Block = $privacyBlockRx; Rx = 'запитує (\S+) дозвол'; Expect = $perm }
    @{ Class = 'permissions'; File = 'site/privacy-uk.html'; Lang = 'uk'; Block = $privacyBlockRx; Rx = 'Жоден із (\S+) не'; Expect = $perm }
    @{ Class = 'permissions'; File = 'docs/play/PLAY_DATA_SAFETY.md'; Lang = 'en'; Rx = 'the (\w+) of the scheduled fill'; Expect = @('phonePermissions') }
    @{ Class = 'permissions'; File = 'docs/play/PLAY_DATA_SAFETY.md'; Lang = 'en'; Rx = 'the (\w+) of the watch run'; Expect = @('watchPermissions') }
    @{ Class = 'permissions'; File = 'docs/contracts/SITE-REPRESENTATION.md'; Lang = 'en'; Rx = 'AndroidManifest\.xml` \((\w+)[\s)]'; Expect = $perm; Local = $true }
    @{ Class = 'permissions'; File = 'docs/contracts/SITE-REPRESENTATION.md'; Lang = 'en'; Rx = '\((\w+) permissions on the phone, (\w+) on the watch'; Expect = $perm; Local = $true }
    @{ Class = 'languages'; File = 'site/index.html'; Lang = 'en'; Rx = 'interface is in (\d+) languages'; Expect = @('phoneLocales') }
    @{ Class = 'languages'; File = 'site/index-ru.html'; Lang = 'ru'; Rx = 'Интерфейс приложения для Android доступен на (\d+) языках'; Expect = @('phoneLocales') }
    @{ Class = 'languages'; File = 'site/index-uk.html'; Lang = 'uk'; Rx = 'Інтерфейс застосунку для Android доступний (\d+) мовами'; Expect = @('phoneLocales') }
    @{ Class = 'languages'; File = 'docs/play/PLAY_LISTING.md'; Lang = 'en'; Rx = 'interface is in (\d+) languages'; Expect = @('phoneLocales') }
    @{ Class = 'languages'; File = 'docs/play/PLAY_LISTING-ru.md'; Lang = 'ru'; Rx = 'Интерфейс приложения для Android доступен на (\d+) языках'; Expect = @('phoneLocales') }
    @{ Class = 'languages'; File = 'docs/play/PLAY_LISTING-uk.md'; Lang = 'uk'; Rx = 'Інтерфейс застосунку для Android доступний (\d+) мовами'; Expect = @('phoneLocales') }
    @{ Class = 'pages'; File = 'docs/contracts/SITE-STRUCTURE.md'; Lang = 'en'; Rx = '\((\w+) pages in the primary language against the threshold'; Expect = @('primaryPages'); Local = $true }
    @{ Class = 'pages'; File = 'docs/contracts/SITE-STRUCTURE.md'; Lang = 'en'; Rx = 'lists exactly the (\w+) pages'; Expect = @('sitemapPages'); Local = $true }
    @{ Class = 'pages'; File = 'docs/contracts/SITE-STRUCTURE.md'; Lang = 'en'; Rx = 'the sitemap and the (\w+) files agree'; Expect = @('sitemapPages'); Local = $true }
)
# REPO-LAYOUT 0.12 rule 8 (FILLER-0071): the two SITE-* contract pointers are local-only and gitignored, so a fresh
# clone carries no copy. The default scope declares their five patterns like any other input - a fresh clone is exit 2
# there (CHECK-VERDICT rule 13, a skipped declared input). -Scope public drops them from this run's declaration and
# says so; the CI composition of .github/workflows/pages.yml runs the public scope.
$scoped = @($claims | Where-Object { $Scope -eq 'all' -or -not $_.Local })
if ($scoped.Count -lt $claims.Count) {
    Write-Output "site-facts: scope public, $($claims.Count - $scoped.Count) local-only pattern(s) with a gitignored source not declared in this run"
}
$checked = 0
foreach ($c in $scoped) {
    $text = Read-Text $c.File
    if ($null -eq $text) { continue }
    $subject = $text
    if ($c.Block) {
        $b = [regex]::Match($text, $c.Block)
        if (-not $b.Success) { Add-Finding $c.Class "$($c.File) has no block matching $($c.Block)"; continue }
        $subject = $b.Value
    }
    $values = @()
    # a space of a pattern is any run of white space: the pages wrap their lines anywhere
    foreach ($m in [regex]::Matches($subject, ($c.Rx -replace ' ', '\s+'))) { for ($g = 1; $g -lt $m.Groups.Count; $g++) { $values += $m.Groups[$g].Value } }
    if ($values.Count -ne $c.Expect.Count) {
        Add-Finding $c.Class "$($c.File) has $($values.Count) statement(s) matching /$($c.Rx)/, the source needs $($c.Expect.Count)"
        continue
    }
    for ($i = 0; $i -lt $values.Count; $i++) {
        $checked++
        $n = ConvertTo-Number $values[$i] $c.Lang
        $want = $sourceValues[$c.Expect[$i]]
        if ($null -eq $n) { Add-Finding $c.Class "$($c.File): '$($values[$i])' is not a number the gate knows in $($c.Lang) (/$($c.Rx)/)" }
        elseif ($n -ne $want) { Add-Finding $c.Class "$($c.File) says $($values[$i]) ($n), the source $($c.Expect[$i]) is $want (/$($c.Rx)/)" }
    }
}

# ---- the application id ----
$idRx = [regex]::new('(?<![A-Za-z0-9_.])com\.sza\.[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)*')
$playRx = [regex]::new('play\.google\.com/store/apps/details\?id=([A-Za-z0-9_.]+)')
$typedIn = [System.Collections.Generic.List[string]]::new()
foreach ($rel in @('README.md', 'tools/site/check-site.ps1')) { $typedIn.Add($rel) }
foreach ($d in @(@('site', '*.html'), @('docs/play', '*.md'))) {
    $dir = Join-Path $Root $d[0]
    if (Test-Path -LiteralPath $dir -PathType Container) { foreach ($f in Get-ChildItem -LiteralPath $dir -Filter $d[1] -File) { $typedIn.Add("$($d[0])/$($f.Name)") } }
    else { $unverified.Add("$($d[0]) is missing") }
}
$idStatements = 0
foreach ($rel in $typedIn) {
    $text = Read-Text $rel
    if ($null -eq $text) { continue }
    if ($rel -ne 'tools/site/check-site.ps1') {
        foreach ($m in $idRx.Matches($text)) {
            $idStatements++
            if ($m.Value -ne $appId) { Add-Finding 'app-id' "$rel types $($m.Value), the application id is $appId" }
        }
    }
    foreach ($m in $playRx.Matches($text)) {
        $idStatements++
        if ($m.Groups[1].Value -ne $appId) { Add-Finding 'app-id' "$rel links the Play listing of $($m.Groups[1].Value), the application id is $appId" }
    }
}
foreach ($rel in @('site/index.html', 'site/index-ru.html', 'site/index-uk.html')) {
    $text = Read-Text $rel
    if ($null -ne $text -and -not $text.Contains("<code>$appId</code>")) { Add-Finding 'app-id' "$rel does not state the application id in <code>$appId</code>" }
}
if ($idStatements -eq 0) { Add-Finding 'app-id' 'no application id was found in any scanned file (a gate that inspects nothing)' }

if ($unverified.Count -gt 0) {
    foreach ($r in $unverified) { Write-Output "COULD NOT VERIFY - $r" }
    Write-Output "site-facts: COULD NOT VERIFY ($($unverified.Count) input(s) missing or unreadable)"
    exit 2
}
foreach ($f in $findings) { Write-Output "FAIL: $f" }
if ($findings.Count -gt 0) { Write-Output "site-facts: FAIL ($($findings.Count) finding(s))"; exit 1 }
Write-Output "site-facts: PASS ($checked statement(s) of $($scoped.Count) pattern(s); phone $($declared.phone.Count) and watch $($declared.wear.Count) permission(s), $($phoneLocales.Count) phone locale(s), $($wearLocales.Count) watch locale(s), $sitemapPages page(s), $idStatements application id statement(s), id $appId)"
exit 0
