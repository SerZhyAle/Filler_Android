#requires -Version 7.0
<#
.SYNOPSIS
    Run one isolated contract-review gate case. Supply -Case to keep each run in the fast tier.
.DESCRIPTION
    The fixture is a temporary catalog, not the shared catalog. It follows the contract ids in the
    candidate index and calls the real lag tool and gate. Each case keeps its own scratch for inspection.
    No deadline is judged: the reason case proves the catch-up marker needs no "until" part (the old form
    that still carries one reads the same) and "9999-12-31" opens no problem, and the expired case proves
    a past Until date opens no expiry problem either.
    Cases: fresh, record, changed, pending, reason, expired, unavailable, ahead.
    Exit 0 = expected result observed, 1 = assertion failed, 2 = fixture could not be made.
#>
[CmdletBinding()]
param(
    [ValidateSet('fresh', 'record', 'changed', 'pending', 'reason', 'expired', 'unavailable', 'ahead')]
    [string] $Case
)

$ErrorActionPreference = 'Stop'
try {
    if (-not $Case) { throw 'Choose one -Case (see the script header).' }
    $repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $index = @(& git -C $repo show 'HEAD:docs/contracts/README.md' 2>$null)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read the candidate contract index.' }
    $ids = @($index | Where-Object { $_ -match '^\| \[' } | ForEach-Object {
        $cell = ($_ -split '\|')[2]
        [regex]::Matches($cell, '`([A-Z0-9-]+)`') | ForEach-Object { $_.Groups[1].Value }
    } | Sort-Object -Unique)
    if ($ids.Count -eq 0) { throw 'No pointer ids in the candidate index.' }
    $target = $ids[0]
    $scratch = Join-Path $repo ('temp/contract-sync-tests/' + [guid]::NewGuid().ToString('N'))
    $catalog = Join-Path $scratch 'catalog'
    $meta = Join-Path $catalog '_meta'
    $null = New-Item -ItemType Directory -Force $meta
    $today = (Get-Date).Date
    $todayText = $today.ToString('yyyy-MM-dd')
    $future = $today.AddDays(1).ToString('yyyy-MM-dd')
    $past = $today.AddDays(-1).ToString('yyyy-MM-dd')
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in @('# Synthetic registry', '', '## 1. Contracts', '',
        '| Id | Folder | Version | Status |', '| --- | --- | --- | --- |')) { $lines.Add($line) }
    foreach ($id in $ids) {
        $folder = $id.ToLowerInvariant()
        $null = New-Item -ItemType Directory -Force (Join-Path $catalog $folder)
        [IO.File]::WriteAllText((Join-Path $catalog "$folder/README.md"), "# Synthetic $id`n")
        $lines.Add(('| `{0}` | [`{1}/`](../{1}/README.md) | 0.8 | draft |' -f $id, $folder))
    }
    foreach ($line in @('', '## 2. Adoption', '', '| Contract | Product | Role | Implements | Reads | Verified | Notes |',
        '| --- | --- | --- | --- | --- | --- | --- |')) { $lines.Add($line) }
    foreach ($id in $ids) {
        $version = if ($id -eq $target -and $Case -eq 'ahead') { '0.9' } else { '0.8' }
        $isOldForm = ($ids.Count -ge 2 -and $id -eq $ids[1])
        $verified = if (($id -eq $target -and $Case -in @('pending', 'reason')) -or
            ($isOldForm -and $Case -eq 'reason')) { 'pending' } else { $todayText }
        $note = if ($id -eq $target -and $Case -eq 'reason') {
            "**Catch-up $todayText (S0043):** Fixture reason and remediation."
        } elseif ($isOldForm -and $Case -eq 'reason') {
            "**Catch-up $todayText (S0042; until $future):** Old-form reason kept."
        } else { 'Synthetic fixture.' }
        $lines.Add(('| `{0}` | filler-mob | C | - | {1} | {2} | {3} |' -f $id, $version, $verified, $note))
    }
    foreach ($line in @('', '## 3. Exceptions', '', '| Contract | Product | Exception | Notes | Until |',
        '| --- | --- | --- | --- | --- |')) { $lines.Add($line) }
    if ($Case -in @('expired', 'reason')) {
        $until = if ($Case -eq 'expired') { $past } else { '9999-12-31' }
        $lines.Add(('| `{0}` 0.8 | filler-mob | Fixture | Fixture | {1} |' -f $target, $until))
    }
    [IO.File]::WriteAllLines((Join-Path $meta 'REGISTRY.md'), $lines, [Text.UTF8Encoding]::new($false))
    $receipt = Join-Path $scratch 'review.json'
    $spec = Join-Path $scratch 'catchup.md'
    $tool = Join-Path $PSScriptRoot 'contract-sync.ps1'
    function Invoke-Fixture([string[]] $Extra = @()) {
        $catalogArg = if ($Case -eq 'unavailable') { Join-Path $scratch 'missing' } else { $catalog }
        $output = & pwsh -NoProfile -File $tool -CatalogRoot $catalogArg -Receipt $receipt -SpecFile $spec @Extra 2>&1
        return [pscustomobject]@{ Code = $LASTEXITCODE; Output = ($output -join "`n") }
    }
    $result = switch ($Case) {
        'record' { Invoke-Fixture @('-RecordReview') }
        'reason' { Invoke-Fixture @('-RecordReview') }
        'changed' {
            $initial = Invoke-Fixture @('-RecordReview')
            if ($initial.Code -ne 0) { throw "Fixture review failed: $($initial.Output)" }
            Add-Content -LiteralPath (Join-Path $catalog ($target.ToLowerInvariant() + '/README.md')) -Value 'Changed contract.'
            Invoke-Fixture
        }
        default { Invoke-Fixture }
    }
    $expectedCode = if ($Case -in @('record', 'reason')) { 0 } elseif ($Case -eq 'unavailable') { 2 } else { 1 }
    $expectedText = switch ($Case) {
        'fresh' { 'no review receipt' }
        'record' { 'review recorded' }
        'changed' { 'does not match' }
        'pending' { 'no current dated catch-up reason' }
        'reason' { 'review recorded' }
        'expired' { 'no review receipt' }
        'unavailable' { 'UNVERIFIED' }
        'ahead' { 'ahead' }
    }
    $forbiddenText = if ($Case -eq 'expired') { 'expir' } else { $null }
    if ($result.Code -ne $expectedCode -or -not $result.Output.Contains($expectedText) -or
        ($forbiddenText -and $result.Output.Contains($forbiddenText))) {
        Write-Output "contract-sync-test: FAIL ($Case, expected exit $expectedCode and '$expectedText'; got $($result.Code))"
        Write-Output $result.Output
        exit 1
    }
    Write-Output "contract-sync-test: PASS ($Case, observed exit $($result.Code); fixture $scratch)"
    exit 0
} catch {
    Write-Output "contract-sync-test: UNVERIFIED - $($_.Exception.Message)"
    exit 2
}
