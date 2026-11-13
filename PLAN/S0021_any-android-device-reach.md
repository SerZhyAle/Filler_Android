# S0021_any-android-device-reach

**Status:** BlockByOtherTask
**Status note:** Blocker: S0005 - the manifest entries and screens it declares reach for are created by the user-flow port.
**Created:** 2026-11-13
**Complexity:** medium - declared device classes, manifest features and a verification matrix
**Depends on:** S0005

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

The owner wants the Filler on any Android device. Today the skeleton's manifest declares no device features, so the store assumes a touchscreen is required and devices driven by a keyboard, a mouse, a D-pad or a remote are excluded, while FastMediaSorter declares touchscreen, faketouch and leanback as not required. Both have minSdk 26. A reach narrower than the FastMediaSorter Filler's would contradict "any Android device" and the canon rule against shrinking reach, and nothing records which device classes the app claims or how each is verified.

## 2. Done criteria

1. A declared device-class list is written in this ticket: phone, tablet and foldable, and devices without a touchscreen driven by keyboard, mouse, D-pad or remote (as FastMediaSorter declares). The manifest feature declarations match it and are compared line by line with the FastMediaSorter manifest; every difference is fixed or recorded as a deliberate difference with its reason.
2. A reach table compares the Filler with the FastMediaSorter Filler (minSdk, ABI set, supported screens, required and optional features, launcher categories) and is the input of the release check "never ship a release that shrinks reach". The Filler's reach is not narrower unless the difference is recorded as deliberate.
3. Every device class has a verification entry that names a test-lab device or says "not verified". A class without a device stays an open manual check carried to S0006 and is never reported as a pass.
4. The input acceptance of S0005 (keyboard, D-pad and mouse reach every control in both orientations) is turned into a navigation checklist per device class.
5. Between releases only a source check of the manifest runs. The merged-manifest read-back (`.\gradlew.bat :phone:assembleDebug`, then the features and launcher categories of the packaged manifest) is release tier and is recorded at the release.
6. `pwsh -NoProfile -File tools/harness.ps1 spec_catalog/validate` exits 0.

## 3. Approach

### 3.1 Scope

In: the manifest declarations, the comparison, the verification matrix. Out: the watch (S0018 to S0020, a separate surface), a TV-optimised interface (not ordered: the app is declared usable with a remote, as FastMediaSorter's is, not designed as a TV app).

### 3.4 Evidence read on 2026-11-13

- `phone/src/main/AndroidManifest.xml` has no `uses-feature` element; `gradle/libs.versions.toml` sets `min-sdk` to 26.
- The FastMediaSorter manifest declares `touchscreen`, `faketouch` and `leanback` with `required="false"` and keeps minSdk 26 for the phone app (its build file).
- The test-lab Android profile lists FastMediaSorter's phones, a TV (manual, model unknown) and emulators; the Filler has no declaration of its own yet (S0014).

### 3.2 Open questions

None open.

### 3.3 Owner inputs (Approval gate)

- **Related tickets:** S0005, S0006, S0007, S0014; FastMediaSorter manifest (cited with the repository name).
