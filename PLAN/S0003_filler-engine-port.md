# S0003 - Port Filler engine and recovery

**Ticket:** S0003
**Status:** BlockExternal
**Status note:** Blocker: FastMediaSorter S4521 is BlockNeedUserTest - never compiled, FillerEngineTest/FillerSessionJournalTest not run, five device checks open; port waits until it is Verified (re-inventory 2026-11-10 in the ticket).
**Priority:** 60
**Tier:** 3 - Moderate
**Complexity:** hard - storage ownership, cancellation and recovery safety
**Depends on:** S0002

## Goal

Port the complete finished FastMediaSorter S4521 Filler engine and its persistent operation journal into the standalone app, including corresponding tests and all safety invariants. The source is `P:/ANDROID/FastMediaSorter_mob_v2`; do not edit it.

## Preconditions and acceptance

- First check S4521's actual status and re-inventory its final spec, all Filler code and tests. If its upstream implementation is unfinished, park the upstream-dependent work with a concrete external blocker; do not claim parity from the bootstrap snapshot.
- Preserve validation, reserve-space measurement, operation serialization, cancellation, persistent ownership, safe deletion of only session-created files and recovery after failures or restart, plus every other behaviour present in completed S4521.
- Port and run the relevant source tests where feasible. Record any deliberate differences and any unresolved checks.

## Upstream re-inventory - 2026-11-10

Read-only pass over `P:/ANDROID/FastMediaSorter_mob_v2` after S0002 closed (Verified), so the in-repo blocker is gone and the upstream gate decides.

- FastMediaSorter S4521: journal status `BlockNeedUserTest` (updated 2026-11-10 10:06). Its Last Audit (pre-handoff, PASS 4, WARN 1, MANUAL 5) records "Not built, not tested until the release": the Kotlin compile, `FillerEngineTest` and `FillerSessionJournalTest`, the registry tests, the resource-link gate and lint are all deferred to its release, and all five on-device checks are open (built-in and memory-card fill, Stop, card removal and retry, cloud-folder refusal, D-pad in both orientations).
- FastMediaSorter S4522 (schedule fill empty space): `BlockNeedUserTest` (2026-11-10 13:27); it reuses the S4521 `FillerEngine` and `FILLER_RESERVE_BYTES` and relies on Storage filler to delete remains after card removal, so the engine's consumers are still moving.
- Upstream Filler surface at this date (the port set once it completes): `data/filler/FillerSessionJournal.kt`, `data/filler/LocalFillerStorage.kt`, `domain/filler/FillerEngine.kt`, `ui/filler/FillerActivity.kt`, `FillerScreenManager.kt`, `FillerViewModel.kt`, `layout/activity_filler.xml` and `layout-land/activity_filler.xml`, `strings_filler.xml` in 13 locales, tests `FillerSessionJournalTest.kt` and `FillerEngineTest.kt`; tactical plan `PLAN/S4521_local-storage-filler/` (4 phases, 1 research note). No content hash is recorded here: the snapshot is not a baseline (CLAUDE.md section 2.2); the parity ledger and its SHA-256 drift check are taken at the plan pass against the completed source.
- Verdict: the upstream implementation is unfinished - never compiled, its tests never run, its device checks open. Porting now would claim parity against an unproven snapshot, which section 2.2 forbids. The ticket is parked at `BlockExternal` until FastMediaSorter S4521 reaches `Verified` (its release build and device sweep done); then re-read S4521's final spec, code and tests, decide the ledger form, and start the plan pass.

## Module layout (added 2026-11-13)

The owner's end state includes a watch Filler and parallel updates of the phone and the watch app (S0013, S0017 to S0020). The plan pass therefore places the pure Filler logic - the engine, the session journal and the progress estimator (S0009) - in one module that the `phone` module and a later `wear` module both consume, and keeps the storage adapter and the screen per surface. The ledger rows of S0011 record the destination module of each ported file. If the owner's answer in S0013 removes the watch app, the module split is dropped.

### 3.3 Owner inputs (Approval gate)

- **Related tickets:** S0002; FastMediaSorter S4521 is the upstream external prerequisite.
