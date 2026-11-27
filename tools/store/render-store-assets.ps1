<#
.SYNOPSIS
    Writes the master of the Filler mark and every rendition of it that the repository keeps: the Android vector
    drawables, the Google Play listing graphics, the GitHub social preview, the Open Graph card and the page icons
    (PRODUCT-IDENTITY 0.6, FILLER-0060, FILLER-0072).

.DESCRIPTION
    The master is defined as code (PRODUCT-IDENTITY rule 33): a dimensional 3-bay storage block on its 24-unit grid
    retaining the FastMediaSorter Filler block silhouette (S0050) with rounded drive bays, 3D lower bevel, left
    status LEDs, and bottom-to-top storage fill-level meters (FILLER-0072). The small/mono form ($smallGlyphPathData)
    keeps the flat upstream app_v2/src/main/res/drawable/ic_storage.xml silhouette for notification, toolbar, help,
    splash, and adaptive monochrome layers.

    Change the geometry here and run tools/identity/build-identity.ps1, which runs this script, the splash generator,
    and writes the identity manifest. Every file below is a render target, never edited by hand.

.PARAMETER Root
    Repository root. Defaults to two levels above this script.
#>
[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$inv = [System.Globalization.CultureInfo]::InvariantCulture
$backgroundHex = '#12355B'
$background = [System.Drawing.ColorTranslator]::FromHtml($backgroundHex)
$name = 'Filler'
$playDir = Join-Path $Root 'docs\play'
$githubDir = Join-Path $Root 'docs\github'
$siteAssetsDir = Join-Path $Root 'site\assets'
New-Item -ItemType Directory -Force $playDir, $githubDir, $siteAssetsDir | Out-Null

# Small/mono form (PRODUCT-IDENTITY section 2 & rule 34): the flat 24-unit Filler block inherited in S0050.
$smallGlyphPathData = 'M2,20h20v-4H2V20zM4,17h2v2H4V17zM2,4v4h20V4H2zM6,7H4V5h2V7zM2,14h20v-4H2V14zM4,11h2v2H4V11z'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# Formats a rounded-rectangle SVG/VectorDrawable path on the 24-unit grid.
function Format-RoundRectPath {
    param([double]$X, [double]$Y, [double]$W, [double]$H, [double]$R)
    $r = [Math]::Min($R, [Math]::Min($W, $H) / 2.0)
    $f = { param([double]$v) $v.ToString('0.###', $inv) }
    $x0 = & $f $X; $y0 = & $f $Y
    $x1 = & $f ($X + $W); $y1 = & $f ($Y + $H)
    $xr0 = & $f ($X + $r); $xr1 = & $f ($X + $W - $r)
    $yr0 = & $f ($Y + $r); $yr1 = & $f ($Y + $H - $r)
    $rr = & $f $r
    if ($r -le 0.001) {
        return "M$x0,$y0 H$x1 V$y1 H$x0 Z"
    }
    return "M$xr0,$y0 H$xr1 A$rr,$rr 0 0 1 $x1,$yr0 V$yr1 A$rr,$rr 0 0 1 $xr1,$y1 H$xr0 A$rr,$rr 0 0 1 $x0,$yr1 V$yr0 A$rr,$rr 0 0 1 $xr0,$y0 Z"
}

# Rich master geometry (FILLER-0072) on the 24-unit grid: three stacked drive bays (y = 4, 10, 16)
# with drop shadows, lower 3D bevels, left indicator sockets + LEDs, and bottom-to-top fill meters.
$bays = @(
    @{ Y = 4.0;  FillRatio = 0.34; LedColor = '#90CAF9'; BarColor = '#2196F3'; HiColor = '#64B5F6' },
    @{ Y = 10.0; FillRatio = 0.68; LedColor = '#38BDF8'; BarColor = '#1976D2'; HiColor = '#38BDF8' },
    @{ Y = 16.0; FillRatio = 1.00; LedColor = '#38BDF8'; BarColor = '#1976D2'; HiColor = '#4FC3F7' }
)

$masterShapes = [System.Collections.Generic.List[object]]::new()
function Add-Shape {
    param([double]$X, [double]$Y, [double]$W, [double]$H, [double]$R, [string]$Color, [double]$Alpha = 1.0)
    $masterShapes.Add([pscustomobject]@{
        X = $X; Y = $Y; W = $W; H = $H; R = $R
        Color = $Color; Alpha = $Alpha
        PathData = (Format-RoundRectPath -X $X -Y $Y -W $W -H $H -R $R)
    })
}

foreach ($bay in $bays) {
    $y = $bay.Y
    # Drop shadow beneath each drive bay
    Add-Shape -X 2.0 -Y ($y + 0.6) -W 20.0 -H 3.85 -R 0.85 -Color '#081A30' -Alpha 0.55
    # Lower 3D bevel edge
    Add-Shape -X 2.0 -Y ($y + 0.32) -W 20.0 -H 3.68 -R 0.85 -Color '#BDD2E6' -Alpha 1.0
    # Crisp white front face
    Add-Shape -X 2.0 -Y $y -W 20.0 -H 3.62 -R 0.85 -Color '#FFFFFF' -Alpha 1.0
    # Left recessed indicator socket (preserves the iconic left square)
    Add-Shape -X 3.5 -Y ($y + 0.78) -W 2.06 -H 2.06 -R 0.38 -Color '#12355B' -Alpha 1.0
    # Glowing status LED inside the socket
    Add-Shape -X 4.03 -Y ($y + 1.31) -W 1.0 -H 1.0 -R 0.22 -Color $bay.LedColor -Alpha 1.0
    # Storage fill-level meter track on the right
    $trackX = 7.2
    $trackY = $y + 1.11
    $trackW = 13.3
    $trackH = 1.40
    Add-Shape -X $trackX -Y $trackY -W $trackW -H $trackH -R 0.70 -Color '#DDE8F3' -Alpha 1.0
    # Filled portion of the meter + top specular highlight
    $fillW = [Math]::Round($trackW * $bay.FillRatio, 3)
    Add-Shape -X $trackX -Y $trackY -W $fillW -H $trackH -R 0.70 -Color $bay.BarColor -Alpha 1.0
    Add-Shape -X ($trackX + 0.2) -Y ($trackY + 0.14) -W ([Math]::Max(0.8, $fillW - 0.4)) -H 0.52 -R 0.26 -Color $bay.HiColor -Alpha 0.90
}

# Build SVG and Android VectorDrawable path elements from the single shape list.
$svgPaths = ($masterShapes | ForEach-Object {
    $op = if ($_.Alpha -lt 0.999) { " fill-opacity=`"$($_.Alpha.ToString('0.##', $inv))`"" } else { '' }
    "<path fill=`"$($_.Color)`"$op d=`"$($_.PathData)`"/>"
}) -join ''

$androidPaths = ($masterShapes | ForEach-Object {
    $alphaAttr = if ($_.Alpha -lt 0.999) { "`n            android:fillAlpha=`"$($_.Alpha.ToString('0.##', $inv))`"" } else { '' }
    "        <path`n            android:fillColor=`"$($_.Color)`"$alphaAttr`n            android:pathData=`"$($_.PathData)`" />"
}) -join "`n"

# Writes a text render target with LF line ends and no BOM, creating its folder; returns its full path.
function Write-Target {
    param([string]$Rel, [string]$Text)
    $path = Join-Path $Root $Rel
    New-Item -ItemType Directory -Force (Split-Path -Parent $path) | Out-Null
    [System.IO.File]::WriteAllText($path, ($Text -replace "`r`n", "`n"), $utf8NoBom)
    $path
}

$masterSvg = Write-Target 'assets/identity/master/filler-mark.svg' ("<svg xmlns=`"http://www.w3.org/2000/svg`" viewBox=`"0 0 24 24`">$svgPaths</svg>`n")
$smallSvg = Write-Target 'assets/identity/master/filler-mark-small.svg' ("<svg xmlns=`"http://www.w3.org/2000/svg`" viewBox=`"0 0 24 24`"><path fill=`"#FFFFFF`" d=`"$smallGlyphPathData`"/></svg>`n")

. (Join-Path $PSScriptRoot 'vector-renditions.ps1')
$vectorPaths = foreach ($rel in $vectorTargets.Keys) {
    $content = $vectorTargets[$rel].Replace('{NOTE}', $generatedNote).Replace('{PATH}', $smallGlyphPathData).Replace('{FOREGROUND_PATHS}', $androidPaths) + "`n"
    Write-Target $rel $content
}

function New-RoundRectGraphicsPath {
    param([single]$X, [single]$Y, [single]$W, [single]$H, [single]$R)
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = [Math]::Min($R, [Math]::Min($W, $H) / 2.0)
    if ($r -le 0.05) {
        $gp.AddRectangle((New-Object System.Drawing.RectangleF($X, $Y, $W, $H)))
        return $gp
    }
    $d = [single]($r * 2.0)
    $gp.AddArc($X, $Y, $d, $d, 180, 90)
    $gp.AddArc($X + $W - $d, $Y, $d, $d, 270, 90)
    $gp.AddArc($X + $W - $d, $Y + $H - $d, $d, $d, 0, 90)
    $gp.AddArc($X, $Y + $H - $d, $d, $d, 90, 90)
    $gp.CloseFigure()
    return $gp
}

# Draws the rich master shapes with the 24-unit centre (12, 12) mapped to ($cx, $cy).
# $unit is the size in pixels of one 108-unit canvas step (matching the 2.5x launcher group scale).
function Draw-Glyph {
    param([System.Drawing.Graphics]$G, [single]$cx, [single]$cy, [single]$unit)
    $scale24 = [single]($unit * 2.5)
    # Subtle ambient radial glow behind the drive stack
    $glowR = [single](15.0 * $scale24)
    $glowPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $glowPath.AddEllipse($cx - $glowR, $cy - $glowR, $glowR * 2, $glowR * 2)
    $pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush($glowPath)
    $pgb.CenterColor = [System.Drawing.Color]::FromArgb(90, 32, 92, 152)
    $pgb.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 18, 53, 91))
    $G.FillPath($pgb, $glowPath)
    $pgb.Dispose()
    $glowPath.Dispose()

    foreach ($s in $masterShapes) {
        $x = [single]($cx + ($s.X - 12.0) * $scale24)
        $y = [single]($cy + ($s.Y - 12.0) * $scale24)
        $w = [single]($s.W * $scale24)
        $h = [single]($s.H * $scale24)
        $r = [single]($s.R * $scale24)
        $baseCol = [System.Drawing.ColorTranslator]::FromHtml($s.Color)
        $alphaByte = [int][Math]::Round($s.Alpha * 255)
        $col = [System.Drawing.Color]::FromArgb($alphaByte, $baseCol.R, $baseCol.G, $baseCol.B)
        $brush = New-Object System.Drawing.SolidBrush($col)
        $gp = New-RoundRectGraphicsPath -X $x -Y $y -W $w -H $h -R $r
        try { $G.FillPath($brush, $gp) }
        finally { $gp.Dispose(); $brush.Dispose() }
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

# The page favicon: the rich master scaled 3.75x onto the 108x108 rounded-square plate.
$faviconPath = Join-Path $siteAssetsDir 'favicon.svg'
$favicon = "<svg xmlns=`"http://www.w3.org/2000/svg`" viewBox=`"0 0 108 108`">" +
    "<rect width=`"108`" height=`"108`" rx=`"20`" fill=`"$backgroundHex`"/>" +
    "<g transform=`"matrix(3.75 0 0 3.75 9 9)`">$svgPaths</g></svg>`n"
[System.IO.File]::WriteAllText($faviconPath, $favicon, $utf8NoBom)

$featurePath = Join-Path $playDir 'feature-graphic-1024x500.png'
Save-Banner -Width 1024 -Height 500 -GlyphX 250 -Unit 6.4 -TextX 450 -MaxFont 140 -Path $featurePath

$socialPath = Join-Path $githubDir 'social-preview-1280x640.png'
Save-Banner -Width 1280 -Height 640 -GlyphX 310 -Unit 8.2 -TextX 560 -MaxFont 170 -Path $socialPath

# The Open Graph and Twitter card of the pages (PRODUCT-IDENTITY rule 6, surface web.og-image).
$ogPath = Join-Path $siteAssetsDir 'og-image-1200x630.png'
Save-Banner -Width 1200 -Height 630 -GlyphX 290 -Unit 8.0 -TextX 530 -MaxFont 165 -Path $ogPath

foreach ($path in $iconPath, $featurePath, $socialPath, $ogPath, $siteIconPath) {
    $img = [System.Drawing.Image]::FromFile($path)
    Write-Host ("{0}: {1} x {2}, {3} bytes" -f $path.Substring($Root.Length + 1), $img.Width, $img.Height, (Get-Item $path).Length)
    $img.Dispose()
}
foreach ($path in @($masterSvg, $smallSvg, $faviconPath) + @($vectorPaths)) {
    Write-Host ("{0}: vector, {1} bytes" -f $path.Substring($Root.Length + 1), (Get-Item $path).Length)
}
