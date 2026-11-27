package com.sza.filler.wear.run

import android.Manifest
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import android.text.format.DateUtils
import android.text.format.Formatter
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import androidx.wear.ongoing.OngoingActivity
import com.sza.filler.wear.FillerWearApplication
import com.sza.filler.wear.MainActivity
import com.sza.filler.wear.R
import com.sza.filler.wear.ui.WatchFillerState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * The host of one watch fill (S0019). A watch screen goes dark when the wrist drops, so the run cannot live on the
 * screen as it does on the phone: it lives here, in a foreground service of type dataSync ("local file
 * processing"), with an ongoing notification paired with an ongoing activity (Wear OS quality rule WO-V4), a
 * partial wake lock with a timeout backstop, and no restart by the platform: a killed run is not resumed, and the
 * next launch offers the cleanup of what it left (S0017 research note section 4, row 6, Assumed A3).
 *
 * Started only by [com.sza.filler.wear.ui.WatchFillerController.start], from the confirmation the user tapped.
 */
class FillerRunService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var run: Job? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var notification: NotificationCompat.Builder? = null
    private var lastPostedMillis = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val controller = (application as FillerWearApplication).controller
        if (intent?.action == ACTION_CANCEL) {
            controller.cancel()
            if (run == null) stopSelf(startId)
            return START_NOT_STICKY
        }
        if (run != null) return START_NOT_STICKY
        createChannel()
        val builder = buildNotification(controller.state.value)
        notification = builder
        // The platform demands the foreground promotion for every start of this kind, even one with nothing to run.
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            builder.build(),
            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
        )
        val job = controller.runIn(scope)
        if (job == null) {
            stopRun()
            return START_NOT_STICKY
        }
        run = job
        acquireWakeLock()
        scope.launch { controller.state.collect { post(it) } }
        scope.launch {
            job.join()
            stopRun()
        }
        return START_NOT_STICKY
    }

    /** The dataSync budget is spent (Android 15 and later): stop at once; the engine still deletes what it wrote. */
    override fun onTimeout(startId: Int, fgsType: Int) {
        (application as FillerWearApplication).controller.cancel()
        stopRun()
    }

    override fun onDestroy() {
        scope.cancel()
        releaseWakeLock()
        super.onDestroy()
    }

    private fun stopRun() {
        releaseWakeLock()
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun acquireWakeLock() {
        val power = getSystemService(PowerManager::class.java) ?: return
        wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKE_LOCK_TAG).apply {
            setReferenceCounted(false)
            acquire(WAKE_LOCK_TIMEOUT_MILLIS)
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
    }

    private fun createChannel() {
        val channel = NotificationChannelCompat.Builder(CHANNEL_ID, NotificationManagerCompat.IMPORTANCE_LOW)
            .setName(getString(R.string.filler_notification_channel))
            .build()
        NotificationManagerCompat.from(this).createNotificationChannel(channel)
    }

    private fun buildNotification(state: WatchFillerState): NotificationCompat.Builder {
        val open = PendingIntent.getActivity(
            this,
            REQUEST_OPEN,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val cancel = PendingIntent.getService(
            this,
            REQUEST_CANCEL,
            Intent(this, FillerRunService::class.java).setAction(ACTION_CANCEL),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_filler)
            .setContentTitle(getString(R.string.filler_notification_title))
            .setContentText(progressText(state))
            .setProgress(PROGRESS_SCALE, scaledProgress(state), false)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentIntent(open)
            .addAction(0, getString(R.string.filler_notification_stop), cancel)
        // The watch face shows this icon while a run is on: the inherited Filler block on its own grid (FILLER-0059).
        OngoingActivity.Builder(applicationContext, NOTIFICATION_ID, builder)
            .setStaticIcon(R.drawable.ic_stat_filler)
            .setTouchIntent(open)
            .build()
            .apply(applicationContext)
        return builder
    }

    /** At most once a second: a chunk lands many times a second, and every post wakes the notification system. */
    private fun post(state: WatchFillerState) {
        val builder = notification ?: return
        if (!state.running) return
        val now = SystemClock.elapsedRealtime()
        if (now - lastPostedMillis < POST_INTERVAL_MILLIS) return
        lastPostedMillis = now
        builder.setContentText(progressText(state)).setProgress(PROGRESS_SCALE, scaledProgress(state), false)
        // Without the notification permission the run still goes on; only the updated line is not shown. Below
        // Android 13 ContextCompat answers from whether notifications are enabled.
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            NotificationManagerCompat.from(this).notify(NOTIFICATION_ID, builder.build())
        }
    }

    private fun progressText(state: WatchFillerState): String {
        val written = Formatter.formatShortFileSize(this, state.writtenBytes)
        val planned = Formatter.formatShortFileSize(this, state.plannedBytes)
        val estimate = state.remainingMillis?.let {
            getString(R.string.filler_estimate, state.percentDone, DateUtils.formatElapsedTime(secondsFor(it)))
        } ?: getString(R.string.filler_estimate_calculating, state.percentDone)
        return getString(R.string.filler_progress, written, planned) + "\n" + estimate
    }

    private fun scaledProgress(state: WatchFillerState): Int =
        (state.writtenBytes * PROGRESS_SCALE / state.plannedBytes.coerceAtLeast(1)).toInt().coerceIn(0, PROGRESS_SCALE)

    companion object {
        private const val ACTION_CANCEL = "com.sza.filler.wear.action.CANCEL_RUN"
        private const val CHANNEL_ID = "filler_run"
        private const val NOTIFICATION_ID = 1
        private const val REQUEST_OPEN = 1
        private const val REQUEST_CANCEL = 2
        private const val PROGRESS_SCALE = 1000
        private const val POST_INTERVAL_MILLIS = 1_000L
        private const val WAKE_LOCK_TAG = "filler:run"

        /** The backstop of the CPU hold, the FastMediaSorter watch module's: a run that outlives it is not expected. */
        private const val WAKE_LOCK_TIMEOUT_MILLIS = 4L * 60 * 60 * 1000

        fun startIntent(context: Context): Intent = Intent(context, FillerRunService::class.java)

        /** Rounded up, so the last second shows 00:01 and the line never reads 00:00 while bytes are still going. */
        fun secondsFor(millis: Long): Long = (millis + 999) / 1000
    }
}
