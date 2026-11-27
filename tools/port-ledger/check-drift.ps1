#requires -Version 7.0
<#
.SYNOPSIS
    Drift check of the port ledger: finds every ported file whose source changed since it was ported or carried.

.DESCRIPTION
    Reads the ledger and, when the profile declares one, the scope file; compares each row with the source
    product's checkout and prints one line per row that is not simply in step, then the status counts and a
    verdict line. It only reads the source and never writes to it (PORT-LEDGER rule 7). The verdict line is the
    last line on stdout: `check-drift: PASS (..)`, `FAIL (..)` or `COULD NOT VERIFY (..)`.

    This is the release preflight check (PORT-LEDGER rule 9): an uncovered row refuses the release until it is
    carried (record-port.ps1 -Refresh) or decided (decide-drift.ps1).

.PARAMETER SourceRoot
    The source checkout. Left out: SZA_PORT_SOURCE_ROOT, then the portfolio registry path of the profile's
    extraction.sourceProject.

.PARAMETER Json
    Print one JSON object (statuses, counts, verdict) instead of the lines.

.PARAMETER ShowAll
    Also list the rows that are in step.

Exit codes: 0 in step (only OK, DECIDED and LOCAL EDIT); 1 at least one DRIFT, SOURCE GONE, NO DEST or NEW
SOURCE; 2 COULD NOT VERIFY (no source root, a malformed ledger or scope file, a missing ledger).
#>
[CmdletBinding()]
param(
    [string]$SourceRoot = '',
    [string]$RepoRoot = '',
    [switch]$Json,
    [switch]$ShowAll
)

. (Join-Path $PSScriptRoot '_ledger.ps1')
if (-not $RepoRoot) { $RepoRoot = Get-LedgerRepoRoot }

$check = Invoke-PortCheck -RepoRoot $RepoRoot -SourceRootArg $SourceRoot

$verdict = switch ($check.Exit) {
    0 { 'PASS' }
    1 { 'FAIL' }
    default { 'COULD NOT VERIFY' }
}
$summary = if ($check.Exit -eq 2) { $check.Message } else {
    $parts = foreach ($name in $check.Counts.Keys) { "$name $($check.Counts[$name])" }
    $scopeNote = if ($check.ScopeDeclared) { 'scope declared' } else { 'scope NOT DECLARED: a file added to the source after the port is invisible' }
    "$($check.LedgerRows) rows, " + ($parts -join ', ') + "; $scopeNote; source root from $($check.SourceFrom)"
}

if ($Json) {
    [ordered]@{
        verdict = $verdict; exit = $check.Exit; message = $check.Message; counts = $check.Counts
        rows = @($check.Rows | Where-Object { $ShowAll -or $_.Status -ne 'OK' })
        newSource = $check.NewSource
    } | ConvertTo-Json -Depth 6
    exit $check.Exit
}

if ($check.Exit -ne 2) {
    foreach ($row in $check.Rows) {
        if (-not $ShowAll -and $row.Status -eq 'OK') { continue }
        $partial = if ($row.Kind -eq 'partial') { " (partial: $($row.Region); only part of the file is carried)" } else { '' }
        '{0,-11} {1} -> {2}{3}' -f $row.Status, $row.Source, $row.Destination, $partial
    }
    foreach ($path in $check.NewSource) { '{0,-11} {1}' -f 'NEW SOURCE', $path }
}
"check-drift: $verdict ($summary)"
exit $check.Exit
