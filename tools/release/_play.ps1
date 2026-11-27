# Pure comparison helpers for GOOGLE-PLAY 0.1. The caller reads artifacts and current Play evidence.
Set-StrictMode -Version Latest

function Get-PlayForeground([xml] $Manifest) {
    $ns = 'http://schemas.android.com/apk/res/android'
    $permissions = @($Manifest.SelectNodes("//*[local-name()='uses-permission' or local-name()='uses-permission-sdk-23']") |
        ForEach-Object { $_.GetAttribute('name', $ns) } | Where-Object { $_ -match '^android\.permission\.FOREGROUND_SERVICE_' } |
        Sort-Object -Unique)
    $types = @()
    foreach ($service in $Manifest.SelectNodes("//*[local-name()='service']")) {
        $value = $service.GetAttribute('foregroundServiceType', $ns).Trim()
        if (-not $value) { continue }
        # bundletool may render the compiled bit field numerically. Do not silently ignore unknown bits.
        if ($value -match '^0x[0-9a-fA-F]+$' -or $value -match '^\d+$') {
            $bits = if ($value.StartsWith('0x')) { [Convert]::ToInt64($value.Substring(2), 16) } else { [long]$value }
            $known = [ordered]@{ 1='dataSync'; 2='mediaPlayback'; 4='phoneCall'; 8='location'; 16='connectedDevice';
                32='mediaProjection'; 64='camera'; 128='microphone'; 256='health'; 512='remoteMessaging';
                1024='systemExempted'; 2048='shortService'; 8192='mediaProcessing'; 1073741824='specialUse' }
            foreach ($entry in $known.GetEnumerator()) {
                $mask = [long]$entry.Key
                if (($bits -band $mask) -ne 0) { $types += $entry.Value; $bits = $bits -band (-bnot $mask) }
            }
            if ($bits -ne 0) { throw "Unknown foregroundServiceType bits in $value." }
        } else {
            $types += @($value -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        }
    }
    return [pscustomobject]@{ permissions = @($permissions); types = @($types | Sort-Object -Unique) }
}

function Get-PlayCandidateProblems($InputState, [object[]] $Candidates, $Previous, [datetime] $Today, $Expected = $null) {
    $problems = [System.Collections.Generic.List[string]]::new()
    $codes = @($InputState.history.entries | ForEach-Object { [long]$_.code })
    $maxCode = if ($codes.Count) { ($codes | Measure-Object -Maximum).Maximum } else { 0 }
    if (@($Candidates | ForEach-Object { $_.badging.versionCode } | Sort-Object -Unique).Count -ne $Candidates.Count) {
        $problems.Add('Candidate phone and wear versionCodes are not distinct.')
    }
    foreach ($candidate in $Candidates) {
        $family = $candidate.family
        $badging = $candidate.badging
        if ($badging.package -ne 'com.sza.filler') { $problems.Add("$family has unexpected application id $($badging.package).") }
        if ($null -ne $Expected -and ($badging.versionName -ne $Expected.versionName -or
                [long]$badging.versionCode -ne [long]$Expected.$family)) {
            $problems.Add("$family bundle version $($badging.versionName) ($($badging.versionCode)) differs from pinned $($Expected.versionName) ($($Expected.$family)).")
        }
        if ([long]$badging.versionCode -le $maxCode) { $problems.Add("$family versionCode $($badging.versionCode) is not above the used maximum $maxCode.") }
        if ([int]$badging.targetSdk -lt [int]$InputState.floors.$family) {
            $problems.Add("$family target API $($badging.targetSdk) is below the observed floor $($InputState.floors.$family).")
        }
        $old = $Previous.$family
        if ($null -ne $old) {
            $reachProblems = Compare-Reach ([pscustomobject]@{ $family = $old.badging }) ([pscustomobject]@{ $family = $badging })
            foreach ($issue in $reachProblems) {
                $problems.Add($issue)
            }
            if ([long]$badging.glEsVersion -gt [long]$old.badging.glEsVersion) {
                $problems.Add("$family OpenGL ES requirement rises from $($old.badging.glEsVersion) to $($badging.glEsVersion).")
            }
        }
        $oldPermissions = if ($null -ne $old) { @($old.foreground.permissions) } else { @() }
        $oldTypes = if ($null -ne $old) { @($old.foreground.types) } else { @() }
        $newPermissions = @($candidate.foreground.permissions | Where-Object { $_ -notin $oldPermissions })
        $newTypes = @($candidate.foreground.types | Where-Object { $_ -notin $oldTypes })
        if ($newPermissions.Count -or $newTypes.Count) {
            $declaration = $InputState.foregroundServiceDeclaration
            $uncoveredPermissions = @($newPermissions | Where-Object { $_ -notin @($declaration.permissions) })
            $uncoveredTypes = @($newTypes | Where-Object { $_ -notin @($declaration.types) })
            $declaredDate = [datetime]::MinValue
            $validDate = [datetime]::TryParseExact([string]$declaration.observedOn, 'yyyy-MM-dd',
                [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$declaredDate)
            if ($declaration.confirmed -isnot [bool] -or $declaration.confirmed -ne $true -or -not $validDate -or $declaredDate.Date -gt $Today.Date -or
                [string]::IsNullOrWhiteSpace([string]$declaration.evidence) -or $uncoveredPermissions.Count -or $uncoveredTypes.Count) {
                $problems.Add("$family adds foreground-service permissions [$($newPermissions -join ', ')] or types [$($newTypes -join ', ')]; a dated, matching App content declaration with justification is required before upload.")
            }
        }
    }
    return $problems.ToArray()
}

function Get-PlayTrackProblems([object[]] $Tracks, [string[]] $Expected) {
    $problems = [System.Collections.Generic.List[string]]::new()
    foreach ($pair in $Expected) {
        if ($pair -notmatch '^([a-zA-Z0-9:_-]+)=([1-9][0-9]*)$') { throw "Invalid expected track=versionCode: $pair" }
        $name = $Matches[1]; $code = $Matches[2]
        $track = @($Tracks | Where-Object { $_.track -eq $name })
        $found = @($track | Where-Object { $_.PSObject.Properties['releases'] } |
            ForEach-Object { $_.releases } | Where-Object { $_.PSObject.Properties['versionCodes'] } |
            ForEach-Object { $_.versionCodes } | Where-Object { "$_" -eq $code })
        if (-not $found.Count) { $problems.Add("$name does not contain versionCode $code") }
    }
    return $problems.ToArray()
}
