package com.sza.filler.ui.schedule

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.sza.filler.FillerApplication
import com.sza.filler.data.schedule.FillSchedule
import com.sza.filler.data.schedule.FillScheduleData
import com.sza.filler.data.schedule.FillScheduleSlots
import com.sza.filler.data.schedule.FillScheduleStore
import com.sza.filler.domain.filler.FillerPlace
import com.sza.filler.domain.filler.FillerTargetResolver
import com.sza.filler.domain.filler.RunScheduledFillUseCase
import com.sza.filler.run.FillScheduler
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.UUID

// This product's own (S0025). The confirmation rule is ported from FastMediaSorter release 48
// (ui/scheduledops/ScheduledOperationsDialogManager.confirmFill, S4522): a schedule is saved only for a place
// usablePlace accepts now, and only after a confirmation naming the reserve. The source's editor serves every
// operation type; this one asks only for the folder, the time and the interval.

/** A schedule being made ([editingId] null) or changed. [place] is null until a usable folder is chosen. */
data class ScheduleDraft(
    val editingId: String?,
    val location: String?,
    val place: FillerPlace?,
    val minuteOfDay: Int,
    val intervalDays: Int,
)

class ScheduleViewModel(
    private val store: FillScheduleStore,
    private val scheduler: FillScheduler,
    private val resolver: FillerTargetResolver,
    private val scheduledFill: RunScheduledFillUseCase,
    private val clock: () -> Long = System::currentTimeMillis,
) : ViewModel() {

    val data: StateFlow<FillScheduleData> = store.data

    private val draftState = MutableStateFlow<ScheduleDraft?>(null)
    val draft: StateFlow<ScheduleDraft?> = draftState.asStateFlow()

    /** True once a picked folder turned out not usable; the screen shows the sentence once and clears it. */
    private val notUsableState = MutableStateFlow(false)
    val notUsable: StateFlow<Boolean> = notUsableState.asStateFlow()

    /** A new schedule starts with the folder the Filler screen uses by default, at the default time, every day. */
    fun startNew() {
        viewModelScope.launch {
            val location = resolver.defaultLocation()
            val place = location?.let { scheduledFill.usablePlace(it) }
            draftState.value = ScheduleDraft(null, location.takeIf { place != null }, place, DEFAULT_MINUTE, 1)
        }
    }

    fun edit(schedule: FillSchedule) {
        viewModelScope.launch {
            val place = scheduledFill.usablePlace(schedule.location)
            draftState.value = ScheduleDraft(
                schedule.id,
                schedule.location.takeIf { place != null },
                place,
                schedule.minuteOfDay,
                schedule.intervalDays,
            )
        }
    }

    fun onFolderPicked(location: String) {
        viewModelScope.launch {
            resolver.grant(location)
            val place = scheduledFill.usablePlace(location)
            if (place == null) {
                notUsableState.value = true
            } else {
                draftState.update { it?.copy(location = location, place = place) }
            }
        }
    }

    fun setTime(minuteOfDay: Int) = draftState.update { it?.copy(minuteOfDay = minuteOfDay) }

    fun setInterval(days: Int) = draftState.update { it?.copy(intervalDays = days) }

    fun cancelDraft() {
        draftState.value = null
    }

    fun notUsableShown() {
        notUsableState.value = false
    }

    /** The place the draft may be saved for, checked again now; null means the screen says why and saves nothing. */
    suspend fun usableDraftPlace(): FillerPlace? {
        val location = draftState.value?.location ?: return null
        return scheduledFill.usablePlace(location).also { if (it == null) notUsableState.value = true }
    }

    /** Saves the confirmed draft and queues its next slot; an edit replaces the old slots. */
    fun commit(place: FillerPlace) {
        val draft = draftState.value ?: return
        val location = draft.location ?: return
        viewModelScope.launch {
            val now = clock()
            val previous = draft.editingId?.let { store.schedule(it) }
            val schedule = FillSchedule(
                id = draft.editingId ?: UUID.randomUUID().toString(),
                location = location,
                folderName = place.folderName,
                volumeName = place.volumeName,
                minuteOfDay = draft.minuteOfDay,
                intervalDays = draft.intervalDays,
                firstDay = FillScheduleSlots.firstDay(draft.minuteOfDay, now),
                enabled = previous?.enabled ?: true,
                revision = now,
            )
            store.save(schedule)
            Log.d("Probe", "FILLER-0025: schedule saved, every ${schedule.intervalDays} day(s) at minute ${schedule.minuteOfDay}")
            if (schedule.enabled && !store.isPaused()) scheduler.replace(schedule) else scheduler.cancel(schedule.id)
            draftState.value = null
        }
    }

    fun setEnabled(schedule: FillSchedule, enabled: Boolean) {
        if (schedule.enabled == enabled) return
        viewModelScope.launch {
            val changed = schedule.copy(enabled = enabled, revision = clock())
            store.save(changed)
            if (enabled && !store.isPaused()) scheduler.replace(changed) else scheduler.cancel(changed.id)
        }
    }

    fun runNow(schedule: FillSchedule) {
        scheduler.runNow(schedule)
        Log.d("Probe", "FILLER-0067: schedule run now queued for ${schedule.id}")
    }

    fun togglePauseAll() {
        viewModelScope.launch {
            val nextPaused = !store.isPaused()
            store.setPaused(nextPaused)
            val saved = store.schedules()
            if (nextPaused) scheduler.cancelAll(saved) else scheduler.queueAll(saved)
            Log.d("Probe", "FILLER-0067: schedules paused=$nextPaused")
        }
    }

    fun clearHistory() {
        viewModelScope.launch {
            store.clearHistory()
            Log.d("Probe", "FILLER-0067: schedule history cleared")
        }
    }

    fun delete(schedule: FillSchedule) {
        viewModelScope.launch {
            scheduler.cancel(schedule.id)
            store.delete(schedule.id)
            if (draftState.value?.editingId == schedule.id) draftState.value = null
        }
    }

    companion object {
        /** 03:00, a time the phone is usually charging and unused. */
        const val DEFAULT_MINUTE = 3 * 60

        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val app = checkNotNull(this[APPLICATION_KEY]) as FillerApplication
                ScheduleViewModel(app.schedules, app.scheduler, app.storage, app.scheduledFill)
            }
        }
    }
}
