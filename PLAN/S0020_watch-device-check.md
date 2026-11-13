# S0020_watch-device-check

**Status:** BlockByOtherTask
**Status note:** Blocker: S0019 - the watch screen and flow it checks on a physical watch are created there.
**Created:** 2026-11-13
**Complexity:** medium - physical watch checks that are never a pass without a watch
**Depends on:** S0019

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

A Filler that writes into a watch's own storage has to be proven on a physical watch: a small storage, survival of screen-off and battery rules, cancellation, restart, cleanup, the reserve and the files that are not the app's. Without a watch none of this is known, and the product rule is that no device claim is made without a device (`CLAUDE.md` section 2.4).

## 2. Done criteria

1. Each scenario below is run on a physical watch named by the test-lab contract (model, OS and the state the watch is left in are recorded) and recorded as pass or fail with the observation. A scenario that has not been run stays an open manual check and is never recorded as a pass. Scenarios: first launch with the default destination and Start; a fill to the reserve with unrelated files intact; cancel with deletion of the operation's own files; screen-off and ambient mode during a run; battery saver and doze during a run; a restart of the app and of the watch during a run, then the retry of cleanup; insufficient space; unknown free space refused; the small and the large round shapes of the reviewed emulators.
2. Without a watch the ticket stops at `BlockNeedUserTest`; it never reaches `Verified` without the runs.
3. Each failure becomes a ticket; this ticket fixes nothing.
4. `pwsh -NoProfile -File tools/harness.ps1 spec_catalog/validate` exits 0.

## 3. Approach

### 3.1 Scope

In: the checks and their record. Out: fixes, the phone's device checks (S0006), the behaviour of the paired phone.

### 3.2 Open questions

None open.

### 3.3 Owner inputs (Approval gate)

- **Related tickets:** S0006, S0017, S0019; the test-lab contract's Android profile (cited by id).
