<#
.SYNOPSIS
    Builds the debug APKs of the local working tree (the phone app, the watch app, or both), collects them in
    DOWNLOADS and copies them to the synced work folder. Run as `.\a.ps1 d`, `dp` or `wd`.

.DESCRIPTION
    One Gradle invocation, so both modules are stamped from the same clock reading and carry the same versionName
    (PACKAGE-VERSIONING rule 6). Gradle runs under the harness's Build.Main lock, queued behind any other build of
    this tree. A debug build needs no version pin and no key; a release package is the pre-flight's job
    (tools/release/preflight.ps1, `.\a.ps1 r`), which copies its release APKs to the same folder.

    Each APK is named filler-<phone|wear>-debug-<versionName>.apk, kept in DOWNLOADS (the gitignored hand-off
    folder of REPOSITORY_LAYOUT) and copied to -CopyTo (default C:\GD\WORK, the Google Drive mirror). -CopyTo ''
    turns the copy off; a folder that does not exist is a warning, never an error and never created.

.PARAMETER Module
    all (default), phone or wear.

.PARAMETER NoBuild
    Skip Gradle and collect the APKs the last build left in phone/build and wear/build.

.PARAMETER DryRun
    Print the Gradle command and the copy plan; build nothing, copy nothing.

.EXAMPLE
    pwsh -NoProfile -File tools/builders/build-debug.ps1
    pwsh -NoProfile -File tools/builders/build-debug.ps1 -Module phone
    pwsh -NoProfile -File tools/builders/build-debug.ps1 -NoBuild -CopyTo temp\apk-copy
    pwsh -NoProfile -File tools/builders/build-debug.ps1 -DryRun

.NOTES
    A full build is release tier (CLAUDE.md section 6): run it when a package is wanted, not between releases.
    Exit codes: 0 done, 1 the build or the copy failed.
#>
[CmdletBinding()]
param(
    [ValidateSet('all', 'phone', 'wear')][string] $Module = 'all',
    [switch] $NoBuild,
    [switch] $DryRun,
    [string] $CopyTo
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\release\_release.ps1')

# Not bound: the default work folder. Bound and empty: the copy is off.
if (-not $PSBoundParameters.ContainsKey('CopyTo')) { $CopyTo = $script:DefaultApkFolder }

try {
    $modules = if ($Module -eq 'all') { @('phone', 'wear') } else { @($Module) }
    $tasks = @($modules | ForEach-Object { ":${_}:assembleDebug" })
    $gradle = Join-Path $script:RepoRoot 'gradlew.bat'
    $downloads = Join-Path $script:RepoRoot 'DOWNLOADS'

    if ($DryRun) {
        Write-Host $(if ($NoBuild) { 'No build (-NoBuild).' } else { "$gradle $($tasks -join ' ') --console=plain" })
        Write-Host "APKs read from: $(($modules | ForEach-Object { "$_\build\outputs\apk\debug" }) -join ', ')"
        Write-Host "APKs collected in: $downloads (filler-<module>-debug-<versionName>.apk)"
        Write-Host $(if ($CopyTo) { "APKs would be copied to: $CopyTo" } else { 'The copy is off (-CopyTo '''').' })
        Write-Host $(if ($NoBuild) { 'Release ledger: skipped (-NoBuild).' } else { "Release ledger: would record debug build(s) for $($modules -join ', ') in docs/releases." })
        exit 0
    }

    if (-not $NoBuild) {
        Enter-LocalBuildLock 'build-debug.ps1: local debug build'
        Push-Location $script:RepoRoot
        try {
            & $gradle @tasks '--console=plain' | Out-Host
            if ($LASTEXITCODE -ne 0) { throw "Gradle failed (exit $LASTEXITCODE)." }
        } finally { Pop-Location }
    }

    # What each module built is read from the output metadata Gradle wrote next to the APK, never guessed.
    New-Item -ItemType Directory -Path $downloads -Force | Out-Null
    $apks = @()
    foreach ($target in $modules) {
        $dir = Join-Path $script:RepoRoot "$target\build\outputs\apk\debug"
        $metaFile = Join-Path $dir 'output-metadata.json'
        if (-not (Test-Path -LiteralPath $metaFile)) { throw "No debug build of $target found ($metaFile is missing)." }
        $elements = @((Get-Content -LiteralPath $metaFile -Raw | ConvertFrom-Json).elements)
        if ($elements.Count -ne 1) { throw "Expected one APK for $target, found $($elements.Count)." }
        $source = Join-Path $dir $elements[0].outputFile
        if (-not (Test-Path -LiteralPath $source)) { throw "$source is missing." }
        $name = "filler-$target-debug-$($elements[0].versionName).apk"
        Copy-Item -LiteralPath $source -Destination (Join-Path $downloads $name) -Force
        Write-Host ("  {0}  ({1:N1} MB)" -f $name, ((Get-Item -LiteralPath $source).Length / 1MB))
        $apks += [pscustomobject]@{ Source = (Join-Path $downloads $name); Name = $name; Package = $target; Version = [string]$elements[0].versionName }
    }
    Write-Host "Packages built from the local working tree: $downloads"

    $null = Copy-ApksToFolder $apks $CopyTo
    if (-not $NoBuild) {
        foreach ($apk in $apks) {
            Write-BuildLedger -Package $apk.Package -Kind 'debug' -Version $apk.Version -Artifact $apk.Source
        }
    }
    exit 0
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
