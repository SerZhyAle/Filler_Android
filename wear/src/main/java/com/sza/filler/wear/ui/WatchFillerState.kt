package com.sza.filler.wear.ui

import com.sza.filler.domain.filler.FILLER_MIN_RESERVE_BYTES
import com.sza.filler.domain.filler.FILLER_RESERVE_BYTES
import com.sza.filler.domain.filler.FillerPlace

// The watch screen state (S0019), ported from the phone's FillerUiState and FillerOutcome (ui/filler/FillerViewModel.kt,
// itself a port of FastMediaSorter release 48 with the reserve choice of S0005 and the percent of S0009).
// Deliberate differences:
// - one place, so the pending session is a flag and not a named place, and NOT_LOCAL (a picked folder off every
//   local volume) becomes NO_PLACE (the app-owned directory of the watch is not available);
// - NOT_STARTED: the platform refused the run's foreground host, a case the phone, which runs on its screen, has not.
// The reserve stops, the start rule and the percent are the phone's, unchanged (FILLER-RESERVE rules 1 to 4).

enum class WatchFillerOutcome {
    DONE,
    CANCELLED,
    FAILED,
    CLEANUP_INCOMPLETE,
    CLEANUP_DONE,
    NO_PLACE,
    NO_ACCESS,
    MEASUREMENT_UNAVAILABLE,
    INSUFFICIENT_SPACE,
    BUSY,
    NOT_STARTED,
}

data class WatchFillerState(
    val place: FillerPlace? = null,
    val accessible: Boolean = false,
    val availableBytes: Long? = null,
    val running: Boolean = false,
    val plannedBytes: Long = 0,
    val writtenBytes: Long = 0,
    /** Null until the run has been observed long enough for a time to be honest. */
    val remainingMillis: Long? = null,
    /** An earlier session still lists files in the journal; Start stays refused until they are deleted. */
    val pending: Boolean = false,
    val outcome: WatchFillerOutcome? = null,
    val reserveBytes: Long = FILLER_RESERVE_BYTES,
) {
    /** Unknown free space (null) never starts a run, exactly as on the phone. */
    val canStart: Boolean
        get() = !running && !pending && accessible && (availableBytes ?: 0) > reserveBytes

    val reserveIndex: Int
        get() = RESERVE_CHOICES_BYTES.indexOf(reserveBytes).takeIf { it >= 0 } ?: RESERVE_CHOICES_BYTES.lastIndex

    val canLowerReserve: Boolean get() = !running && reserveIndex > 0

    val canRaiseReserve: Boolean get() = !running && reserveIndex < RESERVE_CHOICES_BYTES.lastIndex

    /** Free space can change while a run is going, so the share is clamped rather than trusted past 100. */
    val percentDone: Int
        get() = if (plannedBytes <= 0) {
            0
        } else {
            (writtenBytes * PERCENT_FULL / plannedBytes).toInt().coerceIn(0, PERCENT_FULL)
        }

    companion object {
        private const val PERCENT_FULL = 100

        /** The phone's seven stops, lowest first; the engine itself accepts any value from its floor up. */
        val RESERVE_CHOICES_BYTES: List<Long> = listOf(
            FILLER_MIN_RESERVE_BYTES,
            25L shl 20,
            50L shl 20,
            100L shl 20,
            250L shl 20,
            500L shl 20,
            FILLER_RESERVE_BYTES,
        )

        /** Verdicts about the place as it was measured; a fresh measurement replaces them. */
        val SELECTION_PROBLEMS: Set<WatchFillerOutcome> = setOf(
            WatchFillerOutcome.NO_PLACE,
            WatchFillerOutcome.NO_ACCESS,
            WatchFillerOutcome.MEASUREMENT_UNAVAILABLE,
            WatchFillerOutcome.INSUFFICIENT_SPACE,
        )
    }
}
