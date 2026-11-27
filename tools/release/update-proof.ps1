<#
.SYNOPSIS
    Filler's update proof (S0023 G4): a candidate package installs over a real prior install and keeps its data.

.DESCRIPTION
    Emulator only, because the first step uninstalls the package and so deletes its data:
      identity      prior and candidate are one application id with one signing certificate
      order         the candidate's versionCode is higher than the prior's
      prior         the prior APK is installed fresh
      prior-run     it is launched, so the app writes its own state (the session journal), then stopped
      update        the candidate goes over it with adb install -r
      version       the device reports the candidate's versionCode
      same-install  firstInstallTime is unchanged and lastUpdateTime moved: an update, not a reinstall
      data          every file of the prior's data folder is still there (adb root, a userdebug image; SKIP on an
                    image that refuses root, such as most Wear OS images)
      candidate-run the candidate is launched: its process lives and the crash buffer names no line of it

    For the first release the prior is the matching package of an earlier pre-flight (temp/release/<version>/
    packages/); from then on it is the package last shipped to Play. Run it once for the phone APK on a phone
    emulator and once for the watch APK on a Wear OS emulator. The result is written beside the candidate's
    pre-flight verdict as update-proof-<candidate>.json.

.EXAMPLE
    pwsh -NoProfile -File tools/release/update-proof.ps1 -Serial emulator-5554 `
        -Prior temp/release/2.61.1131.410/packages/filler-phone-2.61.1131.410.apk `
        -Candidate temp/release/2.61.1131.520/packages/filler-phone-2.61.1131.520.apk

.NOTES
    Exit codes: 0 PASS, 1 FAIL, 2 could not run (no device, not an emulator, an unreadable package).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Serial,
    [Parameter(Mandatory)][string] $Prior,
    [Parameter(Mandatory)][string] $Candidate,
    [string] $Out,
    [int] $SettleSeconds = 8
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_release.ps1')

$adb = Get-Adb
$steps = [System.Collections.Generic.List[object]]::new()
function Add-Step([string] $Id, [bool] $Ok, [string] $Detail, [switch] $Skip) {
    $status = if ($Skip) { 'SKIP' } elseif ($Ok) { 'PASS' } else { 'FAIL' }
    $steps.Add([pscustomobject]@{ id = $Id; status = $status; detail = $Detail })
    Write-Output ("  {0,-5} {1,-13} {2}" -f $status, $Id, $Detail)
}
function Invoke-Adb { & $adb -s $Serial @args 2>&1 }

function Read-InstallState([string] $Package) {
    $state = [ordered]@{ versionCode = $null; firstInstallTime = $null; lastUpdateTime = $null }
    foreach ($line in (Invoke-Adb shell dumpsys package $Package)) {
        if (-not $state.versionCode -and "$line" -match 'versionCode=(\d+)') { $state.versionCode = [int64]$Matches[1] }
        if (-not $state.firstInstallTime -and "$line" -match 'firstInstallTime=(.+)$') { $state.firstInstallTime = $Matches[1].Trim() }
        if (-not $state.lastUpdateTime -and "$line" -match 'lastUpdateTime=(.+)$') { $state.lastUpdateTime = $Matches[1].Trim() }
    }
    return [pscustomobject]$state
}

function Read-DataFiles([string] $Package) {
    $listing = Invoke-Adb shell "cd /data/data/$Package 2>/dev/null && find . -type f ! -path './cache/*' ! -path './code_cache/*'"
    if ($LASTEXITCODE -ne 0) { return $null }
    return @($listing | ForEach-Object { "$_".Trim() } | Where-Object { $_ } | Sort-Object)
}

function Test-Launch([string] $Package) {
    Invoke-Adb shell monkey -p $Package -c android.intent.category.LAUNCHER 1 | Out-Null
    Start-Sleep -Seconds $SettleSeconds
    $procId = ("$(Invoke-Adb shell pidof $Package)").Trim()
    $crashes = @(Invoke-Adb logcat -d -b crash | Where-Object { "$_" -match [regex]::Escape($Package) })
    return [pscustomobject]@{ pid = $procId; alive = ($procId -match '^\d+'); crashes = $crashes.Count }
}

$rooted = $false
try {
    if ($Serial -notmatch '^emulator-\d+$') { throw "$Serial is not an emulator; this proof uninstalls the package and runs on emulators only." }
    if (("$(Invoke-Adb get-state)").Trim() -ne 'device') { throw "$Serial is not attached." }
    $Prior = (Resolve-Path $Prior).Path
    $Candidate = (Resolve-Path $Candidate).Path
    if (-not $Out) { $Out = Split-Path (Split-Path $Candidate -Parent) -Parent }

    $p = Read-ApkBadging $Prior
    $c = Read-ApkBadging $Candidate
    $ps = Read-Signer $Prior
    $cs = Read-Signer $Candidate
    $pkg = $c.package
    $sameCert = [bool]($ps -and $cs -and $ps.sha256 -eq $cs.sha256)
    Add-Step 'identity' ($p.package -eq $c.package -and $sameCert) "$($p.package) -> $($c.package), certificate $(if ($sameCert) { 'shared' } else { 'DIFFERS or missing' })"
    Add-Step 'order' ($c.versionCode -gt $p.versionCode) "$($p.versionName) ($($p.versionCode)) -> $($c.versionName) ($($c.versionCode))"

    Invoke-Adb uninstall $pkg | Out-Null
    $install = Invoke-Adb install $Prior
    Add-Step 'prior' ($LASTEXITCODE -eq 0 -and "$install" -match 'Success') "fresh install of $(Split-Path $Prior -Leaf): $(($install | Select-Object -Last 1))"

    Invoke-Adb logcat -b crash -c | Out-Null
    $run = Test-Launch $pkg
    Add-Step 'prior-run' ($run.alive -and $run.crashes -eq 0) "pid $($run.pid), crash lines $($run.crashes)"
    Invoke-Adb shell am force-stop $pkg | Out-Null

    $rootOut = Invoke-Adb root
    $rooted = ($LASTEXITCODE -eq 0 -and -not ("$rootOut" -match 'cannot run as root'))
    Invoke-Adb wait-for-device | Out-Null
    $before = Read-InstallState $pkg
    $filesBefore = if ($rooted) { Read-DataFiles $pkg } else { $null }

    $update = Invoke-Adb install -r $Candidate
    Add-Step 'update' ($LASTEXITCODE -eq 0 -and "$update" -match 'Success') "install -r $(Split-Path $Candidate -Leaf): $(($update | Select-Object -Last 1))"

    $after = Read-InstallState $pkg
    Add-Step 'version' ($after.versionCode -eq $c.versionCode) "device reports $($after.versionCode), candidate $($c.versionCode)"
    Add-Step 'same-install' ([bool]$before.firstInstallTime -and $after.firstInstallTime -eq $before.firstInstallTime -and $after.lastUpdateTime -ne $before.lastUpdateTime) `
        "firstInstallTime $($before.firstInstallTime) kept, lastUpdateTime $($before.lastUpdateTime) -> $($after.lastUpdateTime)"

    if ($rooted) {
        $filesAfter = @(Read-DataFiles $pkg)
        $lost = @($filesBefore | Where-Object { $_ -notin $filesAfter })
        Add-Step 'data' ($lost.Count -eq 0) "$(@($filesBefore).Count) data files before, $($filesAfter.Count) after$(if ($lost.Count) { ", lost: $($lost -join ', ')" })"
    } else {
        Add-Step 'data' $false 'adb root refused on this image: the data folder was not listed; same-install shows an update, not a reinstall' -Skip
    }

    $run = Test-Launch $pkg
    Add-Step 'candidate-run' ($run.alive -and $run.crashes -eq 0) "pid $($run.pid), crash lines $($run.crashes)"

    $verdict = if ($steps | Where-Object status -eq 'FAIL') { 'FAIL' } else { 'PASS' }
    $result = [ordered]@{
        verdict = $verdict; package = $pkg; serial = $Serial
        device = ("$(Invoke-Adb shell getprop ro.product.model) API $(Invoke-Adb shell getprop ro.build.version.sdk)").Trim()
        prior = [ordered]@{ file = (Split-Path $Prior -Leaf); versionName = $p.versionName; versionCode = $p.versionCode }
        candidate = [ordered]@{ file = (Split-Path $Candidate -Leaf); versionName = $c.versionName; versionCode = $c.versionCode }
        before = $before; after = $after; dataFiles = $filesBefore
        provedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz'); steps = $steps
    }
    $file = Join-Path $Out ('update-proof-{0}.json' -f [System.IO.Path]::GetFileNameWithoutExtension($Candidate))
    $result | ConvertTo-Json -Depth 6 | Set-Content $file -Encoding utf8
    Write-Output ''
    Write-Output "UPDATE PROOF: $verdict for $pkg $($p.versionName) -> $($c.versionName) on $Serial -> $file"
    exit $(if ($verdict -eq 'PASS') { 0 } else { 1 })
} catch {
    Write-Error "update-proof could not run: $($_.Exception.Message)" -ErrorAction Continue
    exit 2
} finally {
    if ($rooted) { & $adb -s $Serial unroot 2>&1 | Out-Null }
}
