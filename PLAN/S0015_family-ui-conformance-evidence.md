# S0015_family-ui-conformance-evidence

**Status:** BlockByOtherTask
**Status note:** Blocker: S0005 - the Filler screen this ticket measures is created by S0005; S0014 declares the contracts first.
**Created:** 2026-11-13
**Complexity:** hard - visual and behavioural conformance proof on a UI that does not exist yet
**Depends on:** S0005, S0014

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

The owner wants the apps of the family to look more or less the same. The standalone Filler has no screen yet, only a skeleton, so "looks like the family" is a hope. When S0005 ports the FastMediaSorter Filler screen it brings FastMediaSorter's look, the sibling apps follow the same catalog contracts, and nobody has written what "the same" is measured against or checked it.

## 2. Done criteria

1. A conformance table in this ticket has one row per UI contract bound by S0014 - sizing profiles and text enlargement, buttons, boolean option, collapsible group, settings navigation, iconography (the glyphs for Start, Stop, delete, folder and volume), help (the `?` button and F1, a help map that covers every window), input (keyboard, D-pad, mouse, TalkBack) - with the evidence form the contract itself names (generated reference evidence or source gate), a result per portrait and landscape, and a ticket or a dated exception for every failing row.
2. Side-by-side screenshots exist of the standalone Filler screen, the FastMediaSorter Filler screen and the main screen of one sibling app, in portrait and landscape, each taken on a device or emulator named by the test-lab contract. A screenshot that was not taken on a named device is not claimed.
3. The family signature decision of section 3.2 is applied and, if the backdrop is adopted, its conformance is checked with the contract's own checks. The watch screen is measured against the contracts that bind a watch surface in S0019 and S0020; this ticket covers the phone screen.
4. Every deliberate difference from the FastMediaSorter screen is recorded next to the code and in the parity inventory.
5. Between releases only fast source gates run; screenshots and device behaviour are release tier and open manual checks of S0006 until performed (`CLAUDE.md` sections 2.4 and 6).

## 3. Approach

### 3.1 Scope

In: the conformance table, the side-by-side evidence, the family-identity decision. Out: the application icon, store name and branding (open owner decisions of S0007), any change to a contract text, the contract declarations themselves (S0014).

### 3.4 Evidence read on 2026-11-13

- `phone/src/main` holds one `MainActivity` and its layout; the Filler screen arrives with S0005.
- The catalog's backdrop contract names the animated "particles and lines" backdrop as FastMediaSorter's and open to "any product that adopts the backdrop next".
- Tourist_mob registers its UI sizing contract as declared with a partial migration (`pending`), the form S0014 follows for the Filler.

### 3.2 Open questions

None open.

### Assumed (unattended, 2026-11-13)

- **Family signature: only what the UI contracts require (sizing, buttons, groups, icons, help, input).** The owner asks for "more or less the same" look; the agent rules of the sibling apps do not mention the animated backdrop (their code was not searched), so the contracts are the measurable common ground. Alternative: also adopt the animated backdrop under its contract. Owner may overrule.

### 3.3 Owner inputs (Approval gate)

- **Related tickets:** S0005, S0006, S0007, S0014.
