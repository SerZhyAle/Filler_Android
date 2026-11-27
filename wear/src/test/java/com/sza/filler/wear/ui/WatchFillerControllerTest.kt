package com.sza.filler.wear.ui

import android.os.Environment
import com.sza.filler.data.filler.FillerSessionJournal
import com.sza.filler.domain.filler.FILLER_MIN_RESERVE_BYTES
import com.sza.filler.domain.filler.FILLER_RESERVE_BYTES
import com.sza.filler.domain.filler.FillerEngine
import com.sza.filler.domain.filler.FillerFile
import com.sza.filler.domain.filler.FillerJournal
import com.sza.filler.domain.filler.FillerSession
import com.sza.filler.domain.filler.FillerStorage
import com.sza.filler.domain.filler.FillerTarget
import com.sza.filler.wear.NoExternalDirectoryContext
import com.sza.filler.wear.RecordingHostContext
import com.sza.filler.wear.data.WatchFillerStorage
import com.sza.filler.wear.registerFreeBytes
import com.sza.filler.wear.run.FillerRunService
import com.sza.filler.wear.runWatchTest
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.job
import kotlinx.coroutines.joinAll
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowEnvironment
import org.robolectric.shadows.ShadowStatFs
import java.io.File
import java.io.IOException
import java.util.UUID

// The watch flow controller (S0029). Its phone counterparts are FillerViewModelReserveTest (the reserve and the start
// rule) and FillerViewModelStartFlowTest; the source of the port has no test of its screen model, so these cases are
// this app's own. Deliberate differences from the phone's tests:
// - the controller takes the concrete WatchFillerStorage, so the place it measures is the real adapter over a real
//   Context, its free space registered with Robolectric's StatFs; the engine it runs is built over a hand-written
//   storage and journal (the phone test's FakeStorage and FakeJournal), because a real adapter cannot shrink a
//   registered StatFs while it writes. The adapter's own behaviour is WatchFillerStorageTest's;
// - the run is hosted by the test's scope in place of FillerRunService (a service run needs a device, S0020), and the
//   platform's start of that service is observed through RecordingHostContext;
// - a test body runs in runWatchTest (real threads, a timeout) instead of runTest, see WatchTestSupport.kt.

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class WatchFillerControllerTest {
    private val context = RuntimeEnvironment.getApplication()
    private val host = RecordingHostContext(context)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Unconfined)
    private val journalScope = CoroutineScope(Dispatchers.Unconfined)
    private val engineStorage = FakeStorage(FREE_BYTES)
    private val engineJournal = FakeJournal()
    private lateinit var downloads: File
    private lateinit var journal: FillerSessionJournal
    private lateinit var storage: WatchFillerStorage
    private lateinit var controller: WatchFillerController

    @Before
    fun setUp() {
        File(context.noBackupFilesDir, "filler-sessions.json").delete()
        File(context.noBackupFilesDir, "filler-sessions.json.bak").delete()
        File(context.noBackupFilesDir, "filler-sessions.json.new").delete()
        downloads = requireNotNull(context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)).canonicalFile
        ShadowEnvironment.setExternalStorageState(downloads, Environment.MEDIA_MOUNTED)
        registerFreeBytes(downloads, FREE_BYTES)
        journal = FillerSessionJournal(context, journalScope)
        storage = WatchFillerStorage(context, journal)
        controller = WatchFillerController(host, FillerEngine(engineStorage, engineJournal), storage, scope)
    }

    @After
    fun tearDown() = runBlocking {
        scope.cancel()
        journalScope.coroutineContext.job.cancelAndJoin()
    }

    // The start rule and the place.

    @Test
    fun `the default reserve refuses a free space of less than one gibibyte`() = runWatchTest {
        val state = refreshed()

        assertEquals(FILLER_RESERVE_BYTES, state.reserveBytes)
        assertEquals(LOCATION, state.place?.target?.location)
        assertTrue(state.accessible)
        assertEquals(FREE_BYTES, state.availableBytes)
        assertFalse(state.canStart)
        assertEquals(WatchFillerOutcome.INSUFFICIENT_SPACE, state.outcome)
    }

    @Test
    fun `a run needs a measured free space strictly above the reserve`() = runWatchTest {
        registerFreeBytes(downloads, FILLER_RESERVE_BYTES)
        val equal = refreshed()
        assertFalse(equal.canStart)
        assertEquals(WatchFillerOutcome.INSUFFICIENT_SPACE, equal.outcome)

        registerFreeBytes(downloads, FILLER_RESERVE_BYTES + BLOCK)
        val above = refreshed()
        assertTrue(above.canStart)
        assertNull(above.outcome)
    }

    @Test
    fun `an unmounted volume is not accessible and never starts a run`() = runWatchTest {
        ShadowEnvironment.setExternalStorageState(downloads, Environment.MEDIA_UNMOUNTED)

        val state = refreshed()

        assertNotNull(state.place)
        assertFalse(state.accessible)
        assertNull(state.availableBytes)
        assertEquals(WatchFillerOutcome.NO_ACCESS, state.outcome)
        assertFalse(state.canStart)
        assertFalse(controller.start())
        assertTrue(host.startedServices.isEmpty())
    }

    @Test
    fun `without an app-owned directory there is no place`() = runWatchTest {
        val bare = WatchFillerStorage(NoExternalDirectoryContext(context), journal)
        val bareController = WatchFillerController(host, FillerEngine(engineStorage, engineJournal), bare, scope)

        bareController.refresh()
        settle()
        val state = bareController.state.value

        assertNull(state.place)
        assertFalse(state.accessible)
        assertNull(state.availableBytes)
        assertEquals(WatchFillerOutcome.NO_PLACE, state.outcome)
        assertFalse(state.canStart)
        assertFalse(bareController.start())
    }

    @Test
    fun `the next refresh drops a stale verdict about the place`() = runWatchTest {
        ShadowEnvironment.setExternalStorageState(downloads, Environment.MEDIA_UNMOUNTED)
        assertEquals(WatchFillerOutcome.NO_ACCESS, refreshed().outcome)

        ShadowEnvironment.setExternalStorageState(downloads, Environment.MEDIA_MOUNTED)
        registerFreeBytes(downloads, 2L shl 30)
        val state = refreshed()

        assertNull(state.outcome)
        assertTrue(state.accessible)
        assertTrue(state.canStart)
    }

    @Test
    fun `a refresh does nothing while a run is going`() = runWatchTest {
        readyToStart()
        assertTrue(controller.start())
        registerFreeBytes(downloads, 2L shl 30)

        controller.refresh()
        settle()

        assertEquals(FREE_BYTES, controller.state.value.availableBytes)
        assertTrue(controller.state.value.running)
        controller.cancel()
    }

    // The seven reserve stops.

    @Test
    fun `the reserve moves one stop at a time and stops at both ends`() {
        val seen = mutableListOf(controller.state.value.reserveBytes)
        repeat(WatchFillerState.RESERVE_CHOICES_BYTES.size - 1) {
            controller.stepReserve(-1)
            seen += controller.state.value.reserveBytes
        }
        assertEquals(WatchFillerState.RESERVE_CHOICES_BYTES.reversed(), seen)

        controller.stepReserve(-1)
        assertEquals(FILLER_MIN_RESERVE_BYTES, controller.state.value.reserveBytes)

        repeat(WatchFillerState.RESERVE_CHOICES_BYTES.size - 1) { controller.stepReserve(1) }
        assertEquals(FILLER_RESERVE_BYTES, controller.state.value.reserveBytes)

        controller.stepReserve(1)
        assertEquals(FILLER_RESERVE_BYTES, controller.state.value.reserveBytes)
    }

    @Test
    fun `a step larger than one still moves one stop`() {
        controller.stepReserve(-5)
        assertEquals(500L shl 20, controller.state.value.reserveBytes)

        controller.stepReserve(5)
        assertEquals(FILLER_RESERVE_BYTES, controller.state.value.reserveBytes)
    }

    @Test
    fun `lowering the reserve clears the no-space verdict and raising it brings it back`() = runWatchTest {
        refreshed()

        controller.stepReserve(-1)
        assertEquals(500L shl 20, controller.state.value.reserveBytes)
        assertEquals(WatchFillerOutcome.INSUFFICIENT_SPACE, controller.state.value.outcome)
        assertFalse(controller.state.value.canStart)

        controller.stepReserve(-1)
        assertNull(controller.state.value.outcome)
        assertTrue(controller.state.value.canStart)

        controller.stepReserve(1)
        assertEquals(WatchFillerOutcome.INSUFFICIENT_SPACE, controller.state.value.outcome)
        assertFalse(controller.state.value.canStart)
    }

    @Test
    fun `another shown outcome is kept when the reserve moves`() = runWatchTest {
        ShadowEnvironment.setExternalStorageState(downloads, Environment.MEDIA_UNMOUNTED)
        refreshed()

        controller.stepReserve(-1)

        assertEquals(500L shl 20, controller.state.value.reserveBytes)
        assertEquals(WatchFillerOutcome.NO_ACCESS, controller.state.value.outcome)
    }

    @Test
    fun `the reserve cannot change while a run is going`() = runWatchTest {
        readyToStart()
        assertTrue(controller.start())
        val chosen = controller.state.value.reserveBytes

        controller.stepReserve(1)
        controller.stepReserve(-1)

        assertEquals(chosen, controller.state.value.reserveBytes)
        controller.cancel()
    }

    // Starting, cancelling before the host runs, and the refused host.

    @Test
    fun `start marks the run and asks the platform for the foreground host once`() = runWatchTest {
        readyToStart()

        assertTrue(controller.start())

        val state = controller.state.value
        assertTrue(state.running)
        assertEquals(FREE_BYTES - (250L shl 20), state.plannedBytes)
        assertEquals(0L, state.writtenBytes)
        assertNull(state.outcome)
        assertEquals(FillerRunService::class.java.name, host.startedServices.single().component?.className)

        assertFalse(controller.start())
        assertEquals(1, host.startedServices.size)
        controller.cancel()
    }

    @Test
    fun `cancelling before the host runs stops without writing`() = runWatchTest {
        readyToStart()
        assertTrue(controller.start())

        controller.cancel()

        val state = controller.state.value
        assertFalse(state.running)
        assertEquals(WatchFillerOutcome.CANCELLED, state.outcome)
        assertEquals(FILLER_RESERVE_BYTES, state.reserveBytes)
        assertNull(controller.runIn(scope))
        assertEquals(0L, engineStorage.appendedBytes)
    }

    @Test
    fun `a refused foreground host is not started and the reserve returns to the default`() = runWatchTest {
        readyToStart()
        host.refuse = true

        assertFalse(controller.start())

        val state = controller.state.value
        assertFalse(state.running)
        assertEquals(WatchFillerOutcome.NOT_STARTED, state.outcome)
        assertEquals(FILLER_RESERVE_BYTES, state.reserveBytes)
        assertNull(controller.runIn(scope))
        assertEquals(0L, engineStorage.appendedBytes)
    }

    // A run, and how the engine's result is shown.

    @Test
    fun `the run keeps the chosen reserve and the next run starts at the default`() = runWatchTest {
        refreshed()
        repeat(6) { controller.stepReserve(-1) }
        assertEquals(FILLER_MIN_RESERVE_BYTES, controller.state.value.reserveBytes)

        val state = fill()

        assertEquals(FILLER_MIN_RESERVE_BYTES, engineStorage.lowestAvailable)
        assertEquals(WatchFillerOutcome.DONE, state.outcome)
        assertFalse(state.running)
        assertFalse(state.pending)
        assertEquals(FILLER_RESERVE_BYTES, state.reserveBytes)
        assertEquals(FREE_BYTES - FILLER_MIN_RESERVE_BYTES, state.plannedBytes)
        assertEquals(FREE_BYTES - FILLER_MIN_RESERVE_BYTES, state.writtenBytes)
        assertEquals(100, state.percentDone)
        assertNull(state.remainingMillis)
    }

    @Test
    fun `a refused target is shown as no access`() = runWatchTest {
        readyToStart()
        engineStorage.valid = false

        assertEquals(WatchFillerOutcome.NO_ACCESS, fill().outcome)
    }

    @Test
    fun `an unmeasurable space is shown as such`() = runWatchTest {
        readyToStart()
        engineStorage.available = null

        assertEquals(WatchFillerOutcome.MEASUREMENT_UNAVAILABLE, fill().outcome)
    }

    @Test
    fun `a space that no longer clears the reserve is shown as no space`() = runWatchTest {
        readyToStart()
        engineStorage.available = 100L shl 20

        assertEquals(WatchFillerOutcome.INSUFFICIENT_SPACE, fill().outcome)
    }

    @Test
    fun `a session that appeared since the screen was measured is shown as an incomplete cleanup`() = runWatchTest {
        readyToStart()
        engineJournal.sessions += pendingSession()

        val state = fill()

        assertEquals(WatchFillerOutcome.CLEANUP_INCOMPLETE, state.outcome)
        assertTrue(state.pending)
        assertEquals(0L, engineStorage.appendedBytes)
    }

    @Test
    fun `a finished run whose cleanup failed is shown as an incomplete cleanup`() = runWatchTest {
        readyToStart()
        engineStorage.cleanupResult = false

        val state = fill()

        assertEquals(WatchFillerOutcome.CLEANUP_INCOMPLETE, state.outcome)
        assertTrue(state.pending)
        assertFalse(state.canStart)
    }

    @Test
    fun `a failed run whose files were deleted is shown as failed`() = runWatchTest {
        readyToStart()
        engineStorage.failAppend = true

        val state = fill()

        assertEquals(WatchFillerOutcome.FAILED, state.outcome)
        assertFalse(state.pending)
        assertEquals(1, engineStorage.cleanups)
    }

    @Test
    fun `a failed run whose cleanup failed is shown as an incomplete cleanup`() = runWatchTest {
        readyToStart()
        engineStorage.failAppend = true
        engineStorage.cleanupResult = false

        val state = fill()

        assertEquals(WatchFillerOutcome.CLEANUP_INCOMPLETE, state.outcome)
        assertTrue(state.pending)
    }

    @Test
    fun `a run that finds the engine busy shows busy and not a cleanup problem`() = runWatchTest {
        readyToStart()
        val entered = CompletableDeferred<Unit>()
        val gate = CompletableDeferred<Unit>()
        engineStorage.onAppend = {
            entered.complete(Unit)
            gate.await()
        }
        // The engine's lock is process-wide, so a run of another engine holds it against this controller's.
        val other = scope.launch {
            FillerEngine(engineStorage, engineJournal).run(FillerTarget(LOCATION, PRIMARY), FILLER_MIN_RESERVE_BYTES)
        }
        try {
            entered.await()

            val state = fill()

            assertEquals(WatchFillerOutcome.BUSY, state.outcome)
            assertTrue(state.pending)
            assertFalse(state.running)
        } finally {
            gate.complete(Unit)
            other.join()
        }
    }

    @Test
    fun `cancelling a run deletes what it wrote and shows cancelled`() = runWatchTest {
        readyToStart()
        val entered = CompletableDeferred<Unit>()
        val gate = CompletableDeferred<Unit>()
        engineStorage.onAppend = {
            entered.complete(Unit)
            gate.await()
        }
        assertTrue(controller.start())
        val job = requireNotNull(controller.runIn(scope))
        entered.await()
        assertTrue(controller.state.value.running)

        controller.cancel()
        job.join()

        val state = controller.state.value
        assertEquals(WatchFillerOutcome.CANCELLED, state.outcome)
        assertFalse(state.running)
        assertFalse(state.pending)
        assertEquals(FILLER_RESERVE_BYTES, state.reserveBytes)
        assertEquals(1, engineStorage.cleanups)
        assertTrue(engineJournal.sessions.isEmpty())
    }

    // A pending cleanup.

    @Test
    fun `a pending cleanup refuses a start and its retry clears it`() = runWatchTest {
        registerFreeBytes(downloads, 2L shl 30)
        engineJournal.sessions += pendingSession()

        val before = refreshed()
        assertTrue(before.pending)
        assertFalse(before.canStart)
        assertFalse(controller.start())
        assertTrue(host.startedServices.isEmpty())

        controller.retryCleanup()
        settle()

        val after = controller.state.value
        assertEquals(WatchFillerOutcome.CLEANUP_DONE, after.outcome)
        assertFalse(after.pending)
        assertTrue(after.canStart)
        assertEquals(1, engineStorage.cleanups)
    }

    @Test
    fun `a retry that cannot delete everything keeps the start refused`() = runWatchTest {
        registerFreeBytes(downloads, 2L shl 30)
        engineJournal.sessions += pendingSession()
        engineStorage.cleanupResult = false
        refreshed()

        controller.retryCleanup()
        settle()

        val state = controller.state.value
        assertEquals(WatchFillerOutcome.CLEANUP_INCOMPLETE, state.outcome)
        assertTrue(state.pending)
        assertFalse(state.canStart)
    }

    @Test
    fun `a retry with nothing pending does nothing`() = runWatchTest {
        registerFreeBytes(downloads, 2L shl 30)
        refreshed()

        controller.retryCleanup()
        settle()

        assertEquals(0, engineStorage.cleanups)
        assertNull(controller.state.value.outcome)
    }

    /** Measures the place again, as the screen does whenever it becomes visible, and waits for the result. */
    private suspend fun refreshed(): WatchFillerState {
        controller.refresh()
        settle()
        return controller.state.value
    }

    /** Waits for every job the controller launched in the test's scope. */
    private suspend fun settle() {
        scope.coroutineContext.job.children.toList().joinAll()
    }

    /** A measured place with the reserve at 250 MiB, so that the run may start on the 500 MiB the place reports. */
    private suspend fun readyToStart() {
        refreshed()
        repeat(2) { controller.stepReserve(-1) }
        assertEquals(250L shl 20, controller.state.value.reserveBytes)
        assertTrue(controller.state.value.canStart)
    }

    /** What the confirmation does: start, let the host run it, and wait for the run to end. */
    private suspend fun fill(): WatchFillerState {
        assertTrue(controller.start())
        requireNotNull(controller.runIn(scope)).join()
        return controller.state.value
    }

    private fun pendingSession() = FillerSession(UUID.randomUUID().toString(), FillerTarget(LOCATION, PRIMARY))

    /** One volume whose free space shrinks by what is appended and grows back when the session is cleaned. */
    private class FakeStorage(availableBytes: Long) : FillerStorage {
        private val initial = availableBytes
        var available: Long? = availableBytes
        var valid = true
        var cleanupResult = true
        var failAppend = false
        var onAppend: suspend () -> Unit = {}
        var lowestAvailable = availableBytes
            private set
        var appendedBytes = 0L
            private set
        var cleanups = 0
            private set

        override suspend fun validate(target: FillerTarget) = valid
        override suspend fun availableBytes(target: FillerTarget): Long? = available
        override suspend fun create(session: FillerSession, index: Int) = FillerFile("$index")
        override suspend fun append(file: FillerFile, count: Int) {
            if (failAppend) throw IOException("The storage failed")
            val left = requireNotNull(available) - count
            available = left
            lowestAvailable = minOf(lowestAvailable, left)
            appendedBytes += count
            onAppend()
        }
        override suspend fun cleanup(session: FillerSession): Boolean {
            cleanups++
            if (cleanupResult) available = initial
            return cleanupResult
        }
        override suspend fun discardPendingCreate(session: FillerSession) = true
    }

    private class FakeJournal : FillerJournal {
        val sessions = mutableListOf<FillerSession>()
        override suspend fun pendingSessions(): List<FillerSession> = sessions.toList()
        override suspend fun begin(target: FillerTarget) =
            FillerSession(UUID.randomUUID().toString(), target).also { sessions += it }
        override suspend fun prepareCreate(session: FillerSession, index: Int) = Unit
        override suspend fun recordCreated(session: FillerSession, index: Int, file: FillerFile) = Unit
        override suspend fun finish(session: FillerSession) {
            sessions -= session
        }
        override suspend fun resumeIndex(session: FillerSession): Int = sessions.size
    }

    private companion object {
        /** The phone's location, unchanged on the watch; the adapter's own constant is private. */
        const val LOCATION = "filler://app-downloads"
        const val PRIMARY = "primary"
        const val FREE_BYTES = 500L shl 20
        val BLOCK = ShadowStatFs.BLOCK_SIZE.toLong()
    }
}
