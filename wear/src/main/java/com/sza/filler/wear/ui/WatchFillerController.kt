package com.sza.filler.wear.ui

import android.content.Context
import androidx.core.content.ContextCompat
import com.sza.filler.domain.filler.FILLER_RESERVE_BYTES
import com.sza.filler.domain.filler.FillerEngine
import com.sza.filler.domain.filler.FillerPlace
import com.sza.filler.domain.filler.FillerProgressEstimator
import com.sza.filler.domain.filler.FillerResult
import com.sza.filler.domain.filler.FillerSession
import com.sza.filler.wear.data.WatchFillerStorage
import com.sza.filler.wear.run.FillerRunService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit

// The watch flow (S0019), ported from the phone's FillerViewModel (ui/filler/FillerViewModel.kt, a port of
// FastMediaSorter release 48 with the reserve choice of S0005 and the percent and time left of S0009).
// Deliberate differences:
// - the host of a run: on the phone the run lives in viewModelScope and ends with the screen; a watch screen goes
//   dark when the wrist drops, so here start() asks for FillerRunService, a foreground service of type dataSync,
//   and the run is launched in that service's scope by runIn() (S0017 research note section 4 and row 6,
//   Assumed A3). The state lives in this process-wide object, so the screen can close and reopen during a run;
// - one place, the app-owned Downloads directory of the watch (S0017 row 2): there is no folder choice, so the
//   place is measured again whenever the screen comes back (refresh), and a stale measurement verdict is dropped;
// - the reserve is moved one stop at a time (stepReserve), the round-screen operation of the phone's slider.
// The engine, the journal and the estimator are filler-core's, consumed and never copied (S0013 criterion 4).
// Every member is called on the main thread: the screen, the service callbacks and the scopes it is given are
// all main-thread confined.

/** Owns the watch Filler state for the life of the process; the run itself belongs to [FillerRunService]. */
class WatchFillerController(
    private val context: Context,
    private val engine: FillerEngine,
    private val storage: WatchFillerStorage,
    private val scope: CoroutineScope,
) {
    private class PreparedRun(val place: FillerPlace, val reserveBytes: Long, val plannedBytes: Long)

    private val mutableState = MutableStateFlow(WatchFillerState())
    val state: StateFlow<WatchFillerState> = mutableState.asStateFlow()

    private val estimator = FillerProgressEstimator()
    private var preparedRun: PreparedRun? = null
    private var run: Job? = null
    private var pendingSession: FillerSession? = null
    private var selectionVersion = 0

    /** Measures the place again and reads the journal; called whenever the screen becomes visible. */
    fun refresh() {
        if (mutableState.value.running) return
        mutableState.update {
            if (it.outcome in WatchFillerState.SELECTION_PROBLEMS) it.copy(outcome = null) else it
        }
        scope.launch {
            refreshPending()
            select()
        }
    }

    /** Moves the reserve one stop down (negative) or up (positive); the value belongs to the next run only. */
    fun stepReserve(direction: Int) {
        val choices = WatchFillerState.RESERVE_CHOICES_BYTES
        mutableState.update { current ->
            val index = current.reserveIndex + direction.coerceIn(-1, 1)
            if (current.running || index !in choices.indices) {
                current
            } else {
                val bytes = choices[index]
                current.copy(reserveBytes = bytes, outcome = outcomeForReserve(current, bytes))
            }
        }
    }

    /**
     * Called by the confirmation: marks the run as started and asks the platform for its foreground host, which
     * calls [runIn]. False when nothing may start, or when the platform refused the host.
     */
    fun start(): Boolean {
        val current = state.value
        val place = current.place
        if (!current.canStart || place == null || preparedRun != null || run?.isActive == true) return false
        val planned = (current.availableBytes ?: 0) - current.reserveBytes
        preparedRun = PreparedRun(place, current.reserveBytes, planned)
        estimator.reset()
        estimator.record(0, nowMillis())
        mutableState.update {
            it.copy(running = true, plannedBytes = planned, writtenBytes = 0, remainingMillis = null, outcome = null)
        }
        return try {
            ContextCompat.startForegroundService(context, FillerRunService.startIntent(context))
            true
        } catch (_: IllegalStateException) {
            // ForegroundServiceStartNotAllowedException is an IllegalStateException; nothing was written yet.
            preparedRun = null
            mutableState.update {
                it.copy(running = false, outcome = WatchFillerOutcome.NOT_STARTED, reserveBytes = FILLER_RESERVE_BYTES)
            }
            false
        }
    }

    /** Launches the prepared run in the scope of its foreground host; null when nothing is prepared any more. */
    fun runIn(hostScope: CoroutineScope): Job? {
        val prepared = preparedRun ?: return null
        preparedRun = null
        // Undispatched, so the body is inside its try before any cancellation of the host can arrive, and the
        // finally below always clears the running state.
        val job = hostScope.launch(start = CoroutineStart.UNDISPATCHED) {
            var outcome = WatchFillerOutcome.CANCELLED
            try {
                outcome = outcomeOf(
                    engine.run(prepared.place.target, prepared.reserveBytes) { written ->
                        estimator.record(written, nowMillis())
                        mutableState.update {
                            it.copy(
                                writtenBytes = written,
                                remainingMillis = estimator.remainingMillis(prepared.plannedBytes),
                            )
                        }
                    },
                )
            } finally {
                withContext(NonCancellable) { finishRun(outcome) }
            }
        }
        run = job
        return job
    }

    /** Stops the run; the engine deletes what it wrote, because its cleanup runs outside cancellation. */
    fun cancel() {
        if (preparedRun != null) {
            preparedRun = null
            mutableState.update {
                it.copy(running = false, outcome = WatchFillerOutcome.CANCELLED, reserveBytes = FILLER_RESERVE_BYTES)
            }
            return
        }
        run?.cancel()
    }

    fun retryCleanup() {
        val session = pendingSession ?: return
        if (mutableState.value.running || run?.isActive == true) return
        run = scope.launch {
            val cleaned = engine.retryCleanup(session)
            refreshPending()
            mutableState.update {
                it.copy(
                    outcome = if (cleaned) WatchFillerOutcome.CLEANUP_DONE else WatchFillerOutcome.CLEANUP_INCOMPLETE,
                )
            }
            select()
        }
    }

    /** A lowered reserve was chosen for this run only, so the next start screen offers the default again. */
    private suspend fun finishRun(outcome: WatchFillerOutcome) {
        refreshPending()
        val residual = pendingSession != null
        val shown = if (residual && outcome != WatchFillerOutcome.BUSY) WatchFillerOutcome.CLEANUP_INCOMPLETE else outcome
        mutableState.update {
            it.copy(running = false, remainingMillis = null, outcome = shown, reserveBytes = FILLER_RESERVE_BYTES)
        }
        select()
    }

    /** Monotonic, so a wall-clock change during a long run cannot turn the estimate negative. */
    private fun nowMillis(): Long = TimeUnit.NANOSECONDS.toMillis(System.nanoTime())

    private suspend fun select() {
        val version = ++selectionVersion
        val place = storage.defaultLocation()?.let { storage.place(it) }
        if (place == null) {
            if (version == selectionVersion) {
                mutableState.update {
                    it.copy(
                        place = null,
                        accessible = false,
                        availableBytes = null,
                        outcome = it.outcome ?: WatchFillerOutcome.NO_PLACE,
                    )
                }
            }
            return
        }
        val accessible = storage.validate(place.target)
        val available = if (accessible) storage.availableBytes(place.target) else null
        if (version != selectionVersion) return
        mutableState.update {
            it.copy(
                place = place,
                accessible = accessible,
                availableBytes = available,
                outcome = it.outcome ?: selectionProblem(accessible, available, it.reserveBytes),
            )
        }
    }

    private suspend fun refreshPending() {
        val session = engine.pendingSessions().firstOrNull()
        pendingSession = session
        mutableState.update { it.copy(pending = session != null) }
    }

    private fun selectionProblem(accessible: Boolean, available: Long?, reserveBytes: Long): WatchFillerOutcome? =
        when {
            !accessible -> WatchFillerOutcome.NO_ACCESS
            available == null -> WatchFillerOutcome.MEASUREMENT_UNAVAILABLE
            available <= reserveBytes -> WatchFillerOutcome.INSUFFICIENT_SPACE
            else -> null
        }

    /** Only the no-space verdict depends on the reserve, so any other shown outcome is kept as it is. */
    private fun outcomeForReserve(current: WatchFillerState, reserveBytes: Long): WatchFillerOutcome? {
        val dependsOnReserve = current.outcome == null || current.outcome == WatchFillerOutcome.INSUFFICIENT_SPACE
        return if (current.place != null && dependsOnReserve) {
            selectionProblem(current.accessible, current.availableBytes, reserveBytes)
        } else {
            current.outcome
        }
    }

    private fun outcomeOf(result: FillerResult): WatchFillerOutcome = when (result) {
        FillerResult.Busy -> WatchFillerOutcome.BUSY
        FillerResult.InvalidTarget -> WatchFillerOutcome.NO_ACCESS
        FillerResult.MeasurementUnavailable -> WatchFillerOutcome.MEASUREMENT_UNAVAILABLE
        FillerResult.InsufficientSpace -> WatchFillerOutcome.INSUFFICIENT_SPACE
        FillerResult.PendingCleanup -> WatchFillerOutcome.CLEANUP_INCOMPLETE
        is FillerResult.Finished ->
            if (result.cleanupComplete) WatchFillerOutcome.DONE else WatchFillerOutcome.CLEANUP_INCOMPLETE
        is FillerResult.Failed ->
            if (result.cleanupComplete) WatchFillerOutcome.FAILED else WatchFillerOutcome.CLEANUP_INCOMPLETE
    }
}
