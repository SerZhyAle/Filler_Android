#requires -Version 7.0
<#
.SYNOPSIS
    Checks that the committed store graphics are exactly the current output of their renderer.
.DESCRIPTION
    The master SVG of the Filler mark, the Android vector drawables cut from it, the listing graphics, the
    social preview, the Open Graph card and the page icons are render targets of
    tools/store/render-store-assets.ps1 (PRODUCT-IDENTITY, FILLER-0060). This gate renders them into a
    throw-away folder and compares each committed copy with the fresh render byte for byte (SHA-256):
    a stale or hand-edited committed file fails. Run it after changing the master path, the render script or
    tools/store/vector-renditions.ps1, and before any claim about the listing graphics or the app icons.
    Verdict line and exit codes follow CHECK-VERDICT: 0 PASS, 1 findings, 2 could not verify.
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = 'Stop'
$render = Join-Path $PSScriptRoot 'render-store-assets.ps1'
if (-not (Test-Path -LiteralPath $render)) {
    Write-Output 'store-assets: COULD NOT VERIFY (no render-store-assets.ps1 beside this check)'
    exit 2
}
if (-not (Test-Path -LiteralPath (Join-Path $Root '.git'))) {
    Write-Output "store-assets: COULD NOT VERIFY ($Root is not the repository root)"
    exit 2
}

# The committed render targets the renderer owns; keep in one edit with render-store-assets.ps1.
$targets = @(
    'assets/identity/master/filler-mark.svg',
    'assets/identity/master/filler-mark-small.svg',
    'phone/src/main/res/drawable/ic_launcher_foreground.xml',
    'wear/src/main/res/drawable/ic_launcher_foreground.xml',
    'phone/src/main/res/drawable/ic_launcher_monochrome.xml',
    'wear/src/main/res/drawable/ic_launcher_monochrome.xml',
    'phone/src/debug/res/drawable/ic_launcher_foreground.xml',
    'wear/src/debug/res/drawable/ic_launcher_foreground.xml',
    'phone/src/debug/res/drawable/ic_launcher_monochrome.xml',
    'wear/src/debug/res/drawable/ic_launcher_monochrome.xml',
    'phone/src/main/res/drawable/ic_stat_filler.xml',
    'wear/src/main/res/drawable/ic_stat_filler.xml',
    'phone/src/main/res/drawable/ic_storage.xml',
    'wear/src/main/res/drawable/ic_storage.xml',
    'docs/play/icon-512.png',
    'docs/play/feature-graphic-1024x500.png',
    'docs/github/social-preview-1280x640.png',
    'site/assets/og-image-1200x630.png',
    'site/assets/icon-512.png',
    'site/assets/favicon.svg'
)

$temp = Join-Path $Root (Join-Path 'temp' 'store-assets-check')
if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
New-Item -ItemType Directory -Force (Join-Path $temp 'docs/github') | Out-Null
New-Item -ItemType Directory -Force (Join-Path $temp 'site/assets') | Out-Null

try {
    & pwsh -NoProfile -File $render -Root $temp *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Output "store-assets: COULD NOT VERIFY (the renderer exited $LASTEXITCODE)"
        exit 2
    }

    function Get-FileHashOrNull([string]$Path) {
        if (-not (Test-Path -LiteralPath $Path)) { return $null }
        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }

    $findings = @()
    foreach ($rel in $targets) {
        $committed = Get-FileHashOrNull (Join-Path $Root $rel)
        $fresh = Get-FileHashOrNull (Join-Path $temp $rel)
        if ($null -eq $committed) { $findings += "${rel}: not committed"; continue }
        if ($null -eq $fresh) { $findings += "${rel}: not rendered"; continue }
        if ($committed -ne $fresh) { $findings += "${rel}: committed copy differs from the render" }
    }

    if ($findings.Count) {
        $findings | ForEach-Object { Write-Output "  $_" }
        Write-Output "store-assets: FAIL ($($findings.Count) of $($targets.Count) target(s))"
        exit 1
    }
    Write-Output "store-assets: PASS ($($targets.Count) target(s) byte-identical to the render)"
    exit 0
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
