package com.sza.filler.run

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.sza.filler.FillerApplication
import kotlinx.coroutines.launch

// Ported in its role from FastMediaSorter release 48 (ScheduledOperationsBootReceiver, S4522; S0025 here): after a
// restart of the phone or an update of the app, every switched-on schedule has its next slot queued. WorkManager keeps
// its own queue across a restart too; queuing is idempotent (FillScheduler), so this only fills a slot that is missing.

class FillScheduleBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED && intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val app = context.applicationContext as FillerApplication
        Log.d("Probe", "FILLER-0025: boot re-queue on ${intent.action}")
        val pending = goAsync()
        app.applicationScope.launch {
            try {
                app.queueSchedules()
            } finally {
                pending.finish()
            }
        }
    }
}
