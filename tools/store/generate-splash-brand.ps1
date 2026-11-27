<#
.SYNOPSIS
    Generate the splash brand drawable for every phone locale that declares `splash_slogan`.

.DESCRIPTION
    FILLER-0062: Android 12+ splash centre content is a vector drawable, so the wordmark and
    localized slogan are baked into vector path outlines per locale inside the 288dp asset's
    192dp visible mask circle.

.PARAMETER Check
    Compare only. Report what would change and exit 1 instead of writing.

.OUTPUTS
    Exit 0 - drawables generated, or already in sync under -Check.
    Exit 1 - a slogan does not fit the mask circle, or -Check found a divergence.
    Exit 2 - could not verify: resource root missing.
#>
[CmdletBinding()]
param(
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$resRoot = Join-Path $repoRoot 'phone\src\main\res'
if (-not (Test-Path $resRoot)) {
    Write-Error "generate-splash-brand: resource root not found: $resRoot" -ErrorAction Continue
    exit 2
}

$VIEWPORT = 288.0
$CIRCLE_R = 96.0
$CENTRE = $VIEWPORT / 2.0
$FIT_MARGIN = 0.96

$MARK_SPAN = 24.0
$MARK_BOX = 91.2
$MARK_X = $CENTRE - ($MARK_BOX / 2.0)
$MARK_Y = 58.0
$MARK_SCALE = $MARK_BOX / $MARK_SPAN
$MARK_PIVOT_Y = $MARK_Y + ($MARK_BOX / 2.0)
$MARK_PATH_DATA = 'M2,20h20v-4H2V20zM4,17h2v2H4V17zM2,4v4h20V4H2zM6,7H4V5h2V7zM2,14h20v-4H2V14zM4,11h2v2H4V11z'

$WORDMARK_TEXT = 'Filler'
$WORDMARK_BOTTOM = 197.0
$WORDMARK_TRANSLATE_Y = -14.0
$WORDMARK_SIZES = @(28, 26, 24, 22, 20, 18)

$SLOGAN_BOTTOM = 207.0
$SLOGAN_SIZES = @(17, 16, 15, 14, 13, 12, 11, 10)
$INV = [System.Globalization.CultureInfo]::InvariantCulture

function ConvertTo-SvgPathData {
    param(
        [System.Drawing.Drawing2D.GraphicsPath]$Path,
        [double]$OffsetX,
        [double]$OffsetY
    )
    $points = $Path.PathPoints
    $types = $Path.PathTypes
    $sb = New-Object System.Text.StringBuilder
    $i = 0
    while ($i -lt $points.Length) {
        $t = $types[$i]
        $kind = $t -band 0x07
        $close = ($t -band 0x80) -ne 0
        if ($kind -eq 0) {
            $x = ($points[$i].X + $OffsetX).ToString('0.#', $INV)
            $y = ($points[$i].Y + $OffsetY).ToString('0.#', $INV)
            [void]$sb.Append("M$x,$y")
            $i++
        } elseif ($kind -eq 1) {
            $x = ($points[$i].X + $OffsetX).ToString('0.#', $INV)
            $y = ($points[$i].Y + $OffsetY).ToString('0.#', $INV)
            [void]$sb.Append("L$x,$y")
            $i++
        } elseif ($kind -eq 3 -and ($i + 2) -lt $points.Length) {
            $x1 = ($points[$i].X + $OffsetX).ToString('0.#', $INV)
            $y1 = ($points[$i].Y + $OffsetY).ToString('0.#', $INV)
            $x2 = ($points[$i + 1].X + $OffsetX).ToString('0.#', $INV)
            $y2 = ($points[$i + 1].Y + $OffsetY).ToString('0.#', $INV)
            $x3 = ($points[$i + 2].X + $OffsetX).ToString('0.#', $INV)
            $y3 = ($points[$i + 2].Y + $OffsetY).ToString('0.#', $INV)
            [void]$sb.Append("C$x1,$y1 $x2,$y2 $x3,$y3")
            $close = ($types[$i + 2] -band 0x80) -ne 0
            $i += 3
        } else {
            $i++
        }
        if ($close) {
            [void]$sb.Append('Z')
        }
    }
    return $sb.ToString()
}

function Test-InsideCircle {
    param(
        [double]$X0, [double]$Y0, [double]$X1, [double]$Y1,
        [double]$Dy = 0.0
    )
    $limit = $CIRCLE_R * $FIT_MARGIN
    foreach ($x in @($X0, $X1)) {
        foreach ($y in @(($Y0 + $Dy), ($Y1 + $Dy))) {
            $dist = [Math]::Sqrt([Math]::Pow($x - $CENTRE, 2) + [Math]::Pow($y - $CENTRE, 2))
            if ($dist -gt $limit) { return $false }
        }
    }
    return $true
}

function Get-FittedTextPath {
    param(
        [string]$Text,
        [string]$FontName,
        [System.Drawing.FontStyle]$Style,
        [int[]]$Sizes,
        [double]$TargetBottom,
        [double]$CheckDy = 0.0
    )
    $ff = New-Object System.Drawing.FontFamily($FontName)
    $sf = [System.Drawing.StringFormat]::GenericTypographic
    try {
        foreach ($size in $Sizes) {
            $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
            try {
                $gp.AddString($Text, $ff, [int]$Style, [single]$size, (New-Object System.Drawing.PointF(0, 0)), $sf)
                if ($gp.PointCount -eq 0) { continue }
                $b = $gp.GetBounds()
                $dx = $CENTRE - ($b.Left + ($b.Width / 2.0))
                $dy = $TargetBottom - $b.Bottom
                $x0 = $b.Left + $dx
                $x1 = $b.Right + $dx
                $y0 = $b.Top + $dy
                $y1 = $b.Bottom + $dy
                if (Test-InsideCircle -X0 $x0 -Y0 $y0 -X1 $x1 -Y1 $y1 -Dy $CheckDy) {
                    $pathData = ConvertTo-SvgPathData -Path $gp -OffsetX $dx -OffsetY $dy
                    return [pscustomobject]@{ Size = $size; PathData = $pathData; Width = $b.Width }
                }
            } finally {
                $gp.Dispose()
            }
        }
    } finally {
        $ff.Dispose()
    }
    return $null
}

function Read-Slogan {
    param([string]$StringsPath)
    if (-not (Test-Path $StringsPath)) { return $null }
    [xml]$xml = Get-Content -LiteralPath $StringsPath -Encoding UTF8
    foreach ($node in $xml.resources.string) {
        if ($node.name -eq 'splash_slogan') {
            $text = $node.'#text'
            if ($null -eq $text) { $text = $node.InnerText }
            return $text.Trim().Trim('"').Replace("\'", "'")
        }
    }
    return $null
}

function Build-BrandXml {
    param(
        [string]$WordmarkPathData,
        [string]$SloganPathData
    )
    $tx = ($MARK_X).ToString('0.##', $INV)
    $ty = ($MARK_Y).ToString('0.##', $INV)
    $sc = ($MARK_SCALE).ToString('0.##', $INV)
    $py = ($MARK_PIVOT_Y).ToString('0.#', $INV)
    $wty = ($WORDMARK_TRANSLATE_Y).ToString('0.#', $INV)
    $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<!--
    GENERATED by tools/store/generate-splash-brand.ps1 (FILLER-0062) - do not hand-edit.
    Regenerate after changing `splash_slogan` in strings.xml or the generator layout constants.
    Sized for the API-31 splash icon slot: a 288dp asset whose content sits inside the 192dp mask circle.
-->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="288dp"
    android:height="288dp"
    android:viewportWidth="288"
    android:viewportHeight="288">
    <group android:name="splash">
        <group
            android:name="mark"
            android:pivotX="144"
            android:pivotY="$py">
            <group
                android:scaleX="$sc"
                android:scaleY="$sc"
                android:translateX="$tx"
                android:translateY="$ty">
                <path
                    android:name="markPath"
                    android:fillColor="@color/splash_mark"
                    android:fillAlpha="1"
                    android:pathData="$MARK_PATH_DATA" />
            </group>
        </group>
        <group android:name="wordmark" android:translateY="$wty">
            <path
                android:name="wordmarkPath"
                android:fillColor="@color/splash_content"
                android:fillAlpha="1"
                android:pathData="$WordmarkPathData" />
        </group>
        <group android:name="slogan">
            <path
                android:name="sloganPath"
                android:fillColor="@color/splash_slogan"
                android:fillAlpha="1"
                android:pathData="$SloganPathData" />
        </group>
    </group>
</vector>
"@
    return ($xml + "`n")
}

$wordmark = Get-FittedTextPath -Text $WORDMARK_TEXT -FontName 'Segoe UI' -Style ([System.Drawing.FontStyle]::Bold) -Sizes $WORDMARK_SIZES -TargetBottom $WORDMARK_BOTTOM -CheckDy $WORDMARK_TRANSLATE_Y
if ($null -eq $wordmark) {
    Write-Error 'generate-splash-brand: wordmark does not fit the mask circle' -ErrorAction Continue
    exit 1
}

$valuesDirs = Get-ChildItem -LiteralPath $resRoot -Directory | Where-Object {
    $_.Name -eq 'values' -or $_.Name -match '^values-((?:[a-z]{2,3}(?:-r[A-Z]{2})?)|(?:b\+[A-Za-z]{2,3}(?:\+[A-Za-z0-9]+)*))$'
} | Sort-Object Name

$changed = New-Object System.Collections.Generic.List[string]
$failures = New-Object System.Collections.Generic.List[string]
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

foreach ($dir in $valuesDirs) {
    $stringsPath = Join-Path $dir.FullName 'strings.xml'
    $sloganText = Read-Slogan -StringsPath $stringsPath
    if ([string]::IsNullOrWhiteSpace($sloganText)) { continue }

    $locale = if ($dir.Name -eq 'values') { '' } else { $dir.Name.Substring(7) }
    $fitted = Get-FittedTextPath -Text $sloganText -FontName 'Georgia' -Style ([System.Drawing.FontStyle]::Italic) -Sizes $SLOGAN_SIZES -TargetBottom $SLOGAN_BOTTOM
    if ($null -eq $fitted) {
        $failures.Add("$($dir.Name): '$sloganText' does not fit the mask circle at any size down to $($SLOGAN_SIZES[-1])")
        continue
    }

    $targetDir = Join-Path $resRoot ($(if ($locale -eq '') { 'drawable' } else { "drawable-$locale" }))
    $targetFile = Join-Path $targetDir 'ic_splash_app_brand.xml'
    $xmlContent = (Build-BrandXml -WordmarkPathData $wordmark.PathData -SloganPathData $fitted.PathData) -replace "`r`n", "`n"
    $current = if (Test-Path $targetFile) { [System.IO.File]::ReadAllText($targetFile, $utf8NoBom) -replace "`r`n", "`n" } else { $null }
    if ($current -eq $xmlContent) { continue }

    $label = if ($locale -eq '') { 'default' } else { $locale }
    $changed.Add("$label (slogan size $($fitted.Size))")
    if (-not $Check) {
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        [System.IO.File]::WriteAllText($targetFile, $xmlContent, $utf8NoBom)
    }
}

foreach ($f in $failures) { Write-Error "FAIL $f" -ErrorAction Continue }
foreach ($c in $changed) { Write-Host ($(if ($Check) { "would write $c" } else { "wrote $c" })) }

if ($failures.Count -gt 0) { exit 1 }
if ($Check -and $changed.Count -gt 0) { exit 1 }
if ($changed.Count -eq 0) { Write-Host 'splash brand drawables are in sync' }
exit 0
