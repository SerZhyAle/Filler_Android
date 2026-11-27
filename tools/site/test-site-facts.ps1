#requires -Version 7.0
<#
.SYNOPSIS
    Tests of the two site gates added by S0039 - the held-address and anchor block of check-site.ps1 and the facts gate
    check-site-facts.ps1: the pass case, one failing case per finding class and the could-not-verify path, each on a
    throw-away copy of the tree, judged by the gate's exit code, its reason lines and its verdict line.
.DESCRIPTION
    The copy holds only what the gates read (the site, the README, the listing sources, the two contract pointers, the held-
    address list, the two manifests, the build scripts, and empty values* folders for the locale count), so a case mutates the
    copy and never the repository. Every case runs the real gate in its own process; the page gate keeps reading the
    translation pin of the repository, so a mutation never touches visible English text.
    -Filter keeps the cases whose name contains the text (a case-insensitive substring), to run in chunks: the unfiltered run
    has no recorded wall time (each case is about 0.5 s plus the copy).
.NOTES
    Exit codes: 0 every case passed, 1 a case failed. The last line is `site-facts-test: PASS (n case(s))` or
    `site-facts-test: FAIL (n of m case(s))`.
#>
[CmdletBinding()]
param(
    [string]$Filter = ''
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$gates = @{ site = (Join-Path $PSScriptRoot 'check-site.ps1'); facts = (Join-Path $PSScriptRoot 'check-site-facts.ps1') }
$work = Join-Path ([IO.Path]::GetTempPath()) ('site-facts-test-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$pristine = Join-Path $work 'pristine'
$utf8 = [System.Text.UTF8Encoding]::new($false)

function Copy-Subset([string]$From, [string]$To) {
    foreach ($rel in @(Get-ChildItem -LiteralPath $From -Filter 'README_*.md' -File | ForEach-Object { $_.Name }) + @('site', 'README.md', 'tools/locale/locales.json', 'filler-core/src/main/java/com/sza/filler/about/FillerProductLinks.kt', 'tools/site/check-site.ps1', 'phone/build.gradle.kts', 'wear/build.gradle.kts',
        'phone/src/main/AndroidManifest.xml', 'wear/src/main/AndroidManifest.xml', 'docs/site-held-addresses.jsonl',
        'docs/SPECIFICATION_FAMILY_MAP_ROW.md', 'docs/play', 'docs/contracts/SITE-STRUCTURE.md', 'docs/contracts/SITE-REPRESENTATION.md')) {
        $dst = Join-Path $To $rel
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
        Copy-Item -LiteralPath (Join-Path $From $rel) -Destination $dst -Recurse -Force
    }
    foreach ($m in 'phone', 'wear') {
        foreach ($dir in Get-ChildItem -LiteralPath (Join-Path $From "$m/src/main/res") -Directory | Where-Object { $_.Name -like 'values*' }) {
            New-Item -ItemType Directory -Force -Path (Join-Path $To "$m/src/main/res/$($dir.Name)") | Out-Null
        }
    }
}
function Edit-Text([string]$Tree, [string]$Rel, [string]$Pattern, [string]$Replacement) {
    $path = Join-Path $Tree $Rel
    $old = [IO.File]::ReadAllText($path)
    $new = [regex]::Replace($old, $Pattern, $Replacement)
    if ($new -ceq $old) { throw "mutation changed nothing in $Rel ($Pattern)" }
    [IO.File]::WriteAllText($path, $new, $utf8)
}
function Add-Dir([string]$Tree, [string]$Rel) { New-Item -ItemType Directory -Force -Path (Join-Path $Tree $Rel) | Out-Null }
function Add-File([string]$Tree, [string]$Rel, [string]$Text) {
    $path = Join-Path $Tree $Rel
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
    [IO.File]::WriteAllText($path, $Text, $utf8)
}

$sitePass = '^site-check: PASS \('
$siteFail = '^site-check: FAIL \(\d+ finding\(s\) in \d+ page\(s\)\)$'
$factsPass = '^site-facts: PASS \('
$factsFail = '^site-facts: FAIL \(\d+ finding\(s\)\)$'
$factsUnverified = '^site-facts: COULD NOT VERIFY \('
$list = 'docs/site-held-addresses.jsonl'
$priv = 'https://serzhyale.github.io/Filler_Android/privacy.html'
$phoneManifest = 'phone/src/main/AndroidManifest.xml'
$wearManifest = 'wear/src/main/AndroidManifest.xml'
$perm = '    <uses-permission android:name="android.permission.{0}" />'

$cases = @(
    @{ Name = 'site pass: the tree as it is'; Gate = 'site'; Exit = 0; Verdict = $sitePass; Expect = @('held addresses: 43 holder\(s\), 26 page row\(s\)'); Mutate = { param($t) } }
    @{ Name = 'held: list missing'; Gate = 'site'; Exit = 1; Verdict = $siteFail
       Expect = @('docs/site-held-addresses\.jsonl: missing'); Mutate = { param($t) Remove-Item -LiteralPath (Join-Path $t $list) } }
    @{ Name = 'held: line is no JSON'; Gate = 'site'; Exit = 1; Verdict = $siteFail
       Expect = @('site-held-addresses\.jsonl:\d+: not one JSON object'); Mutate = { param($t) Add-File $t $list ([IO.File]::ReadAllText((Join-Path $t $list)) + "{not json`n") } }
    @{ Name = 'held: address is no page'; Gate = 'site'; Exit = 1; Verdict = $siteFail
       Expect = @('H01 holds .*privacy-xx\.html, which is not a page of the site')
       Mutate = { param($t) Edit-Text $t $list '("id":"H01".*?"address":")[^"]+' '${1}https://serzhyale.github.io/Filler_Android/privacy-xx.html' } }
    @{ Name = 'held: fragment is no id'; Gate = 'site'; Exit = 1; Verdict = $siteFail
       Expect = @("H01 holds .*privacy\.html#nowhere, and privacy\.html has no id 'nowhere'")
       Mutate = { param($t) Edit-Text $t $list '("id":"H01".*?"address":"[^"]+)' '${1}#nowhere' } }
    @{ Name = 'held: held row without an answer date'; Gate = 'site'; Exit = 1; Verdict = $siteFail
       Expect = @('H01 is held and has no answered200 date')
       Mutate = { param($t) Edit-Text $t $list '("id":"H01".*?"answered200":)"2026-11-13"' '${1}null' } }
    @{ Name = 'held: pending row with a date'; Gate = 'site'; Exit = 1; Verdict = $siteFail
       Expect = @('H03 is pending-200 and carries a date')
       Mutate = { param($t) Edit-Text $t $list '("id":"H03".*?"answered200":)null' '${1}"2026-11-14"' } }
    @{ Name = 'held: unknown state'; Gate = 'site'; Exit = 1; Verdict = $siteFail
       Expect = @("H04 has state 'planned'"); Mutate = { param($t) Edit-Text $t $list '("id":"H04".*?"state":")pending-200' '${1}planned' } }
    @{ Name = 'held: named file does not carry the address'; Gate = 'site'; Exit = 1; Verdict = $siteFail
       Expect = @('H01 names README\.md, which does not carry', 'README\.md: carries .*privacy-ru\.html, which no holder row of docs/site-held-addresses\.jsonl lists')
       Mutate = { param($t) Edit-Text $t 'README.md' 'Filler_Android/privacy\.html' 'Filler_Android/privacy-ru.html' } }
    @{ Name = 'held: named file missing'; Gate = 'site'; Exit = 1; Verdict = $siteFail
       Expect = @('H05 names docs/SPECIFICATION_FAMILY_MAP_ROW\.md, which does not exist')
       Mutate = { param($t) Remove-Item -LiteralPath (Join-Path $t 'docs/SPECIFICATION_FAMILY_MAP_ROW.md') } }
    @{ Name = 'held: unlisted address in the README'; Gate = 'site'; Exit = 1; Verdict = $siteFail
       Expect = @('README\.md: carries https://serzhyale\.github\.io/Filler_Android/index-ru\.html, which no holder row')
       Mutate = { param($t) Add-File $t 'README.md' ([IO.File]::ReadAllText((Join-Path $t 'README.md')) + "`nRussian: https://serzhyale.github.io/Filler_Android/index-ru.html.`n") } }
    @{ Name = 'held: unlisted address in a listing source'; Gate = 'site'; Exit = 1; Verdict = $siteFail
       Expect = @('docs/play/PLAY_LISTING-ru\.md: carries .*privacy-ru\.html, which no holder row')
       Mutate = { param($t) Add-File $t 'docs/play/PLAY_LISTING-ru.md' ([IO.File]::ReadAllText((Join-Path $t 'docs/play/PLAY_LISTING-ru.md')) + "`n(https://serzhyale.github.io/Filler_Android/privacy-ru.html)`n") } }
    @{ Name = 'held: a program holds an address'; Gate = 'site'; Exit = 1; Verdict = $siteFail
       Expect = @('phone/src/main/java/Help\.kt: carries .*privacy\.html, which no holder row')
       Mutate = { param($t) Add-File $t 'phone/src/main/java/Help.kt' "val page = `"$priv`"`n" } }
    @{ Name = 'held: scan path missing'; Gate = 'site'; Exit = 1; Verdict = $siteFail
       Expect = @('scan path docs/nowhere does not exist'); Mutate = { param($t) Edit-Text $t $list '"docs/play"' '"docs/play","docs/nowhere"' } }
    @{ Name = 'anchor: listed anchor is no id'; Gate = 'site'; Exit = 1; Verdict = $siteFail
       Expect = @("privacy\.html: the anchor 'permissions' is not an id of the page \(it is frozen since 21edc3c\)")
       Mutate = { param($t) Edit-Text $t 'site/privacy.html' 'id="permissions"' 'id="permission-list"' } }
    @{ Name = 'anchor: landing anchor is no id'; Gate = 'site'; Exit = 1; Verdict = $siteFail
       Expect = @("index-uk\.html: the anchor 'limits' is not an id of the page \(it is frozen since 3f77140\)")
       Mutate = { param($t) Edit-Text $t 'site/index-uk.html' 'id="limits"' 'id="obmezhennia"' } }
    @{ Name = 'anchor: page without a row'; Gate = 'site'; Exit = 1; Verdict = $siteFail
       Expect = @('no page row for index-uk\.html'); Mutate = { param($t) Edit-Text $t $list '(?m)^\{"kind":"page","page":"index-uk\.html".*\r?\n' '' } }
    @{ Name = 'anchor: row of a page that does not exist'; Gate = 'site'; Exit = 1; Verdict = $siteFail
       Expect = @('page row privacy-xx\.html names no page of the site')
       Mutate = { param($t) Edit-Text $t $list '"page":"privacy-uk\.html"' '"page":"privacy-xx.html"' } }
    @{ Name = 'anchor: served page without an answer date'; Gate = 'site'; Exit = 1; Verdict = $siteFail
       Expect = @('privacy-ru\.html is served from 21edc3c and has no answered200 date')
       Mutate = { param($t) Edit-Text $t $list '("page":"privacy-ru\.html","servedFrom":"21edc3c","answered200":)"2026-11-13"' '${1}null' } }
    @{ Name = 'anchor: privacy ids differ between languages'; Gate = 'site'; Exit = 1; Verdict = $siteFail
       Expect = @('privacy-ru\.html: the ids differ from privacy\.html')
       Mutate = { param($t) Edit-Text $t 'site/privacy-ru.html' '(<h2 id=")google(")' '${1}google-play${2}' } }
    @{ Name = 'fragment: link leads to no id'; Gate = 'site'; Exit = 1; Verdict = $siteFail
       Expect = @("index\.html: the link #suport leads to no id 'suport' of index\.html")
       Mutate = { param($t) Edit-Text $t 'site/index.html' 'href="#support"' 'href="#suport"' } }
    @{ Name = 'fragment: link to the landing of another language leads to no id'; Gate = 'site'; Exit = 1; Verdict = $siteFail
       Expect = @("privacy-ru\.html: the link index-ru\.html#support leads to no id 'support' of index-ru\.html")
       Mutate = { param($t) Edit-Text $t 'site/index-ru.html' 'id="support"' 'id="podderzhka"' } }

    @{ Name = 'facts pass: the tree as it is'; Gate = 'facts'; Exit = 0; Verdict = $factsPass
       Expect = @('phone 5 and watch 4 permission\(s\), 13 phone locale\(s\), 13 watch locale\(s\), 26 page\(s\)'); Mutate = { param($t) } }
    @{ Name = 'permissions: phone manifest declares a sixth'; Gate = 'facts'; Exit = 1; Verdict = $factsFail
       Expect = @('site/index\.html says five \(5\), the source phonePermissions is 6', 'docs/play/PLAY_DATA_SAFETY\.md says five \(5\), the source phonePermissions is 6')
       Mutate = { param($t) Edit-Text $t $phoneManifest '(?m)^(\s*<uses-permission android:name="android\.permission\.POST_NOTIFICATIONS" />)' ('${1}' + "`n" + ($perm -f 'VIBRATE')) } }
    @{ Name = 'permissions: watch manifest loses one'; Gate = 'facts'; Exit = 1; Verdict = $factsFail
       Expect = @('site/privacy-uk\.html says чотири \(4\), the source watchPermissions is 3')
       Mutate = { param($t) Edit-Text $t $wearManifest '(?m)^\s*<uses-permission android:name="android\.permission\.WAKE_LOCK" />\r?\n' '' } }
    @{ Name = 'permissions: removed permission is not counted'; Gate = 'facts'; Exit = 0; Verdict = $factsPass
       Expect = @('phone 5 and watch 4'); Mutate = { param($t) Edit-Text $t $phoneManifest '(?m)^(\s*<uses-permission android:name="android\.permission\.ACCESS_NETWORK_STATE" tools:node="remove" />)' ('${1}' + "`n" + '    <uses-permission android:name="android.permission.VIBRATE" tools:node="remove" />') } }
    @{ Name = 'permissions: a page says six'; Gate = 'facts'; Exit = 1; Verdict = $factsFail
       Expect = @('site/privacy\.html says six \(6\), the source phonePermissions is 5'); Mutate = { param($t) Edit-Text $t 'site/privacy.html' 'asks for five permissions' 'asks for six permissions' } }
    @{ Name = 'permissions: a number word the table lacks'; Gate = 'facts'; Exit = 1; Verdict = $factsFail
       Expect = @("site/privacy-ru\.html: 'пятнадцать' is not a number the gate knows in ru"); Mutate = { param($t) Edit-Text $t 'site/privacy-ru.html' 'запрашивает пять разрешений' 'запрашивает пятнадцать разрешений' } }
    @{ Name = 'permissions: a statement is gone'; Gate = 'facts'; Exit = 1; Verdict = $factsFail
       Expect = @('site/index\.html has 1 statement\(s\) matching /app asks for \(\\w\+\)/, the source needs 2'); Mutate = { param($t) Edit-Text $t 'site/index.html' 'The watch app asks for four' 'The wristband needs four' } }
    @{ Name = 'permissions: block is gone'; Gate = 'facts'; Exit = 1; Verdict = $factsFail
       Expect = @('site/privacy-uk\.html has no block matching'); Mutate = { param($t) Edit-Text $t 'site/privacy-uk.html' '<h2 id="permissions">' '<h2 id="dozvoly">' } }
    @{ Name = 'permissions: pointer says four phone permissions'; Gate = 'facts'; Exit = 1; Verdict = $factsFail
       Expect = @('docs/contracts/SITE-REPRESENTATION\.md says four \(4\), the source phonePermissions is 5'); Mutate = { param($t) Edit-Text $t 'docs/contracts/SITE-REPRESENTATION.md' '\(five declared' '(four declared' } }
    @{ Name = 'languages: a phone locale is added'; Gate = 'facts'; Exit = 1; Verdict = $factsFail
       Expect = @('site/index\.html says 13 \(13\), the source phoneLocales is 14', 'docs/play/PLAY_LISTING-uk\.md says 13 \(13\), the source phoneLocales is 14')
       Mutate = { param($t) Add-Dir $t 'phone/src/main/res/values-ja' } }
    @{ Name = 'languages: a phone locale is removed'; Gate = 'facts'; Exit = 1; Verdict = $factsFail
       Expect = @('site/index-ru\.html says 13 \(13\), the source phoneLocales is 12'); Mutate = { param($t) Remove-Item -LiteralPath (Join-Path $t 'phone/src/main/res/values-ur') -Recurse } }
    @{ Name = 'languages: other qualifiers are not locales'; Gate = 'facts'; Exit = 0; Verdict = $factsPass
       Expect = @('13 phone locale\(s\)'); Mutate = { param($t) foreach ($q in 'values-night', 'values-land', 'values-v31', 'values-notround', 'values-sw600dp') { Add-Dir $t "phone/src/main/res/$q" } } }
    @{ Name = 'languages: a regional folder is a locale'; Gate = 'facts'; Exit = 1; Verdict = $factsFail
       Expect = @('the source phoneLocales is 14'); Mutate = { param($t) Add-Dir $t 'phone/src/main/res/values-pt-rBR' } }
    @{ Name = 'languages: a watch locale the phone lacks'; Gate = 'facts'; Exit = 1; Verdict = $factsFail
       Expect = @('the watch app has the locale ja, which the phone app lacks'); Mutate = { param($t) Add-Dir $t 'wear/src/main/res/values-ja' } }
    @{ Name = 'languages: the landing names three again'; Gate = 'facts'; Exit = 1; Verdict = $factsFail
       Expect = @('site/index\.html has 0 statement\(s\) matching /interface is in \(\\d\+\) languages/')
       Mutate = { param($t) Edit-Text $t 'site/index.html' "The Android app's interface is in 13 languages\." 'The interface is in English, Russian and Ukrainian.' } }
    @{ Name = 'languages: the listing says 3'; Gate = 'facts'; Exit = 1; Verdict = $factsFail
       Expect = @('docs/play/PLAY_LISTING\.md says 3 \(3\), the source phoneLocales is 13'); Mutate = { param($t) Edit-Text $t 'docs/play/PLAY_LISTING.md' 'interface is in 13 languages' 'interface is in 3 languages' } }
    @{ Name = 'pages: the pointer counts one more'; Gate = 'facts'; Exit = 1; Verdict = $factsFail
       Expect = @('docs/contracts/SITE-STRUCTURE\.md says 27 \(27\), the source sitemapPages is 26'); Mutate = { param($t) Edit-Text $t 'docs/contracts/SITE-STRUCTURE.md' 'exactly the 26 pages' 'exactly the 27 pages' } }
    @{ Name = 'app-id: the README types another id'; Gate = 'facts'; Exit = 1; Verdict = $factsFail
       Expect = @('README\.md types com\.sza\.fillers, the application id is com\.sza\.filler'); Mutate = { param($t) Edit-Text $t 'README.md' 'com\.sza\.filler' 'com.sza.fillers' } }
    @{ Name = 'app-id: a Play link of another app'; Gate = 'facts'; Exit = 1; Verdict = $factsFail
       Expect = @('site/index-uk\.html links the Play listing of com\.sza\.other'); Mutate = { param($t) Edit-Text $t 'site/index-uk.html' 'details\?id=com\.sza\.filler' 'details?id=com.sza.other' } }
    @{ Name = 'app-id: the gate constant names another app'; Gate = 'facts'; Exit = 1; Verdict = $factsFail
       Expect = @('tools/site/check-site\.ps1 links the Play listing of com\.sza\.other'); Mutate = { param($t) Edit-Text $t 'tools/site/check-site.ps1' "details\?id=com\.sza\.filler'" "details?id=com.sza.other'" } }
    @{ Name = 'app-id: a landing page lacks the id in code'; Gate = 'facts'; Exit = 1; Verdict = $factsFail
       Expect = @('site/index-ru\.html does not state the application id in <code>com\.sza\.filler</code>'); Mutate = { param($t) Edit-Text $t 'site/index-ru.html' '<code>com\.sza\.filler</code>' 'com.sza.filler' } }
    @{ Name = 'app-id: the two build scripts differ'; Gate = 'facts'; Exit = 1; Verdict = $factsFail
       Expect = @("publishedApplicationId is 'com\.sza\.filler' in phone and 'com\.sza\.filler2' in wear")
       Mutate = { param($t) Edit-Text $t 'wear/build.gradle.kts' 'val publishedApplicationId = "com\.sza\.filler"' 'val publishedApplicationId = "com.sza.filler2"' } }
    @{ Name = 'internet: the watch declares INTERNET'; Gate = 'facts'; Exit = 1; Verdict = $factsFail
       Expect = @('wear manifest declares android\.permission\.INTERNET'); Mutate = { param($t) Edit-Text $t $wearManifest '(?m)^(\s*<uses-permission android:name="android\.permission\.POST_NOTIFICATIONS" />)' ('${1}' + "`n" + ($perm -f 'INTERNET')) } }
    @{ Name = 'unverified: a manifest is missing'; Gate = 'facts'; Exit = 2; Verdict = $factsUnverified
       Expect = @('COULD NOT VERIFY - wear/src/main/AndroidManifest\.xml is missing'); Mutate = { param($t) Remove-Item -LiteralPath (Join-Path $t $wearManifest) } }
    @{ Name = 'unverified: a manifest is no XML'; Gate = 'facts'; Exit = 2; Verdict = $factsUnverified
       Expect = @('COULD NOT VERIFY - phone/src/main/AndroidManifest\.xml is not XML'); Mutate = { param($t) Add-File $t $phoneManifest '<manifest><unclosed>' } }
    @{ Name = 'facts scope public: the fresh clone carries no local-only pointers'; Gate = 'facts'; Exit = 0; Verdict = $factsPass
       Expect = @('site-facts: scope public, 5 local-only pattern\(s\)'); Args = @('-Scope', 'public')
       Mutate = { param($t) Remove-Item -LiteralPath (Join-Path $t 'docs/contracts/SITE-REPRESENTATION.md'), (Join-Path $t 'docs/contracts/SITE-STRUCTURE.md') } }
    @{ Name = 'facts default scope: a missing local-only pointer is could-not-verify'; Gate = 'facts'; Exit = 2; Verdict = $factsUnverified
       Expect = @('COULD NOT VERIFY - docs/contracts/SITE-REPRESENTATION\.md is missing')
       Mutate = { param($t) Remove-Item -LiteralPath (Join-Path $t 'docs/contracts/SITE-REPRESENTATION.md') } }
)

if ($Filter) { $cases = @($cases | Where-Object { $_.Name -like "*$Filter*" }) }
if ($cases.Count -eq 0) { Write-Output "site-facts-test: FAIL (no case matches '$Filter')"; exit 1 }

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
            $gateArgs = @('-Root', $tree)
            if ($case.Args) { $gateArgs += @($case.Args) }
            $out = @(& pwsh -NoProfile -File $gates[$case.Gate] @gateArgs 2>&1 | ForEach-Object { "$_" })
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
if ($failed -gt 0) { Write-Output "site-facts-test: FAIL ($failed of $($cases.Count) case(s))"; exit 1 }
Write-Output "site-facts-test: PASS ($($cases.Count) case(s))"
exit 0
