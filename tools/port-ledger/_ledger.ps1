# _ledger.ps1 - shared functions of the port ledger tools (S0011). Dot-source only; it prints nothing.
#
# The format is the shared contract PORT-LEDGER 0.1 (rules 1 to 9): a JSON Lines ledger, one row per ported
# file, a drift check that gives each row one status, an optional scope file, and a source root found in a
# fixed order. This file follows the contract by its text; it shares no code with the sibling products' tools.
#
# Statuses (rule 4): OK, DECIDED, DRIFT, SOURCE GONE, NO DEST, LOCAL EDIT, and NEW SOURCE (scope file only).
# Failing statuses (rule 7): DRIFT, SOURCE GONE, NO DEST, NEW SOURCE.

Set-StrictMode -Version Latest

$script:FailingStatuses = @('DRIFT', 'SOURCE GONE', 'NO DEST', 'NEW SOURCE')
$script:DefaultLedgerPath = 'docs/port-ledger.jsonl'

function Get-LedgerRepoRoot {
    Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

function ConvertTo-LedgerPath([string]$Path) {
    ($Path -replace '\\', '/').Trim().TrimStart('/')
}

function Get-Sha256Hex([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try { $bytes = [Security.Cryptography.SHA256]::HashData($stream) } finally { $stream.Dispose() }
    ([BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant()
}

# The profile's `extraction` block (HARNESS-PROFILE rule 13): ledger, scope, sourceProject. Absent block or key
# reads as the contract's default (ledger docs/port-ledger.jsonl, no scope file, no source project).
function Get-ExtractionConfig([string]$RepoRoot) {
    $config = @{ Ledger = $script:DefaultLedgerPath; Scope = $null; SourceProject = $null }
    $profilePath = Join-Path $RepoRoot '.sza-profile.json'
    if (-not (Test-Path -LiteralPath $profilePath)) { return $config }
    $profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
    $block = $profile.PSObject.Properties['extraction']
    if ($null -eq $block) { return $config }
    foreach ($key in 'ledger', 'scope', 'sourceProject') {
        $prop = $block.Value.PSObject.Properties[$key]
        if ($null -ne $prop -and -not [string]::IsNullOrWhiteSpace([string]$prop.Value)) {
            $name = $key.Substring(0, 1).ToUpperInvariant() + $key.Substring(1)
            $config[$name] = [string]$prop.Value
        }
    }
    $config
}

function Get-PortfolioRegistryPath {
    $root = $env:SZA_PORTFOLIO_ROOT
    if ([string]::IsNullOrWhiteSpace($root)) {
        $userDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { [Environment]::GetFolderPath('UserProfile') }
        $root = Join-Path (Join-Path $userDir '.sza') 'portfolio'
    }
    Join-Path $root 'repos.json'
}

# Rule 8: an explicit argument, then SZA_PORT_SOURCE_ROOT, then the registry path of the source project. Never a
# path in a tracked file. Returns @{ Root; From } or $null when no step names an existing directory.
function Resolve-SourceRoot([string]$Explicit, [string]$SourceProject) {
    if (-not [string]::IsNullOrWhiteSpace($Explicit)) {
        if (Test-Path -LiteralPath $Explicit -PathType Container) { return @{ Root = (Resolve-Path -LiteralPath $Explicit).Path; From = 'argument' } }
        return $null
    }
    if (-not [string]::IsNullOrWhiteSpace($env:SZA_PORT_SOURCE_ROOT)) {
        if (Test-Path -LiteralPath $env:SZA_PORT_SOURCE_ROOT -PathType Container) {
            return @{ Root = (Resolve-Path -LiteralPath $env:SZA_PORT_SOURCE_ROOT).Path; From = 'SZA_PORT_SOURCE_ROOT' }
        }
        return $null
    }
    if (-not [string]::IsNullOrWhiteSpace($SourceProject)) {
        $registryPath = Get-PortfolioRegistryPath
        if (Test-Path -LiteralPath $registryPath) {
            $registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
            $entry = @($registry.repos | Where-Object { $_.key -eq $SourceProject }) | Select-Object -First 1
            if ($null -ne $entry -and (Test-Path -LiteralPath ([string]$entry.path) -PathType Container)) {
                return @{ Root = (Resolve-Path -LiteralPath ([string]$entry.path)).Path; From = "registry:$SourceProject" }
            }
        }
    }
    $null
}

# Every non-blank line must parse as a JSON object with the four required fields (rules 1 and 2).
function Read-Ledger([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "LedgerMissing: $Path" }
    $rows = [System.Collections.Generic.List[object]]::new()
    $lineNumber = 0
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        $lineNumber++
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try { $row = $line | ConvertFrom-Json } catch { throw "LedgerMalformed: ${Path}:$lineNumber is not JSON" }
        if ($row -isnot [pscustomobject]) { throw "LedgerMalformed: ${Path}:$lineNumber is not an object" }
        foreach ($field in 'source', 'sourceSha256', 'destination', 'portedOn') {
            $prop = $row.PSObject.Properties[$field]
            if ($null -eq $prop -or [string]::IsNullOrWhiteSpace([string]$prop.Value)) {
                throw "LedgerMalformed: ${Path}:$lineNumber lacks '$field'"
            }
        }
        $rows.Add($row)
    }
    , $rows.ToArray()
}

# JSON Lines, UTF-8 without BOM, LF, a final newline. A row is written with its fields in a fixed order.
function Write-Ledger([string]$Path, [object[]]$Rows) {
    $order = 'source', 'sourceSha256', 'destination', 'portedOn', 'carriedOn', 'kind', 'region', 'destinationSha256', 'docs', 'decision'
    $lines = foreach ($row in $Rows) {
        $ordered = [ordered]@{}
        foreach ($name in $order) {
            $prop = $row.PSObject.Properties[$name]
            if ($null -ne $prop) { $ordered[$name] = $prop.Value }
        }
        $ordered | ConvertTo-Json -Compress -Depth 6
    }
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }
    $text = if (@($lines).Count -gt 0) { (@($lines) -join "`n") + "`n" } else { '' }
    [IO.File]::WriteAllText($Path, $text, [Text.UTF8Encoding]::new($false))
}

function Get-RowProperty($Row, [string]$Name) {
    $prop = $Row.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    $prop.Value
}

# One status per row (rule 4). SOURCE GONE outranks NO DEST; LOCAL EDIT only replaces a non-failing status.
function Get-RowStatus($Row, [string]$SourceRoot, [string]$RepoRoot) {
    $sourcePath = Join-Path $SourceRoot (ConvertTo-LedgerPath $Row.source)
    $destPath = Join-Path $RepoRoot (ConvertTo-LedgerPath $Row.destination)
    $current = $null
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        $status = 'SOURCE GONE'
    } elseif (-not (Test-Path -LiteralPath $destPath -PathType Leaf)) {
        $status = 'NO DEST'
    } else {
        $current = Get-Sha256Hex $sourcePath
        $decision = Get-RowProperty $Row 'decision'
        if ($current -eq [string]$Row.sourceSha256) {
            $status = 'OK'
        } elseif ($null -ne $decision -and [string](Get-RowProperty $decision 'sourceSha256') -eq $current) {
            $status = 'DECIDED'
        } else {
            $status = 'DRIFT'
        }
        $destHash = Get-RowProperty $Row 'destinationSha256'
        if ($status -in 'OK', 'DECIDED' -and $destHash -and (Get-Sha256Hex $destPath) -ne [string]$destHash) {
            $status = 'LOCAL EDIT'
        }
    }
    [pscustomobject]@{
        Status = $status; Source = [string]$Row.source; Destination = [string]$Row.destination
        CurrentSha256 = $current; Kind = [string]((Get-RowProperty $Row 'kind') ?? 'full'); Region = Get-RowProperty $Row 'region'
    }
}

function ConvertTo-GlobRegex([string]$Glob) {
    $g = ConvertTo-LedgerPath $Glob
    $sb = [Text.StringBuilder]::new('^')
    for ($i = 0; $i -lt $g.Length; $i++) {
        $c = $g[$i]
        if ($c -eq '*' -and $i + 1 -lt $g.Length -and $g[$i + 1] -eq '*') {
            if ($i + 2 -lt $g.Length -and $g[$i + 2] -eq '/') { [void]$sb.Append('(?:.*/)?'); $i += 2 } else { [void]$sb.Append('.*'); $i += 1 }
        } elseif ($c -eq '*') { [void]$sb.Append('[^/]*')
        } elseif ($c -eq '?') { [void]$sb.Append('[^/]')
        } else { [void]$sb.Append([regex]::Escape([string]$c)) }
    }
    [void]$sb.Append('$')
    [regex]::new($sb.ToString(), 'IgnoreCase')
}

# The directory an include glob starts in: its path up to the first segment that holds a wildcard.
function Get-GlobBase([string]$Glob) {
    $segments = (ConvertTo-LedgerPath $Glob).Split('/')
    $kept = @(foreach ($segment in $segments) {
        if ($segment -match '[*?]') { break }
        $segment
    })
    # A glob with no wildcard names one file: its base is the directory above it.
    if ($kept.Count -eq $segments.Count) { $kept = @($kept | Select-Object -SkipLast 1) }
    $kept -join '/'
}

# Rule 5. Returns the source files inside `include`, outside every `exclude`, with no row: the NEW SOURCE list.
# An exclusion with no reason is malformed (throws).
function Get-NewSource([string]$ScopePath, [string]$SourceRoot, [object[]]$Rows) {
    $scope = Get-Content -LiteralPath $ScopePath -Raw | ConvertFrom-Json
    $includes = @($scope.include)
    if ($includes.Count -eq 0) { throw "ScopeMalformed: $ScopePath has no 'include'" }
    $excludes = foreach ($ex in @(Get-RowProperty $scope 'exclude')) {
        if ($null -eq $ex) { continue }
        if ([string]::IsNullOrWhiteSpace([string](Get-RowProperty $ex 'glob')) -or [string]::IsNullOrWhiteSpace([string](Get-RowProperty $ex 'reason'))) {
            throw "ScopeMalformed: $ScopePath has an exclusion with no glob or no reason"
        }
        ConvertTo-GlobRegex ([string]$ex.glob)
    }
    $known = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($row in $Rows) { [void]$known.Add((ConvertTo-LedgerPath $row.source)) }
    $found = [System.Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
    $rootLength = $SourceRoot.TrimEnd('\', '/').Length + 1
    foreach ($glob in $includes) {
        $regex = ConvertTo-GlobRegex ([string]$glob)
        $base = Join-Path $SourceRoot (Get-GlobBase ([string]$glob))
        if (-not (Test-Path -LiteralPath $base -PathType Container)) { continue }
        foreach ($file in [IO.Directory]::EnumerateFiles($base, '*', [IO.SearchOption]::AllDirectories)) {
            $relative = ConvertTo-LedgerPath $file.Substring($rootLength)
            if (-not $regex.IsMatch($relative) -or $known.Contains($relative)) { continue }
            if (@($excludes | Where-Object { $_.IsMatch($relative) }).Count -gt 0) { continue }
            [void]$found.Add($relative)
        }
    }
    @($found)
}

# The whole check, shared by check-drift, pass-start and the self-test. Never throws: a problem is Exit 2 and a
# message (rule 7: COULD NOT VERIFY, which a missing source root always is). Exit 0 in step, 1 an uncovered row.
function Invoke-PortCheck([string]$RepoRoot, [string]$SourceRootArg = '', [string]$LedgerPath = '', [string]$ScopePath = '') {
    $result = [pscustomobject]@{
        Exit = 2; Message = ''; Rows = @(); NewSource = @(); Counts = [ordered]@{}; SourceFrom = ''
        ScopeDeclared = $false; LedgerRows = 0
    }
    try {
        $config = Get-ExtractionConfig $RepoRoot
        $ledger = if ($LedgerPath) { $LedgerPath } else { Join-Path $RepoRoot $config.Ledger }
        $scope = if ($ScopePath) { $ScopePath } elseif ($config.Scope) { Join-Path $RepoRoot $config.Scope } else { $null }
        $source = Resolve-SourceRoot $SourceRootArg $config.SourceProject
        if ($null -eq $source) {
            $result.Message = 'no source root: pass -SourceRoot, set SZA_PORT_SOURCE_ROOT, or register the source project'
            return $result
        }
        $result.SourceFrom = $source.From
        $rows = Read-Ledger $ledger
        $result.LedgerRows = $rows.Count
        $result.Rows = @(foreach ($row in $rows) { Get-RowStatus $row $source.Root $RepoRoot })
        if ($scope) {
            if (-not (Test-Path -LiteralPath $scope)) { throw "ScopeMissing: $scope" }
            $result.ScopeDeclared = $true
            $result.NewSource = @(Get-NewSource $scope $source.Root $rows)
        }
        $counts = [ordered]@{}
        foreach ($status in 'OK', 'DECIDED', 'LOCAL EDIT', 'DRIFT', 'SOURCE GONE', 'NO DEST') {
            $counts[$status] = @($result.Rows | Where-Object { $_.Status -eq $status }).Count
        }
        if ($result.ScopeDeclared) { $counts['NEW SOURCE'] = $result.NewSource.Count }
        $result.Counts = $counts
        $uncovered = @($result.Rows | Where-Object { $_.Status -in $script:FailingStatuses }).Count + $result.NewSource.Count
        $result.Exit = if ($uncovered -gt 0) { 1 } else { 0 }
    } catch {
        $result.Exit = 2
        $result.Message = $_.Exception.Message
    }
    $result
}

# The uncovered rows of a check result as plain records: Status, Source, CurrentSha256, Destination.
function Get-UncoveredEntries($Check) {
    $entries = @($Check.Rows | Where-Object { $_.Status -in $script:FailingStatuses })
    $entries += @($Check.NewSource | ForEach-Object {
        [pscustomobject]@{ Status = 'NEW SOURCE'; Source = $_; Destination = ''; CurrentSha256 = $null; Kind = 'full'; Region = $null }
    })
    $entries
}
