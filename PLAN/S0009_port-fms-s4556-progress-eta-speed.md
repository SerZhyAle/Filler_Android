# S0009_port-fms-s4556-progress-eta-speed

**Status:** BlockByOtherTask
**Status note:** Blocker: S0005 - the engine, run state, screen, layouts and strings this port changes are created by S0003 and S0005 (chain S0005 -> S0004 -> S0003, which waits for FastMediaSorter S4521 Verified); spec complete, plan pass after the blocker clears.
**Created:** 2026-11-12
**Complexity:** medium - one pure estimator with unit tests, one engine constant, one UI line in two orientations and three locales; the hard parts (engine, storage, flow) belong to the tickets it waits for
**Depends on:** S0003, S0005

## 0. Owner request (verbatim)

From the FastMediaSorter owner, 2026-11-12, FastMediaSorter ticket S4556 (screenshot of the running Filler):

> изучить возможность сделать заполнение быстрее
> добавить информацию об оценке выполненных процентов.
> добавить оценку сколько времени осталось до окончания
> дополнения отправить в filler_mob

Done upstream in FastMediaSorter S4556 - re-inventory its final spec and code before porting, per the parity law of this project:

- A line under "Written X of Y" on the running screen: percent done and time left. The percent is written bytes over planned bytes, clamped to 0..100. The time left is shown as mm:ss or h:mm:ss by the system formatter; while the run has been observed for less than two seconds, or nothing is written yet, the line says the time is being calculated instead of showing a number. The line is not a live region; only "Written X of Y" keeps that. Portrait and landscape carry the same line in the same place.
- The time left comes from a pure estimator class that takes (bytes written, time) samples and uses the speed over the last 15 seconds, not the average since the start, because a memory card slows down once its cache is full. It has its own unit tests. Time comes from the monotonic clock.
- Faster writing: the write chunk grew from 1 MiB to 8 MiB, so a run opens and closes the output stream eight times less often; for a memory-card folder that open is a cross-process call to the documents provider. The free-space check before every chunk and the reserve are unchanged, and the chunk is still bounded by the space left above the reserve.
- Not done upstream, left as study notes for a measured ticket: one open stream per file instead of one per chunk (changes the storage contract), and preparing the next chunk of random bytes while the current one is being written. Both need a throughput measurement on a real memory card first.
- Two new strings, estimate with time and estimate while calculating, authored in en/ru/uk upstream.

Source files upstream: domain/filler/FillerProgressEstimator.kt (+ test), domain/filler/FillerEngine.kt (chunk size), ui/filler/FillerViewModel.kt (state: remainingMillis, percentDone), ui/filler/FillerScreenManager.kt, layout and layout-land activity_filler.xml, values*/strings_filler.xml.


## 1. Problem

While Filler runs, the screen shows only how many bytes are written out of how many are planned. The user cannot see how far along the run is in percent, cannot tell how long it still takes, and on a memory card the run is slower than it needs to be because the write is cut into many small pieces. The standalone Filler has to carry the same additions that FastMediaSorter's Filler received: a line with percent done and time left under the written-bytes line, an honest estimate that follows the recent speed rather than the early one, and a larger write piece. Shared-contract boundary: none - the estimate is shown only on the screen and no format that another product reads or writes changes.

## 2. Done criteria

Each criterion is a command to run or an observation to repeat. "Unit test" and "build" items run at the release tier (CLAUDE.md section 6); the unit-test task of the phone module is named by S0003's plan pass, and nothing here invents it.

1. **Estimator vectors.** The ported estimator test class passes on the same vectors as upstream: no answer before any sample; no answer while the observed span is under 2 s; no answer while nothing is written; steady speed gives the time for the rest (300 bytes in 3 s against a plan of 1000 bytes gives 7000 ms); nothing is left once the plan is written or exceeded (0 ms); the speed follows the recent window and not the whole run (window 10 s, answer 10 000 ms); reset forgets the earlier run. Window 15 s and minimum span 2 s are the production values; the window is a constructor parameter so the test can shrink it. Expected: the test task exits 0 with the seven tests counted.
2. **Percent.** Percent is written bytes over planned bytes, clamped to 0..100, and 0 while the plan is 0 or less. Observation: a state with written above planned shows 100, never more.
3. **Time left.** The time is shown by the system elapsed-time formatter (mm:ss, or h:mm:ss from an hour), with the seconds rounded up so the last second reads 00:01 and the line never reads 00:00 while bytes are still going. While the estimator has no answer (the run observed for under 2 s, or nothing written) the line says the time is being calculated and carries no number. The time source is the monotonic clock: grep finds no wall-clock call on the estimator path.
4. **Placement and accessibility.** The line sits directly under "Written X of Y" in both `layout` and `layout-land`, in the same place. Only "Written X of Y" keeps the polite live region; the estimate line has none. Grep of both layout files shows the attribute on the first and not on the second.
5. **Faster writing.** The write chunk is 8 MiB (was 1 MiB). The free-space measurement before every chunk and the reserve are unchanged, and the chunk stays bounded by the smaller of the space left above the reserve, the bytes left in the current file and the chunk size. Observation: the ported engine test with free space a little above the reserve writes nothing beyond the reserve (this is the S0003 engine test; this ticket only confirms it still passes with the larger chunk).
6. **Strings.** The two strings (estimate with time, estimate while calculating) exist in the default locale, `ru` and `uk`, with the same placeholders (percent, time) in every file. Prose follows the house style (`..`, plain hyphen, `ё`).
7. **No upstream probe copied.** The upstream view model carries a debug log line tagged with its own ticket id; it is not ported. A probe tagged `S0009` exists in code if and only if this ticket sits in `BlockNeedUserTest`.
8. **Parity record.** Each item above is recorded in the parity inventory in the form S0003's plan pass chooses (or next to the code if that form has none for UI), including any deliberate difference.
9. **Device.** A real run on a device shows the line in portrait and landscape and the estimate settles on a memory-card folder. Not performed by this ticket; it is an open manual check carried to S0006 and is never recorded here as a pass.

## 3. Approach

### 3.1 Scope

**In:** the estimator class and its unit tests; the 8 MiB write chunk in the engine; the percent and time-left state in the run state holder; the estimate line on the running screen in both orientations; the two strings in three locales.

**Out, with the reason:**
- One open output stream per file instead of one per chunk - it changes the storage contract and needs a throughput measurement on a real memory card first (`out-of-scope: measured ticket, after S0004 and the S0006 device check`).
- Preparing the next chunk of random bytes while the current one is written - same reason (`out-of-scope: measured ticket`).
- The reserve, the free-space check cadence and the cleanup, cancellation and recovery behaviour - unchanged and owned by S0003 and S0004.
- Locales beyond en, ru and uk - authored upstream in those three only; the rest fan out at the release boundary (see Assumed).

**Why the ticket waits.** Every file it changes (the engine, the run state holder, the screen manager, the layouts, the string files) is created by S0003 and S0005, and neither exists in this repository yet; the phone module holds only the skeleton from S0002. S0003 is parked behind FastMediaSorter S4521 not yet Verified (CLAUDE.md section 2.2: no parity claim against an unfinished source). Blocker: S0005 (its chain S0004 -> S0003 carries the rest).

**Upstream inventory, read-only, 2026-11-12** (source files of `P:/ANDROID/FastMediaSorter_mob_v2`, `app_v2`; the ticket store of the other repository was not read in this pass, so S4556's own final spec and status are re-read at the port pass). This is a snapshot, not a baseline; the hash for the drift check is taken at the port pass against the completed source.

| Item | Upstream fact observed |
| --- | --- |
| Estimator | `domain/filler/FillerProgressEstimator.kt`: sample deque of (written bytes, time); window 15 000 ms, minimum span 2 000 ms; drops the first sample while the second is at least a window old; returns null on span < 2 s or no bytes; otherwise `max(planned - lastWritten, 0) * span / bytes` |
| Estimator tests | `FillerProgressEstimatorTest.kt`: seven tests, vectors as in criterion 1 |
| Chunk | `domain/filler/FillerEngine.kt`: `BUFFER_BYTES = 8 * 1024 * 1024`, a comment names the cross-process open and close for a card folder; `FILE_BYTES = 100 MiB`; `FILLER_RESERVE_BYTES = 1 GiB`; chunk = min(space above reserve, bytes left in file, buffer), space measured before every chunk |
| State | `ui/filler/FillerViewModel.kt`: `remainingMillis: Long?` (null until observed long enough), `percentDone` clamped 0..100; estimator reset and seeded with (0, now) at start; fed from the engine progress callback; `remainingMillis` cleared when the run ends; clock `TimeUnit.NANOSECONDS.toMillis(System.nanoTime())` |
| Screen | `ui/filler/FillerScreenManager.kt`: estimate line from `filler_estimate` with `DateUtils.formatElapsedTime`, else `filler_estimate_calculating`; seconds rounded up |
| Layouts | `layout` and `layout-land` `activity_filler.xml`: `txtFillerEstimate` right under `txtFillerProgress`, no live region (`txtFillerProgress` keeps `polite`) |
| Strings | `values`, `values-ru`, `values-uk` `strings_filler.xml`: `filler_estimate` (`%1$d%% done, time left: %2$s`) and `filler_estimate_calculating` (`%1$d%% done, time left: calculating..`) and their translations |

**Sequencing.** S0003 and S0005 each re-inventory the final upstream source before porting. If that source already contains the items above (it does in today's snapshot), they arrive with those ports and this ticket closes by checking criteria 1-8 against the ported code and filling any gap; it does not re-port them.

### 3.2 Open questions

None open. Answered here:
- Where the estimator lives and under which package: decided by S0003's layout; it is a pure class with no Android dependency, so it goes with the engine.
- Locales beyond en/ru/uk: see Assumed.
- The measured-speed study: left out of scope above, to a measured ticket that needs a real memory card; no part of it is a question for the owner now.

### Assumed (unattended, 2026-11-12)

- **Taken:** the two new strings are ported in en, ru and uk only, as upstream authored them; other locales fall back to the default at runtime until the release-boundary fan-out. **Alternative weighed:** author all locales of S0005's string set in the same edit now. Reversible inside the ticket (strings only). Owner may overrule.
- **Taken:** the upstream debug probe tagged with S4556 is not ported; a probe tagged S0009 is added only if the ticket reaches `BlockNeedUserTest`. **Alternative weighed:** port the probe verbatim. It would put another repository's ticket id in this code. Owner may overrule.
- **Taken:** the ticket waits for S0005 (which carries S0003 and S0004 through the chain) instead of being worked as a patch over S0002's skeleton. **Alternative weighed:** port only the pure estimator and its tests now, ahead of the engine. Rejected: the parity law (CLAUDE.md section 2, items 2-3) forbids a parity claim against an unfinished source, S0003 has not fixed the package layout or the unit-test task, and no compile command is declared to prove the class builds. Owner may overrule.

### 3.3 Owner inputs (Approval gate)

None required.

- **Related tickets:** S0003 (engine and its tests), S0005 (screen, layouts, strings), S0004 (storage the chunk writes through), S0006 (device check, criterion 9); FastMediaSorter S4556 (the source of this ticket) and S4521 (the Filler it extends).
