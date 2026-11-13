# S0017_wear-storage-access-research

**Status:** Draft
**Created:** 2026-11-13
**Complexity:** medium - read-only research of Wear OS storage and free-space access, no code

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

The owner wants all Filler functionality on the watch as well. FastMediaSorter has no Filler on the watch, and what a watch exposes for storage - a volume to pick, a folder grant, a free-space reading, survival of a long write in the background, removable media - is not established anywhere in this portfolio. Which Filler functions a watch can carry is therefore unknown, and the watch module and screen cannot be planned honestly before that is read.

## 2. Done criteria

1. A research note exists in this ticket's `research/` folder. It answers each item below with a cited source (platform documentation, FastMediaSorter wear code, the test-lab profile, each with the date read) or marks it "not established": (a) which storage a watch app can write without a user-granted folder, including the app-owned directory that the phone's default destination (S0008) uses, and its free-space reading; (b) whether a system folder picker exists on Wear OS and which volumes it offers; (c) whether the free space of a volume can be measured the way the phone engine measures it; (d) how a write of several minutes survives screen-off, ambient mode and the watch's battery rules; (e) what removable media means on a watch; (f) what filling a watch's internal storage does to the system, so that the watch reserve is chosen on evidence and not copied from the phone's 1 GiB.
2. The note ends with a table: each function of the phone Filler (choose or default the destination, measured free space and reserve, confirmation, write with progress, cancel, delete only the operation's own files, retry cleanup after a disconnection or a restart, recovery on restart) with a watch disposition - carried, adapted or cannot - and the evidence line. S0013 (criterion 6) and S0019 consume this table.
3. Nothing is run on a watch by this ticket and no on-watch claim is made; every item that needs a watch is listed as an open check for S0020.
4. `pwsh -NoProfile -File tools/harness.ps1 spec_catalog/validate` exits 0.

## 3. Approach

### 3.1 Scope

In: reading platform documentation, the FastMediaSorter wear module (read-only) and the test-lab Android profile. Out: code, a module, an application id, any edit of the FastMediaSorter checkout.

### 3.4 Evidence read on 2026-11-13

- FastMediaSorter `wear/` has no Filler code; its minSdk is 28.
- The phone default destination (S0008) is the app-owned Downloads directory on internal storage; the phone engine's reserve is 1 GiB (FastMediaSorter S4521 audit).
- The test-lab Android profile lists a physical watch (Galaxy Watch 7, Wear OS on Android 16 / SDK 36) and three reviewed round emulator shapes.

### 3.2 Open questions

None open.

### 3.3 Owner inputs (Approval gate)

- **Related tickets:** S0008, S0013, S0018, S0019, S0020; FastMediaSorter wear module (cited with the repository name).
