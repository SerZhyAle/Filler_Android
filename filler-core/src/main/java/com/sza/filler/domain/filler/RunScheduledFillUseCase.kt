package com.sza.filler.domain.filler

// Ported from FastMediaSorter release 48 (domain/usecase/RunScheduledFillUseCase.kt and the FILL_* part of
// domain/model/ScheduledRunReason.kt, S4522; S0025 here). Deliberate differences:
// - no javax.inject annotation and no Timber: this app has no dependency injection and no logging library;
// - no MediaResource and no operation id: a Filler schedule names a folder address and the name the person
//   saw when saving it, and the caller keys the result by its own schedule;
// - the result is this file's ScheduledFillResult, not the source's ScheduledExecutionResult shared by every
//   scheduled operation type: the outcome is explicit instead of derived from an error list and a skip text;
// - ScheduledFillReason keeps only the seven FILL_* constants of the source's ScheduledRunReason; the other
//   constants belong to copy, move, delete and watch-message schedules, which this product does not have. It adds
//   FILL_DAILY_CAP (the cap of CappedScheduledFill, owner decision 2026-11-13, S0025 Q2) and FILL_STOPPED (a run
//   cancelled before its end, written by the phone app's scheduler so that no attempt is silent);
// - ScheduledFillResult.sessionStarted says whether the engine began writing, which the daily cap counts;
// - a Finished result whose cleanup did not finish keeps its written byte count (the source reports 0), so the
//   history can say how much was left on the storage (S0025, assumed A3).
// The source's working tree after the tag differs only by one deleted debug probe line.

/** Why a scheduled fill was skipped or failed. The name is what a history persists: add or retire, never rename. */
enum class ScheduledFillReason {
    FILL_BUSY,
    FILL_NOT_LOCAL,
    FILL_STORAGE_UNAVAILABLE,
    FILL_MEASUREMENT_UNAVAILABLE,
    FILL_NO_FREE_SPACE,
    FILL_WRITE_FAILED,
    FILL_CLEANUP_PENDING,
    FILL_DAILY_CAP,
    FILL_STOPPED,
    ;

    companion object {
        /** The constant stored under [name], or null for a missing, empty or retired name. */
        fun fromName(name: String?): ScheduledFillReason? = entries.firstOrNull { it.name == name }
    }
}

enum class ScheduledFillOutcome { OK, SKIPPED, ERROR }

/**
 * One attempt as a history records it; [message] is the English text for a log, never parsed by a screen.
 * [sessionStarted] is true once the engine began a session on the storage, whatever the outcome.
 */
data class ScheduledFillResult(
    val outcome: ScheduledFillOutcome,
    val reason: ScheduledFillReason? = null,
    val message: String? = null,
    val writtenBytes: Long = 0L,
    val sessionStarted: Boolean = false,
)

/**
 * One scheduled fill run. The engine owns the volume checks, the reserve, the journal and the cleanup; this
 * class only turns its verdict into a schedule result, so the scheduled and the interactive run cannot drift
 * apart in what they write or delete. The reserve is always [FILLER_RESERVE_BYTES], never a lowered one.
 */
class RunScheduledFillUseCase(
    private val engine: FillerEngine,
    private val resolver: FillerTargetResolver,
    private val storage: FillerStorage,
) {
    /** The place a schedule may fill: on a mounted local volume and writable now, otherwise null. */
    suspend fun usablePlace(location: String): FillerPlace? =
        resolver.place(location)?.takeIf { storage.validate(it.target) }

    /** The run's result; a cancellation is rethrown after the engine has deleted what it wrote. */
    suspend operator fun invoke(location: String, name: String): ScheduledFillResult {
        val place = resolver.place(location)
            ?: return error(ScheduledFillReason.FILL_NOT_LOCAL, "'$name' is not on a local storage device")
        cleanEarlierSessions()
        return resultOf(name, engine.run(place.target, FILLER_RESERVE_BYTES))
    }

    private fun resultOf(name: String, result: FillerResult): ScheduledFillResult = when (result) {
        FillerResult.Busy -> skipped(ScheduledFillReason.FILL_BUSY, "Storage filler is already running")
        FillerResult.InsufficientSpace ->
            skipped(ScheduledFillReason.FILL_NO_FREE_SPACE, "No free space above the reserve")
        FillerResult.InvalidTarget ->
            error(ScheduledFillReason.FILL_STORAGE_UNAVAILABLE, "'$name' is not connected or not writable")
        FillerResult.MeasurementUnavailable ->
            error(ScheduledFillReason.FILL_MEASUREMENT_UNAVAILABLE, "Free space could not be measured")
        FillerResult.PendingCleanup -> error(ScheduledFillReason.FILL_CLEANUP_PENDING, CLEANUP_PENDING_TEXT)
        is FillerResult.Finished -> if (result.cleanupComplete) {
            ScheduledFillResult(ScheduledFillOutcome.OK, writtenBytes = result.writtenBytes, sessionStarted = true)
        } else {
            error(ScheduledFillReason.FILL_CLEANUP_PENDING, CLEANUP_PENDING_TEXT, result.writtenBytes).started()
        }
        is FillerResult.Failed -> if (result.cleanupComplete) {
            error(ScheduledFillReason.FILL_WRITE_FAILED, "Writing failed; temporary files deleted").started()
        } else {
            error(ScheduledFillReason.FILL_CLEANUP_PENDING, CLEANUP_PENDING_TEXT).started()
        }
    }

    private fun ScheduledFillResult.started() = copy(sessionStarted = true)

    /**
     * A run interrupted earlier - a removed card, a killed process - leaves a journaled session the engine
     * refuses to start over. Retrying its cleanup here lets the next slot recover on its own once the storage
     * is back. The verdict is left to the engine's own run: a session that stays is its PendingCleanup, and a
     * session that is the interactive screen's live run is its Busy.
     */
    private suspend fun cleanEarlierSessions() {
        engine.pendingSessions().forEach { engine.retryCleanup(it) }
    }

    private fun error(reason: ScheduledFillReason, text: String, written: Long = 0L) =
        ScheduledFillResult(ScheduledFillOutcome.ERROR, reason, text, written)

    private fun skipped(reason: ScheduledFillReason, text: String) =
        ScheduledFillResult(ScheduledFillOutcome.SKIPPED, reason, text)

    private companion object {
        const val CLEANUP_PENDING_TEXT = "Temporary files from a fill are still on the storage"
    }
}
