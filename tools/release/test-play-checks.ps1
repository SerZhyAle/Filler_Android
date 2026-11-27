#requires -Version 7.0
# Fast, synthetic checks of the safety-critical comparison. Real bundletool and Play runs are release checks.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_release.ps1')
. (Join-Path $PSScriptRoot '_play.ps1')

function Assert-Case([bool] $Condition, [string] $Name) {
    if (-not $Condition) { throw "FAIL: $Name" }
    Write-Output "PASS: $Name"
}
$today = (Get-Date).Date
$state = @'
{"history":{"entries":[{"family":"phone","code":100},{"family":"wear","code":109}]},
 "floors":{"phone":36,"wear":35},
 "foregroundServiceDeclaration":{"confirmed":true,"observedOn":"2020-01-01","evidence":"Console App content with justification",
 "permissions":["android.permission.FOREGROUND_SERVICE_DATA_SYNC"],"types":["dataSync"]}}
'@ | ConvertFrom-Json
$base = @'
{"package":"com.sza.filler","versionName":"old","versionCode":100,"minSdk":26,"targetSdk":36,"nativeCode":[],"requiredFeatures":["old"],"glEsVersion":65536}
'@ | ConvertFrom-Json
$candidate = @'
{"package":"com.sza.filler","versionName":"candidate","versionCode":110,"minSdk":26,"targetSdk":36,"nativeCode":[],"requiredFeatures":["old"],"glEsVersion":65536}
'@ | ConvertFrom-Json
$none = [pscustomobject]@{ permissions = @(); types = @() }
$fg = [pscustomobject]@{ permissions = @('android.permission.FOREGROUND_SERVICE_DATA_SYNC'); types = @('dataSync') }
$previous = [pscustomobject]@{ phone = [pscustomobject]@{ badging = $base; foreground = $none }; wear = $null }
$phone = [pscustomobject]@{ family = 'phone'; badging = $candidate; foreground = $fg }
$watch = [pscustomobject]@{ family = 'wear'; badging = ($candidate | ConvertTo-Json | ConvertFrom-Json); foreground = $none }
$watch.badging.versionCode = 111
$candidates = @($phone, $watch)
$issues = @(Get-PlayCandidateProblems $state $candidates $previous $today)
if ($issues.Count) { $issues | ForEach-Object { Write-Output "DETAIL: $_" } }
Assert-Case ($issues.Count -eq 0) 'valid versions, floors, reach and declared foreground type'
$phone.badging.versionCode = 109
Assert-Case (@(Get-PlayCandidateProblems $state $candidates $previous $today).Count -eq 1) 'version must exceed the maximum across both families'
$phone.badging.versionCode = 110
$phone.badging.targetSdk = 35
Assert-Case (@(Get-PlayCandidateProblems $state $candidates $previous $today).Count -eq 1) 'target API below current floor fails'
$phone.badging.targetSdk = 36
$phone.badging.requiredFeatures = @('old', 'new')
Assert-Case (@(Get-PlayCandidateProblems $state $candidates $previous $today).Count -eq 1) 'new required feature narrows reach'
$phone.badging.requiredFeatures = @()
Assert-Case (@(Get-PlayCandidateProblems $state $candidates $previous $today).Count -eq 0) 'removing a required feature widens reach'
$state.foregroundServiceDeclaration.confirmed = $false
Assert-Case (@(Get-PlayCandidateProblems $state $candidates $previous $today).Count -eq 1) 'new foreground type without console declaration fails'
$xml = [xml]'<manifest xmlns:android="http://schemas.android.com/apk/res/android"><uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"/><application><service android:foregroundServiceType="0x40000001"/></application></manifest>'
$parsed = Get-PlayForeground $xml
Assert-Case (('dataSync' -in $parsed.types) -and ('specialUse' -in $parsed.types) -and $parsed.permissions.Count -eq 1) 'compiled foreground bitmask and permission'
$tracks = @(
    '{"track":"internal","releases":[{"versionCodes":["110"]}]}' | ConvertFrom-Json
    '{"track":"wear:internal","releases":[{"versionCodes":["111"]}]}' | ConvertFrom-Json
)
Assert-Case (@(Get-PlayTrackProblems $tracks @('internal=110', 'wear:internal=111')).Count -eq 0) 'both expected track codes read back'
Assert-Case (@(Get-PlayTrackProblems $tracks @('internal=111', 'wear:internal=110')).Count -eq 2) 'codes on the wrong tracks fail'
$state.foregroundServiceDeclaration.confirmed = $true
$expected = [pscustomobject]@{ versionName = 'candidate'; phone = 110; wear = 112 }
Assert-Case (@(Get-PlayCandidateProblems $state $candidates $previous $today $expected).Count -eq 1) 'AAB version must match the pinned family version'
$rawBadging = @("package: name='com.sza.filler' versionCode='110' versionName='candidate'", "sdkVersion:'26'", "targetSdkVersion:'36'",
    "feature-group: label=''", " uses-feature: name='android.hardware.screen.portrait'", " uses-feature-sdk-23: name='android.hardware.camera'",
    " uses-feature-not-required: name='android.hardware.touchscreen'", " uses-gl-es: '0x20000'")
$parsedBadging = ConvertFrom-ApkBadging $rawBadging
Assert-Case (('android.hardware.screen.portrait' -in $parsedBadging.requiredFeatures) -and
    ('android.hardware.camera' -in $parsedBadging.requiredFeatures) -and
    ('android.hardware.touchscreen' -notin $parsedBadging.requiredFeatures) -and $parsedBadging.glEsVersion -eq 131072 -and
    $parsedBadging.featureGroups -eq 1) 'indented aapt2 requirements and optional feature'
$phone.badging.glEsVersion = 131072
$expected.wear = 111
Assert-Case (@(Get-PlayCandidateProblems $state $candidates $previous $today $expected).Count -eq 1) 'higher OpenGL ES requirement narrows reach'
Write-Output 'play-checks: PASS (12 cases)'
