<#
.SYNOPSIS
    Self-test of tools/docs/check-docs.ps1 on throw-away git trees under temp/: each check passes on a clean tree and
    fails on its own defect, and an unreadable input is exit 2.

.DESCRIPTION
    Release tier (it starts one process per case). Run it after editing tools/docs/. Trees are built under
    temp/S0026-test/ and removed at the end. Exit 0 all cases held, 1 a case failed.
    The last line is a test verdict line: docs-test: PASS (run=N skipped=0). With -Filter only the cases whose name
    contains the text run and the others are counted as skipped, so a filtered PASS is a partial one.
#>
[CmdletBinding()]
param(
    [string] $Filter = ''
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$check = Join-Path $repo 'tools\docs\check-docs.ps1'
$base = Join-Path $repo 'temp\S0026-test'
if (Test-Path -LiteralPath $base) { Remove-Item -LiteralPath $base -Recurse -Force }
New-Item -ItemType Directory -Force $base | Out-Null

$run = 0
$skipped = 0
$failed = [System.Collections.Generic.List[string]]::new()

$config = @'
{ "corpus": { "folders": ["docs"], "files": ["README.md"] }, "registry": "docs/DOCUMENT_REGISTRY.jsonl", "ignore": [] }
'@

function New-Tree {
    param([string] $Name, [hashtable] $Files, [string] $Registry, [string] $GitIgnore = '', [string] $ConfigText = $config, [switch] $NoRegistry, [string] $Under = $base)
    $root = Join-Path $Under $Name
    New-Item -ItemType Directory -Force (Join-Path $root 'tools\docs') | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $root 'tools\docs\docs.config.json'), $ConfigText)
    if (-not $NoRegistry) {
        New-Item -ItemType Directory -Force (Join-Path $root 'docs') | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $root 'docs\DOCUMENT_REGISTRY.jsonl'), $Registry)
    }
    foreach ($key in $Files.Keys) {
        $full = Join-Path $root $key
        New-Item -ItemType Directory -Force (Split-Path $full -Parent) | Out-Null
        if ($Files[$key] -is [byte[]]) { [System.IO.File]::WriteAllBytes($full, $Files[$key]) } else { [System.IO.File]::WriteAllText($full, [string]$Files[$key]) }
    }
    if ($GitIgnore) { [System.IO.File]::WriteAllText((Join-Path $root '.gitignore'), $GitIgnore) }
    & git -C $root init -q 2>&1 | Out-Null
    return $root
}

function Get-Record {
    param([string] $Id, [string[]] $Paths, [hashtable] $Extra = @{})
    $o = [ordered]@{
        id = $Id; title = "Topic $Id"; category = 'process'; audience = 'contributor'; paths = $Paths
        published = $false; indexable = $false; product_areas = @('area'); update_triggers = @('change'); generated = $false
    }
    foreach ($k in $Extra.Keys) { $o[$k] = $Extra[$k] }
    return ($o | ConvertTo-Json -Compress)
}

function Assert-Case {
    param([string] $Name, [string] $Root, [int] $ExpectExit, [string] $ExpectWord, [string] $ExpectText = '', [string[]] $ExtraArgs = @())
    if ($Filter -and $Name -notlike "*$Filter*") { $script:skipped++; return }
    $script:run++
    $out = @(& pwsh -NoProfile -File $check -RepoRoot $Root -SkipHarness @ExtraArgs 2>&1 | ForEach-Object { "$_" })
    $code = $LASTEXITCODE
    $last = if ($out.Count -gt 0) { $out[-1] } else { '' }
    $ok = ($code -eq $ExpectExit) -and ($last -like "docs-check: $ExpectWord*")
    if ($ok -and $ExpectText) { $ok = (($out -join "`n") -like "*$ExpectText*") }
    if (-not $ok) {
        $detail = (@($out | Select-Object -First 2) -join ' | ')
        [void]$script:failed.Add("$Name (expected exit $ExpectExit '$ExpectWord' '$ExpectText'; got exit ${code}: $detail)")
    }
}

$goodRegistry = (Get-Record 'readme' @('README.md')) + "`n" + (Get-Record 'docs' @('docs/*.md')) + "`n" + (Get-Record 'reg' @('docs/DOCUMENT_REGISTRY.jsonl')) + "`n"
$clean = @{ 'README.md' = "# Title`n`nSee [the doc](docs/a.md#part-one).`n"; 'docs/a.md' = "# A`n`n## Part one`n`nText.`n" }

Assert-Case 'clean tree passes' (New-Tree 'clean' $clean $goodRegistry) 0 'PASS'

# registry (rules 1 and 2)
$f = $clean.Clone(); $f['docs/new.md'] = "# New`n"
Assert-Case 'a corpus file without a record fails' (New-Tree 'unrecorded' $f ((Get-Record 'readme' @('README.md')) + "`n" + (Get-Record 'a' @('docs/a.md')) + "`n" + (Get-Record 'reg' @('docs/DOCUMENT_REGISTRY.jsonl')) + "`n")) 1 'FAIL' 'docs/new.md: is in the corpus and has no record'
Assert-Case 'a pattern that matches nothing fails' (New-Tree 'ghost' $clean ($goodRegistry + (Get-Record 'ghost' @('docs/missing.md')) + "`n")) 1 'FAIL' 'matches no file'
Assert-Case 'a file recorded twice fails' (New-Tree 'twice' $clean ($goodRegistry + (Get-Record 'again' @('docs/a.md')) + "`n")) 1 'FAIL' 'is recorded 2 times'
Assert-Case 'a generated record without a generator fails' (New-Tree 'nogen' $clean ($goodRegistry.Replace('"generated":false', '"generated":true'))) 1 'FAIL' 'names no generator'
$bad = (Get-Record 'readme' @('README.md')) + "`n" + (Get-Record 'docs' @('docs/*.md') @{ product_areas = @() }) + "`n" + (Get-Record 'reg' @('docs/DOCUMENT_REGISTRY.jsonl')) + "`n"
Assert-Case 'a record with no product area fails' (New-Tree 'noarea' $clean $bad) 1 'FAIL' 'names no product area'
$ignored = '{ "corpus": { "folders": ["docs"], "files": ["README.md"] }, "registry": "docs/DOCUMENT_REGISTRY.jsonl", "ignore": [ { "path": "docs/a.md", "reason": "scratch" } ] }'
Assert-Case 'an ignore entry with a thin reason fails' (New-Tree 'thin' $clean ((Get-Record 'readme' @('README.md')) + "`n" + (Get-Record 'reg' @('docs/DOCUMENT_REGISTRY.jsonl')) + "`n") '' $ignored) 1 'FAIL' 'reason shorter than four words'
$ignoredOk = '{ "corpus": { "folders": ["docs"], "files": ["README.md"] }, "registry": "docs/DOCUMENT_REGISTRY.jsonl", "ignore": [ { "path": "docs/a.md", "reason": "scratch note nobody maintains" } ] }'
Assert-Case 'an ignore entry with a reason passes' (New-Tree 'ignoreok' $clean ((Get-Record 'readme' @('README.md')) + "`n" + (Get-Record 'reg' @('docs/DOCUMENT_REGISTRY.jsonl')) + "`n") '' $ignoredOk) 0 'PASS'
$f = $clean.Clone(); $f['docs/secret.md'] = "# Local`n"
Assert-Case 'a git-ignored file is outside the corpus' (New-Tree 'gitignored' $f $goodRegistry 'docs/secret.md') 0 'PASS'

# links (rule 3)
$f = $clean.Clone(); $f['docs/a.md'] = "# A`n`n## Part one`n`nSee [x](gone.md).`n"
Assert-Case 'a broken relative link fails' (New-Tree 'brokenlink' $f $goodRegistry) 1 'FAIL' 'target not found: gone.md'
$f = $clean.Clone(); $f['README.md'] = "# Title`n`nSee [the doc](docs/a.md#no-such-part).`n"
Assert-Case 'a broken anchor fails' (New-Tree 'brokenanchor' $f $goodRegistry) 1 'FAIL' 'anchor #no-such-part'
$f = $clean.Clone(); $f['docs/a.md'] = "# A`n`n## Part one`n`n[up](#part-one) [bad](#nowhere)`n"
Assert-Case 'a broken same-file anchor fails' (New-Tree 'brokenself' $f $goodRegistry) 1 'FAIL' 'anchor #nowhere is not a heading of this file'
$f = $clean.Clone(); $f['docs/a.md'] = "# A`n`n## Part one`n`n[web](https://example.com/x) [mail](mailto:a@b.c) ``[x](gone.md)```n"
Assert-Case 'external links and code spans are not judged' (New-Tree 'external' $f $goodRegistry) 0 'PASS'
$f = $clean.Clone(); $f['docs/old/a.md'] = "# Old`n`nSee [x](gone.md).`n"
$arch = $goodRegistry + (Get-Record 'old' @('docs/old/*.md') @{ archive = $true }) + "`n"
Assert-Case 'links inside a frozen archive are not judged' (New-Tree 'archive' $f $arch) 0 'PASS'
$f['README.md'] = "# Title`n`nSee [old](docs/old/missing.md).`n"
Assert-Case 'a link into the archive must resolve' (New-Tree 'intoarchive' $f $arch) 1 'FAIL' 'target not found'

# style (rule 5)
$f = $clean.Clone(); $f['docs/a.md'] = "# A`n`n## Part one`n`nWait" + '...' + " what.`n"
Assert-Case 'three dots in prose fail' (New-Tree 'dots' $f $goodRegistry) 1 'FAIL' 'three dots in prose'
$f = $clean.Clone(); $f['docs/a.md'] = "# A`n`n## Part one`n`nOne " + [char]0x2014 + " two.`n"
Assert-Case 'an em dash in prose fails' (New-Tree 'emdash' $f $goodRegistry) 1 'FAIL' 'em dash in prose'
$f = $clean.Clone(); $f['docs/a.md'] = "# A`n`n## Part one`n`nOne " + [char]0x2013 + " two " + [char]0x2026 + "`n"
Assert-Case 'an en dash and an ellipsis character fail' (New-Tree 'endash' $f $goodRegistry) 1 'FAIL' 'en dash in prose'
$f = $clean.Clone(); $f['docs/a.md'] = "# A`n`n## Part one`n`n``a...b`` and [t](http://x/y...z) and`n`n" + '```' + "`nfence ... here`n" + '```' + "`n"
Assert-Case 'dots in code spans, fences and link targets pass' (New-Tree 'dotsok' $f $goodRegistry) 0 'PASS'

# assets (rule 6)
$png = [byte[]](0x89, 0x50, 0x4E, 0x47)
$f = $clean.Clone(); $f['docs/pic.png'] = $png; $f['docs/a.md'] = "# A`n`n## Part one`n`n![x](pic.png) and ``pic.png```n"
$assetRegistry = $goodRegistry + (Get-Record 'pics' @('docs/*.png')) + "`n"
Assert-Case 'a resolving image link and code-span path pass' (New-Tree 'assetok' $f $assetRegistry) 0 'PASS'
$f = $clean.Clone(); $f['docs/a.md'] = "# A`n`n## Part one`n`n![x](gone.png)`n"
Assert-Case 'an image link that does not resolve fails' (New-Tree 'assetlink' $f $goodRegistry) 1 'FAIL' 'image does not resolve'
$f = $clean.Clone(); $f['docs/a.md'] = "# A`n`n## Part one`n`nSee ``docs/gone.png`` here.`n"
Assert-Case 'an image path in code that does not resolve fails' (New-Tree 'assetcode' $f $goodRegistry) 1 'FAIL' 'cited asset does not resolve'
$f = $clean.Clone(); $f['docs/a.md'] = "# A`n`n## Part one`n`n![x](local.png)`n"; $f['docs/local.png'] = $png
Assert-Case 'a git-ignored image is not a tracked asset' (New-Tree 'assetignored' $f $goodRegistry '*.png') 1 'FAIL' 'git-ignored'

# could not verify (exit 2)
$root = New-Tree 'badjson' $clean "{not json`n"
Assert-Case 'an unreadable registry is exit 2' $root 2 'COULD NOT VERIFY'
$root = New-Tree 'noregistry' $clean '' -NoRegistry
Assert-Case 'a missing registry is exit 2' $root 2 'COULD NOT VERIFY'
$root = New-Tree 'noconfig' $clean $goodRegistry
Remove-Item (Join-Path $root 'tools\docs\docs.config.json')
Assert-Case 'a missing configuration is exit 2' $root 2 'COULD NOT VERIFY'
# Outside this repository: a tree under temp/ would fall back to the work tree of the repository around it.
$outside = Join-Path ([System.IO.Path]::GetTempPath()) 'S0026-docs-nogit'
if (Test-Path -LiteralPath $outside) { Remove-Item -LiteralPath $outside -Recurse -Force }
$root = New-Tree 'nogit' $clean $goodRegistry -Under $outside
Remove-Item (Join-Path $root '.git') -Recurse -Force
Assert-Case 'a tree outside a git work tree is exit 2' $root 2 'COULD NOT VERIFY'
Remove-Item -LiteralPath $outside -Recurse -Force

Remove-Item -LiteralPath $base -Recurse -Force
foreach ($line in $failed) { Write-Output "FAILED: $line" }
if ($failed.Count -gt 0) {
    Write-Output ('docs-test: FAIL (run={0} skipped={1} failed={2})' -f $run, $skipped, $failed.Count)
    exit 1
}
Write-Output ('docs-test: PASS (run={0} skipped={1})' -f $run, $skipped)
exit 0
