package com.sza.filler.run

import android.content.Context
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import com.sza.filler.data.schedule.FillSchedule
import com.sza.filler.data.schedule.FillScheduleSlots
import java.util.concurrent.TimeUnit

// Ported in its scheduling model from FastMediaSorter release 48 (worker/WorkManagerScheduler.kt, S4522; S0025
// here): one one-time WorkManager request per slot, the next slot computed from the start time and the interval.
// Deliberate differences, recorded in S0025 section 3.4:
// - only the Filler is scheduled, so the source's 597 lines for every operation type shrink to this file;
// - no network constraint: a fill writes to a local storage device and needs no network, which is also why the
//   ACCESS_NETWORK_STATE permission WorkManager merges is removed from the manifest (owner decision Q1);
// - one unique work name per slot (the schedule id and the slot time) under a tag per schedule, instead of the
//   source's one name per operation with REPLACE: the worker queues the next slot while it still runs, and a REPLACE
//   of its own name would cancel the running fill. Queuing a slot is idempotent (KEEP), so the boot re-queue and
//   the app start may queue again without doubling a slot; an edit or a delete cancels by the tag.

/** Queues and cancels the slots of the scheduled fills on WorkManager. */
class FillScheduler(context: Context) {
    private val appContext = context.applicationContext

    private fun workManager() = WorkManager.getInstance(appContext)

    /** Queues the next slot of [schedule] after [now]; a switched-off schedule queues nothing. */
    fun queueNext(schedule: FillSchedule, now: Long = System.currentTimeMillis()) {
        if (!schedule.enabled) return
        val due = FillScheduleSlots.nextSlot(schedule, now)
        val request = OneTimeWorkRequestBuilder<ScheduledFillWorker>()
            .setInitialDelay((due - now).coerceAtLeast(0L), TimeUnit.MILLISECONDS)
            .setInputData(
                workDataOf(
                    ScheduledFillWorker.KEY_SCHEDULE to schedule.id,
                    ScheduledFillWorker.KEY_REVISION to schedule.revision,
                    ScheduledFillWorker.KEY_DUE to due,
                ),
            )
            .addTag(tag(schedule.id))
            .build()
        workManager().enqueueUniqueWork("${tag(schedule.id)}-$due", ExistingWorkPolicy.KEEP, request)
    }

    /** After an edit: the old slots go, a running fill of this schedule included, and the new next slot is queued. */
    fun replace(schedule: FillSchedule) {
        cancel(schedule.id)
        queueNext(schedule)
    }

    fun cancel(scheduleId: String) {
        workManager().cancelAllWorkByTag(tag(scheduleId))
    }

    /** Cancels pending work for every saved schedule (Pause all, FILLER-0067). */
    fun cancelAll(schedules: List<FillSchedule>) {
        schedules.forEach { cancel(it.id) }
    }

    /** Runs [schedule] immediately on user request without altering its regular cadence (FILLER-0067). */
    fun runNow(schedule: FillSchedule) {
        val request = OneTimeWorkRequestBuilder<ScheduledFillWorker>()
            .setInputData(
                workDataOf(
                    ScheduledFillWorker.KEY_SCHEDULE to schedule.id,
                    ScheduledFillWorker.KEY_REVISION to schedule.revision,
                    ScheduledFillWorker.KEY_DUE to 0L,
                    ScheduledFillWorker.KEY_MANUAL_TRIGGER to true,
                ),
            )
            .addTag(tag(schedule.id))
            .build()
        workManager().enqueueUniqueWork("${tag(schedule.id)}-run-now", ExistingWorkPolicy.KEEP, request)
    }

    /** The boot re-queue and the app start: every switched-on schedule has its next slot queued. */
    fun queueAll(schedules: List<FillSchedule>) {
        val now = System.currentTimeMillis()
        schedules.forEach { queueNext(it, now) }
    }

    private fun tag(scheduleId: String) = "$TAG_PREFIX$scheduleId"

    private companion object {
        const val TAG_PREFIX = "fill-schedule-"
    }
}
