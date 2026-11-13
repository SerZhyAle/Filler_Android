<#
.SYNOPSIS
    Renders the Google Play listing graphics, the GitHub social preview and the page icon of Filler from the launcher
    glyph.

.DESCRIPTION
    docs/play/icon-512.png                    512 x 512 listing icon (Play applies its own mask, so the square is full bleed)
    docs/play/feature-graphic-1024x500.png    1024 x 500 feature graphic
    docs/github/social-preview-1280x640.png   1280 x 640 repository social preview (uploaded in the repository settings
                                              by the owner)
    site/assets/icon-512.png                  the same listing icon, the Open Graph image of the privacy pages

    The geometry is the one of phone/src/main/res/drawable/ic_launcher_foreground.xml, in its 108-unit canvas: a memory
    card M38,28 L62,28 L70,36 L70,80 L38,80 Z in white, its window M42,32 L60,32 L66,38 L66,76 L42,76 Z in the background
    colour, three contacts (45-48, 51-54 and 57-60 by 35-43) in white and the fill level M42,54 L66,54 L66,76 L42,76 Z
    in #FFB300, over the background colour ic_launcher_background #12355B. The listing icon shows the whole canvas
    instead of the 72-unit visible circle of a launcher, so the glyph is drawn 1.5 times larger. The pictures carry the
    product name only, so one file serves every listing language (Play falls back to the default language's graphics).
    Needs Windows (System.Drawing). Re-run it after changing the glyph; the PNGs are render targets, never edited.
    Owner decision of 2026-11-13 (store graphics rendered by a script, the glyph a memory card filled from the bottom).

.PARAMETER Root
    Repository root. Defaults to two levels above this script.
#>
[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$background = [System.Drawing.ColorTranslator]::FromHtml('#12355B')
$fillColour = [System.Drawing.ColorTranslator]::FromHtml('#FFB300')
$name = 'Filler'
$playDir = Join-Path $Root 'docs\play'
$githubDir = Join-Path $Root 'docs\github'
$siteAssetsDir = Join-Path $Root 'site\assets'
New-Item -ItemType Directory -Force $playDir, $githubDir, $siteAssetsDir | Out-Null

# The launcher vector's paths, in canvas units (centre 54, 54), each with its colour, drawn in this order.
$layers = @(
    @{ Colour = [System.Drawing.Color]::White; Coords = @(38, 28, 62, 28, 70, 36, 70, 80, 38, 80) },
    @{ Colour = $background; Coords = @(42, 32, 60, 32, 66, 38, 66, 76, 42, 76) },
    @{ Colour = [System.Drawing.Color]::White; Coords = @(45, 35, 48, 35, 48, 43, 45, 43) },
    @{ Colour = [System.Drawing.Color]::White; Coords = @(51, 35, 54, 35, 54, 43, 51, 43) },
    @{ Colour = [System.Drawing.Color]::White; Coords = @(57, 35, 60, 35, 60, 43, 57, 43) },
    @{ Colour = $fillColour; Coords = @(42, 54, 66, 54, 66, 76, 42, 76) }
)

function ConvertTo-Points {
    param([double[]]$Coords, [single]$cx, [single]$cy, [single]$unit)
    $points = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
    for ($i = 0; $i -lt $Coords.Count; $i += 2) {
        $x = $cx + ($Coords[$i] - 54) * $unit
        $y = $cy + ($Coords[$i + 1] - 54) * $unit
        $points.Add((New-Object System.Drawing.PointF([single]$x, [single]$y)))
    }
    , $points.ToArray()
}

# Draws the card with the canvas centre (54, 54) at ($cx, $cy); $unit is the size in pixels of one geometry unit.
function Draw-Glyph {
    param([System.Drawing.Graphics]$G, [single]$cx, [single]$cy, [single]$unit)
    foreach ($layer in $layers) {
        $brush = New-Object System.Drawing.SolidBrush($layer.Colour)
        try { $G.FillPolygon($brush, (ConvertTo-Points -Coords $layer.Coords -cx $cx -cy $cy -unit $unit)) }
        finally { $brush.Dispose() }
    }
}

function New-Canvas {
    param([int]$Width, [int]$Height)
    $bmp = New-Object System.Drawing.Bitmap($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear($background)
    [pscustomobject]@{ Bitmap = $bmp; Graphics = $g }
}

# The glyph on the left, the name on the right, the name's size fitted to the box it has.
function Save-Banner {
    param([int]$Width, [int]$Height, [single]$GlyphX, [single]$Unit, [single]$TextX, [single]$MaxFont, [string]$Path)
    $c = New-Canvas -Width $Width -Height $Height
    Draw-Glyph -G $c.Graphics -cx $GlyphX -cy ($Height / 2) -unit $Unit
    $box = $Width - $TextX - ($Width * 0.04)
    $size = $MaxFont
    while ($true) {
        $font = New-Object System.Drawing.Font('Segoe UI Semibold', $size, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
        if ($c.Graphics.MeasureString($name, $font).Width -le $box -or $size -le 24) { break }
        $font.Dispose()
        $size -= 2
    }
    try {
        $format = New-Object System.Drawing.StringFormat
        $format.LineAlignment = [System.Drawing.StringAlignment]::Center
        $c.Graphics.DrawString($name, $font, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF($TextX, 0, $box, $Height)), $format)
    }
    finally { $font.Dispose() }
    $c.Graphics.Dispose()
    $c.Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $c.Bitmap.Dispose()
}

# Listing icon, and its copy for the pages.
$icon = New-Canvas -Width 512 -Height 512
Draw-Glyph -G $icon.Graphics -cx 256 -cy 256 -unit ((512 / 108) * 1.5)
$icon.Graphics.Dispose()
$iconPath = Join-Path $playDir 'icon-512.png'
$icon.Bitmap.Save($iconPath, [System.Drawing.Imaging.ImageFormat]::Png)
$icon.Bitmap.Dispose()
$siteIconPath = Join-Path $siteAssetsDir 'icon-512.png'
Copy-Item -LiteralPath $iconPath -Destination $siteIconPath -Force

$featurePath = Join-Path $playDir 'feature-graphic-1024x500.png'
Save-Banner -Width 1024 -Height 500 -GlyphX 250 -Unit 6.4 -TextX 450 -MaxFont 140 -Path $featurePath

$socialPath = Join-Path $githubDir 'social-preview-1280x640.png'
Save-Banner -Width 1280 -Height 640 -GlyphX 310 -Unit 8.2 -TextX 560 -MaxFont 170 -Path $socialPath

foreach ($path in $iconPath, $featurePath, $socialPath, $siteIconPath) {
    $img = [System.Drawing.Image]::FromFile($path)
    Write-Host ("{0}: {1} x {2}, {3} bytes" -f $path.Substring($Root.Length + 1), $img.Width, $img.Height, (Get-Item $path).Length)
    $img.Dispose()
}
