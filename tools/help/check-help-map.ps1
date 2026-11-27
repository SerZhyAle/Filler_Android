#requires -Version 7.0
<#
.SYNOPSIS
    The help-map gate (S0034): counts the surfaces of the app from its own sources and diffs them with the help map, as
    CONTEXT-HELP rule 19 asks of every product.
.DESCRIPTION
    Sources of truth read here, never the map itself:
      - the <activity> entries of the phone and wear manifests: the surface id is <Prefix><SimpleName> (no prefix for the
        phone, "Wear" for the watch, so the watch's MainActivity is WearMainActivity);
      - the dialog and picker sites of the Kotlin sources (MaterialAlertDialogBuilder, AlertDialog.Builder, TimePickerDialog,
        DatePickerDialog, the Material pickers, Dialog subclasses, DialogFragment, any ActivityResultContracts contract
        except StartActivityForResult): each carries "// help-surface: <RowId>" on its own line or the line above;
        ui/help/ is the help layer itself, the answer and not a surface;
      - the activity_* layouts, and the layouts and menus each activity file inflates.
    Findings (every one is fatal; there is no baseline, CHECK-BASELINE is not applicable here):
      surface: an activity with no row; a row no activity and no dialog site backs; a dialog site with no marker; a marker
        naming no row; a marker with no dialog site; an activity_* layout no manifest activity inflates; a launcher activity
        whose row is none (rule 4).
      map: unknown form, duplicate id, missing name; a none or inherit row without a reason; an inherit row with no parent or
        whose chain ends in no help; a page or both row (this product ships no pages, so no page check exists to run).
      layer: a layer row with no help id; a help id with no entries or no row; a duplicate anchor; a row anchor that is no
        entry anchor (an inherit row's own anchor included, S0041: it must be an entry of the help its chain reaches); an entry view id missing from the surface's layouts (portrait and landscape alike) or from the menus
        its activity inflates; an entry string missing from one of the 13 declared locales (translatable="false" is exempt);
        a locale folder with strings the gate does not declare; an entry glyph (the optional R.drawable argument, FILLER-0059)
        that is missing from phone/src/main/res/drawable, differs from the app:icon or android:icon of the control it marks,
        or sits on an entry whose control draws none, and a control that draws a glyph its entry does not show (ICON-SET
        rule 8: the help shows the control's own glyph beside its name).
      wiring: a layer, page, both or phone inherit row whose activity does not call HelpOpenManager.open with its own row id
        (rules 1 to 3, 17); a window outside ui/help/ that builds a HelpLayer itself (rule 17).
    The run does not stop at the first finding (CHECK-VERDICT rule 9).
.NOTES
    Exit codes: 0 PASS, 1 FAIL (one reason line per finding), 2 COULD NOT VERIFY (a missing or unreadable input, a reason
    line per cause). The verdict line is the last line written, on every path (CHECK-VERDICT rules 1, 5, 11):
      help-map: PASS (<counts>) | help-map: FAIL (<n> finding(s)) | help-map: COULD NOT VERIFY (<what>)
    -Root is the repository root; the test script points it at throw-away copies.
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)
$ErrorActionPreference = 'Stop'

$androidNs = 'http://schemas.android.com/apk/res/android'
$modules = [ordered]@{ phone = ''; wear = 'Wear' }
$locales = @('values', 'values-ar', 'values-b+zh+Hans', 'values-bn', 'values-de', 'values-es', 'values-fr', 'values-hi',
    'values-it', 'values-pt', 'values-ru', 'values-uk', 'values-ur')
$forms = @('page', 'layer', 'both', 'inherit', 'none')
$siteRx = [regex]::new('MaterialAlertDialogBuilder\(|\bAlertDialog\.Builder\(|\bAppCompatDialog\(|(?<![\w.])Dialog\(|\bBottomSheetDialog\(|\b(?:Time|Date)PickerDialog\(|\bMaterial(?:Time|Date)Picker\b|DialogFragment\b|ActivityResultContracts\.(?!StartActivityForResult\b|StartIntentSenderForResult\b)\w+')
$markerRx = [regex]::new('//\s*help-surface:\s*([A-Za-z][A-Za-z0-9_]*)')

$findings = [System.Collections.Generic.List[string]]::new()
function Add-Finding([string]$Class, [string]$Message) { $findings.Add("${Class}: $Message") }
function Get-Rel([string]$Path) { return [IO.Path]::GetRelativePath($Root, $Path).Replace('\', '/') }
function Stop-Unverified([string[]]$Reasons, [string]$What) {
    foreach ($r in $Reasons) { Write-Output "COULD NOT VERIFY - $r" }
    Write-Output "help-map: COULD NOT VERIFY ($What)"
    exit 2
}
function Get-BalancedBody([string]$Text, [int]$Open) {
    $depth = 0; $inString = $false
    for ($i = $Open; $i -lt $Text.Length; $i++) {
        $ch = $Text[$i]
        if ($inString) { if ($ch -eq '\') { $i++ } elseif ($ch -eq '"') { $inString = $false }; continue }
        if ($ch -eq '"') { $inString = $true; continue }
        if ($ch -eq '(') { $depth++ }
        elseif ($ch -eq ')') { $depth--; if ($depth -eq 0) { return $Text.Substring($Open + 1, $i - $Open - 1) } }
    }
    return $null
}
function ConvertTo-LayoutName([string]$Class) { return ([regex]::Replace($Class, '(?<=[a-z0-9])(?=[A-Z])', '_')).ToLowerInvariant() }
$idCache = @{}
function Get-FileIds([string]$Path) {
    if (-not $idCache.ContainsKey($Path)) {
        $set = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($m in [regex]::Matches([IO.File]::ReadAllText($Path), '@\+id/([A-Za-z0-9_]+)')) { [void]$set.Add($m.Groups[1].Value) }
        $idCache[$Path] = $set
    }
    return $idCache[$Path]
}

try {
    # ---- inputs: a missing one is "could not verify", not a finding ------------------------------------------------------
    $mapFile = Join-Path $Root 'phone/src/main/assets/help/help-map.json'
    $contentFile = Join-Path $Root 'phone/src/main/java/com/sza/filler/ui/help/HelpLayerContent.kt'
    $phoneRes = Join-Path $Root 'phone/src/main/res'
    $required = @($mapFile, $contentFile, $phoneRes)
    foreach ($m in $modules.Keys) {
        $required += (Join-Path $Root "$m/src/main/AndroidManifest.xml")
        $required += (Join-Path $Root "$m/src/main/java")
    }
    $absent = @($required | Where-Object { -not (Test-Path -LiteralPath $_) })
    if ($absent.Count -gt 0) {
        Stop-Unverified @($absent | ForEach-Object { "missing input $(Get-Rel $_)" }) "$($absent.Count) missing input(s)"
    }
    try {
        $map = [IO.File]::ReadAllText($mapFile) | ConvertFrom-Json -AsHashtable -Depth 10
    } catch {
        Stop-Unverified @("unreadable $(Get-Rel $mapFile): $($_.Exception.Message)") 'help map unreadable'
    }
    if ($map -isnot [System.Collections.IDictionary] -or -not $map.Contains('surfaces') -or $map['surfaces'] -isnot [System.Collections.IList]) {
        Stop-Unverified @("$(Get-Rel $mapFile) has no surfaces array") 'help map has no surfaces'
    }
    if (-not $map.Contains('schemaVersion')) { Add-Finding 'map' 'schemaVersion is missing' }

    # ---- layouts and menus per module -----------------------------------------------------------------------------------
    $layoutFiles = @{}
    $menuFiles = @{}
    foreach ($m in $modules.Keys) {
        $layoutFiles[$m] = @{}
        $menuFiles[$m] = @{}
        $res = Join-Path $Root "$m/src/main/res"
        if (-not (Test-Path -LiteralPath $res)) { continue }
        foreach ($dir in Get-ChildItem -LiteralPath $res -Directory) {
            $bucket = if ($dir.Name -match '^layout(-.*)?$') { $layoutFiles[$m] } elseif ($dir.Name -match '^menu(-.*)?$') { $menuFiles[$m] } else { $null }
            if ($null -eq $bucket) { continue }
            foreach ($f in Get-ChildItem -LiteralPath $dir.FullName -Filter '*.xml' -File) {
                $name = [IO.Path]::GetFileNameWithoutExtension($f.Name)
                if (-not $bucket.ContainsKey($name)) { $bucket[$name] = [System.Collections.Generic.List[string]]::new() }
                $bucket[$name].Add($f.FullName)
            }
        }
    }

    # ---- source 1: the activities of the manifests ----------------------------------------------------------------------
    $activities = [ordered]@{}
    foreach ($m in $modules.Keys) {
        $manifestPath = Join-Path $Root "$m/src/main/AndroidManifest.xml"
        try { [xml]$doc = [IO.File]::ReadAllText($manifestPath) } catch { Stop-Unverified @("unreadable $(Get-Rel $manifestPath): $($_.Exception.Message)") 'manifest unreadable' }
        foreach ($a in $doc.SelectNodes('//activity')) {
            $simple = $a.GetAttribute('name', $androidNs).Split('.')[-1]
            $id = $modules[$m] + $simple
            $launcher = $false
            foreach ($c in $a.SelectNodes('intent-filter/category')) {
                if ($c.GetAttribute('name', $androidNs) -in 'android.intent.category.LAUNCHER', 'android.intent.category.LEANBACK_LAUNCHER') { $launcher = $true }
            }
            if ($activities.Contains($id)) { Add-Finding 'surface' "two manifest activities give the surface id $id"; continue }
            $file = Get-ChildItem -LiteralPath (Join-Path $Root "$m/src/main/java") -Recurse -Filter "$simple.kt" -File | Select-Object -First 1
            $layoutNames = [System.Collections.Generic.List[string]]::new()
            $menuNames = [System.Collections.Generic.List[string]]::new()
            $text = ''
            if ($null -eq $file) {
                Add-Finding 'surface' "activity $id ($m manifest) has no $simple.kt under $m/src/main/java"
            } else {
                $text = [IO.File]::ReadAllText($file.FullName)
                foreach ($b in [regex]::Matches($text, '\b([A-Z][A-Za-z0-9]*)Binding\b')) {
                    $n = ConvertTo-LayoutName $b.Groups[1].Value
                    if ($layoutFiles[$m].ContainsKey($n) -and -not $layoutNames.Contains($n)) { $layoutNames.Add($n) }
                }
                foreach ($b in [regex]::Matches($text, 'R\.layout\.(\w+)')) {
                    $n = $b.Groups[1].Value
                    if ($layoutFiles[$m].ContainsKey($n) -and -not $layoutNames.Contains($n)) { $layoutNames.Add($n) }
                }
                foreach ($b in [regex]::Matches($text, 'R\.menu\.(\w+)')) {
                    $n = $b.Groups[1].Value
                    if ($menuFiles[$m].ContainsKey($n) -and -not $menuNames.Contains($n)) { $menuNames.Add($n) }
                }
            }
            $activities[$id] = @{ Id = $id; Module = $m; Simple = $simple; Launcher = $launcher; File = $file; Text = $text; Layouts = $layoutNames; Menus = $menuNames }
        }
    }
    if ($activities.Count -eq 0) { Stop-Unverified @('no <activity> found in the manifests') 'no activities' }

    # ---- source 3: layouts no activity inflates --------------------------------------------------------------------------
    foreach ($m in $modules.Keys) {
        foreach ($name in $layoutFiles[$m].Keys) {
            if ($name -notlike 'activity_*') { continue }
            $used = @($activities.Values | Where-Object { $_.Module -eq $m -and $_.Layouts.Contains($name) })
            if ($used.Count -eq 0) { Add-Finding 'surface' "layout $m/res/layout*/$name.xml is inflated by no manifest activity, so it is a window with no row" }
        }
    }

    # ---- source 2: dialog and picker sites, and the markers that tie them to rows ------------------------------------------
    $siteIds = [System.Collections.Generic.Dictionary[string, int]]::new()
    $siteCount = 0
    $markers = [System.Collections.Generic.List[object]]::new()
    $consumed = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($m in $modules.Keys) {
        foreach ($kt in Get-ChildItem -LiteralPath (Join-Path $Root "$m/src/main/java") -Recurse -Filter '*.kt' -File) {
            $rel = Get-Rel $kt.FullName
            $inHelp = $rel -match '/ui/help/'
            $lines = [IO.File]::ReadAllLines($kt.FullName)
            for ($i = 0; $i -lt $lines.Length; $i++) {
                $raw = $lines[$i]
                $trim = $raw.TrimStart()
                $mm = $markerRx.Match($raw)
                if ($mm.Success) { $markers.Add(@{ Key = "${rel}:$($i + 1)"; Where = "${rel}:$($i + 1)"; Id = $mm.Groups[1].Value }) }
                if ($trim.StartsWith('import ') -or $trim.StartsWith('//') -or $trim.StartsWith('*') -or $trim.StartsWith('/*')) { continue }
                $code = [regex]::Replace($raw, '\s//.*$', '')
                if (-not $inHelp -and [regex]::IsMatch($code, '(?<![\w.])HelpLayer\(')) {
                    Add-Finding 'wiring' "${rel}:$($i + 1) builds a HelpLayer itself; the one entry is HelpOpenManager (rule 17)"
                }
                if ($inHelp -or -not $siteRx.IsMatch($code)) { continue }
                $siteCount++
                $id = $null
                if ($mm.Success) {
                    $id = $mm.Groups[1].Value; [void]$consumed.Add("${rel}:$($i + 1)")
                } elseif ($i -gt 0 -and $lines[$i - 1].TrimStart().StartsWith('//')) {
                    $pm = $markerRx.Match($lines[$i - 1])
                    if ($pm.Success) { $id = $pm.Groups[1].Value; [void]$consumed.Add("${rel}:$i") }
                }
                if ($null -eq $id) {
                    Add-Finding 'surface' "dialog site ${rel}:$($i + 1) has no '// help-surface: <RowId>' marker on its line or the line above"
                } else {
                    if (-not $siteIds.ContainsKey($id)) { $siteIds[$id] = 0 }
                    $siteIds[$id]++
                }
            }
        }
    }
    foreach ($mk in $markers) {
        if (-not $consumed.Contains($mk.Key)) { Add-Finding 'surface' "marker '$($mk.Id)' at $($mk.Where) sits on no dialog site" }
    }

    # ---- the map ----------------------------------------------------------------------------------------------------------
    $rows = [ordered]@{}
    $index = 0
    foreach ($r in $map['surfaces']) {
        $index++
        if ($r -isnot [System.Collections.IDictionary]) { Add-Finding 'map' "row $index is not an object"; continue }
        $id = [string]$r['id']
        if ([string]::IsNullOrWhiteSpace($id)) { Add-Finding 'map' "row $index has no id"; continue }
        if ($rows.Contains($id)) { Add-Finding 'map' "row id $id appears twice"; continue }
        if ([string]::IsNullOrWhiteSpace([string]$r['name'])) { Add-Finding 'map' "row $id has no name" }
        $form = ([string]$r['form']).ToLowerInvariant()
        if ($form -notin $forms) { Add-Finding 'map' "row $id has form '$($r['form'])', not one of $($forms -join ', ')"; continue }
        $r['form'] = $form
        $rows[$id] = $r
    }
    foreach ($id in $rows.Keys) {
        $r = $rows[$id]
        if ($r['form'] -in 'none', 'inherit' -and [string]::IsNullOrWhiteSpace([string]$r['reason'])) {
            Add-Finding 'map' "row $id is $($r['form']) without a reason (rule 19)"
        }
        if ($r['form'] -in 'page', 'both') {
            Add-Finding 'map' "row $id has form $($r['form']): this product ships no help pages and the gate has no page check, so the row cannot be judged"
        }
    }
    function Resolve-Row($Row) {
        $visited = [System.Collections.Generic.HashSet[string]]::new()
        while ($null -ne $Row -and $Row['form'] -eq 'inherit') {
            if (-not $visited.Add([string]$Row['id'])) { return $null }
            $parent = [string]$Row['parent']
            $Row = if ($rows.Contains($parent)) { $rows[$parent] } else { $null }
        }
        return $Row
    }
    foreach ($id in $rows.Keys) {
        $r = $rows[$id]
        if ($r['form'] -ne 'inherit') { continue }
        if ([string]::IsNullOrWhiteSpace([string]$r['parent'])) { Add-Finding 'map' "inherit row $id names no parent"; continue }
        $end = Resolve-Row $r
        if ($null -eq $end -or $end['form'] -notin 'layer', 'page', 'both') {
            Add-Finding 'map' "inherit row $id reaches no help: its parent chain ends in none, a cycle or a missing row"
        }
    }

    # ---- surfaces against rows --------------------------------------------------------------------------------------------
    foreach ($id in $activities.Keys) {
        if (-not $rows.Contains($id)) { Add-Finding 'surface' "activity $id ($($activities[$id].Module) manifest) has no row in the help map" }
    }
    foreach ($id in $siteIds.Keys) {
        if (-not $rows.Contains($id)) { Add-Finding 'surface' "marker '$id' names no row in the help map" }
    }
    foreach ($id in $rows.Keys) {
        if (-not $activities.Contains($id) -and -not $siteIds.ContainsKey($id)) {
            Add-Finding 'surface' "row $id has no surface: no manifest activity and no marked dialog site is named $id"
        }
    }
    foreach ($a in $activities.Values) {
        if ($a.Launcher -and $rows.Contains($a.Id) -and $rows[$a.Id]['form'] -eq 'none') {
            Add-Finding 'surface' "launcher activity $($a.Id) has form none; a main window needs help (rule 4)"
        }
    }

    # ---- the layer content (HelpLayerContent.kt) -----------------------------------------------------------------------------
    $src = [IO.File]::ReadAllText($contentFile)
    $src = [regex]::Replace($src, '/\*[\s\S]*?\*/', '')
    $src = [regex]::Replace($src, '(?m)^\s*//.*$', '')
    $consts = @{}
    foreach ($c in [regex]::Matches($src, 'const val (\w+)\s*=\s*"([^"]*)"')) { $consts[$c.Groups[1].Value] = $c.Groups[2].Value }
    $lists = @{}
    foreach ($l in [regex]::Matches($src, '(?m)private val (\w+)\s*=\s*listOf\(')) {
        $body = Get-BalancedBody $src ($l.Index + $l.Length - 1)
        if ($null -eq $body) { Add-Finding 'layer' "list $($l.Groups[1].Value) in HelpLayerContent.kt has no closing parenthesis"; continue }
        $entries = [System.Collections.Generic.List[object]]::new()
        # The optional fifth argument is the glyph drawn beside the entry's name (FILLER-0059, ICON-SET rule 8).
        $pattern = 'HelpLayerEntry\(\s*"([^"]+)"\s*,\s*(R\.id\.(\w+)|null)\s*,\s*R\.string\.(\w+)\s*,\s*R\.string\.(\w+)\s*(?:,\s*R\.drawable\.(\w+)\s*)?,?\s*\)'
        foreach ($e in [regex]::Matches($body, $pattern)) {
            $entries.Add(@{ Anchor = $e.Groups[1].Value; ViewId = $(if ($e.Groups[3].Success) { $e.Groups[3].Value } else { $null }); Label = $e.Groups[4].Value; Text = $e.Groups[5].Value; Glyph = $(if ($e.Groups[6].Success) { $e.Groups[6].Value } else { $null }) })
        }
        $declared = [regex]::Matches($body, 'HelpLayerEntry\(').Count
        if ($declared -ne $entries.Count) { Add-Finding 'layer' "list $($l.Groups[1].Value) declares $declared entries and the gate reads $($entries.Count): an entry is not in the shape R.id/null, two R.string and an optional R.drawable" }
        $lists[$l.Groups[1].Value] = $entries
    }
    if ($lists.Count -eq 0) { Stop-Unverified @("$(Get-Rel $contentFile) holds no entry list the gate can read") 'layer content unreadable' }
    $content = @{}
    foreach ($b in [regex]::Matches($src, '(?m)^\s*(\w+)\s*->\s*(\w+)\s*$')) {
        $const = $b.Groups[1].Value; $list = $b.Groups[2].Value
        if (-not $consts.ContainsKey($const) -or -not $lists.ContainsKey($list)) { Add-Finding 'layer' "entries() branch $const -> $list names no help id constant or no entry list"; continue }
        $content[$consts[$const]] = $lists[$list]
    }
    foreach ($list in $lists.Keys) {
        if (-not ($content.Values | Where-Object { [object]::ReferenceEquals($_, $lists[$list]) })) { Add-Finding 'layer' "entry list $list is reached by no entries() branch" }
    }
    foreach ($helpId in $content.Keys) {
        $seen = @{}
        foreach ($e in $content[$helpId]) {
            if ($seen.ContainsKey($e.Anchor)) { Add-Finding 'layer' "help id $helpId has the anchor '$($e.Anchor)' twice" }
            $seen[$e.Anchor] = $true
        }
    }

    # ---- locales ----------------------------------------------------------------------------------------------------------
    $strings = @{}
    $notTranslatable = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($loc in $locales) {
        $dir = Join-Path $phoneRes $loc
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) { Add-Finding 'locale' "locale folder phone/src/main/res/$loc is missing"; continue }
        $set = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.xml' -File) {
            try { [xml]$x = [IO.File]::ReadAllText($f.FullName) } catch { Add-Finding 'locale' "$(Get-Rel $f.FullName) is not well-formed XML"; continue }
            foreach ($s in $x.SelectNodes('/resources/string')) {
                [void]$set.Add($s.GetAttribute('name'))
                if ($s.GetAttribute('translatable') -eq 'false') { [void]$notTranslatable.Add($s.GetAttribute('name')) }
            }
        }
        $strings[$loc] = $set
    }
    foreach ($dir in Get-ChildItem -LiteralPath $phoneRes -Directory -Filter 'values*') {
        if ($dir.Name -in $locales) { continue }
        $hasStrings = $false
        foreach ($f in Get-ChildItem -LiteralPath $dir.FullName -Filter '*.xml' -File) {
            if ([regex]::IsMatch([IO.File]::ReadAllText($f.FullName), '<string\s')) { $hasStrings = $true }
        }
        if ($hasStrings) { Add-Finding 'locale' "folder $($dir.Name) carries strings but is not one of the 13 locales the gate declares; add it to the gate's list in the same edit" }
    }

    # ---- layer rows: anchors, view ids, strings -----------------------------------------------------------------------------
    $usedHelpIds = [System.Collections.Generic.HashSet[string]]::new()
    $entryCount = 0
    $needed = @{}
    foreach ($id in $rows.Keys) {
        $r = $rows[$id]
        if ($r['form'] -ne 'layer') { continue }
        $helpId = [string]$r['help']
        if ([string]::IsNullOrWhiteSpace($helpId)) { Add-Finding 'layer' "layer row $id has no help id"; continue }
        [void]$usedHelpIds.Add($helpId)
        if (-not $content.ContainsKey($helpId) -or $content[$helpId].Count -eq 0) {
            Add-Finding 'layer' "layer row $id names help id '$helpId' with no entries in HelpLayerContent.kt"; continue
        }
        $entries = $content[$helpId]
        $entryCount += $entries.Count
        $anchor = [string]$r['anchor']
        if ($anchor -ne '' -and -not ($entries | Where-Object { $_.Anchor -eq $anchor })) {
            Add-Finding 'layer' "layer row $id has the anchor '$anchor', which is no entry of help id '$helpId'"
        }
        $act = if ($activities.Contains($id)) { $activities[$id] } else { $null }
        foreach ($e in $entries) {
            foreach ($sn in $e.Label, $e.Text) {
                if (-not $needed.ContainsKey($sn)) { $needed[$sn] = [System.Collections.Generic.List[string]]::new() }
                $needed[$sn].Add("$helpId/$($e.Anchor)")
            }
            if ($null -ne $e.Glyph -and -not (Test-Path -LiteralPath (Join-Path $phoneRes "drawable/$($e.Glyph).xml"))) {
                Add-Finding 'layer' "entry '$($e.Anchor)' of help id $helpId shows R.drawable.$($e.Glyph), which is not in phone/src/main/res/drawable"
            }
            if ($null -eq $e.ViewId) {
                if ($null -ne $e.Glyph) { Add-Finding 'layer' "entry '$($e.Anchor)' of help id $helpId shows a glyph but marks no control that draws it" }
                continue
            }
            $vid = $e.ViewId
            $found = $false
            $partial = $null
            $module = if ($null -ne $act) { $act.Module } else { 'phone' }
            $controlFiles = [System.Collections.Generic.List[string]]::new()
            $layoutNames = if ($null -ne $act) { $act.Layouts } else { $layoutFiles['phone'].Keys }
            foreach ($name in $layoutNames) {
                $variants = $layoutFiles[$module][$name]
                $have = @($variants | Where-Object { (Get-FileIds $_).Contains($vid) })
                foreach ($f in $have) { $controlFiles.Add($f) }
                if ($have.Count -eq 0) { continue }
                if ($have.Count -eq $variants.Count) { $found = $true; break }
                $lacking = @($variants | Where-Object { $_ -notin $have } | ForEach-Object { Get-Rel $_ })
                $partial = "entry '$($e.Anchor)' of help id $helpId marks R.id.$vid, which is missing from $($lacking -join ', ')"
            }
            if (-not $found -and $null -ne $act) {
                foreach ($name in $act.Menus) {
                    foreach ($f in $menuFiles[$act.Module][$name]) { if ((Get-FileIds $f).Contains($vid)) { $found = $true; $controlFiles.Add($f) } }
                }
            }
            if (-not $found) {
                Add-Finding 'layer' $(if ($partial) { $partial } else { "entry '$($e.Anchor)' of help id $helpId marks R.id.$vid, which is in no layout or menu of $id" })
                continue
            }
            # ICON-SET rule 8 (FILLER-0059): the help shows the control's own glyph beside its name, never another one,
            # and a control that draws a glyph has it shown in its help entry.
            $icons = [System.Collections.Generic.List[string]]::new()
            foreach ($f in $controlFiles) {
                $xml = [IO.File]::ReadAllText($f)
                $element = [regex]::Match($xml, "<[^<>]*android:id=`"@\+?id/$vid`"[^<>]*>")
                if (-not $element.Success) { continue }
                $icon = [regex]::Match($element.Value, '(?:app|android):icon="@drawable/(\w+)"')
                if ($icon.Success -and -not $icons.Contains($icon.Groups[1].Value)) { $icons.Add($icon.Groups[1].Value) }
            }
            if ($icons.Count -gt 0 -and $null -eq $e.Glyph) {
                Add-Finding 'layer' "entry '$($e.Anchor)' of help id $helpId names a control that draws R.drawable.$($icons -join '/'), and the entry shows no glyph beside the name"
            } elseif ($null -ne $e.Glyph -and $icons.Count -eq 0) {
                Add-Finding 'layer' "entry '$($e.Anchor)' of help id $helpId shows R.drawable.$($e.Glyph), and R.id.$vid draws no glyph"
            } elseif ($null -ne $e.Glyph -and ($icons.Count -ne 1 -or $icons[0] -ne $e.Glyph)) {
                Add-Finding 'layer' "entry '$($e.Anchor)' of help id $helpId shows R.drawable.$($e.Glyph), and R.id.$vid draws R.drawable.$($icons -join '/')"
            }
        }
    }
    foreach ($helpId in $content.Keys) {
        $viaInherit = $false
        foreach ($id in $rows.Keys) { if ($rows[$id]['form'] -eq 'layer' -and [string]$rows[$id]['help'] -eq $helpId) { $viaInherit = $true } }
        if (-not $viaInherit) { Add-Finding 'layer' "help id '$helpId' in HelpLayerContent.kt is named by no layer row" }
    }
    # an inherit row opens the anchor its own row names (CONTEXT-HELP items A and K, S0041): it must be an entry of the
    # help the row reaches; a chain that reaches no help or a page row already has its own finding above
    foreach ($id in $rows.Keys) {
        $r = $rows[$id]
        if ($r['form'] -ne 'inherit') { continue }
        $anchor = [string]$r['anchor']
        if ([string]::IsNullOrWhiteSpace($anchor)) { continue }
        $end = Resolve-Row $r
        if ($null -eq $end -or $end['form'] -ne 'layer') { continue }
        $helpId = [string]$end['help']
        if (-not $content.ContainsKey($helpId)) { continue }
        if (-not ($content[$helpId] | Where-Object { $_.Anchor -eq $anchor })) {
            Add-Finding 'layer' "inherit row $id has the anchor '$anchor', which is no entry of help id '$helpId' that its parent chain reaches"
        }
    }
    foreach ($sn in $needed.Keys) {
        $lacking = @()
        foreach ($loc in $locales) {
            if (-not $strings.ContainsKey($loc)) { continue }
            if (-not $strings[$loc].Contains($sn) -and -not ($loc -ne 'values' -and $notTranslatable.Contains($sn))) { $lacking += $loc }
        }
        if ($lacking.Count -gt 0) {
            Add-Finding 'layer' "string $sn (used by $($needed[$sn] -join ', ')) is missing from $($lacking -join ', ')"
        }
    }

    # ---- wiring -----------------------------------------------------------------------------------------------------------
    foreach ($id in $rows.Keys) {
        if (-not $activities.Contains($id)) { continue }
        $a = $activities[$id]
        if ($a.Module -ne 'phone') { continue }
        $r = $rows[$id]
        $need = $r['form'] -in 'layer', 'page', 'both' -or ($r['form'] -eq 'inherit' -and [string]$r['ask'] -ne 'off')
        if (-not $need -or $null -eq $a.File) { continue }
        $idOk = $a.Text -match ('HELP_SURFACE_ID\s*=\s*"' + [regex]::Escape($id) + '"')
        $callOk = $a.Text -match 'HelpOpenManager\.open\(\s*this\s*,\s*HELP_SURFACE_ID'
        if (-not $idOk -or -not $callOk) {
            Add-Finding 'wiring' "activity $id has form $($r['form']) but $(Get-Rel $a.File.FullName) does not call HelpOpenManager.open(this, HELP_SURFACE_ID) with HELP_SURFACE_ID = `"$id`" (rules 1 to 3, 17)"
        }
    }

    # ---- verdict ----------------------------------------------------------------------------------------------------------
    foreach ($id in $rows.Keys) {
        $source = @()
        if ($activities.Contains($id)) { $source += "activity($($activities[$id].Module))" }
        if ($siteIds.ContainsKey($id)) { $source += "site x$($siteIds[$id])" }
        Write-Output ('  {0,-30} {1,-8} {2}' -f $id, $rows[$id]['form'], ($(if ($source.Count) { $source -join ' + ' } else { '-' })))
    }
    if ($findings.Count -gt 0) {
        foreach ($f in $findings) { Write-Output "FAIL - $f" }
        Write-Output "help-map: FAIL ($($findings.Count) finding(s))"
        exit 1
    }
    Write-Output ("help-map: PASS ({0} row(s): {1} activity(ies), {2} dialog site(s); {3} layer entry(ies), {4} string(s) x {5} locale(s))" -f $rows.Count, $activities.Count, $siteCount, $entryCount, $needed.Count, $locales.Count)
    exit 0
} catch {
    Write-Output "COULD NOT VERIFY - internal error: $($_.Exception.Message) at line $($_.InvocationInfo.ScriptLineNumber)"
    Write-Output 'help-map: COULD NOT VERIFY (internal error)'
    exit 2
}
