# Google Play release record

One console app, `com.sza.filler`, receives the phone and Wear OS bundles. This is the release record for
`GOOGLE-PLAY` 0.7 sections 4, 8E, 9, 10 and 11. Store evidence references here and keep credentials outside the repository.
FILLER-0022 carries first-publication evidence. Follow the [release procedure](../../tools/release/README.md)
for Play API uploads and separately authorized Console actions.

## Signing and distribution

| Item | Decision or observation | Evidence still needed |
| --- | --- | --- |
| App signing | Product-owned app signing key, Play App Signing (owner, 2026-11-13) | Created 2026-11-17: `P:\ANDROID\Filler_credentials\filler-app-signing.jks`, alias `filler`, local SHA-256 `DE:D8:51:52:C6:31:42:6D:EF:2C:A1:D6:FB:FB:F9:B2:1F:55:85:A5:3E:62:88:5B:A0:FF:1B:84:56:FF:98:1D`. Imported 2026-11-17 (Change key, see below); console SHA-256 equal, character for character. |
| Upload signing | Separate product-owned upload key for both bundles | Created 2026-11-17: `filler-upload.jks`, alias `filler-upload`, local SHA-256 `25:16:C8:BE:E1:08:59:DA:C4:54:73:E2:FA:02:2C:99:C0:8B:7E:87:A1:6F:1F:3E:DE:80:99:25:C7:0C:97:53`, certificate `upload_certificate.pem` beside it. Registered 2026-11-17 in the same save as the app signing key; console SHA-256 equal, character for character. |
| Countries | All countries and regions available, including rest of world, never narrowed (S0022) | Before rollout record the actual selected country set, count, date, and rest-of-world choice from the console; compare later selections against it. |
| First internal testing link | One first publication per form factor goes through internal testing | Record the join URL and date after the owner creates it; the link is not known yet. |

Before the first upload, use `pepk` on OpenJDK or with signed BouncyCastle first on the classpath, as the contract's
rule 4 describes; the OpenJDK-only route is unverified in that contract, so verify the actual export exit code. Keep
passwords inside the owner's local process and never print them. After saving both keys in the
same preferences change, compare the app signing and upload fingerprints with their respective local certificates.
The fingerprints and the owner's sign-off are release evidence, not values inferred from a draft app.

### Key exchange in the console (2026-11-17, browser session on the owner's order)

- Before: App integrity has moved to Protected with Play > Play Store protection > Manage Play app signing. The app held
  a Google-generated app signing key, "In use", install base 0.0%, SHA-256
  `3B:B2:AB:27:9E:D1:82:A8:DD:BD:FE:B3:49:99:5C:62:41:5F:99:89:BF:4E:99:9B:A2:B8:A6:FD:1C:34:31:29`, with one row under
  "Previous app signing keys" (first used 13 Nov 2026, 16:55, 0%, "Quantum-ready (beta)"). Test and release showed every
  track empty ("Get started"), so nothing had been uploaded.
- Choice: Change key > "Export and upload a key from Java keystore" (the dialog also offers "Let Google manage" and "Use
  the same key as another app in this developer account"). The console's encryption public key for this app has SHA-256
  `4A9415A138B50DD2F35D8E19965A50F2283D086302D50CA60E3241420AAA23B3`, not the `0935D8..` key of the DeviceInfo exchange:
  the key is per app, so the zip was regenerated with it (`pepk` with signed BouncyCastle 1.79 first on the classpath,
  Oracle JDK 21, exit 0, 4394 bytes). The zip and `upload_certificate.pem` were attached in the same dialog and saved
  together (`GOOGLE-PLAY` rules 2-4). The `.pem` was attached by the owner: the browser tool refuses a `.pem` on the
  agent's word, as rule 3 records.
- After: the page shows the app signing key and a separate Upload key. Read back from the console's copy buttons:

| Key | Expected (local keystore) | Console | Equal |
| --- | --- | --- | --- |
| App signing | `DE:D8:51:52:C6:31:42:6D:EF:2C:A1:D6:FB:FB:F9:B2:1F:55:85:A5:3E:62:88:5B:A0:FF:1B:84:56:FF:98:1D` | `DE:D8:51:52:C6:31:42:6D:EF:2C:A1:D6:FB:FB:F9:B2:1F:55:85:A5:3E:62:88:5B:A0:FF:1B:84:56:FF:98:1D` | yes |
| Upload | `25:16:C8:BE:E1:08:59:DA:C4:54:73:E2:FA:02:2C:99:C0:8B:7E:87:A1:6F:1F:3E:DE:80:99:25:C7:0C:97:53` | `25:16:C8:BE:E1:08:59:DA:C4:54:73:E2:FA:02:2C:99:C0:8B:7E:87:A1:6F:1F:3E:DE:80:99:25:C7:0C:97:53` | yes |

## Bundles and used version codes

The 2026-11-17 Console observation showed empty tracks. The release record still lacks an accepted prior artifact.
Confirm acceptance in App bundle explorer or retained Play evidence before using the API publisher. Record the
versionCode, date and source. Before every upload, read the full history for both families, including cancelled
releases, and compare the current candidate with the previous artifact. Preserve each AAB that
reached a track in durable owner-controlled storage under a name containing its versionCode, with its SHA-256 and
the associated release evidence; do not rely on the disposable preflight folder. Preserve its embedded R8 mapping
and native symbols, if present. A bundle is never treated as absent merely because a track was cancelled.

| Date observed | Family | versionCode | Track and status | Bundle archive and SHA-256 |
| --- | --- | --- | --- | --- |
| No later observation recorded | - | - | - | - |

### First-use and access evidence

| Prerequisite | Recorded observation | Evidence required to proceed |
| --- | --- | --- |
| Accepted prior artifact for `com.sza.filler` | Empty tracks on 2026-11-17. Accepted artifact history unverified. | Dated artifact acceptance, or a documented and separately authorized bootstrap for the exact release. |
| Saved App content declaration covering both `dataSync` uses | Foreground service permissions was absent on 2026-11-17 and 2026-11-20. | Merged manifest comparison and the dated read-back of the saved declaration covering phone scheduled fill and Wear OS run. |
| Filler API permissions and track IDs | Service-account file available outside a Git worktree on 2026-11-22. App-scoped write permissions and exact target tracks unverified. | Console permission read-back for the requested operation and track discovery for this app. |

The first two rows stop API writes under `GOOGLE-PLAY` 0.7 section 8C while evidence is missing.
The owner kept the API-only upload order on 2026-11-22 (FILLER-0063). A Console bootstrap has no current
authorization. If accepted artifact history remains unavailable, the release waits for authoritative Google Play
guidance on first AAB acceptance and the applicable declaration. Review that evidence against section 8C
before offering a bundle.

## Review batches and verdicts

Phone and Wear OS changes included in the same release share one edit and one intended review submission (**Shape 1 - One salvo** under `GOOGLE-PLAY` 0.6 section 10 rule 31: phone and Wear OS tracks, release notes and changed listing in one edit when watch changed; unchanged watch omitted per rule 6). The machine-wide per-package lock `%LOCALAPPDATA%\sza\play-publishing\<package>.lock` (`GOOGLE-PLAY` 0.5 section 9) is held by the external FMS Python publisher and the canon `release-ledger probe`; this repository has no local script that calls `edits.insert`. Live track and release-notes reads follow `GOOGLE-PLAY` 0.7 section 11.
Record each submission below, including its id, change count and date. Serialize deliberately separate batches
and wait for the app-wide review verdict before the next commit. The first bundle of each form factor goes to
its internal-testing track before production, subject to the first-use requirements above.
Screenshots, the watch testing bundle, and the Wear OS opt-in follow the order of `GOOGLE-PLAY` rule 12.

| Submitted date | Submission ID | Change count | Changes and versionCodes | Commit mode and evidence | Verdict reference |
| --- | --- | --- | --- | --- | --- |
| No submission recorded | - | - | - | - | - |

For every verdict, add a row with the date, routing id, all versionCodes named, each claim separately and its own
carrier ticket. Do not attribute a watch-only claim to the phone. An approved batch is proven public only after the
public page has been read, including its update date, version, description and served image evidence.

| Verdict date | Routing id | Named versionCodes | Claim | Carrier ticket | Public-page evidence |
| --- | --- | --- | --- | --- | --- |
| No verdict recorded | - | - | - | - | - |

## Per-release evidence

`tools/release/README.md` gives the pre-upload input and read-back commands. Keep their commands, exit codes,
output, manual observations and the final receipt with the release. Record the exact authorization, approved
batch, edit ownership, app-wide review check before each commit request, review guard, mode and result. Retain
the qualifying refusal for a held commit and the independent reconciliation of any indeterminate result.
After commit, record the track codes, rollout and notes, then any track lifecycle summary with its date. Keep
the Console review batch, policy claims and public-page observation as separate evidence.

Read the current target API floors, check stale artifacts on every track, and confirm the App content answers
against the store build. For the watch, the owner proves the release build on the 192 dp and 227 dp round shapes,
including mid-gesture, before review
(S0020). A Play warning is not counted as cleared until the contract's required uploads show it gone.
