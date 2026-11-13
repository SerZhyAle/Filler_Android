# S0002 - Standalone Android app skeleton

**Ticket:** S0002
**Status:** Verified
**Priority:** 70
**Tier:** 3 - Moderate
**Complexity:** medium - assessed at the spec pass: one new Gradle build with one module, one version-stamp implementation with its fixed-instant tests, one activity and its resources, and the first contract pointer; no screen logic, no storage code, no signing. Read against the plan: the level stands.
**Depends on:** S0001

## Goal

Create a minimal independently buildable phone project under this root, with its own Gradle configuration and an entry point ready for the Filler port. Follow the completed project foundation and current Android overlay rules. Keep `P:/ANDROID/FastMediaSorter_mob_v2` untouched.

## Acceptance

- A local debug build can be built independently with an explicit provisional application ID, not presented as a published or frozen identifier.
- Own dependency versions, tooling and resources are declared and the independent build does not depend on the FastMediaSorter checkout.
- No release is signed, published or uploaded. Leave signing, final ID, distribution and branding to the release ticket.
- Record the build and relevant verification per the project rules.

### 3.3 Owner inputs (Approval gate)

- **Related tickets:** S0001 foundation; S0003 through S0007 follow.
- **Provisional application id:** `com.sza.filler.provisional`, chosen at the spec pass (2026-11-10) because the ticket requires an explicit provisional id and the owner has not chosen the published one. It is not an anchor: S0007 replaces it, and the build refuses every release packaging task while it is in force.
- **Owner decisions this ticket records and does not take:** published application id and its freeze, signing key and Play signing mode, license, public remote, distribution channel, store name and branding - carried to S0007 (see the open questions).
- **Contract boundary:** yes - `PACKAGE-VERSIONING`, Android profile (consumer). Declared here; the band-table amendment needs the published id and is carried to S0007.

## Spec pass (2026-11-10)

- **Rung:** complex pipeline. Forced upward by the primitive test: more than three files, new files, a new build, a new public type and a contract declaration.
- **Baseline before any edit:** `phone/src` holds empty `main` and `test` folders and the tree has no Gradle file; the machine has JDK 21 (`JAVA_HOME`), Android SDK platforms 35 to 37.1 and build-tools 34 to 36.1 under `C:\Users\serzh\AppData\Local\Android\Sdk`, and a cached Gradle 9.4.1 distribution; `ANDROID_HOME` is not set, so the build needs a gitignored `local.properties` with `sdk.dir`.
- **Settled without asking** (the records answer them):
  - **Toolchain pins** follow the upstream's current values, read read-only on 2026-11-10 from `FastMediaSorter_mob_v2` (`gradle/libs.versions.toml`, `docs/TECH_STACK.md`, `app_v2/build.gradle.kts`): Gradle 9.4.1, AGP 9.2.1, Kotlin 2.2.10 (AGP built-in Kotlin), compileSdk 37, targetSdk 37, minSdk 26 (the upstream standard flavor), bytecode target 17, AppCompat 1.7.1, Material 1.14.0, JUnit 4.13.2 (core-ktx is not declared: nothing here uses it). Kotlin has no catalog entry because it follows AGP; the debug runtime classpath resolves `kotlin-stdlib` to 2.2.10. The two products share no build: a pin moves here on its own ticket, never by reference. The port tickets re-read the upstream pins before porting.
  - **targetSdk 37 rather than the sibling's 36:** the Filler code being ported was written and is being tested against the upstream's targetSdk 37, so the storage behaviour it meets at run time must be the same. S0007 re-checks the Play requirement.
  - **UI toolkit:** the upstream Filler is an XML layout activity (`FillerActivity`, `activity_filler.xml`, a landscape variant), so the entry point is an AppCompat activity over an XML layout. No DI framework, database or compose dependency is added; the port tickets add what the ported code needs.
  - **Build-logic form:** `buildSrc` holding one pure Kotlin object, because a single module needs no convention plugin; a second module would move it into one.
  - **Version stamp:** every build stamps itself from one clock reading at configuration time (Android profile rule 6); no checked-in sentinel exists, so rules 7 and 8 have nothing to drift. A release orchestrator's pair `-Pfiller.versionName` plus `-Pfiller.versionCode` is accepted together or not at all and is refused when the two do not describe one instant (rule 5). The phone family's band map is `floor(minute / 10)`; no watch product is assumed.
  - **Contract boundary and the catalog amendment:** the contract's boundary is the moment a channel receives a package (its section 1); a debug build under a provisional id reaches no channel, and the release guard makes that mechanical. The catalog amendment (the Filler phone family joins the rule 3 band table, a MINOR) needs the published id, so it is S0007's and is a precondition of the first shipped package. The pointer, the index and the registry row land here, with the verified date left `pending`.
  - **Not covered, stated up front:** no install on a device or emulator (no device is attached to this pass; the acceptance asks for a build), so the activity has never run - an open manual check for S0006, never a pass (`CLAUDE.md` section 2).

## Done criteria

Each is a command to run or a file to read; none is an opinion.

1. `gradlew.bat :phone:assembleDebug` exits 0 and `phone/build/outputs/apk/debug/phone-debug.apk` exists.
2. `aapt2 dump badging` of that APK prints the package `com.sza.filler.provisional`, a `versionName` that decodes to the instant its `versionCode` was derived from, `minSdkVersion` 26 and `targetSdkVersion` 37, and no `uses-permission` line (amended at the audit, 2026-11-10: the source manifest declares no permission; the merged manifest carries only the signature permission `<applicationId>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` that AndroidX Core adds to every app, which the audit lists by name).
3. `gradlew.bat -p buildSrc test` exits 0 with every fixed-instant vector passing (the contract's own example `2609262322` renders `2.60.9262.322` and `260926232`).
4. `gradlew.bat :phone:assembleRelease` is refused with the provisional-id message, exit not 0, before any task executes; `:phone:assembleDebug` is unaffected.
5. No build file includes, references or resolves anything from the FastMediaSorter checkout or from a path outside the repository (`includeBuild`, `mavenLocal`, an absolute path, the upstream folder name; the one `../` is the version catalog inside this repository), and none names a `signingConfig` or keystore; a file search finds no signing material (amended at the audit, 2026-11-10: the criterion judges dependence, so a provenance word in a comment is not a hit).
6. A copy of the tree without build outputs, Gradle caches or scratch folders, placed away from the upstream's neighbourhood, builds the debug APK with exit 0 (independence from the FastMediaSorter checkout and from untracked state other than `local.properties`).
7. `spec_catalog/validate`, `spec_catalog/release-queue -Validate` and the canon compliance gate exit 0.
8. `docs/contracts/README.md` and `docs/contracts/PACKAGE-VERSIONING.md` exist, the registry has the row, and `CLAUDE.md` section 6 names the build and test commands with measured times and the fast and release tiers.

## Plan

Coverage: acceptance 1 -> phases A, C, E (criteria 1, 2, 6); acceptance 2 -> phases A, B, C, E (criteria 3, 5, 6); acceptance 3 -> phase C (the release guard, criteria 4, 5); acceptance 4 -> phases D, E (criterion 8); constraint "upstream untouched" -> every phase reads the upstream only; goal "entry point ready for the port" -> phase C (the activity); contract declaration -> phase D (criterion 8). Topology: B consumes nothing of C; C consumes A (catalog, wrapper, properties) and B (`VersionStamp`); D consumes the measured times of E's first run, so the CLAUDE.md numbers are written in E after the runs; no phase consumes what a later one produces. Every step changes source, resources or config.

- **A. Build roots** - files: `gradlew`, `gradlew.bat`, `gradle/wrapper/*` (generated by the cached Gradle 9.4.1, not copied from a sibling), `settings.gradle.kts`, `build.gradle.kts`, `gradle.properties`, `gradle/libs.versions.toml`, `.gitattributes`, `local.properties` (gitignored, machine-specific), `.sza-profile.json` (lock path rules gain `buildSrc/` and `gradlew`). Check: `gradle-wrapper.properties` pins 9.4.1, `gradlew.bat --version` exits 0.
- **B. Version stamp** - files: `buildSrc/settings.gradle.kts`, `buildSrc/build.gradle.kts`, `buildSrc/src/main/kotlin/com/sza/filler/buildlogic/VersionStamp.kt`, `buildSrc/src/test/kotlin/com/sza/filler/buildlogic/VersionStampTest.kt` (the package folder is `buildlogic`, never `build`, which the ignore list `**/build/` would hide from git). Check: criterion 3.
- **C. Phone module** - files: `phone/build.gradle.kts`, `phone/src/main/AndroidManifest.xml`, the activity, `res/layout/activity_main.xml`, `res/values/strings.xml`, `res/values/themes.xml`. Check: criteria 1, 2, 4, 5.
- **D. Contract declaration and docs** - files: `docs/contracts/README.md`, `docs/contracts/PACKAGE-VERSIONING.md`, the registry row in the catalog, `README.md`. Check: criterion 8, first half.
- **E. Evidence** - criteria 1 to 7 run fresh, wall times measured, the build and test commands and their tiers written into `CLAUDE.md` section 6 (the second half of criterion 8), the audit written.

Self-review (2026-11-10): each inventory line maps to a phase above; every symbol the later phases consume (`VersionStamp`, the catalog aliases, the wrapper) is produced by A or B first; every step ends in a static check or a command exit code.

## Open questions

1. **Published application id and its freeze.** Status: Open. The owner has not chosen it; this ticket builds under `com.sza.filler.provisional` and refuses release packaging. Carrier: S0007
2. **Band-table amendment for the Filler phone family** (`PACKAGE-VERSIONING` rule 3, a MINOR amendment, proposed through the canon session beside the contract). Status: Open. It registers the published id, which does not exist. Carrier: S0007
3. **Signing key, its location outside this tree, Play signing mode, license, public remote, distribution channel, store name and branding (launcher icon included).** Status: Open. None chosen; nothing signed, no icon drawn. Carrier: S0007
4. **targetSdk against the Play requirement at the first release.** Status: Open. 37 is the upstream's value; the requirement is read when a package is about to ship. Carrier: S0007
5. **Dependency and DI choices the ported code needs** (view binding, coroutines, a DI framework, persistence). Status: Open. They follow the re-inventory of the completed upstream, not this skeleton. Carrier: S0003
6. **Screen structure of the Filler flow** (landscape variant, D-pad focus). Status: Open. The activity here is an empty entry point. Carrier: S0005
7. **Install and launch of the entry point on a device or emulator.** Status: Open. No pass has run the app; the acceptance asks for a build, and the device pass is a release rung (the emulators on this machine are shared stands, and a real-device scenario that has not happened is never a pass). Carrier: S0006
8. **Does the product hold a shared contract of its own?** Status: Resolved - no (S0001); this ticket adds only a consumer pointer.

## Last Audit

**Date:** 26-11-10 21:51 | **Mode:** static | **Outcome:** Verified
**Counts:** PASS 16 | WARN 0 | FAIL 0 | MANUAL 0 | UNCHECKABLE 0 | EXEMPT 1 | RELEASE 2

Evidence, each run fresh in this pass (expected | actual):

1. Debug build, `.\gradlew.bat :phone:assembleDebug`: exit 0 and the APK exists | exit 0, `BUILD SUCCESSFUL in 1m 1s` (61.5 s, first build), APK of 6 764 650 bytes; rebuilt on the final tree: exit 0, 5.6 s. PASS. Run once because the acceptance and `CLAUDE.md` section 6 name this build as this ticket's evidence; every later pass counts it as a release-tier rung.
2. `aapt2 dump badging` of the final APK: provisional id, a version pair of one instant, minSdk 26, targetSdk 37, no declared permission | package `com.sza.filler.provisional`, versionName `2.61.1102.150` and versionCode `261110215` (the instant 2611102150 renders both: `26111021 * 10 + 5`, minute 50 in band 5), `minSdkVersion` 26, `targetSdkVersion` 37; the source manifest declares 0 permissions (search count 0); the merged manifest adds only the AndroidX Core signature permission `<applicationId>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` and a merged AndroidX receiver guarded by `android.permission.DUMP`. PASS (criterion 2 as amended).
3. Version-stamp vectors, `.\gradlew.bat -p buildSrc test`: exit 0, every vector passes | exit 0, 9 tests, 0 failures, 0 skipped; the contract's example `2609262322` renders `2.60.9262.322` and `260926232`. Negative control: the band map mutated to `minute / 15` | exit not 0, 5 of 9 tests failed; restored, exit 0 again, 9 of 9. PASS.
4. Release guard and pin: `:phone:assembleRelease` and `:phone:bundleRelease` refused before any task of the module runs | both exit 1 with the provisional-id message, 0 `:phone:` tasks executed; a one-sided pin exit 1 ("pinned together or not at all"); a pair of two instants exit 1 ("does not describe one instant"); the valid pair `2.60.9262.322` / `260926232` exit 0 and reads back from the APK unchanged. PASS.
5. Independence and signing, a search over the build files and the manifest: no `includeBuild`, `mavenLocal`, absolute path, upstream folder name, `signingConfig` or keystore | 2 hits, both benign (the Android XML namespace URL; `from(files("../gradle/libs.versions.toml"))`, the version catalog inside this repository); no key, keystore, token or secret file under `phone`, `buildSrc` or `gradle`. PASS.
6. Clean copy of the tree (no `build` outputs, no `.gradle`, no `local.properties`, the SDK given by `ANDROID_HOME`), placed away from the upstream's neighbourhood: debug build exit 0 | exit 0 in 45.1 s, 37 of 37 tasks executed, version stamped from the clock (`2.61.1102.145` / `261110214`). PASS.
7. Source trackability: every source file visible to git | the first copy was built without `VersionStamp.kt` because its package folder was named `build`, which the ignore list `**/build/` hides (`git check-ignore -v`: exit 0, rule `.gitignore:4`). Fixed in scope by renaming the package to `buildlogic`; after the fix `git check-ignore` exit 1 (not ignored) and the 21 source and config files of this ticket are all listed as trackable. PASS.
8. Fast gates: `spec_catalog/validate` exit 0 | exit 0, 10 OK, 0 WARN, 0 FAIL, 0.85 s. `spec_catalog/release-queue -Validate` exit 0 | exit 0, "OK - 7 ticket(s), no drift", 0.8 s. Canon compliance gate from the installed plugin | exit 0, 0 error(s), 1 warning(s), 0.7 s. PASS x3.
9. Contract declaration surfaces: the pointer, the index, the registry row and the commands in `CLAUDE.md` section 6 exist | `docs/contracts/PACKAGE-VERSIONING.md` and `docs/contracts/README.md` present; the registry holds exactly 1 `Filler Android` row (the file grew by exactly the row's length, so nothing else changed); `CLAUDE.md` section 6 names the fast and release commands with measured times. PASS.
10. Probe invariant: no ticket-id probe in source | 0 matches of a ticket id under `phone/src` and `buildSrc/src`; the ticket is not in the needs-manual-test status. PASS.
11. Scope purity: every edit inside the plan's files | the files of phases A to E, plus the one write outside the repository that phase D declares (the registry row); nothing parked, the active ticket never switched; the upstream checkout was only read (`cat`, `sed`, `grep`, `ls`); scratch removed. PASS.
12. House style in the prose and config written | 0 hits of `...`, an ellipsis or a long dash across `README.md`, `CLAUDE.md`, `docs/contracts`, this spec, the catalog, the properties and the sources (one `...` in this spec's plan found and fixed first). PASS.
13. Hygiene gates and dead weight: the diff has no restating comment, empty catch, colour literal, ambient scope or runtime stub | the only runtime code is the entry activity the goal asks for; `core-ktx` and an unused view id were removed in the same change that would have left them dead; no orphaned resource (`app_name`, `Theme.Filler` and `activity_main` are each referenced). PASS.
14. Doc sync: registry records stated | affected: `CLAUDE.md` (sections 3, 5, 6), `README.md`, `docs/contracts/` (new), the catalog registry, `.sza-profile.json` (lock paths); unchanged: `docs/BOOTSTRAP_HANDOFF.md` (the origin record); no document registry is declared; no site, listing or locale surface exists, so no ship-together surface moves. PASS.
15. Contract boundary: `PACKAGE-VERSIONING` is consumed as written | rules 1 to 3, 5 and 6 are implemented and proven by item 3 and item 4; no package reaches a channel (item 4), so the band-table registration, which needs the published id, is carried to S0007 before any package ships. PASS.
16. Claim audit: the final message states only results cited above | re-read, no hedge word left. PASS.
17. Compliance warning `SZA-CANON06` (the record resolves under the installed canon only after the canon repository publishes it): EXEMPT, the same finding S0001 recorded; a project session does not publish the canon.
18. Install and launch of the entry point on a device or emulator: RELEASE. The device pass is a release rung and the emulators here are shared stands; the release runs `adb install -r phone\build\outputs\apk\debug\phone-debug.apk` and `adb shell am start -n com.sza.filler.provisional/com.sza.filler.MainActivity`, and S0006 owns the real-device run. Not claimed here: the activity has never run.
19. Release-variant package: RELEASE. `.\gradlew.bat :phone:bundleRelease` is refused until S0007 chooses the published id and signing; the release runs it once they exist.

Measured times (2026-11-10, warm daemon unless stated): `-p buildSrc test` 1.3 s to 1.5 s forced with `cleanTest test`, 2.5 s to 3.3 s after a source edit, 7.8 s after a package rename, 29.9 s with no live daemon; `:phone:assembleDebug` 61.5 s first, 45.1 s in a clean copy, 7.4 s with `--rerun-tasks`.

### Action items

None for this ticket. Carried, each with its carrier in the open questions: the published id, the band-table amendment, signing, license, remote, channel and branding, and the targetSdk check (S0007); the dependency and DI choices (S0003); the screen structure (S0005); the device pass (S0006). First sighting, not yet a gate: an ignore glob (`**/build/`) swallowed a source package folder named `build`; the name `buildlogic` avoids it.

### Manual / on-target

None open. The device pass is a RELEASE item (18), owned by S0006.
