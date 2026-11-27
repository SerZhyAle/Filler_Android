package com.sza.filler.ui.filler

import androidx.lifecycle.SavedStateHandle
import com.sza.filler.domain.filler.FILLER_RESERVE_BYTES
import com.sza.filler.domain.filler.FillerEngine
import com.sza.filler.domain.filler.FillerFile
import com.sza.filler.domain.filler.FillerJournal
import com.sza.filler.domain.filler.FillerPlace
import com.sza.filler.domain.filler.FillerSession
import com.sza.filler.domain.filler.FillerStorage
import com.sza.filler.domain.filler.FillerTarget
import com.sza.filler.domain.filler.FillerTargetResolver
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
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
import org.robolectric.annotation.Config
import java.util.UUID

// The first-run start flow of the screen model: the default folder is selected without a grant, Start is offered
// only when it is safe, a failed default or measurement leaves a stated way forward, a picked folder replaces
// the default, and an earlier run's cleanup blocks a new run until it succeeds. The resume offer of S0049 (owner
// decision of 2026-11-16) beside that cleanup is covered too: an unfinished fill's files are filled again only on
// a storage that is connected. The source of the port has no test of its screen model, so these cases are this
// app's own; the engine, journal and adapter cases they rest on are the ported tests.

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class FillerViewModelStartFlowTest {
    private val storage = FakeStorage()

    @Before
    fun setUp() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun viewModel(
        journal: FakeJournal = FakeJournal(),
        savedState: SavedStateHandle = SavedStateHandle(),
    ) = FillerViewModel(FillerEngine(storage, journal), storage, storage, savedState)

    @Test
    fun freshLaunchSelectsTheDefaultFolderAndOffersStart() = runTest {
        val state = viewModel().state.value

        assertEquals(DEFAULT, state.place?.target?.location)
        assertEquals("Internal storage", state.place?.volumeName)
        assertTrue(state.accessible)
        assertEquals(storage.available, state.availableBytes)
        assertEquals(FILLER_RESERVE_BYTES, state.reserveBytes)
        assertNull(state.outcome)
        assertFalse(state.running)
        assertTrue(state.canStart)
        assertTrue(storage.granted.isEmpty())
    }

    @Test
    fun selectingTheDefaultFolderWritesNothing() = runTest {
        viewModel()

        assertEquals(0, storage.created)
    }

    @Test
    fun noDefaultFolderLeavesNoPlaceAndStartDisabled() = runTest {
        storage.defaultAddress = null

        val state = viewModel().state.value

        assertNull(state.place)
        assertNull(state.availableBytes)
        assertNull(state.outcome)
        assertFalse(state.canStart)
    }

    @Test
    fun anUnmeasuredDefaultReportsItAndDisablesStart() = runTest {
        storage.available = null

        val state = viewModel().state.value

        assertEquals(DEFAULT, state.place?.target?.location)
        assertNull(state.availableBytes)
        assertEquals(FillerOutcome.MEASUREMENT_UNAVAILABLE, state.outcome)
        assertFalse(state.canStart)
    }

    @Test
    fun anInaccessibleDefaultReportsItAndDisablesStart() = runTest {
        storage.accessible = false

        val state = viewModel().state.value

        assertFalse(state.accessible)
        assertEquals(FillerOutcome.NO_ACCESS, state.outcome)
        assertFalse(state.canStart)
    }

    @Test
    fun aPickedFolderReplacesTheDefaultAndIsGrantedOnce() = runTest {
        val model = viewModel()

        model.onFolderPicked(PICKED)

        assertEquals(listOf(PICKED), storage.granted)
        assertEquals(PICKED, model.state.value.place?.target?.location)
        assertEquals("Memory card", model.state.value.place?.volumeName)
        assertNull(model.state.value.outcome)
        assertTrue(model.state.value.canStart)
    }

    @Test
    fun aPickedFolderOutsideLocalStorageIsRefused() = runTest {
        val model = viewModel()

        model.onFolderPicked(CLOUD)

        assertNull(model.state.value.place)
        assertEquals(FillerOutcome.NOT_LOCAL, model.state.value.outcome)
        assertFalse(model.state.value.canStart)
    }

    @Test
    fun aFolderTheScreenAlreadyHoldsIsNotReplacedByTheDefault() = runTest {
        // "filler_location" is the key the view model saves the picked folder under.
        val state = viewModel(savedState = SavedStateHandle(mapOf("filler_location" to PICKED))).state.value

        assertEquals(PICKED, state.place?.target?.location)
    }

    @Test
    fun earlierPendingCleanupBlocksStartAndStaysRetryableUntilItSucceeds() = runTest {
        val session = FillerSession(UUID.randomUUID().toString(), DEFAULT_TARGET)
        storage.cleanupSucceeds = false
        val model = viewModel(FakeJournal(listOf(session)))

        assertNotNull(model.state.value.pending)
        assertFalse(model.state.value.canStart)
        model.start()
        assertEquals(0, storage.created)

        model.retryCleanup()
        assertEquals(FillerOutcome.CLEANUP_INCOMPLETE, model.state.value.outcome)
        assertNotNull(model.state.value.pending)
        assertFalse(model.state.value.canStart)

        storage.cleanupSucceeds = true
        model.retryCleanup()
        assertEquals(FillerOutcome.CLEANUP_DONE, model.state.value.outcome)
        assertNull(model.state.value.pending)
        assertTrue(model.state.value.canStart)
    }

    // S0049: the resume offer of a fill that a closed app left unfinished (owner decision of 2026-11-16).

    @Test
    fun reachableLeftoverFilesOfferResumeAndCompleteTheEnding() = runTest {
        val session = FillerSession(UUID.randomUUID().toString(), DEFAULT_TARGET)
        storage.available = FILLER_RESERVE_BYTES
        val model = viewModel(FakeJournal(listOf(session)))

        val before = model.state.value
        assertTrue(before.canResume)
        assertEquals(FillerPlace(DEFAULT_TARGET, "Internal storage", "Download"), before.pending)

        model.resume()

        val after = model.state.value
        assertFalse(after.running)
        assertNull(after.pending)
        assertEquals(FillerOutcome.DONE, after.outcome)
        assertEquals(0, storage.created)
    }

    @Test
    fun leftoverFilesOnAMissingStorageOfferDeletionOnly() = runTest {
        val session = FillerSession(UUID.randomUUID().toString(), DEFAULT_TARGET)
        storage.accessible = false
        val model = viewModel(FakeJournal(listOf(session)))

        val state = model.state.value
        assertNotNull(state.pending)
        assertFalse(state.canResume)
    }

    /** Two local places, a default and a picked one; anything else is not on a local volume. */
    private class FakeStorage : FillerStorage, FillerTargetResolver {
        var defaultAddress: String? = DEFAULT
        var accessible = true
        var available: Long? = 5L shl 30
        var cleanupSucceeds = true
        var created = 0
            private set
        val granted = mutableListOf<String>()
        private val places = mapOf(
            DEFAULT to FillerPlace(DEFAULT_TARGET, "Internal storage", "Download"),
            PICKED to FillerPlace(FillerTarget(PICKED, "card"), "Memory card", "Fill"),
        )

        override suspend fun defaultLocation(): String? = defaultAddress
        override suspend fun grant(location: String): Boolean {
            granted += location
            return true
        }
        override suspend fun place(location: String): FillerPlace? = places[location]
        override suspend fun validate(target: FillerTarget) = accessible && places.values.any { it.target == target }
        override suspend fun availableBytes(target: FillerTarget): Long? = available
        override suspend fun create(session: FillerSession, index: Int): FillerFile {
            created++
            return FillerFile("$index")
        }
        override suspend fun append(file: FillerFile, count: Int) = Unit
        override suspend fun cleanup(session: FillerSession): Boolean = cleanupSucceeds
        override suspend fun discardPendingCreate(session: FillerSession) = true
    }

    /** Holds the sessions a previous process left behind, as the real journal does after a restart. */
    private class FakeJournal(initial: List<FillerSession> = emptyList()) : FillerJournal {
        private val sessions = initial.toMutableList()
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
        const val DEFAULT = "filler://default"
        const val PICKED = "filler://picked"
        const val CLOUD = "filler://cloud"
        val DEFAULT_TARGET = FillerTarget(DEFAULT, "primary")
    }
}
