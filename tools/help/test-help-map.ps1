#requires -Version 7.0
<#
.SYNOPSIS
    Tests of the help-map gate (S0034): the pass case, one failing case per finding class and the could-not-verify paths,
    each on a throw-away copy of the tree, judged by the gate's exit code, its reason lines and its verdict line.
.DESCRIPTION
    The copy holds only what the gate reads (manifests, Kotlin sources, the help map, layouts, menus and strings), so a case
    mutates the copy and never the repository. Every case runs the real tools/help/check-help-map.ps1 in its own process.
    -Filter keeps the cases whose name contains the text (a case-insensitive substring), to run in chunks.
.NOTES
    Exit codes: 0 every case passed, 1 a case failed. The last line is `help-map-test: PASS (n case(s))` or
    `help-map-test: FAIL (n of m case(s))`.
#>
[CmdletBinding()]
param(
    [string]$Filter = ''
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$gate = Join-Path $PSScriptRoot 'check-help-map.ps1'
$work = Join-Path ([IO.Path]::GetTempPath()) ('help-map-test-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$pristine = Join-Path $work 'pristine'

function Copy-Subset([string]$From, [string]$To) {
    foreach ($rel in 'phone/src/main/AndroidManifest.xml', 'phone/src/main/assets', 'phone/src/main/java',
        'wear/src/main/AndroidManifest.xml', 'wear/src/main/java') {
        $dst = Join-Path $To $rel
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
        Copy-Item -LiteralPath (Join-Path $From $rel) -Destination $dst -Recurse -Force
    }
    foreach ($m in 'phone', 'wear') {
        foreach ($dir in Get-ChildItem -LiteralPath (Join-Path $From "$m/src/main/res") -Directory | Where-Object { $_.Name -match '^(layout|menu|values)' }) {
            $dst = Join-Path $To "$m/src/main/res/$($dir.Name)"
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
            Copy-Item -LiteralPath $dir.FullName -Destination $dst -Recurse -Force
        }
    }
}
function Edit-Text([string]$Tree, [string]$Rel, [string]$Pattern, [string]$Replacement) {
    $path = Join-Path $Tree $Rel
    $old = [IO.File]::ReadAllText($path)
    $new = [regex]::Replace($old, $Pattern, $Replacement)
    if ($new -ceq $old) { throw "mutation changed nothing in $Rel ($Pattern)" }
    [IO.File]::WriteAllText($path, $new, [System.Text.UTF8Encoding]::new($false))
}
function Edit-Map([string]$Tree, [scriptblock]$Change) {
    $path = Join-Path $Tree 'phone/src/main/assets/help/help-map.json'
    $map = [IO.File]::ReadAllText($path) | ConvertFrom-Json -AsHashtable -Depth 10
    & $Change $map
    [IO.File]::WriteAllText($path, ($map | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
}
function Get-Row($Map, [string]$Id) { return $Map['surfaces'] | Where-Object { $_['id'] -eq $Id } | Select-Object -First 1 }

$passLine = '^help-map: PASS \('
$failLine = '^help-map: FAIL \(\d+ finding\(s\)\)$'
$unverifiedLine = '^help-map: COULD NOT VERIFY \('
$sched = 'phone/src/main/java/com/sza/filler/ui/schedule/ScheduleActivity.kt'
$other = 'phone/src/main/java/com/sza/filler/data/filler/AppFillerStorage.kt'
$res = 'phone/src/main/res'

$cases = @(
    @{ Name = 'pass: the tree as it is'; Exit = 0; Verdict = $passLine; Expect = @('WearMainActivity +inherit +activity\(wear\)'); Mutate = { param($t) } }
    @{ Name = 'surface: activity with no row'; Exit = 1; Verdict = $failLine
       Expect = @('activity ScheduleActivity \(phone manifest\) has no row'); Mutate = { param($t) Edit-Map $t { param($m) $m['surfaces'] = @($m['surfaces'] | Where-Object { $_['id'] -ne 'ScheduleActivity' }) } } }
    @{ Name = 'surface: row with no surface'; Exit = 1; Verdict = $failLine
       Expect = @('row GhostDialog has no surface'); Mutate = { param($t) Edit-Map $t { param($m) $m['surfaces'] += @{ id = 'GhostDialog'; name = 'Ghost'; form = 'none'; reason = 'x' } } } }
    @{ Name = 'surface: dialog site with no marker'; Exit = 1; Verdict = $failLine
       Expect = @('dialog site phone/src/main/java/.*ScheduleActivity\.kt:\d+ has no', 'row ScheduleDeleteDialog has no surface')
       Mutate = { param($t) Edit-Text $t $sched '(?m)^\s*// help-surface: ScheduleDeleteDialog\r?\n' '' } }
    @{ Name = 'surface: watch dialog site with no marker'; Exit = 1; Verdict = $failLine
       Expect = @('dialog site wear/src/main/java/.*MainActivity\.kt:\d+ has no')
       Mutate = { param($t) Edit-Text $t 'wear/src/main/java/com/sza/filler/wear/MainActivity.kt' '(?m)^\s*// help-surface: SystemNotificationPermission\r?\n' '' } }
    @{ Name = 'surface: marker naming no row'; Exit = 1; Verdict = $failLine
       Expect = @("marker 'NoSuchRow' names no row", 'row ScheduleRepeatDialog has no surface')
       Mutate = { param($t) Edit-Text $t $sched 'help-surface: ScheduleRepeatDialog' 'help-surface: NoSuchRow' } }
    @{ Name = 'surface: marker on no site'; Exit = 1; Verdict = $failLine
       Expect = @("marker 'SystemTimePicker' at phone/src/main/java/.*AppFillerStorage\.kt:1 sits on no dialog site")
       Mutate = { param($t) $p = Join-Path $t $other; [IO.File]::WriteAllText($p, "// help-surface: SystemTimePicker`n" + [IO.File]::ReadAllText($p)) } }
    @{ Name = 'surface: layout inflated by no activity'; Exit = 1; Verdict = $failLine
       Expect = @('activity_ghost\.xml is inflated by no manifest activity')
       Mutate = { param($t) Set-Content -LiteralPath (Join-Path $t "$res/layout/activity_ghost.xml") -Value '<LinearLayout />' } }
    @{ Name = 'surface: launcher activity with form none'; Exit = 1; Verdict = $failLine
       Expect = @('launcher activity FillerActivity has form none')
       Mutate = { param($t) Edit-Map $t { param($m) $r = Get-Row $m 'FillerActivity'; $r['form'] = 'none'; $r['reason'] = 'x' } } }
    @{ Name = 'map: none row without a reason'; Exit = 1; Verdict = $failLine
       Expect = @('row SystemTimePicker is none without a reason'); Mutate = { param($t) Edit-Map $t { param($m) (Get-Row $m 'SystemTimePicker')['reason'] = '' } } }
    @{ Name = 'map: inherit row without a reason'; Exit = 1; Verdict = $failLine
       Expect = @('row WearMainActivity is inherit without a reason'); Mutate = { param($t) Edit-Map $t { param($m) (Get-Row $m 'WearMainActivity').Remove('reason') } } }
    @{ Name = 'map: inherit chain ends in none'; Exit = 1; Verdict = $failLine
       Expect = @('inherit row WearMainActivity reaches no help'); Mutate = { param($t) Edit-Map $t { param($m) (Get-Row $m 'WearMainActivity')['parent'] = 'SystemTimePicker' } } }
    @{ Name = 'map: inherit row without a parent'; Exit = 1; Verdict = $failLine
       Expect = @('inherit row WearMainActivity names no parent'); Mutate = { param($t) Edit-Map $t { param($m) (Get-Row $m 'WearMainActivity').Remove('parent') } } }
    @{ Name = 'map: page form'; Exit = 1; Verdict = $failLine
       Expect = @('row FillerConfirmDialog has form page'); Mutate = { param($t) Edit-Map $t { param($m) (Get-Row $m 'FillerConfirmDialog')['form'] = 'page' } } }
    @{ Name = 'map: duplicate id'; Exit = 1; Verdict = $failLine
       Expect = @('row id SystemTimePicker appears twice'); Mutate = { param($t) Edit-Map $t { param($m) $m['surfaces'] += @{ id = 'SystemTimePicker'; name = 'Time'; form = 'none'; reason = 'x' } } } }
    @{ Name = 'map: unknown form'; Exit = 1; Verdict = $failLine
       Expect = @("row SystemTimePicker has form 'popup'"); Mutate = { param($t) Edit-Map $t { param($m) (Get-Row $m 'SystemTimePicker')['form'] = 'popup' } } }
    @{ Name = 'map: missing schemaVersion'; Exit = 1; Verdict = $failLine
       Expect = @('schemaVersion is missing'); Mutate = { param($t) Edit-Map $t { param($m) $m.Remove('schemaVersion') } } }
    @{ Name = 'map: row without a name'; Exit = 1; Verdict = $failLine
       Expect = @('row SystemTimePicker has no name'); Mutate = { param($t) Edit-Map $t { param($m) (Get-Row $m 'SystemTimePicker').Remove('name') } } }
    @{ Name = 'map: two activities, one surface id'; Exit = 1; Verdict = $failLine
       Expect = @('two manifest activities give the surface id FillerActivity')
       Mutate = { param($t) Edit-Text $t 'phone/src/main/AndroidManifest.xml' 'android:name="\.ui\.schedule\.ScheduleActivity"' 'android:name=".ui.other.FillerActivity"' } }
    @{ Name = 'layer: row without a help id'; Exit = 1; Verdict = $failLine
       Expect = @('layer row FillerActivity has no help id'); Mutate = { param($t) Edit-Map $t { param($m) (Get-Row $m 'FillerActivity').Remove('help') } } }
    @{ Name = 'layer: help id with no entries'; Exit = 1; Verdict = $failLine
       Expect = @("layer row FillerActivity names help id 'nope' with no entries"); Mutate = { param($t) Edit-Map $t { param($m) (Get-Row $m 'FillerActivity')['help'] = 'nope' } } }
    @{ Name = 'layer: duplicate anchor'; Exit = 1; Verdict = $failLine
       Expect = @("help id filler has the anchor 'place' twice")
       Mutate = { param($t) Edit-Text $t 'phone/src/main/java/com/sza/filler/ui/help/HelpLayerContent.kt' '"choose-folder"' '"place"' } }
    @{ Name = 'layer: entry the gate cannot read'; Exit = 1; Verdict = $failLine
       Expect = @('list filler declares 12 entries and the gate reads 11')
       Mutate = { param($t) Edit-Text $t 'phone/src/main/java/com/sza/filler/ui/help/HelpLayerContent.kt' 'R\.id\.btnFillerStart,' '0,' } }
    @{ Name = 'layer: branch naming no constant'; Exit = 1; Verdict = $failLine
       Expect = @('entries\(\) branch SCHEDULEX -> schedule names no help id constant', 'entry list schedule is reached by no entries\(\) branch')
       Mutate = { param($t) Edit-Text $t 'phone/src/main/java/com/sza/filler/ui/help/HelpLayerContent.kt' 'SCHEDULE -> schedule' 'SCHEDULEX -> schedule' } }
    @{ Name = 'layer: translatable false is exempt'; Exit = 0; Verdict = $passLine; Expect = @()
       Mutate = { param($t)
           Edit-Text $t "$res/values/strings_filler.xml" '<string name="filler_help_start_text">' '<string name="filler_help_start_text" translatable="false">'
           Edit-Text $t "$res/values-de/strings_filler.xml" '(?s)\s*<string name="filler_help_start_text">.*?</string>' '' } }
    @{ Name = 'layer: view id missing in landscape'; Exit = 1; Verdict = $failLine
       Expect = @("entry 'start' of help id filler marks R\.id\.btnFillerStart, which is missing from phone/src/main/res/layout-land/activity_filler\.xml")
       Mutate = { param($t) Edit-Text $t "$res/layout-land/activity_filler.xml" '@\+id/btnFillerStart"' '@+id/btnFillerStartX"' } }
    @{ Name = 'layer: view id missing everywhere'; Exit = 1; Verdict = $failLine
       Expect = @("entry 'add' of help id schedule marks R\.id\.btnScheduleAdd, which is in no layout or menu of ScheduleActivity")
       Mutate = { param($t) Edit-Text $t "$res/layout/activity_schedule.xml" '@\+id/btnScheduleAdd"' '@+id/btnScheduleAddX"' } }
    @{ Name = 'layer: menu id missing'; Exit = 1; Verdict = $failLine
       Expect = @('R\.id\.action_help, which is in no layout or menu of FillerActivity')
       Mutate = { param($t) Edit-Text $t "$res/menu/menu_filler_help.xml" '@\+id/action_help"' '@+id/action_helpx"' } }
    @{ Name = 'layer: string missing in one locale'; Exit = 1; Verdict = $failLine
       Expect = @('string filler_help_start_text \(used by filler/start\) is missing from values-de$')
       Mutate = { param($t) Edit-Text $t "$res/values-de/strings_filler.xml" '(?s)\s*<string name="filler_help_start_text">.*?</string>' '' } }
    @{ Name = 'layer: string missing in the default locale'; Exit = 1; Verdict = $failLine
       Expect = @('string schedule_help_add_text \(used by schedule/add\) is missing from values$')
       Mutate = { param($t) Edit-Text $t "$res/values/strings_schedule.xml" '(?s)\s*<string name="schedule_help_add_text">.*?</string>' '' } }
    @{ Name = 'layer: locale folder missing'; Exit = 1; Verdict = $failLine
       Expect = @('locale folder phone/src/main/res/values-ur is missing')
       Mutate = { param($t) Remove-Item -LiteralPath (Join-Path $t "$res/values-ur") -Recurse -Force } }
    @{ Name = 'layer: locale folder not declared'; Exit = 1; Verdict = $failLine
       Expect = @('folder values-nl carries strings but is not one of the 13 locales')
       Mutate = { param($t) Copy-Item -LiteralPath (Join-Path $t "$res/values-de") -Destination (Join-Path $t "$res/values-nl") -Recurse } }
    @{ Name = 'layer: row anchor is no entry'; Exit = 1; Verdict = $failLine
       Expect = @("layer row FillerActivity has the anchor 'nowhere'")
       Mutate = { param($t) Edit-Map $t { param($m) (Get-Row $m 'FillerActivity')['anchor'] = 'nowhere' } } }
    @{ Name = 'layer: inherit row anchor is no entry'; Exit = 1; Verdict = $failLine
       Expect = @("inherit row WearMainActivity has the anchor 'nowhere', which is no entry of help id 'filler'")
       Mutate = { param($t) Edit-Map $t { param($m) (Get-Row $m 'WearMainActivity')['anchor'] = 'nowhere' } } }
    @{ Name = 'layer: inherit row anchor is an entry'; Exit = 0; Verdict = $passLine
       Expect = @('WearMainActivity +inherit +activity\(wear\)')
       Mutate = { param($t) Edit-Map $t { param($m) (Get-Row $m 'WearMainActivity')['anchor'] = 'place' } } }
    @{ Name = 'layer: help id with no row'; Exit = 1; Verdict = $failLine
       Expect = @("help id 'schedule' in HelpLayerContent.kt is named by no layer row", 'activity ScheduleActivity.*has no row')
       Mutate = { param($t) Edit-Map $t { param($m) $m['surfaces'] = @($m['surfaces'] | Where-Object { $_['id'] -ne 'ScheduleActivity' }) } } }
    @{ Name = 'wiring: activity does not wire its row id'; Exit = 1; Verdict = $failLine
       Expect = @('activity ScheduleActivity has form layer but .*ScheduleActivity\.kt does not call HelpOpenManager\.open')
       Mutate = { param($t) Edit-Text $t $sched 'HELP_SURFACE_ID = "ScheduleActivity"' 'HELP_SURFACE_ID = "ScheduleActivityX"' } }
    @{ Name = 'wiring: window builds a layer itself'; Exit = 1; Verdict = $failLine
       Expect = @('AppFillerStorage\.kt:\d+ builds a HelpLayer itself')
       Mutate = { param($t) $p = Join-Path $t $other; [IO.File]::AppendAllText($p, "`nval stray = HelpLayer(null, emptyList(), null)`n") } }
    @{ Name = 'verdict: every finding is reported, not the first'; Exit = 1; Verdict = $failLine
       Expect = @('row GhostDialog has no surface', 'row SystemTimePicker is none without a reason', 'string filler_help_start_text .* is missing from values-de', 'help-map: FAIL \([3-9]\d* finding')
       Mutate = { param($t)
           Edit-Map $t { param($m) $m['surfaces'] += @{ id = 'GhostDialog'; name = 'Ghost'; form = 'none'; reason = 'x' }; (Get-Row $m 'SystemTimePicker')['reason'] = '' }
           Edit-Text $t "$res/values-de/strings_filler.xml" '(?s)\s*<string name="filler_help_start_text">.*?</string>' '' } }
    @{ Name = 'unverified: the map is missing'; Exit = 2; Verdict = $unverifiedLine
       Expect = @('COULD NOT VERIFY - missing input phone/src/main/assets/help/help-map\.json', 'help-map: COULD NOT VERIFY \(1 missing input\(s\)\)')
       Mutate = { param($t) Remove-Item -LiteralPath (Join-Path $t 'phone/src/main/assets/help/help-map.json') } }
    @{ Name = 'unverified: the map is not JSON'; Exit = 2; Verdict = $unverifiedLine
       Expect = @('COULD NOT VERIFY - unreadable phone/src/main/assets/help/help-map\.json')
       Mutate = { param($t) Set-Content -LiteralPath (Join-Path $t 'phone/src/main/assets/help/help-map.json') -Value '{ not json' } }
    @{ Name = 'unverified: a manifest is missing'; Exit = 2; Verdict = $unverifiedLine
       Expect = @('COULD NOT VERIFY - missing input wear/src/main/AndroidManifest\.xml')
       Mutate = { param($t) Remove-Item -LiteralPath (Join-Path $t 'wear/src/main/AndroidManifest.xml') } }
)

$selected = @($cases | Where-Object { $_.Name -like "*$Filter*" })
if ($selected.Count -eq 0) { Write-Output "help-map-test: COULD NOT VERIFY (no case matches '$Filter')"; exit 2 }
$failed = 0
try {
    New-Item -ItemType Directory -Force -Path $pristine | Out-Null
    Copy-Subset $repo $pristine
    $n = 0
    foreach ($case in $selected) {
        $n++
        $tree = Join-Path $work ('case{0:D2}' -f $n)
        Copy-Item -LiteralPath $pristine -Destination $tree -Recurse
        $problems = @()
        try {
            & $case.Mutate $tree
            $out = @(& pwsh -NoProfile -File $gate -Root $tree 2>&1 | ForEach-Object { "$_" })
            $code = $LASTEXITCODE
            if ($code -ne $case.Exit) { $problems += "exit expected $($case.Exit) actual $code" }
            if ($out.Count -eq 0 -or $out[-1] -notmatch $case.Verdict) { $problems += "last line expected /$($case.Verdict)/ actual '$($out[-1])'" }
            foreach ($rx in $case.Expect) {
                if (-not ($out | Where-Object { $_ -match $rx })) { $problems += "no output line matches /$rx/" }
            }
        } catch {
            $problems += "case threw: $($_.Exception.Message)"
        }
        if ($problems.Count -gt 0) {
            $failed++
            Write-Output "FAIL - $($case.Name)"
            foreach ($p in $problems) { Write-Output "    $p" }
            if ($out) { $out | ForEach-Object { Write-Output "    | $_" } }
        } else {
            Write-Output "PASS - $($case.Name)"
        }
    }
} finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
if ($failed -gt 0) { Write-Output "help-map-test: FAIL ($failed of $($selected.Count) case(s))"; exit 1 }
Write-Output "help-map-test: PASS ($($selected.Count) case(s))"
exit 0
