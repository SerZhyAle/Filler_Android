# S0010_upstream-completion-gate

**Status:** Approved
**Created:** 2026-11-13
**Complexity:** light - one owner decision recorded and one blocker rewritten

## 0. Owner request (verbatim)

[Owner, 2026-11-13, first message]

Так.
Идея этого приложения была чтобы весь функционал по суб-программы Filler телефоне (любом андроид устройстве), часах , который реализован в FMS_A был представлен в виде самостоятельных приложений android,  которые могут заинтересовать пользователя, которому не интересен весь остальной функционал FMS_A
Но при этом эти приложения не только выглядят более-менее одинаково, но и развиваются вместеи новый/исправленный функционал обновляется/исправляется в них паралельно, они пересекаются по документации, принадлежат общему семейству программ и связаны канонами и контрактами.
Исследуй всё ли верно в мположениях?

[Owner, 2026-11-13, request after the research report]

Создай такие спецификации в рамках этого продукта, которые приведут его к вышеописанному заказанному состоянию


## 1. Problem

The whole port chain (S0003 to S0009) waits for FastMediaSorter's Filler (FastMediaSorter S4521) to reach `Verified` before any parity claim is made. In FastMediaSorter that status cannot arrive by its own flow: the Filler shipped inside release package 48 and its ticket was archived on 2026-11-12 with the five device checks still open. The owner wants the standalone Filler to follow the FastMediaSorter Filler as one family of apps, but today every ticket of the product is parked behind a condition nobody is working towards, so nothing of the standalone product can start.

## 2. Done criteria

1. The owner's answer to question 1 is written in this ticket, and `CLAUDE.md` section 2 item 2 says in one sentence what "completed source" means (it names the answer, it does not restate the options).
2. S0003 leaves `BlockExternal` through `spec_catalog/update`, its status note cites this ticket, and - if the answer is B - the blocker names the FastMediaSorter ticket that carries the device checks.
3. After the change `pwsh -NoProfile -File tools/harness.ps1 spec_catalog/validate` exits 0 and `pwsh -NoProfile -File tools/harness.ps1 spec_catalog/release-queue -Validate` exits 0.
4. This ticket claims no parity and reports no device check as passed (`CLAUDE.md` section 2.4).

## 3. Approach

### 3.1 Scope

In: the decision, the S0003 status note and blocker, the one sentence in `CLAUDE.md` section 2. Out: porting, any edit of the FastMediaSorter checkout, running the FastMediaSorter device checks, S0003's own re-inventory (the 2026-11-10 one is stale and S0003 redoes it).

### 3.4 Evidence read on 2026-11-13

- FastMediaSorter journal: S4521 status `Archived`, updated 2026-11-12 19:20 (`PLAN/spec-catalog-archive.jsonl`); S4522 archived the same minute.
- Its last audit (2026-11-10, pre-handoff) is `BlockNeedUserTest`: PASS 4, WARN 1, MANUAL 5, and the five device checks are unticked.
- FastMediaSorter `PLAN/RELEASE_QUEUE_DONE.md`: release 48, v2.61.1121.756, 2026-11-12, lists S4521 as `BlockNeedUserTest`.
- S0003 status note: "port waits until it is Verified" (re-inventory 2026-11-10).

### 3.2 Open questions

1. **What makes the FastMediaSorter Filler a "completed source" for parity claims?**
   - A (recommended): the code and the archived spec as shipped in FastMediaSorter package 48. The exact source state is pinned in the ledger at port time (S0011); FastMediaSorter's five device checks are carried here as open manual checks of S0006, never as passes. `CLAUDE.md` section 2.2 asks for a completed source, not a device-verified one, and section 2.4 keeps device claims honest on its own.
   - B: FastMediaSorter first runs its five device checks and records `Verified` (an action in the FastMediaSorter repository, not here). This chain stays parked and the blocker names that FastMediaSorter ticket.
   - C: the owner confirms the FastMediaSorter Filler by hand on a device (the statement is recorded here), after which A applies.
   - **Resolved 2026-11-13 (owner): A.**

### 3.3 Owner inputs (Approval gate)

- **Related tickets:** S0003, S0006, S0011; FastMediaSorter S4521, S4522.
- **Completed source for parity (question 1):** A - the code and the archived spec of FastMediaSorter S4521 as shipped in release package 48 (answered 2026-11-13).

### Quiz decisions (2026-11-13)

- What makes the FastMediaSorter Filler a "completed source" for parity claims -> A: the code and the archived spec as shipped in FastMediaSorter package 48 (owner chose the recommendation; the exact source state is pinned in the ledger at port time, S0011; FastMediaSorter's five device checks are carried as open manual checks of S0006, never as passes; `CLAUDE.md` sections 2.2 and 2.4 are consistent with this).
- Consequence for the pass: done criteria 1 and 2 apply as written - `CLAUDE.md` section 2 item 2 names answer A in one sentence, and S0003 leaves `BlockExternal` with a status note citing this ticket. The blocker needs no FastMediaSorter ticket (that is only for answer B).
