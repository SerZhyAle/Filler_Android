<#
.SYNOPSIS
    DOC-INTERNAL-QUALITY rules 1, 2, 3, 5 and 6 over the internal documentation corpus of this repository.

.DESCRIPTION
    The corpus is declared in tools/docs/docs.config.json (whole folders plus files matched by pattern), never
    inferred, and holds only the files git tracks or could track: a git-ignored file is outside it. The one
    document registry is docs/DOCUMENT_REGISTRY.jsonl (same record fields as the harness document_registry
    cluster, which `-Check all` also runs).

      registry  rule 1 and 2: every record carries the harness fields, a topic, a product area, update triggers
                and, when generated, its generator and its check; every declared pattern matches a file; every
                corpus file has exactly one record (or an ignore entry with a reason in the configuration).
      links     rule 3: every relative Markdown link resolves to a file or folder, and a #fragment to a heading
                (GitHub's slug) or an explicit anchor of the target. Links inside a record marked "archive": true
                are not judged (a frozen archive, item Q); links into it are.
      style     rule 5: no three dots, no ellipsis character, no em or en dash in Markdown prose; fenced blocks,
                inline code and link targets are removed first.
      assets    rule 6: every image link, and every image path written in inline code, resolves to a tracked asset
                file; an asset that only git-ignores is refused.

    Rule 4 (generated documents) is held by the generator and the check each generated record names; rule 7
    (offline safety) is held by reading. No baseline file: the gate keeps no accepted debt.

    Exit codes: 0 PASS, 1 FAIL (findings), 2 COULD NOT VERIFY (unreadable configuration or registry, no git work
    tree, the harness validator missing or erroring). The last line on stdout is the verdict line:
        docs-check: PASS (<n> corpus file(s), <m> Markdown, <r> record(s), check <name>)
        docs-check: FAIL (<k> finding(s), <n> corpus file(s))
        docs-check: COULD NOT VERIFY (<reason>)

.PARAMETER Check
    registry, links, style, assets or all (default). all also runs the harness document_registry/validate.

.PARAMETER RepoRoot
    Repository to judge; defaults to the repository this script lives in (the self-test points it at a throw-away tree).

.PARAMETER Config
    Configuration file; defaults to tools/docs/docs.config.json under RepoRoot.

.PARAMETER SkipHarness
    With -Check all, do not run the harness validator (the self-test tree has no harness forwarder).
#>
[CmdletBinding()]
param(
    [ValidateSet('all', 'registry', 'links', 'style', 'assets')]
    [string] $Check = 'all',
    [string] $RepoRoot = '',
    [string] $Config = '',
    [switch] $SkipHarness
)

$ErrorActionPreference = 'Stop'
$script:findings = [System.Collections.Generic.List[string]]::new()

function Add-Finding {
    param([string] $Kind, [string] $Subject, [string] $Message)
    [void]$script:findings.Add(('docs-{0} {1}: {2}' -f $Kind, $Subject, $Message))
}

function Convert-GlobToRegex {
    param([string] $Glob)
    $sb = [System.Text.StringBuilder]::new('^')
    $i = 0
    while ($i -lt $Glob.Length) {
        $c = $Glob[$i]
        if ($c -eq '*') {
            if ($i + 1 -lt $Glob.Length -and $Glob[$i + 1] -eq '*') {
                if ($i + 2 -lt $Glob.Length -and $Glob[$i + 2] -eq '/') { [void]$sb.Append('(?:.*/)?'); $i += 3; continue }
                [void]$sb.Append('.*'); $i += 2; continue
            }
            [void]$sb.Append('[^/]*'); $i++; continue
        }
        if ($c -eq '?') { [void]$sb.Append('[^/]'); $i++; continue }
        [void]$sb.Append([regex]::Escape([string]$c)); $i++
    }
    [void]$sb.Append('$')
    return $sb.ToString()
}

function Get-Slug {
    param([string] $Heading)
    $t = $Heading
    $t = [regex]::Replace($t, '!\[([^\]]*)\]\([^)]*\)', '$1')
    $t = [regex]::Replace($t, '\[([^\]]*)\]\([^)]*\)', '$1')
    $t = $t.Replace('`', '')
    $t = [regex]::Replace($t, '<[^>]+>', '')
    $t = $t.ToLowerInvariant()
    $t = [regex]::Replace($t, '[^\p{L}\p{M}\p{N}_ -]', '')
    return $t.Replace(' ', '-')
}

$script:markdownCache = @{}
$script:headingRx = [regex]::new('^\s{0,3}(#{1,6})\s+(.+?)\s*#*\s*$', 'Compiled')
$script:anchorRx = [regex]::new('(?:name|id)="([^"]+)"', 'Compiled')
$script:codeSpanRx = [regex]::new('(?<!`)(`+)(?!`)(.+?)(?<!`)\1(?!`)', 'Compiled')

function Read-Markdown {
    <# One read per file: prose lines (fences blanked, code spans cut out), the code spans per line, the anchors. #>
    param([string] $RelativePath)
    if ($script:markdownCache.ContainsKey($RelativePath)) { return $script:markdownCache[$RelativePath] }
    $text = [System.IO.File]::ReadAllText((Join-Path $RepoRoot $RelativePath), [System.Text.Encoding]::UTF8)
    $lines = $text -split "`r?`n"
    $prose = New-Object 'string[]' $lines.Count
    $spans = New-Object 'object[]' $lines.Count
    $anchors = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $slugCount = @{}
    $fenceChar = [char]0
    $fenceLen = 0
    $noSpans = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $spans[$i] = $noSpans
        $trimmed = $line.TrimStart()
        $indent = $line.Length - $trimmed.Length
        if ($fenceChar -ne [char]0) {
            # Inside a fence: blank the line; a run of the fence character, at least as long as the opener, closes it.
            $closer = $line.Trim()
            if ($closer.Length -ge $fenceLen -and $closer.Trim($fenceChar).Length -eq 0) { $fenceChar = [char]0; $fenceLen = 0 }
            $prose[$i] = ''
            continue
        }
        if ($indent -le 3 -and $trimmed.Length -ge 3 -and ($trimmed[0] -eq '`' -or $trimmed[0] -eq '~')) {
            $c = $trimmed[0]
            $run = $trimmed.Length - $trimmed.TrimStart($c).Length
            if ($run -ge 3) {
                $fenceChar = $c
                $fenceLen = $run
                $prose[$i] = ''
                continue
            }
        }
        if ($indent -le 3 -and $trimmed.Length -gt 1 -and $trimmed[0] -eq '#') {
            $hm = $script:headingRx.Match($line)
            if ($hm.Success) {
                $slug = Get-Slug $hm.Groups[2].Value
                if ($slugCount.ContainsKey($slug)) {
                    [void]$anchors.Add(('{0}-{1}' -f $slug, $slugCount[$slug]))
                    $slugCount[$slug]++
                } else {
                    [void]$anchors.Add($slug)
                    $slugCount[$slug] = 1
                }
            }
        }
        if ($line.Contains('="')) {
            foreach ($m in $script:anchorRx.Matches($line)) { [void]$anchors.Add($m.Groups[1].Value) }
        }
        if ($line.Contains('`')) {
            $cm = $script:codeSpanRx.Matches($line)
            if ($cm.Count -gt 0) {
                $found = New-Object 'string[]' $cm.Count
                for ($k = 0; $k -lt $cm.Count; $k++) { $found[$k] = $cm[$k].Groups[2].Value }
                $spans[$i] = $found
                $prose[$i] = $script:codeSpanRx.Replace($line, ' ')
                continue
            }
        }
        $prose[$i] = $line
    }
    $model = [pscustomobject]@{ Prose = $prose; Spans = $spans; Anchors = $anchors }
    $script:markdownCache[$RelativePath] = $model
    return $model
}

function Resolve-LinkTarget {
    <# Kind: skip (external or empty), self (fragment only) or file with the repo-relative path and the fragment. #>
    param([string] $DocPath, [string] $Target)
    $t = $Target.Trim().Trim('<', '>')
    if (-not $t) { return [pscustomobject]@{ Kind = 'skip' } }
    if ($t -match '^[A-Za-z][A-Za-z0-9+.-]*:') { return [pscustomobject]@{ Kind = 'skip' } }
    $fragment = ''
    $hash = $t.IndexOf('#')
    if ($hash -ge 0) { $fragment = $t.Substring($hash + 1); $t = $t.Substring(0, $hash) }
    $query = $t.IndexOf('?')
    if ($query -ge 0) { $t = $t.Substring(0, $query) }
    if (-not $t) { return [pscustomobject]@{ Kind = 'self'; Fragment = $fragment } }
    $t = [System.Uri]::UnescapeDataString($t)
    if ($t.StartsWith('/')) {
        $combined = Join-Path $RepoRoot $t.TrimStart('/')
    } else {
        $docDir = [System.IO.Path]::GetDirectoryName((Join-Path $RepoRoot $DocPath))
        $combined = Join-Path $docDir $t
    }
    $full = [System.IO.Path]::GetFullPath($combined)
    $rootFull = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    if (-not $full.StartsWith($rootFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{ Kind = 'escape'; Path = $t }
    }
    $relative = $full.Substring($rootFull.Length + 1).Replace('\', '/')
    return [pscustomobject]@{ Kind = 'file'; Path = $relative; Fragment = $fragment }
}

try {
    if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path.TrimEnd('\', '/')
    if ([string]::IsNullOrWhiteSpace($Config)) { $Config = Join-Path $RepoRoot 'tools/docs/docs.config.json' }
    if (-not (Test-Path -LiteralPath $Config)) { throw "configuration not found: $Config" }
    $cfg = Get-Content -LiteralPath $Config -Raw -Encoding utf8 | ConvertFrom-Json
    if (-not $cfg.corpus -or -not $cfg.registry) { throw 'configuration needs "corpus" and "registry"' }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'git is not available' }

    # The files git tracks or could track (not git-ignored), present on disk.
    $listed = @(& git -C $RepoRoot -c core.quotepath=off ls-files --cached --others --exclude-standard)
    if ($LASTEXITCODE -ne 0) { throw 'git ls-files failed: not a git work tree' }
    $allFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($p in $listed) {
        if ($p -and [System.IO.File]::Exists((Join-Path $RepoRoot $p))) { [void]$allFiles.Add($p) }
    }

    # The declared corpus.
    $folderPrefixes = @($cfg.corpus.folders | ForEach-Object { (($_ -replace '\\', '/').TrimEnd('/')) + '/' })
    $fileRegexes = @($cfg.corpus.files | ForEach-Object { [regex]::new((Convert-GlobToRegex ($_ -replace '\\', '/'))) })
    $corpusList = [System.Collections.Generic.List[string]]::new()
    foreach ($f in $allFiles) {
        $inCorpus = $false
        foreach ($prefix in $folderPrefixes) { if ($f.StartsWith($prefix, [System.StringComparison]::Ordinal)) { $inCorpus = $true; break } }
        if (-not $inCorpus) { foreach ($rx in $fileRegexes) { if ($rx.IsMatch($f)) { $inCorpus = $true; break } } }
        if ($inCorpus) { [void]$corpusList.Add($f) }
    }
    $corpus = @($corpusList | Sort-Object -Unique)
    $markdown = @($corpus | Where-Object { $_.EndsWith('.md', [System.StringComparison]::OrdinalIgnoreCase) })

    # The registry.
    $registryPath = Join-Path $RepoRoot (($cfg.registry) -replace '\\', '/')
    if (-not (Test-Path -LiteralPath $registryPath)) { throw "registry not found: $($cfg.registry)" }
    $records = [System.Collections.Generic.List[object]]::new()
    $lineNumber = 0
    foreach ($line in (Get-Content -LiteralPath $registryPath -Encoding utf8)) {
        $lineNumber++
        if (-not $line.Trim()) { continue }
        try { [void]$records.Add(($line | ConvertFrom-Json)) } catch { throw "registry line ${lineNumber} is not valid JSON" }
    }
    $recordRegexes = @{}
    foreach ($r in $records) {
        $list = [System.Collections.Generic.List[object]]::new()
        foreach ($pattern in @($r.paths)) {
            if ($pattern) { [void]$list.Add([pscustomobject]@{ Pattern = [string]$pattern; Regex = [regex]::new((Convert-GlobToRegex (([string]$pattern) -replace '\\', '/'))) }) }
        }
        $recordRegexes[[string]$r.id] = $list
    }
    $archiveFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($r in $records) {
        if ($r.archive -eq $true) {
            foreach ($entry in $recordRegexes[[string]$r.id]) { foreach ($f in $corpus) { if ($entry.Regex.IsMatch($f)) { [void]$archiveFiles.Add($f) } } }
        }
    }

    $runAll = ($Check -eq 'all')

    if ($runAll -or $Check -eq 'registry') {
        $required = @('id', 'title', 'category', 'audience', 'paths', 'published', 'indexable', 'product_areas', 'update_triggers', 'generated')
        $seen = @{}
        foreach ($r in $records) {
            $id = [string]$r.id
            foreach ($field in $required) {
                if (-not ($r.PSObject.Properties.Name -contains $field)) { Add-Finding 'registry' $registryPath "record '$id' misses field '$field'" }
            }
            if ($id -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') { Add-Finding 'registry' $registryPath "record id '$id' is not a lowercase hyphenated id" }
            if ($seen.ContainsKey($id)) { Add-Finding 'registry' $registryPath "record id '$id' is used twice" } else { $seen[$id] = $true }
            if ([string]::IsNullOrWhiteSpace([string]$r.title)) { Add-Finding 'registry' $registryPath "record '$id' has no title (topic)" }
            if (@($r.product_areas).Count -eq 0) { Add-Finding 'registry' $registryPath "record '$id' names no product area" }
            if (@($r.update_triggers).Count -eq 0) { Add-Finding 'registry' $registryPath "record '$id' names no update trigger" }
            if ($r.generated -eq $true) {
                if ([string]::IsNullOrWhiteSpace([string]$r.generator)) { Add-Finding 'registry' $registryPath "record '$id' is generated and names no generator" }
                if ([string]::IsNullOrWhiteSpace([string]$r.check)) { Add-Finding 'registry' $registryPath "record '$id' is generated and names no check" }
            }
            foreach ($entry in $recordRegexes[$id]) {
                if ($entry.Pattern -match '(^|/)\.\.($|/)' -or [System.IO.Path]::IsPathRooted($entry.Pattern)) {
                    Add-Finding 'registry' $registryPath "record '$id' path escapes the repository: $($entry.Pattern)"
                    continue
                }
                $any = $false
                foreach ($f in $allFiles) { if ($entry.Regex.IsMatch($f)) { $any = $true; break } }
                if (-not $any) { Add-Finding 'registry' $registryPath "record '$id' declares '$($entry.Pattern)', which matches no file" }
            }
        }
        $ignoreRegexes = [System.Collections.Generic.List[object]]::new()
        foreach ($ig in @($cfg.ignore)) {
            if (-not $ig) { continue }
            $words = @((([string]$ig.reason) -split '\s+') | Where-Object { $_ })
            if ($words.Count -lt 4) { Add-Finding 'registry' $Config "ignore entry '$($ig.path)' has a reason shorter than four words" }
            $rx = [regex]::new((Convert-GlobToRegex (([string]$ig.path) -replace '\\', '/')))
            $hit = $false
            foreach ($f in $corpus) { if ($rx.IsMatch($f)) { $hit = $true; break } }
            if (-not $hit) { Add-Finding 'registry' $Config "ignore entry '$($ig.path)' matches no corpus file" }
            [void]$ignoreRegexes.Add($rx)
        }
        foreach ($f in $corpus) {
            $ids = [System.Collections.Generic.List[string]]::new()
            foreach ($r in $records) {
                foreach ($entry in $recordRegexes[[string]$r.id]) { if ($entry.Regex.IsMatch($f)) { [void]$ids.Add([string]$r.id); break } }
            }
            $ignored = $false
            foreach ($rx in $ignoreRegexes) { if ($rx.IsMatch($f)) { $ignored = $true; break } }
            if ($ids.Count -eq 0 -and -not $ignored) { Add-Finding 'registry' $f 'is in the corpus and has no record (add it to a record or to the ignore list with a reason)' }
            elseif ($ids.Count -gt 1) { Add-Finding 'registry' $f ("is recorded {0} times: {1}" -f $ids.Count, ($ids -join ', ')) }
            elseif ($ids.Count -eq 1 -and $ignored) { Add-Finding 'registry' $f "is both recorded ($($ids[0])) and ignored" }
        }
    }

    if ($runAll -or $Check -eq 'links') {
        $linkRx = [regex]'(!?)\[(?:[^\]\\]|\\.)*\]\(\s*(<[^>]*>|[^)\s]*)(?:\s+(?:"[^"]*"|''[^'']*''))?\s*\)'
        $refRx = [regex]'^\s{0,3}\[[^\]]+\]:\s*(<[^>]+>|\S+)'
        foreach ($doc in $markdown) {
            if ($archiveFiles.Contains($doc)) { continue }
            $model = Read-Markdown $doc
            for ($i = 0; $i -lt $model.Prose.Length; $i++) {
                $proseLine = $model.Prose[$i]
                if (-not $proseLine.Contains('](') -and -not $proseLine.TrimStart().StartsWith('[')) { continue }
                $targets = [System.Collections.Generic.List[string]]::new()
                foreach ($m in $linkRx.Matches($proseLine)) { [void]$targets.Add($m.Groups[2].Value) }
                $rm = $refRx.Match($proseLine)
                if ($rm.Success) { [void]$targets.Add($rm.Groups[1].Value) }
                foreach ($target in $targets) {
                    $res = Resolve-LinkTarget $doc $target
                    $where = '{0}:{1}' -f $doc, ($i + 1)
                    if ($res.Kind -eq 'skip') { continue }
                    if ($res.Kind -eq 'escape') { Add-Finding 'links' $where "link leaves the repository: $target"; continue }
                    if ($res.Kind -eq 'self') {
                        if ($res.Fragment -and -not $model.Anchors.Contains($res.Fragment.ToLowerInvariant()) -and -not $model.Anchors.Contains($res.Fragment)) {
                            Add-Finding 'links' $where "anchor #$($res.Fragment) is not a heading of this file"
                        }
                        continue
                    }
                    $onDisk = Join-Path $RepoRoot $res.Path
                    $isFile = [System.IO.File]::Exists($onDisk)
                    $isDir = [System.IO.Directory]::Exists($onDisk)
                    if (-not $isFile -and -not $isDir) { Add-Finding 'links' $where "target not found: $target"; continue }
                    if ($res.Fragment -and $isFile -and $res.Path.EndsWith('.md', [System.StringComparison]::OrdinalIgnoreCase)) {
                        $targetModel = Read-Markdown $res.Path
                        if (-not $targetModel.Anchors.Contains($res.Fragment.ToLowerInvariant()) -and -not $targetModel.Anchors.Contains($res.Fragment)) {
                            Add-Finding 'links' $where "anchor #$($res.Fragment) is not a heading of $($res.Path)"
                        }
                    }
                }
            }
        }
    }

    if ($runAll -or $Check -eq 'style') {
        $styleRx = [regex]'\.\.\.|…|—|–'
        foreach ($doc in $markdown) {
            $model = Read-Markdown $doc
            for ($i = 0; $i -lt $model.Prose.Length; $i++) {
                $line = $model.Prose[$i]
                if (-not $line -or -not $styleRx.IsMatch($line)) { continue }
                # A candidate: take the link targets, bare URLs and reference definitions out, then judge again.
                $line = [regex]::Replace($line, '\]\([^)]*\)', ']')
                $line = [regex]::Replace($line, '<https?://[^>]*>|https?://\S+', ' ')
                $line = [regex]::Replace($line, '^\s{0,3}\[[^\]]+\]:\s*\S+', ' ')
                $m = $styleRx.Match($line)
                if ($m.Success) {
                    $kind = 'en dash'
                    if ($m.Value -eq '...') { $kind = 'three dots' }
                    elseif ($m.Value -eq [string][char]0x2026) { $kind = 'ellipsis character' }
                    elseif ($m.Value -eq [string][char]0x2014) { $kind = 'em dash' }
                    $from = [Math]::Max(0, $m.Index - 25)
                    $excerpt = $line.Substring($from, [Math]::Min(60, $line.Length - $from)).Trim()
                    Add-Finding 'style' ('{0}:{1}' -f $doc, ($i + 1)) "$kind in prose: $excerpt"
                }
            }
        }
    }

    if ($runAll -or $Check -eq 'assets') {
        $imageLinkRx = [regex]'!\[(?:[^\]\\]|\\.)*\]\(\s*(<[^>]*>|[^)\s]*)'
        $imagePathRx = [regex]'(?<![\w/.\-])((?:[\w.\-]+/)*[\w.\-]+\.(?:png|jpe?g|gif|webp|svg|ico))(?![\w])'
        $byName = @{}
        foreach ($f in $allFiles) { $n = [System.IO.Path]::GetFileName($f); if (-not $byName.ContainsKey($n)) { $byName[$n] = 0 }; $byName[$n]++ }
        foreach ($doc in $markdown) {
            $model = Read-Markdown $doc
            for ($i = 0; $i -lt $model.Prose.Length; $i++) {
                $where = '{0}:{1}' -f $doc, ($i + 1)
                if ($model.Prose[$i].Contains('![')) {
                    foreach ($m in $imageLinkRx.Matches($model.Prose[$i])) {
                        $res = Resolve-LinkTarget $doc $m.Groups[1].Value
                        if ($res.Kind -ne 'file') { continue }
                        if ($allFiles.Contains($res.Path)) { continue }
                        if ([System.IO.File]::Exists((Join-Path $RepoRoot $res.Path))) { Add-Finding 'assets' $where "image $($res.Path) is git-ignored, not a tracked asset" }
                        else { Add-Finding 'assets' $where "image does not resolve: $($m.Groups[1].Value)" }
                    }
                }
                foreach ($span in $model.Spans[$i]) {
                    foreach ($m in $imagePathRx.Matches($span)) {
                        $cited = $m.Groups[1].Value
                        $docDir = ($doc -replace '[^/]*$', '')
                        $candidates = @($cited, ($docDir + $cited))
                        $ok = $false
                        foreach ($c in $candidates) { if ($allFiles.Contains($c)) { $ok = $true; break } }
                        if (-not $ok -and $cited -notmatch '/' -and $byName.ContainsKey($cited)) { $ok = $true }
                        if ($ok) { continue }
                        $ignoredOnDisk = $false
                        foreach ($c in $candidates) { if ([System.IO.File]::Exists((Join-Path $RepoRoot $c))) { $ignoredOnDisk = $true; break } }
                        if ($ignoredOnDisk) { Add-Finding 'assets' $where "cited asset $cited is git-ignored, not a tracked asset" }
                        else { Add-Finding 'assets' $where "cited asset does not resolve: $cited" }
                    }
                }
            }
        }
    }

    $harnessNote = ''
    if ($runAll -and -not $SkipHarness) {
        $forwarder = Join-Path $RepoRoot 'tools/harness.ps1'
        if (-not (Test-Path -LiteralPath $forwarder)) { throw 'the harness forwarder tools/harness.ps1 is missing' }
        $out = @(& pwsh -NoProfile -File $forwarder 'document_registry/validate' 2>&1 | ForEach-Object { "$_" })
        $code = $LASTEXITCODE
        if ($code -eq 2) { throw ('harness document_registry/validate could not run: ' + ($out -join ' ')) }
        if ($code -ne 0) { foreach ($l in $out) { if ($l.Trim()) { Add-Finding 'registry' 'harness document_registry/validate' $l.Trim() } } }
        $harnessNote = ', harness validator'
    }

    foreach ($f in $script:findings) { Write-Output $f }
    if ($script:findings.Count -gt 0) {
        Write-Output ('docs-check: FAIL ({0} finding(s), {1} corpus file(s))' -f $script:findings.Count, $corpus.Count)
        exit 1
    }
    Write-Output ('docs-check: PASS ({0} corpus file(s), {1} Markdown, {2} record(s), check {3}{4})' -f $corpus.Count, $markdown.Count, $records.Count, $Check, $harnessNote)
    exit 0
} catch {
    foreach ($f in $script:findings) { Write-Output $f }
    Write-Output ('docs-check: COULD NOT VERIFY ({0})' -f ($_.Exception.Message -replace '\s+', ' '))
    exit 2
}
