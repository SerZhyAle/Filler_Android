# S0019_watch-filler-flow

**Status:** BlockByOtherTask
**Status note:** Blocker: S0018 - the wear module it builds on does not exist yet; S0003 (shared logic) and S0017 (what a watch can carry) are also prerequisites.
**Created:** 2026-11-13
**Complexity:** hard - the Filler functions on a small round screen with watch input
**Depends on:** S0003, S0017, S0018

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

The owner wants the Filler's functionality on the watch. S0017 establishes what the platform can carry; this ticket builds the watch screen and flow for every function that research says a watch can carry, on a small round screen with watch input, on top of the shared pure logic of S0003.

## 2. Done criteria

1. Every phone Filler function with the disposition "carried" or "adapted" in S0017's table exists on the watch: choosing or defaulting the destination, measured free space and reserve, a confirmation naming destination, amount and reserve, progress with percent and time left (as S0009), cancel, deleting only the files the operation wrote, retrying cleanup after a restart or a disconnection. The safety invariants are the phone's: unknown free space never starts a run, and nothing but the operation's own files is deleted.
2. Every function with the disposition "cannot" is recorded as a deliberate difference next to the code and in the parity inventory (the ledger of S0011), with the evidence line from S0017.
3. The screen follows the catalog contracts that bind a watch surface (which of the UI contracts bind a round watch screen is the subject of the proposal `ui-sizing/PROPOSAL-2026-11-13-watch-surface-scope.md`, status `proposed`; until the owner decides, the practice of the sibling watch apps applies and any difference is a dated exception in the rows of S0014) and the input contract for the keys and touch the watch has; the help entry follows the in-app help contract or carries a dated exception.
4. Strings are authored in EN, RU and UK with the feature; the other locales fan out at the release boundary, as on the phone.
5. The shared logic is consumed from the module of S0003, not copied: a search of `wear/` finds no second copy of the engine, journal or estimator.
6. Between releases only the fast gates run; compile and unit tests run at the release tier, and no on-watch claim is made here (S0020).
7. `pwsh -NoProfile -File tools/harness.ps1 spec_catalog/validate` exits 0.

## 3. Approach

### 3.1 Scope

In: the watch screen and flow, its strings, the watch storage adapter in the form S0017 finds possible, the help entry. Out: a watch face, tiles or complications (not ordered), the published application id, the device check (S0020), any change to the phone app.

### 3.2 Open questions

None open.

### 3.3 Owner inputs (Approval gate)

- **Related tickets:** S0003, S0009, S0011, S0013, S0017, S0018, S0020.
