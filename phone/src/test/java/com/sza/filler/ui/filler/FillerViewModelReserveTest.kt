package com.sza.filler.ui.filler

import androidx.lifecycle.SavedStateHandle
import com.sza.filler.domain.filler.FILLER_MIN_RESERVE_BYTES
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
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.UUID

// The reserve the user may lower before a run (owner order of 2026-11-13, S0005; catalog proposal FILLER-RESERVE).
// The source of the port has no test of its screen model, so these cases are this app's own.

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class FillerViewModelReserveTest {
    private val storage = FakeStorage(availableBytes = 500L shl 20)
    private val journal = FakeJournal()

    @Before
    fun setUp() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun viewModel() = FillerViewModel(FillerEngine(storage, journal), storage, storage, SavedStateHandle())

    @Test
    fun defaultReserveRefusesLessFreeSpaceThanOneGibibyte() = runTest {
        val state = viewModel().state.value

        assertEquals(FILLER_RESERVE_BYTES, state.reserveBytes)
        assertFalse(state.canStart)
        assertEquals(FillerOutcome.INSUFFICIENT_SPACE, state.outcome)
    }

    @Test
    fun loweredReserveLetsTheRunStartAndClearsTheNoSpaceVerdict() = runTest {
        val model = viewModel()

        model.chooseReserve(FILLER_MIN_RESERVE_BYTES)

        assertEquals(FILLER_MIN_RESERVE_BYTES, model.state.value.reserveBytes)
        assertTrue(model.state.value.canStart)
        assertNull(model.state.value.outcome)
    }

    @Test
    fun aValueOutsideTheChoicesIsIgnored() = runTest {
        val model = viewModel()

        model.chooseReserve(FILLER_MIN_RESERVE_BYTES - 1)
        model.chooseReserve(5L shl 20)

        assertEquals(FILLER_RESERVE_BYTES, model.state.value.reserveBytes)
    }

    @Test
    fun theRunKeepsTheChosenReserveAndTheNextRunStartsAtTheDefault() = runTest {
        val model = viewModel()
        model.chooseReserve(FILLER_MIN_RESERVE_BYTES)

        model.start()

        assertEquals(FILLER_MIN_RESERVE_BYTES, storage.lowestAvailable)
        assertEquals(FillerOutcome.DONE, model.state.value.outcome)
        assertFalse(model.state.value.running)
        assertEquals(FILLER_RESERVE_BYTES, model.state.value.reserveBytes)
    }

    @Test
    fun theReserveCannotChangeWhileARunIsGoing() = runTest {
        val model = viewModel()
        model.chooseReserve(FILLER_MIN_RESERVE_BYTES)
        storage.onAppend = { model.chooseReserve(500L shl 20) }

        model.start()

        assertEquals(FILLER_MIN_RESERVE_BYTES, storage.lowestAvailable)
    }

    /** One volume whose free space shrinks by what is appended and grows back when the session is cleaned. */
    private class FakeStorage(availableBytes: Long) : FillerStorage, FillerTargetResolver {
        private val initial = availableBytes
        private var available = availableBytes
        var lowestAvailable = availableBytes
            private set
        var onAppend: () -> Unit = {}
        private val target = FillerTarget(LOCATION, "primary")

        override suspend fun defaultLocation(): String = LOCATION
        override suspend fun grant(location: String) = true
        override suspend fun place(location: String) =
            if (location == LOCATION) FillerPlace(target, "Internal storage", "Download") else null
        override suspend fun validate(target: FillerTarget) = target == this.target
        override suspend fun availableBytes(target: FillerTarget): Long = available
        override suspend fun create(session: FillerSession, index: Int) = FillerFile("$index")
        override suspend fun append(file: FillerFile, count: Int) {
            available -= count
            lowestAvailable = minOf(lowestAvailable, available)
            onAppend()
        }
        override suspend fun cleanup(session: FillerSession): Boolean {
            available = initial
            return true
        }
        override suspend fun discardPendingCreate(session: FillerSession) = true
    }

    private class FakeJournal : FillerJournal {
        private val sessions = mutableListOf<FillerSession>()
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
        const val LOCATION = "filler://test"
    }
}
