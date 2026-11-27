package com.sza.filler

import android.app.Application
import com.sza.filler.data.filler.AppFillerStorage
import com.sza.filler.data.filler.FillerSessionJournal
import com.sza.filler.data.filler.LocalFillerStorage
import com.sza.filler.data.repository.PlatformStorageVolumeSource
import com.sza.filler.data.schedule.FillScheduleStore
import com.sza.filler.domain.filler.CappedScheduledFill
import com.sza.filler.domain.filler.FillerEngine
import com.sza.filler.domain.filler.RunScheduledFillUseCase
import com.sza.filler.run.FillScheduler
import com.sza.filler.ui.theme.ColorThemePrefs
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.withContext

/**
 * Holds the one journal, storage adapter and engine of the process. The source gets them from Hilt as
 * singletons; this app has no dependency injection, so the application object is where they are built once.
 * The scheduled fill (S0025) runs through the same engine and journal as the screen, so the two cannot differ
 * in what they write or delete.
 */
class FillerApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        ColorThemePrefs.applySavedMode(this)
    }
    /** Lives as long as the process, like the source's application scope the journal reads itself in. */
    val applicationScope = CoroutineScope(SupervisorJob())

    val journal: FillerSessionJournal by lazy { FillerSessionJournal(this, applicationScope) }

    val storage: LocalFillerStorage by lazy {
        val volumes = PlatformStorageVolumeSource(this)
        LocalFillerStorage(this, volumes, journal, AppFillerStorage(this, volumes, journal))
    }

    val engine: FillerEngine by lazy { FillerEngine(storage, journal) }

    val schedules: FillScheduleStore by lazy { FillScheduleStore(this, applicationScope) }

    val scheduler: FillScheduler by lazy { FillScheduler(this) }

    /** The run of one slot: the engine's verdict as a schedule result, without the daily cap. */
    val scheduledFill: RunScheduledFillUseCase by lazy { RunScheduledFillUseCase(engine, storage, storage) }

    /** What a slot actually calls: the run behind the daily cap of unattended fills. */
    val cappedFill: CappedScheduledFill by lazy { CappedScheduledFill(scheduledFill, schedules) }

    /** Queues the next slot of every switched-on schedule unless schedules are globally paused (FILLER-0067). */
    suspend fun queueSchedules() {
        if (schedules.isPaused()) return
        val saved = schedules.schedules()
        withContext(Dispatchers.Default) { scheduler.queueAll(saved) }
    }
}
