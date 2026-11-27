#requires -Version 7.0
<#
.SYNOPSIS
    Checks the hosted pages under site/ before they are published (owner's order of 2026-11-13, the public presence of Filler).
.DESCRIPTION
    The pages are hand-written HTML; nothing renders them, so this gate holds what a renderer would:
      - each site/*.html page has one <h1>, a canonical link equal to its own published address (index.html is the root
        address), the reciprocal hreflang set (every language of tools/locale/locales.json and x-default), lang and dir
        of its language, the secondary language row (FILLER-0079, PAGE-STYLE 4.2) and the matching og:url;
      - every relative href and src of every page resolves to a file under site/, and no page loads a remote script,
        image, frame or stylesheet (the privacy statement of the product holds for its site);
      - sitemap.xml lists every page and nothing else, each page of a locale group with its four alternates, and
        robots.txt names the sitemap;
      - site/assets/sza-kit.css has the sha256 that site/assets/PROVENANCE.txt records (the family kit is copied byte
        for byte and never edited);
      - no page carries "..." or U+2026 in its text (house style);
      - the landing pages (S0031: index.html, index-ru.html, index-uk.html) also hold: title of at most 60 and description
        of at most 160 characters, the Open Graph and Twitter cards, a JSON-LD SoftwareApplication block that parses, the
        identity block, the #get block with the one Google Play link and no other channel, the header link to #get and to
        the documentation, the nine rows of SITE-FAMILY-MAP in the footer grid, the contact strings, the localized privacy
        link, no en or em dash, no emoji, no promise or readiness word, no cap on a page wrapper in landing.css, the same
        ids, links and counts in the three languages, and the translation pin: tools/site/landing-translation-pin.json
        holds the SHA-256 of the English page's text, and English changing without the pin fails the gate, so a text
        change reaches the Russian and Ukrainian pages in the same edit.
    S0038 added, for the contracts SITE-STRUCTURE rules 2 and 15 and section 9 item A and SITE-EXPERIENCE rule 15:
      - every page opens its body with the skip link to #main, has a main with id="main", links assets/common.css after the
        kit, and common.css keeps the link off screen until it takes focus (never display:none or visibility:hidden);
      - the not-found pages (404.html, 404-ru.html, 404-uk.html, served by the host for any missing address at any depth) are
        noindex, carry no canonical and no hreflang, link the landing and the privacy page of their own language, and hold
        every own-origin address as an absolute address under the base, each resolving to a file under site/; they are not in
        the sitemap;
      - an address under the base is the site's own origin, not a remote resource, and must resolve to a file under site/;
      - the landing carries the Support section (#support): the issue tracker link, once on the page, the contact e-mail and
        no digit in its text (no invented response deadline); every page footer links it, in the page's own language; the
        header brand of the privacy and not-found pages links the landing of the page's own language.
    S0039 added, for the contract SITE-STRUCTURE rule 8, section 8 items D and E and section 9 item F:
      - docs/site-held-addresses.jsonl, one JSON object per line, three kinds. scope (one row): the base address and the paths
        whose every site address must be listed (README.md, docs/play, phone/src/main, wear/src/main). holder (one per outside
        holder): id H<nn>, holder, type (repository-file, console-field, repository-setting or sibling-site), file (the file of
        this repository that carries or records the address, or null), address, state, since and answered200. state held needs
        both dates, pending-200 (the holder is to carry an address that does not answer yet) needs neither. page (one per
        page of the sitemap): page, servedFrom (the first commit the host served it from, null before the owner's push),
        answered200 and anchors (the headings and navigation ids a visitor or an outside surface links, never a script handle);
      - each holder address is a page of the sitemap set (the root and index.html are the landing) and its fragment an id of
        that page; a file a row names carries the address; every site address found in a scanned file is listed for that
        file; every page has a row and every listed anchor is an id of the page; the three privacy pages carry one id set;
      - every link with a fragment, on any page, leads to an id of its target page.
    The gate reads the list and the pages, never git history, and makes no request: that a held address answers 200 is a date
    the list records when the owner or a session saw it, not a thing this script observes.
    -WritePin records the pin of the current English text after the other checks pass; run it only after re-reading
    index-ru.html and index-uk.html against index.html.
    Runs on the Windows runner of .github/workflows/pages.yml and locally between releases.
.NOTES
    Exit codes: 0 PASS, 1 FAIL, 2 could not verify. The verdict line is the last line written.
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [switch]$WritePin
)
$ErrorActionPreference = 'Stop'
$base = 'https://serzhyale.github.io/Filler_Android/'
$playUrl = 'https://play.google.com/store/apps/details?id=com.sza.filler'
$docsUrl = 'https://github.com/SerZhyAle/Filler_Android#readme'
$issuesUrl = 'https://github.com/SerZhyAle/Filler_Android/issues'
# SITE-FAMILY-MAP 1.17 section 2: the landing's footer grid lists every row (the product itself is not a row yet). A row
# added to the map is added here and to the three landing pages in one edit.
$familyMap = @(
    'https://serzhyale.github.io/FastMediaSorter_mob_v2/', 'https://serzhyale.github.io/FastMediaSorter_Lite/', 'https://serzhyale.github.io/FastMediaSorter_WEB/',
    'https://serzhyale.github.io/CyrFlip/', 'https://serzhyale.github.io/doc-html-translate/',
    'https://serzhyale.github.io/FileDO/', 'https://serzhyale.github.io/StreamsPlayer/',
    'https://serzhyale.github.io/OneClickRunner/', 'https://serzhyale.github.io/universal-agent-kit/', 'https://serzhyale.github.io/DeviceInfo_Android/', 'https://serzhyale.github.io/Tourist_Android/',
    'https://sza.od.ua'
)
$site = Join-Path $Root 'site'
if (-not (Test-Path -LiteralPath $site -PathType Container)) { Write-Host "site-check: COULD NOT VERIFY (no site/ under $Root)"; exit 2 }

$findings = New-Object System.Collections.Generic.List[string]
$utf8 = New-Object System.Text.UTF8Encoding($false)
$pages = @(Get-ChildItem -LiteralPath $site -Filter '*.html' -File | Sort-Object Name)
if ($pages.Count -eq 0) { Write-Host 'site-check: COULD NOT VERIFY (no pages)'; exit 2 }

# The languages of the site are the one list of the product (FILLER-0079): the file suffix is the code, lang and
# hreflang are the tag.
$localesPath = Join-Path $Root 'tools/locale/locales.json'
if (-not (Test-Path -LiteralPath $localesPath -PathType Leaf)) { Write-Host 'site-check: COULD NOT VERIFY (tools/locale/locales.json is missing)'; exit 2 }
$languages = @(([IO.File]::ReadAllText($localesPath, $utf8) | ConvertFrom-Json).languages)
$codes = @($languages | ForEach-Object { $_.code })
$furtherCodes = @($languages | Where-Object { $_.hand.Count -eq 0 } | ForEach-Object { $_.code })
$language = @{}
foreach ($entry in $languages) { $language[$entry.code] = $entry }
function Get-PageName([string]$Stem, [string]$Code) { if ($Code -eq 'en') { return "$Stem.html" }; return "$Stem-$Code.html" }
# Locale groups: the pages of one group are each other's hreflang alternates. English is the x-default of its group.
$groups = [ordered]@{ privacy = [ordered]@{}; landing = [ordered]@{} }
foreach ($c in $codes) {
    $groups['privacy'][$c] = Get-PageName 'privacy' $c
    $groups['landing'][$c] = Get-PageName 'index' $c
}
$localeOf = @{}
$groupOf = @{}
foreach ($g in $groups.Keys) { foreach ($l in $groups[$g].Keys) { $localeOf[$groups[$g][$l]] = $l; $groupOf[$groups[$g][$l]] = $g } }
# The not-found pages (S0038): not a locale group of the sitemap. The host serves 404.html for an address it has no page for,
# at any depth; the two siblings are plain pages with noindex. They carry no canonical and no hreflang.
$notFound = [ordered]@{}
foreach ($c in $codes) { $notFound[$c] = Get-PageName '404' $c }
$notFoundLocale = @{}
foreach ($l in $notFound.Keys) { $notFoundLocale[$notFound[$l]] = $l }
function Get-PublishedUrl([string]$name) { if ($name -eq 'index.html') { return $base }; return $base + $name }
function Get-VisibleText([string]$html) {
    $t = [regex]::Replace($html, '<script[\s\S]*?</script>|<style[\s\S]*?</style>|<!--[\s\S]*?-->|<[^>]+>', ' ')
    return [regex]::Replace([System.Net.WebUtility]::HtmlDecode($t), '\s+', ' ').Trim()
}
$htmlOf = @{}

foreach ($page in $pages) {
    $name = $page.Name
    $html = [IO.File]::ReadAllText($page.FullName, $utf8)
    $htmlOf[$name] = $html
    $url = Get-PublishedUrl $name
    if (([regex]::Matches($html, '<h1[\s>]')).Count -ne 1) { $findings.Add("$name`: not exactly one <h1>") }
    if (-not $notFoundLocale.ContainsKey($name)) {
        if ($html -notmatch [regex]::Escape("<link rel=`"canonical`" href=`"$url`">")) { $findings.Add("$name`: canonical is not $url") }
        if ($html -notmatch [regex]::Escape("<meta property=`"og:url`" content=`"$url`">")) { $findings.Add("$name`: og:url is not $url") }
    }
    if ($groupOf.ContainsKey($name)) {
        $set = $groups[$groupOf[$name]]
        foreach ($c in @($codes) + @('x-default')) {
            $hreflang = if ($c -eq 'x-default') { $c } else { $language[$c].tag }
            $targetName = if ($c -eq 'x-default') { $set['en'] } else { $set[$c] }
            $link = "<link rel=`"alternate`" hreflang=`"$hreflang`" href=`"$(Get-PublishedUrl $targetName)`">"
            if (-not $html.Contains($link)) { $findings.Add("$name`: missing hreflang $hreflang") }
        }
        $own = $language[$localeOf[$name]]
        if (-not $html.Contains("<html lang=`"$($own.tag)`" dir=`"$($own.dir)`"")) { $findings.Add("$name`: html lang and dir are not $($own.tag) $($own.dir)") }
    }
    foreach ($m in [regex]::Matches($html, '\s(?:href|src)="([^"]+)"')) {
        $ref = $m.Groups[1].Value
        if ($ref.StartsWith($base)) {
            # an address under the base is the site's own origin: it resolves to a file under site/ (the root is the landing)
            $rel = ($ref.Substring($base.Length) -split '[#?]')[0]
            if ($rel -ne '' -and -not (Test-Path -LiteralPath (Join-Path $site $rel))) { $findings.Add("$name`: $ref does not resolve under site/") }
            continue
        }
        if ($ref -match '^(https?:|mailto:|#)') { continue }
        $path = Join-Path $site (($ref -split '[#?]')[0])
        if (-not (Test-Path -LiteralPath $path)) { $findings.Add("$name`: $ref does not resolve under site/") }
    }
    # a remote load is one from any origin but the site's own (the not-found pages load their layers by absolute address)
    $remoteLoads = @([regex]::Matches($html, '<(?:script|img|iframe|source|embed)\b[^>]*\ssrc="(https?:[^"]*)"') | ForEach-Object { $_.Groups[1].Value }) +
        @([regex]::Matches($html, '<link\b[^>]*\srel="(?:stylesheet|preload|preconnect|prefetch|dns-prefetch|modulepreload)"[^>]*\shref="(https?:[^"]*)"') | ForEach-Object { $_.Groups[1].Value })
    if (@($remoteLoads | Where-Object { -not $_.StartsWith($base) }).Count -gt 0) {
        $findings.Add("$name`: loads a remote script, image, frame or stylesheet")
    }
    $text = [regex]::Replace($html, '<script[\s\S]*?</script>|<style[\s\S]*?</style>|<[^>]+>', ' ')
    if ($text.Contains('...') -or $text.Contains([string][char]0x2026)) { $findings.Add("$name`: three dots in the text (house style is ..)") }
}

# ---- the landing pages (S0031) ----
$landing = $groups['landing']
foreach ($l in $landing.Keys) {
    $name = $landing[$l]
    if (-not $htmlOf.ContainsKey($name)) { $findings.Add("$name`: the landing page is missing"); continue }
    $html = $htmlOf[$name]
    $url = Get-PublishedUrl $name
    $title = [regex]::Match($html, '<title>([^<]*)</title>').Groups[1].Value
    $title = [System.Net.WebUtility]::HtmlDecode($title)
    if ($title.Length -eq 0 -or $title.Length -gt 60) { $findings.Add("$name`: title is $($title.Length) characters (1 to 60)") }
    $desc = [System.Net.WebUtility]::HtmlDecode([regex]::Match($html, '<meta name="description" content="([^"]*)">').Groups[1].Value)
    if ($desc.Length -eq 0 -or $desc.Length -gt 160) { $findings.Add("$name`: description is $($desc.Length) characters (1 to 160)") }
    foreach ($needle in @('<meta property="og:title" content="', '<meta property="og:description" content="', '<meta property="og:image" content="',
                          '<meta name="twitter:card" content="', '<meta name="twitter:title" content="', '<meta name="twitter:description" content="')) {
        if (-not $html.Contains($needle)) { $findings.Add("$name`: missing $needle") }
    }
    $ld = [regex]::Match($html, '<script type="application/ld\+json">([\s\S]*?)</script>').Groups[1].Value
    try {
        $obj = $ld | ConvertFrom-Json
        if ($obj.'@type' -ne 'SoftwareApplication') { $findings.Add("$name`: JSON-LD @type is not SoftwareApplication") }
        if ($obj.url -ne $url) { $findings.Add("$name`: JSON-LD url is not $url") }
        if ($obj.inLanguage -ne $language[$l].tag) { $findings.Add("$name`: JSON-LD inLanguage is not $($language[$l].tag)") }
        if ($obj.installUrl -ne $playUrl) { $findings.Add("$name`: JSON-LD installUrl is not the Google Play listing") }
    }
    catch { $findings.Add("$name`: JSON-LD does not parse") }
    foreach ($needle in @('<div class="identity">', '<img class="product-icon" src="assets/icon-512.png" width="104" height="104" alt="">', '<p class="product-name">Filler</p>')) {
        if (-not $html.Contains($needle)) { $findings.Add("$name`: identity block lacks $needle") }
    }
    if ($html.IndexOf('<p class="product-name">') -gt $html.IndexOf('<h1')) { $findings.Add("$name`: the identity block does not come before the h1") }
    $header = [regex]::Match($html, '<header class="site-header">[\s\S]*?</header>').Value
    if (-not $header.Contains('href="#get"')) { $findings.Add("$name`: the header has no link to #get") }
    # the documentation of a language is the README in that language (SITE-STRUCTURE section 8 item B)
    $docsOf = if ($l -eq 'en') { $docsUrl } else { "https://github.com/SerZhyAle/Filler_Android/blob/main/README_$l.md" }
    if (-not $header.Contains("href=`"$docsOf`"")) { $findings.Add("$name`: the header has no documentation link ($docsOf)") }
    foreach ($k in @('ru', 'en', 'ua')) { if (-not $header.Contains("data-lang=`"$k`"")) { $findings.Add("$name`: the header has no $k language control") } }
    $get = [regex]::Match($html, '<section class="get" id="get"[\s\S]*?</section>').Value
    if ($get.Length -eq 0) { $findings.Add("$name`: no #get block") }
    elseif (-not $get.Contains("href=`"$playUrl`"")) { $findings.Add("$name`: the #get block has no Google Play link") }
    foreach ($m in [regex]::Matches($html, 'href="([^"]*play\.google\.com[^"]*)"')) {
        if ($m.Groups[1].Value -ne $playUrl) { $findings.Add("$name`: a Play link other than the product's listing: $($m.Groups[1].Value)") }
    }
    $grid = [regex]::Match($html, '<nav class="tools-grid"[\s\S]*?</nav>').Value
    if ([regex]::Matches($grid, '<a\s').Count -ne $familyMap.Count) { $findings.Add("$name`: the footer grid has $([regex]::Matches($grid, '<a\s').Count) entries, SITE-FAMILY-MAP has $($familyMap.Count)") }
    foreach ($u in $familyMap) { if (-not $grid.Contains("href=`"$u`"")) { $findings.Add("$name`: the footer grid lacks $u") } }
    $footer = [regex]::Match($html, '<footer class="site-footer">[\s\S]*?</footer>').Value
    foreach ($needle in @('href="mailto:sza@ukr.net"', 'href="https://github.com/SerZhyAle"', 'href="https://sza.od.ua"')) {
        if (-not $footer.Contains($needle)) { $findings.Add("$name`: the footer lacks $needle") }
    }
    foreach ($m in [regex]::Matches($html, 'mailto:([^"]+)"')) { if ($m.Groups[1].Value -ne 'sza@ukr.net') { $findings.Add("$name`: a contact address other than sza@ukr.net") } }
    if (-not $html.Contains("href=`"$($groups['privacy'][$l])`"")) { $findings.Add("$name`: no link to $($groups['privacy'][$l])") }
    # the Support section (S0038, SITE-STRUCTURE section 9 item A): the tracker once, the one private contact, and no number
    # in the text, because a number there would be a response deadline the product has not promised
    $supportBlock = [regex]::Match($html, '<details class="sec" id="support">[\s\S]*?</details>').Value
    if ($supportBlock.Length -eq 0) { $findings.Add("$name`: no #support section") }
    else {
        if (-not $supportBlock.Contains("href=`"$issuesUrl`"")) { $findings.Add("$name`: the #support section has no issue tracker link") }
        if (-not $supportBlock.Contains('href="mailto:sza@ukr.net"')) { $findings.Add("$name`: the #support section has no contact e-mail") }
        if ((Get-VisibleText ([regex]::Replace($supportBlock, '<summary>[\s\S]*?</summary>', ' '))) -match '\d') { $findings.Add("$name`: the #support section text holds a digit (no invented response deadline)") }
    }
    if ([regex]::Matches($html, [regex]::Escape("href=`"$issuesUrl`"")).Count -ne 1) { $findings.Add("$name`: the issue tracker link is not typed exactly once") }
    foreach ($needle in @('id="get"', 'id="expandAll"', 'id="collapseAll"')) { if (-not $html.Contains($needle)) { $findings.Add("$name`: lacks $needle") } }
    $visible = Get-VisibleText $html
    if ($visible -match '[–—−]') { $findings.Add("$name`: an en or em dash in the text (house style is the plain hyphen)") }
    if ($visible -match '[\uD83C-\uD83E][\uDC00-\uDFFF]|[☀-➿️]') { $findings.Add("$name`: an emoji in the text") }
    if ($visible -match '(?i)\b(coming soon|planned|beta|experimental|not yet|in development|work in progress)\b|скоро|планиру|\bбета|экспериментал|ещё не|в разработке|незабаром|планує|експеримент|ще не|у розробці') {
        $findings.Add("$name`: a promise or readiness word in the text")
    }
}

# the page layer: nothing caps or centres a wrapper of the page (PAGE-CONTENT "Layout contract")
$layer = Join-Path $site 'assets/landing.css'
if (Test-Path -LiteralPath $layer) {
    $css = [IO.File]::ReadAllText($layer, $utf8)
    $css = [regex]::Replace($css, '/\*[\s\S]*?\*/', '')
    foreach ($m in [regex]::Matches($css, '([^{}]+)\{([^{}]*)\}')) {
        $sel = $m.Groups[1].Value.Trim()
        $body = $m.Groups[2].Value
        if ($body -match 'max-width') {
            foreach ($part in ($sel -split ',')) { if ($part.Trim() -notmatch '\s(?:p|li)$') { $findings.Add("assets/landing.css: max-width on '$($part.Trim())', only running prose inside a card or group may be capped") } }
        }
        if ($body -match 'margin\s*:[^;]*\bauto\b') { $findings.Add("assets/landing.css: a centred margin on '$sel'") }
    }
}
else { $findings.Add('assets/landing.css: missing') }

# the layer every page shares (S0038): the skip link stays off screen until it takes focus
$commonLayer = Join-Path $site 'assets/common.css'
if (Test-Path -LiteralPath $commonLayer) {
    $cc = [regex]::Replace([IO.File]::ReadAllText($commonLayer, $utf8), '/\*[\s\S]*?\*/', '')
    $skipBase = $false
    $skipFocus = $false
    foreach ($m in [regex]::Matches($cc, '([^{}]+)\{([^{}]*)\}')) {
        $sel = $m.Groups[1].Value.Trim()
        $body = $m.Groups[2].Value
        if ($sel -notmatch '\.skip-link') { continue }
        if ($body -match 'display\s*:\s*none|visibility\s*:\s*hidden') { $findings.Add("assets/common.css: '$sel' hides the skip link from the keyboard") }
        if ($sel -eq '.skip-link') { $skipBase = $true }
        if ($sel -eq '.skip-link:focus' -and $body -match 'transform\s*:\s*none') { $skipFocus = $true }
    }
    if (-not $skipBase) { $findings.Add('assets/common.css: no .skip-link rule') }
    if (-not $skipFocus) { $findings.Add('assets/common.css: no .skip-link:focus rule that brings the link on screen') }
}
else { $findings.Add('assets/common.css: missing') }

# the chrome every page carries (S0038): the skip link, the common layer, the support link in the footer, the brand as a link
# to the landing (privacy and not-found pages) - each in the page's own language
$landingHomeHref = @{}
foreach ($c in $codes) { $landingHomeHref[$c] = if ($c -eq 'en') { './' } else { Get-PageName 'index' $c } }
foreach ($page in $pages) {
    $name = $page.Name
    $html = $htmlOf[$name]
    $isNotFound = $notFoundLocale.ContainsKey($name)
    $l = if ($isNotFound) { $notFoundLocale[$name] } elseif ($localeOf.ContainsKey($name)) { $localeOf[$name] } else { $null }
    if ($null -eq $l) { $findings.Add("$name`: a page that belongs to no locale group of the gate"); continue }
    $kind = if ($isNotFound) { 'notfound' } else { $groupOf[$name] }
    # the secondary language row (PAGE-STYLE 4.2): a page of RU EN UA lists the further languages, a further page all of them
    $row = [regex]::Match($html, '<nav class="locale-row"[\s\S]*?</nav>').Value
    if ($row.Length -eq 0) { $findings.Add("$name`: no language row") }
    else {
        $listed = if ($furtherCodes -contains $l) { $codes } else { $furtherCodes }
        if ([regex]::Matches($row, '<a\s').Count -ne $listed.Count) { $findings.Add("$name`: the language row has $([regex]::Matches($row, '<a\s').Count) link(s), it lists $($listed.Count) language(s)") }
        foreach ($c in $listed) { if (-not $row.Contains("hreflang=`"$($language[$c].tag)`"")) { $findings.Add("$name`: the language row lacks $($language[$c].tag)") } }
    }
    if (-not [regex]::IsMatch($html, '<body>\r?\n<a class="btn btn-primary skip-link" href="#main"><span>[^<]+</span></a>\r?\n')) {
        $findings.Add("$name`: the skip link is not the first element of the body")
    }
    if ($html -notmatch '<main\b[^>]*\sid="main"') { $findings.Add("$name`: no main with id=main for the skip link") }
    $commonHref = if ($isNotFound) { "${base}assets/common.css" } else { 'assets/common.css' }
    $commonAt = $html.IndexOf("<link rel=`"stylesheet`" href=`"$commonHref`">")
    if ($commonAt -lt 0 -or $commonAt -lt $html.IndexOf('assets/sza-kit.css')) { $findings.Add("$name`: assets/common.css is not linked after the kit") }
    $supportHref = switch ($kind) {
        'landing' { '#support' }
        'privacy' { if ($l -eq 'en') { './#support' } else { "$($landing[$l])#support" } }
        'notfound' { (Get-PublishedUrl $landing[$l]) + '#support' }
    }
    $footerBlock = [regex]::Match($html, '<footer class="site-footer">[\s\S]*?</footer>').Value
    if (-not $footerBlock.Contains("href=`"$supportHref`"")) { $findings.Add("$name`: the footer does not link the support section ($supportHref)") }
    if ($kind -ne 'landing') {
        $homeHref = if ($isNotFound) { Get-PublishedUrl $landing[$l] } else { $landingHomeHref[$l] }
        $headerBlock = [regex]::Match($html, '<header class="site-header">[\s\S]*?</header>').Value
        if (-not $headerBlock.Contains("<a class=`"brand`" href=`"$homeHref`"")) { $findings.Add("$name`: the header brand is not a link to the landing of its language ($homeHref)") }
    }
}

# the not-found pages (S0038, SITE-STRUCTURE rule 15): in the product's chrome, noindex, the way back, absolute addresses
foreach ($l in $notFound.Keys) {
    $name = $notFound[$l]
    if (-not $htmlOf.ContainsKey($name)) { $findings.Add("$name`: the not-found page is missing"); continue }
    $html = $htmlOf[$name]
    if (-not $html.Contains('<meta name="robots" content="noindex">')) { $findings.Add("$name`: not noindex") }
    if ($html -match 'rel="canonical"' -or $html -match 'hreflang="(?:en|ru|uk|x-default)"[^>]*\shref=|<link\b[^>]*rel="alternate"') {
        $findings.Add("$name`: a not-found page carries a canonical or an alternate link")
    }
    if (-not $html.Contains("href=`"$(Get-PublishedUrl $landing[$l])`"")) { $findings.Add("$name`: no link to the landing of its language") }
    if (-not $html.Contains("href=`"$(Get-PublishedUrl $groups['privacy'][$l])`"")) { $findings.Add("$name`: no link to the privacy page of its language") }
    foreach ($layerName in @('sza-kit.css', 'common.css', 'policy.css')) {
        if (-not $html.Contains("<link rel=`"stylesheet`" href=`"${base}assets/$layerName`">")) { $findings.Add("$name`: assets/$layerName is not linked by its absolute address") }
    }
    foreach ($m in [regex]::Matches($html, '\s(?:href|src)="([^"]+)"')) {
        # the host serves this file for a missing address at any depth, so a relative path would resolve against the wrong folder
        if ($m.Groups[1].Value -notmatch '^(https:|mailto:|#)') { $findings.Add("$name`: $($m.Groups[1].Value) is a relative address on a page the host serves at any depth") }
    }
}

# the languages are one set: the same ids, links and counts (the language row aside, it differs by design)
if ($htmlOf.ContainsKey('index.html')) {
    function Get-Shape([string]$html) {
        $html = [regex]::Replace($html, '<nav class="locale-row"[\s\S]*?</nav>', ' ')
        $ids = @([regex]::Matches($html, '\sid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }) -join ','
        $links = @([regex]::Matches($html, '<a\s[^>]*href="([^"]+)"') | ForEach-Object { $_.Groups[1].Value -replace '^privacy(-[a-z]+)?\.html$', 'privacy.html' -replace '/INSTALL_TRUST(-[a-z]+)?\.md$', '/INSTALL_TRUST.md' -replace '(?:#readme|/blob/main/README_[a-z]+\.md)$', '#readme' }) -join ','
        $counts = "cards=$([regex]::Matches($html, '<article class="card">').Count) items=$([regex]::Matches($html, '<li>').Count) groups=$([regex]::Matches($html, '<details ').Count) steps=$([regex]::Matches($html, '<ol class="quickstart">[\s\S]*?</ol>').Count)"
        return "$ids|$links|$counts"
    }
    $shapeEn = Get-Shape $htmlOf['index.html']
    foreach ($l in @($codes | Where-Object { $_ -ne 'en' })) {
        $n = $landing[$l]
        if ($htmlOf.ContainsKey($n) -and (Get-Shape $htmlOf[$n]) -ne $shapeEn) { $findings.Add("$n`: ids, links or counts differ from index.html") }
    }
}

# the sitemap
$sitemapPath = Join-Path $site 'sitemap.xml'
if (Test-Path -LiteralPath $sitemapPath) {
    $sitemap = [IO.File]::ReadAllText($sitemapPath, $utf8)
    $listed = @([regex]::Matches($sitemap, '<loc>([^<]+)</loc>') | ForEach-Object { $_.Groups[1].Value })
    $expected = @($pages | Where-Object { -not $notFoundLocale.ContainsKey($_.Name) } | ForEach-Object { Get-PublishedUrl $_.Name })
    foreach ($u in $expected) { if ($listed -notcontains $u) { $findings.Add("sitemap.xml: $u is not listed") } }
    foreach ($u in $listed) {
        if ($notFound.Values | Where-Object { (Get-PublishedUrl $_) -eq $u }) { $findings.Add("sitemap.xml: $u is a not-found page and stays out of the sitemap"); continue }
        if ($expected -notcontains $u) { $findings.Add("sitemap.xml: $u is not a page") }
    }
    foreach ($blk in [regex]::Matches($sitemap, '<url>[\s\S]*?</url>')) {
        $loc = [regex]::Match($blk.Value, '<loc>([^<]+)</loc>').Groups[1].Value
        $file = $pages | Where-Object { (Get-PublishedUrl $_.Name) -eq $loc } | Select-Object -First 1
        if ($file -and $groupOf.ContainsKey($file.Name)) {
            $set = $groups[$groupOf[$file.Name]]
            foreach ($c in @($codes) + @('x-default')) {
                $hreflang = if ($c -eq 'x-default') { $c } else { $language[$c].tag }
                $targetName = if ($c -eq 'x-default') { $set['en'] } else { $set[$c] }
                if (-not $blk.Value.Contains("hreflang=`"$hreflang`" href=`"$(Get-PublishedUrl $targetName)`"")) { $findings.Add("sitemap.xml: $loc lacks the $hreflang alternate") }
            }
        }
    }
}
else { $findings.Add('sitemap.xml: missing') }
$robotsPath = Join-Path $site 'robots.txt'
if (-not (Test-Path -LiteralPath $robotsPath) -or -not ([IO.File]::ReadAllText($robotsPath, $utf8).Contains("Sitemap: ${base}sitemap.xml"))) {
    $findings.Add('robots.txt: missing or does not name the sitemap')
}

$kit = Join-Path $site 'assets/sza-kit.css'
$provenance = Join-Path $site 'assets/PROVENANCE.txt'
if ((Test-Path -LiteralPath $kit) -and (Test-Path -LiteralPath $provenance)) {
    $recorded = [regex]::Match([IO.File]::ReadAllText($provenance, $utf8), 'sza-kit\.css sha256 ([0-9a-f]{64})').Groups[1].Value
    $actual = (Get-FileHash -LiteralPath $kit -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($recorded -ne $actual) { $findings.Add("assets/sza-kit.css: sha256 $actual, PROVENANCE.txt records '$recorded'") }
}
else { $findings.Add('assets/sza-kit.css or assets/PROVENANCE.txt: missing') }

# ---- the held addresses and the anchors (S0039; SITE-STRUCTURE rule 8, section 8 items D and E, section 9 item F) ----
# docs/site-held-addresses.jsonl is read with System.Text.Json so that a date stays the text it was written as, whichever
# ConvertFrom-Json the runner has.
function ConvertFrom-JsonElement([System.Text.Json.JsonElement]$e) {
    switch ($e.ValueKind) {
        'Object' { $h = [ordered]@{}; foreach ($p in $e.EnumerateObject()) { $h[$p.Name] = ConvertFrom-JsonElement $p.Value }; return $h }
        'Array' { $a = [System.Collections.Generic.List[object]]::new(); foreach ($i in $e.EnumerateArray()) { $a.Add((ConvertFrom-JsonElement $i)) }; return , $a.ToArray() }
        'String' { return $e.GetString() }
        'Null' { return $null }
        default { return $e.GetRawText() }
    }
}
function Get-PageIds([string]$html) { return [System.Collections.Generic.HashSet[string]]::new([string[]]@([regex]::Matches($html, '\sid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }), [StringComparer]::Ordinal) }
$heldRel = 'docs/site-held-addresses.jsonl'
$heldPath = Join-Path $Root $heldRel
$holders = [System.Collections.Generic.List[object]]::new()
$pageRows = [System.Collections.Generic.List[object]]::new()
$scopeRows = [System.Collections.Generic.List[object]]::new()
if (-not (Test-Path -LiteralPath $heldPath)) { $findings.Add("${heldRel}: missing (the list of the addresses outside surfaces hold of the site, SITE-STRUCTURE rule 8)") }
else {
    $n = 0
    foreach ($line in [IO.File]::ReadAllLines($heldPath, $utf8)) {
        $n++
        if ($line.Trim() -eq '') { continue }
        try {
            $doc = [System.Text.Json.JsonDocument]::Parse($line)
            $row = ConvertFrom-JsonElement $doc.RootElement
            $doc.Dispose()
            if ($row -isnot [System.Collections.IDictionary]) { throw 'not an object' }
        }
        catch { $findings.Add("${heldRel}:${n}: not one JSON object ($($_.Exception.Message))"); continue }
        switch ($row['kind']) {
            'scope' { $scopeRows.Add($row) }
            'holder' { $holders.Add($row) }
            'page' { $pageRows.Add($row) }
            default { $findings.Add("${heldRel}:${n}: unknown kind '$($row['kind'])'") }
        }
    }
    $dateRx = '^\d{4}-\d{2}-\d{2}$'
    # the pages a visitor can be sent to: the root answers the landing, which is also index.html
    $published = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($p in $pages) { if (-not $notFoundLocale.ContainsKey($p.Name)) { [void]$published.Add((Get-PublishedUrl $p.Name)) } }
    [void]$published.Add($base + 'index.html')
    $idsOf = @{}
    foreach ($p in $pages) { $idsOf[$p.Name] = Get-PageIds $htmlOf[$p.Name] }
    function Resolve-SiteAddress([string]$Address) {
        # returns the page file name the address means, or $null; the fragment is checked by the caller
        $u = ($Address -split '#')[0]
        if (-not $published.Contains($u)) { return $null }
        if ($u -eq $base) { return 'index.html' }
        return $u.Substring($base.Length)
    }

    if ($scopeRows.Count -ne 1) { $findings.Add("${heldRel}: expected exactly one scope row, found $($scopeRows.Count)") }
    $scan = @()
    if ($scopeRows.Count -ge 1) {
        if ($scopeRows[0]['base'] -ne $base) { $findings.Add("${heldRel}: the scope base is not $base") }
        $scan = @($scopeRows[0]['scan'])
        if ($scan.Count -eq 0) { $findings.Add("${heldRel}: the scope row names no scan path") }
    }

    $seenIds = @{}
    foreach ($h in $holders) {
        $id = [string]$h['id']
        if ($id -notmatch '^H\d{2}$') { $findings.Add("${heldRel}: holder id '$id' is not H<nn>"); $id = "(holder $id)" }
        elseif ($seenIds.ContainsKey($id)) { $findings.Add("${heldRel}: holder id $id is used twice") }
        $seenIds[$id] = $true
        if ([string]::IsNullOrWhiteSpace($h['holder'])) { $findings.Add("${heldRel}: $id has no holder name") }
        if (@('repository-file', 'console-field', 'repository-setting', 'sibling-site') -notcontains $h['type']) { $findings.Add("${heldRel}: $id has type '$($h['type'])'") }
        $addr = [string]$h['address']
        $target = Resolve-SiteAddress $addr
        if ($null -eq $target) { $findings.Add("${heldRel}: $id holds $addr, which is not a page of the site (the sitemap set)") }
        elseif ($addr.Contains('#')) {
            $frag = $addr.Substring($addr.IndexOf('#') + 1)
            if (-not $idsOf[$target].Contains($frag)) { $findings.Add("${heldRel}: $id holds $addr, and $target has no id '$frag'") }
        }
        switch ($h['state']) {
            'held' {
                if ([string]$h['answered200'] -notmatch $dateRx) { $findings.Add("${heldRel}: $id is held and has no answered200 date (the address was never seen to answer 200)") }
                if ([string]$h['since'] -notmatch $dateRx) { $findings.Add("${heldRel}: $id is held and has no since date") }
            }
            'pending-200' {
                if ($null -ne $h['answered200'] -or $null -ne $h['since']) { $findings.Add("${heldRel}: $id is pending-200 and carries a date; set the state to held when the holder carries an address that answered") }
            }
            default { $findings.Add("${heldRel}: $id has state '$($h['state'])' (held or pending-200)") }
        }
        if ($null -ne $h['file']) {
            $hf = Join-Path $Root ([string]$h['file'])
            if (-not (Test-Path -LiteralPath $hf -PathType Leaf)) { $findings.Add("${heldRel}: $id names $($h['file']), which does not exist") }
            elseif (-not [IO.File]::ReadAllText($hf, $utf8).Contains($addr)) { $findings.Add("${heldRel}: $id names $($h['file']), which does not carry $addr") }
        }
        elseif ($h['state'] -eq 'held' -and $h['type'] -eq 'repository-file') { $findings.Add("${heldRel}: $id is a repository-file holder with no file") }
    }

    # the reverse direction: every address of the site that a scanned holder carries is listed for that file
    $hostLiteral = $base.Substring($base.IndexOf('//') + 2)
    $addrRx = [regex]::new([regex]::Escape($base) + '[^\s)`"''<>\[\],;]*')
    $textExt = @('.md', '.kt', '.java', '.xml', '.json', '.txt', '.html', '.kts', '.properties', '.yml')
    $scanned = 0
    foreach ($rel in $scan) {
        $sp = Join-Path $Root ([string]$rel)
        if (Test-Path -LiteralPath $sp -PathType Leaf) { $files = @(Get-Item -LiteralPath $sp) }
        elseif (Test-Path -LiteralPath $sp -PathType Container) { $files = @(Get-ChildItem -LiteralPath $sp -Recurse -File | Where-Object { $textExt -contains $_.Extension }) }
        else { $findings.Add("${heldRel}: scan path $rel does not exist"); continue }
        foreach ($f in $files) {
            $scanned++
            $text = [IO.File]::ReadAllText($f.FullName, $utf8)
            if (-not $text.Contains($hostLiteral)) { continue }
            $relFile = [IO.Path]::GetRelativePath($Root, $f.FullName).Replace('\', '/')
            $reported = @{}
            foreach ($m in $addrRx.Matches($text)) {
                $a = $m.Value.TrimEnd('.', ':')
                if ($reported.ContainsKey($a)) { continue }
                $reported[$a] = $true
                if (-not @($holders | Where-Object { $_['file'] -eq $relFile -and $_['address'] -eq $a }).Count) {
                    $findings.Add("${relFile}: carries $a, which no holder row of ${heldRel} lists for this file")
                }
            }
        }
    }

    # the pages and their anchors (section 8 item D, section 9 item F): every page has a row, every listed anchor is an id of it
    $rowFor = @{}
    foreach ($r in $pageRows) {
        $pn = [string]$r['page']
        if ($rowFor.ContainsKey($pn)) { $findings.Add("${heldRel}: page $pn has two rows") }
        $rowFor[$pn] = $r
        if (-not $idsOf.ContainsKey($pn) -or $notFoundLocale.ContainsKey($pn)) { $findings.Add("${heldRel}: page row $pn names no page of the site"); continue }
        $frozen = $null -ne $r['servedFrom']
        if ($frozen -and [string]$r['answered200'] -notmatch $dateRx) { $findings.Add("${heldRel}: $pn is served from $($r['servedFrom']) and has no answered200 date") }
        if (-not $frozen -and $null -ne $r['answered200']) { $findings.Add("${heldRel}: $pn has an answered200 date and no servedFrom commit") }
        $anchors = @($r['anchors'])
        if ($anchors.Count -eq 0) { $findings.Add("${heldRel}: page row $pn lists no anchor") }
        foreach ($an in $anchors) {
            if (-not $idsOf[$pn].Contains([string]$an)) {
                $why = if ($frozen) { "it is frozen since $($r['servedFrom'])" } else { 'it is listed' }
                $findings.Add("$pn`: the anchor '$an' is not an id of the page ($why)")
            }
        }
    }
    foreach ($p in $pages) {
        if (-not $notFoundLocale.ContainsKey($p.Name) -and -not $rowFor.ContainsKey($p.Name)) { $findings.Add("${heldRel}: no page row for $($p.Name)") }
    }
    # the languages of the privacy pages are one set of sections: a language switch keeps the section
    $privacySet = $groups['privacy']
    if ($idsOf.ContainsKey($privacySet['en'])) {
        $enIds = ($idsOf[$privacySet['en']] | Sort-Object) -join ','
        foreach ($l in @($codes | Where-Object { $_ -ne 'en' })) {
            $pn = $privacySet[$l]
            if ($idsOf.ContainsKey($pn) -and (($idsOf[$pn] | Sort-Object) -join ',') -ne $enIds) { $findings.Add("${pn}: the ids differ from $($privacySet['en']) (the anchors of the languages are one set)") }
        }
    }
}

# every link with a fragment leads to an id of its target (rule 11: no link to a place that is not there; the anchors above
# are the ones outside surfaces and the pages' own navigation link)
$fragLinks = 0
foreach ($page in $pages) {
    $name = $page.Name
    foreach ($m in [regex]::Matches($htmlOf[$name], '<a\s[^>]*?href="([^"]*#[^"]*)"')) {
        $ref = $m.Groups[1].Value
        $hashAt = $ref.IndexOf('#')
        $frag = $ref.Substring($hashAt + 1)
        if ($frag -eq '' -or ($ref -match '^(?:mailto:|https?:)' -and -not $ref.StartsWith($base))) { continue }
        $pathPart = $ref.Substring(0, $hashAt)
        if ($ref.StartsWith($base)) { $pathPart = $pathPart.Substring($base.Length) }
        $targetName = if ($pathPart -eq '') { if ($ref.StartsWith('#')) { $name } else { 'index.html' } } elseif ($pathPart -eq './') { 'index.html' } else { $pathPart }
        if (-not $htmlOf.ContainsKey($targetName)) { continue }
        $fragLinks++
        if (-not (Get-PageIds $htmlOf[$targetName]).Contains($frag)) { $findings.Add("$name`: the link $ref leads to no id '$frag' of $targetName") }
    }
}

# the translation pin: the English page's text against the text the translations were last read against
$pinPath = Join-Path $PSScriptRoot 'landing-translation-pin.json'
if ($htmlOf.ContainsKey('index.html')) {
    $enHtml = $htmlOf['index.html']
    $enTitle = [regex]::Match($enHtml, '<title>([^<]*)</title>').Groups[1].Value
    $enDesc = [regex]::Match($enHtml, '<meta name="description" content="([^"]*)">').Groups[1].Value
    # the language row is generated and carries no sentence of the product, so it is not part of the pinned text
    $enBody = [regex]::Replace([regex]::Match($enHtml, '<body[\s\S]*</body>').Value, '<nav class="locale-row"[\s\S]*?</nav>', ' ')
    $enText = (Get-VisibleText "$enTitle <p>$enDesc</p> $enBody")
    $sha = [BitConverter]::ToString([Security.Cryptography.SHA256]::HashData($utf8.GetBytes($enText))).Replace('-', '').ToLowerInvariant()
    if ($WritePin) {
        if ($findings.Count -eq 0) {
            $json = ([ordered]@{ englishPage = 'index.html'; englishTextSha256 = $sha; translations = @('index-ru.html', 'index-uk.html') } | ConvertTo-Json) + "`n"
            [IO.File]::WriteAllText($pinPath, $json.Replace("`r`n", "`n"), $utf8)
            Write-Host "site-check: pin written ($sha)"
        }
        else { $findings.Add('translation pin not written: fix the findings above first') }
    }
    elseif (-not (Test-Path -LiteralPath $pinPath)) { $findings.Add('tools/site/landing-translation-pin.json: missing (run check-site.ps1 -WritePin after reading the translations)') }
    else {
        $pin = [IO.File]::ReadAllText($pinPath, $utf8) | ConvertFrom-Json
        if ($pin.englishTextSha256 -ne $sha) {
            $findings.Add("index.html: the English text changed after the translations were last read (sha256 $sha, pin $($pin.englishTextSha256)); re-read index-ru.html and index-uk.html, then run check-site.ps1 -WritePin")
        }
    }
}
else { $findings.Add('index.html: the English landing is missing') }

foreach ($f in $findings) { Write-Host "FAIL: $f" }
if ($findings.Count) { Write-Host "site-check: FAIL ($($findings.Count) finding(s) in $($pages.Count) page(s))"; exit 1 }
Write-Host "site-check: PASS ($($pages.Count) page(s), landing, support, skip link, not-found pages, sitemap, robots, kit hash, translation pin; held addresses: $($holders.Count) holder(s), $($pageRows.Count) page row(s), $scanned scanned file(s), $fragLinks fragment link(s))"
exit 0
