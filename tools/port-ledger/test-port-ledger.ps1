#requires -Version 7.0
<#
.SYNOPSIS
    Self-test of the port ledger tools on a throw-away tree; it touches neither this repository's ledger nor any
    source checkout.

.DESCRIPTION
    Builds a fake source tree and a fake derived repository under temp/port-ledger-selftest/, runs the PORT-LEDGER
    rule 13 cases (unchanged source, changed source, removed source, missing destination, a decision pinned to the
    current source version, a decision made stale by a second change, a file added to the source inside and
    outside the scope, a partial row, a destination edited by hand, an empty ledger, a source root that cannot be
    found) and the script-level paths (record-port, decide-drift, pass-start with a stub that files no ticket).
    The tree is removed at the end. The last line is the verdict: `test-port-ledger: PASS (n checks)` exits 0,
    `FAIL (..)` exits 1.
#>
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot '_ledger.ps1')
$tools = $PSScriptRoot
$repoRoot = Get-LedgerRepoRoot
$work = Join-Path $repoRoot ("temp/port-ledger-selftest/{0}" -f ([guid]::NewGuid().ToString('N').Substring(0, 8)))
$src = Join-Path $work 'source'
$repo = Join-Path $work 'repo'
$ledger = Join-Path $repo 'docs/port-ledger.jsonl'
$checks = 0
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-Equal($Actual, $Expected, [string]$Name) {
    $script:checks++
    if ("$Actual" -ne "$Expected") { $script:failures.Add("$Name (expected: $Expected | actual: $Actual)") }
}

function Set-File([string]$Root, [string]$Relative, [string]$Text) {
    $path = Join-Path $Root $Relative
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force
    [IO.File]::WriteAllText($path, $Text, [Text.UTF8Encoding]::new($false))
}

function Invoke-Tool([string]$Script, [string[]]$Arguments) {
    $output = & pwsh -NoProfile -File (Join-Path $tools $Script) @Arguments 2>&1
    [pscustomobject]@{ Exit = $LASTEXITCODE; Text = (@($output) -join "`n"); Last = (@($output) | Select-Object -Last 1) }
}

function Get-Status($Check, [string]$Source) {
    (@($Check.Rows | Where-Object { $_.Source -eq $Source }) | Select-Object -First 1).Status
}

function New-Fixture {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
    Set-File $src 'app/a.kt' 'alpha v1'
    Set-File $src 'app/b.kt' 'beta v1'
    Set-File $src 'app/sub/c.kt' 'gamma v1'
    Set-File $src 'other/z.kt' 'zeta v1'
    Set-File $repo 'dst/a.kt' 'alpha ported'
    Set-File $repo 'dst/b.kt' 'beta ported'
    Set-File $repo 'dst/c.kt' 'gamma ported'
    Set-File $repo 'docs/port-ledger.jsonl' ''
}

function Add-Port([string]$Source, [string]$Dest, [string[]]$Extra = @()) {
    Invoke-Tool 'record-port.ps1' (@('-Source', $Source, '-Destination', $Dest, '-SourceRoot', $src, '-RepoRoot', $repo) + $Extra)
}

function Get-Check([string]$Scope = '') {
    Invoke-PortCheck -RepoRoot $repo -SourceRootArg $src -ScopePath $Scope
}

try {
    # --- record-port, then the unchanged source
    New-Fixture
    $r = Add-Port 'app/a.kt' 'dst/a.kt'
    Assert-Equal $r.Exit 0 'record-port adds a row (exit)'
    Assert-Equal ($r.Last -like 'record-port: ADDED app/a.kt -> dst/a.kt sha256=*') $true 'record-port prints ADDED'
    Assert-Equal (Add-Port 'app/a.kt' 'dst/a.kt').Exit 2 'record-port refuses a duplicate row'
    Assert-Equal (Add-Port 'app/missing.kt' 'dst/a.kt').Exit 2 'record-port refuses a missing source'
    Assert-Equal (Add-Port 'app/b.kt' 'dst/nope.kt').Exit 2 'record-port refuses a missing destination'
    Assert-Equal (Add-Port 'app/b.kt' 'dst/b.kt' @('-Kind', 'partial')).Exit 2 'record-port refuses a partial row with no region'
    $row = (Read-Ledger $ledger)[0]
    Assert-Equal $row.sourceSha256 (Get-Sha256Hex (Join-Path $src 'app/a.kt')) 'row holds the source SHA-256'
    Assert-Equal ($row.sourceSha256 -cmatch '^[0-9a-f]{64}$') $true 'hash is lower-case hex'
    $c = Get-Check
    Assert-Equal (Get-Status $c 'app/a.kt') 'OK' 'unchanged source is OK'
    Assert-Equal $c.Exit 0 'unchanged source exits 0'
    $r = Invoke-Tool 'check-drift.ps1' @('-SourceRoot', $src, '-RepoRoot', $repo)
    Assert-Equal $r.Exit 0 'check-drift on an unchanged source exits 0'
    Assert-Equal ($r.Last -like 'check-drift: PASS (*scope NOT DECLARED*') $true 'verdict line says the scope is not declared'

    # --- changed source, then a decision, then a second change
    Set-File $src 'app/a.kt' 'alpha v2'
    $c = Get-Check
    Assert-Equal (Get-Status $c 'app/a.kt') 'DRIFT' 'changed source is DRIFT'
    Assert-Equal $c.Exit 1 'changed source exits 1'
    $r = Invoke-Tool 'check-drift.ps1' @('-SourceRoot', $src, '-RepoRoot', $repo)
    Assert-Equal $r.Exit 1 'check-drift on a changed source exits 1'
    Assert-Equal ($r.Last -like 'check-drift: FAIL (*') $true 'verdict line says FAIL'
    Assert-Equal (Invoke-Tool 'decide-drift.ps1' @('-Source', 'app/a.kt', '-Note', '', '-SourceRoot', $src, '-RepoRoot', $repo)).Exit 2 'decide-drift refuses an empty note'
    Assert-Equal (Invoke-Tool 'decide-drift.ps1' @('-Source', 'app/none.kt', '-Note', 'x', '-SourceRoot', $src, '-RepoRoot', $repo)).Exit 2 'decide-drift refuses an unknown source'
    $r = Invoke-Tool 'decide-drift.ps1' @('-Source', 'app/a.kt', '-Note', 'deliberate difference: not applicable here', '-SourceRoot', $src, '-RepoRoot', $repo)
    Assert-Equal $r.Exit 0 'decide-drift writes a decision'
    $c = Get-Check
    Assert-Equal (Get-Status $c 'app/a.kt') 'DECIDED' 'a decision pinned to the current version is DECIDED'
    Assert-Equal $c.Exit 0 'a decided drift exits 0'
    Assert-Equal (Invoke-Tool 'decide-drift.ps1' @('-Source', 'app/a.kt', '-Note', 'again', '-SourceRoot', $src, '-RepoRoot', $repo)).Exit 0 'a second decision at the same version is accepted (it re-pins)'
    Set-File $src 'app/a.kt' 'alpha v3'
    $c = Get-Check
    Assert-Equal (Get-Status $c 'app/a.kt') 'DRIFT' 'a decision made stale by a second change is DRIFT again'

    # --- carry: -Refresh takes the current hash, sets carriedOn, drops the decision
    $r = Invoke-Tool 'record-port.ps1' @('-Source', 'app/a.kt', '-Destination', 'dst/a.kt', '-SourceRoot', $src, '-RepoRoot', $repo, '-Refresh')
    Assert-Equal $r.Exit 0 'record-port -Refresh carries'
    $row = (Read-Ledger $ledger)[0]
    Assert-Equal (Get-RowProperty $row 'carriedOn') (Get-Date).ToString('yyyy-MM-dd') 'carriedOn is written'
    Assert-Equal ($null -eq $row.PSObject.Properties['decision']) $true 'a carry drops the decision'
    Assert-Equal (Get-Status (Get-Check) 'app/a.kt') 'OK' 'a carried row is OK'

    # --- removed source, missing destination
    Add-Port 'app/b.kt' 'dst/b.kt' | Out-Null
    Remove-Item -LiteralPath (Join-Path $src 'app/b.kt')
    $c = Get-Check
    Assert-Equal (Get-Status $c 'app/b.kt') 'SOURCE GONE' 'removed source is SOURCE GONE'
    Assert-Equal $c.Exit 1 'SOURCE GONE exits 1'
    Set-File $src 'app/b.kt' 'beta v1'
    Remove-Item -LiteralPath (Join-Path $repo 'dst/b.kt')
    $c = Get-Check
    Assert-Equal (Get-Status $c 'app/b.kt') 'NO DEST' 'missing destination is NO DEST'
    Assert-Equal $c.Exit 1 'NO DEST exits 1'
    Set-File $repo 'dst/b.kt' 'beta ported'

    # --- partial row, destination edited by hand
    Add-Port 'app/sub/c.kt' 'dst/c.kt' @('-Kind', 'partial', '-Region', 'the estimate block', '-WithDestinationHash') | Out-Null
    Assert-Equal (Get-Status (Get-Check) 'app/sub/c.kt') 'OK' 'a partial row in step is OK'
    Set-File $repo 'dst/c.kt' 'gamma edited by hand'
    $c = Get-Check
    Assert-Equal (Get-Status $c 'app/sub/c.kt') 'LOCAL EDIT' 'a hand-edited destination is LOCAL EDIT'
    Assert-Equal $c.Exit 0 'LOCAL EDIT never fails'
    Set-File $src 'app/sub/c.kt' 'gamma v2'
    $c = Get-Check
    Assert-Equal (Get-Status $c 'app/sub/c.kt') 'DRIFT' 'a change to a partial row is DRIFT'
    $r = Invoke-Tool 'check-drift.ps1' @('-SourceRoot', $src, '-RepoRoot', $repo)
    Assert-Equal ($r.Text -like '*partial: the estimate block; only part of the file is carried*') $true 'a partial row says only part is carried'

    # --- scope: a file added inside, outside and excluded with a reason
    New-Fixture
    Add-Port 'app/a.kt' 'dst/a.kt' | Out-Null
    $scopePath = Join-Path $repo 'docs/port-scope.json'
    Set-File $repo 'docs/port-scope.json' '{"include":["app/**"],"exclude":[{"glob":"app/skip/**","reason":"not part of the product"}]}'
    $c = Get-Check $scopePath
    Assert-Equal ($c.NewSource -join ',') 'app/b.kt,app/sub/c.kt' 'files inside the scope with no row are NEW SOURCE'
    Assert-Equal $c.Exit 1 'NEW SOURCE exits 1'
    Set-File $src 'app/skip/d.kt' 'excluded'
    Set-File $src 'other/y.kt' 'outside'
    Assert-Equal (Get-Check $scopePath).NewSource.Count 2 'an excluded file and an outside file are not NEW SOURCE'
    Set-File $repo 'docs/port-scope.json' '{"include":["app/**"],"exclude":[{"glob":"app/skip/**"}]}'
    $c = Get-Check $scopePath
    Assert-Equal $c.Exit 2 'an exclusion with no reason is COULD NOT VERIFY'
    Set-File $repo 'docs/port-scope.json' '{"include":["app/**"],"exclude":[{"glob":"app/skip/**","reason":"not part of the product"},{"glob":"app/b.kt","reason":"a"},{"glob":"app/sub/**","reason":"b"}]}'
    $c = Get-Check $scopePath
    Assert-Equal $c.Exit 0 'every file ported or excluded with a reason exits 0'
    # the profile's extraction block is read by the script
    Set-File $repo '.sza-profile.json' '{"extraction":{"ledger":"docs/port-ledger.jsonl","scope":"docs/port-scope.json"}}'
    $r = Invoke-Tool 'check-drift.ps1' @('-SourceRoot', $src, '-RepoRoot', $repo)
    Assert-Equal $r.Exit 0 'extraction.scope from the profile is applied'
    Assert-Equal ($r.Last -like '*scope declared*') $true 'verdict line says the scope is declared'

    # --- empty ledger, unresolvable source root, malformed ledger
    New-Fixture
    Assert-Equal (Get-Check).Exit 0 'an empty ledger is in step'
    $c = Invoke-PortCheck -RepoRoot $repo -SourceRootArg (Join-Path $work 'nowhere')
    Assert-Equal $c.Exit 2 'a source root that cannot be found is exit 2, never 0'
    $saved = $env:SZA_PORT_SOURCE_ROOT
    $env:SZA_PORT_SOURCE_ROOT = Join-Path $work 'nowhere'
    try {
        $r = Invoke-Tool 'check-drift.ps1' @('-RepoRoot', $repo)
        Assert-Equal $r.Exit 2 'check-drift with an unresolvable SZA_PORT_SOURCE_ROOT exits 2'
        Assert-Equal ($r.Last -like 'check-drift: COULD NOT VERIFY (*') $true 'verdict line says COULD NOT VERIFY'
        $env:SZA_PORT_SOURCE_ROOT = $src
        Assert-Equal (Invoke-Tool 'check-drift.ps1' @('-RepoRoot', $repo)).Exit 0 'SZA_PORT_SOURCE_ROOT names the source root'
    } finally { $env:SZA_PORT_SOURCE_ROOT = $saved }
    Set-File $repo 'docs/port-ledger.jsonl' "{`"source`":`"app/a.kt`"}`n"
    Assert-Equal (Get-Check).Exit 2 'a row that lacks required fields is exit 2'
    Set-File $repo 'docs/port-ledger.jsonl' "not json`n"
    Assert-Equal (Get-Check).Exit 2 'a line that is not JSON is exit 2'
    Remove-Item -LiteralPath $ledger
    Assert-Equal (Get-Check).Exit 2 'a missing ledger file is exit 2'

    # --- pass-start with a stub that files into the throw-away PLAN/
    New-Fixture
    Add-Port 'app/a.kt' 'dst/a.kt' | Out-Null
    $stub = Join-Path $work 'stub-spec-draft.ps1'
    Set-File $work 'stub-spec-draft.ps1' @'
param($Project, $Slug, $TextFile, $Priority)
$null = New-Item -ItemType Directory -Path (Join-Path $Project 'PLAN') -Force
Copy-Item -LiteralPath $TextFile -Destination (Join-Path $Project "PLAN/S9999_$Slug.md")
Write-Host 'drafted test:S9999 file=PLAN/S9999.md priority=60 pq=dispatchable position=1/1'
'@
    $r = Invoke-Tool 'pass-start.ps1' @('-SourceRoot', $src, '-RepoRoot', $repo, '-DraftTool', $stub)
    Assert-Equal ($r.Last -like 'pass-start: PASS (*') $true 'pass-start on a clean ledger passes'
    Assert-Equal (Test-Path (Join-Path $repo 'PLAN')) $false 'pass-start on a clean ledger files nothing'
    Set-File $src 'app/a.kt' 'alpha v2'
    $r = Invoke-Tool 'pass-start.ps1' @('-SourceRoot', $src, '-RepoRoot', $repo, '-DraftTool', $stub, '-NoFile')
    Assert-Equal ($r.Last -like 'pass-start: WOULD FILE (1 uncovered*') $true 'pass-start -NoFile reports without filing'
    Assert-Equal (Test-Path (Join-Path $repo 'PLAN')) $false '-NoFile files nothing'
    $r = Invoke-Tool 'pass-start.ps1' @('-SourceRoot', $src, '-RepoRoot', $repo, '-DraftTool', $stub)
    Assert-Equal ($r.Last -like 'pass-start: FILED (1 uncovered; drafted test:S9999*') $true 'pass-start files one Draft for an undecided drift'
    Assert-Equal $r.Exit 0 'pass-start exits 0 after filing'
    $filed = @(Get-ChildItem (Join-Path $repo 'PLAN') -Filter 'S9999_*.md')
    Assert-Equal $filed.Count 1 'one ticket text was written'
    Assert-Equal ([IO.File]::ReadAllText($filed[0].FullName) -like '*port-drift: app/a.kt DRIFT *') $true 'the ticket names the moved file and its hash token'
    $r = Invoke-Tool 'pass-start.ps1' @('-SourceRoot', $src, '-RepoRoot', $repo, '-DraftTool', $stub)
    Assert-Equal ($r.Last -like 'pass-start: TRACKED (1 uncovered*') $true 'a drift already named in a ticket is not filed twice'
    Assert-Equal @(Get-ChildItem (Join-Path $repo 'PLAN') -Filter 'S9999_*.md').Count 1 'no second ticket'
    Set-File $src 'app/a.kt' 'alpha v3'
    $r = Invoke-Tool 'pass-start.ps1' @('-SourceRoot', $src, '-RepoRoot', $repo, '-DraftTool', $stub)
    Assert-Equal ($r.Last -like 'pass-start: FILED*') $true 'a source that changed again has a new token and is filed again'
    $r = Invoke-Tool 'pass-start.ps1' @('-SourceRoot', (Join-Path $work 'nowhere'), '-RepoRoot', $repo, '-DraftTool', $stub)
    Assert-Equal ($r.Last -like 'pass-start: COULD NOT VERIFY (*') $true 'pass-start with no source root says so'
    Assert-Equal $r.Exit 0 'pass-start never fails a session'
} finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
    $parent = Split-Path -Parent $work
    if ((Test-Path -LiteralPath $parent) -and @(Get-ChildItem -LiteralPath $parent -Force).Count -eq 0) { Remove-Item -LiteralPath $parent -Force }
}

if ($failures.Count -eq 0) {
    "test-port-ledger: PASS ($checks checks)"
    exit 0
}
foreach ($failure in $failures) { "FAILED: $failure" }
"test-port-ledger: FAIL ($($failures.Count) of $checks checks failed)"
exit 1
