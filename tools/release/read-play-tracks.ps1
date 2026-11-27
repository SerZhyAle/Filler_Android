#requires -Version 7.0
<#
.SYNOPSIS
    Read tracks after a commit through a separately opened Play API edit; this script only sends GET.
.NOTES
    A new edit invalidates another edit, so the owner opens it after the prior commit and supplies its id.
    The access token is read only from FILLER_PLAY_ACCESS_TOKEN and is never written to the receipt.
    Exit 0: expected codes found, 1: a code was absent, 2: the read could not be verified.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $EditId,
    [Parameter(Mandatory)][string[]] $Expected,
    [Parameter(Mandatory)][ValidateSet('automatic', 'held', 'console')][string] $CommitMode,
    [Parameter(Mandatory)][string] $CommitEvidence,
    [Parameter(Mandatory)][string] $OutFile
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_play.ps1')
try {
    if ([string]::IsNullOrWhiteSpace($env:FILLER_PLAY_ACCESS_TOKEN)) { throw 'FILLER_PLAY_ACCESS_TOKEN is not set.' }
    $Expected = @($Expected | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ([string]::IsNullOrWhiteSpace($CommitEvidence) -or $Expected.Count -eq 0) { throw 'Commit evidence and expected tracks are required.' }
    # Check the input before contacting Play.
    foreach ($pair in $Expected) { if ($pair -notmatch '^[a-zA-Z0-9:_-]+=[1-9][0-9]*$') { throw "Invalid expected track=versionCode: $pair" } }
    $edit = [uri]::EscapeDataString($EditId)
    $uri = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.sza.filler/edits/$edit/tracks"
    $reply = Invoke-RestMethod -Method Get -Uri $uri -Headers @{ Authorization = "Bearer $env:FILLER_PLAY_ACCESS_TOKEN" }
    $tracks = if ($reply.PSObject.Properties['tracks']) { @($reply.tracks) } else { @() }
    $problems = @(Get-PlayTrackProblems $tracks $Expected)
    $receipt = [ordered]@{ applicationId = 'com.sza.filler'; checkedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz');
        commitMode = $CommitMode; commitEvidence = $CommitEvidence; expected = $Expected; tracks = $tracks; problems = $problems }
    $receipt | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutFile -Encoding utf8
    Write-Output "Commit mode: $CommitMode (reported from $CommitEvidence)"
    foreach ($track in $tracks) {
        if ($track.PSObject.Properties['releases']) {
            foreach ($release in @($track.releases)) {
                $versions = if ($release.PSObject.Properties['versionCodes']) { @($release.versionCodes) -join ', ' } else { '' }
                $status = if ($release.PSObject.Properties['status']) { $release.status } else { 'unspecified' }
                Write-Output "$($track.track): $versions [$status]"
            }
        } else { Write-Output "$($track.track): empty" }
    }
    if ($problems.Count) { $problems | ForEach-Object { Write-Output "FAIL: $_" }; exit 1 }
    Write-Output 'PASS: each expected versionCode was read on its expected track; this does not prove public serving.'
    exit 0
} catch {
    # Do not print HTTP response bodies or authorization headers.
    Write-Output 'UNVERIFIED: track read failed, input was invalid, or the receipt could not be written.'
    exit 2
}
