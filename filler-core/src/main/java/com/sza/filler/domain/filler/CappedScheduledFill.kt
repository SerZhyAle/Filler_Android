package com.sza.filler.domain.filler

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

// This product's own (S0025): FastMediaSorter has no cap on unattended writes (its scheduled fill is bounded by
// the reserve alone). The cap is the owner's decision of 2026-11-13 (S0025 Q2): at most one unattended fill per
// local day for the whole app, no byte cap beyond the reserve. A run still fills all free space above
// FILLER_RESERVE_BYTES, so the cap bounds how often the storage is written full, not how much one run writes.

/** Where the day of the last unattended fill is kept; a day is the local epoch day, as LocalDate.toEpochDay(). */
interface UnattendedFillDays {
    suspend fun lastFillDay(): Long?
    suspend fun setLastFillDay(day: Long?)
}

/**
 * Runs a scheduled fill only when no unattended fill has started a session today. The day is claimed before the
 * engine runs, so a process killed mid-run still counts the day; it is given back when the run never began a
 * session (a refusal before any write: no free space, storage missing, busy, leftovers). A run refused by the cap
 * reaches neither the engine nor the storage.
 */
class CappedScheduledFill(
    private val run: RunScheduledFillUseCase,
    private val days: UnattendedFillDays,
) {
    suspend operator fun invoke(location: String, name: String, today: Long): ScheduledFillResult {
        val previous = claim.withLock {
            val last = days.lastFillDay()
            if (last == today) return capped()
            days.setLastFillDay(today)
            last
        }
        val result = run(location, name)
        if (!result.sessionStarted) {
            claim.withLock { if (days.lastFillDay() == today) days.setLastFillDay(previous) }
        }
        return result
    }

    private fun capped() = ScheduledFillResult(
        ScheduledFillOutcome.SKIPPED,
        ScheduledFillReason.FILL_DAILY_CAP,
        "An unattended fill already ran today",
    )

    private companion object {
        /** One claim at a time per process, so two slots due together cannot both pass the check. */
        val claim = Mutex()
    }
}
