# S0011_fms-sync-model-and-drift-check

**Status:** Draft
**Created:** 2026-11-13
**Complexity:** medium - a ledger tool and a preflight gate on a model the siblings already run

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

The owner wants new and corrected Filler behaviour to land in FastMediaSorter's Filler and in the standalone Filler in parallel. Today the only link is that the owner hands a change over by hand (S0008 and S0009 started that way) and that a port ticket re-reads the source once. Nothing detects a later change in the FastMediaSorter Filler, nothing records which of its changes this product has already seen, and there is no rule for a defect found here in behaviour both apps share. The sibling apps already run a ledger with a drift check; this repository has neither.

## 2. Done criteria

1. A one-page sync model exists under `docs/` (English) and `CLAUDE.md` cites it. It states the direction (FastMediaSorter to Filler, pull), the triggers of section 3.2, what happens to a defect found here (a hand-off to the FastMediaSorter owner; the checkout stays read-only), and who decides "port / not applicable / deliberate difference" for a drifted file.
2. A port ledger tool exists under `tools/port-ledger`: record a port (source path, SHA-256 at port time, destination, date), check drift, record the decision on a drifted file. Its self-test exits 0. It follows the siblings' model by decision, not by copying their code (`CLAUDE.md` section 1).
3. The release preflight of this product runs the drift check and refuses on an undecided drift. The same check runs at the start of every `pq` pass over this project, and an undecided drift opens a Draft ticket here (through the `spec-draft` flow) naming the FastMediaSorter file that moved, so a change lands in the queue within one pass. `CLAUDE.md` section 6 names the check with its measured time; a check over 5 seconds is release tier.
4. A change-intake log lists every FastMediaSorter Filler change made after the 2026-11-10 inventory, each with a disposition and a carrier: S4556 (S0009), the default destination (S0008), S4542 and S4522 (S0012), and the journal change S0484 (taken by the port itself, no ticket). Every later change adds a line.
5. The triggers of section 3.2 are in place and `pwsh -NoProfile -File tools/harness.ps1 spec_catalog/validate` exits 0.
6. No Filler logic is written ahead of S0003 to S0005 (`CLAUDE.md` section 5a): the ledger starts empty and its first rows come with the first port.
7. The sync model also says how a fix lands in both apps of this product: the pure Filler logic lives in one module consumed by `phone` and `wear` (S0003, S0013, S0018), so it is fixed once and reaches both; nothing is copied between them.

## 3. Approach

### 3.1 Scope

In: the model page, the ledger tool, the preflight hook, the intake log, the `CLAUDE.md` pointers (sections 2.3 and 6). `CLAUDE.md` section 2.3 leaves the form of the parity inventory to S0003's plan pass: this ticket supplies the form, and S0003's plan pass confirms or amends it; if S0003's plan pass starts first it adopts this ticket's result. Out: porting any file, editing the FastMediaSorter checkout, a change in FastMediaSorter's own rules. The ledger's row fields and exit codes follow the catalog proposal `_meta/PROPOSAL-2026-11-13-new-contract-source-port-ledger.md` (status `proposed`, filed 2026-11-13), which describes what the three sibling ledgers already do; until the catalog owner decides, those ledgers are the reference, and the proposal's rule 8 (the source's side of the sync) is the owner's decision, not made here.

### 3.4 Evidence read on 2026-11-13

- FastMediaSorter S4065 section 1 and S4053 section 5.1.7: the model is "pull", the source repository carries no obligation, the new product compares itself.
- `tools/port-ledger` exists in StreamsPlayer_mob (record-port, check-drift, decide-drift, self-test), Tourist_mob and deviceinfo_mob; this repository has only `tools/harness.ps1`.
- The FastMediaSorter `CLAUDE.md` does not mention its extracted apps.
- The S0003 inventory of 2026-11-10 predates S4542, S4556, S0484, the default-destination change and S4522's archive.

### 3.2 Open questions

None open. The trigger was a question in the first draft; the owner's statement of 2026-11-13 (new and corrected functionality is updated in the apps in parallel) settles it as below.

### Assumed (unattended, 2026-11-13)

- **Trigger: drift is compared at every release preflight and at the start of every `pq` pass over this project, and an undecided drift becomes a Draft ticket here.** Alternative A (release preflight only, the siblings' model) does not meet "in parallel", because a change could wait weeks unseen. Alternative C (a rule in FastMediaSorter that each Filler change opens a hand-off ticket here) is the only way a change is pushed instead of pulled, but it needs a ticket in the FastMediaSorter repository; it is not created from here and is listed in the hand-off note of S0016. Owner may overrule.
- **Limit stated in the sync model:** FastMediaSorter carries no obligation towards this product (S4065). A change made there reaches this repository as a queued ticket within one `pq` pass of being detected, not as shipped code at the same moment; a fix made here reaches FastMediaSorter only through the hand-off note, never by editing its checkout.

### 3.3 Owner inputs (Approval gate)

- **Related tickets:** S0003, S0008, S0009, S0010, S0012, S0013, S0016, S0018; FastMediaSorter S4053, S4065.
