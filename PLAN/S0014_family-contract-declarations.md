# S0014_family-contract-declarations

**Status:** Draft
**Created:** 2026-11-13
**Complexity:** medium - catalog rows and pointers for contracts that already bind the product

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

The owner wants the apps of the family bound together by the canon and the contracts. This product is bound by the canon and declares one contract, package versioning; the catalog registry holds one row for it, against 22 for Tourist and 29 for StreamsPlayer_mob. The repository-level contracts (stamp, harness profile, layout, rule delivery, internal documentation quality, test lab) and the contracts that bind every Android application have no declaration here, so the family link exists in practice but is not written in the catalog and cannot be checked by it.

## 2. Done criteria

1. The `contract-sync` skill is run once. Its inventory lists every catalog contract that binds this product with a disposition (consumer, adopter, not applicable), the reason and the version read. It covers at least the registry ids `REPO-STAMP`, `HARNESS-PROFILE`, `REPO-LAYOUT`, `RULE-DELIVERY`, `DOC-INTERNAL-QUALITY`, `TEST-LAB`, and decides each of the catalog's UI and input contracts (ui-sizing, buttons, boolean-option, collapsible-group, settings-navigation, iconography, in-app-help, input-controls, automated-checks), in the ids the registry uses.
2. Each declared contract has a pointer under `docs/contracts/` and a row in the pointer table of `docs/contracts/README.md` - id, version, role, state; no contract text is copied and every pointer cites by id and section, never by link.
3. The registry rows of the declared contracts are written through the catalog's own flow, in the form Tourist_mob's rows use: a UI contract whose screen does not exist yet is registered as declared and `pending`, never as verified.
4. Every contract not yet met has a dated exception with an expiry (comply or amend; no silent deviation).
5. `CLAUDE.md` section 5, "Declarations still to come", is rewritten to the real state.
6. The compliance gate `tools/check-compliance.ps1`, run from the installed plugin root, exits 0, and `pwsh -NoProfile -File tools/harness.ps1 spec_catalog/validate` exits 0.
7. No conformance of a UI contract is claimed here; that evidence is S0015.

## 3. Approach

### 3.1 Scope

In: the inventory, the pointers, the registry rows, the exceptions, the `CLAUDE.md` section 5 text. The declarations cover the phone app and the watch app of the Filler family: the watch rows are written when S0013 is answered and S0018 creates the module, as `pending` until the watch screen exists. Two proposals were filed in the catalog on 2026-11-13, both `proposed`: `_meta/PROPOSAL-2026-11-13-new-contract-source-port-ledger.md` and `ui-sizing/PROPOSAL-2026-11-13-watch-surface-scope.md`. The rows record a consumer role towards them only after the owner accepts, and any local difference until then is a dated exception here (`_meta/RULES.md` section 15). Out: UI conformance evidence (S0015), the application id band amendment of `PACKAGE-VERSIONING` (S0007), install trust and the product web pages, which depend on the distribution channel (carried to S0007), and any change to a contract text (the catalog is sealed: a deviation is a proposal filed beside the contract by this product, never an edit).

### 3.4 Evidence read on 2026-11-13

- Registry rows per product (counted in `REGISTRY.md`): Tourist 22, StreamsPlayer_mob 29, deviceinfo_mob 0, Filler 1 (`PACKAGE-VERSIONING`).
- Tourist_mob's rows include `TEST-LAB`, `CONTEXT-HELP`, `INPUT-PARITY`, `REPO-STAMP`, `HARNESS-PROFILE`, `REPO-LAYOUT`, `RULE-DELIVERY`, `DOC-INTERNAL-QUALITY`, `UI-SIZING`.
- The UI contracts name as bound "every portfolio Android application" or "every product with a user interface" (catalog README).
- `CLAUDE.md` section 5 lists the declarations to come: input parity, in-app help and the unified UI contracts (S0005), install trust and the web-page family (S0007).

### 3.2 Open questions

1. **Which of the optional contracts apply once a distribution channel exists** (install trust, product web pages, store contracts)? Carrier: S0007.

### 3.3 Owner inputs (Approval gate)

- **Related tickets:** S0005, S0007, S0015; Tourist_mob and StreamsPlayer_mob registry rows (cited with the repository name).
