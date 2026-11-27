#requires -Version 7.0
<#
.SYNOPSIS
    The language gate of Filler (FILLER-0079): every surface speaks every language of tools/locale/locales.json.
.DESCRIPTION
    Findings (every one is fatal; there is no baseline):
      strings: in phone and in wear, a translatable string, plural or string array of res/values that a language folder
        lacks or leaves empty, a key a language folder adds, format arguments that differ from the English ones, and a
        values folder with strings that the language list does not name;
      config: res/xml/locales_config.xml of an app that does not list exactly the languages of the list, or a manifest
        that does not name it (Android's per-app language setting);
      links: a language whose product page, privacy policy or README address FillerProductLinks does not write out;
      documents: a finding of tools/locale/render-translations.ps1 -Check - a missing, stale or damaged translation, or a
        rendered file that differs from its render.
    The gate makes no request and builds nothing.
.NOTES
    Exit codes: 0 PASS, 1 FAIL (one reason line per finding), 2 COULD NOT VERIFY. The verdict line is the last line:
      locales: PASS (<counts>) | locales: FAIL (<n> finding(s)) | locales: COULD NOT VERIFY (<what>)
    -Root is the repository root; test-locales.ps1 points it at throw-away copies. -SkipDocuments leaves the document
    render out (the self-test of the string rules).
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [switch]$SkipDocuments
)
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
$findings = [System.Collections.Generic.List[string]]::new()
function Add-Finding([string]$Class, [string]$Message) { $findings.Add("${Class}: $Message") }
function Stop-Unverified([string]$Message) { Write-Output "locales: COULD NOT VERIFY ($Message)"; exit 2 }
function Read-Text([string]$Rel) {
    $path = Join-Path $Root $Rel
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Stop-Unverified "$Rel is missing" }
    return [IO.File]::ReadAllText($path, $utf8)
}

$languages = @(((Read-Text 'tools/locale/locales.json') | ConvertFrom-Json).languages)
if ($languages.Count -lt 2) { Stop-Unverified 'tools/locale/locales.json names fewer than two languages' }
$translated = @($languages | Where-Object { $_.code -ne 'en' })

# ---- the app strings ------------------------------------------------------------------------------------------------
$formatRx = [regex]::new('%(?:\d+\$)?[-#+ 0,(]*\d*(?:\.\d+)?[a-zA-Z%]')
function Get-Arguments([string]$Text) { return (@($formatRx.Matches($Text) | ForEach-Object { $_.Value } | Sort-Object) -join ' ') }
function Get-Entries([string]$Folder) {
    # name -> @{ Kind; Translatable; Texts }
    $map = [System.Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($f in Get-ChildItem -LiteralPath $Folder -Filter '*.xml' -File) {
        try { $x = [xml][IO.File]::ReadAllText($f.FullName, $utf8) } catch { Stop-Unverified "$($f.FullName) is not XML" }
        foreach ($node in $x.SelectNodes('/resources/string | /resources/plurals | /resources/string-array')) {
            # the outer array keeps one string an array: an if block would unroll it into the string itself
            $texts = @(if ($node.LocalName -eq 'string') { $node.InnerText } else { $node.SelectNodes('item') | ForEach-Object { $_.InnerText } })
            $map[$node.GetAttribute('name')] = @{ Kind = $node.LocalName; Translatable = ($node.GetAttribute('translatable') -ne 'false'); Texts = $texts }
        }
    }
    return , $map
}
$checked = 0
foreach ($module in @('phone', 'wear')) {
    $res = Join-Path $Root "$module/src/main/res"
    if (-not (Test-Path -LiteralPath (Join-Path $res 'values') -PathType Container)) { Stop-Unverified "$module/src/main/res/values is missing" }
    $english = Get-Entries (Join-Path $res 'values')
    $wanted = @($english.Keys | Where-Object { $english[$_].Translatable })
    if ($wanted.Count -eq 0) { Stop-Unverified "$module has no translatable string" }
    foreach ($lang in $translated) {
        $folder = Join-Path $res $lang.android
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) { Add-Finding 'strings' "$module/$($lang.android) is missing"; continue }
        $local = Get-Entries $folder
        foreach ($name in $wanted) {
            if (-not $local.ContainsKey($name)) { Add-Finding 'strings' "$module/$($lang.android) lacks $name"; continue }
            $checked++
            $e = $english[$name]; $t = $local[$name]
            if ($t.Kind -ne $e.Kind) { Add-Finding 'strings' "$module/$($lang.android): $name is a $($t.Kind), in English a $($e.Kind)"; continue }
            if (@($t.Texts).Count -eq 0 -or @($t.Texts | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count) { Add-Finding 'strings' "$module/$($lang.android): $name is empty" }
            # aapt2 refuses a bare apostrophe and silently drops a bare double quote, unless the whole value is quoted
            foreach ($text in $t.Texts) {
                $value = $text.Trim()
                if ($value.Length -ge 2 -and $value.StartsWith('"') -and $value.EndsWith('"') -and -not $value.EndsWith('\"')) { continue }
                if ([regex]::IsMatch($value, '(?<!\\)(?:\\\\)*[''"]')) { Add-Finding 'strings' "$module/$($lang.android): $name has an apostrophe or a double quote without a backslash" }
            }
            if ($e.Kind -eq 'string') {
                $a = Get-Arguments $e.Texts[0]; $b = Get-Arguments $t.Texts[0]
                if ($a -cne $b) { Add-Finding 'strings' "$module/$($lang.android): $name has the format arguments [$b], English has [$a]" }
            }
        }
        foreach ($name in $local.Keys) {
            if (-not $english.ContainsKey($name) -or -not $english[$name].Translatable) { Add-Finding 'strings' "$module/$($lang.android) adds $name, which English does not translate" }
        }
    }
    $declared = @($languages | ForEach-Object { $_.android })
    foreach ($d in Get-ChildItem -LiteralPath $res -Directory -Filter 'values-*') {
        if ($declared -contains $d.Name) { continue }
        if (@(Get-ChildItem -LiteralPath $d.FullName -Filter '*.xml' -File | Where-Object { [IO.File]::ReadAllText($_.FullName, $utf8) -match '<(string|plurals|string-array)\b' }).Count) {
            Add-Finding 'strings' "$module/$($d.Name) carries strings but tools/locale/locales.json does not name it"
        }
    }
    # Android's per-app language setting
    $config = Read-Text "$module/src/main/res/xml/locales_config.xml"
    $listed = @([regex]::Matches($config, '<locale\s+android:name="([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object)
    $expected = @($languages | ForEach-Object { $_.tag } | Sort-Object)
    if (($listed -join ',') -cne ($expected -join ',')) { Add-Finding 'config' "$module locales_config.xml lists [$($listed -join ', ')], the languages are [$($expected -join ', ')]" }
    if (-not (Read-Text "$module/src/main/AndroidManifest.xml").Contains('android:localeConfig="@xml/locales_config"')) { Add-Finding 'config' "$module manifest does not name @xml/locales_config" }
}

# ---- the addresses the apps open ------------------------------------------------------------------------------------
$links = Read-Text 'filler-core/src/main/java/com/sza/filler/about/FillerProductLinks.kt'
foreach ($lang in $translated) {
    $c = $lang.code
    foreach ($address in @("https://serzhyale.github.io/Filler_Android/index-$c.html", "https://serzhyale.github.io/Filler_Android/privacy-$c.html", "https://github.com/SerZhyAle/Filler_Android/blob/main/README_$c.md")) {
        if (-not $links.Contains("`"$c`" -> `"$address`"")) { Add-Finding 'links' "FillerProductLinks does not answer '$c' with $address" }
    }
}

# ---- the documents --------------------------------------------------------------------------------------------------
$documents = 'documents not checked'
if (-not $SkipDocuments) {
    $render = Join-Path $PSScriptRoot 'render-translations.ps1'
    $out = @(& $render -Root $Root -Check)
    $code = $LASTEXITCODE
    if ($code -eq 2) { Stop-Unverified "render-translations: $($out | Select-Object -Last 1)" }
    if ($code -ne 0) { foreach ($line in $out | Where-Object { $_ -like 'FAIL: *' }) { Add-Finding 'documents' $line.Substring(6) } }
    $documents = ($out | Select-Object -Last 1) -replace '^locale-render: PASS \((.*)\)$', '$1'
}

foreach ($f in $findings) { Write-Output "FAIL: $f" }
if ($findings.Count) { Write-Output "locales: FAIL ($($findings.Count) finding(s))"; exit 1 }
Write-Output "locales: PASS ($($languages.Count) languages, $checked app string translation(s); $documents)"
exit 0
