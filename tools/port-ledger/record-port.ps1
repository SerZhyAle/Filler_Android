#requires -Version 7.0
<#
.SYNOPSIS
    Writes a ledger row: right after porting a file, or (-Refresh) after carrying a newer source version.

.DESCRIPTION
    Adds a row with the source file's SHA-256 as it is now (or the one given with -Sha256, for a port whose hash
    was recorded at the time and is imported later). With -Refresh the existing row takes the source's current
    hash, gets `carriedOn` and loses any `decision` (a carried version is no longer a deliberate difference).
    Paths are relative to their repository root with forward slashes (PORT-LEDGER rules 1 and 2).

.PARAMETER Source
    Path of the source file relative to the source root.

.PARAMETER Destination
    Path of the ported file relative to this repository's root.

.PARAMETER Sha256
    Use this hash instead of reading the source (an import of a hash recorded at port time).

.PARAMETER Kind
    full (default) or partial; a partial row needs -Region.

.PARAMETER WithDestinationHash
    Also record the destination's hash, so a later hand edit shows as LOCAL EDIT.

Exit codes: 0 row written; 2 refused or could not run (message names why).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Source,
    [Parameter(Mandatory)][string]$Destination,
    [string]$SourceRoot = '',
    [string]$RepoRoot = '',
    [string]$LedgerPath = '',
    [string]$Sha256 = '',
    [string]$PortedOn = '',
    [ValidateSet('full', 'partial')][string]$Kind = 'full',
    [string]$Region = '',
    [string[]]$Docs = @(),
    [switch]$WithDestinationHash,
    [switch]$Refresh
)

. (Join-Path $PSScriptRoot '_ledger.ps1')
if (-not $RepoRoot) { $RepoRoot = Get-LedgerRepoRoot }

function Stop-Record([string]$Message) {
    Write-Host "record-port: REFUSED ($Message)"
    exit 2
}

try {
    $config = Get-ExtractionConfig $RepoRoot
    if (-not $LedgerPath) { $LedgerPath = Join-Path $RepoRoot $config.Ledger }
    $srcRoot = Resolve-SourceRoot $SourceRoot $config.SourceProject
    if ($null -eq $srcRoot -and -not $Sha256) { Stop-Record 'no source root: pass -SourceRoot or set SZA_PORT_SOURCE_ROOT' }

    $sourceRel = ConvertTo-LedgerPath $Source
    $destRel = ConvertTo-LedgerPath $Destination
    if ($Kind -eq 'partial' -and [string]::IsNullOrWhiteSpace($Region)) { Stop-Record 'a partial row names the ported part: pass -Region' }
    $destPath = Join-Path $RepoRoot $destRel
    if (-not (Test-Path -LiteralPath $destPath -PathType Leaf)) { Stop-Record "destination does not exist: $destRel" }

    if ($Sha256) {
        if ($Sha256 -cnotmatch '^[0-9a-f]{64}$') { Stop-Record '-Sha256 is 64 lower-case hex digits' }
        $hash = $Sha256
    } else {
        $sourcePath = Join-Path $srcRoot.Root $sourceRel
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { Stop-Record "source file does not exist: $sourceRel" }
        $hash = Get-Sha256Hex $sourcePath
    }

    $rows = [System.Collections.Generic.List[object]]::new()
    if (Test-Path -LiteralPath $LedgerPath) { $rows.AddRange([object[]](Read-Ledger $LedgerPath)) }
    $existing = @($rows | Where-Object { $_.source -ceq $sourceRel -and $_.destination -ceq $destRel }) | Select-Object -First 1
    $today = (Get-Date).ToString('yyyy-MM-dd')

    if ($Refresh) {
        if ($null -eq $existing) { Stop-Record "no row for $sourceRel -> $destRel to refresh" }
        $existing.sourceSha256 = $hash
        $existing | Add-Member -NotePropertyName carriedOn -NotePropertyValue $today -Force
        if ($null -ne $existing.PSObject.Properties['decision']) { $existing.PSObject.Properties.Remove('decision') }
        if ($WithDestinationHash) { $existing | Add-Member -NotePropertyName destinationSha256 -NotePropertyValue (Get-Sha256Hex $destPath) -Force }
        $verb = 'CARRIED'
    } else {
        if ($null -ne $existing) { Stop-Record "a row for $sourceRel -> $destRel exists: use -Refresh to carry a newer version" }
        $row = [pscustomobject][ordered]@{
            source = $sourceRel; sourceSha256 = $hash; destination = $destRel
            portedOn = $(if ($PortedOn) { $PortedOn } else { $today })
        }
        if ($Kind -eq 'partial') {
            $row | Add-Member -NotePropertyName kind -NotePropertyValue 'partial'
            $row | Add-Member -NotePropertyName region -NotePropertyValue $Region
        }
        if ($WithDestinationHash) { $row | Add-Member -NotePropertyName destinationSha256 -NotePropertyValue (Get-Sha256Hex $destPath) }
        if ($Docs.Count -gt 0) { $row | Add-Member -NotePropertyName docs -NotePropertyValue @($Docs) }
        $rows.Add($row)
        $verb = 'ADDED'
    }
    Write-Ledger $LedgerPath $rows.ToArray()
    "record-port: $verb $sourceRel -> $destRel sha256=$($hash.Substring(0, 8))"
    exit 0
} catch {
    Stop-Record $_.Exception.Message
}
