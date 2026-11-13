# S0013_watch-product-decision

**Status:** Approved
**Created:** 2026-11-13
**Complexity:** hard - a new product surface with unverified Wear OS storage access

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

The owner states the end state as a Filler for the phone, for any Android device and for the watch. The sibling apps do have a watch part, the Filler does not: FastMediaSorter has no Filler on the watch, so there is nothing to port, and this repository says in several places that no watch product is assumed. The watch is therefore a new product surface designed from the phone Filler, not a port, and its application id (a frozen anchor) is the owner's decision. The engine port (S0003) is about to fix a module layout, and the watch is a second consumer of it.

## 2. Done criteria

1. The owner's answer to question 1 is recorded in this ticket.
2. `CLAUDE.md` sections 1 and 5 no longer say "no watch product is assumed"; they state that the Filler family has a watch app and which application-id model was chosen. The `PACKAGE-VERSIONING` pointer and registry row are corrected through the catalog flow.
3. The follow-on tickets exist as drafts with their own `Depends on:` lines: S0017 (research of Wear OS storage access and free-space measurement, including whether the app-owned default destination of S0008 is the only destination a watch can offer), S0018 (the watch module skeleton with its application id and its version band, registered by a `PACKAGE-VERSIONING` amendment through the canon session), S0019 (the watch Filler screen and flow, input per the catalog's input contract), S0020 (the device check on a physical watch named by the test-lab contract, never a pass without one). S0018 reads this ticket's answer.
4. The pure Filler logic (engine, session journal, progress estimator) lives in one module that `phone` and `wear` both consume, so a fix is made once and reaches both apps; only the storage adapter and the screen differ per surface. S0003 carries this as a pointer and its plan pass reads it before fixing the module layout.
5. `pwsh -NoProfile -File tools/harness.ps1 spec_catalog/validate` exits 0.
6. Every function of the phone Filler has a disposition on the watch (carried, adapted, or a deliberate difference backed by the evidence of S0017). "All functionality" is claimed for the watch only for the functions the platform can carry.

## 3. Approach

### 3.1 Scope

In: the decision, the repository statements that depend on it, the follow-on drafts. Out: building any watch code, choosing an application id by assumption, editing the FastMediaSorter checkout. The answer is needed before S0003's plan pass, but this ticket does not block S0003 by itself.

### 3.4 Evidence read on 2026-11-13

- FastMediaSorter `wear/` has no Filler code (the only match for the word is a comment in the voice-recording service); S4521 section 3.4: the program is available "wherever phone subprograms are available".
- StreamsPlayer_mob, Tourist_mob and deviceinfo_mob each have a `wear` module; Tourist uses one application id for phone and watch (owner decision of 2026-10-02 in that repository).
- This repository has only `phone/`; `docs/BOOTSTRAP_HANDOFF.md`, `CLAUDE.md` section 1 and the registry row of `PACKAGE-VERSIONING` say no watch product is assumed.

### 3.2 Open questions

1. **Which application-id model does the watch Filler use?** The owner's statement of 2026-11-13 settles that a watch Filler exists, so "phone only" and "later" no longer apply. The id is a frozen anchor, so the choice stays the owner's.
   - B: one application id for phone and watch, as Tourist does (frozen after the first package).
   - C: a separate watch application with its own id and listing.
   - **Resolved 2026-11-13 (owner): B.**

### 3.3 Owner inputs (Approval gate)

- **Related tickets:** S0003, S0008, S0014; FastMediaSorter S4521; Tourist_mob and StreamsPlayer_mob watch modules (cited with the repository name).
- **Application-id model of the watch Filler (question 1):** B - one application id for phone and watch (answered 2026-11-13). The id itself is not chosen here; it stays the owner's open decision in S0007.

### Quiz decisions (2026-11-13)

- Which application-id model does the watch Filler use -> B: one application id for phone and watch, as Tourist_mob and StreamsPlayer_mob do (owner chose the recommendation; StreamsPlayer_mob records that its Data Layer requires the shared id; the id is a frozen anchor after the first package and its value is still decided in S0007, so no id is chosen by assumption).
- Consequence for the pass: `CLAUDE.md` sections 1 and 5 state that the Filler family has a watch app under the same application id as the phone app; S0018 builds the wear module under that id and reads this answer; the `PACKAGE-VERSIONING` registry row is corrected through the catalog flow.
