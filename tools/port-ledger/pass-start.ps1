#requires -Version 7.0
<#
.SYNOPSIS
    The pass-start drift check: runs the ledger check and, for an undecided drift, files a Draft ticket here.

.DESCRIPTION
    Wired as a SessionStart hook in .claude/settings.json, so it runs at the start of every Claude Code session
    in this repository, including each pass of the portfolio queue (pq). It runs the same check as
    check-drift.ps1. A source file that moved and has no carry or decision (DRIFT, SOURCE GONE, NO DEST, NEW
    SOURCE) opens ONE Draft ticket through the spec-draft flow, naming each file and its source hash; the queue
    works it in the next pass, so a FastMediaSorter change lands here within one pass of being detected.

    A file is filed once: every filed line carries the token `port-drift: <source> <status> <sha8>`, and a token
    that already appears in any ticket under PLAN/ (open, closed or archived) is not filed again. A source that
    changes again has a new hash and so a new token. The release preflight (check-drift.ps1) stays the backstop:
    it refuses on any uncovered row whether or not a ticket exists.

    Read-only unless it files; never writes to the source; never fails a session (exit 0 on every path, the
    verdict is the last line on stdout). A second pass-start running at the same moment skips (a named mutex).

.PARAMETER NoFile
    Report what would be filed and file nothing.

.PARAMETER DraftTool
    The script that files the Draft; default is the harness spec-draft through tools/harness.ps1. The self-test
    passes a stub. It is called with -Project, -Slug, -TextFile and -Priority and must print the spec-draft
    result line `drafted <key>:<id> ..`.
#>
[CmdletBinding()]
param(
    [string]$SourceRoot = '',
    [string]$RepoRoot = '',
    [string]$DraftTool = '',
    [switch]$NoFile
)

. (Join-Path $PSScriptRoot '_ledger.ps1')
if (-not $RepoRoot) { $RepoRoot = Get-LedgerRepoRoot }

function Close-PassStart([string]$Text) {
    Write-Host "pass-start: $Text"
    exit 0
}

$check = Invoke-PortCheck -RepoRoot $RepoRoot -SourceRootArg $SourceRoot
if ($check.Exit -eq 2) { Close-PassStart "COULD NOT VERIFY ($($check.Message))" }

$uncovered = @(Get-UncoveredEntries $check)
if ($uncovered.Count -eq 0) {
    Close-PassStart "PASS (port ledger in step: $($check.LedgerRows) rows, drift check clean)"
}

function Get-DriftToken($Entry) {
    $hash = if ($Entry.CurrentSha256) { $Entry.CurrentSha256.Substring(0, 8) } else { 'none' }
    "port-drift: $($Entry.Source) $($Entry.Status) $hash"
}

# Tokens already named in any ticket text under PLAN/ (open, closed, archived).
function Get-TrackedText([string]$Root) {
    $planDir = Join-Path $Root 'PLAN'
    if (-not (Test-Path -LiteralPath $planDir)) { return '' }
    (Get-ChildItem -LiteralPath $planDir -Filter '*.md' -File -Recurse | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n"
}

$mutex = [Threading.Mutex]::new($false, 'Global\filler-port-ledger-pass-start')
$held = $false
try {
    try { $held = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $held = $true }
    if (-not $held) { Close-PassStart 'SKIPPED (another pass-start is filing)' }

    $tracked = Get-TrackedText $RepoRoot
    $fresh = @($uncovered | Where-Object { -not $tracked.Contains((Get-DriftToken $_)) })
    if ($fresh.Count -eq 0) {
        Close-PassStart "TRACKED ($($uncovered.Count) uncovered, every one already named in a ticket; the release preflight still refuses until each is carried or decided)"
    }
    if ($NoFile) {
        foreach ($entry in $fresh) { Write-Host "would file: $(Get-DriftToken $entry)" }
        Close-PassStart "WOULD FILE ($($fresh.Count) uncovered, none filed: -NoFile)"
    }

    $lines = @(
        'The port-ledger drift check found FastMediaSorter files that moved with no carry and no decision.',
        'Each line below names a source file relative to the FastMediaSorter checkout and the first eight',
        'hex digits of its current SHA-256.',
        ''
    )
    foreach ($entry in $fresh) {
        $dest = if ($entry.Destination) { " (ported to $($entry.Destination))" } else { '' }
        $lines += "- $(Get-DriftToken $entry)$dest"
    }
    $lines += @(
        '',
        'What to do, per file (docs/SPECIFICATION_SYNC_MODEL.md section 4): read the source change, then record one disposition.',
        '- port: carry the change here, then run tools/port-ledger/record-port.ps1 -Refresh for the row;',
        '- not applicable, or a deliberate difference: run tools/port-ledger/decide-drift.ps1 with a note naming the reason;',
        '- NEW SOURCE: port it (record-port.ps1) or add an exclusion with a reason to docs/port-scope.json.',
        'The change is also entered in docs/PROGRESS_PORT_INTAKE.md. Verify with tools/port-ledger/check-drift.ps1 (exit 0).'
    )
    $scratch = Join-Path $RepoRoot 'temp/port-ledger'
    if (-not (Test-Path -LiteralPath $scratch)) { $null = New-Item -ItemType Directory -Path $scratch -Force }
    $textFile = Join-Path $scratch ("draft-{0}.md" -f (Get-Date).ToString('yyyyMMdd-HHmmss'))
    [IO.File]::WriteAllText($textFile, ($lines -join "`n") + "`n", [Text.UTF8Encoding]::new($false))

    $slug = 'port-drift-' + (Get-Date).ToString('yyyyMMdd-HHmm')
    $output = if ($DraftTool) {
        & pwsh -NoProfile -File $DraftTool -Project $RepoRoot -Slug $slug -TextFile $textFile -Priority 60 2>&1
    } else {
        & pwsh -NoProfile -File (Join-Path $RepoRoot 'tools/harness.ps1') portfolio/spec-draft -Project $RepoRoot -Slug $slug -TextFile $textFile -Priority 60 2>&1
    }
    $last = @($output | ForEach-Object { "$_" } | Where-Object { $_ -match '^drafted ' }) | Select-Object -Last 1
    if ($last) { Close-PassStart "FILED ($($fresh.Count) uncovered; $last)" }
    Close-PassStart ("COULD NOT FILE ($($fresh.Count) uncovered, spec-draft printed no result line: " + (($output | Select-Object -Last 1) -as [string]) + ')')
} finally {
    if ($held) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
