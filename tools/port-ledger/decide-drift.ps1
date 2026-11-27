#requires -Version 7.0
<#
.SYNOPSIS
    Records that a newer source version is deliberately not carried, pinned to that exact version.

.DESCRIPTION
    Writes `decision` { sourceSha256, note, decidedOn } on the row of a drifting source file. The decision covers
    exactly the source hash read now (PORT-LEDGER rule 3): the next change to the source is drift again. Who may
    decide, and the three dispositions (port, not applicable, deliberate difference), are in docs/SPECIFICATION_SYNC_MODEL.md.

.PARAMETER Source
    Path of the drifting source file relative to the source root.

.PARAMETER Destination
    Needed only when the source has more than one row.

.PARAMETER Note
    Why the change is not carried: the disposition, the reason and the carrier ticket if there is one.

Exit codes: 0 decision written; 2 refused (no such row, not drifting, no note, no source root).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Source,
    [string]$Note = '',
    [string]$Destination = '',
    [string]$SourceRoot = '',
    [string]$RepoRoot = '',
    [string]$LedgerPath = ''
)

. (Join-Path $PSScriptRoot '_ledger.ps1')
if (-not $RepoRoot) { $RepoRoot = Get-LedgerRepoRoot }

function Stop-Decide([string]$Message) {
    Write-Host "decide-drift: REFUSED ($Message)"
    exit 2
}

try {
    if ([string]::IsNullOrWhiteSpace($Note)) { Stop-Decide 'a decision needs a note' }
    $config = Get-ExtractionConfig $RepoRoot
    if (-not $LedgerPath) { $LedgerPath = Join-Path $RepoRoot $config.Ledger }
    $srcRoot = Resolve-SourceRoot $SourceRoot $config.SourceProject
    if ($null -eq $srcRoot) { Stop-Decide 'no source root: pass -SourceRoot or set SZA_PORT_SOURCE_ROOT' }

    $sourceRel = ConvertTo-LedgerPath $Source
    $rows = [System.Collections.Generic.List[object]]::new([object[]](Read-Ledger $LedgerPath))
    $candidates = @($rows | Where-Object { $_.source -ceq $sourceRel -and (-not $Destination -or $_.destination -ceq (ConvertTo-LedgerPath $Destination)) })
    if ($candidates.Count -eq 0) { Stop-Decide "no ledger row for $sourceRel" }
    if ($candidates.Count -gt 1) { Stop-Decide "$sourceRel has $($candidates.Count) rows: pass -Destination" }
    $row = $candidates[0]

    $sourcePath = Join-Path $srcRoot.Root $sourceRel
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { Stop-Decide "source file does not exist: $sourceRel (SOURCE GONE is answered by removing or re-pointing the row)" }
    $current = Get-Sha256Hex $sourcePath
    if ($current -eq [string]$row.sourceSha256) { Stop-Decide "$sourceRel is in step: nothing to decide" }

    $decision = [pscustomobject][ordered]@{ sourceSha256 = $current; note = $Note.Trim(); decidedOn = (Get-Date).ToString('yyyy-MM-dd') }
    $row | Add-Member -NotePropertyName decision -NotePropertyValue $decision -Force
    Write-Ledger $LedgerPath $rows.ToArray()
    "decide-drift: DECIDED $sourceRel sha256=$($current.Substring(0, 8))"
    exit 0
} catch {
    Stop-Decide $_.Exception.Message
}
