# S0012_standalone-scope-of-fms-filler-extras

**Status:** Approved
**Created:** 2026-11-13
**Complexity:** medium - a triage table plus two owner decisions

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

The owner wants all functionality of the Filler sub-program available as a standalone app. Inside FastMediaSorter the Filler is surrounded by features that exist because it sits in a bigger app: entries in the programs menu, the quick-access panel and the launcher and system shortcuts, a scheduled fill, an on/off switch carried through backup, exchange and presets, a help-map row, feature documentation. Nobody has recorded which of these a standalone app carries, so "full functionality" is undefined at its edges, and two of them (the scheduled fill and the on/off switch) arrived upstream after the 2026-11-10 inventory with no ticket here.

## 2. Done criteria

1. This ticket holds a table with one row per Filler-adjacent FastMediaSorter item and, for each, a disposition (in / adapted / out), a reason and a carrier ticket. Rows at least: programs menu entry; quick-access panel entry; launcher shortcut; system app shortcut; scheduled fill (S4522); on/off switch (S4542) with its backup, exchange and preset carriage; help-map row; feature documentation entry; translations; the lazily resolved journal directory (S0484); the watch (no FastMediaSorter counterpart, carried by S0017 to S0020).
2. The owner's answer to question 1 is recorded and the assumption of section 3.2 is confirmed or overruled.
3. Every "in" or "adapted" row has a follow-on port ticket citing its FastMediaSorter ticket (the form of S0008 and S0009) or names the existing ticket that carries it. Every "out" row is listed as a deliberate difference for S0003 and S0005 to record next to the code and in the parity inventory.
4. `pwsh -NoProfile -File tools/harness.ps1 spec_catalog/validate` exits 0.

## 3. Approach

### 3.1 Scope

In: the table, the owner's answers, the follow-on tickets. The first pass fills each row from the FastMediaSorter code and tickets it reads, and proposes a disposition for every row not covered by a question; the proposal for the entry points is that the launcher icon of the standalone app replaces the menu, panel and shortcut entries. Out: any port code, any edit of the FastMediaSorter checkout.

### 3.4 Evidence read on 2026-11-13

- Registration of the FastMediaSorter Filler (S4521 audit): programs menu, quick-access panel, launcher shortcut, system app shortcut, help map, manifest, 13 locales (EN/RU/UK authored).
- S4522 (scheduled fill) reuses the Filler engine; S4542 (2026-11-12) adds the on/off switch in Operations settings, carried by backup, exchange, presets and Enable-all.
- S0003's inventory mentions S4522 only as a moving consumer; no ticket in this repository covers S4522 or S4542.

### 3.2 Open questions

1. **Scheduled fill (S4522) in the standalone app.** The owner asks for "all functionality of the corresponding sub-program" (2026-11-13). In FastMediaSorter the scheduled fill is a function of the scheduler that runs the Filler engine, not of the Filler screen, so that statement does not settle it.
   - A: out of the first release, recorded as a deliberate difference.
   - B: in, as a follow-on port after S0006 (it needs a scheduler of its own, a run history and a cap on unattended writes).
   - C: in, before the first release.
   - **Resolved 2026-11-13 (owner): B.**

### Assumed (unattended, 2026-11-13)

- **On/off switch (S4542): out, a deliberate difference.** The standalone app is the Filler, so a switch that hides the Filler from a programs menu has no meaning here; the settings that remain (reserve, destination) are not affected. Alternative: carry the switch in the form the standalone settings screen gives it. Owner may overrule.

### 3.3 Owner inputs (Approval gate)

- **Related tickets:** S0003, S0005, S0008, S0009, S0011; FastMediaSorter S4521, S4522, S4542, S0484.
- **Scheduled fill (S4522), question 1:** B - in, as a follow-on port after S0006 (answered 2026-11-13).

### Quiz decisions (2026-11-13)

- Does the standalone Filler carry the scheduled fill of FastMediaSorter S4522 -> B: in, as a follow-on port after S0006 (owner chose the recommendation; it keeps the first release unchanged and keeps the function, in line with `CLAUDE.md` section 2.1; the port needs a scheduler of its own, a run history and a cap on unattended writes).
- Consequence for the pass: the scheduled-fill row of the table is dispositioned "in" with a new follow-on port ticket citing FastMediaSorter S4522 (the form of S0008 and S0009) and depending on S0006. The unattended assumption on the on/off switch (S4542) was not raised in this sitting and stays as recorded above.
