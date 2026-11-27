package com.sza.filler.run

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.CoroutineWorker
import androidx.work.ForegroundInfo
import androidx.work.WorkerParameters
import com.sza.filler.FillerApplication
import com.sza.filler.R
import com.sza.filler.data.schedule.FillHistoryEntry
import com.sza.filler.data.schedule.FillSchedule
import com.sza.filler.data.schedule.FillScheduleSlots
import com.sza.filler.domain.filler.ScheduledFillOutcome
import com.sza.filler.domain.filler.ScheduledFillReason
import com.sza.filler.domain.filler.ScheduledFillResult
import com.sza.filler.ui.schedule.ScheduleActivity
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext

// Ported in its run model from FastMediaSorter release 48 (worker/ScheduledOperationsWorker.kt and the
// FILL_FREE_SPACE branch of domain/usecase/ExecuteScheduledOperationUseCase.kt, S4522; S0025 here): the worker
// promotes itself to a dataSync foreground service where the system allows it and goes on without it otherwise,
// runs the fill through the engine's use case and records the result. Deliberate differences:
// - only the Filler runs here, and the run goes through CappedScheduledFill, the daily cap the source does not have;
// - every attempt is written to the history, a stop before the end included (FILL_STOPPED), and the slot's due time
//   is kept beside its start so the screen can say when the system delayed it (S0025 criteria 4 and 5);
// - the next slot is queued by the worker itself (FillScheduler), not by the source's shared dispatcher.

/** One slot of one scheduled fill. */
class ScheduledFillWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val app = applicationContext as FillerApplication
        val id = inputData.getString(KEY_SCHEDULE) ?: return Result.success()
        val schedule = app.schedules.schedule(id)
        val manualTrigger = inputData.getBoolean(KEY_MANUAL_TRIGGER, false)
        // A deleted schedule cannot run; an unattended timer slot also stops if turned off, globally paused, or superseded.
        if (schedule == null) return Result.success()
        if (!manualTrigger && (!schedule.enabled || app.schedules.isPaused() ||
                schedule.revision != inputData.getLong(KEY_REVISION, -1L))
        ) {
            return Result.success()
        }
        val due = inputData.getLong(KEY_DUE, 0L)
        val startedAt = System.currentTimeMillis()
        Log.d("Probe", "FILLER-0025: scheduled fill slot runs, late by ${startedAt - due} ms")
        promoteToForeground(schedule)
        val result = try {
            if (manualTrigger) {
                app.scheduledFill(schedule.location, schedule.folderName)
            } else {
                app.cappedFill(schedule.location, schedule.folderName, FillScheduleSlots.today(startedAt))
            }
        } catch (cancelled: CancellationException) {
            withContext(NonCancellable) { record(app, schedule, due, startedAt, STOPPED) }
            throw cancelled
        }
        record(app, schedule, due, startedAt, result)
        if (!manualTrigger && !app.schedules.isPaused()) app.scheduler.queueNext(schedule)
        return Result.success()
    }

    override suspend fun getForegroundInfo(): ForegroundInfo = foregroundInfo(null)

    private suspend fun record(
        app: FillerApplication,
        schedule: FillSchedule,
        due: Long,
        startedAt: Long,
        result: ScheduledFillResult,
    ) {
        app.schedules.addHistory(
            FillHistoryEntry(
                scheduleId = schedule.id,
                folderName = schedule.folderName,
                volumeName = schedule.volumeName,
                dueAt = due,
                startedAt = startedAt,
                outcome = result.outcome,
                reason = result.reason,
                writtenBytes = result.writtenBytes,
            ),
        )
    }

    // Android 12 and later may refuse a foreground start from the background; the run then goes on as a plain
    // worker, within the system's limits for one, as the source's worker does.
    private suspend fun promoteToForeground(schedule: FillSchedule) {
        try {
            setForeground(foregroundInfo(schedule.folderName))
        } catch (refused: IllegalStateException) {
            Log.w(LOG_TAG, "Scheduled fill runs without a foreground service", refused)
        }
    }

    private fun foregroundInfo(folderName: String?): ForegroundInfo {
        val context = applicationContext
        NotificationManagerCompat.from(context).createNotificationChannel(
            NotificationChannelCompat.Builder(CHANNEL_ID, NotificationManagerCompat.IMPORTANCE_LOW)
                .setName(context.getString(R.string.schedule_notification_channel))
                .build(),
        )
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, ScheduleActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val text = folderName?.let { context.getString(R.string.schedule_notification_text, it) }
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_filler)
            .setContentTitle(context.getString(R.string.schedule_notification_title))
            .setContentText(text)
            .setContentIntent(open)
            .setOngoing(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ForegroundInfo(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            ForegroundInfo(NOTIFICATION_ID, notification)
        }
    }

    companion object {
        const val KEY_SCHEDULE = "schedule"
        const val KEY_REVISION = "revision"
        const val KEY_DUE = "due"
        const val KEY_MANUAL_TRIGGER = "manualTrigger"

        private const val LOG_TAG = "ScheduledFillWorker"
        private const val CHANNEL_ID = "scheduled-fill"
        private const val NOTIFICATION_ID = 1

        private val STOPPED = ScheduledFillResult(
            ScheduledFillOutcome.ERROR,
            ScheduledFillReason.FILL_STOPPED,
            "Stopped before the end; the engine deleted what it wrote",
        )
    }
}
