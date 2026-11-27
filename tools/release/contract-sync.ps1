#requires -Version 7.0
<#
.SYNOPSIS
    Prepare and check Filler's contract catch-up before choosing a release version.
.DESCRIPTION
    -Prepare generates the live spec. After reviewing the candidate and every relevant contract, use
    -RecordReview to record that review for the candidate commit and today's catalog state. The default
    mode regenerates the spec and checks that record. Neither mode asserts that a manual review happened.
    Outstanding behind, partial or pending rows need an explicit dated catch-up reason in their own adoption
    row: **Catch-up YYYY-MM-DD (S0000):** followed by the reason (an older reason that still carries
    "; until YYYY-MM-DD" reads the same). Nothing expires: an exception stands until its row is closed, and
    the registry's Until cell (9999-12-31, closed or permanent) is never compared with today. The actual
    exception and its scope still belong in the registry; independent release blockers are not waived.
    The candidate's contract index is read from the commit; a candidate that carries no copy (the pointers
    are local-only since REPO-LAYOUT 0.12 rule 8, FILLER-0071) is judged against the on-disk index.
    Exit 0 = prepared or matching record, 1 = incomplete or stale review, 2 = could not verify.
#>
[CmdletBinding()]
param(
    [switch] $Prepare,
    [switch] $RecordReview,
    [string] $Ref = 'HEAD',
    [string] $Receipt,
    [string] $SpecFile,
    [string] $CatalogRoot,
    [string] $CanonRoot
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
if (-not $Receipt) { $Receipt = Join-Path $repo 'temp/release/contract-review.json' }
$spec = if ($SpecFile) { [IO.Path]::GetFullPath($SpecFile) } else { Join-Path $repo 'temp/release/contract-catchup.md' }

try {
    if ($Prepare -and $RecordReview) { throw 'Choose -Prepare or -RecordReview, not both.' }
    $roots = @()
    if ($CanonRoot) {
        $roots = @($CanonRoot)
    } else {
        if ($env:SZA_HARNESS_ROOT) { $roots += (Split-Path (Split-Path $env:SZA_HARNESS_ROOT -Parent) -Parent) }
        $userRoot = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
        if ($userRoot) {
            $cache = Join-Path $userRoot '.claude/plugins/cache/sza-unified-rules/sza'
            if (Test-Path -LiteralPath $cache) {
                $roots += @(Get-ChildItem -LiteralPath $cache -Directory | Where-Object { $_.Name -as [version] } |
                    Sort-Object { [version]$_.Name } -Descending | ForEach-Object FullName)
            }
        }
        $roots += 'P:/WEB/sza-unified-rules'
    }
    $root = $roots | Where-Object {
        (Test-Path -LiteralPath (Join-Path $_ 'tools/contract-lag.ps1')) -and
        (Test-Path -LiteralPath (Join-Path $_ 'tools/lib/registry-tables.ps1'))
    } | Select-Object -First 1
    if (-not $root) { throw 'The canon contract-lag tool and registry reader are unavailable.' }
    $lagTool = Join-Path $root 'tools/contract-lag.ps1'
    $lagArgs = @('-Product', 'filler-mob')
    if ($CatalogRoot) { $lagArgs += @('-CatalogRoot', $CatalogRoot) }
    $null = New-Item -ItemType Directory -Force (Split-Path -Parent $spec)
    $emitted = & pwsh -NoProfile -File $lagTool @lagArgs -EmitSpec -OutFile $spec 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Could not generate catch-up spec: $($emitted -join ' ')" }
    $json = & pwsh -NoProfile -File $lagTool @lagArgs -Json 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Could not read contract status: $($json -join ' ')" }
    $report = ($json -join "`n") | ConvertFrom-Json
    $rows = @($report.rows | Where-Object { $_.product -eq 'filler-mob' })
    if ($rows.Count -eq 0) { throw 'The registry contains no filler-mob adoption rows.' }
    Write-Output ($emitted -join ' ')
    if ($Prepare) { exit 0 }

    $registry = Join-Path $report.catalog '_meta/REGISTRY.md'
    . (Join-Path $root 'tools/lib/registry-tables.ps1')
    $tables = @(Read-SzaRegistryTables $registry)
    $lines = [System.IO.File]::ReadAllLines($registry)
    $adoptions = @($tables | Where-Object { $_.section -like 'Adoption*' -and $_.cells.Product -eq 'filler-mob' })
    $exceptions = @($tables | Where-Object { $_.section -like 'Exceptions*' -and $_.cells.Product -eq 'filler-mob' })
    $definitions = @($tables | Where-Object { $_.section -like 'Contracts*' })
    $today = (Get-Date).Date
    $problems = [System.Collections.Generic.List[string]]::new()
    foreach ($row in $rows) {
        $adoption = @($adoptions | Where-Object { $_.cells.Contract -match ('`' + [regex]::Escape($row.contract) + '`') })
        if ($adoption.Count -ne 1 -or $adoption[0].cells.Verified -ne $row.verified) {
            throw "The registry changed while reading $($row.contract); retry the catch-up."
        }
        $definition = @($definitions | Where-Object { $_.cells.Id -eq ('`' + $row.contract + '`') })
        if ($definition.Count -ne 1 -or $definition[0].cells.Version -ne $row.current) {
            throw "The contract version changed while reading $($row.contract); retry the catch-up."
        }
        $cell = if ($adoption[0].cells.Implements -in @('', '-')) { $adoption[0].cells.Reads } else { $adoption[0].cells.Implements }
        if (-not $row.multiId -and $cell -ne $row.raw) {
            throw "The adoption changed while reading $($row.contract); retry the catch-up."
        }
        if (-not $lines[[int]$adoption[0].line - 1].Contains('| filler-mob |') -or
            -not $lines[[int]$adoption[0].line - 1].Contains('`' + $row.contract + '`')) {
            throw 'The registry shifted while reading it; retry the catch-up.'
        }
        if ($row.state -in @('unparsed', 'ahead')) { $problems.Add("$($row.contract): $($row.state)"); continue }
        if ($row.state -in @('behind', 'partial', 'pending')) {
            $line = $lines[[int]$adoption[0].line - 1]
            $m = [regex]::Match($line, 'Catch-up (\d{4}-\d{2}-\d{2}) \((?:FILLER-|S)\d{4}(; until \d{4}-\d{2}-\d{2})?\):\*\*\s*\S')
            $reviewed = [datetime]::MinValue
            if (-not $m.Success -or -not [datetime]::TryParseExact($m.Groups[1].Value, 'yyyy-MM-dd', $null, 'None', [ref]$reviewed) -or
                $reviewed -gt $today) {
                $problems.Add("$($row.contract): $($row.state), no current dated catch-up reason")
            }
        }
    }

    $commit = (& git -C $repo rev-parse --verify "$Ref^{commit}" 2>$null | Select-Object -First 1)
    if ($LASTEXITCODE -ne 0 -or -not $commit) { throw "Candidate ref '$Ref' is not a commit." }
    $index = @(& git -C $repo show "${commit}:docs/contracts/README.md" 2>$null)
    if ($LASTEXITCODE -ne 0) {
        # REPO-LAYOUT 0.12 rule 8 (FILLER-0071): docs/contracts/ is local-only, so a candidate commit after the
        # untracking carries no index. Judge the on-disk pointers, the live ledger of what this product adopts.
        $indexPath = Join-Path $repo 'docs/contracts/README.md'
        if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) { throw 'Cannot read the contract index: absent from the candidate and from disk.' }
        $index = @(Get-Content -LiteralPath $indexPath)
        Write-Output "contract-sync: the candidate carries no docs/contracts/README.md (local-only, REPO-LAYOUT 0.12 rule 8); judged the on-disk pointer index."
    }
    . (Join-Path $PSScriptRoot '_release.ps1')
    $cells = @($index | Where-Object { $_ -match '^\| \[' } | ForEach-Object { ($_ -split '\|')[2] })
    if ($cells.Count -eq 0) { throw 'The candidate contract index contains no pointer rows.' }
    $missing = @(Get-UnregisteredContractIds $cells @($rows.contract))
    foreach ($id in $missing) { $problems.Add("${id}: no adoption row") }
    if ($problems.Count) {
        $problems | ForEach-Object { Write-Output "  OPEN $_" }
        Write-Output "contract-sync: OPEN ($($problems.Count) issue(s)); review $spec"
        exit 1
    }

    # Bind a review to the candidate and this product's exact ledger entries and contract texts. Other
    # products' ledger edits do not invalidate it. The receipt is an attestation, not proof of observation.
    $material = [System.Collections.Generic.List[string]]::new()
    $material.Add("commit=$commit")
    $material.Add("date=$($today.ToString('yyyy-MM-dd'))")
    foreach ($entry in @($adoptions + $exceptions | Sort-Object line)) {
        $line = $lines[$entry.line - 1]
        if (-not $line.Contains('| filler-mob |') -or -not $line.Contains($entry.cells.Contract)) {
            throw 'The registry shifted while preparing the receipt; retry the catch-up.'
        }
        $material.Add($line)
    }
    foreach ($id in @($rows.contract | Sort-Object -Unique)) {
        $definition = @($definitions | Where-Object { $_.cells.Id -eq ('`' + $id + '`') })
        if ($definition.Count -ne 1 -or $definition[0].cells.Folder -notmatch '\[`([^`]+)`\]') { throw "Cannot locate contract $id." }
        $relative = $Matches[1].TrimEnd('/')
        $path = Join-Path $report.catalog $relative
        if (Test-Path -LiteralPath $path -PathType Container) { $path = Join-Path $path 'README.md' }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Cannot read contract $id." }
        $material.Add("$id=$((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash)")
    }
    $hash = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($material -join "`n"))))
    if ($RecordReview) {
        $null = New-Item -ItemType Directory -Force (Split-Path -Parent ([IO.Path]::GetFullPath($Receipt)))
        [ordered]@{ product = 'filler-mob'; commit = $commit; reviewed = $today.ToString('yyyy-MM-dd'); sha256 = $hash } |
            ConvertTo-Json | Set-Content -LiteralPath $Receipt -Encoding utf8
        Write-Output "contract-sync: review recorded for $commit; $($rows.Count) rows, receipt $Receipt"
        exit 0
    }
    if (-not (Test-Path -LiteralPath $Receipt -PathType Leaf)) {
        Write-Output "contract-sync: OPEN, no review receipt for $commit; read $spec"
        exit 1
    }
    $saved = Get-Content -LiteralPath $Receipt -Raw | ConvertFrom-Json
    if ($saved.product -ne 'filler-mob' -or $saved.commit -ne $commit -or $saved.reviewed -ne $today.ToString('yyyy-MM-dd') -or $saved.sha256 -ne $hash) {
        Write-Output 'contract-sync: OPEN, review receipt does not match the candidate, date or catalog state'
        exit 1
    }
    Write-Output "contract-sync: PASS ($($rows.Count) rows, reviewed $($saved.reviewed), candidate $commit)"
    exit 0
} catch {
    Write-Output "contract-sync: UNVERIFIED - $($_.Exception.Message)"
    exit 2
}
