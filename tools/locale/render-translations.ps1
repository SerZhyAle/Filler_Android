#requires -Version 7.0
<#
.SYNOPSIS
    Renders the translated pages and documents of Filler from their English sources and one dictionary per language
    (FILLER-0079).
.DESCRIPTION
    tools/locale/locales.json lists the languages and, per language, the document kinds written by hand. Every other pair
    of a language and a document kind is a render target:
      page     site/index.html, site/privacy.html, site/404.html   -> site/<name>-<code>.html
      guide    docs/INSTALL_TRUST.md                               -> docs/INSTALL_TRUST-<code>.md
      listing  docs/play/PLAY_LISTING.md, its store field sections -> docs/play/PLAY_LISTING-<code>.md
      readme   README.md                                           -> README_<code>.md
    A segment is one block of the English source (a heading, a paragraph, a list item, a text node, a translated
    attribute); tools/locale/dictionaries/<code>.json maps each English segment to its translation. A segment with no
    translation, a dictionary key no source uses, and a translation that loses a tag, a link, a code span, a number or
    the brand are findings, so a changed English sentence cannot reach a release untranslated.
    The generated regions of the hand-written files (the hreflang block, the secondary language row, the language line
    of README.md and the install guides) and site/sitemap.xml are render targets too.
    Modes:
      (none)     render and write every target; nothing is written while a finding stands.
      -Check     render in memory and compare with the files on disk.
      -Validate  check the dictionaries only (with -Language, of those languages).
      -Extract   write the English segments to -OutFile as JSON [{id, kinds, text}]; ids are stable for one source state.
      -Import    merge the part files <From>/*.json ({"<id>": "translation"}) of one -Language into its dictionary,
                 resolving ids through the -Segments file written by -Extract.
.NOTES
    Exit codes: 0 PASS, 1 FAIL (one reason line per finding), 2 could not verify. The verdict line is the last line.
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [switch]$Check,
    [switch]$Validate,
    [switch]$Extract,
    [switch]$Import,
    [string[]]$Language,
    [string]$OutFile,
    [string]$Segments,
    [string]$From
)
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
$base = 'https://serzhyale.github.io/Filler_Android/'
$repo = 'https://github.com/SerZhyAle/Filler_Android'

$findings = [System.Collections.Generic.List[string]]::new()
function Add-Finding([string]$Message) { $findings.Add($Message) }
function Stop-Unverified([string]$Message) { Write-Output "locale-render: COULD NOT VERIFY ($Message)"; exit 2 }
function Read-Source([string]$Rel) {
    $path = Join-Path $Root $Rel
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Stop-Unverified "$Rel is missing" }
    return [IO.File]::ReadAllText($path, $utf8).Replace("`r`n", "`n")
}

$config = (Read-Source 'tools/locale/locales.json') | ConvertFrom-Json
$languages = @($config.languages)
$further = @($languages | Where-Object { $_.hand.Count -eq 0 })
$keep = [System.Collections.Generic.HashSet[string]]::new([string[]]@($config.keep), [StringComparer]::Ordinal)
if ($Language) {
    $Language = @($Language | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
    foreach ($c in $Language) { if (@($languages | Where-Object { $_.code -eq $c }).Count -ne 1) { Stop-Unverified "unknown language $c" } }
}

$pageSources = @('index', 'privacy', '404')
$kinds = @('page', 'guide', 'listing', 'readme')
function Get-SourceFiles([string]$Kind) {
    switch ($Kind) {
        'page' { return @($pageSources | ForEach-Object { "site/$_.html" }) }
        'guide' { return @('docs/INSTALL_TRUST.md') }
        'listing' { return @('docs/play/PLAY_LISTING.md') }
        'readme' { return @('README.md') }
    }
}
function Get-TargetFile([string]$Source, [string]$Code) {
    if ($Source -eq 'README.md') { if ($Code -eq 'en') { return 'README.md' }; return "README_$Code.md" }
    if ($Code -eq 'en') { return $Source }
    return ($Source -replace '\.(html|md)$', "-$Code.`$1")
}
function Get-PageUrl([string]$Name, [string]$Code) {
    $suffix = if ($Code -eq 'en') { '' } else { "-$Code" }
    if ($Name -eq 'index' -and $Code -eq 'en') { return $base }
    return "$base$Name$suffix.html"
}
$tagRx = [regex]::new('<[^>]+>')
$letterRx = [regex]::new('\p{L}')
$translatable = [System.Collections.Generic.Dictionary[string, bool]]::new([StringComparer]::Ordinal)
function Test-Translatable([string]$Text) {
    $answer = $false
    if ($translatable.TryGetValue($Text, [ref]$answer)) { return $answer }
    $t = $Text.Trim()
    $answer = $t -ne '' -and -not $keep.Contains($t) -and $letterRx.IsMatch([System.Net.WebUtility]::HtmlDecode($tagRx.Replace($t, ' ')))
    $translatable[$Text] = $answer
    return $answer
}
function ConvertTo-Key([string]$Text) { return [regex]::Replace($Text, '\s+', ' ').Trim() }

# ---- HTML: one traversal serves extraction and rendering ------------------------------------------------------------
$tokenRx = [regex]::new('(?s)<!--.*?-->|<script\b.*?</script>|<style\b.*?</style>|<noscript\b.*?</noscript>|<nav class="locale-row".*?</nav>|<[^>]+>|[^<]+')
$blockTags = @('title', 'h1', 'h2', 'h3', 'h4', 'p', 'li', 'figcaption', 'td', 'th')
$attributeRx = [regex]::new('\s(?:aria-label|title|alt|placeholder|content)="')
function Convert-Attributes([string]$Tag, [scriptblock]$Translate) {
    if (-not $attributeRx.IsMatch($Tag)) { return $Tag }
    $metaWanted = $Tag -match '^<meta\s' -and $Tag -match '(?:name|property)="(?:description|og:title|og:description|og:image:alt|twitter:title|twitter:description)"'
    $names = if ($metaWanted) { 'content' } else { 'aria-label|title|alt|placeholder' }
    if ($Tag -match '^<meta\s' -and -not $metaWanted) { return $Tag }
    return [regex]::Replace($Tag, "(\s(?:$names)=`")([^`"]*)(`")", {
            param($m)
            $value = $m.Groups[2].Value
            if (-not (Test-Translatable $value)) { return $m.Value }
            $t = [string](& $Translate (ConvertTo-Key $value))
            return $m.Groups[1].Value + $t.Replace('"', '&quot;') + $m.Groups[3].Value
        })
}
function Convert-Script([string]$Script, [scriptblock]$Translate) {
    if ($Script -match '^<script type="application/ld\+json">') {
        return [regex]::Replace($Script, '("(?:name|description)":")((?:[^"\\]|\\.)*)(")', {
                param($m)
                $value = $m.Groups[2].Value
                if (-not (Test-Translatable $value)) { return $m.Value }
                $t = [string](& $Translate (ConvertTo-Key $value))
                return $m.Groups[1].Value + $t.Replace('\', '\\').Replace('"', '\"') + $m.Groups[3].Value
            })
    }
    return [regex]::Replace($Script, "(labels=\{light:')((?:[^'\\]|\\.)*)(',dark:')((?:[^'\\]|\\.)*)('\})", {
            param($m)
            $a = ([string](& $Translate (ConvertTo-Key $m.Groups[2].Value))).Replace('\', '\\').Replace("'", "\'")
            $b = ([string](& $Translate (ConvertTo-Key $m.Groups[4].Value))).Replace('\', '\\').Replace("'", "\'")
            return $m.Groups[1].Value + $a + $m.Groups[3].Value + $b + $m.Groups[5].Value
        })
}
$tokenCache = [System.Collections.Generic.Dictionary[string, string[]]]::new([StringComparer]::Ordinal)
function Convert-Html([string]$Html, [scriptblock]$Translate) {
    $out = [System.Text.StringBuilder]::new()
    $tokens = $tokenCache[$Html]
    if ($null -eq $tokens) {
        $tokens = [string[]]::new(0)
        $found = $tokenRx.Matches($Html)
        $tokens = [string[]]::new($found.Count)
        for ($n = 0; $n -lt $found.Count; $n++) { $tokens[$n] = $found[$n].Value }
        $tokenCache[$Html] = $tokens
    }
    for ($i = 0; $i -lt $tokens.Length; $i++) {
        $tok = $tokens[$i]
        if ($tok.StartsWith('<!--') -or $tok.StartsWith('<noscript') -or $tok.StartsWith('<style') -or $tok.StartsWith('<nav class="locale-row"')) { [void]$out.Append($tok); continue }
        if ($tok.StartsWith('<script')) { [void]$out.Append((Convert-Script $tok $Translate)); continue }
        if ($tok.StartsWith('<')) {
            $m = [regex]::Match($tok, '^<([a-zA-Z0-9]+)')
            if ($m.Success -and $blockTags -contains $m.Groups[1].Value.ToLowerInvariant()) {
                $name = $m.Groups[1].Value
                $depth = 1
                $inner = [System.Text.StringBuilder]::new()
                $j = $i + 1
                for (; $j -lt $tokens.Length; $j++) {
                    if ($tokens[$j] -match "^<$name[\s>]") { $depth++ }
                    elseif ($tokens[$j] -eq "</$name>") { $depth--; if ($depth -eq 0) { break } }
                    [void]$inner.Append($tokens[$j])
                }
                if ($j -ge $tokens.Length) { Stop-Unverified "an unclosed <$name> in an English page" }
                $text = $inner.ToString()
                [void]$out.Append((Convert-Attributes $tok $Translate))
                if (Test-Translatable $text) { [void]$out.Append([string](& $Translate (ConvertTo-Key $text))) }
                else { [void]$out.Append($text) }
                [void]$out.Append($tokens[$j])
                $i = $j
                continue
            }
            [void]$out.Append((Convert-Attributes $tok $Translate))
            continue
        }
        if (Test-Translatable $tok) {
            $lead = [regex]::Match($tok, '^\s*').Value
            $trail = [regex]::Match($tok, '\s*$').Value
            [void]$out.Append($lead + [string](& $Translate (ConvertTo-Key $tok)) + $trail)
        }
        else { [void]$out.Append($tok) }
    }
    return $out.ToString()
}

# ---- Markdown -------------------------------------------------------------------------------------------------------
$languagesRx = [regex]::new('(?s)<!-- languages -->.*?<!-- /languages -->')
function Get-ListingBody([string]$Text) {
    $start = $Text.IndexOf("`n## Title`n")
    $end = $Text.IndexOf("`n## Console fields")
    if ($start -lt 0 -or $end -lt $start) { Stop-Unverified 'docs/play/PLAY_LISTING.md has no "## Title" .. "## Console fields" range' }
    return $Text.Substring($start + 1, $end - $start - 1).TrimEnd() + "`n"
}
function Convert-Markdown([string]$Text, [bool]$LinePerSegment, [bool]$TranslateHeadings, [scriptblock]$Translate) {
    $lines = $Text.Split("`n")
    $out = [System.Collections.Generic.List[string]]::new()
    $itemRx = '^(\s*(?:[-*]|\d+\.)\s+)(.*)$'
    $inFence = $false
    $inLanguages = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line.StartsWith('```')) { $inFence = -not $inFence; $out.Add($line); continue }
        if ($line.StartsWith('<!-- languages -->')) { $inLanguages = $true }
        if ($inLanguages) { $out.Add($line); if ($line.Contains('<!-- /languages -->')) { $inLanguages = $false }; continue }
        if ($inFence -or $line.Trim() -eq '' -or $line.StartsWith('<!--')) { $out.Add($line); continue }
        if ($line -match '^(#{1,6}\s+)(.*)$') {
            $marker = $Matches[1]; $title = $Matches[2]
            if ($TranslateHeadings -and (Test-Translatable $title)) { $out.Add($marker + [string](& $Translate (ConvertTo-Key $title))) }
            else { $out.Add($line) }
            continue
        }
        $marker = ''
        $body = $line
        if ($line -match $itemRx) { $marker = $Matches[1]; $body = $Matches[2] }
        if (-not $LinePerSegment) {
            while ($i + 1 -lt $lines.Count) {
                $next = $lines[$i + 1]
                if ($next.Trim() -eq '' -or $next -match $itemRx -or $next -match '^#{1,6}\s' -or $next.StartsWith('```') -or $next.StartsWith('<!--')) { break }
                $body += ' ' + $next.Trim()
                $i++
            }
        }
        if (Test-Translatable $body) { $out.Add($marker + [string](& $Translate (ConvertTo-Key $body))) }
        else { $out.Add($marker + $body) }
    }
    return $out -join "`n"
}
function Invoke-SourceTraversal([string]$Source, [scriptblock]$Translate) {
    $text = Read-Source $Source
    if ($Source.EndsWith('.html')) { return Convert-Html $text $Translate }
    if ($Source -eq 'docs/play/PLAY_LISTING.md') { return Convert-Markdown (Get-ListingBody $text) $true $false $Translate }
    return Convert-Markdown $text $false $true $Translate
}

# ---- the segments ---------------------------------------------------------------------------------------------------
$segmentKinds = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
foreach ($kind in $kinds) {
    foreach ($source in Get-SourceFiles $kind) {
        $script:currentKind = $kind
        $null = Invoke-SourceTraversal $source {
            param($key)
            if (-not $segmentKinds.Contains($key)) { $segmentKinds[$key] = [System.Collections.Generic.List[string]]::new() }
            if (-not $segmentKinds[$key].Contains($script:currentKind)) { $segmentKinds[$key].Add($script:currentKind) }
            return $key
        }
    }
}
function Get-NeededKeys($Lang) {
    $needed = [System.Collections.Generic.List[string]]::new()
    foreach ($k in $segmentKinds.Keys) { foreach ($kind in $segmentKinds[$k]) { if ($Lang.hand -notcontains $kind) { $needed.Add($k); break } } }
    return , $needed.ToArray()
}

if ($Extract) {
    if (-not $OutFile) { Stop-Unverified '-Extract needs -OutFile' }
    $n = 0
    $rows = @($segmentKinds.Keys | ForEach-Object { $n++; [ordered]@{ id = "$n"; kinds = @($segmentKinds[$_]); text = $_ } })
    $outPath = [IO.Path]::GetFullPath($OutFile, (Get-Location).Path)
    New-Item -ItemType Directory -Force (Split-Path -Parent $outPath) | Out-Null
    [IO.File]::WriteAllText($outPath, ((ConvertTo-Json -InputObject $rows -Depth 4) + "`n").Replace("`r`n", "`n"), $utf8)
    Write-Output "locale-render: PASS ($($rows.Count) segment(s) written to $outPath)"
    exit 0
}

function Get-DictionaryPath([string]$Code) { return Join-Path $Root "tools/locale/dictionaries/$Code.json" }
function Read-Dictionary([string]$Code) {
    $map = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
    $path = Get-DictionaryPath $Code
    if (-not (Test-Path -LiteralPath $path)) { return , $map }
    try {
        $doc = [System.Text.Json.JsonDocument]::Parse([IO.File]::ReadAllText($path, $utf8))
        foreach ($p in $doc.RootElement.EnumerateObject()) { $map[$p.Name] = $p.Value.GetString() }
        $doc.Dispose()
    }
    catch { Add-Finding "tools/locale/dictionaries/$Code.json: not a JSON object of strings ($($_.Exception.Message))" }
    return , $map
}

if ($Import) {
    if (@($Language).Count -ne 1 -or -not $Segments -or -not $From) { Stop-Unverified '-Import needs one -Language, -Segments and -From' }
    $code = @($Language)[0]
    $byId = @{}
    foreach ($r in ([IO.File]::ReadAllText((Resolve-Path -LiteralPath $Segments).Path, $utf8) | ConvertFrom-Json)) { $byId[[string]$r.id] = [string]$r.text }
    $map = Read-Dictionary $code
    $parts = @(Get-ChildItem -LiteralPath $From -Filter '*.json' -File | Sort-Object Name)
    if ($parts.Count -eq 0) { Stop-Unverified "no part file in $From" }
    foreach ($part in $parts) {
        try {
            $doc = [System.Text.Json.JsonDocument]::Parse([IO.File]::ReadAllText($part.FullName, $utf8))
            foreach ($p in $doc.RootElement.EnumerateObject()) {
                if (-not $byId.ContainsKey($p.Name)) { Add-Finding "$($part.Name): unknown segment id $($p.Name)"; continue }
                $map[$byId[$p.Name]] = $p.Value.GetString()
            }
            $doc.Dispose()
        }
        catch { Add-Finding "$($part.Name): not a JSON object of strings ($($_.Exception.Message))" }
    }
    $ordered = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
    foreach ($k in $segmentKinds.Keys) { if ($map.ContainsKey($k)) { $ordered[$k] = $map[$k] } }
    New-Item -ItemType Directory -Force (Split-Path -Parent (Get-DictionaryPath $code)) | Out-Null
    [IO.File]::WriteAllText((Get-DictionaryPath $code), ((ConvertTo-Json -InputObject $ordered -Depth 3) + "`n").Replace("`r`n", "`n"), $utf8)
    foreach ($f in $findings) { Write-Output "FAIL: $f" }
    if ($findings.Count) { Write-Output "locale-render: FAIL ($($findings.Count) finding(s))"; exit 1 }
    Write-Output "locale-render: PASS ($code dictionary holds $($ordered.Count) segment(s))"
    exit 0
}

# ---- the integrity of a translation ---------------------------------------------------------------------------------
$markTagRx = [regex]::new('<\s*(/?)\s*([a-zA-Z0-9]+)([^>]*)>')
$markHrefRx = [regex]::new('\shref="([^"]*)"')
$markLinkRx = [regex]::new('\]\(([^)\s]*)\)')
$markCodeRx = [regex]::new('`[^`]*`')
$houseStyleRx = [regex]::new('\.\.\.|[…–—]')
function Get-Marks([string]$Text) {
    $marks = [System.Collections.Generic.List[string]]::new()
    foreach ($m in $markTagRx.Matches($Text)) {
        $href = $markHrefRx.Match($m.Groups[3].Value).Groups[1].Value
        $marks.Add("tag $($m.Groups[1].Value)$($m.Groups[2].Value.ToLowerInvariant()) $href")
    }
    foreach ($m in $markLinkRx.Matches($Text)) { $marks.Add("link $($m.Groups[1].Value)") }
    foreach ($m in $markCodeRx.Matches($Text)) { $marks.Add("code $($m.Value)") }
    $marks.Sort([StringComparer]::Ordinal)
    return [string]::Join('|', $marks)
}
$sourceFacts = [System.Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
function Get-SourceFacts([string]$Source) {
    $facts = $null
    if ($sourceFacts.TryGetValue($Source, [ref]$facts)) { return $facts }
    $plain = [regex]::Replace($Source, '<[^>]+>|\]\([^)]*\)', ' ')
    $facts = @{ Marks = (Get-Marks $Source); Numbers = @(foreach ($m in [regex]::Matches($plain, '[0-9]+')) { $m.Value }); Brand = ($Source -cmatch '\bFiller\b') }
    $sourceFacts[$Source] = $facts
    return $facts
}
function Test-Translation([string]$Code, [string]$Source, [string]$Target) {
    $short = if ($Source.Length -gt 60) { $Source.Substring(0, 60) + '..' } else { $Source }
    if ([string]::IsNullOrWhiteSpace($Target)) { Add-Finding "$Code`: empty translation of '$short'"; return }
    if ($Target -match '[\r\n]') { Add-Finding "$Code`: a line break in the translation of '$short'" }
    $facts = Get-SourceFacts $Source
    $b = Get-Marks $Target
    if ($facts.Marks -cne $b) { Add-Finding "$Code`: tags, links or code spans differ for '$short' (source [$($facts.Marks)], translation [$b])" }
    foreach ($number in $facts.Numbers) { if (-not $Target.Contains($number)) { Add-Finding "$Code`: the number $number is missing from the translation of '$short'" } }
    if ($facts.Brand -and -not $Target.Contains('Filler')) { Add-Finding "$Code`: the name Filler is missing from the translation of '$short'" }
    if ($houseStyleRx.IsMatch($Target)) { Add-Finding "$Code`: three dots, an ellipsis or a long dash in the translation of '$short' (house style: '..' and '-')" }
}

$dictionaries = @{}
foreach ($lang in $languages) {
    $needed = Get-NeededKeys $lang
    if ($needed.Count -eq 0) { continue }
    if ($Language -and $Language -notcontains $lang.code) { continue }
    $map = Read-Dictionary $lang.code
    $dictionaries[$lang.code] = $map
    $missing = @($needed | Where-Object { -not $map.ContainsKey($_) })
    foreach ($k in ($missing | Select-Object -First 10)) { Add-Finding "$($lang.code): no translation of '$k'" }
    if ($missing.Count -gt 10) { Add-Finding "$($lang.code): $($missing.Count - 10) further segment(s) have no translation" }
    $neededSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$needed, [StringComparer]::Ordinal)
    foreach ($k in @($map.Keys)) { if (-not $neededSet.Contains($k)) { Add-Finding "$($lang.code): a stale dictionary key '$k' (no source uses it)" } }
    foreach ($k in $needed) { if ($map.ContainsKey($k)) { Test-Translation $lang.code $k $map[$k] } }
}

function Write-Findings {
    foreach ($f in $findings) { Write-Output "FAIL: $f" }
    Write-Output "locale-render: FAIL ($($findings.Count) finding(s))"
}
if ($findings.Count) { Write-Findings; exit 1 }
# ---- the generated regions ------------------------------------------------------------------------------------------
function Get-Alternates([string]$Name) {
    $rows = @($languages | ForEach-Object { "  <link rel=`"alternate`" hreflang=`"$($_.tag)`" href=`"$(Get-PageUrl $Name $_.code)`">" })
    $rows += "  <link rel=`"alternate`" hreflang=`"x-default`" href=`"$(Get-PageUrl $Name 'en')`">"
    return $rows -join "`n"
}
function Get-LocaleRow([string]$Name, $Lang) {
    # PAGE-STYLE 4.2: a page of the core three lists the further locales; a further page carries RU, EN, UA first
    $isCore = $Lang.hand.Count -gt 0
    $first = @('ru', 'en', 'uk') | ForEach-Object { $c = $_; $languages | Where-Object { $_.code -eq $c } }
    $listed = if ($isCore) { $further } else { @($first) + @($further) }
    $links = foreach ($l in $listed) {
        $href = if ($Name -eq '404') { Get-PageUrl $Name $l.code } elseif ($l.code -eq 'en') { if ($Name -eq 'index') { './' } else { "$Name.html" } } else { "$Name-$($l.code).html" }
        $store = switch ($l.code) { 'ru' { ' data-lang="ru"' } 'en' { ' data-lang="en"' } 'uk' { ' data-lang="ua"' } default { '' } }
        $current = if ($l.code -eq $Lang.code) { ' aria-current="page"' } else { '' }
        "    <a href=`"$href`" hreflang=`"$($l.tag)`" lang=`"$($l.tag)`" title=`"$($l.endonym)`"$store$current>$($l.label)</a>"
    }
    return "  <nav class=`"locale-row`" aria-label=`"$($Lang.more)`">`n$($links -join "`n")`n  </nav>"
}
function Set-Region([string]$Text, [string]$Region, [string]$Body, [string]$File) {
    $rx = [regex]::new("(?s)([ \t]*<!-- locales:$Region -->\n).*?([ \t]*<!-- /locales:$Region -->)")
    if (-not $rx.IsMatch($Text)) { Add-Finding "$File`: no <!-- locales:$Region --> region"; return $Text }
    return $rx.Replace($Text, { param($m) $m.Groups[1].Value + $Body + "`n" + $m.Groups[2].Value }, 1)
}
function Get-LanguageLine([string]$Source, $Lang) {
    $items = foreach ($l in $languages) {
        if ($l.code -eq $Lang.code) { $l.endonym; continue }
        $file = Split-Path -Leaf (Get-TargetFile $Source $l.code)
        "[$($l.endonym)]($file)"
    }
    return "<!-- languages -->`n$($Lang.list) $($items -join ' - ')`n<!-- /languages -->"
}

# ---- rendering ------------------------------------------------------------------------------------------------------
function ConvertTo-LocalPage([string]$Html, [string]$Name, $Lang) {
    $code = $Lang.code
    $t = $Html
    # the root-only forward to a stored language choice does not travel to a locale page (PAGE-STYLE 3.9 item 3)
    $t = [regex]::Replace($t, '(?s)[ \t]*// locales:forward\n.*?// /locales:forward\n', '')
    $t = [regex]::Replace($t, '(?s)[ \t]*<!--.*?-->\n?', '')
    # the noscript links keep pointing at the core three and the language row at every language
    $held = @([regex]::Matches($t, '(?s)<noscript>.*?</noscript>|<nav class="locale-row".*?</nav>') | ForEach-Object { $_.Value })
    for ($i = 0; $i -lt $held.Count; $i++) { $t = $t.Replace($held[$i], "@@held$i@@") }
    $t = $t.Replace('<html lang="en" dir="ltr"', "<html lang=`"$($Lang.tag)`" dir=`"$($Lang.dir)`"")
    $t = $t.Replace("<head>`n", "<head>`n  <!-- Rendered by tools/locale/render-translations.ps1 from $Name.html and tools/locale/dictionaries/$code.json. Never edit it by hand. -->`n")
    $own = Get-PageUrl $Name $code
    $english = Get-PageUrl $Name 'en'
    $t = $t.Replace("<link rel=`"canonical`" href=`"$english`">", "<link rel=`"canonical`" href=`"$own`">")
    $t = $t.Replace("<meta property=`"og:url`" content=`"$english`">", "<meta property=`"og:url`" content=`"$own`">")
    $t = $t.Replace('<meta property="og:locale" content="en_US">', "<meta property=`"og:locale`" content=`"$($Lang.og)`">")
    $t = $t.Replace("`"url`":`"$english`"", "`"url`":`"$own`"").Replace('"inLanguage":"en"', "`"inLanguage`":`"$($Lang.tag)`"")
    $t = $t.Replace('data-lang="en" aria-pressed="true"', 'data-lang="en" aria-pressed="false"')
    # the Latin brand keeps its own direction on a right-to-left page, or its trailing dot moves to the front
    if ($Lang.dir -eq 'rtl') { $t = $t.Replace('Filler<span class="dot">.</span>', '<bdi dir="ltr">Filler<span class="dot">.</span></bdi>') }
    # every link of a locale page leads to the page of its own language (SITE-STRUCTURE rule 11)
    $map = [ordered]@{
        'privacy.html'                              = "privacy-$code.html"
        './'                                        = "index-$code.html"
        './#support'                                = "index-$code.html#support"
        "$base"                                     = "${base}index-$code.html"
        "$base#support"                             = "${base}index-$code.html#support"
        "${base}privacy.html"                       = "${base}privacy-$code.html"
        "$repo#readme"                              = "$repo/blob/main/README_$code.md"
        "$repo/blob/main/docs/INSTALL_TRUST.md"     = "$repo/blob/main/docs/INSTALL_TRUST-$code.md"
    }
    $t = [regex]::Replace($t, '(<a\s(?:[^>]*?\s)?href=")([^"]+)(")', {
            param($m)
            $href = $m.Groups[2].Value
            if ($map.Contains($href)) { return $m.Groups[1].Value + $map[$href] + $m.Groups[3].Value }
            return $m.Value
        })
    for ($i = 0; $i -lt $held.Count; $i++) { $t = $t.Replace("@@held$i@@", $held[$i]) }
    return $t
}
$targets = [ordered]@{}
foreach ($lang in $languages) {
    if ($Language -and $Language -notcontains $lang.code) { continue }
    foreach ($kind in $kinds) {
        foreach ($source in Get-SourceFiles $kind) {
            $target = Get-TargetFile $source $lang.code
            $name = if ($kind -eq 'page') { [IO.Path]::GetFileNameWithoutExtension($source) } else { $null }
            if ($lang.hand -contains $kind) {
                # a hand-written file: only its generated regions are rendered
                if ($kind -eq 'listing') { continue }
                $text = Read-Source $target
                if ($kind -eq 'page') {
                    if ($name -ne '404') { $text = Set-Region $text 'alternates' (Get-Alternates $name) $target }
                    $text = Set-Region $text 'row' (Get-LocaleRow $name $lang) $target
                }
                else {
                    if (-not $languagesRx.IsMatch($text)) { Add-Finding "$target`: no <!-- languages --> region"; continue }
                    $line = Get-LanguageLine $source $lang
                    $text = $languagesRx.Replace($text, { param($m) $line }, 1)
                }
                $targets[$target] = $text
                continue
            }
            $map = $dictionaries[$lang.code]
            if ($kind -eq 'page') {
                $english = Read-Source $source
                if ($name -ne '404') { $english = Set-Region $english 'alternates' (Get-Alternates $name) $source }
                $english = Set-Region $english 'row' (Get-LocaleRow $name $lang) $source
                $translated = Convert-Html $english { param($key) $map[$key] }
                $targets[$target] = ConvertTo-LocalPage $translated $name $lang
                continue
            }
            $body = Invoke-SourceTraversal $source { param($key) $map[$key] }
            $body = $body.Replace('](docs/INSTALL_TRUST.md)', "](docs/INSTALL_TRUST-$($lang.code).md)").Replace("]($($base)privacy.html)", "]($($base)privacy-$($lang.code).html)")
            if ($kind -eq 'listing') {
                $head = "# Play listing - $($lang.english) ($($lang.play))`n`nThe $($lang.english) text of the three store fields of ``com.sza.filler``, rendered by`n``tools/locale/render-translations.ps1`` from [PLAY_LISTING.md](PLAY_LISTING.md) and`n``tools/locale/dictionaries/$($lang.code).json``; never edit it by hand. The headings are the console's field names.`n`n"
                $body = $head + $body
                foreach ($limit in @(@('Title', 30), @('Short description', 80), @('Full description', 4000), @("What's new", 500))) {
                    $m = [regex]::Match($body, "(?s)\n## $($limit[0])\n\n(.*?)(?=\n## |\z)")
                    if ($m.Success -and $m.Groups[1].Value.Trim().Length -gt $limit[1]) { Add-Finding "$target`: $($limit[0]) is $($m.Groups[1].Value.Trim().Length) characters (at most $($limit[1]))" }
                }
            }
            else {
                $line = Get-LanguageLine $source $lang
                $body = $languagesRx.Replace($body, { param($m) $line }, 1)
                $body = $body.TrimEnd() + "`n`n<!-- Rendered by tools/locale/render-translations.ps1 from $(Split-Path -Leaf $source) and tools/locale/dictionaries/$($lang.code).json. Never edit it by hand. -->`n"
            }
            $targets[$target] = $body.TrimEnd() + "`n"
        }
    }
}
# the limits of the landing's head (the page gate states them for every language)
foreach ($t in @($targets.Keys | Where-Object { $_ -match '^site/index-' })) {
    $title = [System.Net.WebUtility]::HtmlDecode([regex]::Match($targets[$t], '<title>([^<]*)</title>').Groups[1].Value)
    if ($title.Length -gt 60) { Add-Finding "$t`: title is $($title.Length) characters (at most 60)" }
    $desc = [System.Net.WebUtility]::HtmlDecode([regex]::Match($targets[$t], '<meta name="description" content="([^"]*)">').Groups[1].Value)
    if ($desc.Length -gt 160) { Add-Finding "$t`: description is $($desc.Length) characters (at most 160)" }
}
if ($Validate) {
    if ($findings.Count) { Write-Findings; exit 1 }
    Write-Output "locale-render: PASS ($($dictionaries.Count) dictionary(ies) complete, $($segmentKinds.Count) segment(s))"
    exit 0
}
# the sitemap: the landing and the privacy page in every language, each with the full set of alternates
if (-not $Language) {
    $xml = [System.Collections.Generic.List[string]]::new()
    $xml.Add('<?xml version="1.0" encoding="UTF-8"?>')
    $xml.Add('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">')
    foreach ($name in @('index', 'privacy')) {
        foreach ($lang in $languages) {
            $xml.Add('  <url>')
            $xml.Add("    <loc>$(Get-PageUrl $name $lang.code)</loc>")
            foreach ($alt in $languages) { $xml.Add("    <xhtml:link rel=`"alternate`" hreflang=`"$($alt.tag)`" href=`"$(Get-PageUrl $name $alt.code)`"/>") }
            $xml.Add("    <xhtml:link rel=`"alternate`" hreflang=`"x-default`" href=`"$(Get-PageUrl $name 'en')`"/>")
            $xml.Add('  </url>')
        }
    }
    $xml.Add('</urlset>')
    $targets['site/sitemap.xml'] = ($xml -join "`n") + "`n"
}

if ($findings.Count) { Write-Findings; exit 1 }

$changed = [System.Collections.Generic.List[string]]::new()
foreach ($rel in $targets.Keys) {
    $path = Join-Path $Root $rel
    $old = if (Test-Path -LiteralPath $path) { [IO.File]::ReadAllText($path, $utf8) } else { $null }
    if ($null -ne $old -and $old.Replace("`r`n", "`n") -ceq $targets[$rel]) { continue }
    $changed.Add($rel)
    if (-not $Check) {
        $text = $targets[$rel]
        if ($null -ne $old -and $old.Contains("`r`n")) { $text = $text.Replace("`n", "`r`n") }
        [IO.File]::WriteAllText($path, $text, $utf8)
    }
}
if ($Check -and $changed.Count) {
    foreach ($c in $changed) { Add-Finding "$c differs from its render (run tools/locale/render-translations.ps1)" }
    Write-Findings
    exit 1
}
$what = if ($Check) { "$($targets.Count) target(s) in step" } else { "$($targets.Count) target(s), $($changed.Count) written" }
Write-Output "locale-render: PASS ($what, $($segmentKinds.Count) segment(s), $($dictionaries.Count) dictionary(ies))"
exit 0
