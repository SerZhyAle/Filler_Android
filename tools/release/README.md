# Release pipeline

The build side of a Filler release (S0023): the keys, the signing wiring, the pre-flight and its written verdict,
the update proof. Nothing here tags, pushes, uploads or publishes; that is the `release` skill's one-way step, run
only when the owner orders that exact release. The primary store channel is Google Play (the phone app and the watch app,
one application id `com.sza.filler`, one listing); on 2026-11-22 (`FILLER-0061`) the owner also authorized GitHub Releases
(signed phone and watch APKs plus `.sha256` sidecars) and SourceForge (`Files` + `Git` at mount point `git`).

| Script | Who, when | What it does |
| --- | --- | --- |
| `new-release-keys.ps1` | the owner, once | creates the app signing key, the upload key and the `keystore.properties` the build reads, in `P:\ANDROID\Filler_credentials` |
| `new-release-keys.ps1 -Rehearsal -Destination temp/<ticket>/keys` | a dry run | the same with throwaway keys and random passwords, under `temp/` only |
| `contract-sync.ps1 -Prepare [-Ref <commit>]` | first, before choosing a release version | generates the live contract catch-up spec |
| `contract-sync.ps1 -RecordReview [-Ref <commit>]` | after the candidate and catalog are reviewed | records the review for that commit and catalog state |
| `preflight.ps1 [-Ref <commit>] [-Keys <file>] [-Instant yyMMddHHmm]` | after contract catch-up | checks the review, builds and judges every package, writes the verdict (exit 0 PASS, 1 FAIL, 2 could not run) |
| `update-proof.ps1 -Serial <emulator> -Prior <apk> -Candidate <apk>` | after a PASS | installs the candidate over a real prior install and checks version, install identity and data |
| `check-play-preupload.ps1` | inside pre-flight, before offering a bundle | reads the AABs and fresh Play evidence; exit 0 PASS, 1 FAIL, 2 UNVERIFIED |
| `read-play-tracks.ps1` | after a commit, in an owner-supplied edit | reads tracks through the Play API, prints the reported commit mode, compares expected versionCodes and saves a receipt |
| `record-play-public.ps1` | after approval | records the owner's public-page observation and checks that the page answers 200 |

Run each as `pwsh -NoProfile -File tools/release/<script>.ps1 ..` from the repository root. `_release.ps1` holds
their shared helpers. Every script here is release tier: none has a recorded time of 5 seconds or less.

## Contract catch-up before a release

Before choosing the version, run `pwsh -NoProfile -File tools/release/contract-sync.ps1 -Prepare -Ref <candidate>`.
Read the generated `temp/release/contract-catchup.md` and the full current contract documents against that
candidate. Review the complete adoption inventory, existing exceptions and the logs since the last synchronized
versions. Fix a divergence or record a justified, dated exception with scope, evidence, impact, compensation,
responsibility, expiry, remediation and review condition. An exception never waives an independent Play, legal,
security or data-safety blocker. Update only this product's catalog rows and pointers; do not assert evidence
that has not been collected.

For an outstanding `behind`, `partial` or `pending` adoption, its own registry note also carries
`**Catch-up YYYY-MM-DD (FILLER-0000):**` (or legacy `S0000`) followed by the actual reason and the real remediation ticket. An older
reason that still carries `; until YYYY-MM-DD` reads the same. Nothing expires: an exception stands until
its row is closed. Unparsed or ahead rows are corrected.
The marker is a machine-readable index of the review, not a substitute for the exception or the review itself.
After reviewing the candidate and every remaining reason, run
`pwsh -NoProfile -File tools/release/contract-sync.ps1 -RecordReview -Ref <candidate>`. This writes a local
receipt tied to the candidate commit, today's date, the product's adoption and exception rows and the current
contract texts. A receipt is the operator's attestation; the script cannot prove the review was performed.

Preflight generates the spec again before it reads the clock and refuses to proceed if the receipt is missing,
stale, or the registry has an unresolved row without a valid reason. It repeats the check before its verdict;
changed catalog text, product rows, candidate or date require another review. `-ContractReceipt <file>` selects
another receipt; the default is `temp/release/contract-review.json`. An unreachable catalog is UNVERIFIED, not
a pass. A working-tree preflight remains a dry run and cannot produce a shippable verdict.

## The work folder

Every script that builds an APK hands it on to `C:\GD\WORK`, the synced work folder on the owner's PC (owner's order
of 2026-11-15). `-CopyTo <folder>` names another folder and `-CopyTo ''` turns the copy off; a folder that does not
exist is a warning, never an error and never created. The copy is `Copy-ApksToFolder` of `_release.ps1`. Both scripts
run from the launcher `a.ps1` at the repository root, the shape of FastMediaSorter's: `.\a.ps1` lists every command.

| Command | Script | APKs copied | Name in the folder |
| --- | --- | --- | --- |
| `.\a.ps1 d`, `dp`, `wd` (phone and watch, phone, watch) | `tools/builders/build-debug.ps1 -Module all\|phone\|wear`, `-NoBuild`, `-DryRun` | the debug APKs of the working tree, one Gradle invocation under the `Build.Main` lock, collected in the gitignored `DOWNLOADS/` | `filler-phone-debug-<versionName>.apk`, `filler-wear-debug-<versionName>.apk` |
| `.\a.ps1 r` | `preflight.ps1` | the two release APKs of the judged commit, after the verdict is written and whatever it says | `filler-phone-release-<versionName>.apk`, `filler-wear-release-<versionName>.apk` |
| preflight's Play check, or `check-play-preupload.ps1` directly | `check-play-preupload.ps1` | universal inspection APKs generated from the candidate and previous AABs | `filler-play-inspection-<candidate or previous>-<family>-<versionCode>.apk` |

The AABs are not copied; they stay in the verdict folder `temp/release/<versionName>/packages/` beside the release APKs and their `<apk>.sha256` checksum files (uploaded as GitHub Release assets for `SOURCEFORGE-CHANNEL` verification). `.\a.ps1 d -NoBuild` collects and copies the APKs of the last build
again without building. Options after a launcher command go to its script (`.\a.ps1 dp -CopyTo ''`, `.\a.ps1 r
-WorkingTree -Keys <file>`) and win over the command's preset. In an agent shell (`CLAUDECODE=1`) the launcher refuses
`d`, `dp`, `wd`, `r` and `fu` with exit 6 unless the call is dry (`-DryRun`, `-NoBuild`) or `FILLER_TIER=Release` says
it is a release run or one the owner named.

The Play inspection APKs are signed by bundletool for inspection; they are not the release-signed APKs. The Play
check uses the same `-CopyTo` as preflight, including an empty value to disable the copy.

## Keys and signing (G1, G2)

Owner decision of 2026-11-13: Play App Signing with the product's own app signing key plus a separate upload key.

| Key | File | Who reads it |
| --- | --- | --- |
| app signing key | `filler-app-signing.jks`, `app-signing.properties` | nobody in the build; the owner imports it into Play App Signing in the console |
| upload key | `filler-upload.jks`, `keystore.properties` | `:phone` and `:wear` sign every release package with it (buildSrc `ReleaseSigning`) |

The build reads one properties file, named by the environment variable `FILLER_KEYSTORE_PROPERTIES` or found as
`keystore.properties` at the repository root (ignored by git): `storeFile` (relative to the file's folder or
absolute), `storePassword`, `keyAlias`, `keyPassword`. Without it the release packages are built unsigned and each
module logs a warning; a named file that is missing, an empty entry or a missing key store fails the configuration.
The phone app and the watch app are always signed with the one upload key: they share the application id. Keeping
a backup of the credentials folder is the owner's.

## The verdict (G3)

`preflight.ps1` judges a commit extracted with `git archive` into `temp/rc/src`, pins one version instant for every
package, and writes `temp/release/<versionName>/`: `preflight.json` and `preflight.md` (the verdict naming the
version), a log per run, `packages/`, `reach-candidate.json`, `permissions.md`. Its header lists every check.

- **FAIL** is a defect of the candidate: undecided drift, a red gate or self-test, a leaked key, a failed build or
  test, a missing, unsigned, debug-signed or mixed-signature package, a wrong id or version, a family missing from
  the PACKAGE-VERSIONING band table, a contract with no registry row, a reach shrink, native code without notices,
  a permission the privacy records do not name. Any FAIL makes the verdict FAIL.
- **OPEN** is a precondition outside the build: rehearsal keys, a working-tree snapshot, a contract review that
  changed during preflight, or a listing without its "What's new". A pending contract row may carry a dated
  reason without claiming verification. The verdict can be PASS with OPEN checks; it is
  **shippable** only when it is PASS and nothing is OPEN.
- **WARN** is the release plan not validating; reconcile it and carry on.

`-WorkingTree` judges a snapshot of the tree for a dry run; its verdict is never shippable.

The rest of the pre-release sweep, each written into the same folder and each blocking on a FAIL:

- one `update-proof.ps1` PASS for the phone APK (a phone emulator) and one for the watch APK (a Wear OS emulator);
- the owner's manual items: the device checks of S0006 and S0020, the screenshots, the Play targetSdk requirement,
  stale track artifacts, the countries, and the console text against `docs/play`.

## Google Play evidence and bundle checks

The release record is `docs/play/PLAY_RELEASE_RECORD.md`. FILLER-0022 carries first-publication evidence. The
procedure below governs the upload and declaration order for that release. Require a version-specific shippable
preflight and the applicable Play API prerequisites before offering either bundle.

Before each preflight, copy `play-input.example.json` to `temp/release/play-input.json` and complete it from a
same-day console and release-history read. Set `history.complete` to true only after including every code ever used
by either family, including cancelled releases. Each entry is an object such as
`{"family":"phone","code":261115001}`. `previous.phone` and `previous.wear` are null only for a family that has
never used a code; otherwise each is `{"versionCode":123,"bundle":"path/to/previous.aab","sha256":"64 hex digits"}`
for its previous release. The path is absolute or relative to the input file. Keep the previous AAB itself in durable
owner-controlled storage, not the disposable preflight folder. The script verifies its hash, id and versionCode.
Read the history again immediately before offering a bundle and repeat the check if another upload has changed it.

Read both form-factor target API floors from Google's current target-API policy during that release, record the policy
URL, date and integer floors, and check that every older artifact still on any track meets its floor. `previous` and
the history come from the console plus the product's retained records; the track API alone omits cancelled releases.
For each new foreground-service permission and type, record the App content declaration, justification and date
in `foregroundServiceDeclaration`. Set `confirmed` after reading back the saved declaration in Play Console.
The first candidate adds `dataSync` for both families. Keep the Console evidence separately and use the first-use
procedure below if the form is unavailable. Unknown, incomplete or stale input yields UNVERIFIED.

Supply a standalone executable bundletool JAR with `-Bundletool <path>` or `FILLER_BUNDLETOOL_JAR`, and optionally
pass `-PlayState <path>` to preflight. The check generates a universal APK from each candidate AAB and previous AAB,
runs `aapt2 dump badging` for required and implied features, minSdk, targetSdk, ABIs, id and versionCode, and dumps
the merged base manifest for foreground-service permissions and types. It refuses any candidate code at or below the
highest code used by either family, a bundle version differing from the pin, an API below the recorded current floor, a newly required feature, raised minSdk or OpenGL ES requirement,
dropped ABI, or an undeclared new service type or permission. `play-check/` retains command lines, exit codes, output,
the input observations and the comparison. A missing tool or input marks `play-upload` OPEN, so the verdict is not
shippable. Missing or multiple feature groups also require a manual reach comparison and leave the gate OPEN. The
legacy `reach-candidate.json` from the separately built APK remains a secondary record only.

### Publish an authorized release through the Play Developer API

Follow the canon's Google Play release procedure, section 7, and `GOOGLE-PLAY` 0.4 sections 4 and 8. Use Play
Console for App content, review and managed-publishing actions as required by the exact release order. Use the API
for signed AAB transfer and track assignment after these checks.

1. **Check first-use evidence.** For `com.sza.filler`, record an accepted prior artifact from App bundle explorer
   or retained Play acceptance evidence. Include the versionCode, source and observation date. Record the merged
   manifest comparison and read back the saved declaration for every new type, covering both Filler `dataSync`
   uses with demonstrations. Stop before API writes if artifact history is missing or the declaration cannot be
   shown and saved. A draft track release requires a commit. Opening the form by making a draft or held commit,
   or saving the form inside an open edit, is forbidden by `GOOGLE-PLAY` section 8C. Follow the current API-only
   decision in the [release record](../../docs/play/PLAY_RELEASE_RECORD.md#first-use-and-access-evidence). Any
   future Console exception requires a documented safe sequence and separate owner authorization for the exact
   release and each outward step. [Edits guide](https://developers.google.com/android-publisher/edits),
   [edit concurrency](https://developers.google.com/android-publisher/concurrency-considerations),
   [App content policy](https://support.google.com/googleplay/android-developer/answer/13392821?hl=en).
2. **Confirm publisher access and the scope of the edit.** The service account named by
   `SZA_PLAY_SERVICE_ACCOUNT_JSON` needs app-scoped rights for the authorized operation. Check its rights under
   Play Console Users and permissions. Keep the key outside every repository. Confirm the exact track IDs for
   `com.sza.filler` and compare the track changes with the authorized release, including any existing releases
   or rollout affected by the update. The local ledger declares `internal` for phone and `wear:internal` for Wear
   OS. Use the identifiers returned for this app, including when they differ from those examples. First testing
   uses each form factor's internal track. Coordinate publishers, Console writes and edit-opening probes as one
   work stream for the application id. Finish and delete any track-discovery edit before starting the publisher.
   [Service-account setup](https://developers.google.com/android-publisher/getting_started?hl=en),
   [tracks guide](https://developers.google.com/android-publisher/tracks).
3. **Prepare one batch.** Use the guarded FastMediaSorter Python publisher from its checkout. Put the exact
   signed Filler AABs, pinned versionName, per-artifact versionCodes, track IDs and release notes into
   `play-batch.json` beside the candidate's `preflight.json`. Release notes carry one block per listing language, named
   by the `play` code of `tools/locale/locales.json`.
   When phone and Wear OS belong to the same release, stage both in one edit with one successful commit. A
   deliberately separate release waits for the previous app-wide review verdict. Approve changed listing content
   in the same batch when it ships with the release. Prepare an explicit Filler `listingRoot` from the approved
   sources when the API must stage that content. The publisher reads its `en-US`, `ru-RU` and `uk-UA` directories
   as Play locales `en-US`, `ru-RU` and `uk`; confirm the publisher's directory names for the other listing languages
   before the batch. Each directory carries `title.txt`, `short_description.txt`,
   `full_description.txt` and any approved images in the publisher's slot layout. Match outstanding Console
   changes to the approved batch as well.

   This example uses sample codes and track IDs. Substitute the AABs and values from the authorized candidate.

   ```json
   {
     "packageName": "com.sza.filler",
     "releases": [
       {
         "track": "internal",
         "status": "draft",
         "aab": "packages/filler-phone-2.61.1221.600.aab",
         "versionCode": 261122160,
         "versionName": "2.61.1221.600",
         "notesFile": "play-notes.txt"
       },
       {
         "track": "wear:internal",
         "status": "draft",
         "aab": "packages/filler-wear-2.61.1221.600.aab",
         "versionCode": 261122166,
         "versionName": "2.61.1221.600",
         "notesFile": "play-notes.txt"
       }
     ]
   }
   ```

4. **Bind the plan to evidence.** Use the following offline dry run and compare its `Planned operations` JSON
   with the shippable Filler verdict, bundle hashes, note languages and approved Play actions. Relative paths in
   the batch resolve from the batch file's directory.

   ```powershell
   $publisherRoot = 'P:/ANDROID/FastMediaSorter_mob_v2'
   $publisher = Join-Path $publisherRoot 'scripts/release/publish-play-release.py'
   $publisherPython = Join-Path $publisherRoot '.venv/Scripts/python.exe'
   & $publisherPython -B $publisher --batch '<candidate-folder>/play-batch.json' --dry-run
   ```

   Save `play-api-preflight.json` beside the batch with `packageName`, the exact `operations` array from the
   dry run, and the evidence references `authorization`, `acceptedArtifact`, `manifestComparison` and
   `newForegroundServices`. The first three references are strings. The last is an object mapping each new type
   to its saved App content evidence. Use an empty object when the observed manifest comparison has no new type.
   Tie the attestation to the shippable Filler verdict. The publisher requires this attestation as a separate
   input from Filler's build verdict.
5. **Commit once in an attended release.** Run the following only after the exact release has been authorized
   and the above checks pass. Immediately before each commit request, verify Publishing overview has no active
   app-wide review and that its pending changes match the authorized batch. Confirm in the publisher's terminal.

   ```powershell
   & $publisherPython -B $publisher --batch '<candidate-folder>/play-batch.json' --preflight '<candidate-folder>/play-api-preflight.json'
   ```

   Require `changesInReviewBehavior=ERROR_IF_IN_REVIEW` on both commit modes. The automatic mode can send
   pending Console changes to review. The held mode adds `changesNotSentForReview=true` only after the specific
   rule 18 refusal and a fresh app-wide review check. An active or unknown review, an unsupported guard or
   `CHANGES_ALREADY_IN_REVIEW` stops the release. If the commit result is indeterminate, reconcile it from
   independent read-back before another Play action. Never retry that commit. Keep the app serialized until
   the edit ends. [Commit reference](https://developers.google.com/android-publisher/api-ref/rest/v3/edits/commit).

   Retain the publisher's receipt from `%LOCALAPPDATA%/sza/play-publishing`. For an indeterminate result, read
   Publishing overview without writing to it. Wait for an active edit to end before using an edit-based probe.
   After independently confirming the outcome, record it with the publisher's reconciliation command. Use the
   observed outcome, `committed` or `not-committed`.

   ```powershell
   $reconcile = Join-Path $publisherRoot 'scripts/release/play_publishing.py'
   & $publisherPython -B $reconcile reconcile --package com.sza.filler --edit-id '<edit-id>' --outcome '<observed-outcome>' --evidence '<dated-read-back-reference>'
   ```

### Read back a committed release

After the publishing edit ends, open a separate serialized read edit and supply its id, an ambient OAuth access
token in `FILLER_PLAY_ACCESS_TOKEN`, and the recorded commit mode and evidence. Close the read edit after use.
The read-back script sends GET to the supplied edit. Replace the sample values with the approved batch:

```powershell
pwsh -NoProfile -File tools/release/read-play-tracks.ps1 -EditId '<read-edit-id>' -Expected 'internal=261122160,wear:internal=261122166' -CommitMode automatic -CommitEvidence '<publisher receipt>' -OutFile '<candidate-folder>/tracks.json'
```

Record `automatic` or `held` from the publisher receipt. Check the read-back's track, versionCode, release status,
rollout and notes languages against the approved operations. The script's PASS checks the expected versionCodes
on their expected tracks. The separate `applications.tracks.releases.list` GET reports a per-track lifecycle
without opening an edit. Save available lifecycle observations with their track and date. Use Publishing overview
for app-wide review and record policy claims and App content separately.
[Track lifecycle reference](https://developers.google.com/android-publisher/api-ref/rest/v3/applications.tracks.releases/list).

After approval, the owner reads the public store page itself. Complete `play-public.example.json` with the actual
version, updated date, first description lines, served image comparison, observer and a retained evidence file, then
run `pwsh -NoProfile -File tools/release/record-play-public.ps1 -Observation <json> -ExpectedVersion <approved-version> -OutFile <receipt>`. It verifies
that the public page answers 200 and labels the content observations as manual; it does not infer publication from
the API or independently prove the version, date or image. Add the result and each batch and verdict to the release
record. Review claims each need their own ticket.

## Update proof (G4)

Emulator only: the script uninstalls the package first. The prior is installed fresh and launched, the candidate
goes over it with `adb install -r`, and the device must report the candidate's versionCode with the same
`firstInstallTime`; on a userdebug image every data file of the prior is still there, and on an image that refuses
root (most Wear OS images) the data step is SKIP. For the first release the prior is the package of an earlier
pre-flight (two pre-flights, two instants); from then on it is the package last shipped to Play.

## Reach (G5)

The first release defines the secondary APK baseline: commit its `reach-candidate.json` as `tools/release/reach-baseline.json`
in the change that records the release. From then on each candidate is compared per package (phone, wear): a higher
minSdk, a newly named or dropped ABI, or a newly required feature is a FAIL that needs an owner decision before the
release. The watch package requires `android.hardware.type.watch` by design, so the baseline carries it. Countries
and form factors are console settings, kept as they are (all countries), and are checked in the console.
The Play pre-upload check above independently compares the universal APK made from each AAB with the previous AAB.

## Notices (G6)

Decision (S0023, unattended assumption of 2026-11-13, owner may overrule): the packages carry no
`THIRD-PARTY-NOTICES.txt` while they bundle no native code. The canon's notice rule binds third-party binaries; the
packages carry only JVM libraries (AndroidX, Material, Kotlin, coroutines, all Apache-2.0), and the app's own
licence is the MIT `LICENSE` of the public repository. The pre-flight fails a package that bundles native code
without the notices. The alternative weighed: a generated notices asset in every APK from the resolved runtime
inventory (StreamsPlayer's model), which the Apache-2.0 redistribution clause favours; it is the first thing to take
if the owner prefers it or a dependency brings native code.

## Ledger and "What's new" (G7)

Decision (S0023, unattended assumption of 2026-11-13, owner may overrule): no changelog ledger (`ledgerShape` stays
`none`, as in Tourist_mob). The release notes of a Filler release are the Play "What's new" text only, because Play is
the only channel. The release writes a `## What's new` section, at most 500 characters, as a shipped fact with no hedge
words, before the tag, into the three hand-written listing sources (`docs/play/PLAY_LISTING.md`, `PLAY_LISTING-ru.md`,
`PLAY_LISTING-uk.md`), translates the new English segments into `tools/locale/dictionaries/` and runs
`tools/locale/render-translations.ps1`, which writes the section into every other listing (FILLER-0079). Use those
sections to prepare the publisher's notes file with one block per listing language (`<en-US>`, `<ru-RU>`, `<uk>`,
`<de-DE>` and so on, the `play` codes of `tools/locale/locales.json`) and matching closing tags. Read back every
language on each released track. The preflight reports OPEN until every listing carries the section. The alternative weighed was a `CHANGELOG.md` ledger rendered into
the three texts, worth taking when a second channel (a GitHub Release) appears.

R8: the release variant of both apps is unminified (`isMinifyEnabled = false`, stated in each module's build
script) until a pre-flight proves a minified one on the release variant; turning it on is its own ticket.

## Release ledger (S0054)

`docs/releases/` holds the repository's release ledger (`RELEASE-LEDGER` 0.3, `docs/contracts/RELEASE-LEDGER.md`),
written through `pwsh -NoProfile -File tools/harness.ps1 releases/release-ledger <verb>`:

- `channels.json` declares the `phone` and `wear` packages, the four Google Play track entries (`play-phone-internal`,
  `play-phone-production`, `play-wear-internal`, `play-wear-production`) under `com.sza.filler`, and the two GitHub
  Releases entries (`github-phone`, `github-wear`) for `SerZhyAle/Filler_Android`.
- `Write-BuildLedger` (`tools/release/_release.ps1`) hooks `release-ledger build` as the last step of
  `tools/builders/build-debug.ps1` (`debug`) and `tools/release/preflight.ps1` (`release` on a passing commit candidate,
  `test` on a working-tree snapshot, rehearsal keys or non-PASS verdict). Any ledger failure prints a warning and never
  fails the build.
- During a release, record each observed track state with
  `release-ledger publish -Key <channel> -Version <versionName> -State <state>`. A `release-ledger probe` uses
  `SZA_PLAY_SERVICE_ACCOUNT_JSON` to read the declared tracks and may open a transient edit. Run it outside
  a publishing edit. Record public `live` through `release-ledger confirm` with the independently verified
  public store URL.
