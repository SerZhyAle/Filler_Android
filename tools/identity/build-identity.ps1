#requires -Version 7.0
<#
.SYNOPSIS
    The one generator of the Filler mark (PRODUCT-IDENTITY 0.6 section 5, FILLER-0060): writes the master SVG, every
    rendition the repository keeps, and assets/identity/identity-manifest.json.

.DESCRIPTION
    1. tools/store/render-store-assets.ps1 writes the master SVG (the mark defined as code, rule 33), the Android
       vector drawables, the listing graphics, the social preview, the Open Graph card and the page icons.
    2. tools/store/generate-splash-brand.ps1 writes the 13 per-locale splash drawables, which draw the same path.
    3. This script lists every rendition with its surface id, size and SHA-256 in the manifest.

    A rerun on an unchanged master changes no byte (rung 3); tools/store/check-store-assets.ps1 proves it for the
    renderer's targets and the reference checker of PRODUCT-IDENTITY proves the manifest against the files:
        pwsh -NoProfile -File P:\Contracts\product-identity\reference\Test-ProductIdentity.ps1 -RepoRoot .

    Exit codes: 0 written; 1 a step failed (its output says which).
#>
[CmdletBinding()]
param(
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

if ($Check) {
    & pwsh -NoProfile -File (Join-Path $root 'tools\store\check-store-assets.ps1') -Root $root
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & pwsh -NoProfile -File (Join-Path $root 'tools\store\generate-splash-brand.ps1') -Check
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    & pwsh -NoProfile -File (Join-Path $root 'tools\store\render-store-assets.ps1') -Root $root
    if ($LASTEXITCODE -ne 0) { Write-Error "build-identity: render-store-assets.ps1 exited $LASTEXITCODE" -ErrorAction Continue; exit 1 }
    & pwsh -NoProfile -File (Join-Path $root 'tools\store\generate-splash-brand.ps1')
    if ($LASTEXITCODE -ne 0) { Write-Error "build-identity: generate-splash-brand.ps1 exited $LASTEXITCODE" -ErrorAction Continue; exit 1 }
}

$master = 'assets/identity/master/filler-mark.svg'
$masterSmall = 'assets/identity/master/filler-mark-small.svg'

# Surface id (PRODUCT-IDENTITY section 3 rule 2) and repository path of every rendition, in the manifest's order.
# A file that serves two surfaces is a row under each (rule 36 reads one SHA-256 as one picture).
$rows = [System.Collections.Generic.List[object]]::new()
function Add-Row([string]$Surface, [string]$Path) { $rows.Add([pscustomobject]@{ Surface = $Surface; Path = $Path }) }

Add-Row 'app.launcher' 'phone/src/main/res/drawable/ic_launcher_foreground.xml'
Add-Row 'app.wear' 'wear/src/main/res/drawable/ic_launcher_foreground.xml'
Add-Row 'app.launcher' 'phone/src/debug/res/drawable/ic_launcher_foreground.xml'
Add-Row 'app.wear' 'wear/src/debug/res/drawable/ic_launcher_foreground.xml'
Add-Row 'app.notification' 'phone/src/main/res/drawable/ic_stat_filler.xml'
Add-Row 'app.notification' 'wear/src/main/res/drawable/ic_stat_filler.xml'
Add-Row 'app.about' 'phone/src/main/res/drawable/ic_storage.xml'
Add-Row 'app.about' 'wear/src/main/res/drawable/ic_storage.xml'
Add-Row 'help.head' 'phone/src/main/res/drawable/ic_storage.xml'
$splash = Get-ChildItem -LiteralPath (Join-Path $root 'phone\src\main\res') -Directory -Filter 'drawable*' |
    Sort-Object Name -Culture ([System.Globalization.CultureInfo]::InvariantCulture) |
    ForEach-Object { Join-Path $_.FullName 'ic_splash_app_brand.xml' } |
    Where-Object { Test-Path -LiteralPath $_ }
foreach ($file in $splash) { Add-Row 'app.splash' ([System.IO.Path]::GetRelativePath($root, $file).Replace('\', '/')) }
Add-Row 'play.icon' 'docs/play/icon-512.png'
Add-Row 'play.feature-graphic' 'docs/play/feature-graphic-1024x500.png'
Add-Row 'github.social-preview' 'docs/github/social-preview-1280x640.png'
Add-Row 'web.og-image' 'site/assets/og-image-1200x630.png'
Add-Row 'web.favicon-svg' 'site/assets/favicon.svg'
Add-Row 'site.identity' 'site/assets/icon-512.png'
Add-Row 'web.apple-touch' 'site/assets/icon-512.png'
Add-Row 'hub.card' 'docs/play/icon-512.png'

function Get-Sha([string]$Rel) {
    (Get-FileHash -LiteralPath (Join-Path $root $Rel) -Algorithm SHA256).Hash.ToLowerInvariant()
}

# Width and height from the PNG header (IHDR, big-endian at offsets 16 and 20).
function Get-PngSize([string]$Rel) {
    $b = [System.IO.File]::ReadAllBytes((Join-Path $root $Rel))
    $w = ([int]$b[16] -shl 24) -bor ([int]$b[17] -shl 16) -bor ([int]$b[18] -shl 8) -bor [int]$b[19]
    $h = ([int]$b[20] -shl 24) -bor ([int]$b[21] -shl 16) -bor ([int]$b[22] -shl 8) -bor [int]$b[23]
    @($w, $h)
}

$renditions = foreach ($row in $rows) {
    $format = [System.IO.Path]::GetExtension($row.Path).TrimStart('.').ToLowerInvariant()
    $entry = [ordered]@{ surface = $row.Surface; path = $row.Path; format = $format }
    if ($format -eq 'png') {
        $size = Get-PngSize $row.Path
        $entry.width = $size[0]; $entry.height = $size[1]
    }
    $entry.sha256 = Get-Sha $row.Path
    $entry
}

$manifest = [ordered]@{
    schemaVersion = 1
    product       = 'Filler'
    family        = $null
    master        = [ordered]@{
        svg        = $master
        small      = $masterSmall
        mono       = $masterSmall
        background = '#12355B'
        sha256     = Get-Sha $master
    }
    generator     = 'pwsh -NoProfile -File tools/identity/build-identity.ps1'
    renditions    = @($renditions)
}

$manifestPath = Join-Path $root 'assets\identity\identity-manifest.json'
$json = (($manifest | ConvertTo-Json -Depth 6) -replace "`r`n", "`n") + "`n"
if ($Check) {
    $current = if (Test-Path -LiteralPath $manifestPath) { ([System.IO.File]::ReadAllText($manifestPath, $utf8NoBom) -replace "`r`n", "`n") } else { '' }
    if ($current -ne $json) {
        Write-Error 'build-identity: assets/identity/identity-manifest.json is out of sync; run tools/identity/build-identity.ps1' -ErrorAction Continue
        exit 1
    }
    Write-Host ("build-identity: PASS ({0} renditions, master {1})" -f $rows.Count, $manifest.master.sha256.Substring(0, 12))
    exit 0
}
[System.IO.File]::WriteAllText($manifestPath, $json, $utf8NoBom)
Write-Host ("build-identity: assets/identity/identity-manifest.json written ({0} renditions, master {1})" -f $rows.Count, $manifest.master.sha256.Substring(0, 12))
exit 0
