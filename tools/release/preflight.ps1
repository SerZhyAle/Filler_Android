<#
.SYNOPSIS
    Filler's pre-flight (S0023 G3): builds every release package of a candidate from a clean source and writes a
    PASS/FAIL verdict that names the version it judged. A FAIL or no verdict blocks the release.

.DESCRIPTION
    Judges a commit (default HEAD) extracted with git archive into temp/rc/src, never the working tree, which
    carries other tickets' work. -WorkingTree judges a snapshot of the tree for a dry run; that verdict is never
    shippable. The version is pinned from one instant (-Instant yyMMddHHmm, default the clock now): every package
    carries its rendering, and the verdict folder is named by it.

    Before a version is chosen, regenerate the contract catch-up and require a review receipt bound to the
    candidate and current catalog. A missing or stale receipt stops pre-flight before the build.

    Checks, in order; each is PASS, WARN, OPEN or FAIL:
      contract-sync  catch-up reviewed for this candidate and current catalog before selecting the version
      source      the judged commit (OPEN for a working-tree snapshot)
      drift       tools/port-ledger/check-drift.ps1 of the judged source: exit 0, nothing undecided
      site        tools/site/check-site.ps1 of the judged source
      ledger-selftest  tools/port-ledger/test-port-ledger.ps1
      plan        the release plan validates (WARN only: plan drift is reconciled, never a blocker)
      leaks       no key, key store or keystore.properties among the files the candidate carries
      keys        the upload key's properties file is found (OPEN when it holds rehearsal keys)
      buildsrc    the version stamp and signing vectors, gradlew -p buildSrc test
      build       one Gradle invocation with the pinned pair: :filler-core:testDebugUnitTest,
                  :phone:testDebugUnitTest, :wear:testDebugUnitTest, then :phone and :wear assembleRelease
                  and bundleRelease
      packages    four packages: phone APK and AAB, watch APK and AAB
      ids         every APK is com.sza.filler (the frozen anchor)
      signatures  every package signed with one certificate, not a debug key
      version     read back from the APKs: one versionName equal to the pin, each versionCode its family's
      families    the Filler phone and watch families are rows of the PACKAGE-VERSIONING band table
      contracts   repeat the catch-up check and confirm every contract pointer has a registry row
      reach       per package against tools/release/reach-baseline.json: a shrink is a FAIL that needs an owner
                  decision; with no baseline the candidate defines it (reach-candidate.json)
      play-upload GOOGLE-PLAY checks on the AABs and fresh Play evidence, or OPEN if evidence/tools are missing
      notices     no package bundles native code without THIRD-PARTY-NOTICES.txt (decision: tools/release/README.md)
      privacy     the permissions read from the APKs against the privacy page and the Data safety record
      whats-new   each listing (en, ru, uk) carries a '## What's new' text Play can take (OPEN until written)

    The verdict is FAIL when any check fails, otherwise PASS; it is shippable only when it is PASS and nothing is
    OPEN. The device half (update-proof.ps1) and the owner's manual items are listed in tools/release/README.md.

    Output: temp/release/<versionName>/ - preflight.json and preflight.md (the verdict), one log per run,
    packages/, reach-candidate.json, permissions.md.

    The two release APKs are also copied, once the verdict is written, into -CopyTo (default C:\GD\WORK, the synced
    work folder) as filler-phone-release-<versionName>.apk and filler-wear-release-<versionName>.apk, whatever the
    verdict says: it is the owner's copy for a device, not a release step. -CopyTo '' turns the copy off; a folder
    that does not exist is a warning. The AABs stay in packages/.

.EXAMPLE
    pwsh -NoProfile -File tools/release/preflight.ps1
    pwsh -NoProfile -File tools/release/preflight.ps1 -Ref main -Keys P:\ANDROID\Filler_credentials\keystore.properties
    pwsh -NoProfile -File tools/release/preflight.ps1 -WorkingTree -Keys temp/S0023/keys/keystore.properties

.NOTES
    Exit codes: 0 verdict PASS, 1 verdict FAIL, 2 the pre-flight could not run.
#>
[CmdletBinding()]
param(
    [string] $Ref = 'HEAD',
    [switch] $WorkingTree,
    [string] $Keys,
    [string] $Instant,
    [string] $OutRoot,
    [string] $Baseline,
    [string] $PlayState,
    [string] $Bundletool,
    [string] $CopyTo,
    [string] $ContractReceipt
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_release.ps1')

# This must precede the clock read and all package work. A receipt is an explicit record of a review, not
# proof of the review's content; the operator performs the catalog catch-up as described in README.md.
$contractArgs = @('-Ref', $Ref)
if ($ContractReceipt) { $contractArgs += @('-Receipt', $ContractReceipt) }
$contractOut = & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'contract-sync.ps1') @contractArgs 2>&1
$contractExit = $LASTEXITCODE
$contractOut | ForEach-Object { Write-Output $_ }
if ($contractExit -ne 0) {
    Write-Output 'preflight: stopped before version selection; complete the contract catch-up first.'
    exit $(if ($contractExit -eq 1) { 1 } else { 2 })
}

# Not bound: the default work folder. Bound and empty: the copy is off.
if (-not $PSBoundParameters.ContainsKey('CopyTo')) { $CopyTo = $script:DefaultApkFolder }

if (-not $OutRoot) { $OutRoot = Join-Path $script:RepoRoot 'temp\release' }
if (-not $Baseline) { $Baseline = Join-Path $PSScriptRoot 'reach-baseline.json' }
if (-not $Instant) { $Instant = Get-Date -Format 'yyMMddHHmm' }

$checks = [System.Collections.Generic.List[object]]::new()
function Add-Check([string] $Id, [string] $Status, [string] $Detail) {
    $checks.Add([pscustomobject]@{ id = $Id; status = $Status; detail = $Detail })
    Write-Output ("  {0,-5} {1,-16} {2}" -f $Status, $Id, $Detail)
}
Add-Check 'contract-sync' 'PASS' (($contractOut | Select-Object -Last 1) -as [string])

$work = Join-Path $script:RepoRoot 'temp\rc'
$src = Join-Path $work 'src'
$marker = Join-Path $work '.preflight-scratch'
$out = Join-Path $OutRoot "pending-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$script:SourceLabel = 'not resolved'

function Write-Verdict([string] $Version) {
    $failed = @($checks | Where-Object status -eq 'FAIL')
    $open = @($checks | Where-Object status -eq 'OPEN')
    $verdict = if ($failed.Count) { 'FAIL' } else { 'PASS' }
    $result = [ordered]@{
        verdict = $verdict
        shippable = ($verdict -eq 'PASS' -and $open.Count -eq 0)
        version = $Version
        source = $script:SourceLabel
        judgedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
        checks = $checks
    }
    $result | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $out 'preflight.json') -Encoding utf8
    $md = @("# Pre-flight verdict: $verdict", '', "- Version judged: ``$Version``", "- Source: $($script:SourceLabel)",
        "- Shippable: $($result.shippable)$(if ($open.Count) { " ($($open.Count) open: $(($open | ForEach-Object id) -join ', '))" })",
        "- Judged at: $($result.judgedAt)", '', '| Check | Status | Detail |', '| --- | --- | --- |')
    $md += $checks | ForEach-Object { "| $($_.id) | $($_.status) | $($_.detail -replace '\|', '/') |" }
    Set-Content (Join-Path $out 'preflight.md') $md -Encoding utf8
    Write-Host ''
    Write-Host "VERDICT: $verdict for $Version (shippable: $($result.shippable)) -> $out"
    return $verdict
}

function Invoke-Gate([string] $Id, [string] $Script, [string[]] $Arguments = @()) {
    $gateOut = & pwsh -NoProfile -File (Join-Path $src $Script) @Arguments 2>&1
    $gateExit = $LASTEXITCODE
    $gateOut | Set-Content (Join-Path $out "$Id.log") -Encoding utf8
    $last = ($gateOut | Select-Object -Last 1) -as [string]
    Add-Check $Id $(if ($gateExit -eq 0) { 'PASS' } else { 'FAIL' }) "exit $gateExit - $last"
}

function Invoke-Gradle([string] $Log, [string[]] $Arguments) {
    Push-Location $src
    try {
        & .\gradlew.bat --no-daemon --console=plain @Arguments *> $Log
        $code = $LASTEXITCODE
    } finally { Pop-Location }
    $line = (Select-String -Path $Log -Pattern '^BUILD (SUCCESSFUL|FAILED)' | Select-Object -Last 1)
    return [pscustomobject]@{ exit = $code; line = $(if ($line) { $line.Line } else { 'no BUILD line' }) }
}

try {
    $pinName = ConvertTo-VersionName $Instant
    $pinCode = Get-VersionCode 'phone' $Instant

    # --- source ---------------------------------------------------------------------------------------------
    if ((Test-Path $work) -and -not (Test-Path $marker)) { throw "$work exists but is not this script's scratch; move it away first." }
    if (Test-Path $work) { Remove-Item -Recurse -Force $work }
    New-Item -ItemType Directory -Force $src, $out | Out-Null
    Set-Content $marker 'Scratch of tools/release/preflight.ps1; deleted and recreated on every run.'

    $commit = (git -C $script:RepoRoot rev-parse --verify "$Ref^{commit}" 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $commit) { throw "Ref '$Ref' is not a commit." }
    if ($WorkingTree) {
        $carried = @(git -C $script:RepoRoot ls-files -co --exclude-standard)
        $script:SourceLabel = "working-tree snapshot on $($commit.Substring(0, 12))"
        $null = robocopy $script:RepoRoot $src /E /NFL /NDL /NJH /NJS /NP `
            /XD build .gradle .kotlin .git .idea temp /XF keystore.properties *.jks *.keystore local.properties
        if ($LASTEXITCODE -ge 8) { throw "robocopy failed with $LASTEXITCODE." }
        Add-Check 'source' 'OPEN' "$($script:SourceLabel): a snapshot is a dry run, never a release candidate"
    } else {
        $carried = @(git -C $script:RepoRoot ls-tree -r --name-only $commit)
        $script:SourceLabel = "commit $commit"
        $tar = Join-Path $work 'src.tar'
        git -C $script:RepoRoot archive --format=tar -o $tar $commit
        if ($LASTEXITCODE -ne 0) { throw 'git archive failed.' }
        tar -xf $tar -C $src
        if ($LASTEXITCODE -ne 0) { throw 'tar could not extract the archive.' }
        Remove-Item $tar
        Add-Check 'source' 'PASS' $script:SourceLabel
    }
    Set-Content (Join-Path $src 'local.properties') ('sdk.dir=' + ((Get-SdkRoot) -replace '\\', '\\' -replace ':', '\:')) -Encoding ascii

    # --- script gates of the judged source --------------------------------------------------------------------
    Invoke-Gate 'drift' 'tools\port-ledger\check-drift.ps1'
    Invoke-Gate 'site' 'tools\site\check-site.ps1'
    Invoke-Gate 'ledger-selftest' 'tools\port-ledger\test-port-ledger.ps1'

    $planOut = & pwsh -NoProfile -File (Join-Path $script:RepoRoot 'tools\harness.ps1') spec_catalog/release-queue -Validate 2>&1
    $planExit = $LASTEXITCODE
    $planOut | Set-Content (Join-Path $out 'plan.log') -Encoding utf8
    Add-Check 'plan' $(if ($planExit -eq 0) { 'PASS' } else { 'WARN' }) "release-queue -Validate exit $planExit$(if ($planExit) { ' (run -Reconcile)' })"

    # --- leaks and keys ---------------------------------------------------------------------------------------
    $leaks = @($carried | Where-Object { $_ -match '(?i)(\.(jks|keystore|p12|pfx|pem)$)|((^|/)(keystore|signing|app-signing)\.properties$)|((^|/)\.env$)' })
    Add-Check 'leaks' $(if ($leaks.Count) { 'FAIL' } else { 'PASS' }) $(if ($leaks.Count) { "carried: $($leaks -join ', ')" } else { "$($carried.Count) files carried, no signing material" })

    if (-not $Keys) { $Keys = if ($env:FILLER_KEYSTORE_PROPERTIES) { $env:FILLER_KEYSTORE_PROPERTIES } else { Join-Path $script:CredentialsDir 'keystore.properties' } }
    if (-not [System.IO.Path]::IsPathRooted($Keys)) { $Keys = Join-Path $script:RepoRoot $Keys }
    if (-not (Test-Path $Keys)) {
        Add-Check 'keys' 'FAIL' "no upload key file at $Keys; every release package would be unsigned (tools/release/new-release-keys.ps1)"
        $null = Write-Verdict 'not built'
        exit 1
    }
    $Keys = (Resolve-Path $Keys).Path
    $rehearsal = [bool](Select-String -Path $Keys -Pattern '^# REHEARSAL' -Quiet)
    Add-Check 'keys' $(if ($rehearsal) { 'OPEN' } else { 'PASS' }) $(if ($rehearsal) { "rehearsal keys ($Keys): re-run with the owner's keys" } else { $Keys })

    # --- buildSrc and the build -------------------------------------------------------------------------------
    $logic = Invoke-Gradle (Join-Path $out 'buildsrc.log') @('-p', 'buildSrc', 'test')
    Add-Check 'buildsrc' $(if ($logic.exit -eq 0) { 'PASS' } else { 'FAIL' }) "gradlew -p buildSrc test exit $($logic.exit) - $($logic.line)"

    $tasks = @(':filler-core:testDebugUnitTest', ':phone:testDebugUnitTest', ':wear:testDebugUnitTest',
        ':phone:assembleRelease', ':phone:bundleRelease', ':wear:assembleRelease', ':wear:bundleRelease')
    $env:FILLER_KEYSTORE_PROPERTIES = $Keys
    try {
        $build = Invoke-Gradle (Join-Path $out 'build.log') ($tasks + @("-Pfiller.versionName=$pinName", "-Pfiller.versionCode=$pinCode"))
    } finally { Remove-Item Env:FILLER_KEYSTORE_PROPERTIES -ErrorAction SilentlyContinue }
    Add-Check 'build' $(if ($build.exit -eq 0) { 'PASS' } else { 'FAIL' }) "pin $pinName ($pinCode), gradlew exit $($build.exit) - $($build.line) ($($tasks.Count) tasks)"
    if ($build.exit -ne 0) {
        $null = Write-Verdict "$pinName (build failed)"
        exit 1
    }

    # --- packages, ids, signatures, version --------------------------------------------------------------------
    $expected = @(
        @{ family = 'phone'; kind = 'apk'; dir = 'phone\build\outputs\apk\release' },
        @{ family = 'phone'; kind = 'aab'; dir = 'phone\build\outputs\bundle\release' },
        @{ family = 'wear'; kind = 'apk'; dir = 'wear\build\outputs\apk\release' },
        @{ family = 'wear'; kind = 'aab'; dir = 'wear\build\outputs\bundle\release' })
    $packages = @(); $missing = @()
    foreach ($e in $expected) {
        $file = Get-ChildItem (Join-Path $src $e.dir) -Filter "*.$($e.kind)" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $file) { $missing += "$($e.family) .$($e.kind)"; continue }
        $packages += [pscustomobject]@{ family = $e.family; kind = $e.kind; path = $file.FullName; name = $file.Name
            signer = (Read-Signer $file.FullName); badging = $(if ($e.kind -eq 'apk') { Read-ApkBadging $file.FullName } else { $null }) }
    }
    Add-Check 'packages' $(if ($missing.Count) { 'FAIL' } else { 'PASS' }) $(if ($missing.Count) { "missing: $($missing -join ', ')" } else { "$($packages.Count) packages" })
    $apks = @($packages | Where-Object kind -eq 'apk')

    $badIds = @($apks | Where-Object { $_.badging.package -ne $script:AppId } | ForEach-Object { "$($_.family)=$($_.badging.package)" })
    Add-Check 'ids' $(if ($badIds.Count) { 'FAIL' } else { 'PASS' }) $(if ($badIds.Count) { "not the frozen anchor: $($badIds -join ', ')" } else { "$($script:AppId) (phone, wear)" })

    $sigProblems = @()
    $unsigned = @($packages | Where-Object { -not $_.signer } | ForEach-Object name)
    if ($unsigned.Count) { $sigProblems += "unsigned: $($unsigned -join ', ')" }
    $debug = @($packages | Where-Object { $_.signer -and $_.signer.subject -match 'CN=Android Debug' } | ForEach-Object name)
    if ($debug.Count) { $sigProblems += "debug key: $($debug -join ', ')" }
    $digests = @($packages | Where-Object signer | ForEach-Object { $_.signer.sha256 } | Sort-Object -Unique)
    if ($digests.Count -gt 1) { $sigProblems += "$($digests.Count) different certificates (one upload key signs both apps)" }
    Add-Check 'signatures' $(if ($sigProblems.Count) { 'FAIL' } else { 'PASS' }) $(if ($sigProblems.Count) { $sigProblems -join '; ' } else { "one upload certificate $(if ($digests.Count) { $digests[0].Substring(0, 16) }).. on $($packages.Count) packages" })

    $vProblems = @()
    foreach ($a in $apks) {
        if ($a.badging.versionName -ne $pinName) { $vProblems += "$($a.family) name $($a.badging.versionName), pinned $pinName" }
        $want = Get-VersionCode $a.family $Instant
        if ($a.badging.versionCode -ne $want) { $vProblems += "$($a.family) code $($a.badging.versionCode), expected $want" }
    }
    $codes = ($apks | ForEach-Object { "$($_.family) $($_.badging.versionCode)" }) -join ', '
    Add-Check 'version' $(if ($vProblems.Count) { 'FAIL' } else { 'PASS' }) $(if ($vProblems.Count) { $vProblems -join '; ' } else { "$pinName - $codes" })

    # The verdict folder is named by the version it judged; the packages and APK .sha256 sidecars are kept there under stable names.
    $final = Join-Path $OutRoot $pinName
    if (Test-Path $final) { Remove-Item -Recurse -Force $final }
    Move-Item $out $final
    $out = $final
    $pkgDir = Join-Path $out 'packages'
    New-Item -ItemType Directory -Force $pkgDir | Out-Null
    foreach ($p in $packages) {
        $dstName = "filler-$($p.family)-$pinName.$($p.kind)"
        $dstPath = Join-Path $pkgDir $dstName
        Copy-Item $p.path $dstPath
        if ($p.kind -eq 'apk') {
            $sha = (Get-FileHash -LiteralPath $dstPath -Algorithm SHA256).Hash.ToLowerInvariant()
            [IO.File]::WriteAllText("$dstPath.sha256", "$sha  $dstName`n", [Text.UTF8Encoding]::new($false))
        }
    }

    # --- families and contracts (the catalog CLAUDE.md names) -----------------------------------------------
    $claude = Get-Content (Join-Path $script:RepoRoot 'CLAUDE.md') -Raw
    $catalog = if ($claude -match 'in the catalog at `([^`]+)`') { $Matches[1] } else { $null }
    $registryFile = if ($catalog) { Join-Path $catalog '_meta\REGISTRY.md' } else { $null }
    if (-not $registryFile -or -not (Test-Path $registryFile)) {
        Add-Check 'families' 'OPEN' 'UNVERIFIED: the contracts catalog cannot be read from this machine'
        Add-Check 'contracts' 'OPEN' 'UNVERIFIED: the contracts catalog cannot be read from this machine'
    } else {
        $bandTable = Join-Path $catalog 'package-versioning\README.md'
        $bandText = if (Test-Path $bandTable) { Get-Content $bandTable -Raw } else { '' }
        $rowsFound = @('Filler phone', 'Filler watch app' | Where-Object { $bandText -match ('\|\s*' + [regex]::Escape($_) + '\s*\|\s*`com\.sza\.filler`') })
        Add-Check 'families' $(if ($rowsFound.Count -eq 2) { 'PASS' } else { 'FAIL' }) $(if ($rowsFound.Count -eq 2) { 'Filler phone and Filler watch app are rows of the PACKAGE-VERSIONING band table' } else { "PACKAGE-VERSIONING band table lacks: $((@('Filler phone', 'Filler watch app') | Where-Object { $_ -notin $rowsFound }) -join ', ')" })

        $rows = @(Get-Content $registryFile | Where-Object { $_ -match '^\| `[A-Z0-9-]+` \| filler-mob \|' })
        $registered = @($rows | ForEach-Object { ($_ -split '`')[1] })
        $contractCells = @(Get-Content (Join-Path $script:RepoRoot 'docs\contracts\README.md') | Where-Object { $_ -match '^\| \[' } | ForEach-Object { ($_ -split '\|')[2] })
        $absent = @(Get-UnregisteredContractIds $contractCells $registered)
        $pending = @($rows | Where-Object { $_ -match '\| pending \|' } | ForEach-Object { ($_ -split '`')[1] })
        $detail = @()
        if ($absent.Count) { $detail += "no filler-mob row: $($absent -join ', ')" }
        $repeat = & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'contract-sync.ps1') @contractArgs 2>&1
        $repeatExit = $LASTEXITCODE
        if ($repeatExit -ne 0) { $detail += "catch-up changed or unavailable: $(($repeat | Select-Object -Last 1) -as [string])" }
        if ($pending.Count) { $detail += "verification remains pending with dated reasons: $($pending -join ', ')" }
        $status = if ($absent.Count) { 'FAIL' } elseif ($repeatExit -ne 0) { 'OPEN' } else { 'PASS' }
        Add-Check 'contracts' $status $(if ($detail.Count) { $detail -join '; ' } else { "$($rows.Count) filler-mob rows, review still current" })
    }

    # --- reach ------------------------------------------------------------------------------------------------
    $reach = [ordered]@{}
    foreach ($a in $apks) {
        $reach[$a.family] = [ordered]@{ minSdk = $a.badging.minSdk; targetSdk = $a.badging.targetSdk
            nativeCode = $a.badging.nativeCode; requiredFeatures = $a.badging.requiredFeatures }
    }
    $reachJson = [ordered]@{ version = $pinName; source = $script:SourceLabel; packages = $reach } | ConvertTo-Json -Depth 5
    $reachJson | Set-Content (Join-Path $out 'reach-candidate.json') -Encoding utf8
    $candidate = ($reachJson | ConvertFrom-Json).packages
    $summary = ($apks | ForEach-Object { "$($_.family) min $($_.badging.minSdk) target $($_.badging.targetSdk)" }) -join ', '
    if (Test-Path $Baseline) {
        $base = Get-Content $Baseline -Raw | ConvertFrom-Json
        $shrinks = Compare-Reach $base.packages $candidate
        Add-Check 'reach' $(if ($shrinks.Count) { 'FAIL' } else { 'PASS' }) $(if ($shrinks.Count) { "shrinks against $($base.version): $($shrinks -join '; ') - an owner decision before the release" } else { "no shrink against $($base.version) ($summary)" })
    } else {
        Add-Check 'reach' 'PASS' "no shipped baseline: this candidate defines it ($summary); commit reach-candidate.json as tools/release/reach-baseline.json with the first release"
    }

    # The authoritative Play reach and foreground checks inspect the bundle, not the independently built APK.
    if (-not $PlayState) { $PlayState = Join-Path $script:RepoRoot 'temp\release\play-input.json' }
    if (-not $Bundletool) { $Bundletool = $env:FILLER_BUNDLETOOL_JAR }
    $phoneAab = @($packages | Where-Object { $_.family -eq 'phone' -and $_.kind -eq 'aab' })
    $wearAab = @($packages | Where-Object { $_.family -eq 'wear' -and $_.kind -eq 'aab' })
    if ($phoneAab.Count -ne 1 -or $wearAab.Count -ne 1) {
        Add-Check 'play-upload' 'FAIL' 'phone and watch AABs are required for the Play checks'
    } elseif (-not $Bundletool -or -not (Test-Path -LiteralPath $Bundletool -PathType Leaf) -or
              -not (Test-Path -LiteralPath $PlayState -PathType Leaf)) {
        Add-Check 'play-upload' 'OPEN' 'UNVERIFIED: supply fresh Play state and a standalone bundletool jar (tools/release/README.md)'
    } else {
        $playOut = & pwsh -NoProfile -File (Join-Path $src 'tools\release\check-play-preupload.ps1') `
            -PhoneBundle $phoneAab[0].path -WearBundle $wearAab[0].path -State $PlayState `
            -ExpectedVersion $pinName -ExpectedPhoneCode $pinCode -ExpectedWearCode (Get-VersionCode 'wear' $Instant) `
            -Bundletool $Bundletool -EvidenceDir (Join-Path $out 'play-check') -CopyTo $CopyTo 2>&1
        $playExit = $LASTEXITCODE
        $playOut | Set-Content -LiteralPath (Join-Path $out 'play-upload.log') -Encoding utf8
        $status = switch ($playExit) { 0 { 'PASS' } 1 { 'FAIL' } default { 'OPEN' } }
        Add-Check 'play-upload' $status "exit $playExit - $(($playOut | Select-Object -Last 1) -as [string])"
    }

    # --- notices ----------------------------------------------------------------------------------------------
    $needNotices = @()
    foreach ($a in $apks) {
        $entries = Get-ZipEntryNames $a.path
        $native = @($entries | Where-Object { $_ -match '^lib/.+\.so$' })
        if ($native.Count -and -not ($entries | Where-Object { $_ -match 'THIRD-PARTY-NOTICES\.txt$' })) { $needNotices += "$($a.family) ($($native.Count) .so)" }
    }
    Add-Check 'notices' $(if ($needNotices.Count) { 'FAIL' } else { 'PASS' }) $(if ($needNotices.Count) { "native code without THIRD-PARTY-NOTICES.txt: $($needNotices -join ', ')" } else { 'no package bundles native code' })

    # --- privacy ----------------------------------------------------------------------------------------------
    $dataSafety = Get-Content (Join-Path $src 'docs\play\PLAY_DATA_SAFETY.md') -Raw
    $perm = @('# Permissions per package', '', "Version $pinName, read from the built APKs with aapt2.", '')
    $privacyProblems = @()
    foreach ($a in $apks) {
        $perm += "## $($a.family)", ''
        $perm += @($a.badging.permissions | ForEach-Object { "- ``$_``" })
        if (-not @($a.badging.permissions).Count) { $perm += '- none' }
        $perm += ''
        $privacyProblems += Test-PermissionRecord $a.family $a.badging.permissions $dataSafety
    }
    Set-Content (Join-Path $out 'permissions.md') $perm -Encoding utf8
    Add-Check 'privacy' $(if ($privacyProblems.Count) { 'FAIL' } else { 'PASS' }) $(if ($privacyProblems.Count) { $privacyProblems -join '; ' } else { 'phone and watch permissions are in PLAY_DATA_SAFETY.md, no INTERNET (permissions.md)' })

    # --- What's new -------------------------------------------------------------------------------------------
    $notes = @()
    foreach ($listing in 'PLAY_LISTING.md', 'PLAY_LISTING-ru.md', 'PLAY_LISTING-uk.md') {
        $problem = Test-WhatsNew (Get-Content (Join-Path $src "docs\play\$listing") -Raw)
        if ($problem) { $notes += "$listing`: $problem" }
    }
    Add-Check 'whats-new' $(if ($notes.Count) { 'OPEN' } else { 'PASS' }) $(if ($notes.Count) { $notes -join '; ' } else { "What's new written in en, ru, uk" })

    $verdict = Write-Verdict $pinName

    # The synced work folder is a convenience: a failure to reach it must not turn a written verdict into exit 2.
    try {
        $null = Copy-ApksToFolder @($apks | ForEach-Object {
                [pscustomobject]@{ Source = $_.path; Name = "filler-$($_.family)-release-$pinName.apk" } }) $CopyTo
    } catch {
        Write-Warning "APKs not copied to ${CopyTo}: $($_.Exception.Message)"
    }

    $ledgerKind = if (-not $WorkingTree -and -not $rehearsal -and $verdict -eq 'PASS') { 'release' } else { 'test' }
    $ledgerFlags = @()
    if ($WorkingTree) { $ledgerFlags += 'working-tree' }
    if ($rehearsal) { $ledgerFlags += 'rehearsal' }
    $flagSuffix = if ($ledgerFlags.Count) { '; ' + ($ledgerFlags -join ', ') } else { '' }
    foreach ($fam in @('phone', 'wear')) {
        $aab = Join-Path $pkgDir "filler-$fam-$pinName.aab"
        $art = if (Test-Path -LiteralPath $aab -PathType Leaf) { $aab } else { Join-Path $pkgDir "filler-$fam-$pinName.apk" }
        Write-BuildLedger -Package $fam -Kind $ledgerKind -Version $pinName -Artifact $art `
            -Note ("versionCode {0}; verdict {1}{2}" -f (Get-VersionCode $fam $Instant), $verdict, $flagSuffix)
    }
    exit $(if ($verdict -eq 'PASS') { 0 } else { 1 })
} catch {
    Write-Error "preflight could not run: $($_.Exception.Message)" -ErrorAction Continue
    exit 2
}
