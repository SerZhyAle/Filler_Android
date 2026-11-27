#requires -Version 7.0
<#
.SYNOPSIS
    Filler project launcher: one short command per build, check, queue runner or lock tool.

.DESCRIPTION
    `.\a.ps1 <command> [options]` runs the script the command names; everything after the command goes to that
    script unchanged, and an option you give wins over the command's preset of the same name. `.\a.ps1` alone
    lists the commands. The shape is the launcher of FastMediaSorter (a.ps1 there), cut to what Filler has.

    Builds    d   debug APKs of the phone and the watch app -> DOWNLOADS and C:\GD\WORK
              dp  the phone app only          wd  the watch app only
              r   release packages of HEAD, judged by the pre-flight (APKs also -> C:\GD\WORK)
    Checks    fg  every fast gate below in one run         fb  buildSrc tests (version stamp, signing)
              fsite ffacts fpos fdocs fdrift fhelp fstore floc fcomp fval fq  one gate each    fu  unit tests, all modules
    Runners   r0 r1 r2 r3  queue runners      rs  stop them      rm  monitor them      rw  portfolio dispatcher
    Locks     ub uc  clear a stale build / code lock      ul  drop stale ticket leases      uqb uqc  leave a queue
    Other     ss  the release queue          adb  adb of the Android SDK, e.g. `.\a.ps1 adb devices`

    Every APK a build command produces is copied to C:\GD\WORK (`-CopyTo <folder>` names another folder, `-CopyTo ''`
    turns the copy off).

    Tier (CLAUDE.md section 6): between releases an agent runs only checks of 5 seconds or less. In an agent shell
    (CLAUDECODE=1) a release-tier command (d dp wd r fu) is refused with exit 6 and nothing runs, unless the run is a
    dry one (-DryRun, -NoBuild) or the environment says FILLER_TIER=Release for a release run or one the owner named.
    The owner's own shell is the Release tier.

.EXAMPLE
    .\a.ps1 d
    .\a.ps1 dp -CopyTo ''
    .\a.ps1 d -DryRun
    .\a.ps1 fg
    .\a.ps1 r -WorkingTree -Keys temp\S0023\keys\keystore.properties

.NOTES
    Exit codes: the target's own, unchanged. The launcher adds 1 for an unknown command, a missing target or a failed
    `fg`, and 6 for a release-tier command asked for in an agent shell outside a release run. Run it as
    `pwsh -NoProfile -File a.ps1 <command>` from a shell that is not Bash.
#>
param(
    [string] $Command = ''
)

# Everything after <Command> goes to the target verbatim. The automatic $args is read on purpose: it keeps -flag
# tokens that a declared remaining-arguments parameter would reject.
$Rest = @($args)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'tools\release\_release.ps1')
$root = $script:RepoRoot

# --- the commands --------------------------------------------------------------------------------------------------
# Kind: script  a script of this repository, run as a child `pwsh -File`
#       harness a script of the canon harness, through tools/harness.ps1
#       plugin  a script of the installed sza plugin (outside the harness folder)
#       gradle  gradlew in this tree, under the Build.Main lock
#       adb     adb.exe of the Android SDK
# Args is the preset (a hashtable: a $true switch, or a value); Tier is 'release' for what takes longer than 5 s
# (CLAUDE.md section 6: a command with no recorded time of 5 s or less counts as release); FastFlags are the options
# that make the call a dry one; Gate marks the members of `fg`; Isolate marks what reaches Gradle, run with its
# output in files so a daemon never holds the caller's pipe.
$commands = [ordered]@{
    'd'     = @{ Group = 'Builds'; Kind = 'script'; Path = 'tools\builders\build-debug.ps1'; Args = @{}; Tier = 'release'; Isolate = $true; FastFlags = @('-DryRun', '-NoBuild'); Help = 'Debug APKs of the phone and the watch app -> DOWNLOADS and C:\GD\WORK' }
    'dp'    = @{ Group = 'Builds'; Kind = 'script'; Path = 'tools\builders\build-debug.ps1'; Args = @{ Module = 'phone' }; Tier = 'release'; Isolate = $true; FastFlags = @('-DryRun', '-NoBuild'); Help = 'Debug APK of the phone app only' }
    'wd'    = @{ Group = 'Builds'; Kind = 'script'; Path = 'tools\builders\build-debug.ps1'; Args = @{ Module = 'wear' }; Tier = 'release'; Isolate = $true; FastFlags = @('-DryRun', '-NoBuild'); Help = 'Debug APK of the watch app only' }
    'r'     = @{ Group = 'Builds'; Kind = 'script'; Path = 'tools\release\preflight.ps1'; Args = @{}; Tier = 'release'; Isolate = $true; Help = 'Release packages of HEAD, judged by the pre-flight; APKs -> C:\GD\WORK (-WorkingTree for a dry run, -Keys <file>)' }

    'fg'    = @{ Group = 'Checks'; Kind = 'batch'; Help = 'Every fast gate below in one run, with a summary' }
    'fb'    = @{ Group = 'Checks'; Kind = 'gradle'; Args = @('-p', 'buildSrc', 'test'); Tier = 'fast'; Help = 'buildSrc tests: the version stamp and the signing vectors (fast on a warm daemon, 29.9 s cold)' }
    'fsite' = @{ Group = 'Checks'; Kind = 'script'; Path = 'tools\site\check-site.ps1'; Args = @{}; Gate = $true; Help = 'Site gate: pages, SEO, languages, held addresses' }
    'ffacts' = @{ Group = 'Checks'; Kind = 'script'; Path = 'tools\site\check-site-facts.ps1'; Args = @{}; Gate = $true; Help = 'Facts gate: permissions, locales, page count, application id' }
    'fpos'  = @{ Group = 'Checks'; Kind = 'script'; Path = 'tools\site\check-positioning.ps1'; Args = @{}; Gate = $true; Help = 'Positioning gate: the order of the five pillars on seven surfaces' }
    'fdocs' = @{ Group = 'Checks'; Kind = 'script'; Path = 'tools\docs\check-docs.ps1'; Args = @{}; Gate = $true; Help = 'Documents gate: registry, links, style' }
    'fdrift' = @{ Group = 'Checks'; Kind = 'script'; Path = 'tools\port-ledger\check-drift.ps1'; Args = @{}; Gate = $true; Help = 'Port ledger drift check against the FastMediaSorter checkout' }
    'fhelp' = @{ Group = 'Checks'; Kind = 'script'; Path = 'tools\help\check-help-map.ps1'; Args = @{}; Gate = $true; Help = 'Help map gate: surfaces, dialogs, layer entries, locales' }
    'fstore' = @{ Group = 'Checks'; Kind = 'script'; Path = 'tools\store\check-store-assets.ps1'; Args = @{}; Gate = $true; Help = 'Store assets gate: the committed graphics equal their render' }
    'floc'  = @{ Group = 'Checks'; Kind = 'script'; Path = 'tools\locale\check-locales.ps1'; Args = @{}; Gate = $true; Help = 'Language gate: app strings, per-app languages, links, translated documents' }
    'fcomp' = @{ Group = 'Checks'; Kind = 'plugin'; Path = 'tools\check-compliance.ps1'; Args = @{ RepoRoot = $root; IncludeUntracked = $true }; Gate = $true; Help = 'Canon compliance gate of the installed sza plugin' }
    'fval'  = @{ Group = 'Checks'; Kind = 'harness'; Path = 'spec_catalog/validate'; Args = @{}; Gate = $true; Help = 'Ticket journal validation' }
    'fq'    = @{ Group = 'Checks'; Kind = 'harness'; Path = 'spec_catalog/release-queue'; Args = @{ Validate = $true }; Gate = $true; Help = 'Release plan validation' }
    'fu'    = @{ Group = 'Checks'; Kind = 'gradle'; Args = @(':filler-core:testDebugUnitTest', ':phone:testDebugUnitTest', ':wear:testDebugUnitTest'); Tier = 'release'; Help = 'Unit tests of filler-core, the phone and the watch app' }

    'r0'    = @{ Group = 'Runners'; Kind = 'script'; Path = 'r0.ps1'; Args = @{}; Help = 'Single-agent queue runner, one fresh process per ticket' }
    'r1'    = @{ Group = 'Runners'; Kind = 'script'; Path = 'r1.ps1'; Args = @{}; Help = 'Queue runner, instance A' }
    'r2'    = @{ Group = 'Runners'; Kind = 'script'; Path = 'r2.ps1'; Args = @{}; Help = 'Queue runner, instance B (staggered)' }
    'r3'    = @{ Group = 'Runners'; Kind = 'script'; Path = 'r3.ps1'; Args = @{}; Help = 'Queue runner, instance C (staggered further)' }
    'rs'    = @{ Group = 'Runners'; Kind = 'script'; Path = 'rs.ps1'; Args = @{}; Help = 'Stop the runners after their ticket (-Kill to end the children)' }
    'rm'    = @{ Group = 'Runners'; Kind = 'script'; Path = 'rm.ps1'; Args = @{}; Help = 'Monitor the runners (-Watch to refresh, -Json)' }
    'rw'    = @{ Group = 'Runners'; Kind = 'script'; Path = 'rw.ps1'; Args = @{}; Help = 'Portfolio dispatcher scoped to this repository' }

    'ub'    = @{ Group = 'Locks'; Kind = 'harness'; Path = 'locks/clear-agent-lock'; Args = @{ Name = 'Build' }; Help = 'Clear a stale or dead build lock (a live holder is refused; -Force once it is gone)' }
    'uc'    = @{ Group = 'Locks'; Kind = 'harness'; Path = 'locks/clear-agent-lock'; Args = @{ Name = 'Code' }; Help = 'Clear a stale or dead code lock, every code domain (-Force)' }
    'ul'    = @{ Group = 'Locks'; Kind = 'harness'; Path = 'locks/ticket-lease'; Args = @{ Verb = 'Clean' }; Help = 'Drop the ticket leases a killed flow left behind' }
    'uqb'   = @{ Group = 'Locks'; Kind = 'harness'; Path = 'locks/withdraw-lock-ticket'; Args = @{ Name = 'Build' }; Help = "Withdraw this session's place in the build queue (the lock is untouched)" }
    'uqc'   = @{ Group = 'Locks'; Kind = 'harness'; Path = 'locks/withdraw-lock-ticket'; Args = @{ Name = 'Code' }; Help = "Withdraw this session's place in the code queue (the lock is untouched)" }

    'ss'    = @{ Group = 'Other'; Kind = 'harness'; Path = 'spec_catalog/release-queue'; Args = @{ List = $true }; Help = 'The release queue: what is left to do' }
    'adb'   = @{ Group = 'Other'; Kind = 'adb'; Help = 'adb of the Android SDK: .\a.ps1 adb devices' }
}

function Show-Commands([string] $Unknown) {
    if ($Unknown) { Write-Host "Unknown command: $Unknown" -ForegroundColor Red; Write-Host '' }
    Write-Host 'Filler launcher: .\a.ps1 <command> [options]' -ForegroundColor Yellow
    $group = ''
    foreach ($name in $commands.Keys) {
        $entry = $commands[$name]
        if ($entry.Group -ne $group) { $group = $entry.Group; Write-Host ''; Write-Host "$group" -ForegroundColor Yellow }
        $mark = if ($entry.ContainsKey('Tier') -and $entry.Tier -eq 'release') { '*' } else { ' ' }
        Write-Host ('  {0,-7}{1} {2}' -f $name, $mark, $entry.Help) -ForegroundColor Cyan
    }
    Write-Host ''
    Write-Host '  * release tier: refused in an agent shell unless FILLER_TIER=Release or the call is a dry one (see the header).' -ForegroundColor DarkGray
    Write-Host '  APKs are copied to C:\GD\WORK; -CopyTo <folder> changes it, -CopyTo '''' turns it off.' -ForegroundColor DarkGray
}

if ([string]::IsNullOrWhiteSpace($Command) -or $Command -in @('help', '?', '-?')) { Show-Commands ''; exit 0 }
$Command = $Command.Trim().ToLowerInvariant()
if (-not $commands.Contains($Command)) { Show-Commands $Command; exit 1 }
$entry = $commands[$Command]

# --- tier ----------------------------------------------------------------------------------------------------------
function Get-ActiveTier {
    # The caller's explicit word, then the agent shell, then the owner's shell (Release).
    if ($env:FILLER_TIER -ieq 'Fast') { return 'Fast' }
    if ($env:FILLER_TIER -ieq 'Release') { return 'Release' }
    if ($env:CLAUDECODE -eq '1') { return 'Fast' }
    return 'Release'
}

$isDry = $entry.ContainsKey('FastFlags') -and (@($Rest | Where-Object { $_ -in $entry.FastFlags }).Count -gt 0)
if ((Get-ActiveTier) -eq 'Fast' -and $entry.ContainsKey('Tier') -and $entry.Tier -eq 'release' -and -not $isDry) {
    Write-Host "a.ps1: '$Command' is a release-tier command (no recorded time of 5 s or less) and does not run between releases." -ForegroundColor Yellow
    Write-Host '  A fast check of what changed:  .\a.ps1 fg' -ForegroundColor Yellow
    Write-Host "  A release run, or one the owner named:  `$env:FILLER_TIER='Release'; .\a.ps1 $Command .." -ForegroundColor Yellow
    Write-Host '  Report it as: not built, not tested until the release.' -ForegroundColor Yellow
    exit 6
}

# --- running a target ----------------------------------------------------------------------------------------------
function ConvertTo-ArgumentTokens($Preset, [object[]] $Extra) {
    # The preset hashtable as tokens (a $true switch is the bare flag); a flag the caller also gives replaces the
    # preset's, so PowerShell never sees the name twice.
    $given = @($Extra | ForEach-Object { if ("$_" -match '^-([A-Za-z_]\w*)') { $Matches[1] } })
    $tokens = @()
    if ($Preset -is [hashtable]) {
        foreach ($key in $Preset.Keys) {
            if (@($given | Where-Object { $key.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }).Count) { continue }
            $value = $Preset[$key]
            if ($value -is [bool]) { if ($value) { $tokens += "-$key" } } else { $tokens += "-$key"; $tokens += "$value" }
        }
    }
    return @($tokens + @($Extra | ForEach-Object { "$_" }))
}

function Get-PluginRoot {
    $roots = @()
    if ($env:SZA_HARNESS_ROOT) { $roots += (Split-Path (Split-Path $env:SZA_HARNESS_ROOT -Parent) -Parent) }
    $cache = Join-Path ($env:USERPROFILE ?? $env:HOME) '.claude/plugins/cache/sza-unified-rules/sza'
    if (Test-Path -LiteralPath $cache) {
        $roots += @(Get-ChildItem -LiteralPath $cache -Directory | Where-Object { $_.Name -as [version] } |
                Sort-Object { [version]$_.Name } -Descending | ForEach-Object FullName)
    }
    return $roots | Select-Object -First 1
}

function Invoke-Child([string[]] $ChildArgs, [bool] $Isolate) {
    # A Gradle daemon born under an agent's tool call inherits that call's stdout handle and outlives the build, so
    # the call never sees end of file. A child whose streams are files leaves the daemon no pipe to inherit; the
    # output is printed when the child ends. FILLER_ISOLATE_STDOUT=1 forces it on, 0 off.
    $useFiles = if ($env:FILLER_ISOLATE_STDOUT -eq '1') { $true } elseif ($env:FILLER_ISOLATE_STDOUT -eq '0') { $false } else { $Isolate -and [Console]::IsOutputRedirected }
    if (-not $useFiles) {
        & pwsh @ChildArgs | Out-Host
        return [int]$LASTEXITCODE
    }
    $dir = Join-Path ([IO.Path]::GetTempPath()) "filler-a-$PID-$([guid]::NewGuid().ToString('N').Substring(0, 6))"
    New-Item -ItemType Directory -Path $dir | Out-Null
    try {
        $out = Join-Path $dir 'out.txt'; $err = Join-Path $dir 'err.txt'
        $quoted = @($ChildArgs | ForEach-Object { if ($_ -eq '' -or $_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } })
        $process = Start-Process pwsh -ArgumentList $quoted -NoNewWindow -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
        Get-Content -LiteralPath $out | Out-Host
        Get-Content -LiteralPath $err | ForEach-Object { Write-Host $_ -ForegroundColor DarkYellow }
        return [int]$process.ExitCode
    } finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
}

function Invoke-Entry([string] $Name, [hashtable] $Item, [object[]] $Extra) {
    $isolate = $Item.ContainsKey('Isolate') -and $Item.Isolate
    switch ($Item.Kind) {
        'adb' { & (Get-Adb) @Extra | Out-Host; return [int]$LASTEXITCODE }
        'gradle' {
            $null = Enter-LocalBuildLock "a.ps1 ${Name}: gradle"
            Push-Location $root
            try { & (Join-Path $root 'gradlew.bat') @($Item.Args + @($Extra)) '--console=plain' | Out-Host; return [int]$LASTEXITCODE } finally { Pop-Location }
        }
        default {
            $base = switch ($Item.Kind) {
                'script' { $root }
                'harness' { Join-Path $root 'tools' }
                'plugin' { Get-PluginRoot }
            }
            if (-not $base) { Write-Host "a.ps1: '$Name' needs the sza plugin, which is not installed here." -ForegroundColor Red; return 2 }
            $target = if ($Item.Kind -eq 'harness') { Join-Path $base 'harness.ps1' } else { Join-Path $base $Item.Path }
            if (-not (Test-Path -LiteralPath $target)) { Write-Host "a.ps1: script not found: $target" -ForegroundColor Red; return 1 }
            # The harness forwarder takes the harness-relative script path as its first argument.
            $childArgs = @('-NoProfile', '-File', $target)
            if ($Item.Kind -eq 'harness') { $childArgs += $Item.Path }
            $childArgs += @(ConvertTo-ArgumentTokens $Item.Args $Extra)
            return (Invoke-Child $childArgs $isolate)
        }
    }
}

# --- fg: the fast gates in one run ---------------------------------------------------------------------------------
if ($entry.Kind -eq 'batch') {
    $rows = @()
    foreach ($name in $commands.Keys) {
        $item = $commands[$name]
        if (-not ($item.ContainsKey('Gate') -and $item.Gate)) { continue }
        Write-Host "--- $name" -ForegroundColor DarkGray
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $code = [int](@(Invoke-Entry $name $item @()))[-1]
        $rows += [pscustomobject]@{ Gate = $name; Exit = $code; Seconds = [math]::Round($clock.Elapsed.TotalSeconds, 1) }
    }
    Write-Host ''
    $rows | Format-Table -AutoSize | Out-Host
    $bad = @($rows | Where-Object Exit -ne 0)
    Write-Host $(if ($bad.Count) { "fg: $($bad.Count) of $($rows.Count) gates not green: $(($bad | ForEach-Object Gate) -join ', ')" } else { "fg: $($rows.Count) gates green" })
    exit $(if ($bad.Count) { 1 } else { 0 })
}

$exitCode = [int](@(Invoke-Entry $Command $entry $Rest))[-1]
exit $exitCode
