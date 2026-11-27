#requires -Version 7.0
<#
.SYNOPSIS
    GOOGLE-PLAY 0.1 pre-upload check. Inspects universal APKs and manifests made from the actual AABs.
.NOTES
    Exit 0: checks pass; 1: a candidate violates a check; 2: evidence or tools are missing or unreadable.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $PhoneBundle,
    [Parameter(Mandatory)][string] $WearBundle,
    [Parameter(Mandatory)][string] $ExpectedVersion,
    [Parameter(Mandatory)][long] $ExpectedPhoneCode,
    [Parameter(Mandatory)][long] $ExpectedWearCode,
    [Parameter(Mandatory)][string] $State,
    [Parameter(Mandatory)][string] $Bundletool,
    [Parameter(Mandatory)][string] $EvidenceDir,
    [AllowEmptyString()][string] $CopyTo
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_release.ps1')
. (Join-Path $PSScriptRoot '_play.ps1')
if (-not $PSBoundParameters.ContainsKey('CopyTo')) { $CopyTo = $script:DefaultApkFolder }

function Read-PlayArtifact([string] $Family, [string] $Bundle, [string] $Label) {
    if (-not (Test-Path -LiteralPath $Bundle -PathType Leaf)) { throw "$Label $Family bundle is missing: $Bundle" }
    $stem = Join-Path $EvidenceDir "$Label-$Family"
    $archive = "$stem.apks"
    $buildOut = @(& $java -jar $Bundletool build-apks "--bundle=$Bundle" "--output=$archive" --mode=universal --overwrite 2>&1)
    $code = $LASTEXITCODE
    @("command: java -jar `"$Bundletool`" build-apks --bundle=`"$Bundle`" --output=`"$archive`" --mode=universal --overwrite", "exit: $code") + $buildOut |
        Set-Content -LiteralPath "$stem-bundletool.log" -Encoding utf8
    if ($code -ne 0 -or -not (Test-Path -LiteralPath $archive)) { throw "bundletool build-apks failed for $Label $Family (exit $code)." }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($archive)
    try {
        $entry = $zip.GetEntry('universal.apk')
        if (-not $entry) { throw "universal.apk missing for $Label $Family." }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, "$stem.apk", $true)
    } finally { $zip.Dispose() }
    $badgingLines = @(& (Get-BuildTool 'aapt2') dump badging "$stem.apk" 2>&1)
    $code = $LASTEXITCODE
    @("command: aapt2 dump badging `"$stem.apk`"", "exit: $code") + $badgingLines |
        Set-Content -LiteralPath "$stem-badging.txt" -Encoding utf8
    if ($code -ne 0) { throw "aapt2 could not read $Label $Family (exit $code)." }
    $badging = Read-ApkBadging "$stem.apk"
    if (-not $badging.package -or -not $badging.versionCode -or -not $badging.minSdk -or -not $badging.targetSdk) {
        throw "Incomplete badging for $Label $Family."
    }
    if ($badging.featureGroups -ne 1) { throw "$Label $Family badging has $($badging.featureGroups) feature groups; reach needs a manual comparison." }
    # These are bundletool's inspection APKs, signed for local inspection, not the original release APKs.
    try {
        $copy = [pscustomobject]@{ Source = "$stem.apk"; Name = "filler-play-inspection-$Label-$Family-$($badging.versionCode).apk" }
        $null = Copy-ApksToFolder @($copy) $CopyTo
    } catch { Write-Warning "Inspection APK not copied: $($_.Exception.Message)" }
    $manifestLines = @(& $java -jar $Bundletool dump manifest "--bundle=$Bundle" --module=base 2>&1)
    $code = $LASTEXITCODE
    $manifestLines | Set-Content -LiteralPath "$stem-manifest.xml" -Encoding utf8
    @("command: java -jar `"$Bundletool`" dump manifest --bundle=`"$Bundle`" --module=base", "exit: $code") + $manifestLines |
        Set-Content -LiteralPath "$stem-manifest.log" -Encoding utf8
    if ($code -ne 0) { throw "bundletool dump manifest failed for $Label $Family (exit $code)." }
    $manifest = [xml]($manifestLines -join "`n")
    return [pscustomobject]@{ family = $Family; badging = $badging; foreground = (Get-PlayForeground $manifest) }
}

try {
    foreach ($file in @($State, $Bundletool)) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Required evidence or bundletool is missing: $file" }
    }
    $statePath = (Resolve-Path -LiteralPath $State).Path
    $Bundletool = (Resolve-Path -LiteralPath $Bundletool).Path
    $stateData = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    if ($stateData.schema -ne 1 -or $stateData.applicationId -ne $script:AppId -or
        $stateData.history.complete -isnot [bool] -or $stateData.history.complete -ne $true) {
        throw 'State must name schema 1, the application id and a complete used-version history.'
    }
    if ([string]::IsNullOrWhiteSpace($ExpectedVersion) -or $ExpectedPhoneCode -le 0 -or $ExpectedWearCode -le 0) {
        throw 'The pinned versionName and both family versionCodes are required.'
    }
    $today = (Get-Date).Date
    foreach ($observation in @($stateData.history, $stateData.floors)) {
        $date = [datetime]::MinValue
        if (-not [datetime]::TryParseExact([string]$observation.observedOn, 'yyyy-MM-dd',
                [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$date) -or $date.Date -ne $today) {
            throw 'The Play version history and target API floors must each be read today, for this release.'
        }
        if ([string]::IsNullOrWhiteSpace([string]$observation.source)) { throw 'Each observation must name its source.' }
    }
    if ($stateData.floors.source -notmatch '^https://(support\.google\.com|developer\.android\.com)/' -or
        [int]$stateData.floors.phone -lt 1 -or [int]$stateData.floors.wear -lt 1) {
        throw 'Target API floors require positive values and an official Google or Android policy URL.'
    }
    foreach ($entry in @($stateData.history.entries)) {
        if ($entry.family -notin @('phone', 'wear') -or [long]$entry.code -lt 1) { throw 'Invalid used-version history entry.' }
    }
    $used = @($stateData.history.entries | ForEach-Object { [long]$_.code })
    if (@($used | Sort-Object -Unique).Count -ne $used.Count) { throw 'Used-version history repeats a versionCode.' }
    New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
    $java = Get-JdkTool 'java'
    $previous = [ordered]@{ phone = $null; wear = $null }
    foreach ($family in @('phone', 'wear')) {
        $prior = $stateData.previous.$family
        $familyCodes = @($stateData.history.entries | Where-Object { $_.family -eq $family } | ForEach-Object { [long]$_.code })
        if ($null -eq $prior) {
            if ($familyCodes.Count) { throw "$family has used codes but no previous bundle was supplied." }
            continue
        }
        if ([long]$prior.versionCode -notin $familyCodes -or $prior.sha256 -notmatch '^[0-9a-fA-F]{64}$') { throw "$family previous bundle needs a historical code and SHA-256." }
        $path = [string]$prior.bundle
        if (-not [System.IO.Path]::IsPathRooted($path)) { $path = Join-Path (Split-Path -Parent $statePath) $path }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $prior.sha256) {
            throw "$family previous bundle is missing or its SHA-256 differs."
        }
        $previous[$family] = Read-PlayArtifact $family $path 'previous'
        if ($previous[$family].badging.package -ne $script:AppId -or $previous[$family].badging.versionCode -ne [long]$prior.versionCode) {
            throw "$family previous bundle identity or versionCode disagrees with the history."
        }
    }
    $candidates = @((Read-PlayArtifact 'phone' $PhoneBundle 'candidate'), (Read-PlayArtifact 'wear' $WearBundle 'candidate'))
    $expected = [pscustomobject]@{ versionName = $ExpectedVersion; phone = $ExpectedPhoneCode; wear = $ExpectedWearCode }
    $problems = @(Get-PlayCandidateProblems $stateData $candidates ([pscustomobject]$previous) $today $expected)
    $result = [ordered]@{ applicationId = $script:AppId; checkedOn = $today.ToString('yyyy-MM-dd'); history = $stateData.history;
        floors = $stateData.floors; expected = $expected; previousInput = $stateData.previous; declaration = $stateData.foregroundServiceDeclaration;
        candidates = $candidates; previous = $previous; problems = $problems }
    $result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $EvidenceDir 'play-preupload.json') -Encoding utf8
    if ($problems.Count) { $problems | ForEach-Object { Write-Output "FAIL: $_" }; exit 1 }
    Write-Output "PASS: phone $($candidates[0].badging.versionCode), wear $($candidates[1].badging.versionCode); current Play history, API floors, bundle reach and foreground-service declarations checked."
    exit 0
} catch {
    Write-Output "UNVERIFIED: $($_.Exception.Message)"
    exit 2
}
