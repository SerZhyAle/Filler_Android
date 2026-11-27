<#
.SYNOPSIS
    Creates Filler's two release keys (S0023 G1) and the keystore.properties the build reads.

.DESCRIPTION
    Owner decision of 2026-11-13: Play App Signing with the product's own app signing key plus a separate upload
    key. The owner runs this once, in an interactive console; no agent creates anything under the credentials
    folder. Writes into -Destination (default P:\ANDROID\Filler_credentials, outside the repository):

      filler-app-signing.jks   the product's own key; imported into Play App Signing by the owner, never read by
                               the build (Play re-signs every download of the phone app and the watch app with it)
      filler-upload.jks        the separate upload key; signs every package the build makes for Play
      keystore.properties      the upload key's file, alias and passwords, the format buildSrc ReleaseSigning reads;
                               point FILLER_KEYSTORE_PROPERTIES at it
      app-signing.properties   the app signing key's file, alias and password, for the owner's console import only;
                               no build reads it

    Both keys are RSA 4096, PKCS12, valid 10000 days (Play wants validity past 2033-10-22). Passwords are asked
    twice each and reach keytool through the environment, never its command line. Nothing existing is overwritten.

    -Rehearsal writes throwaway keys with random passwords for a dry run of the pipeline. They are refused anywhere
    but under the repository's temp/ (gitignored); keystore.properties then starts with '# REHEARSAL', and the
    pre-flight never calls a verdict built on them shippable.

.EXAMPLE
    pwsh -NoProfile -File tools/release/new-release-keys.ps1
    pwsh -NoProfile -File tools/release/new-release-keys.ps1 -Rehearsal -Destination temp/S0023/keys

.NOTES
    Exit codes: 0 keys written, 1 refused (a file exists, the passwords differ or are short, a wrong destination),
    2 keytool failed.
#>
[CmdletBinding()]
param(
    [string] $Destination,
    [string] $DistinguishedName = 'CN=SZA Filler, O=SZA',
    [switch] $Rehearsal
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_release.ps1')

function Stop-Refused([string] $Message) {
    Write-Error $Message -ErrorAction Continue
    exit 1
}

if (-not $Destination) { $Destination = $script:CredentialsDir }
$target = [System.IO.Path]::GetFullPath($(if ([System.IO.Path]::IsPathRooted($Destination)) { $Destination } else { Join-Path $script:RepoRoot $Destination }))
$repoTemp = [System.IO.Path]::GetFullPath((Join-Path $script:RepoRoot 'temp')) + [System.IO.Path]::DirectorySeparatorChar
$insideRepo = ($target + '\').StartsWith($script:RepoRoot + '\', [StringComparison]::OrdinalIgnoreCase)
if ($Rehearsal -and -not $target.StartsWith($repoTemp, [StringComparison]::OrdinalIgnoreCase)) {
    Stop-Refused "Rehearsal keys go under $repoTemp only, not $target."
}
if (-not $Rehearsal -and $insideRepo) {
    Stop-Refused "Release keys never live inside the repository ($target); use a folder outside it."
}

$keys = @(
    @{ File = 'filler-app-signing.jks'; Alias = 'filler'; Role = 'app signing key'; Properties = 'app-signing.properties' },
    @{ File = 'filler-upload.jks'; Alias = 'filler-upload'; Role = 'upload key'; Properties = 'keystore.properties' }
)
foreach ($key in $keys) {
    foreach ($name in @($key.File, $key.Properties)) {
        $path = Join-Path $target $name
        if (Test-Path $path) { Stop-Refused "$path exists; this script never overwrites a key." }
    }
}

function Read-NewPassword([string] $Role) {
    if ($Rehearsal) {
        $bytes = [byte[]]::new(24)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
        return [Convert]::ToBase64String($bytes) -replace '[+/=]', 'x'
    }
    $first = [System.Net.NetworkCredential]::new('', (Read-Host "Password for the $Role (6 or more characters)" -AsSecureString)).Password
    $second = [System.Net.NetworkCredential]::new('', (Read-Host "Repeat the password for the $Role" -AsSecureString)).Password
    if ($first -ne $second) { Stop-Refused "The two passwords for the $Role differ." }
    if ($first.Length -lt 6) { Stop-Refused "keytool needs 6 or more characters for the $Role." }
    return $first
}

$keytool = Get-JdkTool 'keytool'
New-Item -ItemType Directory -Force $target | Out-Null
$header = if ($Rehearsal) { '# REHEARSAL keys of Filler: throwaway, nothing signed with them ever ships.' } else { '# Release keys of Filler (S0023). Never commit this file; keep a backup of the folder.' }
foreach ($key in $keys) {
    $password = Read-NewPassword $key.Role
    $store = Join-Path $target $key.File
    $env:FILLER_NEW_KEY_PASSWORD = $password
    try {
        & $keytool -genkeypair -keystore $store -storetype PKCS12 -alias $key.Alias -keyalg RSA -keysize 4096 `
            -validity 10000 -dname $DistinguishedName `
            -storepass:env FILLER_NEW_KEY_PASSWORD -keypass:env FILLER_NEW_KEY_PASSWORD 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "keytool failed to create the $($key.Role)." -ErrorAction Continue
            exit 2
        }
        $listing = & $keytool -list -v -keystore $store -storetype PKCS12 -storepass:env FILLER_NEW_KEY_PASSWORD 2>&1
        $sha = $listing | Select-String '^\s*SHA256: (.+)$' | Select-Object -First 1
        $key.Sha256 = if ($sha) { $sha.Matches[0].Groups[1].Value } else { '(not read)' }
    } finally {
        Remove-Item Env:FILLER_NEW_KEY_PASSWORD -ErrorAction SilentlyContinue
    }
    # PKCS12 keeps one password for the store and the key, so both entries carry it.
    Set-Content -Path (Join-Path $target $key.Properties) -Encoding ascii -Value @(
        $header, "# The $($key.Role)."
        "storeFile=$($key.File)", "storePassword=$password", "keyAlias=$($key.Alias)", "keyPassword=$password")
}

$kind = if ($Rehearsal) { 'Rehearsal keys (throwaway; never ship anything signed with them)' } else { 'Release keys' }
Write-Output "$kind written to $target"
foreach ($key in $keys) { Write-Output ("  {0,-24} {1,-16} SHA-256 {2}" -f $key.File, $key.Role, $key.Sha256) }
Write-Output "Point the build at the upload key: `$env:$($script:KeysEnv) = '$(Join-Path $target 'keystore.properties')'"
exit 0
