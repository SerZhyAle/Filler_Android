# Shared helpers of the Filler release and build scripts (S0023). Dot-sourced by new-release-keys.ps1, preflight.ps1,
# update-proof.ps1, tools/builders/build-debug.ps1 and the launcher a.ps1; never run on its own. Pure functions (version
# rendering, reach and permission comparison) take their inputs as arguments so they can be called directly from a
# console.

Set-StrictMode -Version Latest

$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

# Frozen anchor (owner, 2026-11-13): the phone app and the watch app share one Play application id.
$script:AppId = 'com.sza.filler'

# The environment variable the build reads (buildSrc ReleaseSigning.ENV) and the owner's key folder.
$script:KeysEnv = 'FILLER_KEYSTORE_PROPERTIES'
$script:CredentialsDir = 'P:\ANDROID\Filler_credentials'

function Get-SdkRoot {
    foreach ($candidate in @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT)) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }
    $local = Join-Path $script:RepoRoot 'local.properties'
    if (Test-Path $local) {
        $line = Get-Content $local | Where-Object { $_ -match '^sdk\.dir=' } | Select-Object -First 1
        if ($line) { return ($line -replace '^sdk\.dir=', '' -replace '\\:', ':' -replace '\\\\', '\') }
    }
    $default = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
    if (Test-Path $default) { return $default }
    throw 'Android SDK not found: set ANDROID_HOME or sdk.dir in local.properties.'
}

function Get-BuildTool([string] $Name) {
    $newest = Get-ChildItem (Join-Path (Get-SdkRoot) 'build-tools') -Directory |
        Where-Object { $_.Name -match '^\d+(\.\d+)*$' } |
        Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
    if (-not $newest) { throw 'No Android build-tools are installed.' }
    foreach ($file in @("$Name.exe", "$Name.bat", $Name)) {
        $path = Join-Path $newest.FullName $file
        if (Test-Path $path) { return $path }
    }
    throw "build-tools $($newest.Name) has no $Name."
}

function Get-JdkTool([string] $Name) {
    if ($env:JAVA_HOME) {
        $path = Join-Path $env:JAVA_HOME "bin\$Name.exe"
        if (Test-Path $path) { return $path }
    }
    $found = Get-Command $Name -ErrorAction SilentlyContinue
    if ($found) { return $found.Source }
    throw "$Name not found: set JAVA_HOME to a JDK."
}

function Get-Adb { return (Join-Path (Get-SdkRoot) 'platform-tools\adb.exe') }

# Several sessions share the working tree: queue for the Build.Main lock the harness scripts use before any Gradle
# run in it. The library is found the way tools/harness.ps1 finds the plugin: $env:SZA_HARNESS_ROOT first, then the
# newest installed version. Without the plugin the build goes ahead with a warning. The lock is held by this
# process until it exits (Enter-BuildLockOrExit exits the caller when it cannot be had).
function Enter-LocalBuildLock([string] $Reason) {
    $roots = @()
    if ($env:SZA_HARNESS_ROOT) { $roots += $env:SZA_HARNESS_ROOT }
    $cache = Join-Path ($env:USERPROFILE ?? $env:HOME) '.claude/plugins/cache/sza-unified-rules/sza'
    if (Test-Path -LiteralPath $cache) {
        $roots += @(Get-ChildItem -LiteralPath $cache -Directory | Where-Object { $_.Name -as [version] } |
                Sort-Object { [version]$_.Name } -Descending | ForEach-Object { Join-Path $_.FullName 'tools/harness' })
    }
    $lockLib = $roots | ForEach-Object { Join-Path $_ 'locks/agent-lock.ps1' } |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $lockLib) {
        Write-Warning 'The harness lock library (sza plugin) was not found; running without the Build.Main lock.'
        return
    }
    $env:SZA_PROJECT_ROOT = $script:RepoRoot
    . $lockLib
    Enter-BuildLockOrExit -Reason $Reason -Name 'Build.Main'
}

# The synced work folder every script that builds an APK hands it on to (owner's order of 2026-11-15). The folder
# is the Google Drive mirror on the owner's PC; an empty -CopyTo turns the copy off.
$script:DefaultApkFolder = 'C:\GD\WORK'

# Copies built APKs into $Folder under a name each. $Apks are objects with Source (a file) and Name (the file name
# in the folder). A missing folder is a warning, never an error and never created: the drive may be unmounted, and
# creating the path would leave a stray directory behind. Returns the paths written.
function Copy-ApksToFolder([object[]] $Apks, [string] $Folder) {
    $written = @()
    if ([string]::IsNullOrWhiteSpace($Folder) -or -not $Apks) { return , $written }
    if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
        Write-Warning "APKs not copied: folder $Folder does not exist."
        return , $written
    }
    foreach ($apk in $Apks) {
        $target = Join-Path $Folder $apk.Name
        Copy-Item -LiteralPath $apk.Source -Destination $target -Force
        Write-Host ("Copied to {0}: {1} ({2:N1} MB)" -f $Folder, $apk.Name, ((Get-Item -LiteralPath $target).Length / 1MB))
        $written += $target
    }
    return , $written
}

# Record a completed build in the repository's release ledger (RELEASE-LEDGER rule 4). Never fails the build:
# a missing harness or non-zero ledger exit is reported as a warning only.
function Write-BuildLedger {
    param(
        [Parameter(Mandatory)][ValidateSet('phone', 'wear')][string] $Package,
        [Parameter(Mandatory)][ValidateSet('release', 'test', 'debug')][string] $Kind,
        [Parameter(Mandatory)][string] $Version,
        [string] $Flavor = 'default',
        [string] $Artifact,
        [string] $Note
    )
    $harness = Join-Path $script:RepoRoot 'tools\harness.ps1'
    if (-not (Test-Path -LiteralPath $harness -PathType Leaf)) {
        Write-Warning "release-ledger: tools/harness.ps1 not found; build $Package/$Flavor $Kind $Version not recorded."
        return
    }
    $rlArgs = @('-NoProfile', '-File', $harness, 'releases/release-ledger', 'build',
        '-Package', $Package, '-Kind', $Kind, '-Version', $Version, '-Flavor', $Flavor)
    if ($Artifact) { $rlArgs += @('-Artifact', $Artifact) }
    if ($Note) { $rlArgs += @('-Note', $Note) }
    try {
        $prevPref = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $out = & pwsh @rlArgs 2>&1
            $code = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $prevPref
        }
        if ($code -ne 0) {
            Write-Warning "release-ledger build failed for $Package $Kind $Version (exit $code): $(($out | ForEach-Object { "$_" }) -join ' ')"
        } else {
            $out | ForEach-Object { Write-Host $_ }
        }
    } catch {
        Write-Warning "release-ledger build failed for $Package $Kind $Version`: $($_.Exception.Message)"
    }
}

# PACKAGE-VERSIONING, Android profile, as buildSrc VersionStamp renders it: instant yyMMddHHmm,
# versionName Y.YM.MDDH.Hmm, versionCode yyMMddHH * 10 + the family's band of the minute.
function ConvertTo-VersionName([string] $Instant) {
    if ($Instant -notmatch '^\d{10}$') { throw "'$Instant' is not a yyMMddHHmm instant." }
    $d = $Instant.ToCharArray()
    return "$($d[0]).$($d[1])$($d[2]).$($d[3])$($d[4])$($d[5])$($d[6]).$($d[7])$($d[8])$($d[9])"
}

function ConvertFrom-VersionName([string] $Name) {
    if ($Name -notmatch '^(\d)\.(\d{2})\.(\d{4})\.(\d{3})$') { return $null }
    return $Matches[1] + $Matches[2] + $Matches[3] + $Matches[4]
}

function Get-VersionCode([ValidateSet('phone', 'wear')][string] $Family, [string] $Instant) {
    $minute = [int]$Instant.Substring(8, 2)
    $band = if ($Family -eq 'phone') { [math]::Floor($minute / 10) } else { 6 + [math]::Floor($minute / 15) }
    return [int64]$Instant.Substring(0, 8) * 10 + $band
}

# Parse the aapt2 output. Feature rows are indented inside feature-group; optional rows are not requirements.
function ConvertFrom-ApkBadging([string[]] $Lines) {
    $info = [ordered]@{ package = $null; versionCode = $null; versionName = $null; minSdk = $null; targetSdk = $null
        nativeCode = @(); requiredFeatures = @(); glEsVersion = 65536; featureGroups = 0; permissions = @() }
    foreach ($line in $Lines) {
        if ($line -match "^package: name='([^']+)' versionCode='([^']+)' versionName='([^']*)'") {
            $info.package = $Matches[1]; $info.versionCode = [int64]$Matches[2]; $info.versionName = $Matches[3]
        } elseif ($line -match "^(?:minSdkVersion|sdkVersion):'(\d+)'") {
            $info.minSdk = [int]$Matches[1]
        } elseif ($line -match "^targetSdkVersion:'(\d+)'") {
            $info.targetSdk = [int]$Matches[1]
        } elseif ($line -match '^native-code: (.*)$') {
            $info.nativeCode = @([regex]::Matches($Matches[1], "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
        } elseif ($line -match '^feature-group:') {
            $info.featureGroups++
        } elseif ($line -match "^\s*uses-feature(?:-sdk-23)?: name='([^']+)'") {
            $info.requiredFeatures += $Matches[1]
        } elseif ($line -match "^\s*uses-gl-es: '0x([0-9a-fA-F]+)'") {
            $info.glEsVersion = [math]::Max([int64]$info.glEsVersion, [Convert]::ToInt64($Matches[1], 16))
        } elseif ($line -match "^\s*uses-permission(?:-sdk-23)?: name='([^']+)'") {
            $info.permissions += $Matches[1]
        }
    }
    $info.requiredFeatures = @($info.requiredFeatures | Sort-Object -Unique)
    $info.permissions = @($info.permissions | Sort-Object -Unique)
    return [pscustomobject]$info
}

# What a built APK declares, read from the package with aapt2 (never from the sources).
function Read-ApkBadging([string] $Apk) {
    $lines = & (Get-BuildTool 'aapt2') dump badging $Apk 2>$null
    if ($LASTEXITCODE -ne 0) { throw "aapt2 could not read $Apk." }
    return ConvertFrom-ApkBadging $lines
}

# The signing certificate of a package (SHA-256, subject); $null when it carries none.
function Read-Signer([string] $Package) {
    if ($Package -like '*.apk') {
        $out = & (Get-BuildTool 'apksigner') verify --print-certs $Package 2>&1
        if ($LASTEXITCODE -ne 0) { return $null }
        $sha = $out | Select-String 'certificate SHA-256 digest: ([0-9a-f]+)' | Select-Object -First 1
        $dn = $out | Select-String 'certificate DN: (.+)$' | Select-Object -First 1
        if (-not $sha) { return $null }
        return [pscustomobject]@{ sha256 = $sha.Matches[0].Groups[1].Value
            subject = $(if ($dn) { $dn.Matches[0].Groups[1].Value } else { '' }) }
    }
    $out = & (Get-JdkTool 'keytool') -printcert -jarfile $Package 2>&1
    if ($LASTEXITCODE -ne 0) { return $null }
    $sha = $out | Select-String '^\s*SHA256: ([0-9A-F:]+)' | Select-Object -First 1
    $owner = $out | Select-String '^\s*Owner: (.+)$' | Select-Object -First 1
    if (-not $sha) { return $null }
    return [pscustomobject]@{ sha256 = ($sha.Matches[0].Groups[1].Value -replace ':', '').ToLowerInvariant()
        subject = $(if ($owner) { $owner.Matches[0].Groups[1].Value } else { '' }) }
}

function Get-ZipEntryNames([string] $Path) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try { return @($zip.Entries | ForEach-Object FullName) } finally { $zip.Dispose() }
}

# Reach (S0023 G5): a candidate shrinks the baseline when a package is gone, its minSdk rose, it newly names ABIs
# or drops one, or it newly requires a feature. Inputs are the 'packages' objects of two reach JSON files.
function Compare-Reach([pscustomobject] $Baseline, [pscustomobject] $Candidate) {
    $shrinks = @()
    $candidateKeys = @($Candidate.PSObject.Properties.Name)
    foreach ($prop in $Baseline.PSObject.Properties) {
        $key = $prop.Name; $b = $prop.Value
        if ($key -notin $candidateKeys) { $shrinks += "$key is gone"; continue }
        $c = $Candidate.$key
        if ([int]$c.minSdk -gt [int]$b.minSdk) { $shrinks += "$key minSdk $($b.minSdk) -> $($c.minSdk)" }
        $bAbi = @($b.nativeCode | Where-Object { $_ }); $cAbi = @($c.nativeCode | Where-Object { $_ })
        if ($cAbi.Count -and -not $bAbi.Count) { $shrinks += "$key ABIs any -> $($cAbi -join ',')" }
        foreach ($abi in $bAbi) { if ($cAbi.Count -and $abi -notin $cAbi) { $shrinks += "$key drops ABI $abi" } }
        foreach ($f in @($c.requiredFeatures | Where-Object { $_ })) {
            if ($f -notin @($b.requiredFeatures)) { $shrinks += "$key now requires $f" }
        }
    }
    return , $shrinks
}

# Privacy (canon invariant 14): what a package asks for against what the records say. The app's own signature
# permission (androidx.core's DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION under the application id) is internal and
# not a user permission. Each remaining permission must be named in the Data safety record for both families;
# INTERNET is never allowed (the pages say there is none).
function Test-PermissionRecord([string] $Family, [string[]] $Permissions, [string] $DataSafetyText) {
    $problems = @()
    $user = @($Permissions | Where-Object { $_ -and -not $_.StartsWith("$($script:AppId).") })
    foreach ($p in $user) {
        $short = $p -replace '^android\.permission\.', ''
        if ($short -eq 'INTERNET') { $problems += "$Family asks for INTERNET; the privacy pages say there is none"; continue }
        if ($DataSafetyText -notmatch ('`' + [regex]::Escape($short) + '`')) { $problems += "$Family asks for $short, which docs/play/PLAY_DATA_SAFETY.md does not name" }
    }
    return , $problems
}

# "What's new" (S0023 G7): each listing file carries a '## What's new' section with text, at most 500 characters
# (the Play limit for release notes). Returns the problem, or $null when the section is fit to paste.
function Test-WhatsNew([string] $ListingText) {
    $m = [regex]::Match($ListingText, "(?ms)^## What's new[^\r\n]*\r?\n(.*?)(?=^## |\z)")
    if (-not $m.Success) { return "no '## What's new' section" }
    $body = ($m.Groups[1].Value -split "\r?\n" | Where-Object { $_ -notmatch '^\s*(<!--.*-->)?\s*$' }) -join "`n"
    if (-not $body.Trim()) { return "the '## What's new' section is empty" }
    if ($body.Trim().Length -gt 500) { return "the '## What's new' text is $($body.Trim().Length) characters, Play takes 500" }
    return $null
}

# Contract registration (S0030, REPO-LAYOUT rule 2): a pointer cell names every id it covers. An id counts as registered
# when a 'filler-mob' registry row carries it, or when its parent is registered and named in the same cell, the
# parent followed by a dash (TEST-LAB under TEST-LAB-ANDROID: a platform profile is defined by its parent's row, and no
# product holds a row of its own for it). Inputs: the contract cells of the pointer rows, one string per row, and the
# ids of the registry rows. Returns the ids with no registration, in order.
function Get-UnregisteredContractIds([string[]] $PointerCells, [string[]] $RegisteredIds) {
    $absent = @()
    foreach ($cell in $PointerCells) {
        $ids = @([regex]::Matches($cell, '`([A-Z0-9-]+)`') | ForEach-Object { $_.Groups[1].Value })
        foreach ($id in $ids) {
            if ($id -in $RegisteredIds) { continue }
            $parentRegistered = @($ids | Where-Object { $id.StartsWith("$($_)-", [StringComparison]::Ordinal) -and $_ -in $RegisteredIds }).Count -gt 0
            if (-not $parentRegistered) { $absent += $id }
        }
    }
    return $absent
}
