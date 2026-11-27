# Port intake log - changes seen in FastMediaSorter's Filler

Every change made in the FastMediaSorter Filler is a line here with a disposition and a carrier (`docs/SPECIFICATION_SYNC_MODEL.md`
section 4). The drift check (`tools/port-ledger/check-drift.ps1`) finds a moved file; this log says what the change
was and where it went, so a reader does not have to reconstruct it from hashes. Hashes are the first eight hex digits
of the SHA-256 of the FastMediaSorter file. Paths are relative to the FastMediaSorter checkout.

**Adding a line:** one row per upstream change (not per file), newest first, with the date it was seen, the upstream
ticket or commit, the disposition (port, not applicable, deliberate difference, or follow-on port), the carrier ticket
here, and the evidence. A change found by `pass-start.ps1` arrives as a Draft ticket; the pass that works it adds the
line in the same edit that records the carry or the decision.

## Changes seen

| Seen | Upstream change | Disposition | Carrier | Evidence |
| --- | --- | --- | --- | --- |
| 2026-11-27 | Upstream commit `5699ba020`: removal of `Timber.d("S4567: chooseReserve ...")` and unused `Timber` import in `FillerViewModel.kt` (`2afd0529`) | already ported without it (this product uses `android.util.Log` and drops ticket-id debug lines) | FILLER-0073 | 2 ledger rows refreshed (`carriedOn` 2026-11-27: `2afd0529` -> `FillerViewModel.kt`, `WatchFillerController.kt`); `check-drift.ps1` PASS (52 rows, DRIFT 0) |
| 2026-11-25 | **Theme, toolbar, and schedule UI parity** from FastMediaSorter (`ColorThemePrefs.kt`, `StandardToolbar.kt`, `focus_button_background.xml`, blue Light/Dark palette + six custom accent theme overlays from `values*/themes.xml` and `values*/colors.xml`, `Widget.FastMediaSorter.Toolbar.Flat` + `toolbar_title_icon_gap` 8 dp, and `ScheduledOperationsActivity` card/actions: `Run now`, `Pause/Resume all`, `Clear history`, API 33+ notification-permission prompt button) | port (self-contained files tracked in ledger; monolithic upstream `themes.xml`/`colors.xml`/`ScheduledOperations*` aligned with deliberate-difference file headers; keeps `BUTTONS` 2.2 4 dp glyph buttons, neutral Outlined Stop, rectangular text dialog answers, and `BOOLEAN-OPTION` 2.2 24 dp square checkbox per owner decision Q2) | FILLER-0067 | 3 ledger rows added (`c31b5114` `ColorThemePrefs.kt`, `a1342f32` `StandardToolbar.kt`, `107b46d8` `focus_button_background.xml`); 13 locales + `help-map.json` + `HelpLayerContent.kt` updated (`check-help-map.ps1` PASS) |
| 2026-11-24 | Upstream commit `030cd96bb`: translations of the four **S4556** / **S4567** strings (`filler_estimate`, `filler_estimate_calculating`, `filler_reserve_slider_description`, `filler_confirm_reserve_lowered`) in 10 non-en/ru/uk `strings_filler.xml` locales | port (replaces S0005/S0009 pass-authored translations; standalone and help keys kept intact) | FILLER-0066 | 10 ledger rows refreshed (`carriedOn` 2026-11-24: `f613cc37`, `32dd19e6`, `9a57adc4`, `1164b261`, `0ec2a599`, `8fbcc1d4`, `87214f17`, `27192a69`, `dc1aae76`, `0b94e821`); check-drift PASS 49 rows |
| 2026-11-13 | **Feature documents** of the Filler in FastMediaSorter: `docs/FEATURES.md` (+ ru, uk), `docs/HOW_TO.md`, `README.md`, `docs/WHATS_NEW*.md`, the icon legend and inventory, the scheduled-operations recipe and page | adapted: this product has its own README, listing texts and site; the overlap is an explicit map, not a copy | S0016 (overlap map), S0025 (scheduled-fill text) | outside the scope globs; triage table row 8 of S0012; the overlap is `docs/SPECIFICATION_DOC_OVERLAP_MAP.md` (S0016, 2026-11-13) |
| 2026-11-13 | **Entry surfaces** of the Filler in FastMediaSorter: programs menu (`MENU_ITEM_FILLER`), quick-access panel route with its guard, availability rule and amber accent, launcher-desktop cell, dynamic system shortcut, the manifest registration | adapted: the launcher icon of the standalone app is the entry; the route guard, availability rule and accent colour are out, a deliberate difference | S0012 (table rows 1 to 4, 12, 13), S0005 | outside the scope globs; `FillerActivity` has the MAIN and LAUNCHER filter in `phone/src/main/AndroidManifest.xml`; the difference is written at the head of `FillerActivity.kt` |
| 2026-11-13 | Journal change **S0484**: `data/filler/FillerSessionJournal.kt` last changed upstream on 2026-11-12 (commit `03188d37f`), before release 48 | in - taken by the port itself, no ticket of its own | S0003 | the ported file is the release-48 blob; the working-tree file equals it (hash `d2bd474c`), ledger row OK |
| 2026-11-13 | **S4542** on/off switch of the Filler in the Operations settings, carried by backup, exchange and presets | not applicable, a deliberate difference: a switch that hides the Filler from a programs menu has no meaning in the standalone app | S0012 (unattended assumption, owner may overrule) | outside the scope globs of `docs/port-scope.json`; no ledger row |
| 2026-11-13 | **S4522** scheduled fill (`RunScheduledFillUseCase`, its tests) | follow-on port after S0006 (owner answer B, 2026-11-13) | S0025 (created by S0012) | three files named in `docs/port-scope.json` as an exclusion with this reason; the exclusion is removed when the port adds its rows |
| 2026-11-13 | **S4522** port, first phase: `RunScheduledFillUseCase`, the `FILL_*` part of `ScheduledRunReason`, `RunScheduledFillUseCaseTest` | port; adapted: no `MediaResource`, no operation id, a result type of its own, the test runs a real engine over fakes instead of MockK; the working tree differs from the tag by one deleted debug probe line only | S0025 | three ledger rows (`55b6500f`, `6b253455` partial, `9b648e84`); the S4522 exclusion replaced by one for `ExecuteScheduledFillDispatchTest.kt` (the shared dispatcher, not ported); `ScheduledRunReason.kt` added to the scope; check-drift PASS 36 rows on 2026-11-13 |
| 2026-11-14 | **S4522** port, phases 2 to 5: the fill confirmation and the seven `scheduled_op_reason_fill_*` sentences of `strings_scheduled.xml` in 13 locales; the scheduling model of `WorkManagerScheduler`, `ScheduledOperationsWorker` and `ScheduledOperationsBootReceiver`, and the `confirmFill` rule of `ScheduledOperationsDialogManager` | port of the strings (adapted: the cleanup sentence names this app); the scheduler, worker, receiver and dialog rule are rewritten for the Filler only (owner decision Q1: WorkManager one-time slots, boot re-queue, `dataSync` foreground run), with the daily cap of owner decision Q2 that the source does not have | S0025 | 13 partial ledger rows for `strings_scheduled.xml`; the shared scheduler files are not in the scope (they serve every operation type, and a change to them is read by S4522's next port, not by a drift row); `strings_scheduled.xml` added to the scope; check-drift PASS 49 rows on 2026-11-14 |
| 2026-11-13 | **S4567** reserve slider: seven stops (10, 25, 50, 100, 250, 500 MiB and 1 GiB), the lowered-reserve line in the confirmation, `chooseReserve`, four strings in en, ru and uk | port, adapted: the slider listener lives and dies with the activity's views, so the source's removal in `onDestroy` is dropped | S0005 | the working-tree files carry the change (`sliderFillerReserve`, `RESERVE_CHOICES_BYTES`, `chooseReserve`, `outcomeForReserve`, `filler_confirm_reserve_lowered` found in the ported files); the difference is written at the head of `FillerActivity.kt` |
| 2026-11-13 | **S4556** progress, time left and write speed: `FillerProgressEstimator` and its test (new, untracked upstream), the 8 MiB `BUFFER_BYTES`, the estimate line, two strings | port; the ten locales beyond en, ru and uk are authored here | S0009 | estimator and test rows equal their working-tree hashes (`caf6665e`, `27e66375`); `BUFFER_BYTES = 8 * 1024 * 1024` in `FillerEngine.kt`; estimate line in both layouts |
| 2026-11-13 | **Reserve floor**: `FILLER_MIN_RESERVE_BYTES` (10 MiB) in `FillerEngine.kt` and the floor test in `FillerEngineTest.kt` | port; the floor is the owner-ordered one (catalog contract `FILLER-RESERVE`, still a proposal) | S0003 | `FILLER_MIN_RESERVE_BYTES` and the check `reserveBytes < FILLER_MIN_RESERVE_BYTES` in the ported engine; the test constants match |
| 2026-11-13 | Removal of the ticket-id debug lines (`S4521:`, `S4567:`) from the Filler sources | already ported without them; this product keeps no ticket-id log line | S0004, S0005 | no `S4521` log line in `LocalFillerStorage.kt` or `FillerViewModel.kt` here |
| 2026-11-13 | **Default destination** and start flow | in - already built by the adapter and the screen ports | S0008 (S0004, S0005) | S0008's note: re-inventoried against upstream HEAD `1a3ddca74`, no drift |
| 2026-11-13 | Release 48 (tag `v2.61.1121.756`) as the first baseline: S4521, S4522 and S4556 are `Archived` there (owner decision of S0010) | in - 28 ledger rows from the port tickets S0003 (5), S0004 (5) and S0005 (18) | S0003, S0004, S0005 | each recorded hash equals `git show v2.61.1121.756:<path>` (checked 2026-11-13 for all 28 rows) |

## Baseline of 2026-11-13 - carried at import

The ledger was imported on 2026-11-13 from the rows that S0003, S0004, S0005 and S0009 recorded when they ported
(30 rows: 28 from release 48, 2 from the upstream working tree). The FastMediaSorter working tree is ahead of the tag
in eleven of those files. Every hunk of the tag-to-working-tree difference is one of the changes above (floor, S4556,
S4567, the dropped debug lines), each already in the ported file, so those eleven rows were written at the tag hash
and then carried to the working-tree hash (`record-port.ps1 -Refresh`, `carriedOn` 2026-11-13):

| Source | Tag hash | Carried hash | Ported by |
| --- | --- | --- | --- |
| `main/java/com/sza/fastmediasorter/domain/filler/FillerEngine.kt` | `9875feed` | `f0e3bc4f` | S0003 |
| `test/java/com/sza/fastmediasorter/domain/filler/FillerEngineTest.kt` | `7b0c83e4` | `952a7f38` | S0003 |
| `main/java/com/sza/fastmediasorter/data/filler/LocalFillerStorage.kt` | `be965e93` | `dc11f1ca` | S0004 |
| `main/java/com/sza/fastmediasorter/ui/filler/FillerActivity.kt` | `e82d5a60` | `8c0ead2c` | S0005 |
| `main/java/com/sza/fastmediasorter/ui/filler/FillerScreenManager.kt` | `0920cf2f` | `2ae15045` | S0005 |
| `main/java/com/sza/fastmediasorter/ui/filler/FillerViewModel.kt` | `295b9d2c` | `3d0bd7e7` | S0005 |
| `main/res/layout/activity_filler.xml` | `9f3e8fb9` | `40be22cf` | S0005 |
| `main/res/layout-land/activity_filler.xml` | `a1134144` | `7f2124a0` | S0005 |
| `main/res/values/strings_filler.xml` | `e644f672` | `e715ebb4` | S0005 |
| `main/res/values-ru/strings_filler.xml` | `a1324fb0` | `9dc4d3cd` | S0005 |
| `main/res/values-uk/strings_filler.xml` | `5dedfe01` | `5a5fd561` | S0005 |

The other nineteen files equal their recorded hashes. The check against the real checkout on 2026-11-13: 30 rows,
all OK, scope declared, no `NEW SOURCE`.
