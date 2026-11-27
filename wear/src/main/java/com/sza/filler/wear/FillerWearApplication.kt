package com.sza.filler.wear

import android.app.Application
import com.sza.filler.data.filler.FillerSessionJournal
import com.sza.filler.domain.filler.FillerEngine
import com.sza.filler.wear.data.WatchFillerStorage
import com.sza.filler.wear.ui.WatchFillerController
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

/**
 * Holds the one journal, storage adapter, engine and flow controller of the watch process, as the phone's
 * FillerApplication does: this app has no dependency injection. The journal and the engine are filler-core's.
 */
class FillerWearApplication : Application() {
    /** Lives as long as the process; main-thread confined, as the controller requires. */
    private val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    val journal: FillerSessionJournal by lazy { FillerSessionJournal(this, applicationScope) }

    val storage: WatchFillerStorage by lazy { WatchFillerStorage(this, journal) }

    val engine: FillerEngine by lazy { FillerEngine(storage, journal) }

    val controller: WatchFillerController by lazy {
        WatchFillerController(this, engine, storage, applicationScope)
    }
}
