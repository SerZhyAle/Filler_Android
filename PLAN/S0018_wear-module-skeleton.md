# S0018_wear-module-skeleton

**Status:** BlockByOtherTask
**Status note:** Blocker: S0013 - the application-id model of the watch Filler is the owner answer recorded there.
**Created:** 2026-11-13
**Complexity:** medium - a Gradle module, an application id and a version band, no Filler logic
**Depends on:** S0013

## 0. Owner request (verbatim)

[Owner, 2026-11-13, first message]

Так.
Идея этого приложения была чтобы весь функционал по суб-программы Filler телефоне (любом андроид устройстве), часах , который реализован в FMS_A был представлен в виде самостоятельных приложений android,  которые могут заинтересовать пользователя, которому не интересен весь остальной функционал FMS_A
Но при этом эти приложения не только выглядят более-менее одинаково, но и развиваются вместеи новый/исправленный функционал обновляется/исправляется в них паралельно, они пересекаются по документации, принадлежат общему семейству программ и связаны канонами и контрактами.
Исследуй всё ли верно в мположениях?

[Owner, 2026-11-13, request after the research report]

Создай такие спецификации в рамках этого продукта, которые приведут его к вышеописанному заказанному состоянию

[Owner, 2026-11-13, correction request]

правильно ли я понял, что по производству всех заказаных задач
это приложение будет иметь весь функционал по соответствующей суб-программы телефона (любом андроид устройстве), часах , который реализован в FMS_A был представлен в виде самостоятельных приложений android,  которые могут заинтересовать пользователя, которому не интересен весь остальной функционал FMS_A
Но при этом эти приложения будут выглядеть более-менее одинаково, развиваться вместе и новый/исправленный функционал обновляется/исправляется в них паралельно, они пересекаются по документации, принадлежат общему семейству программ и связаны канонами и контрактами.
Поправь спецификации чтобы было именно так


## 1. Problem

The watch Filler needs a build target. This repository has only the `phone` module, so until a `wear` module exists with an application id, a version stamp and a release guard like the phone's, nothing about the watch app can be built, versioned or checked.

## 2. Done criteria

1. After the owner's answer in S0013, a `wear` Gradle module exists. It is built by the same root files and the one version catalog (the `FAIL_ON_PROJECT_REPOS` rule holds) and carries one empty launcher activity like the phone skeleton; no Filler logic is written (`CLAUDE.md` section 5a).
2. Its application id follows the id model of S0013 and is provisional (`.provisional` suffix), with the same release guard as the phone: `assembleRelease`, `bundleRelease` and `packageRelease` are refused while the id is provisional.
3. Its version is stamped by the existing `VersionStamp` from one clock reading, never typed. The version band of the watch family is taken from the band table of `PACKAGE-VERSIONING` once registered; until the amendment (a MINOR change proposed through the canon session, together with the phone band owed by S0007) lands, the module has no release-capable version and the guard refuses it. The fixed-instant vectors of the watch band are added to `buildSrc/src/test` on the day the band is assigned.
4. `.sza-profile.json` has a path rule for `wear/`, so the lease locks cover it (`CLAUDE.md` section 5a). `CLAUDE.md` sections 1, 5, 5a and 6 describe the module.
5. The layout leaves a place for the shared pure-logic module that S0003's plan pass creates (the engine, journal and estimator that `phone` and `wear` both consume); this ticket creates no logic module.
6. `.\gradlew.bat :wear:assembleDebug` exits 0 at the release tier; its time is recorded in `CLAUDE.md` section 6. Until it is run, the ticket reports "not built, not tested until the release".
7. `pwsh -NoProfile -File tools/harness.ps1 spec_catalog/validate` exits 0.

## 3. Approach

### 3.1 Scope

In: the module, the provisional id, the stamp wiring, the profile path rule, the `CLAUDE.md` text. Out: Filler logic, the screen (S0019), the published id, signing, the band registration decision (the canon session), a watch face (not ordered).

### 3.4 Evidence read on 2026-11-13

- `phone/build.gradle.kts` carries the provisional id and the `taskGraph.whenReady` release guard; `VersionStamp` renders `versionName` and `versionCode` from one instant.
- The registry row of `PACKAGE-VERSIONING` for the Filler says "no watch product is assumed"; Tourist's row records that its phone, watch and variant families need disjoint bands.

### 3.2 Open questions

None open; the id model is the answer of S0013.

### 3.3 Owner inputs (Approval gate)

- **Related tickets:** S0003, S0007, S0013, S0014, S0017; Tourist_mob (one application id for phone and watch, cited with the repository name).
