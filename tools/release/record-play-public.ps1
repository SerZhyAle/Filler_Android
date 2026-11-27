#requires -Version 7.0
<#
.SYNOPSIS
    Record an owner's public-page observation after approval and check the page answers over HTTPS.
.NOTES
    Version, update date, description and image are manually observed; an API track response is not publication proof.
    Exit 0: the owner attested all observations and the page answered 200; 2: the proof is incomplete.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Observation,
    [Parameter(Mandatory)][string] $ExpectedVersion,
    [Parameter(Mandatory)][string] $OutFile
)
$ErrorActionPreference = 'Stop'
try {
    $record = Get-Content -LiteralPath $Observation -Raw | ConvertFrom-Json
    if ($record.applicationId -ne 'com.sza.filler' -or [string]::IsNullOrWhiteSpace($ExpectedVersion) -or
        $record.expectedVersion -ne $ExpectedVersion -or $record.observedVersion -ne $ExpectedVersion -or
        [string]::IsNullOrWhiteSpace([string]$record.descriptionExcerpt) -or
        [string]::IsNullOrWhiteSpace([string]$record.imageEvidence) -or [string]::IsNullOrWhiteSpace([string]$record.observer) -or
        $record.confirmed -isnot [bool] -or $record.confirmed -ne $true) { throw 'Incomplete manual observation.' }
    $date = [datetime]::MinValue
    if (-not [datetime]::TryParseExact([string]$record.updatedOn, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::None, [ref]$date) -or $date.Date -gt (Get-Date).Date) { throw 'Invalid public update date.' }
    $observed = [datetime]::MinValue
    if (-not [datetime]::TryParseExact([string]$record.observedOn, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::None, [ref]$observed) -or $observed.Date -ne (Get-Date).Date) {
        throw 'The public observation must be from today.'
    }
    $evidence = [string]$record.evidenceFile
    if (-not [System.IO.Path]::IsPathRooted($evidence)) { $evidence = Join-Path (Split-Path -Parent (Resolve-Path $Observation).Path) $evidence }
    if (-not (Test-Path -LiteralPath $evidence -PathType Leaf)) { throw 'Observation evidence file is missing.' }
    $url = 'https://play.google.com/store/apps/details?id=com.sza.filler&hl=en_US'
    $response = Invoke-WebRequest -Uri $url -Method Get -MaximumRedirection 3
    if ($response.StatusCode -ne 200 -or $response.BaseResponse.RequestMessage.RequestUri.Host -ne 'play.google.com') { throw 'Public page did not answer 200.' }
    $receipt = [ordered]@{ url = $url; httpStatus = $response.StatusCode; checkedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz');
        observation = $record; evidenceSha256 = (Get-FileHash -LiteralPath $evidence -Algorithm SHA256).Hash }
    $receipt | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutFile -Encoding utf8
    Write-Output 'PASS: public page answered 200; version, update date, description and image were manually attested by the named observer.'
    exit 0
} catch {
    Write-Output 'UNVERIFIED: public page could not be read or the manual observation and evidence are incomplete.'
    exit 2
}
